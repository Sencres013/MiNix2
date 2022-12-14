local gpu = component.proxy(component.list("gpu")());

if not gpu then
    computer.shutdown();
end

local screen;
for address in component.list("screen") do
    if #component.invoke(address, "getKeyboards") > 0 then
        screen = address;
        break;
    end
end

if not screen then
    screen = component.list("screen")();
end

if not screen or not gpu.bind(screen) then
    computer.shutdown();
end

local screenWidth, screenHeight = gpu.getResolution();

gpu.setDepth(gpu.maxDepth());
gpu.setBackground(0x000000);
gpu.setForeground(0xA5A5A5);
gpu.fill(1, 1, screenWidth, screenHeight, " ");
gpu.set(1, screenHeight, "Ctrl - ");
gpu.setForeground(0xFFFFFF);

local deadline = computer.uptime() + 2;

while computer.uptime() < deadline do
    local signal = table.pack(computer.pullSignal(deadline - computer.uptime()));
    
    -- left ctrl
    if signal[1] == "key_down" and signal[4] == 0x1d then
        gpu.fill(1, 1, screenWidth, screenHeight, " ");
        -- TODO
        break;
    end
end

gpu.fill(1, 1, screenWidth, screenHeight, " ");

local lineNum = 1;

local function status(text, statusCode)
    checkArg(1, text, "string");
    checkArg(2, statusCode, "number", "nil");
    
    statusCode = type(statusCode) == "number" and statusCode or 0;
    
    local statusColor, statusText, statusOffset;
    
    -- nil (or anything besides 1 and 2) = in progress, 1 = ok, 2 = fail
    if statusCode == 1 or statusCode == 2 then
        if statusCode == 1 then
            statusColor = 0x00B600;
            statusText = "OK";
            statusOffset = 4;
        else
            statusColor = 0xFF0040;
            statusText = "FAIL";
            statusOffset = 3;
        end
        
        gpu.set(1, lineNum, "[");
        gpu.setForeground(statusColor);
        gpu.set(statusOffset, lineNum, statusText);
        gpu.setForeground(0xFFFFFF);
        gpu.set(8, lineNum, "]");
    end
    
    for i = 0, #text // (screenWidth - 9), 1 do
        gpu.set(10, lineNum, string.sub(text, i * (screenWidth - 9), math.min((i + 1) * (screenWidth - 9), #text)));
        
        if lineNum + 1 > screenHeight then
            gpu.copy(1, 2, screenWidth, screenHeight - 1, 0, -1);
            gpu.fill(1, screenHeight, screenWidth, 1, " ");
        else
            lineNum = lineNum + 1;
        end
    end
end

status("GPU bound to screen", 1);
status("Finding bootable MiNix medium");

local eeprom = component.proxy(component.list("eeprom")());
local bootFs = component.proxy(eeprom.getData());

if bootFs then
    status("Found bootable MiNix medium", 1);
else
    for address in component.list("filesystem") do
        local fs = component.proxy(address);

        if fs.getLabel() ~= "tmpfs" and not fs.isReadOnly() and fs.exists("/sbin/init.lua") then
            bootFs = fs;
            break;
        end
    end

    if not bootFs then
        status("Bootable MiNix filesystem not found", 2);
        status("Waiting for insertion of a bootable MiNix filesystem");

        while true do
            local signal = table.pack(computer.pullSignal());

            if signal[1] == "component_added" and signal[3] == "filesystem" then
                if component.invoke(signal[2], "exists", "/sbin/init.lua") then
                    bootFs = signal[2];
                    break;
                end
            end
        end
    end
end

eeprom.setData(bootFs.address);

function dofile(path)
    checkArg(1, path, "string");

    local filename = string.sub(path, (#path - (string.find(string.reverse(path), "/") or #path + 1) + 2) or 0, #path);

    if not bootFs.exists(path) then
        error("Can't find file " .. filename, 0);
    elseif bootFs.isDirectory(path) then
        error(path .. " is a directory", 0);
    end

    local handle = bootFs.open(path);

    local buffer, data = "", "";
    repeat
        data = data .. buffer;
        buffer = bootFs.read(handle, math.huge);
    until not buffer

    local res, err = load(data, "=" .. string.sub(filename, 1, string.find(filename, ".", 1, true) - 1));

    if res == "fail" then
        error("Error executing " .. filename .. ": " .. tostring(err), 0);
    end

    return res;
end

status("Loading init file");

local init = dofile("/sbin/init.lua");

status("Loaded init file", 1);
status("Initializing module system");

package = {
    preload = {},
    loaded = {},
    search = function(module, path)
        checkArg(1, module, "string");
        checkArg(2, path, "string", "nil");

        path = path or "/";

        if bootFs.exists(path .. module) then
            return (path .. module);
        end

        for obj in bootFs.list(path) do
            if bootFs.isDirectory(obj) then
                local found = package.search(module, obj);

                if found then
                    return found;
                end
            end
        end

        return false;
    end
};

-- analogous to lua module requiring
function require(module)
    checkArg(1, module, "string");

    if package.loaded[module] then
        return package.loaded[module];
    elseif package.preload[module] then
        error("Recursive require detected in module " .. module, 0);
    end

    preload[module] = true;

    local modulePath = package.search(module);
    if not modulePath then
        error("Module " .. module .. " not found", 0);
    end

    local res = dofile(modulePath);

    package.preload[module] = nil;
    package.loaded[module] = res() or true;
    return package.loaded[module];
end

status("Initialized module system");

init();

-- as to not get a "computer halted" error
computer.shutdown();

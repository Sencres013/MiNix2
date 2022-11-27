do
    local gpu = component.proxy(component.list("gpu")());
    local screen = component.proxy(component.list("screen")());

    if gpu and screen then
        gpu.bind(screen.address);
    else
        error("unable to bind gpu to screen");
    end
end

local eeprom = component.proxy(component.list("eeprom")());

local init;

do
    local bootFs, fsList, index = component.proxy(eeprom.getData()), {}, 1;

    if not bootFs then
        local tempIndex = 1;
        for address in component.list("filesystem") do
            if component.invoke(address, "getLabel") ~= "tmpfs" then
                fsList[tempIndex] = address;
                tempIndex = tempIndex + 1;
            end
        end

        bootFs = component.proxy(fsList[1]);
        index = 2;
    end
    
    while bootFs do
        if bootFs.exists("/sbin/init.lua") then
            local handle = bootFs.open("/sbin/init.lua");
            
            local buffer, data = "", "";
            repeat
                data = data .. buffer;
                buffer = bootFs.read(handle, math.huge);
            until not buffer
            
            local _init, err = load(data, "=init");
            
            if _init == "fail" then
                error("Error loading OS: " .. err);
            end
            
            init = _init;
            break;
        end
        
        bootFs = component.proxy(fsList[index]);
        index = index + 1;
    end
end

if not init then
    error("no bootable medium found");
end

init();
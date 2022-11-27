--[[do
    local deadline = computer.uptime() + 1;

    while computer.uptime() < deadline do
        local signal = table.pack(computer.pullSignal(1));

        -- lshift or rshift key held down
        if signal[1] == "key_down" and (signal[4] == 0x2a or signal[4] == 0x36) then
            
        end
    end
end]]

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
error("a: " .. eeprom.getData(), 0);
do

    computer.getBootAddress = computer.getBootAddress or function() return eeprom.getData() end;
    computer.setBootAddress = computer.setBootAddress or function(data) return eeprom.setData(data) end;
end

local main;

do
    local bootFs, fsList, index = component.proxy(eeprom.getData()), {}, 1;

    if not bootFs then
        local tempIndex = 1;
        for address in component.list("filesystem") do
            fsList[tempIndex] = address;
            tempIndex = tempIndex + 1;
        end

        bootFs = component.proxy(fsList[1]);
        index = 2;
    end

    while bootFs do
        if bootFs.exists("/boot/main.lua") then
            local handle = bootFs.open("/boot/main.lua");

            local buffer, data = "", "";
            repeat
                data = data .. buffer;
                buffer = bootFs.read(handle, math.huge);
            until not buffer

            local _main, err = load(data, "=main");

            if _main == "fail" then
                error("Error loading OS: " .. err);
            end

            main = _main;
            break;
        end

        bootFs = component.proxy(fsList[index]);
        index = index + 1;
    end
end

if not main then
    error("no bootable medium found");
end

main();
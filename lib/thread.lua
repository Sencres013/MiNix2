-- WIP

local thread = {};

local function thread.spawn(callback, ...)
    checkArg(1, callback, "function");

    local thread = coroutine.create(callback, ...);

    if not thread then
        error("Could not create thread: " .. debug.traceback());
    end

    return thread;
end

local function thread.kill(thread)
    
end

return threads;
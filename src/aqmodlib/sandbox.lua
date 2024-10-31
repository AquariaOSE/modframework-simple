local sandbox = {}

local setfenv = rawget(_G, "setfenv")
if setfenv then
    -- Lua 5.1
    function sandbox.loadstring(s, env)
        local f, err = loadstring(s)
        if f then
            setfenv(f, env)
        end
        return f, err
    end

    function sandbox.loadfile(fn, env)
        local f, err = loadfile(fn)
        if f then
            setfenv(f, env)
        end
        return f, err
    end
    
    --[[
    local function restore(f, oldenv, ...)
        setfenv(f, oldenv)
        return ...
    end
    
    local xxpcall = assert(xxpcall)
    local pcall = pcall
    local getfenv = getfenv
    
    function sandbox.pcall(f, env, ...)
        local oldenv = getfenv(f)
        setfenv(f, env)
        return restore(f, oldenv, pcall(f, ...))
    end
    
    function sandbox.xpcall(f, env, err, ...)
        local oldenv = getfenv(f)
        setfenv(f, env)
        return restore(f, oldenv, xxpcall(f, err, ...)) -- Lua 5.1 xpcall() does not support params, use custom version
    end
    ]]
else
    -- Lua 5.2+
    function sandbox.loadstring(s, env)
        return load(s, "", "bt", env)
    end

    function sandbox.loadfile(fn, env)
        return loadfile(fn, "bt", env)
    end
    
    --[[
    local pcall = pcall
    local xpcall = xpcall
    local _ENV
    
    local function restore(env, ...)
        _ENV = env
        return ...
    end
    
    function sandbox.pcall(f, env, ...)
        local oldenv = _ENV
        _ENV = env
        return restore(oldenv, pcall(f, ...))
    end
    
    function sandbox.xpcall(f, env, err, ...)
        local oldenv = _ENV
        _ENV = env
        return restore(oldenv, xpcall(f, err, ...)) -- Lua 5.2+ xpcall() does support params, can use that
    end
    ]]
end

rawset(_G, "sandbox", sandbox)

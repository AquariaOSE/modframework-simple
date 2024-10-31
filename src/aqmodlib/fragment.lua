-- fragment loader
-- uses _CTQ from tq.lua as the context to run inside, if present


local FRAGS = {}
local TQ = tq_create()

local yield = coroutine.yield
local cowrap = coroutine.wrap
local costatus = coroutine.status

local staticdata =
{
    tq = TQ,
}

local G =
{
    -- for backwards compat. should use yield()
    wait = function(t)
        yield(t)
    end,
    watch = function(t)
        disableInput()
        yield(t)
        enableInput()
    end,

    yield = yield,
    schedule = function(...) return (_CTQ or TQ):push(...) end
}
--G._G = G -- don't need to lie about this
G.__index = _G
G.__newindex = function(k, val) error("Fragment: Attempt to set global [" .. tostring(k) .. "] to " .. type(val)) end
setmetatable(G, G)

local function frag_load(name, env, path, nocache)
    name = name:lower()
    path = path or "fragment"
    env = env or G
    local fn = "src/" .. path .. "/" .. name .. ".lua"
    local f
    local cache = not nocache
    if cache then
        f = FRAGS[fn]
    end
    if f == nil then
        f = assert(sandbox.loadfile(fn, env))
        if cache then
            FRAGS[fn] = f
        end
    end
    return f
end

-- this can actually run any function as a fragment.
-- just remember that the fenv of a "normal" function is _G, not the slightly more convenient G above!
local function frag_start(f, ...)
    return (_CTQ or TQ):launch(false, f, ...)
end

-- returns a function f that starts fragment name when called.
-- f(...) calls fragment(...)
local function frag_loadfunc(name)
    local frag = frag_load(name)
    if frag then
        return function(...)
            return frag_start(frag, ...)
        end
    end
end


-- idea via https://gist.github.com/daurnimator/ec4eb15407262ee0d27d
local function yieldresume(state, f, ...)
    if state.running then
        return yieldresume(state, f, f(yield(...))) -- recursive tailcall!
    end
    return ...
end
local function _restoreV(prevv, ...)
    v_restoreContext(prevv)
    return ...
end
local function _callWithV(vv, f, ...)
    local prevv = v_pushContext(vv)
    return _restoreV(prevv, f(...))
end
local function _finish(state, ...)
    return ...
end
local function _launch(state, f, ...)
    return _finish(state, yieldresume(state, f, f(...)))
end

-- passed-in v will be set whenever the function is running
local function meanwhile_v(vv, f, ...)
    if not vv and MOD_RELEASE then
        return frag_start(f, ...) -- actually really simple. just ignore v handling
    end
    
    local state = { running = true }
    local runco = cowrap(function(...)
        f(...) -- can yield
        state.running = false -- signal yieldresume() to exit
    end)
    local ff = function(...) return _callWithV(vv, runco, ...) end
    return frag_start(_launch, state, ff, ...)
end

-- no guarantees about v (context-less call)
local function meanwhile_x(f, ...)
    return meanwhile_v(false, f, ...) -- invalidate v so we don't accidentally use it
end

-- runs f(...) in background.
-- f(...) is called immediately, until that calls yield(t). Resumes running f after t seconds.
-- carries forward current v into the call.
local function meanwhile(f, ...)
    return meanwhile_v(v, f, ...)
end

-----------------------

local function frag_INTERNAL_update(dt)
    TQ:update(dt)
end

local function frag_DEBUG_count()
    return TQ:size(), table.count(FRAGS)
end

local function cleanup(mapchange)
    if mapchange then
        TQ:clear()
    end
    modlib_onClean(cleanup)
end
cleanup()

return {
    modlib_updateFragments = frag_INTERNAL_update,
    frag_DEBUG_count = frag_DEBUG_count,
    frag_load = frag_load,
    frag_loadfunc = frag_loadfunc,
    frag_start = frag_start,
    meanwhile = meanwhile,
    meanwhile_x = meanwhile_x,
    meanwhile_v = meanwhile_v,
}

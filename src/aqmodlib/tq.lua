-- timerqueue module
-- for delayed function calls

local tins = table.insert
local tremove = table.remove
local tassign = assert(table.assign)
local tpack = assert(table.pack)
local type = type
local error = error
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local setmetatable = setmetatable
local next = next
local cowrap = coroutine.wrap
local costatus = coroutine.status

-- cache table to take some work off the GC if the TQ system is used a lot per-frame
local GARBAGE = setmetatable({}, {__mode="kv"})

-- set to current tq when we're running inside a coroutine started by tq:launch()
_CTQ = false -- yes this is intentionally a global

local M = {}
M.__index = M

function M:push(...)
    local t = self:_push(...)
    t.withdt = false
end

function M:pushDT(...)
    local t = self:_push(...)
    t.withdt = true
end


function M:_push(delay, func, ...)
    if type(delay) ~= "number" then
        error("TQ: param 1: expected number, got " .. type(delay))
    end
    if type(func) ~= "function" then
        error("TQ: param 2: expected function, got " .. type(func))
    end
    
    local t = next(GARBAGE)
    if t then
        GARBAGE[t] = nil
        t.n = tassign(t, 1, ...)
    else
        t = tpack(...) -- assigns t.n
    end
    t.f = func
    t.t = delay
    
    tins(self, t)

    return t
end

-- re-entrant update function
-- that means calling wait()/watch() in a TQ callback is allowed,
-- and calling push() from a callback is no problem either.
function M:update(dt)
    if not self[1] then
        return
    end
    local N = #self
    local i = 1
    while true do -- not using a for loop is intentional, because it's not safe to insert while iterating
        -- NOTE: it's legal that a callback schedules another call with t=0,
        -- which is then called in the NEXT update().
        -- In general, we want to only update those entries that exist by the time
        -- update() is called.
        -- Therefore we check for a maximum index, not until e is nil!
        if i > N then
            break
        end
        local e = self[i] -- known to exist
        if e.t < dt then
            N = N - 1
            tremove(self, i)
            GARBAGE[e] = true
            if e.withdt then
                e.f(dt, unpack(e, 1, e.n))
            else
                e.f(unpack(e, 1, e.n))
            end
        else
            e.t = e.t - dt
            i = i + 1
        end
    end 
end

function M:isEmpty()
    return not self[1]
end

function M:size()
    return #self
end

-- don't call this when iterating
function M:clear()
    for i = 1, #self do
        self[i] = nil
    end
end

local function _coroTick(dt, tq, co, timepassed, pass, ...)
    local wait
    local ctq = _CTQ
    _CTQ = tq
    if not timepassed then -- first call?
        wait = co(...) -- pass params to start of function
        timepassed = 0
    else
        wait = co(timepassed, dt) -- further yield()s return the total time passed plus the dt this frame
    end
    _CTQ = ctq
    
    --if costatus(co) == "dead" then -- doesn't work, co is a function, not an actual coro
    if pass._done then -- with the little hack below this works instead
        return
    end
    
    if wait == nil then
        wait = 0 -- resume next frame
    end
    
    if type(wait) == "number" and wait >= 0 then
        tq:pushDT(wait, _coroTick,
            tq, co, timepassed + wait + dt, pass)
    else
        error("TQ:launch: Unable to deal with return type (" .. type(wait).. "), value [" 
            .. tostring(wait) .. "]. Return/yield nil, false, or a number >= 0!")
    end
end

local function _done(pass, ...)
    pass._bodyDone = true
    if select("#", ...) > 0 then
        pass._retvals = table.pack(...)
    end
    -- now that the coro is about done, run all followups
    -- in theory followups could yield(), so don't set _done just yet
    local ff = pass._followups
    if ff then
        for i = 1, #ff do
            local fe = ff[i]
            fe.f(unpack(fe, 1, fe.n))
        end
    end
    pass._done = true -- must be the very last thing before exiting here
    return ...
end

local passMeta = {}
passMeta.__index = passMeta
function passMeta:afterwards(f, ...)
    assert(f)
    if self._done then -- a launched func without delay is run and may finish inline; run followups right now if done
        f(...)
    else -- remember for later
        local ff = self._followups
        if not ff then
            ff = {}
            self._followups = ff
        end
        local fe = table.pack(...)
        fe.f = f
        tins(ff, fe)
    end
end
function passMeta:done()
    return self._bodyDone
end
function passMeta:allDone()
    return self._done
end
function passMeta:getResults()
    local r = self._retvals
    if r then
        return unpack(r, 1, r.n)
    end
end

function M:launch(delay, f, ...)
    -- upvalue(1) of co would be the actual coroutine, but we don't rely on the debug lib to be present
    -- so instead we use a table that gets passed around; _done=true will be set just before the coro exits
    local pass = setmetatable({ _done = false, _bodyDone = false, tq = self }, passMeta)
    local co = cowrap(function(...)
        return _done(pass, f(...))
    end)
    if not delay then
        _coroTick(0, self, co, false, pass, ...)
    else
        assert(type(delay) == "number" and delay >= 0, "param #1 must be number >= 0")
        self:pushDT(delay, _coroTick,
            self, co, false, pass, ...)
    end
    return pass -- so we can do tq:launch(...):afterwards(...) ...
end

local function tq_create()
    return setmetatable({}, M)
end

return {
    tq_create = tq_create,
}

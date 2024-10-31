--[[
Notation:

<varname>  -- angle brackets for variable names (description inside the bracket)

---== IMPLEMENTED FUNCTIONS ==---

cn max <target> <inputs...>
cn min <target> <inputs...>


]]

local tins = table.insert

local M = assert(circuitnetwork.modules)
local toint = assert(circuitnetwork.toint)
local tclear = assert(table.clear)

-- return result from init
local compileExpr = assert(circuitnetwork.compileExpr)
local configureEval = assert(circuitnetwork.configureEval)
local configureEvalK = assert(circuitnetwork.configureEvalK)
local evalCallback = assert(circuitnetwork.evalCallback)
local splitExpr = assert(circuitnetwork.splitExpr)
local valexpr = assert(circuitnetwork.valexpr)
local kunion = assert(circuitnetwork.kunion)

-- return first thing from init(), keep second thing as function that returns bool whenever the condition is true
local condition = assert(circuitnetwork.condition)

-----------------------

local function exprOrNum(expr, defaultval) -- HACK: to support hardcoded floats
    if not expr then
        if defaultval then
            return nil, function() return defaultval end
        end
        return
    end
    local t = tonumber(expr)
    if t then
        return nil, function() return t end
    end
    return valexpr(expr)
end


-- cn playerin var
-- Puts into 'var' if the player is inside the node (0 or 1)
M["playerin"] =
{
    init = function(d, node, target)
        assert(target, "need target")
        local function isPlayerIn()
            return node_isEntityIn(node, getNaija())
        end
        return evalCallback(target, isPlayerIn)
    end,
}

local function countEntities(e, counts)
    local name = entity_getName(e):lower()
    counts[name] = (counts[name] or 0) + 1
end

-- cn count j=jelly d=energydoor x=crotoid+aggrohopper
-- (yes this supports simple exprs as long as ALL variables are entity names
-- whose counts are provided by this node)
M.count =
{
    init = function(d, node, ...)
        local t, n = table.pack2(...)
        local funcs = {}
        local provides = {}
        for i = 1, n do
            local x = compileExpr(t[i])
            if x.var then
                tins(funcs, x.f)
                tins(provides, x.var)
            end
        end
        d.funcs = funcs
        d.counts = {}
        return configureEval(provides, nil)
    end,
    preEval = function(d, node)
        local counts = d.counts
        tclear(counts)
        node_forAllEntitiesWithin(node, countEntities, counts)
    end,
    eval = function(d, node, _in, _out)
        for _, f in pairs(d.funcs) do -- order doesn't matter
            f(d.counts, _out)
        end
    end,
}

-- cn countall (no params; to count all entities and export all their counts as vars)
M.countall =
{
    init = function(d, node, ...)
        return configureEval(nil, nil)
    end,
    eval = function(d, node, _in, _out)
        node_forAllEntitiesWithin(node, countEntities, _out)
    end,
}

local function doorstate(door, open)
    --[[local state = entity_getState(door)
    local fast = getMapTime() < 0.2
    if open then
        if not (state == STATE_OPENED or state == STATE_OPEN) then
            entity_setState(door, (fast and STATE_OPENED) or STATE_OPEN)
        end
    else
        if not (state == STATE_CLOSED or state == STATE_CLOSE) then
            entity_setState(door, (fast and STATE_CLOSED) or STATE_CLOSE)
        end
    end]]
    doorhelper_setState(door, open)
end
local function findDoor(e)
    if egetv(e, EV_TYPEID) == EVT_DOOR then
        return e
    end
end
M.opendoor =
{
    init = function(d, node, ...)
        d.door = node_forAllEntitiesWithin(node, findDoor) or 0
        local expr, xx = ...
        if xx then
            warnLog("cn opendoor: Extraneous expr ignored: " .. xx)
        end
        local ret, cond = condition(expr)
        d.dbgword = "???"
        d.check = cond
        return ret
    end,
    update = function(d, node, dt, _in, _out)
        local open = d.check(_in, _out)
        d.dbgword = open and "open" or "closed"
        if d.door ~= 0 then
            doorstate(d.door, open)
        end
    end,
    inspect = function(d)
        if d.door ~= 0 then
            return "My door: " .. entity_getName(d.door) .. " (id: " .. entity_getID(d.door) .. ")"
            .. "\nShould be: " .. d.dbgword
        end
        return "No door found!"
    end,
}

local doorStateToNum =
{
    [STATE_CLOSED] = 0,
    [STATE_OPENED] = 3,
    [STATE_OPEN] = 2,
    [STATE_CLOSE] = 1,
}
local doorStateName =
{
    [STATE_CLOSED] = "closed",
    [STATE_OPENED] = "opened",
    [STATE_OPEN] = "opening",
    [STATE_CLOSE] = "closing",
}
M.readdoor =
{
    init = function(d, node, ...)
        local door = node_forAllEntitiesWithin(node, findDoor) or 0
        d.door = door
        local var, xx = ...
        if xx then
            warnLog("cn readdoor: Extraneous expr ignored: " .. xx)
        end
        if door ~= 0 then
            local function doorstate()
                return doorStateToNum[entity_getState(door)]
            end
            return evalCallback(var, doorstate)
        end
    end,
    inspect = function(d)
        if d.door ~= 0 then
            local state = entity_getState(d.door)
            return "My door: " .. entity_getName(d.door) .. " (id: " .. entity_getID(d.door) .. ")"
            .. "\nStatus: " .. tostring(doorStateName[state]) .. " -> " .. tostring(doorStateToNum[state])
        end
        return "No door found!"
    end,

}

-- cn latch x=expr latchcond [timeout]
-- Latches and stores value when latchcond is true, otherwise returns stored value.
-- If a timeout expression is specified, reset to 0 after that many seconds.
-- The timeout is evaluated whenever the value is latched.
M.latch =
{
    init = function(d, node, ...)
        local outexpr, condexpr, timoexpr = ...
        local q, cond = condition(condexpr)
        local x = compileExpr(outexpr)
        local timo, timof = exprOrNum(timoexpr)
        d.var = assert(x.var, "first latch expr must set a variable")
        d.f = x.f
        d.latched = 0
        d.check = cond
        d.to = 0
        d.timof = timof
        return configureEvalK(x.var, kunion(x.referenced, q.referenced, timo and timo.referenced))
    end,
    eval = function(d, node, _in, _out)
        local val
        local on = d.check(_in, _out)
        d.on = on
        if on then
            if d.timof then
                d.to = d.timof(_in, _out)
            end
            val = assert(d.f(_in, _out))
            d.latched = val
        else
            val = d.latched
            _out[d.var] = val
        end
        return val
    end,
    inspect = function(d)
        local s = "Latching: " .. tostring(d.on) .. "\nStored val: " .. d.latched
        if d.to >= 0 then
            s = s .. ("\nReset in: %.3f"):format(d.to)
        end
        return s
    end,
    update = function(d, node, dt)
        if d.timof and not d.on and d.to >= 0 then
            d.to = d.to - dt
            if d.to <= 0 then
                d.latched = 0
            end
        end
    end
}

-- cn save x=expr latchcond
-- Latches and stores value when latchcond is true, otherwise returns stored value.
-- The value is stored to the save file and persists across map loads.
-- (Note: Moving or changing the text of the node will forget the saved value,
-- keep that in mind for compatibility across savegames)
M.save =
{
    init = function(d, node, ...)
        local outexpr, condexpr = ...
        local q, cond = condition(condexpr)
        local x = compileExpr(outexpr)
        d.var = assert(x.var, "first latch expr must set a variable")
        d.f = x.f
        d.latched = node_getFlag(node)
        d.check = cond
        d.to = 0
        return configureEvalK(x.var, kunion(x.referenced, q.referenced))
    end,
    eval = function(d, node, _in, _out)
        local val
        local on = d.check(_in, _out)
        d.on = on
        if on then
            val = assert(d.f(_in, _out))
            if d.latched ~= val then
                node_setFlag(node, val)
                d.latched = val
            end
        else
            val = d.latched
            _out[d.var] = val
        end
        return val
    end,
    inspect = function(d)
        local s = "Latching: " .. tostring(d.on) .. "\nSaved val: " .. d.latched
        return s
    end,
}

-- cn countdown t=expr resetexpr [speed=1]
M.countdown =
{
    init = function(d, node, ...)
        local beginexpr, resetexpr, speed = ...
        local beg = compileExpr(beginexpr)
        local res, isreset = condition(resetexpr) 
        d.var = assert(beg.var, "first latch expr must set a variable")
        d.beginf = assert(beg.f)
        d.counter = 0
        d.speed = tonumber(speed) or 1
        d.isreset = assert(isreset, "need reset condition")
        return configureEvalK(beg.var, kunion(beg.referenced, res.referenced))
    end,
    eval = function(d, node, _in, _out)
        local val
        local reset = d.isreset(_in, _out)
        d.reset = reset
        if reset then
            val = d.beginf(_in, _out)
            d.counter = val
        else
            val = d.counter
            _out[d.var] = val
        end
        return val
    end,
    inspect = function(d)
        local s = ("Counter: %.4f"):format(d.counter)
              .. "\nReset: " .. tostring(d.reset)
              .. ("\nSpeed: %f"):format(d.speed)
        return s
    end,
    update = function(d, node, dt)
        if not d.reset then
            if d.counter > 0 then
                d.counter = d.counter - (dt * d.speed)
                if d.counter <= 0 then
                    d.counter = 0
                end
            elseif d.counter < 0 then
                d.counter = d.counter + (dt * d.speed)
                if d.counter >= 0 then
                    d.ounter = 0
                end
            end
        end
    end
}

-- cn countup t=expr activeexpr [speed=1]
M.countup =
{
    init = function(d, node, ...)
        local beginexpr, whileexpr, speed = ...
        local beg = compileExpr(beginexpr)
        local res, ison = condition(whileexpr) 
        d.var = assert(beg.var, "first expr must set a variable")
        d.beginf = assert(beg.f)
        d.counter = 0
        d.speed = tonumber(speed) or 1
        d.ison = assert(ison, "need on-condition")
        d.startval = 0
        d.on = false
        return configureEvalK(beg.var, kunion(beg.referenced, res.referenced))
    end,
    eval = function(d, node, _in, _out)
        local val
        local on = d.ison(_in, _out)
        d.on = on
        if on then
            val = d.beginf(_in, _out)
            d.startval = val
            val = toint(val + d.counter)
        else
            val = 0
            d.counter = 0
        end
        _out[d.var] = val
        return val
    end,
    update = function(d, node, dt)
        if d.on then
            d.counter = d.counter + dt * d.speed
        end
    end,
    inspect = function(d)
        local s = ("Val: %.4f + %.4f\nActive: %s"):format(d.startval, d.counter, tostring(d.on))
        return s
    end,
}

-- cn maptime VAR [speed]
M.maptime =
{
    init = function(d, node, target, mul)
        assert(target, "need target")
        local x, numf = exprOrNum(mul, 1)
        local function f(_in)
            return getMapTime() * numf(_in)
        end
        return kunion(x, evalCallback(target, f))
    end,
}


local function findSwitch(e)
    if egetv(e, EV_TYPEID) == EVT_ACTIVATOR then
        return e
    end
end
M.readswitch =
{
    init = function(d, node, ...)
        local switch = node_forAllEntitiesWithin(node, findSwitch) or 0
        d.switch = switch
        local var, xx = ...
        if xx then
            warnLog("cn readswitch: Extraneous expr ignored: " .. xx)
        end
        if switch ~= 0 then
            local function isSwitchOn()
                return entity_isState(switch, STATE_ON)
            end
            return evalCallback(var, isSwitchOn)
        end
    end,
    inspect = function(d)
        if d.switch ~= 0 then
            return "My switch: " .. entity_getName(d.switch) .. " (id: " .. entity_getID(d.switch) .. ")"
            .. "\nOn: " .. tostring(entity_isState(d.switch, STATE_ON))
        end
        return "No switch found!"
    end,
}

-- cn setswitch expr [latchcond]
M.setswitch =
{
    init = function(d, node, ...)
        local switch = node_forAllEntitiesWithin(node, findSwitch) or 0
        d.switch = switch
        local expr, latchcond, xx = ...
        if xx then
            warnLog("cn setswitch: Extraneous expr ignored: " .. xx)
        end
        local x, isactive = condition(expr)
        local latchx, islatch
        if latchcond then
            latchx, islatch = condition(latchcond)
        end
        d.isactive = isactive
        d.islatch = islatch
        return kunion(x, latchx)
    end,
    update = function(d, node, dt, _in, _out)
        local latch = true -- latch if no expr present
        if d.islatch then
            latch = d.islatch(_in, _out)
        end
        d.latchstate = latch -- for debugging only
        if latch then
            local on = d.isactive(_in, _out)
            d.on = on
            if d.switch ~= 0 then
                local targetstate = (d.on and STATE_ON) or STATE_OFF
                if not entity_isState(d.switch, targetstate) then
                    entity_setState(d.switch, targetstate)
                end
            end
        end
    end,
    inspect = function(d)
        if d.switch ~= 0 then
            return "My switch: " .. entity_getName(d.switch) .. " (id: " .. entity_getID(d.switch) .. ")"
            .. "\nSet to: " .. tostring(d.on)
            .. "\nLatching: " .. ((d.islatch and tostring(d.latchstate)) or "always")
        end
        return "No switch found!"
    end,
}

-- TODO activate node
-- TODO set node on/off

-- TODO: node that sets water level
-- TODO: node that gets water level
-- TODO: node that reports own position as x, y
-- TODO: barrier (make it use the door api?) -- but they are nodes now, no longer entities

-- TODO: hide/show map tiles with tags

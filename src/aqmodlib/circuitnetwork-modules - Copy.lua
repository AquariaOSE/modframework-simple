--[[
Notation:

<varname>  -- angle brackets for variable names (description inside the bracket)

---== IMPLEMENTED FUNCTIONS ==---

cn max <target> <inputs...>
cn min <target> <inputs...>


]]

local M = assert(circuitnetwork.modules)
local splitexpr = assert(circuitnetwork.splitexpr)
local compile_v = assert(circuitnetwork.compileexpr_v)

local getFirstEntity = getFirstEntity
local getNextEntity = getNextEntity

M["playerin"] =
{
    init = function(d, node, target)
        assert(target, "need target")
        d.target = target
    end,
    -- called to produce values
    eval = function(d, node, vals)
        vals[d.target] = node_isEntityIn(node, getNaija())
    end,
}

-- cn count j=jelly d=energydoor
M.count =
{
    init = function(d, node, ...)
        local t, n = table.pack2(...)
        if n > 0 then
            local as, check = {}, {}
            for i = 1, n do
                local dst, rest = splitexpr(t[i])
                as[rest] = dst
            end
            d.f = function(e, vals) -- assign specific var=entity mode
                local dst = as[entity_getName(e):lower()]
                if dst then
                    vals[dst] = (vals[dst] or 0) + 1
                end
            end
        else
            d.f = function(e, vals) -- wildcard mode -- every entity name becomes a variable
                local k = entity_getName(e):lower()
                vals[k] = (vals[k] or 0) + 1
            end
        end
    end,
    eval = function(d, node, vals)
        node_forAllEntitiesWithin(node, d.f, vals)
    end,
}

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
        d.expridx = compile_v(d, ...) -- TODO
        d.dbgword = "???"
    end,
    assign = function(d, xlat)
        d.expridx = xlat[d.expridx]
    end,
    update = function(d, node, vals, dt)
        local open = vals[d.expridx] > 0
        d.dbgword = open and "open" or "closed"
        local door = d.door
        local state = entity_getState(door)
        if open then
            if not (state == STATE_OPENED or state == STATE_OPEN) then
                entity_setState(door, STATE_OPEN)
            end
        else
            if not (state == STATE_CLOSED or state == STATE_CLOSE) then
                entity_setState(door, STATE_CLOSE)
            end
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

-- cn latch x=expr latchexpr
M.latch =
{
    init = function(d, node, ...)
        local latch, val = ...
        d.latchexpr = compile_v(d, latch) -- TODO: compile single, return var name
        d.valexpr = compile_v(d, val)
        d.latched = 0
    end,
    assign = function(d, xlat)
        d.latchexpr = xlat[d.latchexpr]
        d.valexpr = xlat[d.valexpr]
    end,
    eval = function(d, node, vals)
        local val = vals[d.valexpr]
        if vals[d.latchexpr] > 0 then
            d.latched = val
        end
        vals[d.valexpr] = max(val, d.latched)
    end,
}

-- Standalone script -- no library dependencies!

-- Place this node somewhere to store the orb that's in it.
-- Upon map load, if an orb was stored, move it to the node.
-- Put "saveorb c" to also store the orb's charge status.

local CHO = 100000

v.once = true
v.lastOrb = false

local function restoreOrb(me)
    local f = node_getFlag(me)
    if f == 0 then
        return
    end
    
    local orb = 0
    local charged
    if f > 0 then
        charged = f >= CHO
        if charged then
            f = f - CHO
        end
        orb = getEntityByID(f)
    else -- orb was a temporary entity, spawn one
        charged = f == -2
        orb = v.lastOrb or createEntity("energyorb")
    end
    --errorLog("orb " .. entity_getID(orb) .. " charged " .. tostring(charged))
    
    if orb ~= 0 then
        entity_setPosition(orb, node_getPosition(me))
        if charged then
            local a = node_getContent(me)
            if a == "c" then
                if not entity_isState(orb, STATE_CHARGED) then
                    entity_setState(orb, STATE_CHARGED)
                end
            end
        end
    end
    
    v.lastOrb = orb
end

function init(me)
    restoreOrb(me)
end

function update(me)
    if v.once then
        v.once = false
        restoreOrb(me) -- twice, yes
    end
    --local orb = node_getNearestEntityWithEVT(me, -1, EVT_ORB)
    local orb = node_getNearestEntity(me, "energyorb")
    local id = 0
    if orb ~= 0 and node_isEntityIn(me, orb) then
        id = entity_getID(orb)
        local charged = entity_isState(orb, STATE_CHARGED)
        if id > 0 then -- don't save temporary entities
            if charged then
                id = id + CHO
            end
        elseif charged then
            id = -2
        else
            id = -1
        end
    end
    node_setFlag(me, id)
end

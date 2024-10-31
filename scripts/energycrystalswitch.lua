-- works with node: [cra TARGETNODE on]
-- where on can be: -1: always off, 0: initially off, 1: initially on, 2: always on (where always means everytime the map is loaded - won't be saved!)
v.accu = 0
v.q = 0
v.q2 = 0
v.on = false
v.node = 0
v.ignoreT = 0
v.save = false

local sin = math.sin
local clamp = math.clamp

local function setOn(me, on, ...)
    --debugLog("energycrstalswitch: set on: " .. tostring(on))
    v.on = on
    if on then
        quad_alpha(v.q, 0.3)
        quad_alpha(v.q, 0.7, 1, -1, 1, 1)
        quad_alpha(v.q2, 0.2)
        quad_alpha(v.q2, 0.5, 1, -1, 1, 1)
    else
        quad_alpha(v.q, 0)
        quad_alpha(v.q2, 0)
    end
    
    --node_activate(v.node, me)
    if v.node ~= 0 then
        node_msg(v.node, "seton", on, ...)
    end
    
    if v.save then
        entity_setFlag(me, on, "on")
    end
    
    local targetState = (on and STATE_ON) or STATE_OFF
    
    if not entity_isState(me, targetState) then
        entity_setState(me, targetState)
    end
end

function init(me)
    setupEntity(me, "white-crystal-0002", -2)
    entity_setCollideRadius(me, 50)
    
    esetv(me, EV_TYPEID, EVT_ACTIVATOR)
    entity_setEntityType(me, ET_ENEMY)
    entity_scale(me, 0.6, 0.5)
    
    v.q = createQuad("softglow-add")
    quad_setBlendType(v.q, BLEND_ADD)
    quad_setPosition(v.q, entity_getPosition(me))
    quad_scale(v.q, 1.3, 1.3)
    quad_scale(v.q, 2, 2, 1, -1, 1, 1)
    
    v.q2 = createQuad("softglow-add", 13)
    quad_setBlendType(v.q2, BLEND_ADD)
    quad_setPosition(v.q2, entity_getPosition(me))
    quad_scale(v.q2, 1.3, 1.3)
    quad_scale(v.q2, 2, 2, 1, -1, 1, 1)
end

function postInit(me)
    local on = false
    local cra = entity_getNearestNode(me, "cra")
    if node_isEntityIn(cra, me) then
        v.node = node_getNearestNode(cra, node_getContent(cra))
        if v.node == 0 then
            warnLog("energycrystalswitch: cra node specifies [" .. node_getContent(cra) .. "] which was not found")
        end
        on = node_getAmount(cra)
        
        if on == -1 then
            on = false
        elseif on == 0 then
            on = entity_getFlag(me, "on")
            if on == nil then on = false end
            v.save = true
        elseif on == 1 then
            on = entity_getFlag(me, "on")
            if on == nil then on = true end
            v.save = true
        elseif on == 2 then
            on = true
        else
            warnLog("energycrystalswitch: cra node specifies on = " .. node_getAmount(cra) .. ", this is not handled")
        end
    end
    setOn(me, on, true)
end

function update(me, dt)
    local cs, cv
    if v.on then
        v.accu = v.accu + dt * 2
        cs = ((sin(v.accu) * 0.2) + 0.5) * clamp(v.accu, 0, 1)
        cv = 0.9
    else
        v.accu = 0
        cs = 0
        cv = 0.2
    end
    local r, g, b = color_HSVtoRGB(0.1*360, cs, cv)
    entity_color(me, r, g, b, 0.2)
    quad_color(v.q, r, g, b, 0.2)
    quad_color(v.q2, r, g, b, 0.2)
    
    v.ignoreT = v.ignoreT - dt
    entity_handleShotCollisions(me)
end

function damage(me, attacker, bone, damageType, dmg)
    if v.ignoreT > 0 then
        debugLog("energycrstalswitch: ignored damage due to timer")
        return false
    end
    
    --if damage_isGroup(damageType, DG_ENERGY_ACTIVATE) then
    if damageType == DT_AVATAR_ENERGYBLAST then
        debugLog("energycrstalswitch: toggle!")
        v.ignoreT = 0.6
        local on = not v.on
        setOn(me, on)
    else
        debugLog("energycrstalswitch: not energy damage: " .. damageType)
        playNoEffect()
    end
    return false
end

function msg(me, s, x, ...)
    if s == "seton" then
        setOn(me, x or false, ...)
    end
end

function enterState(me)
    local state = entity_getState(me)
    local setTo
    if state == STATE_ON then
        setTo = true
    elseif state == STATE_OFF then
        setTo = false
    end
    if setTo ~= nil then
        setOn(me, setTo)
    end
end

function exitState(me)
end

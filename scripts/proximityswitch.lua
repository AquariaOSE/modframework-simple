v.on = false
v.charge = 0
v.q = 0
v.q2 = 0
v.accu = 0
v.lamp = 0 -- bone
v.dbgq = 0

local ACTIVATION_RANGE = 220
local CHARGE_TIME = 1.5

v.range = ACTIVATION_RANGE

local sin = math.sin
local max = math.max
local clamp = math.clamp

local function _updateState(me)
    local on = entity_isState(me, STATE_ON)
    debugLog("proximityswitch: set on: " .. tostring(on))
    v.on = on
    if on then
        bone_color(v.lamp, 0.3, 0.8, 1, 0.3)
        --[[quad_alpha(v.q, 0.3)
        quad_alpha(v.q, 0.7, 1, -1, 1, 1)
        quad_alpha(v.q2, 0.2)
        quad_alpha(v.q2, 0.5, 1, -1, 1, 1)]]

    else
        bone_color(v.lamp, 0.7, 0.4, 0.1, 0.3)
        --quad_alpha(v.q, 0)
        --quad_alpha(v.q2, 0)
    end
end

local function setOn(me, on)
    local targetState = (on and STATE_ON) or STATE_OFF
    if not entity_isState(me, targetState) then
        entity_setState(me, targetState)
    end
end

function init(me)
    setupEntity(me, "", -2)
    entity_initSkeletal(me, "mithalas-lamp")
    entity_setCollideRadius(me, 50)
    
    esetv(me, EV_TYPEID, EVT_ACTIVATOR)
    entity_setEntityType(me, ET_NEUTRAL)
    entity_scale(me, 0.33, 0.33)
    
    v.q = createQuad("softglow-add")
    quad_setBlendType(v.q, BLEND_ADD)
    --quad_scale(v.q, 1.3, 1.3)
    --quad_scale(v.q, 2, 2, 1, -1, 1, 1)
    quad_scale(v.q, 5, 5)
    
    v.q2 = createQuad("softglow-add", 13)
    quad_setBlendType(v.q2, BLEND_ADD)
    --quad_scale(v.q2, 1.3, 1.3)
    --quad_scale(v.q2, 2, 2, 1, -1, 1, 1)
    quad_scale(v.q2, 5, 5)
    
    entity_animate(me, "idle")
    entity_updateSkeletal(me, 1)
    
    v.lamp = entity_getBoneByIdx(me, 1)
    
    quad_alpha(v.q, 0.6)
    quad_alpha(v.q, 0.7, 1, -1, 1, 1)
    quad_alpha(v.q2, 0.4)
    quad_alpha(v.q2, 0.5, 1, -1, 1, 1)
    
    if MOD_DEVMODE then
        local x, y = entity_getPosition(me)
        local q = debugShowRange(x, y, v.range, false)
        quad_color(q, 1, 1, 0)
        quad_alphaMod(q, 0.3)
        v.dbgq = q
    end
end

function postInit(me)
    setOn(me, false)
end

local function isTriggerEntity(e, me)
    if eisv(e, EV_TYPEID, EVT_HUMANOID) then -- who can activate the switch?
        return e
    end
end

local function isEntityNearby(me)
    return entity_isEntityInRange(me, getNaija(), v.range)
        --or entity_forAllEntitiesInRange(me, v.range, isTriggerEntity, me)
    -- ^ comment this in to allow other entities to trigger the switch
end

function update(me, dt)
    local x, y = entity_getPosition(me)
    quad_setPosition(v.q, x, y)
    quad_setPosition(v.q2, x, y)
    if v.dbgq ~= 0 then
        quad_setPosition(v.dbgq, x, y)
    end
    
    
    local cs, cv
    local amod, on
    --[[if isEntityNearby(me) then
        v.charge = v.charge + dt
    else
        v.charge = max(v.charge - 2*dt, 0)
    end
    if v.charge < CHARGE_TIME then]]
    if not isEntityNearby(me) then
        amod = rangeTransformClamp(v.charge, 0, CHARGE_TIME, 0.4, 0.7)
    else
        amod = 1
        on = true
    end
        
    if v.on then
        v.accu = v.accu + dt * 2
        cs = ((sin(v.accu) * 0.2) + 0.5) * clamp(v.accu, 0, 1)
        cv = 0.9
    else
        v.accu = 0
        cs = 0
        cv = 0.4
    end
    local r, g, b = color_HSVtoRGB(0.5*360, cs, cv)
    quad_color(v.q, r, g, b, 0.2)
    quad_color(v.q2, r, g, b, 0.2)
    quad_alphaMod(v.q, amod)
    quad_alphaMod(v.q2, amod)
    
    if v.on ~= on then
        setOn(me, on)
    end
end

function damage(me, attacker, bone, damageType, dmg)
    return false
end

function enterState(me, state)
    local setTo
    if state == STATE_ON then
        setTo = true
    elseif state == STATE_OFF then
        setTo = false
    end
    if setTo ~= nil then
        setOn(me, setTo)
    end
    _updateState(me)
end

function exitState(me)
end

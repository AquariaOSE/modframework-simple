local EFFECT_RANGE = 1800

v.dist = 0
v.speed = 0
v.sound = false
v.closeSound = false
v.qopen = 0
v.qclosed = 0
v.initx, v.inity = 0, 0

local function getOpenPos(me)
    local dx, dy = vector_fromDeg(entity_getRotation(me), v.dist)
    local ix, iy = v.initx, v.inity
    return ix + dx, iy + dy
end

local function createOverlay(me, x, y)
    local q = createQuad("debugbox")
    quad_setWidth(q, entity_getWidth(me))
    quad_setHeight(q, entity_getHeight(me))
    quad_rotate(q, entity_getRotation(me))
    quad_scale(q, entity_getScale(me))
    quad_setPosition(q, x, y)
    quad_setLayer(q, LR_PROGRESS)
    return q
end

function v.commonInit(me, tex, snd, sz, flipDir, speed, dist, closeSound)
    sz = sz or 1
    v.initx, v.inity = entity_getPosition(me)
    setupEntity(me, tex, -2)
    entity_scale(me, sz, sz)
    entity_setActivationType(me, AT_NONE)
    entity_setFillGrid(me, true)
    entity_setAllDamageTargets(me, false)
    entity_setUpdateCull(me, -1)
    entity_setEntityType(me, ET_NEUTRAL)
    esetv(me, EV_TYPEID, EVT_DOOR)
    --esetv(me, EV_LOOKAT, 0)
    v.sound = snd
    v.closeSound = closeSound
    loadSound(snd)
    loadSound(closeSound)
    v.speed = speed or 2
    v.dist = dist or 700
    if flipDir then
        if type(flipDir) == "number" then
            warnLog("flipDir is number -- deprecated")
        end
        v.dist = -v.dist
    end
    
    if MOD_DEVMODE then
        v.qclosed = createOverlay(me, v.initx, v.inity)
        quad_color(v.qclosed, 1, 0, 0)
        v.qopen = createOverlay(me, getOpenPos(me))
        quad_color(v.qopen, 0.3, 1, 0.5)
    end
end

function v.commonUpdate(me, dt)
    local state = entity_getState(me)
    local moving = state == STATE_OPEN or state == STATE_CLOSE
    
    if moving then
        reconstructEntityGrid()
        if not entity_isInterpolating(me) then
            if state == STATE_OPEN then
                entity_setState(me, STATE_OPENED)
            elseif state == STATE_CLOSE then
                entity_setState(me, STATE_CLOSED)
            end
        end
    end
    
    if v.qopen ~= 0 then
        local r = entity_getRotation(me)
        quad_setPosition(v.qclosed, v.initx, v.inity)
        quad_setPosition(v.qopen, getOpenPos(me))
        quad_rotate(v.qopen, r)
        quad_rotate(v.qclosed, r)
    end
end

local function shake(me)
    if entity_isEntityInRange(me, getNaija(), EFFECT_RANGE) then
        shakeCamera(4, 1)
    end
    entity_playSfx(me, v.closeSound, nil, 2, nil, nil, 4000)
end

function enterState(me)
    local state = entity_getState(me)
    if state == STATE_OPEN or state == STATE_CLOSE then
       -- debugLog("door: open or close, play sfx")
        entity_playSfx(me, v.sound, nil, nil, nil, nil, 3000)
        if state == STATE_OPEN then
            --debugLog("door: open slowly")
            local dx, dy = getOpenPos(me)
            entity_setPosition(me, dx, dy, v.speed)
        elseif state == STATE_CLOSE then
            --debugLog("door: close slowly")
            local ix, iy = v.initx, v.inity
            entity_setPosition(me, ix, iy, v.speed)
        end
    else
        local prev = entity_getPrevState(me)
        if state == STATE_CLOSED then
            entity_setPosition(me, v.initx, v.inity)
            if prev == STATE_CLOSE then
                shake(me)
            end
        elseif state == STATE_OPENED then
            entity_setPosition(me, getOpenPos(me))
            if prev == STATE_OPEN then
                shake(me)
            end
        end
    end
    reconstructEntityGrid()
end

function exitState(me)
end

function damage(me)
    return false
end

msg = doorhelper_handleMsg

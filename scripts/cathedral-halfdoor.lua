local EFFECT_RANGE = 1000

v.dist = 0
v.speed = 0
v.sound = false
v.closeSound = false

function init(me)
    setupEntity(me, "", -2)
    entity_initSkeletal(me, "cathedral-halfdoor")
    --entity_scale(me, sz, sz)
    --entity_setActivationType(me, AT_NONE)
    entity_setFillGrid(me, false, 2)
    entity_setAllDamageTargets(me, false)
    entity_setUpdateCull(me, -1)
    entity_setEntityType(me, ET_NEUTRAL)
    esetv(me, EV_TYPEID, EVT_DOOR)
    esetv(me, EV_LOOKAT, 0)
    v.sound = "" --snd
    v.closeSound = "" --closeSound
    loadSound(v.sound)
    loadSound(v.closeSound)
    entity_setState(me, STATE_CLOSED)
    entity_animate(me, "idle", 0, 0, -1)
end

function postInit(me)
    local x, y = entity_getPosition(me)
    -- the door tile collision leaves some free space where both halves meet;
    -- insert a filler to make sure it's really closed
    v.filler = createEntity("filler", "", x, y)
    -- yeeeah doesn't work, the fill grid function tries to respect width/height but actually messes it up
    --entity_setWidth(v.filler, TILE_SIZE * 5)
    --entity_setHeight(v.filler, TILE_SIZE * 5)
    entity_scale(v.filler, 2.5, 2.5) -- this is fine

    reconstructEntityGrid()
end

function update(me, dt)
    local state = entity_getState(me)
    local moving = state == STATE_OPEN or state == STATE_CLOSE
    
    if moving then
        if not entity_isAnimating(me) then
            if state == STATE_OPEN then
                entity_setState(me, STATE_OPENED)
            elseif state == STATE_CLOSE then
                entity_setState(me, STATE_CLOSED)
            end
        end
        reconstructEntityGrid()
    end
    
    entity_setPosition(v.filler, entity_getPosition(me))
end

local function shake(me)
    if entity_isEntityInRange(me, getNaija(), EFFECT_RANGE) then
        shakeCamera(1, 1)
    end
    entity_playSfx(me, v.closeSound, nil, 2, nil, nil, 4000)
end

function enterState(me)
    local state = entity_getState(me)
    local fillerstate = STATE_DISABLED
    local t
    if state == STATE_OPEN or state == STATE_CLOSE then
        entity_playSfx(me, v.sound, nil, nil, nil, nil, 3000)
        local ct = entity_isAnimating(me) and entity_getAnimationTime(me)
        if state == STATE_OPEN then
            t = entity_animate(me, "open", 0, 0, -1) -- no transition
        elseif state == STATE_CLOSE then
            t = entity_animate(me, "close", 0, 0, -1)
        end
        if ct then
            -- when partially on the way already, go back to where it was but in the reversed direction
            -- needs no transition and both animations to be the same length to look right
            entity_setAnimationTime(me, math.clamp(t - ct, 0, t))
        end
    else
        local prev = entity_getPrevState(me)
        if state == STATE_CLOSED then
            fillerstate = STATE_IDLE
            entity_animate(me, "idle", 0, 0, -1)
            if prev == STATE_CLOSE then
                shake(me)
            end
        elseif state == STATE_OPENED then
            entity_animate(me, "opened", 0, 0, -1)
            if prev == STATE_OPEN then
                shake(me)
            end
        end
    end
    entity_setState(v.filler, fillerstate)
    reconstructEntityGrid()
    
    if t then
        entity_setStateTime(me, t)
    end
end

function exitState(me)
    local state = entity_getState(me)
    if state == STATE_OPEN then
        entity_setState(me, STATE_OPENED)
    elseif state == STATE_CLOSE then
        entity_setState(me, STATE_CLOSED)
    end
end

msg = doorhelper_handleMsg

function damage(me)
    return false
end

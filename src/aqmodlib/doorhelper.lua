-- little helper to manage door state because door states are actually annoying
-- and i don't want to duplicate this into every script that handles doors

-- to be called externally to control doors
local function doorhelper_setState(door, state, fast)
    state = state or false
    if type(state) == "boolean" then
        if fast == nil then
            fast = getMapTime() < 0.2
        end
    elseif state == STATE_OPEN or state == STATE_OPENED then
        if state == STATE_OPENED then
            fast = true
        end
        state = true
    elseif state == STATE_CLOSE or state == STATE_CLOSED then
        if state == STATE_CLOSED then
            fast = true
        end
        state = false
    else
        assert(false, state)
    end
    
    local ok = entity_msg(door, "doorcontrol", state, fast) -- always send bool how the door should be
    if ok ~= nil then
        return ok
    end
    
    -- door didn't acknowledge it, do it the hard/oldschool/legacy way
    local curstate = entity_getState(door)
    local newstate

    if state then
        if not (curstate == STATE_OPENED or curstate == STATE_OPEN) then
            newstate = (fast and STATE_OPENED) or STATE_OPEN
        end
    else
        if not (curstate == STATE_CLOSED or curstate == STATE_CLOSE) then
            newstate = (fast and STATE_CLOSED) or STATE_CLOSE
        end
    end
    
    if newstate and newstate ~= curstate then
        entity_setState(door, newstate)
    end
end

-- nil if nothing to do, one of the states otherwise
-- to be called by doors to figure out their intended state
local function doorhelper_getTargetState(door, open, fast)
    local curstate = entity_getState(door)
    local newstate
    if fast then
        newstate = (open and STATE_OPENED) or STATE_CLOSED
    else
        if open and curstate ~= STATE_OPENED then
            newstate = STATE_OPEN
        elseif not open and curstate ~= STATE_CLOSED then
            newstate = STATE_CLOSE
        end
    end
    if newstate ~= curstate then
        return newstate -- possibly nil
    end
end

-- returns bool, state
-- false if fully closed, true if opening/closing
-- state is one of STATE_OPEN, STATE_CLOSED, STATE_OPENING, STATE_CLOSING if the extra info is needed
local function doorhelper_getState(door)
    local state = entity_getState(door)
    local somewhatopen = state ~= STATE_CLOSED
    return somewhatopen, state
end

local function doorhelper_open(door)
    doorhelper_setstate(door, false)
end

local function doorhelper_close(door)
    doorhelper_setstate(door, true)
end

local function doorhelper_handleMsg(me, s, ...)
    if s == "doorcontrol" then
        local state = doorhelper_getTargetState(me, ...)
        if state then
            entity_setState(me, state)
        end
        return true
    end
end

return {
    doorhelper_getTargetState = doorhelper_getTargetState,
    doorhelper_setState = doorhelper_setState,
    doorhelper_getState = doorhelper_getState,
    doorhelper_open = doorhelper_open,
    doorhelper_close = doorhelper_close,
    doorhelper_handleMsg = doorhelper_handleMsg,
}

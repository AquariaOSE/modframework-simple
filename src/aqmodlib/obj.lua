
-- used as an alternative to bonelocking where it's not viable
-- also supports non-entities
local function obj_getStuckIn(me, inwho, bone, timeout)
    local x, y = obj_getPosition(me)
    local r = obj_getRotation(me)
    
    local lock = { inwho = inwho }
    obj_addDeathNotify(me, inwho)
    local lx, ly, lrot, fh
    if not isBone(bone) then
        lx, ly = obj_getPosition(inwho)
        lrot = obj_getRotation(inwho)
        fh = obj_isfh(inwho)
    else
        lx, ly, lrot = bone_getWorldPositionAndRotation(bone)
        fh = bone_isfhr(bone)
        lock.bone = bone
        obj_addDeathNotify(me, bone)
    end
    lock.addx, lock.addy = makeVector(lx, ly, x, y)
    lock.addrot = r - lrot
    lock.startrot = lrot
    lock.t = timeout
    lock.fh = fh
    return lock
end

local function obj_updateStuckIn(me, lock, dt)
    local x, y, r, fh
    local bone = lock.bone -- nil if not used
    if bone then
        x, y, r = bone_getWorldPositionAndRotation(bone)
        fh = bone_isfhr(bone)
    else
        local inwho = lock.inwho
        x, y = obj_getPosition(inwho)
        r = obj_getRotation(inwho)
        fh = obj_isfh(inwho)
    end
    
    local t = lock.t
    if t then
        t = t - dt
        lock.t = t
        if t <= 0 then
            return false
        end
    end
    if lock.fh ~= fh then
        return false
    end
    
    local rotdiff = r - lock.startrot
    local ax, ay = vector_rotateDeg(lock.addx, lock.addy, rotdiff)
    entity_setPosition(me, x + ax, y + ay)
    entity_rotate(me, r + lock.addrot)
    return true
end

return {
    obj_getStuckIn = obj_getStuckIn,
    obj_updateStuckIn = obj_updateStuckIn,
}

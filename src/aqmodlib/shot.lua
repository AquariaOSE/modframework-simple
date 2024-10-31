
local lerp2 = math.lerp2
local shot_getDamageType = shot_getDamageType
local vector_normalize = vector_normalize
local getFirstShot = getFirstShot
local getNextShot = getNextShot
local getNextFilteredShot = getNextFilteredShot
local filterNearestShots = filterNearestShots
local shot_getInternalVel = shot_getInternalVel
local shot_getPosition = shot_getPosition
local entity_getPosition = entity_getPosition
    
local function forAllShots(f, param, filter, fparam)
    local s = getFirstShot()
    local nx = getNextShot
    if not filter then
        while s ~= 0 do
            if f(s, param) == true then
                return true
            end
            s = nx()
        end
    elseif type(filter) == "string" then
        while s ~= 0 do
            if shot_getName(s) == filter then
                if f(s, param) == true then
                    return true
                end
            end
            s = nx()
        end
    else
        while s ~= 0 do
            if filter(s, fparam) then
                if f(s, param) == true then
                    return true
                end
            end
            s = nx()
        end
    end
    return false
end

local function forAllShots2(f, ...)
    local s = getFirstShot()
    local nx = getNextShot
    while s ~= 0 do
        if f(s, ...) == true then
            return true
        end
        s = nx()
    end
    return false
end

-- generic. stops the iteration if function returns something non-false, then also returns that.
-- leave distance away/0/nil to iterate over all shots sorted by distance.
local function forAllShotsInRange(x, y, distance, f, ...)
    if filterNearestShots(x, y, distance) == 0 then
        return
    end
    local nx = getNextFilteredShot
    local s = nx()
    local ret
    while s ~= 0 do
        ret = f(s, ...)
        if ret then
            return ret
        end
        s = nx()
    end
end

local function getNearestShotOfDamageType(x, y, distance, ...) -- list of DT_*
    if filterNearestShots(x, y, distance) == 0 then
        return 0
    end
    local nargs = select("#", ...)
    local nx = getNextFilteredShot
    local s = nx()
    while s ~= 0 do
        for i = 1, nargs do
            if shot_getDamageType(s) == select(i, ...) then
                return s
            end
        end
        s = nx()
    end
    return 0
end

local function shot_calculateSmartAimVectorToEntity(s, target, ratio)
    local sx, sy = shot_getPosition(s)
    local x, y = entity_getPosition(target)
    local svx, svy = shot_getInternalVel(s)
    local vx, vy = entity_getVel(target)
    
    local tx, ty = makeVector(sx, sy, x, y)
    shot_setAimVector(s, tx, ty) -- sets vel
    
    local a = getInterceptAngle(sx, sy, svx, svy, x, y, vx, vy)
    --debugLog("aim: " .. tostring(a) .. "; vel: " .. vx .. ", " .. vy)
    if not a then
        debugLog("shot_smartAimAtEntity: got nil aim")
        shot_setAimVector(s, tx, ty)
        return false
    end
    local ax, ay = vector_fromDeg(a)
    if ratio then
        ax, ay = lerp2(tx, ty, ax, ay, ratio)
    end
    
    if isDebug() then
        isLineObstructed(sx, sy, sx + ax, sy + ay, "awesomedebug")
    end
    return ax, ay
end

local function shot_smartAimAtEntity(s, target, ratio)
    local ax, ay = shot_calculateSmartAimVectorToEntity(s, target, ratio)
    if ax then
        shot_setAimVector(s, ax, ay)
        return true
    end
    return false
end

-- base damage, extra damage
local function shot_getDamageDetail(s)
    local total = shot_getDamage(s)
    local extra = shot_getExtraDamage(s)
    return total, extra, total - extra
end

local function shot_setTotalDamage(s, newdamage)
    local total, extra, base = shot_getDamageDetail(s)
    local remain = newdamage - base
    return shot_setExtraDamage(s, remain)
end


local function entity_shotIsTowardsMe(me, s, mindot) -- mindot: -1 = totally away from me, 0: perpendicular, 1: directly towards me
    local vx, vy = shot_getInternalVel(s)
    local sx, sy = shot_getPosition(s)
    local dx, dy = makeVector(sx, sy, entity_getPosition(me))
    if not mindot then
        return dx*vx + dy*vy > 0
    end
    
    vx, vy = vector_normalize(vx, vy)
    dx, dy = vector_normalize(dx, dy)
    return dx*vx + dy*vy >= mindot
end

local function _entity_getNearestDamagingShotTowardsMe_helper(s, me, mindot)
    --return entity_isDamageTarget(me, shot_getDamageType(s)) and entity_shotIsTowardsMe(me, s) and s
    return entity_shotIsTowardsMe(me, s) and shot_canHitEntity(s, me) and s -- note that this calls entity's canShotHit() interface function
end
local function entity_getNearestDamagingShotTowardsMe(me, distance, mindot)
    local x, y = entity_getPosition(me)
    return forAllShotsInRange(x, y, distance, _entity_getNearestDamagingShotTowardsMe_helper, me, mindot) or 0
end

-- this is to check for trigger shots, eg. those used by urchin costume or spears
local function shot_isRegularShot(s)
    return shot_isVisible(s) and shot_getLifeTime(s) > 0.2
end

return {
    forAllShots = forAllShots,
    forAllShots2 = forAllShots2,
    forAllShotsInRange = forAllShotsInRange,
    getNearestShotOfDamageType = getNearestShotOfDamageType,
    shot_smartAimAtEntity = shot_smartAimAtEntity,
    shot_getDamageDetail = shot_getDamageDetail,
    shot_setTotalDamage = shot_setTotalDamage,
    entity_shotIsTowardsMe = entity_shotIsTowardsMe,
    entity_getNearestDamagingShotTowardsMe = entity_getNearestDamagingShotTowardsMe,
    shot_calculateSmartAimVectorToEntity = shot_calculateSmartAimVectorToEntity,
    shot_isRegularShot = shot_isRegularShot,
}

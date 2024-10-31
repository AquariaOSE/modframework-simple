local type = type
local tins = table.insert

local entity_getPosition = entity_getPosition
local entity_getEntityType = entity_getEntityType
local egetv = egetv
local EV_TYPEID = EV_TYPEID
local entity_isfh = entity_isfh
local getNextFilteredEntity = getNextFilteredEntity
local entity_getLayer = entity_getLayer
local entity_getRiding = entity_getRiding
local LR_ENTITIES = LR_ENTITIES
local LR_ENTITIES0 = LR_ENTITIES0
local LR_ENTITIES2 = LR_ENTITIES2
local LR_ENTITIES_MINUS2 = LR_ENTITIES_MINUS2
local LR_ENTITIES_MINUS3 = LR_ENTITIES_MINUS3
local TILE_SIZE = TILE_SIZE


-- returns a table[1..n] with all entities, optionally matching a given filter function
-- * filter: if given, the entity will only be included if filter(entity, ...) returns true
-- * ...: passed to the filter function
local function getAllEntities(filter, ...)
    if not filter then
        return (getEntityList())
    end
    local w = 0
    local tab, n = getEntityList()
    for i = 1, n do
        local e = tab[i]
        if filter(e, ...) then
            tab[w] = e
            w = w + 1
        end
    end
    for i = w+1, n do
        tab[i] = nil
    end
    return tab
end


local function getNearestEntityEx(x, y, distance, filter, ...)
    if filterNearestEntities(x, y, distance) == 0 then
        return 0
    end
    local nx = getNextFilteredEntity
    local e = nx()
    if not filter then
        return e
    end
    if type(filter) == "string" then
        while e ~= 0 do
            if entity_getName(e) == filter then
                return e
            end
            e = nx()
        end
    else
        while e ~= 0 do
            if filter(e, ...) then
                return e
            end
            e = nx()
        end
    end
    return 0
end

local function entity_getNearestEntityOfType(me, distance, ...) -- list of ET_*
    local x, y = entity_getPosition(me)
    if filterNearestEntities(x, y, distance, me) == 0 then -- this ignores the passed in entity
        return 0
    end
    local nargs = select("#", ...)
    local nx = getNextFilteredEntity
    local e = nx()
    while e ~= 0 do
        local et = entity_getEntityType(e)
        for i = 1, nargs do
            if et == select(i, ...) then
                return e
            end
        end
        e = nx()
    end
    return 0
end

local function entity_getNearestEntityWithEVT(me, distance, evt)
    local x, y = entity_getPosition(me)
    if filterNearestEntities(x, y, distance, me) == 0 then -- this ignores the passed in entity
        return 0
    end
    local nx = getNextFilteredEntity
    local e = nx()
    while e ~= 0 do
        if egetv(e, EV_TYPEID) == evt then
            return e
        end
        e = nx()
    end
    return 0
end


local function entity_disable(e)
    entity_alpha(e, 0)
    entity_setUpdateCull(e, 0)
    entity_setEntityType(e, ET_NEUTRAL)
    esetv(e, EV_LOOKAT, 0)
    esetv(e, EV_NOAVOID, 1)
    entity_setAllDamageTargets(e, false)
    entity_setPosition(e, 0, 0)
    entity_setLife(e, 0.5)
end

-- this function needs a bit of explanation.
-- if using many trigger entities, they usually stick to naija's position.
-- the problem is that these break the head rotation/smile, because the game
-- searches for any entity within a distance of 800, and focuses that if it has EV_LOOKAT set.
-- if this is not set, NO other entity is chosen.
-- but because song related callbacks need a distance of 1000 or smaller to be called,
-- the triggers can't be too far away.
-- basically, using this function reduces usage of magic numbers everywhere.
-- [Intended to be called from init() !!]
-- NOTE: patched by framework to set ET_HELPER instead
local function entity_makePassive(me)
    entity_setEntityType(me, ET_NEUTRAL) -- by making the entity neutral, normal shots won't target this
    esetv(me, EV_LOOKAT, 0)
    esetv(me, EV_NOAVOID, 1)
    entity_setAllDamageTargets(me, false)
    entity_setUpdateCull(me, -1)
    entity_setCanLeaveWater(me, true)
    entity_setEntityLayer(me, -100) -- LR_ENTITIES00 - Avatar::updateLookAt() searches only for entities in [LR_ENTITIES0 .. LR_ENTITIES2]
    entity_setInvincible(me, true)
    entity_setBeautyFlip(me, false)
    entity_setCollideRadius(me, 0)
    entity_setDeathSound(me, "")
    entity_setDeathParticleEffect(me, "")
    entity_setTargetPriority(me, -99999) -- don't ever target lock-on in energy form (game uses -999, anything less is fine)
end

local function entity_isFacingLeft(e)
    return not entity_isfh(e)
end

local function entity_faceRight(e)
    if not entity_isfh(e) then
        entity_fh(e)
    end
end

local function entity_faceLeft(e)
    if entity_isfh(e) then
        entity_fh(e)
    end
end

local function entity_fhToX(e, x)
    if x < entity_x(e) then
        entity_faceLeft(e)
    else
        entity_faceRight(e)
    end
end

local function entity_fhSame(e, x)
    if entity_isfh(e) ~= entity_isfh(x) then
        entity_fh(e)
    end
end

local function entity_fhAgainst(e, x)
    if entity_isfh(e) == entity_isfh(x) then
        entity_fh(e)
    end
end

local function _fhxGetEnt(e)
    local ride = entity_getRiding(e)
    return (ride ~= 0 and ride) or e
end

-- fh extended functions -- flip entity or ride, if riding on something

local function entity_fhxToPosition(e, x, y)
    entity_fhToPosition(_fhxGetEnt(e), x, y)
end


-- offs is additional angle to add: +x to look down by x more angles, -x to look up
local function entity_getHeadLookVector(e, head, offs)
    local nx, ny = obj_getNormal(head)
    offs = offs or 0
    if entity_isfh(e) then
        -- facing right
        nx, ny = vector_perpendicularLeft(nx, ny)
        nx, ny = vector_rotateDeg(nx, ny, offs) -- positive: rotate right -> rotate down
    else
        -- facing left
        nx, ny = vector_perpendicularRight(nx, ny)
        nx, ny = vector_rotateDeg(nx, ny, -offs) -- -> made negative: rotate right -> rotate up
    end
    return nx, ny
end

local function entity_canSeePoint(e, head, px, py, maxdist, angleUp, angleDown, offs, mindist)

    local headx, heady = obj_getWorldPosition(head)

    -- first check - point nearby?
    if maxdist or mindist then
        local dx = headx - px
        local dy = heady - py
        local d = dx*dx + dy*dy
        if maxdist and d > maxdist*maxdist then
            return false
        end
        if mindist and d < mindist*mindist then
            if isObstructed(headx, heady) then
                return not castLineIgnoreInitialObstruction(headx, heady, px, py)
            end
            return not castLine(headx, heady, px, py) -- near enough? just make sure it's in LOS, then
        end
    end

    -- second check - in arc?
    if not angleUp   then angleUp   = 30 end
    if not angleDown then angleDown = 30 end
    local lookx, looky = entity_getHeadLookVector(e, head, offs)
    if not isPointInArc(headx, heady, lookx, looky, angleUp, angleDown, px, py) then
        return false
    end

    -- last check - obstructed / behind a wall?
    if isObstructed(headx, heady) then
        return not castLineIgnoreInitialObstruction(headx, heady, px, py, 4)
    end

    return not castLine(headx, heady, px, py)
end

local function entity_getSeeAngles(e, head, angleUp, angleDown, offs)
    local lookx, looky = entity_getHeadLookVector(e, head, offs)
    return getOuterArcAnglesForDirection(lookx, looky, angleUp, angleDown)
end

local function entity_canSeeEntity(e, head, who, maxdist, angleUp, angleDown, offs)
    local x, y = entity_getPosition(who)
    return entity_canSeePoint(e, head, x, y, maxdist, angleUp, angleDown, offs)
end

local function entity_getVelAngle(e)
    return clamp360(vector_getAngleDeg(entity_getVel(e)))
end

local function entity_setHealthRange(e, cur, max)
    entity_setMaxHealth(e, max)
    entity_setCurrentHealth(e, cur)
    entity_heal(e, 0) -- process engine callbacks for health change
end

local function entity_isNormalLayer(e)
    local layer = entity_getLayer(e)
    return layer == LR_ENTITIES or layer == LR_ENTITIES0 or layer == LR_ENTITIES2 or layer == LR_ENTITIES_MINUS2 or layer == LR_ENTITIES_MINUS3
end

local function entity_isPullable(e)
    return entity_isProperty(e, EP_MOVABLE) and entity_getLife(e) >= 1
end


local function _getpullable(e)
    return entity_isPullable(e) and e
end
local function entity_getNearestPullTarget(e, maxdist)
    return entity_forAllEntitiesInRange(e, maxdist, _getpullable) or 0
end

-- safer version that prevents oscillation if friction force is big enough
local function entity_doFrictionEx(e, dt, len)
    local vx, vy = entity_getVel(e)
    entity_doFriction(e, dt, len)
    local vx2, vy2 = entity_getVel(e)
    if (vx <= 0) ~= (vx2 <= 0) or (vy <= 0) ~= (vy2 <= 0) then
        entity_clearVel(e)
    end
end

local function entity_doFriction2(e, dt, a)
    local x, y = entity_getVel2(e)
    if x ~= 0 or y ~= 0 then
        entity_addVel2(e, vector_setLength(-x, -y, dt * a))
        local nx, ny = entity_getVel2(e)
        if (x <= 0) ~= (nx <= 0) or (y <= 0) ~= (ny <= 0) then
            entity_clearVel2(e)
        end
    end
end

local function entity_getTotalVel(me)
    local vx, vy = entity_getVel(me)
    local vx2, vy2 = entity_getVel2(me)
    return vx+vx2, vy+vy2
end

local function entity_getTotalVelAngle(e)
    return clamp360(vector_getAngleDeg(entity_getTotalVel(e)))
end

-- return normalized direction vector + angle required to intercept an entity at a given speed.
-- returns nothing if impossible.
local function entity_getInterceptEntityVector(me, other, speed)
    if not entity_isVelIn(other, 1) then
        local x, y = entity_getPosition(me)
        local ox, oy = entity_getPosition(other)
        local a = getInterceptAngleForSpeed(x, y, speed or entity_getVelLen(me), ox, oy, entity_getTotalVel(other))
        if a then
            x, y = vector_fromDeg(a)
            return x, y, a
        end
    else
        local x, y = entity_getVectorToEntity(me, other)
        local a = vector_getAngleDeg(x, y)
        return x, y, a
    end
end

local function entity_getInterceptEntityVectorFallback(me, other, speed)
    local x, y, a = entity_getInterceptEntityVector(me, other, speed)
    if not x then
        x, y = entity_getVectorToEntity(me, other)
        a = vector_getAngleDeg(x, y)
    end
    return x, y, a
end

local function entity_getPathToEntity(e, o, step, xs, ys)
    local x, y = entity_getPosition(e)
    local xend, yend = entity_getPosition(o)
    return findPath(x, y, xend, yend, step, xs, ys)
end

local function entity_getPathToNode(e, o, step, xs, ys)
    local x, y = entity_getPosition(e)
    local xend, yend = node_getPosition(o)
    return findPath(x, y, xend, yend, step, xs, ys)
end

local function entity_getPathToPosition(e, xend, yend, step, xs, ys)
    local x, y = node_getPosition(e)
    return findPath(x, y, xend, yend, step, xs, ys)
end

-- select a nearby entity based on priority and entity's target points, if any
-- entity is the nearest one that matches cond
-- returns entity, priority
local getNearbyEntityTarget, entity_getNearbyEntityTarget
do
    local tmp = {}

    local function _selectTarget(e, x, y, cond, ...)
        if not cond or cond(e, ...) then
            local p = entity_getTargetPriority(e)
            local dx, dy, tpx, tpy, numtp
            if p >= tmp.p then
                local numtp = entity_getNumTargetPoints(e)
                if numtp == 0 then
                    tpx, tpy = entity_getPosition(e)
                    dx = tpx - x
                    dy = tpy - y
                    local d = dx*dx + dy*dy
                    if d < tmp.d then
                        tmp.d = d
                        tmp.e = e
                        tmp.p = p
                    end
                else
                    for i = 0, numtp-1 do
                        tpx, tpy = entity_getTargetPoint(e, i)
                        dx = tpx - x
                        dy = tpy - y
                        local d = dx*dx + dy*dy
                        if d < tmp.d then
                            tmp.d = d
                            tmp.e = e
                            tmp.p = p
                        end
                    end
                end
            end
        end
    end

    getNearbyEntityTarget = function(x, y, dist, cond, ...)
        dist = dist or 99999
        tmp.d = dist*dist+1
        tmp.e = 0
        tmp.p = -999
        forAllEntitiesInRange(x, y, dist, _selectTarget, x, y, cond, ...)
        return tmp.e, tmp.p
    end

    entity_getNearbyEntityTarget = function(me, dist, cond, ...)
        dist = dist or 99999
        tmp.d = dist*dist+1
        tmp.e = 0
        tmp.p = -999
        entity_forAllEntitiesInRange(me, dist, _selectTarget, x, y, cond, ...)
        return tmp.e, tmp.p
    end
end

local function entity_isInMapBoundaries(me)
    return entity_isInRect(me, getMaxCameraValues())
end

local function entity_isFacingDirection(me, dx, dy)
    local vx, vy = vector_fromDeg(entity_getRotation(me))
    if entity_isfh(me) then
        vx, vy = -vy, vx
    else
        vx, vy = vy, -vx
    end
    return dx*vx + dy*vy >= 0
end

local function entity_isFacingPosition(me, x, y)
    local ex, ey = entity_getPosition(me)
    return entity_isFacingDirection(me, makeVector(ex, ey, x, y))
end

local function entity_isFacingEntity(me, other)
    return entity_isFacingPosition(me, entity_getPosition(other))
end

local function entity_fhToPosition(me, x, y)
    if not entity_isFacingPosition(me, x, y) then
        entity_fh(me)
    end
end

local function entity_fhToDirection(me, dx, dy)
    if not entity_isFacingDirection(me, dx, dy) then
        entity_fh(me)
    end
end

local function entity_fhToEntity(me, other)
    return entity_fhToPosition(me, entity_getPosition(other))
end

-- 1 for facing totally towards point, 0 for facing 90°, -1 for facing totally away (point is behind back)
-- note that this assumes the entitity has a head that looks left when the rotation is 0 and fh==false
local function entity_getFacingTo(me, x, y)
    local ex, ey = entity_getPosition(me)
    local a = entity_getRotation(me)
    local dx, dy = vector_normalize(makeVector(ex, ey, x, y))
    local vx, vy = vector_fromDeg(a)
    if entity_isfh(me) then
        vx, vy = -vy, vx
    else
        vx, vy = vy, -vx
    end
    return dx*vx + dy*vy
end

local function entity_getFacingToEntity(me, e)
    return entity_getFacingTo(me, entity_getPosition(me))
end

local function entity_getVectorAroundEntity(me, e, left, len)
    local vx, vy = entity_getVectorToEntity(me, e)
    if len and len ~= 0 then
        vx, vy = vector_setLength(vx, vy, len)
    end
    if left then
        return -vy, vx
    else
        return vy, -vx
    end
end

local function entity_moveOutOfWall(me, ...)
    local cr = entity_getCollideRadius(me)
    local x, y = entity_getPosition(me)
    if not collideCircleWithGrid(x, y, cr) then
        return
    end
    local x2, y2, nx, ny = getNearestPointNotInWall(x, y)
    if x2 then
        x2 = x2 + cr
        y2 = y2 + cr
        for i = 1, 5 do
            if not collideCircleWithGrid(x2, y2, cr) then
                entity_setPosition(me, x2, y2, ...)
                return true
            end
            x2 = x2 + nx * TILE_SIZE
            y2 = y2 + ny * TILE_SIZE
        end
    end
    debugLog("entity_moveOutOfWall() failed")
    return false
end

-- returns: false or tileType, x, y (last checked position or where it hit an obstruction)
local function entity_isLineToEntityObstructed(me, e)
    --assert(entity_getName(me) ~= "")
    --assert(entity_getName(e) ~= "")
    local startx, starty = entity_getPosition(me)
    local endx, endy = entity_getPosition(e)
    local dx, dy = entity_getVectorToEntity(e, me)
    dx, dy = vector_setLength(dx, dy, entity_getCollideRadius(e))
    return castLine(startx, starty, endx + dx, endy + dy)
end

local function entity_isInLineOfSight(me, e)
    local obs, x, y = entity_isLineToEntityObstructed(me, e)
    return (not obs), x, y
end

--- return node by name the entity is inside, if any
local function entity_getEnclosingNode(me, nodename)
    local list = getNodesByLabel(nodename)
    if list then
        for i = 1, #list do
            if node_isEntityIn(list[i], me) then
                return list[i]
            end
        end
    end
    return 0
end

local getBoneByLUT =
{
    number = entity_getBoneByIdx,
    string = entity_getBoneByName,
}
local function entity_getBoneByAny(me, k)
    return getBoneByLUT[type(k)](me, k)
end

local function entity_applyBoneVisibility(me, tab, invert, silent)
    for k, on in pairs(tab) do
        local b = entity_getBoneByAny(me, k)
        if b and b ~= 0 then
            if invert then
                on = not on
            end
            bone_setVisible(b, on)
        elseif not silent then
            warnLog("entity_applyBoneVisibility: Bone [" .. tostring(k) .. "] not found for entity [" .. entity_getName(me) .. "]")
        end
    end
end

local function entity_stopRotation(me)
    entity_rotate(me, entity_getRotation(me)) -- this cancels any ongoing interpolation
end


return {
    getAllEntities = getAllEntities,
    getNearestEntityEx = getNearestEntityEx,
    entity_getNearestEntityOfType = entity_getNearestEntityOfType,
    entity_getNearestEntityWithEVT = entity_getNearestEntityWithEVT,
    getNearbyEntityTarget = getNearbyEntityTarget,
    entity_canSeePoint = entity_canSeePoint,
    entity_canSeeEntity = entity_canSeeEntity,
    entity_getSeeAngles = entity_getSeeAngles,
    entity_disable = entity_disable,
    entity_isFacingLeft = entity_isFacingLeft,
    entity_isFacingRight = entity_isfh, -- ALIAS but more clear
    entity_faceLeft = entity_faceLeft,
    entity_faceRight = entity_faceRight,
    entity_fhToX = entity_fhToX,
    entity_fhSame = entity_fhSame,
    entity_fhAgainst = entity_fhAgainst,
    entity_fhToEntity = entity_fhToEntity,
    entity_fhToPosition = entity_fhToPosition,
    entity_fhToDirection = entity_fhToDirection,
    entity_fhxToPosition = entity_fhxToPosition,
    entity_getHeadLookVector = entity_getHeadLookVector,
    entity_getTotalVel = entity_getTotalVel,
    entity_getVelAngle = entity_getVelAngle,
    entity_getTotalVelAngle = entity_getTotalVelAngle,
    entity_makePassive = entity_makePassive,
    entity_setHealthRange = entity_setHealthRange,
    entity_isNormalLayer = entity_isNormalLayer,
    entity_isPullable = entity_isPullable,
    entity_getNearestPullTarget = entity_getNearestPullTarget,
    entity_getNearbyEntityTarget = entity_getNearbyEntityTarget,
    entity_doFrictionEx = entity_doFrictionEx,
    entity_doFriction2 = entity_doFriction2,
    entity_getInterceptEntityVector = entity_getInterceptEntityVector,
    entity_getInterceptEntityVectorFallback = entity_getInterceptEntityVectorFallback,
    entity_getPathToEntity = entity_getPathToEntity,
    entity_getPathToNode = entity_getPathToNode,
    entity_getPathToPosition = entity_getPathToPosition,
    entity_getBoneByAny = entity_getBoneByAny,
    entity_isInMapBoundaries = entity_isInMapBoundaries,
    entity_isFacingEntity = entity_isFacingEntity,
    entity_isFacingPosition = entity_isFacingPosition,
    entity_isFacingDirection = entity_isFacingDirection,
    entity_getFacingTo = entity_getFacingTo,
    entity_getFacingToEntity = entity_getFacingToEntity,
    entity_getVectorAroundEntity = entity_getVectorAroundEntity,
    entity_moveOutOfWall = entity_moveOutOfWall,
    entity_isLineToEntityObstructed = entity_isLineToEntityObstructed,
    entity_isInLineOfSight = entity_isInLineOfSight,
    entity_getEnclosingNode = entity_getEnclosingNode,
    entity_stopRotation = entity_stopRotation,
    entity_applyBoneVisibility = entity_applyBoneVisibility,
}

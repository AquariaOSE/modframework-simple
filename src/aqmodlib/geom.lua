
-- geometry related functions

local isObstructed = isObstructed
local getObstruction = getObstruction
local isObstructedBlock = isObstructedBlock
local TILE_SIZE = TILE_SIZE
local TILE_SIZE_HALF = TILE_SIZE/2
local makeVector = makeVector

local toPolarAngle = math.atan2
local asin = math.asin
local abs = math.abs
local sin = math.sin
local sqrt = math.sqrt
local min = math.min
local max = math.max
local clamp = math.clamp
local DEGTORAD = 3.14159265359 / 180.0
local RADTODEG = 180.0 / 3.14159265359



-- Note: Better use castLine(), it's a native C++ function and way faster, but doesn't spawn particles
local function isLineObstructed(xstart, ystart, xend, yend, prt, prtEnd)

    local isObstructed = isObstructed
    local spawnParticleEffect = spawnParticleEffect
    
    local vx, vy = makeVector(xstart, ystart, xend, yend)
    local sx, sy = vector_setLength(vx, vy, TILE_SIZE) -- normalize to tile size
    local steps = vector_getLength(vx, vy) / TILE_SIZE
    
    local spawn = 70 -- more is never visible on screen
    
    local x, y = xstart, ystart
    for i = 0, steps do
        if isObstructed(x, y) then
            if prtEnd then
                spawnParticleEffect(prtEnd, x, y)
            end
            return getObstruction(x, y), x, y
        end
        if prt and spawn > 0 then
            spawnParticleEffect(prt, x, y)
            spawn = spawn - 1
        end
        x = x + sx
        y = y + sy
    end
    return false, x, y
end


local function castLineIgnoreInitialObstruction(xstart, ystart, xend, yend, maxsteps)
    local isObstructed = isObstructed
    
    local vx, vy = makeVector(xstart, ystart, xend, yend)
    local sx, sy = vector_setLength(vx, vy, TILE_SIZE) -- normalize to tile size
    local steps = min(vector_getLength(vx, vy) / TILE_SIZE, maxsteps or 20)
    
    -- loop until we're out of obs, then continue normal linecast
    local x, y = xstart, ystart
    for i = 0, steps do
        if not isObstructed(x, y) then
            return castLine(x, y, xend, yend)
        end
        x = x + sx
        y = y + sy
    end
    
    -- end of obs, so we're still obstructed. pretend nothing was hit.
    return getObstruction(xend, yend), xend, yend
end

-- center* : center point (map coords)
-- d* : direction vector from circle center (which counts as zero-angle) -- relative!
-- angle:  max. allowed angles between [-up ... +down]
-- p* : target point (map coords)
local function isPointInArc(centerx, centery, dx, dy, angleUp, angleDown, px, py)

    -- if in right quadrant, angles must be swapped to deliver correct result
    if dx > 0 then
        angleUp, angleDown = angleDown, angleUp
    end
    
    local prx, pry = makeVector(centerx, centery, px, py) -- point relative vector from center
    prx, pry = vector_normalize(prx, pry)
    dx, dy = vector_normalize(dx, dy)
    local ppol = toPolarAngle(prx, pry)
    local dpol = toPolarAngle(dx, dy)
    
    local aup = DEGTORAD * angleUp
    local adown = DEGTORAD * angleDown
    
    local a = ppol - dpol
    --if a >= -aup and a <= adown then spawnParticleEffect("awesomedebug2", px, py) else spawnParticleEffect("awesomedebug", px, py) end
    return a >= -aup and a <= adown
    
end

local function getOuterArcAngles(a, angleUp, angleDown)
    local a1 = (a + angleUp + 360*2) % 360
    local a2 = (a - angleDown + 360*2) % 360
    if a1 > a2 then
        a1, a2 = a2, a1
    end
    return a1, a2
end

local function getOuterArcAnglesForDirection(dx, dy, angleUp, angleDown)
    return getOuterArcAngles(vector_getAngleDeg(dx, dy), angleUp, angleDown)
end

-- Returns the course direction required to intercept a moving target at a given speed. Returns nil if there is no solution.
-- a: source; b: target
-- aspeed: current move speed of a, assumed to be constant
-- bvel[x|y]: move vector of b. length of this vector is speed of b.
-- adapted from: http://www.gmlscripts.com/script/intercept_course
local function getInterceptAngleForSpeed(ax, ay, aspeed, bx, by, bvelx, bvely)
    local blen = vector_getLength(bvelx, bvely)
    local dir = vector_getAngleRad(makeVector(ax, ay, bx, by))
    
    if blen <= 0 or aspeed <= 0 then
        return dir * RADTODEG
    end
    
    local beta = ((blen / aspeed) * sin(vector_getAngleRad(bvelx, bvely) - dir))
    --debugLog(string.format("beta: %f", beta)) 
    if beta > 1 then
        beta = beta - 1
    elseif beta < -1 then
        beta = beta + 1
    end
    if abs(beta) > 1 then
        return
    end
    return (dir + asin(beta)) * RADTODEG
end

local function getInterceptAngle(ax, ay, avelx, avely, bx, by, bvelx, bvely)
    return getInterceptAngleForSpeed(ax, ay, vector_getLength(avelx, avely), bx, by, bvelx, bvely)
end



-- a: source; b: target to be intercepted
-- returns position at which both will meet
-- via https://stackoverflow.com/questions/10358022/find-the-better-intersection-of-two-moving-objects
-- and http://jaran.de/goodbits/2011/07/17/calculating-an-intercept-course-to-a-target-with-constant-direction-and-velocity-in-a-2-dimensional-plane/
-- and http://wiki.unity3d.com/index.php/Calculating_Lead_For_Projectiles
local function getInterceptPositionAndTimeForSpeed(ax, ay, aspeed, bx, by, bvelx, bvely)
    local ox = bx - ax
    local oy = by - ay
    local bvelsq = bvelx*bvelx + bvely*bvely
    if bvelsq < 5 then -- HACK: otherwise we'd 
        return
    end
    local h1 = bvelsq - aspeed*aspeed
    local h2 = ox*bvelx + oy*bvely
    
    local t
    if h1 == 0 then
        t = -(ox*ox + oy*oy) / 2*h2
    else
        local minusPHalf = -h2 / h1
        local discr = minusPHalf*minusPHalf - (ox*ox + oy*oy) / h1
        if discr < 0 then
            return
        end
        
        local root = sqrt(discr)
        local t1 = minusPHalf + root
        local t2 = minusPHalf - root
        local tmin = min(t1, t2)
        local tmax = max(t1, t2)
        if t1 > 0 then
            t = t1
        end
        if t2 > 0 and (not t or t < t2) then
            t = t2
        end
        if not t then
            return
        end
    end
    
    return bx + t*bvelx, by + t*bvely, t
end

local function getInterceptPositionAndTime(ax, ay, avelx, avely, bx, by, bvelx, bvely)
    getInterceptPositionAndTimeForSpeed(ax, ay, vector_getLength(avelx, avely), bx, by, bvelx, bvely)
end

local function getNearbyObstructedPos(x, y)
    if isObstructed(x, y) then return x, y end
    local ts = TILE_SIZE
    if isObstructed(x, y+ts) then return x, y+ts end
    if isObstructed(x, y-ts) then return x, y-ts end
    if isObstructed(x+ts, y) then return x+ts, y end
    if isObstructed(x-ts, y) then return x+ts, y end
    if isObstructed(x+ts, y+ts) then return x+ts, y+ts end
    if isObstructed(x-ts, y+ts) then return x-ts, y+ts end
    if isObstructed(x+ts, y-ts) then return x+ts, y-ts end
    if isObstructed(x-ts, y-ts) then return x-ts, y-ts end
end

local function roundVectorToGrid(x, y)
    return x - (x % TILE_SIZE) + TILE_SIZE_HALF, y - (y % TILE_SIZE) + TILE_SIZE_HALF
end

local function findGround(x, y, maxlen)
    local dbg = isDebug()
    -- HACKish: Game::fillGrid() has the annoying tendency to insert small holes into diagonally
    -- rotated tiles... therefore this code checks for an extra free grid point above to be sure
    if y > 0 and (isObstructed(x, y) or isObstructed(x, y - TILE_SIZE)) then
        -- starting in ground, go up
        local yend = y - maxlen
        while y > yend do
            if not (isObstructed(x, y) or isObstructed(x, y - TILE_SIZE)) then
                y = y + TILE_SIZE -- get back on ground
                if dbg then
                    spawnParticleEffect("awesomedebug", x, y)
                end
                return y - (y % TILE_SIZE) + TILE_SIZE_HALF
            end
            y = y - TILE_SIZE
        end
    else
        -- starting in air, go down
        local yend = y + maxlen
        while y < yend do
            if isObstructed(x, y) then
                if dbg then
                    spawnParticleEffect("awesomedebug", x, y)
                end
                return y - (y % TILE_SIZE) + TILE_SIZE_HALF
            end
            y = y + TILE_SIZE
        end
    end
    
    -- failed to find ground
    if dbg then
        spawnParticleEffect("awesomedebug2", x, y)
    end
end

local function interpolateHeight(x, y, near, maxlen)
    near = near or 1
    maxlen = maxlen or 60
    local yi = 0
    local div = 0
    for xi = x - (near * TILE_SIZE), x + (near * TILE_SIZE), TILE_SIZE do
        local yg = findGround(xi, y, maxlen)
        if yg then
            yi = yi + yg
            div = div + 1
        end
    end
    if div > 0 then
        return yi / div
    end
end


-- via http://stackoverflow.com/questions/6176227/for-a-point-in-an-irregular-polygon-what-is-the-most-efficient-way-to-select-th
-- Line from (x1, y2) to (x2, y2) with point (px, py)
local function getClosestPointOnInfiniteLine(x1, y1, x2, y2, px, py)
    local dx = x2 - x1
    local dy = y2 - y1
    local u = ((px - x1) * dx + (py - y1) * dy) / (dx*dx + dy*dy)
    local xu = x1 + u * dx
    local yu = y1 + u * dy
    return xu, yu
end

local function getClosestPointOnLine(x1, y1, x2, y2, px, py)
    local dx = x2 - x1
    local dy = y2 - y1
    local u = ((px - x1) * dx + (py - y1) * dy) / (dx*dx + dy*dy)
    u = clamp(u, 0.0, 1.0)
    local xu = x1 + u * dx
    local yu = y1 + u * dy
    return xu, yu
end

local function getDistanceFromLineToPoint(x1, y1, x2, y2, px, py)
    local xu, yu = getClosestPointOnLine(x1, y1, x2, y2, px, py)
    return vector_getLength(makeVector(px, py, xu, yu)), xu, yu
end

local function isPositionInMapBoundaries(x, y)
    local x1, y1, x2, y2 = getMaxCameraValues()
    return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

-- returns: false or tileType, x, y (last checked position or where it hit an obstruction)
local function obj_isLineToObjObstructed(me, e)
    local startx, starty = obj_getPosition(me)
    local endx, endy = obj_getPosition(e)
    return castLine(startx, starty, endx, endy)
end

local function obj_isInLineOfSight(me, e)
    local obs, x, y = obj_isLineToObjObstructed(me, e)
    return (not obs), x, y
end

local function getNearestPointNotInWall(x, y)
    if not isObstructed(x, y) then
        return x, y, 0, 0
    end
    local nx, ny = getWallNormal(x, y)
    if nx == 0 and ny == 0 then
        return
    end
    local nxa = nx * TILE_SIZE
    local nya = ny * TILE_SIZE
    for i = 1, 6 do
        x = x + nxa
        y = y + nya
        if not isObstructed(x, y) then
            return x, y, nx, ny
        end
    end
    -- fail
end

local RESPECT_OBS = (OT_BLOCKING + OT_USER1)
local MIN_STEP = TILE_SIZE/2
local MAX_STEP = TILE_SIZE*2
local JUMP_MUL = 10
local function estimatePositionInDistance(sx, sy, vx, vy, dist, stepsize, maxiter, obs, mincorr, exponent)
    if vx == 0 and vy == 0 then
        return sx, sy
    end
    PROFILER.estimatePositionInDistance = PROFILER.estimatePositionInDistance + 1
    mincorr = mincorr or 0.3
    exponent = exponent or 5
    dist = dist or 2000
    obs = obs or RESPECT_OBS
    stepsize = stepsize or rangeTransformClamp(vector_getLength(vx, vy), 0, 1000, MIN_STEP, MAX_STEP)
    local jumpsize = stepsize * JUMP_MUL
    local jx, jy = vector_setLength(vx, vy, jumpsize)
    vx, vy = vector_setLength(vx, vy, stepsize)
    local avx, avy = vx * 0.3, vy * 0.3
    local avxs, avys = vx * 0.2, vy * 0.2
    local avxn, avyn = vector_normalize(vx, vy)
    
    local dsq = dist * dist
    maxiter = maxiter or (dist / stepsize)
    
    local x, y = sx, sy
    local px, py, c
    local vxn, vyn = vector_normalize(vx, vy)
    local m = 0
    local bestx, besty = x, y
    local bestd = 0
    local warp
    for i = 1, maxiter do
        --spawnParticleEffect("awesomedebug", x, y)
        
        px, py = x, y
        c, x, y = castLine(x, y, x+jx, y+jy, obs)
        
        if c then
            m = min(m * 1.05 + 0.5, 10.0)
            
            local nx, ny = getWallNormal(x, y, nil, obs)
            local ux, uy = -nx, -ny
            if uy*vx + nx*vy > ny*vx + ux*vy then
                ux, uy = uy, nx
            else
                ux, uy = ny, ux
            end
            
            local ms = m * stepsize
            local mms = 0.1 * ms
            local rx, ry = randVector(stepsize * 0.05)
            vxn, vyn = vector_normalize(
                    vx + ux*ms + avx + rx + mms*nx,
                    vy + uy*ms + avy + ry + mms*ny)
            x, y = px + vx + (nx+ux)*stepsize,
                   py + vy + (ny+uy)*stepsize
            if isObstructed(x, y, obs) then
                x, y = px, py
            end
            
            -- dead end or alcove? check for warp
            -- (don't always check for warp because this could get pretty expensive)
            local same = (vxn*nx + vyn*ny) -- in [-1, 1]
            if same < -0.4 then
                --spawnParticleEffect("awesomedebug2", x, y)
                local node = getNearestNodeByType(x, y, PATH_WARP)
                if node_isPositionIn(node, x, y) then
                    local wx, wy = node_getPosition(node)
                    bestx, besty = x, y
                    warp = node
                    break
                end
            end
            
        else
            m = 0 --max(m * 0.5 - 0.3, 0)
            vxn, vyn = vector_normalize(vx + avxs, vy + avys)
        end
        vx, vy = vxn * stepsize, vyn * stepsize
        jx, jy = vx * JUMP_MUL, vy * JUMP_MUL
        
        if not isObstructed(x, y, obs) then
            local dx, dy = x-sx, y-sy
            local dxn, dyn = vector_normalize(dx, dy)
            local corr = (dxn*avxn + dyn*avyn) * 0.5 + 0.5 -- in [0 .. 1]
            -- abort if going completely opposite way
            if corr < mincorr then
                break
            end
            local bias = corr ^ exponent
            local d = (dx*dx + dy*dy)
            local dbias = d * bias
            if dbias > bestd then
                bestd = dbias
                bestx, besty = x, y
                if d >= dsq then
                    break
                end
            end
        end
    end
    
    return bestx, besty, warp
end

return {
    isLineObstructed = isLineObstructed,
    castLineIgnoreInitialObstruction = castLineIgnoreInitialObstruction,
    isPointInArc = isPointInArc,
    getOuterArcAngles = getOuterArcAngles,
    getOuterArcAnglesForDirection = getOuterArcAnglesForDirection,
    getInterceptAngle = getInterceptAngle,
    getInterceptAngleForSpeed = getInterceptAngleForSpeed,
    getNearbyObstructedPos = getNearbyObstructedPos,
    roundVectorToGrid = roundVectorToGrid,
    findGround = findGround,
    interpolateHeight = interpolateHeight,
    getClosestPointOnLine = getClosestPointOnLine,
    getDistanceFromLineToPoint = getDistanceFromLineToPoint,
    isPositionInMapBoundaries = isPositionInMapBoundaries,
    obj_isLineToObjObstructed = obj_isLineToObjObstructed,
    obj_isInLineOfSight = obj_isInLineOfSight,
    getInterceptPositionAndTimeForSpeed = getInterceptPositionAndTimeForSpeed,
    getInterceptPositionAndTime = getInterceptPositionAndTime,
    getNearestPointNotInWall = getNearestPointNotInWall,
    estimatePositionInDistance = estimatePositionInDistance,
    
}

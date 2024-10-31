local RADTODEG = RADTODEG
local DEGTORAD = DEGTORAD
local PI = math.pi
local PI_HALF = PI / 2
local TWO_PI = PI * 2

local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local acos = math.acos
local atan2 = math.atan2
local abs = math.abs
local clamp360 = clamp360
local max = math.max
local min = math.min

local function vector_rotateRad(x, y, a)
    local s = sin(a)
    local c = cos(a);
    return c*x - s*y, s*x + c*y
end


local function vector_rotateDeg(x, y, a)
    return vector_rotateRad(x, y, DEGTORAD * a)
end

local function vector_fromRad(a, len)
    -- straightforward: rotate vector pointing upwards, clockwise.
    --if not len then len = 1 end
    --return vector_rotateRad(0, -len, r)
    
    local sa = sin(a)
    local ca = -cos(a)
    
    if len then
        return sa*len, ca*len
    end
    
    return sa, ca
end

local function vector_fromDeg(r, len)
    return vector_fromRad(DEGTORAD * r, len)
end

local function makeVector(fromx, fromy, tox, toy)
    return tox - fromx, toy - fromy
end

local function vector_perpendicularLeft(x, y)
    return -y, x
end

local function vector_perpendicularRight(x, y)
    return y, -x
end

local function vector_getAngleDeg(x, y)
    return (atan2(vector_normalize(y, x)) * RADTODEG) + 90
end

local function vector_getAngleRad(x, y)
    return atan2(vector_normalize(y, x)) + PI_HALF
end

local function vector_getAngleBetweenRad(x1, y1, x2, y2)
    x1, y1 = vector_normalize(x1, y1)
    x2, y2 = vector_normalize(x2, y2)
    return acos(x1*x2 + y1*y2)
end

local function vector_getAngleBetweenDeg(x1, y1, x2, y2)
    return vector_getAngleBetweenRad(x1, y1, x2, y2) * RADTODEG
end

local function vector_getAngleFromToRad(x1, y1, x2, y2)
    return atan2(y2, x2) - atan2(y1, x1)
end

local function vector_getAngleFromToDeg(x1, y1, x2, y2)
    return (atan2(y2, x2) - atan2(y1, x1)) * RADTODEG
end


local function vector_getLength3DSq(x, y, z)
    return x*x + y*y + z*z
end

local function vector_getLength3D(x, y, z)
    return sqrt(x*x + y*y + z*z)
end

local function vector_normalize3D(x, y, z)
    local len = vector_getLength3D(x, y, z)
    if len == 0 then
        return 0, 0, 0
    end
    local m = 1 / len
    return x * m, y * m, z * m
end

local function vector_setLength3D(x, y, z, newlen)
    local oldlen = sqrt(x*x + y*y + z*z)
    if oldlen == 0 then 
        return 0, 0, 0
    end
    local m = newlen / oldlen
    return x * m, y * m, z * m
end


-- steepness given wall normal
-- 0 when flat
-- 1 in vertical shafts
-- 2 on the ceiling
local function vector_getSteepness(x, y)
    x, y = vector_normalize(x, y)
    return y + 1
end


-- broken?
-- assumes (nx, ny) is normalized vector
--[[local function vector_reflect(x, y, nx, ny)
    local len = vector_getLength(x, y)
    x, y = x / len, y / len
    local tmp = (x*nx + y*ny) * 2
    return vector_setLength(tmp*nx - x, tmp*ny - y, len)
end]]

-- get best rotation angle to rotate from `from` to `to` so it looks good in (optional) time t
-- returns current rotation, new rotation
-- Note: returned current rotation may differ from actual current rotation in case there's a rollover,
-- in that case do this:
-- from, to = getBestRot360(from, to, t)
-- thing_rotate(e, from)
-- thing_rotate(e, to, t)
local function getBestRot360(from, to, t)
    local slow = t and t ~= 0 -- when rotating slowly, don't wrap around
    from = clamp360(from) -- [0..360)
    to = clamp360(to)     -- [0..360)
    if slow then
        -- account for rollover on both ends and use whatever minimizes the difference
        local d1 = to - from
        local d2 = (to - 360) - from
        local d3 = (to + 360) - from
        local da1 = abs(d1)
        local da2 = abs(d2)
        local da3 = abs(d3)
        local d
        if da1 <= da2 and da1 <= da3 then
            d = d1
        elseif da2 <= da1 and da2 <= da3 then
            d = d2
        else
            d = d3
        end
        to = from + d
    else
        local d = to - from
        local neg = abs(d) > 180
        if d < 0 then
            -- rot left
            if d < -180 then
                d = 360 + d
            end
        else
            -- rot right
            if d > 180 then
                d = 360 - d
            end
        end
        if neg then
            d = -d
        end
        to = to + d
    end
    return from, to
end




-- -1 when going down a cliff
-- -0.5 when going downhill 45°
-- 0 when flat
-- 0.5 when going up 45°
-- 1 when going up a cliff
-- up to 2/-2 when wall is above head (normal vector pointing downwards)
local function vector_getSteepnessForNormalInDirection(nx, ny, dx)
    if nx ~= 0 or ny == 0 then
        nx, ny = vector_normalize(nx, ny)
        local a = acos(-ny) -- simplified vector_getAngleBetweenDeg(nx, ny, 0, -1)
        if a > PI then
            a = TWO_PI - a
        end
        a = a / PI_HALF
        -- simplified dot(n, d) <= 0 -> up (normal goes against walking direction)
        -- so if not up then go the other way
        if nx * dx > 0 then
            a = -a
        end
        return a
    end
end
--[[
function vector_normalize(nx, ny)
    local len = sqrt(nx*nx + ny*ny)
    if len == 0 then
        return 0, 0
    end
    return nx / len, ny / len
end
function vector_dot(a, b, c, d)
    return a*c + b*d
end
local function test(nx, ny, dx)
    nx, ny = vector_normalize(nx, ny)
    local s = vector_getSteepnessForNormalInDirection(nx, ny, dx)
    print(nx, ny, dx, s)
end
RADTODEG = 180.0 / 3.14159265359
DEGTORAD = 3.14159265359 / 180.0

test(-1, 0, 0)--   |   (1)
test(0, -1, 0)--   _   (0)
print()
test(-1, 0, 1)-- ->|  (1)
test(0, -1, 1)-- ->_  (0)
test(-0.5, -0.5, 1)  -- --> / (0.5)
test(-1, -0.1, 1)  -- --> / (> 0.9)
test(-0.1, -1, 1)  -- --> / (< 0.1)
print()
test(-1, 0, -1)--   |<-  (1)
test(0, -1, -1)--   _<-  (0)
test(-0.5, -0.5, -1)  --    / <-  (-0.5)
test(-1, -0.1, -1) --     / <--   (< -0.9)
test(-0.1, -1, -1) --     / <--   (> -0.1)
]]

return {
    vector_rotateRad = vector_rotateRad,
    vector_rotateDeg = vector_rotateDeg,
    vector_rotate = vector_rotateDeg,
    vector_fromRad = vector_fromRad,
    vector_fromDeg = vector_fromDeg,
    vector_perpendicularLeft = vector_perpendicularLeft,
    vector_perpendicularRight = vector_perpendicularRight,
    vector_getAngleDeg = vector_getAngleDeg,
    vector_getAngleRad = vector_getAngleRad,
    makeVector = makeVector,
    vector_getLength3DSq = vector_getLength3DSq,
    vector_getLength3D = vector_getLength3D,
    vector_normalize3D = vector_normalize3D,
    vector_setLength3D = vector_setLength3D,
    vector_getSteepness = vector_getSteepness,
    --vector_reflect = vector_reflect,
    getBestRot360 = getBestRot360,
    vector_getSteepnessForNormalInDirection = vector_getSteepnessForNormalInDirection,
}

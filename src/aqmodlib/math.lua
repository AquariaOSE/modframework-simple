local min = math.min
local max = math.max
local floor = math.floor
local random = math.random
local TWO_PI = math.pi * 2
local INV_TWO_PI = 1 / TWO_PI

local RADTODEG = 180.0 / 3.14159265359
local DEGTORAD = 3.14159265359 / 180.0

rawset(_G, "RADTODEG", RADTODEG)
rawset(_G, "DEGTORAD", DEGTORAD)

local function clamp(x, a, b)
    return max(a, min(x, b))
end
math.clamp = clamp

-- scale t from [lower, upper] into [rangeMin, rangeMax]
local function rangeTransform(t, lower, upper, rangeMin, rangeMax)
    if upper == lower then
        return rangeMin
    end

    return (((t - lower) / (upper - lower)) * (rangeMax - rangeMin)) + rangeMin
end

local function rangeTransformClamp(t, lower, upper, rangeMin, rangeMax)
    return clamp(rangeTransform(t, lower, upper, rangeMin, rangeMax), min(rangeMin, rangeMax), max(rangeMin, rangeMax))
end

local function rangeClamp(value, a, b)
    local width = b - a
    if width == 0 then
        return a
    end
    local offsetValue = value - a
    return (offsetValue - (floor(offsetValue / width) * width)) + a
end

local function clamp360(value)
    return value - (floor(value * (1/360)) * 360)
end

local function clamp2pi(value)
    return value - (floor(value * INV_TWO_PI) * TWO_PI)
end


-- creates gaussian smoothing kernel of size (2*dim)-1 with standard deviation sigma
local function createGaussianKernel(dim, sigma)
    sigma = sigma or 1
    local t = {}
    local k
    local sigsq = sigma*sigma
    local sum = 0
    local tins = table.insert
    for x = -dim, dim do
        k = 2.71828 ^ (-0.5*x*x/sigsq)
        tins(t, k)
        sum = sum + k
    end
    -- normalize
    for i, val in pairs(t) do
        t[i] = val / sum
    end
    return t
end

function math.sign(x)
    if x < 0 then
        return -1
    elseif x > 0 then
        return 1
    end
    return 0
end

function math.lerp(x1, x2, t)
    return (1 - t) * x1 + x2 * t
end

function math.lerp2(x1, y1, x2, y2, t)
    return (1 - t) * x1 + x2 * t,
           (1 - t) * y1 + y2 * t
end

function math.lerp3(x1, y1, z1, x2, y2, z2, t)
    local t1 = 1 - t
    return t1 * x1 + x2 * t,
           t1 * y1 + y2 * t,
           t1 * z1 + z2 * t
end

-- random function that is prone to produce small numbers (always in [1 .. n] and integer)
-- radix is how "aggressively" the numbers are skewed towards small numbers
-- (1 = uniform distribution, 2 = quadratic, etc)
function math.makeskewrandom(radix)
    local invradix = 1 / radix
    return function(n)
        return n - floor((random() * (n ^ radix)) ^ invradix)
    end
end

return {
    rangeTransform = rangeTransform,
    rangeTransformClamp = rangeTransformClamp,
    createGaussianKernel = createGaussianKernel,
    rangeClamp = rangeClamp,
    clamp360 = clamp360,
    clamp2pi = clamp2pi,
}

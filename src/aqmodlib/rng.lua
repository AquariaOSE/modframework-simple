
-- simple random number generator
-- Based on http://www.rgba.org/articles/sfrand/sfrand.htm

local M = {}

local floor = math.floor
local random = math.random

function M.new(x)
    local r = {}
    setmetatable(r, M)
    if x then
        x = floor(x)
    else
        x = random(0, 0xFFFFFF)
    end
    r._init = x
    r:reset()
    return r
end

function M.reset(r)
    r._state = r._init
end

-- [0 .. 1]
local D = 2.0 / 23767
local i32 = 0xFFFFFFFF + 1
function M:next()
    local a = self._state * 16807
    self._state = a % i32
    a = (a / 0x8000) % 0x8000
    return ((1 + (D * a)) % 1)
end

-- same semantics as math.random()
function M:random(a, b)
    if a then
        if b then
            return floor(1 + a + (self:next() * (b - a)))
        end
        
        return floor(1 + (self:next() * a))
    end
    
    return self:next()
end

function M:chance(c)
    return c > self:next() * 100
end

M.__index = M
M.__call = M.random

rawset(_G, "prandom", M)




-- turn any random function / RNG that returns [0..1) into a RNG that produces a normal distribution

local sqrt = math.sqrt
local log = math.log
local cos = math.cos
local sin = math.sin

local N = {}

function N.new(rng, mean, variance)
    return setmetatable({rng = assert(rng), mean = mean or 0, var = variance or 1}, N)
end

-- box-muller-method
function N:next()
    local rng = self.rng
    local r = sqrt(-2.0 * log(1.0-rng())) * self.var;
    local phi = (2.0 * 3.141592653) * rng();
    return self.mean + r * cos(phi);
end

N.__call = N.next

rawset(_G, "normrandom", N)

-----------
-- normal-ish (more like a small hill) distribution, centered around 0, in range [-1 .. +1]
-- rng is expected to return [0..1)

local N0 = {}

function N0.new(rng, mean, variance)
    return setmetatable({rng = assert(rng)}, N0)
end

-- mean=0, variance=1
-- bastardized box-muller-something. no, i don't know what i'm doing but plotting this in R looked kinda ok
function N0:next()
    local rng = self.rng
    local r = sqrt(-2.0 * log(1.0-rng()));
    local phi = (2.0 * 3.141592653) * rng();
    return sin(0.5 * r * cos(phi));
end

N0.__call = N0.next

rawset(_G, "norm0random", N0)

--[[
local nr = N0.new(math.random)
for i = 1, 10 do
    print(nr())
end
]]

-- translated from some of my own C++ code
-- uses zero-based indexing
-- just take care that the end of the for loop
--  for(i = 0; i < m; ++i) ...
-- in c++ is exclusive, while in lua the same loop would be inclusive, so it must be
--  for i=0, m-1 do ... end


local abs = math.abs
local sqrt = math.sqrt

local function findKnotIndex(knots, t, num)
    local i = table.lowerbound(knots, t, 0, num)
    if i >= num then
        return num-1
    end
    -- i is index of first element not less than t, go one back to get the one strictly less than t
    if knots[i] > 0 then
        i = i - 1
    end
    return i
end

-- uniformly spaced knots
local function generateKnotVectorUniform(knots, n, p)
    local m = 1 / (n - p + 1)
    for j = 1, n - p do
        knots[j+p] = j * m
    end
end

--[[local function generateKnotVectorAxis1(knots, n, p, xs)
    local steps = n - p
    local totallen = 0
    local points = #xs
    local prev = xs[1]
    for i = 1, points-1 do
        local cur = xs[i+1]
        local d = abs(prev - cur)
        totallen = totallen + d
        prev = cur
        knots[i+p] = totallen
    end
    
    for i = p, points-p do
        knots[i] = knots[i] / totallen
    end
end]]

-- pass (ordered!) values in ... for custom parametrization.
-- customlen should be without end points
local function generateKnotVector(knots, points, degree, customknots, customlen)
    local n = points - 1
    local p = degree
    if n < p then
        error("n < p")
    end

    local numknots = n + p + 2 -- total number of knots for this degree
    --print("nk", numknots)

   local firstknot, maxknot

    if customknots then -- custom parametrization?
        local needknots = n - p + 2
        --print("need", needknots)
        --generateKnotVectorAxis1(knots, n, p, ...)
        -- do nothing except copy + fixup
        local customlen = customknots.n or #customknots
        if customlen ~= needknots then
            error("bspline: generateKnotVector(degree: " .. p .. ", points: " .. points .. ") - custom: expected " .. needknots .. " values, but got " .. customlen)
        end
        --print("ck", unpack(customknots))
        --table.sort(customknots) -- user must pass in knots already sorted
        firstknot = customknots[1]
        maxknot = customknots[customlen]

        local w = p+1
        local prevknot = firstknot
        -- middle points. skip outer values, these are written to the padding area later below
        for i = 2, customlen-1 do -- check that really ordered. 
            local val = customknots[i]
            assert(prevknot <= val, "bspline: custom knots not ordered properly")
            prevknot = val
            knots[w] = val -- zero-based indexing!
            w = w + 1
            --debugLog("c: " ..customknots[i] / maxknot)
        end

    else
        firstknot = 0
        maxknot = 1
        generateKnotVectorUniform(knots, n, p)
    end
    
        -- end point interpolation, beginning
    for i = 0, p do
        knots[i] = firstknot
    end
        -- end point interpolation, end
    for i = numknots - p - 1, numknots-1 do
        knots[i] = maxknot
    end
    -- possibly some leftover tail entries in knots but we know the length, so this doesn't matter
    return numknots
end

local xwork = {}
local ywork = {}
local zwork = {}

local B1, B2, B3 = {}, {}, {} -- class metatables
B1.__index = B1
B2.__index = B2
B3.__index = B3

function B1:eval(t)
    local knots = self._knots
    local r = findKnotIndex(knots, t, self._numknots)
    local d = self._lastdegree
    local xs = self._xs
    if r < d then
        r = d
    end
    local k = d + 1
    local xwork = xwork
    for i = 0, d do
        xwork[i] = xs[r - d + i]
    end
    
    local worksize = k
    while worksize > 1 do
        local j = k - worksize + 1 -- iteration number, starting with 1, going up to k
        local tmp = r - k + 1 + j
        for w = 0, worksize-2 do
            local i = w + tmp
            local ki = knots[i]
            local a = (t - ki) / (knots[i+k-j] - ki)
            xwork[w] = xwork[w] * (1-a) + xwork[w+1] * a
        end
        worksize = worksize - 1
    end
    return xwork[0]
end

function B2:eval(t)
    local knots = self._knots
    local r = findKnotIndex(knots, t, self._numknots)
    local d = self._lastdegree
    local xs = self._xs
    local ys = self._ys
    if r < d then
        r = d
    end
    local k = d + 1
    local xwork = xwork
    local ywork = ywork
    for i = 0, d do
        local tt = r - d + i
        xwork[i] = xs[tt]
        ywork[i] = ys[tt]
    end
    
    local worksize = k
    while worksize > 1 do
        local j = k - worksize + 1 -- iteration number, starting with 1, going up to k
        local tmp = r - k + 1 + j
        for w = 0, worksize-2 do
            local i = w + tmp
            local ki = knots[i]
            local a = (t - ki) / (knots[i+k-j] - ki)
            xwork[w] = xwork[w] * (1-a) + xwork[w+1] * a
            ywork[w] = ywork[w] * (1-a) + ywork[w+1] * a
        end
        worksize = worksize - 1
    end
    return xwork[0], ywork[0]
end

function B3:eval(t)
    local knots = self._knots
    local r = findKnotIndex(knots, t, self._numknots)
    local d = self._lastdegree
    local xs = self._xs
    local ys = self._ys
    local zs = self._zs
    if r < d then
        r = d
    end
    local k = d + 1
    local xwork = xwork
    local ywork = ywork
    local zwork = zwork
    for i = 0, d do
        local tt = r - d + i
        xwork[i] = xs[tt]
        ywork[i] = ys[tt]
        zwork[i] = zs[tt]
    end
    
    local worksize = k
    while worksize > 1 do
        local j = k - worksize + 1 -- iteration number, starting with 1, going up to k
        local tmp = r - k + 1 + j
        for w = 0, worksize-2 do
            local i = w + tmp
            local ki = knots[i]
            local a = (t - ki) / (knots[i+k-j] - ki)
            local a1 = 1-a
            local w1 = w+1
            xwork[w] = xwork[w] * (a1) + xwork[w1] * a
            ywork[w] = ywork[w] * (a1) + ywork[w1] * a
            zwork[w] = zwork[w] * (a1) + zwork[w1] * a
        end
        worksize = worksize - 1
    end
    return xwork[0], ywork[0], zwork[0]
end

function B2:calculateLength()
    local xs = self._xs
    local ys = self._ys
    local len = xs.n or #xs
    local d = 0
    for i = 2, len do
        local dx = xs[i-1] - xs[i]
        local dy = ys[i-1] - ys[i]
        d = d + sqrt(dx*dx + dy*dy)
    end
    return d
end

-- returns true when knot vector changed
local function _updateGeneric(b, len, degree, customknots)
    -- intentionally not using _lastdegree here.
    -- allow setting default degree in ctor, or use a specific one when passed.
    -- but _lastdegree is needed for eval and to check if the current degree is changing
    degree = degree or b._degree or 3
    local defaultknots = not customknots
    if customknots or defaultknots ~= b._hasdefaultknots or len ~= b._len or degree ~= b._lastdegree then
        local numknots = generateKnotVector(b._knots, len, degree, customknots)
        b._numknots = numknots
        b._len = len
        b._lastdegree = degree
        b._hasdefaultknots = defaultknots -- just used here for the check
        return true
    end
end

local function _idxshift(t0, t, len)
    t0 = t0 or {}
    for i = 1, len do -- convert to 0-based indexing (makes things above easier)
        t0[i-1] = t[i]
    end
    return t0
end

-- update#d semantic:
-- pass xs, ys, zs as point lists (mandatory. must have same number of points)
-- degree is used if passed, otherwise the spline's initial degree is used, and if that isn't present, make it a cubic spline
local function _update1d(b, xs, ...)
    local len = xs.n or #xs
    _updateGeneric(b, len, ...)
    b._xs = _idxshift(b._xs, xs, len)
end

local function _update2d(b, xs, ys, ...)
    local len = xs.n or #xs
    _updateGeneric(b, len, ...)
    b._xs = _idxshift(b._xs, xs, len)
    b._ys = _idxshift(b._ys, ys, len)
end

local function _update3d(b, xs, ys, zs, ...)
    local len = xs.n or #xs
    _updateGeneric(b, len, ...)
    b._xs = _idxshift(b._xs, xs, len)
    b._ys = _idxshift(b._ys, ys, len)
    b._zs = _idxshift(b._zs, zs, len)
end

B1.__call = B1.eval
B2.__call = B2.eval
B3.__call = B3.eval

B1.updatePoints = _update1d
B2.updatePoints = _update2d
B3.updatePoints = _update3d

local function _prep(xs, degree, ...)
    local customknots
    if (...) then
        customknots = ...
        if type(customknots) ~= "table" then
            customknots = table.pack(...)
        end
    end
    if type(xs) == "number" then
        degree = xs
        xs = nil
    end
    if not xs then
        assert(not customknots, "bspline init: custom knots passed without points, can't use them")
    end
    return xs, degree, customknots
end

local B = {}

-- pass in tp[1..N] where tp[] is a sorted array, and N is the number of value points that are also passed
-- in the ctor or to updatePoints().
-- Each value in tp[i] corresponds to a point[i], so that evaluating spline(t) results in a curve point
-- where point[i] has the most influence, where t corresponds to the tp[i] but rescaled to 0..1.
-- think of it as a timeline from T0..Tn, where the spline will then go between T0..Tn for eval in t=0..1.
function B.generateKnotVectorFromTimeline(tp, degree, len, knots)
    len = len or tp.n or #tp
    local low = tp[1]
    local range = tp[len] - low
    local m
    if range ~= 0 then
        m = 1 / range
    else
        m = 0
    end
    
    -- first knot is always 0
    knots = knots or {}
    knots[1] = 0
    for i = 2, len-degree do -- clip off the right tail, it will be evaluated in the deBoor phase
        knots[i] = (tp[i] - low) * m
    end
    
    -- last knot is always 1
    local klen = len-degree+1
    knots[klen] = 1
    knots.n = klen
    
    return knots
end

function B.new1d(xs, degree, ...)
    local customknots
    xs, degree, customknots = _prep(xs, degree, ...)
    local b = setmetatable({ _knots = {}, _degree = degree }, B1)
    if xs then
        _update1d(b, xs, degree, customknots)
    end
    return b
end

function B.new2d(xs, ys, degree, ...)
    local customknots
    xs, degree, customknots = _prep(xs, degree, ...)
    
    local b = setmetatable({ _knots = {}, _degree = degree }, B2)
    if xs then
        _update2d(b, xs, ys, degree, customknots)
    end
    return b
end

function B.new3d(xs, ys, zs, degree, ...)
    local customknots
    xs, degree, customknots = _prep(xs, degree, ...)
    
    local b = setmetatable({ _knots = {}, _degree = degree }, B3)
    if xs then
        _update3d(b, xs, ys, zs, degree, customknots)
    end
    return b
end

rawset(_G, "bspline", B)


-- test code
--[[
dofile("table.lua")
debugLog = print
local xs = {-5, -1, 1, 5, 7}
local ys = {-5, 5, -5, 5, 0}
local s = B.new2d(xs, ys)

for i, k in pairs(s._knots) do
    print(i, k)
end

print(s(0.0))
print(s(0.1))
print(s(0.9))
print(s(1.0))
print("-------------")

s = B.new1d(xs)
for i, k in pairs(s._knots) do
    print(i, k)
end
print(s(0.0))
print(s(0.1))
print(s(0.9))
print(s(1.0))

print("------custom-------")
local xs = {0, 4, 10, 2}
local lin = B.new1d(xs, 2, {0, 0.2, 1})
print(unpack(lin._knots))
print(lin(0.75))
]]

-- incremental pathfinder

--[[ usage:
    local ipf = ipf_create(20000)
    ipf:start(sx, sy, tx, ty, obs)
    while not ipf() do
        yield()
    end
    local num, xs, ys = ipf:result()
    if num then
        -- use path in xs[1..num], ys[1..num]
    end
]]

local ipf = {}
ipf.__index = ipf

local function ipf_create(limit, steps)
    local self = { _limit = limit, _steps = steps, _pf = createFindPath(), on = false, num = false }
    return setmetatable(self, ipf)
end

function ipf:start(sx, sy, gx, gy, obs)
    findPathBegin(self._pf, sx, sy, gx, gy, obs)
    self.on = true
end

function ipf:__call(limit)
    return findPathUpdate(self._pf, limit or self._limit) -- returns true when done
end

function ipf:updateCallback(limit, f, ...)
    if self.on and findPathUpdate(self._pf, limit or self._limit) then
        self.on = false
        local num, xs, ys = findPathFinish(self._pf, granularity, self.xs, self.ys)
        self.num, self.xs, self.ys = num, xs, ys
        return true, f(num, xs, ys, ...)
    end
end

function ipf:result(granularity)
    if self.on then
        self.on = false
        local num, xs, ys = findPathFinish(self._pf, granularity, self.xs, self.ys)
        self.num, self.xs, self.ys = num, xs, ys
        return num, xs, ys
    else
        return self.num, self.xs, self.ys
    end
end

function ipf:stats() -- stepsTaken, nodesExpanded
    return findPathGetStats(self._pf)
end

return {
    ipf_create = ipf_create,
}

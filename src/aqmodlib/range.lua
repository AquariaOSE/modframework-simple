-- helper to parse strings like "1,3-5,10-" to contruct a range to easily check
-- whether a number is contained in it.

local M = {}
M.__index = M

function M.new(s)
    local parts = s:explode(",")
    local self = { on = {}, min = false, max = false }
    for i = 1, #parts do
        local n = s:match("^(%d)$")
        if n then
            n = tonumber(n)
            self.on[n] = true
        end
        local min, max = s:match("^(%d)-(%d)$")
        if min then
            min = tonumber(min)
            max = tonumber(max)
            for i = min,max do
                self.on[i] = true
            end
        end
        min = s:match("^(%d)-$")
        if min then
            min = tonumber(min)
            self.min = min
        end
        max = s:match("^-(%d)$")
        if max then
            max = tonumber(max)
            self.max = max
        end
    end
    return setmetatable(self, M)
end

function M:contains(x)
    if self.min and x >= self.min then
        return true
    end
    if self.max and x <= self.max then
        return true
    end
    return self.on[x] or false
end

rawset(_G, "Range", M)

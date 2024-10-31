-- Originally https://github.com/Yonaba/Jumper/blob/master/jumper/core/bheap.lua,
-- but then hacked into shape, eliminated recursion, and made much faster.

local floor = math.floor
local tins = table.insert
local tremove = table.remove

local function f_min(a,b) return a < b end

local function percolate_up(h, less, i)
    while i > 1 do
        local k = floor(i/2)
        if not less(h[k], h[i]) then
            h[k], h[i] = h[i], h[k]
        end
        i = k
    end
end

local function percolate_down(h, less, sz, i)
    while true do
        local L = 2*i
        local R = L + 1
        local mi
        if R > sz then
            if L > sz then
                return
            else
                mi = L
            end
        else
            if less(h[L], h[R]) then
                mi = L
            else
                mi = R
            end
        end
        if less(h[i], h[mi]) then
            return
        else
            h[i], h[mi] = h[mi], h[i]
            i = mi
        end
    end
end

-----------------------------------------------------

local heap = {}
heap.__index = heap
setmetatable(heap, heap)

function heap.new(comp)
    return setmetatable( { _sort = comp or f_min }, heap)
end

function heap:empty()
    return #self == 0
end

function heap:clear()
    for i = 1, #self do
        self[i] = nil
    end
end

function heap:push(item)
    if item then
        local i = #self + 1
        self[i] = item
        percolate_up(self, self._sort, i)
    end
end

function heap:pop()
    local sz = #self
    if sz > 0 then
        local root = self[1]
        self[1] = self[sz]
        self[sz] = nil
        if sz > 1 then
            percolate_down(self, self._sort, sz - 1, 1)
        end
        return root
    end
end
 
function heap:heapify(item)
    local sz = #heap
    if sz == 0 then
        return
    end
    if item then -- heapify from that item onwards
        local idx
        for i = 1, sz do
            if self[i] == item then
                percolate_down(self, self._sort, sz, i)
                percolate_up(self, self._sort, i)
                return
            end
        end
    else -- heapify the whole thing
        for i = floor(sz/2), 1, -1 do
            percolate_down(self,i)
        end
    end
end

local function leq(less, a, b)
    return less(a, b) and not less(b, a)
end

local function _verify(h, pos)
    local L = 2 * pos
    local R = L + 1
    local x = h[pos]
    return not x or (less(x, h[L]) and less(x, h[R]) and _verify(h, L) and _verify(h, R))
end

function heap:verify()
    return _verify(self, 0)
end

rawset(_G, "bheap", heap)

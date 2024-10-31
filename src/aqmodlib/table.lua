
local random = math.random
local floor = math.floor
local pairs = pairs
local type = type
local select = select
local next = next


-- does NOT handle loops/self-refs
local function fastdeepcopy(t, new)
    new = new or {}
    for i, x in pairs(t) do
        if type(x) == "table" then
            new[i] = fastdeepcopy(x)
        else
            new[i] = x
        end
    end
    return new
end
table.fastdeepcopy = fastdeepcopy

local function _deepcopyRec(t, target, used)
    used[t] = target
    for k, val in pairs(t) do
        local newk = k
        local newval = val
        if type(k) == "table" then
            newk = used[k] or _deepcopyRec(k, {}, used)
        end
        if type(val) == "table" then
            newval = used[val] or _deepcopyRec(val, {}, used)
        end
        target[newk] = newval
    end
    return target
end

-- handles self-loops and multi-references properly
function table.deepcopy(t, new)
    return _deepcopyRec(t, new or {}, {})
end

function table.shallowcopy(t, new)
    new = new or {}
    for i, x in pairs(t) do
        new[i] = x
    end
    return new
end

function table.clear(t)
    for k in next, t, nil do
        t[k] = nil
    end
end

function table.cleari(t)
    for i = 1, #t do
        t[i] = nil
    end
end

-- search for key in [1 .. #t] in sorted table
function table.bsearch(t, item)
    local L = 1
    local R = #t
    local i, p
    while L < R do
        i = L + floor((R-L) * 0.5)
        p = t[i]
        if p < item then
            L = i + 1
        else
            R = i
        end
    end
    if L == R and t[i] == item then
        return true, i
    end
    return false, i
end

-- index of item in t[1 .. #t]
function table.indexOf(t, item)
    for i = 1, #t do
        if t[i] == item then
            return i
        end
    end
end

-- Return index of element in table t that is not greater than item.
-- Assumes sorted table.
function table.lowerbound(t, item, first, count)
    count = count or #t
    first = first or 1
    local i, step
    while count > 0 do
        step = floor(count * 0.5)
        i = first + step
        if t[i] < item then
            i = i + 1
            first = i
            count = count - (step + 1)
        else
            count = step
        end
    end
    return first
end

function table.reverse(t)
    local len = #t+1
    for i=1, (len-1)/2 do
        t[i], t[len-i] = t[len-i], t[i]
    end
end

function table.count(t)
    local c = 0
    for _, _ in pairs(t) do
        c = c + 1
    end
    return c
end

function table.issorted(t, goes_before)
    local len = #t
    if len < 2 then
        return true
    end
    local x = t[1]
    local y
    if goes_before then
        for i = 2, len do
            y = t[i]
            if not goes_before(x, y) then
                return false
            end
            x = y
        end
    else
        for i = 2, len do
            y = t[i]
            if x > y then
                return false
            end
            x = y
        end
    end
    return true
end

do -- via http://lua.2524044.n2.nabble.com/A-stable-sort-td7648892.html

    local function insertion_sort( array, first, last, goes_before )
      for i = first + 1, last do
        local k = first
        local v = array[i]
        for j = i, first + 1, -1 do
          if goes_before( v, array[j-1] ) then
            array[j] = array[j-1]
          else
            k = j
            break
          end
        end
        array[k] = v
      end
    end

    local function merge( array, workspace, low, middle, high, goes_before )
      local i, j, k
      i = 1
      -- Copy first half of array to auxiliary array
      for j = low, middle do
        workspace[ i ] = array[ j ]
        i = i + 1
      end
      i = 1
      j = middle + 1
      k = low
      while true do
        if (k >= j) or (j > high) then
          break
        end
        if goes_before( array[ j ], workspace[ i ] )  then
          array[ k ] = array[ j ]
          j = j + 1
        else
          array[ k ] = workspace[ i ]
          i = i + 1
        end
        k = k + 1
      end
      -- Copy back any remaining elements of first half
      for k = k, j-1 do
        array[ k ] = workspace[ i ]
        i = i + 1
      end
    end


    local function merge_sort( array, workspace, low, high, goes_before )
      if high - low < 12 then
        insertion_sort( array, low, high, goes_before )
      else
        local middle = floor((low + high)/2)
        merge_sort( array, workspace, low, middle, goes_before )
        merge_sort( array, workspace, middle + 1, high, goes_before )
        merge( array, workspace, low, middle, high, goes_before )
      end
    end
    
    local function less(a, b)
        return a < b
    end
    
    -- use weak table to allow garbage collection, but don't reallocate all the time
    local _workspace = setmetatable({}, { __mode = "kv" })

    local function stable_sort( array, goes_before )
      local n = #array
      if n < 2 then  return array  end
      goes_before = goes_before or less
      local workspace = _workspace.sortbuf
      if not workspace then
        workspace = {}
        _workspace.sortbuf = workspace
      end
      --  Allocate some room.
      workspace[ floor( (n+1)/2 ) ] = array[1]
      merge_sort( array, workspace, 1, n, goes_before )
      return array
    end
    
    table.stablesort = stable_sort
end

function table.shuffle(tab, rnd)
    rnd = rnd or random
    for i = #tab, 2, -1 do
        local j = rnd(1, i)
        tab[i], tab[j] = tab[j], tab[i]
    end
    return tab
end

function table.expandtab(t, ex)
    local len = #ex
    local ins = #t
    for i = 1, len do
        inx = ins + 1
        t[ins] = ex[i]
    end
    for k, val in pairs(ex) do
        if not (type(k) == "number" and k <= len) then
            t[k] = val
        end
    end
end

function table.union(dst, ...)
    local n = select("#", ...)
    for i = 1, n do
        local src = select(i, ...)
        for k, val in pairs(src) do
            dst[k] = val
        end
    end
    return dst
end

-- returns # of values assigned
function table.assign(t, start, ...)
    local n = select("#", ...)
    for i = 1, n do
        t[start] = select(i, ...)
        start = start + 1
    end
    return n
end

function table.pack(...)
    return { n = select("#", ...), ... }
end

function table.pack2(...)
    local n = select("#", ...)
    return { n = n, ... }, n
end

-- shrink table so that #t returns <= n
-- op# does a binary search, so it's not accurate when there are holes
-- so we move on to remove elems until the hole is either big enough or the tail is clipped off completely
function table.shrink(t, n)
    local u = n
    while true do
        local len = #t
        if len <= n then
            return t
        end
        for i = u+1, len do
            t[i] = nil
        end
    end
end

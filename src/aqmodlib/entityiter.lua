-- (Re-entrant) entity iteration functions
-- Since getFirstEntity() / getNextEntity() / ... are non-reentrant and should be avoided

local ITER_DEBUG = not MOD_RELEASE

local type = type
local xxpcall = xxpcall
local selectfirst = selectfirst
local filterNearestEntities = filterNearestEntities
local getNextFilteredEntity = getNextFilteredEntity
--local getNextEntity = getNextEntity
--local getFirstEntity = getFirstEntity
local entity_getEntityType = entity_getEntityType
local entity_getPosition = entity_getPosition

local ITERSTACK = setmetatable({}, { __index = function(t, k) local x = {}; t[k] = x; return x end })
local STACKIDX = 0

local function _cleartail(tab, k)
    local e
    for i = k+1, #tab do
        e = tab[i]
        tab[i] = nil
        tab[e] = nil
    end
    return tab, k
end

local function _collectAllEntities(tab)
    local n
    tab, n = getEntityList(tab)
    -- be as lazy as possible: keep possibly associated data in tab intact, if needed they will be removed by _cleartail().
    if ITER_DEBUG then
        -- ... but for debugging, remove associated data immediately to catch misuse (expecting extra value when none was set)
        for i = 1, n do
            local e = tab[i]
            tab[e] = nil
        end
    end
    return _cleartail(tab, n)
end

local function _collectAllEntitiesFiltered(tab, ...)
    local n = filterNearestEntities(...)
    if n == 0 then
        if ITER_DEBUG then
            table.clear(tab)
        end
        return nil, 0
    end
    tab = tab or {}
    local nx = getNextFilteredEntity
    local e, dsq
    for i = 1, n do
        e, dsq = nx()
        tab[i] = e
        tab[e] = dsq
    end
    return _cleartail(tab, n)
end

local function _collectAllEntitiesNearEntity(tab, e, ...)
    if ITER_DEBUG then
        assert(not ITER_DEBUG or isEntity(e), tostring(e))
    end
    local x, y = entity_getPosition(e)
    return _collectAllEntitiesFiltered(tab, x, y, ...)
end

local function _iter1Full(tab, n, f, ...)
    for i = 1, n do
        f(tab[i], ...)
    end
end

local function _iter2Full(tab, n, f, ...)
    local e
    for i = 1, n do
        e = tab[i]
        f(e, tab[e], ...)
    end
end

local function _iter1RetIfTrue(tab, n, f, ...)
    for i = 1, n do
        if f(tab[i], ...) == true then
            return true
        end
    end
    return false
end

local function _iter1RetIfNotFalse(tab, n, f, ...)
    local ret
    for i = 1, n do
        ret = f(tab[i], ...)
        if ret then
            return ret
        end
    end
end

local function _iter2RetIfNotFalse(tab, n, f, ...)
    local e, ret
    for i = 1, n do
        e = tab[i]
        ret = f(e, tab[e], ...)
        if ret then
            return ret
        end
    end
end

local function _endIteration(ok, ...)
    STACKIDX = STACKIDX - 1
    if ok then
        return ...
    end
    error((...)) -- pass error along
end

local function _endIterationUnsafe(...)
    STACKIDX = STACKIDX - 1
    return ...
end

-- fill function: return array of entities, and the number of valid entries
-- iterator function: itf(tab, n, f, ...) -> walk over tab[1..n] and call f(e, ...) for each entity
-- fparams: how many params go to the fill function (= how many to skip for the main iteration)
local function _doIteration(fillf, itf, fparams, ...)
    STACKIDX = STACKIDX + 1
    -- use selectfirst() to strip any additional args that would confuse the filter
    local tab, n = fillf(ITERSTACK[STACKIDX], selectfirst(fparams, ...))
    if n > 0 then
        if ITER_DEBUG then
            return _endIteration(xxpcall(itf, errorLog, tab, n, select(fparams+1, ...))) -- skip params passed to filter
        else
            return _endIterationUnsafe(itf(tab, n, select(fparams+1, ...))) -- skip params passed to filter
        end
    end
    STACKIDX = STACKIDX - 1
end
_doIteration = addInstrumentation(_doIteration, "entity::_doIteration")


local function entity_DEBUG_getIterationStats()
    local N, ci, ce = #ITERSTACK, 0, 0
    for i = 1, N do
        for k, _ in pairs(ITERSTACK[i]) do
            if type(k) == "number" then
                ci = ci + 1
            else
                ce = ce + 1
            end
        end
    end
    return STACKIDX, N, ci, ce
end

----------------------------------------------------------------------------------------------------------

local function _showCircle(x, y, radius)
    if type(radius) ~= "number" then return end
    local q = createQuad("debugnoise")
    quad_setPosition(q, x, y)
    quad_setLayer(q, LR_DEBUG_TEXT)
    quad_setWidth(q, radius*2)
    quad_setHeight(q, radius*2)
    quad_color(q, 0, 0, 0)
    quad_delete(q, 1.5)
end


-- Runs a function for all entites. Returns true if processing was stopped early.
-- * f:      function to run. once it returns true, stop processing.
-- * param:  passed as additional parameter, as in f(entity, param)
-- * filter: if given, f will only be called if filter(entity, fparam) returns true
-- * fparam: passed to the filter function
local function _legacyHelper(e, f, param, ff, fparam)
    if f(e, param) == true then
        return true
    end
end
local function _legacyHelperFilter(e, f, param, ff, fparam)
    if (ff(e, fparam) and f(e, param)) == true then
        return true
    end
end
local function forAllEntities(f, param, filter, fparam)
    local callf, ff
    if not filter then
        callf = _legacyHelper
    elseif type(filter) == "string" then
        callf = _legacyHelperFilter
        ff = entity_isName
    else
        callf = _legacyHelperFilter
        ff = filter
    end
    return _doIteration(_collectAllEntities, _iter1RetIfTrue, 0, callf, f, param, ff, fparam)
--[[
    local e = getFirstEntity()
    local nx = getNextEntity
    if not filter then
        while e ~= 0 do
            if f(e, param) == true then
                return true
            end
            e = nx()
        end
    elseif type(filter) == "string" then
        while e ~= 0 do
            if entity_isName(e, filter) then
                if f(e, param) == true then
                    return true
                end
            end
            e = nx()
        end
    else
        while e ~= 0 do
            if filter(e, fparam) then
                if f(e, param) == true then
                    return true
                end
            end
            e = nx()
        end
    end
    return false
]]
end

-- unfiltered, variadic
local function forAllEntities2(...) -- f, ...
    return _doIteration(_collectAllEntities, _iter1RetIfTrue, 0, ...)
    --[[local e = getFirstEntity()
    local nx = getNextEntity
    while e ~= 0 do
        if f(e, ...) == true then
            return true
        end
        e = nx()
    end
    return false]]
end

-- generic. stops the iteration if function returns something non-false, then also returns that.
-- leave distance away/0/nil to iterate over all entities sorted by distance.
local function forAllEntitiesInRange(x, y, distance, ...)
    return _doIteration(_collectAllEntitiesFiltered, _iter1RetIfNotFalse, 3,   x, y, distance, ...)
    --_showCircle(x, y, distance)
    --[[if filterNearestEntities(x, y, distance) == 0 then
        return
    end
    local nx = getNextFilteredEntity
    local e = nx()
    local ret
    while e ~= 0 do
        ret = f(e, ...)
        if ret then
            return ret
        end
        e = nx()
    end]]
end


-- generic. stops the iteration if function returns true, then also returns true.
local function entity_forAllEntitiesInRange(me, distance, ...)
    return _doIteration(_collectAllEntitiesNearEntity, _iter1RetIfNotFalse, 3,   me,   distance, me, ...)
    --                                 -- Parameters for filterNearestEntities(<x, y>, distance, me)
    --[[local x, y = entity_getPosition(me)
    --_showCircle(x, y, distance)
    if filterNearestEntities(x, y, distance, me) == 0 then -- this ignores the passed in entity
        return
    end
    local nx = getNextFilteredEntity
    local e = nx()
    local ret
    while e ~= 0 do
        ret = f(e, ...)
        if ret then
            return ret
        end
        e = nx()
    end]]
end

local function _collectByET(tab, et)
    return _collectAllEntitiesFiltered(tab,    0, 0, 0, nil, et)
    --                                        ^-- params to filterNearestEntities()
end
local function forAllEntitiesOfEntityType(...) -- et, f, ...
    return _doIteration(_collectByET, _iter1RetIfNotFalse, 1, ...)
    --[[if filterNearestEntities(0, 0, 0, nil, et) == 0 then
        return
    end
    local nx = getNextFilteredEntity
    local e = nx()
    local ret
    while e ~= 0 do
        ret = f(e, ...)
        if ret then
            return ret
        end
        e = nx()
    end]]
end


----------------------------------------------------------------------------------------------------------

local function cleanup(mapchange)
    if mapchange then
        table.clear(ITERSTACK)
        STACKIDX = 0
    end
    modlib_onClean(cleanup)
end
cleanup()

----------------------------------------------------------------------------------------------------------



return {
    entity_DEBUG_getIterationStats = entity_DEBUG_getIterationStats,
    entity_INTERNAL_doIteration = _doIteration,
    entity_INTERNAL_collectAllEntities = _collectAllEntities,
    entity_INTERNAL_collectAllEntitiesFiltered = _collectAllEntitiesFiltered,
    entity_INTERNAL_collectAllEntitiesNearEntityFiltered = _collectAllEntitiesNearEntity,
    entity_INTERNAL_iter1Full = _iter1Full,
    entity_INTERNAL_iter2Full = _iter2Full,
    entity_INTERNAL_iter1RetIfNotFalse = _iter1RetIfNotFalse,
    entity_INTERNAL_iter2RetIfNotFalse = _iter2RetIfNotFalse,
    
    forAllEntities = forAllEntities,
    forAllEntities2 = forAllEntities2,
    forAllEntitiesInRange = forAllEntitiesInRange,
    entity_forAllEntitiesInRange = entity_forAllEntitiesInRange,
    forAllEntitiesOfEntityType = forAllEntitiesOfEntityType,
}

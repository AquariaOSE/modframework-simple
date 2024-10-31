local tins = table.insert
local sqrt = math.sqrt
local random = math.random
local min = math.min
local max = math.max
local pairs = pairs
local ipairs = ipairs
local lerp2 = math.lerp2
local clamp = math.clamp
local node_isEntityIn = node_isEntityIn
local entity_getNearestNode = entity_getNearestNode
local node_getShape = node_getShape
local node_getPosition = node_getPosition
local node_isPositionIn = node_isPositionIn
local obj_getPosition = obj_getPosition
local tlowerbound = table.lowerbound
local rangeTransform = rangeTransform
local PATHSHAPE_CIRCLE = PATHSHAPE_CIRCLE
local isInEditor = isInEditor

local __allnodes = false
local __allnodesLookup = false
local __nodesByLabel = false
local __nodeParams = false

local function getAllNodes()
    -- FIXME: the editor check here is BAD. tanks perf. don't do.
    -- but it SHOULD be done because nodes in the cache could be deleted in the editor.
    -- this becomes a problem if something updates even when paused and tries to iterate over nodes.
    --> then we get dangling pointers becaue the cache cleanup happens only when the editor is closed.
    -- ideally we'd invalidate the cache on the start of each frame when the editor is on...
    -- this would be fine and easy using framework's event system, but aqmodlib should NEVER use framework.
    -- so for now let's keep the pointers dangle and hope for the best. has worked fine for years, anyway.
    if __allnodes --[[and not isInEditor()]] then
        return __allnodes
    end

    -- this function is veeeeery hacky. Don't look!
    local n = getNaija() -- guaranteed to exist, so we use that
    local has = {} -- [ node => {x, y} ]

    local node
    while true do
        node = entity_getNearestNode(n)
        if has[node] then
            break
        end
        -- save old position and move it far away
        has[node] = { x = node_x(node), y = node_y(node) }
        node_setPosition(node, -999999, -999999)
    end -- as soon as we find a node we already have, we got all (hopefully)

    __allnodes = {}
    __allnodesLookup = {}
    __nodesByLabel = {}
    __nodeParams = {}
    -- restore old positions
    for node, pos in pairs(has) do
        node_setPosition(node, pos.x, pos.y)
        tins(__allnodes, node)
        __allnodesLookup[node] = true
        -- categorize by label
        local label = node_getLabel(node)
        local cat = __nodesByLabel[label]
        if not cat then
            cat = {}
            __nodesByLabel[label] = cat
        end
        tins(cat, node)
        --__nodeParams[node] = node_getParams(node) -- not here, causes stack overflow
    end
    debugLog("aqmodlib: cached " .. #__allnodes .. " nodes")
    return __allnodes
end

local function node_isValid(me)
    getAllNodes()
    return __allnodesLookup[me]
end

-- Runs a function for all nodes. Returns true if processing was stopped early.
-- * f:      function to run. once it returns true, stop processing.
-- * param:  passed as additional parameter, as in f(node, param)
-- * filter: if given, f will only be called if filter(node, fparam) returns true
-- * fparam: passed to the filter function
-- for convenience, if filter is a string, it will only process nodes with that name. (as long as the function node_getLabel() exists!)
local function forAllNodes(f, param, filter, fparam)
    local nodes = getAllNodes()
    if not filter then
        for _, n in pairs(nodes) do
            if f(n, param) == true then
                return true
            end
        end
    elseif type(filter) == "string" then
        local fstr = filter:lower()
        for _, n in pairs(nodes) do
            if node_getLabel(n) == fstr then
                if f(n, param) == true then
                    return true
                end
            end
        end
    else
        for _, n in pairs(nodes) do
            if filter(n, fparam) then
                if f(n, param) == true then
                    return true
                end
            end
        end
    end
    return false
end

local function forAllNodes2(f, ...)
    for _, n in pairs(getAllNodes()) do
        if f(n, ...) == true then
            return true
        end
    end
end

local function node_getRandomPoint(me, insideOffs)
    local xc, yc = node_getPosition(me) -- center
    local xs, ys = node_getSize(me) -- size
    if insideOffs then
        xs = max(0, xs - insideOffs)
        ys = max(0, ys - insideOffs)
    end
    if node_getShape(me) == PATHSHAPE_CIRCLE then
        local xa, ya = randVector(random() * xs * 0.5)
        return xc + xa, yc + ya
    else
        return (xc - (xs * 0.5)) + (random() * xs), (yc - (ys * 0.5)) + (random() * ys)
    end
end

-- i => 0:name, 1:content, 2:amount, ...
local function node_getParam(node, i)
    return string.explode(node_getName(node), " ", true)[i + 1] or ""
end

local function node_getParamString(node)
    return node_getName(node):match("^[%S]+%s(.*)$") or ""
end

-- removes name, returns list of trailing params
local function node_getParams(node)
    getAllNodes()

    local p = __nodeParams[node]
    if p then
        return p
    end
    
    -- old version, doesn't support the var=val syntax...
    --local t = string.explode(node_getName(node), " ", true)
    --table.remove(t, 1)
    
    ---new version
    local t = {}
    local i = 0
    local skipped
    for part in node_getName(node):gmatch"%S+" do
        if skipped then -- skip the actual node name (first entry)
            local a, b = part:match"([^=]+)=(.*)"
            if a then
                t[a] = b
            else
                i = i + 1
                t[i] = part
            end
        end
        skipped = true 
    end
    ----

    __nodeParams[node] = t
    return t
end

local function autotype(x)
    assert(type(x) == "string")
    if x == "nil" then
        return nil
    elseif x == "false" then
        return false
    elseif x == "true" then
        return true
    end
    return tonumber(x) or x
end

local function node_autoParams(node)
    return fun_map(node_getParams(node), autotype)
end

local function getNodesByLabel(label)
    local all = getAllNodes() -- also inits __nodesByLabel
    if (not label) or (label == "") then
        return all
    end
    return __nodesByLabel[label]
end

local function forAllNodesWithLabel(label, f, ...)
    local some = getNodesByLabel(label)
    if some then
        for _, node in pairs(some) do
            local res = f(node, ...)
            if res ~= nil then
                return res
            end
        end
    end
end

local function _getNearestNodeFromListWithinMe(me, list)
    local closest = 0
    local dmin
    if list then
        dmin = 9999999
        local x, y = node_getPosition(me)
        for _, n in pairs(list) do
            if n ~= me then
                local nx, ny = node_getPosition(n)
                if node_isPositionIn(me, nx, ny) then
                    local dx, dy = makeVector(x, y, nx, ny)
                    local d = dx*dx + dy*dy
                    if d < dmin then
                        closest = n
                        dmin = d
                    end
                end
            end
        end
    end
    return closest
end

local function _getNearestNodeToPosFromListFiltered(x, y, list, filter, ...)
    local closest = 0
    if list then
        local dmin = 9999999
        for _, n in pairs(list) do
            if (not filter) or filter(n, ...) then
                local nx, ny = node_getPosition(n)
                local dx, dy = makeVector(x, y, nx, ny)
                local d = dx*dx + dy*dy
                if d < dmin then
                    closest = n
                    dmin = d
                end
            end
        end
    end
    return closest
end

local function node_getNearestNodeWithinMe(me, label)
    assert(type(label) == "string", "node_getNearestNodeWithinMe: label must be string")

    -- try the easy way first
    local n = node_getNearestNode(me, label)
    if n == 0 then -- no node with this name on this map
        return 0
    end
    if node_isPositionIn(me, node_getPosition(n)) then
        return n
    end

    -- maybe there is a node that is not the closest but still inside us, search manually
    -- (possible for long, thin nodes)
    local candidates = getNodesByLabel(label)
    return _getNearestNodeFromListWithinMe(me, candidates)
end

local function node_forNodeListWithinMe(me, nodes, f, ...)
    for _, n in pairs(nodes) do
        if n ~= me then
            local nx, ny = node_getPosition(n)
            if node_isPositionIn(me, nx, ny) then
                if f(n, ...) == true then
                    return true
                end
            end
        end
    end
end

local function node_forAllNodesWithLabelWithinMe(me, label, f, ...)
    assert(type(label) == "string", "node_forAllNodesWithLabelWithinMe: label must be string")

    local nodes = getNodesByLabel(label)
    if nodes then
        return node_forNodeListWithinMe(me, nodes, f, ...)
    end
end

local function node_forAllNodesWithinMe(me, f, ...)
    return node_forNodeListWithinMe(me, getAllNodes(), f, ...)
end

-- TODO: rewrite to entity iter
local function node_getAllEntitiesWithin(me, t)
    local cx, cy = node_getPosition(me)

    local d
    local circle = node_getShape(me) == PATHSHAPE_CIRCLE
    local w, h = node_getSize(me)
    if circle then
        d = w / 2
    else
        d = vector_getLength(w / 2, h / 2)
    end

    if filterNearestEntities(cx, cy, d) == 0 then
        return
    end

    t = t or {}
    local e
    local nx = getNextFilteredEntity
    if circle then
        e = nx()
        while e ~= 0 do
            tins(t, e)
            e = nx()
        end
    else
        e = nx()
        while e ~= 0 do
            if node_isEntityIn(me, e) then
                tins(t, e)
            end
            e = nx()
        end
    end
    return t
end

-- TODO: rewrite to entity iter
local function node_forAllEntitiesWithin(me, f, ...)
    local cx, cy = node_getPosition(me)

    local d
    local circle = node_getShape(me) == PATHSHAPE_CIRCLE
    local w, h = node_getSize(me)
    if circle then
        d = w / 2
    else
        d = vector_getLength(w / 2, h / 2)
    end

    if filterNearestEntities(cx, cy, d) == 0 then
        return
    end

    local nx = getNextFilteredEntity
    if circle then
        local e = nx()
        while e ~= 0 do
            local ret = f(e, ...)
            if ret then
                return ret
            end
            e = nx()
        end
    else
        local e = nx()
        while e ~= 0 do
            if node_isEntityIn(me, e) then
                local ret = f(e, ...)
                if ret then
                    return ret
                end
            end
            e = nx()
        end
    end
end

local function node_getVectorToEntity(me, ent)
    local x, y = node_getPosition(me)
    return makeVector(x, y, entity_getPosition(ent))
end

local function node_getBoundingRadius(me)
    local w, h = node_getSize(me)
    if node_getShape(me) == PATHSHAPE_CIRCLE then
        return w
    else
        w = w * 0.5
        h = h * 0.5
        return sqrt(w*w + h*h)
    end
end

local function node_getDistanceToPoint(me, x, y)
    return vector_getLength(makeVector(x, y, node_getPosition(me)))
end

local function node_isPositionInRange(me, x, y, range)
    x, y = makeVector(x, y, node_getPosition(me))
    return vector_isLength2DIn(x, y, range)
end

local function node_getDistanceToNode(me, node)
    return node_getDistanceToPoint(me, node_getPosition(node))
end

local function node_getDistanceToEntity(me, e)
    return entity_getDistanceToPoint(e, node_getPosition(me))
end

local function node_getPathLen(me)
    local len = 0
    local px, py = node_getPosition(me)
    local nx, ny, dx, dy
    local i = 1
    while true do
        nx, ny = node_getPathPosition(me, i)
        if nx == 0 and ny == 0 then
            return len, i
        end
        dx, dy = nx-px, ny-py
        len = len + sqrt(dx*dx + dy*dy)
        px, py = nx, ny
        i = i + 1
    end
end

-- returns function that takes [0 .. 1] and returns a position along the path (0 = start, ..., 1 = end)
local function node_createPathInterpolator(me)
    local len = 0
    local x, y = node_getPosition(me)
    local i = 1
    local d
    local idxs, xs, ys = {}, {}, {}
    while true do
        xs[i], ys[i], idxs[i] = x, y, len
        local nx, ny = node_getPathPosition(me, i)
        if nx == 0 and ny == 0 then
            break
        end
        len = len + vector_getLength(makeVector(x, y, nx, ny))
        x, y = nx, ny
        i = i + 1
    end

    if len == 0 then -- degenerate case
        return function() return x, y end
    end

    local mul = 1 / len
    for k, val in pairs(idxs) do
        idxs[k] = val * mul
    end

    i = i - 1
    return function(k)
        local a = clamp(tlowerbound(idxs, clamp(k, 0, 1)) - 1, 1, i)
        local b = a + 1
        local t1 = idxs[a]
        return lerp2(xs[a], ys[a], xs[b], ys[b], (k-t1) / (idxs[b]-t1))
    end
end

local function node_getNodesFromListOnPath(me, list, start, filter, ...)
    local ret = {}
    if list then
        local N = #list
        local seen = { me } -- don't include ourselves
        while true do
            local x, y = node_getPathPosition(me, start)
            if x == 0 and y == 0 then
                break
            end
            start = start + 1
            for i = 1, N do
                local node = list[i]
                if node_isPositionIn(node, x, y) and (not seen[node]) and ((not filter) or filter(node, ...)) then
                    seen[node] = true
                    tins(ret, node)
                end
            end
        end
    end
    return ret
end

-- get all nodes that overlap my tail/path nodes (but not the main node body pos)
local function node_getNodesOnPath(me, name, ...)
    local list = getNodesByLabel(name)
    return node_getNodesFromListOnPath(me, list, 1, ...)
end

-- get all nodes that overlap my path nodes (all of them, incl body)
local function node_getNodesOnPath0(me, name, ...)
    local list = getNodesByLabel(name)
    return node_getNodesFromListOnPath(me, list, 0, ...)
end

local function forAllNodesNearPosition(x, y, distance, f, ...)
    for _, node in pairs(getAllNodes()) do
        if node_isPositionInRange(node, x, y, distance) then
            f(node, ...)
        end
    end
end

local function node_forAllNodesInRange(me, distance, f, ...)
    local x, y = node_getPosition(me)
    for _, node in pairs(getAllNodes()) do
        if node ~= me and node_isPositionInRange(node, x, y, distance) then
            f(node, ...)
        end
    end
end

local function getNearestNodeToPosition(x, y, label, filter, ...)
    local list = getNodesByLabel(label)
    return _getNearestNodeToPosFromListFiltered(x, y, list, filter, ...)
end

local function node_isObjIn(me, obj)
    return node_isPositionIn(me, obj_getPosition(obj))
end

local function node_getNearestEntityWithEVT(me, distance, evt)
    local x, y = node_getPosition(me)
    if filterNearestEntities(x, y, distance) == 0 then
        return 0
    end
    local nx = getNextFilteredEntity
    local e = nx()
    while e ~= 0 do
        if egetv(e, EV_TYPEID) == evt then
            return e
        end
        e = nx()
    end
    return 0
end

local function node_getEnclosingNode(node, othername)
    local list = getNodesByLabel(othername)
    if list then
        local x, y = node_getPosition(node)
        for i = 1, #list do
            if node_isPositionIn(list[i], x, y) then
                return list[i]
            end
        end
    end
    return 0
end

-- writes to xs[], ys[]; returns len
local function node_collectPathPoints(node, xs, ys)
    local i = 0
    while true do
        local x, y = node_getPathPosition(node, i)
        if x == 0 and y == 0 then
            break
        end
        i = i + 1
        xs[i] = x
        ys[i] = y
    end
    return i
end

local function node_createPathSpline(node, deg)
    local xs, ys = {}, {}
    local n = node_collectPathPoints(node, xs, ys)
    return bspline.new2d(xs, ys, deg or 1)
end

local function node_toggleTilesWithTag(node, tag, on)
    local function cb(idx, gfx, vis, layer, tagg, x, y)
        if node_isPositionIn(node, x, y) then
            vis = on
        end
        return vis
    end
    local num = refreshElementsWithTagCallback(tag, cb)
    reconstructGrid()
    return num
end

-- returns xmin, ymin, xmax, ymax
local function node_getBox(me)
    local x, y = node_getPosition(me)
    local w, h = node_getSize(me)
    local w2, h2 = w * 0.5, h * 0.5
    return x - w2, y - h2, x + w2, y + h2
end

local function node_getUpperLeftCorner(me)
    local x, y = node_getPosition(me) -- center
    local w, h = node_getSize(me)
    if node_getShape(me) == PATHSHAPE_CIRCLE then
        local diag = w * 0.5
        return x - diag, y - diag
    end
    local w2, h2 = w * 0.5, h * 0.5
    return x - w2, y - h2
end

local function cleanup()
    __allnodes = false
    __nodeParams = false
    __nodesByLabel = false
    __allnodesLookup = false
    modlib_onClean(cleanup)
end
cleanup()

return {
    getAllNodes = getAllNodes,
    forAllNodes = forAllNodes,
    forAllNodes2 = forAllNodes2,
    forAllNodesNearPosition = forAllNodesNearPosition,
    getNearestNodeToPosition = getNearestNodeToPosition,
    node_isValid = node_isValid,
    node_getRandomPoint = node_getRandomPoint,
    node_getParamString = node_getParamString,
    node_getParam = node_getParam,
    node_getParams = node_getParams,
    node_autoParams = node_autoParams,
    getNodesByLabel = getNodesByLabel,
    forAllNodesWithLabel = forAllNodesWithLabel,
    node_getNearestNodeWithinMe = node_getNearestNodeWithinMe,
    node_getVectorToEntity = node_getVectorToEntity,
    node_getAllEntitiesWithin = node_getAllEntitiesWithin,
    node_getBoundingRadius = node_getBoundingRadius,
    node_isPositionInRange = node_isPositionInRange,
    node_getDistanceToPoint = node_getDistanceToPoint,
    node_getDistanceToEntity = node_getDistanceToEntity,
    node_getDistanceToNode = node_getDistanceToNode,
    node_getPathLen = node_getPathLen,
    node_forAllEntitiesWithin = node_forAllEntitiesWithin,
    node_forNodeListWithinMe = node_forNodeListWithinMe,
    node_forAllNodesWithLabelWithinMe = node_forAllNodesWithLabelWithinMe,
    node_forAllNodesWithinMe = node_forAllNodesWithinMe,
    node_createPathInterpolator = node_createPathInterpolator,
    node_getNodesFromListOnPath = node_getNodesFromListOnPath,
    node_getNodesOnPath = node_getNodesOnPath,
    node_getNodesOnPath0 = node_getNodesOnPath0,
    node_forAllNodesInRange = node_forAllNodesInRange,
    node_isObjIn = node_isObjIn,
    node_getNearestEntityWithEVT = node_getNearestEntityWithEVT,
    node_getEnclosingNode = node_getEnclosingNode,
    node_collectPathPoints = node_collectPathPoints,
    node_createPathSpline = node_createPathSpline,
    node_toggleTilesWithTag = node_toggleTilesWithTag,
    node_getBox = node_getBox,
    node_getUpperLeftCorner = node_getUpperLeftCorner,
}

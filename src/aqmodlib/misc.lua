
local function isInGame()
    return not (isInEditor() or isInGameMenu() or isPaused())
end

local function setLayerVisible(layer, on)
    return setElementLayerVisible(layer - LR_ELEMENTS1, on)
end

local function getMinimapPosition()
    local vx, vy = getScreenVirtualOff()
    return 800 - 56 + vx, 600 - 56 + vy -- FIXME: verify this
end

local function constrainMouseCircleWindow(cx, cy, radius)
    local mx, my = getMousePos()
    local dx, dy = makeVector(cx, cy, mx, my)
    if not vector_isLength2DIn(dx, dy, radius) then
        dx, dy = vector_setLength(dx, dy, radius)
        dx, dy = dx + cx, dy + cy
        setMousePos(dx, dy)
        return true, dx, dy
    end
    return false, mx, my
end

local function constrainMouseCircleWorld(cx, cy, radius)
    local mx, my = getMouseWorldPos()
    local dx, dy = makeVector(cx, cy, mx, my)
    if not vector_isLength2DIn(dx, dy, radius) then
        dx, dy = vector_setLength(dx, dy, radius)
        dx, dy = dx + cx, dy + cy
        setMousePos(toWindowFromWorld(dx, dy))
        return true, dx, dy
    end
    return false, mx, my
end

local function setMouseWorldPos(x, y)
    return setMousePos(toWindowFromWorld(x, y))
end

local KEY2LR = {
    [-6] = LR_PARALLAX_6,
    [-5] = LR_PARALLAX_5,
    [-4] = LR_PARALLAX_4,
    [-3] = LR_PARALLAX_3,
    [-2] = LR_PARALLAX_2,
    [-1] = LR_PARALLAX_1,
    [1] = LR_ELEMENTS1,
    [2] = LR_ELEMENTS2,
    [3] = LR_ELEMENTS3,
    [4] = LR_ELEMENTS4,
    [5] = LR_ELEMENTS5,
    [6] = LR_ELEMENTS6,
    [7] = LR_ELEMENTS7,
    [8] = LR_ELEMENTS8,
    [9] = LR_ELEMENTS9,
}

local function getLayerFromEditorKey(k)
    return assert(KEY2LR[k], "unhandled layer key")
end

return {
    isInGame = isInGame,
    setLayerVisible = setLayerVisible,
    getMinimapPosition = getMinimapPosition,
    constrainMouseCircleWindow = constrainMouseCircleWindow,
    constrainMouseCircleWorld = constrainMouseCircleWorld,
    getLayerFromEditorKey = getLayerFromEditorKey,
    setMouseWorldPos = setMouseWorldPos,
}

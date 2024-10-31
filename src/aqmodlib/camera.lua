
-- get globalscale -- afaik there is no API function for this, use this as workaround
-- --> now it's in the API.
--[[local function getZoom()
    local x, y = entity_getPosition(getNaija())
    local nx = x + 100
    local ny = y + 100
    local wx, wy = toWindowFromWorld(x, y)
    local wx2, wy2 = toWindowFromWorld(nx, ny)
    
    local dx = math.abs(wx2 - wx)
    
    local zoom = dx / 100
    --debugLog("zoom: " .. zoom)
    
    return zoom
end]]

-- give position on the screen, return position in-game
--[[local function toWorldFromWindow(wx, wy)
    local cx, cy = getScreenCenter()
    local zoom =  getZoom()
    return cx + (-400 + wx) / zoom, cy + (-300 + wy) / zoom
end]]



return {
    --toWorldFromWindow = toWorldFromWindow,
    --getZoom = getZoom,
}

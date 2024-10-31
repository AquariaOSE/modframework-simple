
local max = math.max

local function quad_setFullscreen(q)
    local vx, vy = getScreenVirtualOff()
    quad_setWidth(q, 800 + 2*vx)
    quad_setHeight(q, 600 + 2*vy)
    quad_setPosition(q, 400, 300)
    quad_followCamera(q, 1)
end

local function quad_setFullscreenAspect(q, aspect)
    local vx, vy = getScreenVirtualOff() 
    local m = max((800 + 2*vx) * (aspect or 1), 600 + 2*vy)
    quad_setWidth(q, m)
    quad_setHeight(q, m)
    quad_setPosition(q, 400, 300)
    quad_followCamera(q, 1)
end

return {
    quad_setFullscreen = quad_setFullscreen,
    quad_setFullscreenAspect = quad_setFullscreenAspect,
}

if rawget(_G, "MOD_RELEASE") == nil then
    MOD_RELEASE = false
end

local function warnLog(s, level)
    if MOD_RELEASE then
        return debugLog(s)
    end
    return errorLog(s, (level or 0) + 1)
end

local function debugShowAngle(x, y, a, t)
    local q = createQuad("vector")
    quad_setPosition(q, x, y)
    quad_rotate(q, a)
    if t ~= false then
        quad_setPauseLevel(q, 99)
        quad_delete(q, t or 0.3)
    end
    return q
end

local function debugShowVector(x, y, vx, vy, ...)
    local a = vector_getAngleDeg(vx, vy)
    return debugShowAngle(x, y, a, ...)
end

local function debugShowRange(x, y, r, t)
    local q = createQuad("debugcircle")
    quad_setPosition(q, x, y)
    -- correction factor, png is 128x128 but the circle is only 100px in diameter
    -- plus we want to show a radius, so x2 it is
    local s = r / 100 * 2
    quad_scale(q, s, s)
    if t ~= false then
        quad_setPauseLevel(q, 99)
        quad_delete(q, t or 0.3)
    end
    return q
end

return {
    warnLog = warnLog,
    debugShowAngle = debugShowAngle,
    debugShowVector = debugShowVector,
    debugShowRange = debugShowRange,
}

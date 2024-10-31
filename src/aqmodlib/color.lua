local abs = math.abs
local min = math.min
local max = math.max
local floor = math.floor
local clamp = math.clamp
local vector_getLength = vector_getLength

local function color_getHealthPercRGB(x)
    x = clamp(x, 0, 1)
    local r, g, b = 1-x, x, x*0.5
    local len = vector_getLength(r, g) -- this intentionally ignores the blue channel
    local m = 1 / len
    return r*m, g*m, b*m
end

local function color_HSVtoRGB(h, s, v)
    local f = (h / 60)
    local i = floor(f)
    f = f - i
    local p = v * (1 - s)
    local q = v * (1 - (s*f))
    local t = v * (1 - (s * (1-f)))
    if i == 0 then
        return v, t, p
    elseif i == 1 then
        return q, v, p
    elseif i == 2 then
        return p, v, t
    elseif i == 3 then
        return p, q, v
    elseif i == 4 then
        return t, p, v
    elseif i == 5 then
        return v, p, q
    end
    return 0, 0, 0 -- shouldn't reach this
end

-- h in [0..360); s, v in [0, 1]
-- from http://lolengine.net/blog/2013/01/13/fast-rgb-to-hsv
local function color_RGBtoHSV(r, g, b)
    local K = 0.0
    if g < b then
        g, b = b, g
        K = -1.0
    end
    local min_gb = b
    if r < g then
        r, g = g, r
        K = -2.0 / 6.0 - K
        min_gb = min(g, b)
    end
    local chroma = r - min_gb
    return
        360.0 * abs(K + (g - b) / (6.0 * chroma + 1e-20)), -- h
        chroma / (r + 1e-20), -- s
        r -- v
end

--[[
local function color_RGBtoHSV(r, g, b)
    local M = math.max(r, g, b)
    local m = math.min(r, g, b)
    local h
    if M == m then
        h = 0
    elseif M == r then
        h = 60 * (    ((g-b) / (M - m)))
    elseif M == g then
        h = 60 * (2 + ((b-r) / (M - m)))
    elseif M == b then
        h = 60 * (4 + ((r-g) / (M - m)))
    end
    if h < 0 then
        h = h + 360
    end
    local s
    if M == 0 then
        s = 0
    else
        s = (M - m) / M
    end
    return h, s, M
end
]]

return {
    color_getHealthPercRGB = color_getHealthPercRGB,
    color_HSVtoRGB = color_HSVtoRGB,
    color_RGBtoHSV = color_RGBtoHSV,
}


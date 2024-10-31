local floor = math.floor

local function time_splitHMS(raw)
    local ms = raw % 1
    raw = floor(raw) -- do this early to avoid precision problems
    local h = floor(raw / 3600)
    raw = raw - h * 3600
    local m = floor(raw / 60)
    raw = raw - m * 60
    return h, m, raw, ms
end


return {
    time_splitHMS = time_splitHMS,
}

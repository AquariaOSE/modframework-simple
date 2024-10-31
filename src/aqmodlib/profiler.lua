local getPerformanceCounter = getPerformanceCounter
local getPerformanceFreq = getPerformanceFreq

if rawget(_G, "DEBUG_ENABLE_PROFILER") == nil then
    DEBUG_ENABLE_PROFILER = MOD_DEVMODE
end

local nullmeta = { __index = function() return 0 end }
local PROFILER = setmetatable({}, nullmeta)
local PROFILER_T = setmetatable({}, nullmeta)

rawset(_G, "PROFILER", PROFILER)
rawset(_G, "PROFILER_T", PROFILER_T)

local function ret(fn, t1, ...)
    PROFILER_T[fn] = PROFILER_T[fn] + ((getPerformanceCounter() - t1) / getPerformanceFreq())
    return ...
end

-- return new function that wraps passed function and adds time and callcount profiling
local function addInstrumentation(f, fn)
    assert(fn, "name missing")
    if not f then
        error("function missing: " .. fn)
    end
    if not DEBUG_ENABLE_PROFILER then
        return f
    end
    debugLog("Add profiling instrumentation to '" .. fn .. "'")

    return function(...)
        PROFILER[fn] = PROFILER[fn] + 1
        local t1 = getPerformanceCounter()
        return ret(fn, t1, f(...))
    end
end

return {
    addInstrumentation = addInstrumentation,
}

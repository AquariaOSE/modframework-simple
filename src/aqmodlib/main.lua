
local function include(file)
    debugLog("modlib: include: " .. file)
    local ok, ret = pcall(dofile, "src/aqmodlib/" .. file)
    --local ok, ret = xpcall(function() return dofile("src/aqmodlib/" .. file) end,
    --    function(err) errorLog(tostring(err) .. "\n" .. debug.traceback()) end)
    if ok then
        return ret
    else
        errorLog("modlib: include(" .. file .. ") error: \n" .. ret)
    end
end

local function globalize(tab)
    if not tab then return end
    for i, x in pairs(tab) do
        if type(i) == "string" and type(x) == "function" then
            debugLog("modlib: add global function: " .. i)
            rawset(_G, i, x)
        end
    end
end

local function import(file)
    return globalize(include(file .. ".lua"))
end

local cleanupfuncs = {}

-- must be called when entering a new map,
-- so that cached values valid only on one map can be erased
rawset(_G, "modlib_cleanup", function(mapchange)
    local todo = cleanupfuncs
    debugLog("aqmodlib: Processing " .. #todo .. " cleanup hooks")
    cleanupfuncs = {}
    for _, f in pairs(todo) do
        f(mapchange)
    end
end)

rawset(_G, "modlib_onClean", function(f)
    table.insert(cleanupfuncs, f)
end)


-- additional plain-Lua stuff (not related to aquaria at all)
import "luafunc"
import "string"
import "table"
import "sandbox"
import "debugx"
import "gc"
import "interpolated"
import "tq"
import "math"
import "rng"
import "functional"
import "serialize"
import "lfa"
import "statemachine"
import "bspline"
import "markov"
import "bheap"
import "time"
import "range"

if rawget(_G, "debug") and rawget(_G, "os") then
    local ProFi = include "profi.lua"
    rawset(_G, "ProFi", ProFi)
end

import "profiler"

-- aquaria-specific v global management
import "v"

-- depends on v, tq and table.* extensions
import "fragment"

-- mostly aquaria-specific
import "defs"

import "color"
import "interface"
import "vector"
import "geom"
import "obj"
import "quad"
import "entityiter"
import "entity"
import "bone"
import "node"
import "camera"
import "superfx"
import "shot"
import "cinematic"
import "misc"
import "sfx"
import "shader"
import "songline"
import "ipf"
import "datacache"
import "utilclasses"
import "debugutil"
import "doorhelper"
import "circuitnetwork"
import "circuitnetwork-modules"

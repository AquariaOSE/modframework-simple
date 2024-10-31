-- couple functions that depend on an update() call,
-- can't just provide those in a library that's not supposed to have state,
-- so they go here to keep things clean

-- Also, this detours the grid reconstruction functions.
-- Those are pretty expensive to call, and if a sliding door calls this once a frame
-- it's maybe not a problem, but in case multiple doors are operated at the same time
-- this quickly adds up and may cause stutter.
-- Therefore only reconstruct the grid a couple times per second regardless of how often
-- the function is called.

local M = {}

local min = math.min

local RECONSTRUCT_GRID_DELAY = 0.2

local MAPTIME
local reconstructEGTimer
local reconstructGTimer
local reconstructEGScheduled
local reconstructGScheduled

-- guard against reloading
local originalReconstructEntityGrid = rawget(_G, ".orig.reconstructEntityGrid")
local originalReconstructGrid = rawget(_G, ".orig.reconstructGrid")

local function _reconstructGridNow()
    reconstructGScheduled = false
    reconstructGTimer = RECONSTRUCT_GRID_DELAY
    debugLog("Reconstruct grid...") -- expensive, so we log it
    originalReconstructGrid()
end

local function _reconstructEntityGridNow()
    reconstructEGScheduled = false
    reconstructEGTimer = RECONSTRUCT_GRID_DELAY
    --debugLog("Reconstruct entity grid...") -- not quite so expensive, don't bother
    originalReconstructEntityGrid()
end

local function delayReconstructEntityGrid()
    if reconstructEGTimer <= 0 then -- timer expired? just update now and set the timer
        _reconstructEntityGridNow()
    else
        reconstructEGScheduled = true -- last reconstruct wasn't so long ago, delay until timer expires
    end
end

local function delayReconstructGrid()
    if reconstructGTimer <= 0 then
        _reconstructGridNow()
    else
        reconstructGScheduled = true
    end
end

local function getMapTime()
    return MAPTIME
end

function M.init()
    MAPTIME = 0
    
    reconstructEGScheduled = false
    reconstructEGTimer = 0

    reconstructGScheduled = false
    reconstructGTimer = 0
end

function M.postInit()
end

function M.update(dt)
    MAPTIME = MAPTIME + dt
    
    -- let the timer expire, but only reconstruct if there was another delayed call in the meantime
    if reconstructEGTimer >= 0 then
        reconstructEGTimer = reconstructEGTimer - dt
        if reconstructEGScheduled and reconstructEGTimer <= 0 then
            _reconstructEntityGridNow()
        end
    end
    if reconstructGTimer >= 0 then
        reconstructGTimer = reconstructGTimer - dt
        if reconstructGScheduled and reconstructGTimer <= 0 then
            _reconstructGridNow()
        end
    end
    
end


if not originalReconstructEntityGrid then
    originalReconstructEntityGrid = _G.reconstructEntityGrid
    rawset(_G, ".orig.reconstructEntityGrid", originalReconstructEntityGrid)
end
_G.reconstructEntityGrid = delayReconstructEntityGrid

if not originalReconstructGrid then
    originalReconstructGrid = _G.reconstructGrid
    rawset(_G, ".orig.reconstructGrid", originalReconstructGrid)
end
_G.reconstructGrid = delayReconstructGrid
    
rawset(_G, "getMapTime", getMapTime)

return M

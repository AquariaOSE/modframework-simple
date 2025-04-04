-- This script is loaded on every map load. Set a couple variables for the rest of the framework.

-- Release version of the mod. Turns off all debugging features if set to true.
local MOD_RELEASE = false

-- Enable extra developer things that may interfere with regular gameplay.
-- Also reloads ALL library code on every map load if this is on (takes longer).
local MOD_DEVMODE = true


-- export globals
rawset(_G, "MOD_DEVMODE", MOD_DEVMODE)
rawset(_G, "MOD_RELEASE", MOD_RELEASE)

-- export isDebug() function that some entities use to check whether to display extra debug info
rawset(_G, "isDebug", function() return MOD_DEVMODE end)

dofile("defines.lua")

-- Initial startup
-- For unused game flags, see
--   https://github.com/AquariaOSE/Aquaria/blob/master/Aquaria/ScriptInterface.cpp
-- and search for FLAG_SONGCAVECRYSTAL.
-- Anything that doesn't show up in this list is definitely unused and can be used for mods.
local FLAG_STARTUP = 1
local VERSION = 1

local saveVersion = getFlag(FLAG_STARTUP) -- this is initially 0
if saveVersion == 0 then
    -- In here, do anything you want to be done exactly once, when the mod is loaded for the first time.
    -- Since this is run on every map load, you may do save migration if something changes drastically
    -- and your code needs to react to an older savefile.
    
    learnSong(SONG_ENERGYFORM)
    learnSong(SONG_SPIRITFORM)
    learnSong(SONG_BIND)
    
    setFlag(FLAG_STARTUP, VERSION) -- this is stored in the savefile also
end

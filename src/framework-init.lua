-- This script is intended to be run as early as possible,
-- **once per map load**
-- to load all of the framework code and register a couple things.
-- Works in conjunction with node_logic.lua

local loaded = rawget(_G, "._framework-init-done")

if not loaded or MOD_DEVMODE then
    -- enable extra warnings against potential bugs. highly recommended. should be first.
    dofile("src/_strict.lua")
    
    dofile("mod-config.lua") -- always do this after strict
    dofile("src/aqmodlib/main.lua")
    rawset(_G, "._framework-init-done", true)
else
    dofile("mod-config.lua")
end

-- This is to notify aqmodlib that the map was reloaded and it needs to flush all of its caches.
modlib_cleanup(true)

-- For completeness:
-- Whenever the editor is closed and the game is resumed, some light flush needs to be done
-- for things that have been cached and need to be updated because the editor might have
-- changed something that only the editor can change (ie. not passing true is a weaker flush).
-- This is taken care of by node_logic.lua
--modlib_cleanup() -- do NOT do this here.

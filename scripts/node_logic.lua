-- This node is the backbone of all mod scripting.
-- This is basically a plugin manager; a single node that loads a set of plugins,
-- each doing its own stuff.

-- Exactly one (!) logic node must be placed in each map.

-- This version is for modframework-simple and takes care of loading aqmodlib right here in this file.

-- ######################
-- There is one downside to this simple version:
-- You can't use any aqmodlib code in li.lua's init(). All other functions are ok.
-- Move your code to postInit() if you need to.
-- It may appear to work regardless, but is likely to break when you load a saved game.
-- You have been warned.
-- ######################


dofile("src/framework-init.lua")

v.logic = false

v.lastAction = false
v.lastActionState = false
v.firstUpdate = true

local function doCall(fn, ...)
    local L = v.logic
    for i = 1, #L do
        local f = L[i][fn]
        if f then
            f(...)
        end
    end
end

function init(me)
    
    node_setCatchActions(me, true)
    node_setSpiritFreeze(me, false)
    node_setPauseFreeze(me, false)
    
    v.tq = tq_create()
    v.logic = dofile("src/logic/main.lua")

    doCall("init")
end

function update(me, dt)
    local v = v
    local paused = isPaused()
    local worldpaused = isWorldPaused()
    
    DTALWAYS = dt
    DT = ((paused or worldpaused) and 0) or dt
    
    v.lastAction = false
    v.lastActionState = false
    
    if not v.logic then -- if loading plugins failed
        return
    end
    
    if v.firstUpdate then
        v.firstUpdate = false
        doCall("postInit")
    end
    
    if paused then
        doCall("updatePaused", dt)
    else
        if not worldpaused then
            v.tq:update(dt)
            doCall("update", dt)
        end
        doCall("updateAlways", dt)
    end
end
update = addInstrumentation(update, "/NODE/LOGIC")

function action(me, id, state)
    --debugLog("core ac: " .. id .. " - " .. state)
    if v.lastAction == id and v.lastActionState == state then
        return
    end
    
    v.lastAction = id
    v.lastActionState = state
    
    if id == ACTION_TOGGLESCENEEDITOR then
        -- whenever the editor is opened, there's a chance of things breaking
        -- due to nodes/entities/etc being added or removed.
        -- This should prevent the worst. (Reloads nodes among many other things)
        -- The isInEditor() is true exactly when we're in the editor and tabbing out.
        if state == 0 and isInEditor() then
            modlib_cleanup()
        end
    end
    
    doCall("action", id, state)
end

-- using LR_PROGRESS as editor overlay
local LayerIndex = LR_PROGRESS - LR_ELEMENTS1 -- HACK: game does this, but has no range check; see Game::setElementLayerVisible

local M = {}

M.init = function()
    setElementLayerVisible(LayerIndex, false)
end

if not MOD_DEVMODE then
    return
end
-------------------------------------------------------------------

M.ineditor = false

M.postInit = function()
end

local function checkEditor()
    local edit = isInEditor()
    if edit ~= M.ineditor then
        --debugLog("editor overlay: " .. tostring(edit))
        M.ineditor = edit
        setElementLayerVisible(LayerIndex, edit)
    end
end

M.updateAlways = checkEditor
M.updatePaused = checkEditor

return M

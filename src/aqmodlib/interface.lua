-- all interface functions and allowed globals used by the game.
-- also adds additional custom interface function names

-- TODO: move to modconfig
local EXTRA_INTERFACE_FUNCTIONS =
{
    -- custom ones
    earlyInit = true, -- for nodes -- run before entity init
    updateFrozen = true, -- for entities -- ran instead of update() if frozen
    deleted = true, -- for entities -- called just before an entity is deleted
    hearNoise = true, -- for entities -- called when near enough to noise source
    killedEntity = true, -- for entities -- called when one entity kills another
    activateByChar = true -- for both -- called when a char activates a node (likely the player)
}

local INTERFACE_FUNCTION_NAMES = getInterfaceFunctionNames()
for k, _ in pairs(EXTRA_INTERFACE_FUNCTIONS) do
    table.insert(INTERFACE_FUNCTION_NAMES, k)
end

local LUT = {}
for i = 1, #INTERFACE_FUNCTION_NAMES do
    LUT[INTERFACE_FUNCTION_NAMES[i]] = true
end

local function isInterfaceFunctionEx(s)
    return LUT[s]
end

local function getInterfaceFunctionNamesEx()
    return INTERFACE_FUNCTION_NAMES
end

return {
    isInterfaceFunctionEx = isInterfaceFunctionEx,
    getInterfaceFunctionNamesEx = getInterfaceFunctionNamesEx,
}

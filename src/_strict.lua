--[[to use this, add this line at the top of node_logic.lua:

dofile("_strict.lua")

]]

local INTERFACE_FUNCTION = {}
for _, fname in pairs(getInterfaceFunctionNames()) do
    INTERFACE_FUNCTION[fname] = true
end

local function dummy()
end

local function looksLikeGlobal(s)
    return type(s) == "string" and not s:match("[^_%u%d]")
end

local stfu = rawget(_G, "._strict_stfu")
if not stfu then
    stfu = {}
    rawset(_G, "._strict_stfu", stfu)
end

-- this function patches the global table in a way that warnings because of missing globals are shown exactly once.
-- Reloading the map will reset shown warnings.
local function patchGlobalTable()
    for k, _ in pairs(stfu) do
        debugLog("_strict: Clearing muted warning for global [" .. tostring(k) .. "]")
        rawset(_G, k, nil)
        stfu[k] = nil
    end
    setmetatable(_G, {
        __index = function(t, k)
            -- this would trigger when the game tries to collect globals for interface function use.
            -- this is not an error when they don't exist.
            if k == "v" or INTERFACE_FUNCTION[k] then
                return
            end
            if type(k) ~= "string" or not stfu[k] then -- UPPERCASE_VAR_NAMES will still be reported if missing.
                stfu[k] = true
                errorLog("Trying to read undefined global: " .. tostring(k), 1)
            end
        end,
        __newindex = function(t, k, val)
            local isIFF = INTERFACE_FUNCTION[k]
            local tv = type(val)
            if isIFF and tv ~= "function" and val ~= nil then
                errorLog("Set interface var name is not a function, type is [" .. type(val) .. "]: " .. tostring(k) .. " = " .. tostring(val), 1)
            end
            local isstr = type(k) == "string"
            local maybeglobal = isstr and looksLikeGlobal(k)
            local allowed = k == "v" or isIFF
            --local blargh = isstr or not (k == "v" or stfu[k] or isIFF or maybeglobal)
            if not (allowed or maybeglobal) then
                if not stfu[k] then
                    stfu[k] = true
                    errorLog("Warning: Attempt to set global [" .. tv .. "]: " .. tostring(k) .. " = " .. tostring(val), 1)
                end
            end
            if not stfu[k] and not allowed and maybeglobal then
                stfu[k] = true
                debugLog("_strict: Set global " .. tv .. " " .. tostring(k) .. " = " .. tostring(val))
            end
            rawset(t, k, val)
        end,
    })
    debugLog("_strict: patchGlobalTable() ok")
end

patchGlobalTable()

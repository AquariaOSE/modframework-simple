-- I'd prefer to have this in the framework, but it's needed by the data subsystem,
-- which must be loaded before the framework. Fortunately this gets re-loaded in dev mode,
-- and in production none of the cached data change, so that's fine.

local SKELCACHE = setmetatable({}, {
    __index = function(t, k)
        local val = {}
        t[k] = val
        return val
    end,
})
local BONENAMES = {}



local function _loadXMLBones(fn)
    local t, err = loadXMLTable(fn)
    if not t then
        warnLog("_loadXMLBones: File not found or error: [" .. fn .. "]: " .. tostring(err))
        return
    end
    local bones
    for i = 1, #t do
        if t[i].name == "Bones" then
            bones = t[i]
            break
        end
    end
    if not bones then
        warnLog("File does not contain <Bones> tag")
        return
    end
    return bones
end

local function _loadAnim(bones)
    if not bones then
        return
    end
    local t = {}
    local idname = {}
    for i = 1, #bones do
        local bone = bones[i]
        local a = bone.attr
        if a and bone.name == "Bone" then
            local gfx = a.gfx
            local idx = tonumber(a.idx)
            local name = a.name or ""
            if idx then
                idname[idx] = name
                if name ~= "" then
                    idname[name] = idx
                end
            end
            if name ~= "" then
                if t[name] then
                    warnLog("Duplicate bone name [" .. name .. "]")
                end
                t[name] = gfx
            elseif idx then
                if t[idx] then
                    warnLog("Duplicate bone idx " .. idx)
                end
                t[idx] = gfx
            end

        end
    end
    return t, idname
end

local function _loadSkin(bones, idname)
    if not bones then
        return
    end
    local t = {}
    for i = 1, #bones do
        local bone = bones[i]
        local a = bone.attr
        if a and bone.name == "Bone" then
            local gfx = a.gfx
            local idx = tonumber(a.idx)
            local name = idname[idx]
            if name then
                t[name] = gfx
            elseif idx then
                t[idx] = gfx
            else
                warnLog("no idx or name attrib?!")
            end
        end
    end
    return t
end

local function _doAnim(skel)
    local t, idname = _loadAnim(_loadXMLBones("animations/" .. skel .. ".xml"))
    BONENAMES[skel] = idname
    return t
end
local function _doSkin(skel, skin)
    local idname = BONENAMES[skel]
    return _loadSkin(_loadXMLBones("animations/skins/" .. skin .. ".xml"), idname)
end

local function _querySkeletalBones(skel, skin)
    debugLog("_querySkeletalBones, skel: [" .. skel .. "], skin: [" .. skin .. "]")

    local base = SKELCACHE[skel][""]
    if not base then
        base = _doAnim(skel)
        SKELCACHE[skel][""] = base
    end

    if skin == "" then
        return base
    end

    local tab = _doSkin(skel, skin)
    SKELCACHE[skel][skin] = tab
    return tab
end

local function getSkeletalBoneTexturesTab(skel, skin)
    skin = skin or ""
    return SKELCACHE[skel][skin] or _querySkeletalBones(skel, skin)
end

local function getSkeletalBoneTex(skel, boneName, skin)
    local tab = getSkeletalBoneTexturesTab(skel, skin)
    return tab and tab[boneName]
end


return {
    getSkeletalBoneTexturesTab = getSkeletalBoneTexturesTab,
    getSkeletalBoneTex = getSkeletalBoneTex,
}

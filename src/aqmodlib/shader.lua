
local SHADER_PATH = "shaders/"


local TYPE_FUNCS = {
    int = shader_setInt,
    ivec2 = shader_setInt,
    ivec3 = shader_setInt,
    ivec4 = shader_setInt,
    float = shader_setFloat,
    vec2 = shader_setFloat,
    vec3 = shader_setFloat,
    vec4 = shader_setFloat,
    dummy = function() end,
}
local GOOD_TYPES = ""
for k, _ in pairs(TYPE_FUNCS) do
    GOOD_TYPES = GOOD_TYPES .. tostring(k) .. " "
end

local function GC_Lua51(proxy)
    local shobj = getmetatable(proxy).shobj
    return getmetatable(shobj).__gc(shobj)
end

local function typeFail(ty)
    errorLog("Custom shader error: Unknown uniform type '" .. tostring(ty) .. "', assuming dummy.\nAllowed types: [" .. GOOD_TYPES .. "]")
    return TYPE_FUNCS.dummy
end

local function applyAfterEffectShader(shobj, ...)
    return shader_setAsAfterEffect(shobj._ptr, ...)
end

local function setUniform(shobj, name,  ...)
    if shobj._funcs and shobj._funcs[name] then
        local shv = shobj._vars[name]
        for i = 1, select("#", ...) do
            shv[i] = select(i, ...)
        end
        return shobj._funcs[name](shobj._ptr, name, ...)
    else
        if name:sub(1,1) ~= "_" then
            warnLog("Custom shader warning: Set unknown or not exported uniform variable: " .. tostring(name))
        end
        if not shobj._funcs then
            shobj._funcs = {}
            shobj._vars = {}
        end
        shobj._funcs[name] = TYPE_FUNCS.dummy
        shobj._vars[name] = { ... }
    end
end

local function setUniformOpt(shobj, name, ...)
    if shobj._vars[name] then
        return setUniform(shobj, name, ...)
    end
end

local function getUniform(shobj, name)
    local t = shobj._vars[name]
    if t then
        return unpack(t)
    end
end

local SHmeta = {
    __newindex = setUniform,
    __index = getUniform,

    __gc = function(shobj)
        shader_delete(shobj._ptr)
        shobj._ptr = nil
    end,
}

local function loadLuaShader(name, ...)
    local makesh, err = loadfile(SHADER_PATH .. name .. ".shader")
    if not makesh then
        errorLog("Failed to load Lua shader file: " .. name .. "\n" .. err)
        return
    end

    local vert, frag, uniforms, methods = makesh(...)
    local ptr = createShader(vert, frag)
    if not ptr or ptr == 0 then
        local err = "loadLuaShader: Failed to create shader: " .. name
        debugLog(err)
        return
    end

    local numUniforms = 0

    local vars = {}
    local funcs = false
    if uniforms then
        funcs = {}
        for varname, entry in pairs(uniforms) do
            local ty
            if type(entry) == "table" then -- contains initializer table with { "typename", ... values ...}
                ty = table.remove(entry, 1)
                vars[varname] = entry -- these are what's left.
            elseif type(entry) == "string" then
                ty = entry
                vars[varname] = { 0 } -- to make arithmetic without prior init happy.
            else
                error("Bad uniform info entry")
            end
            funcs[varname] = TYPE_FUNCS[ty] or typeFail(ty)
            numUniforms = numUniforms + 1
        end
    end

    local shobj = { _ptr = ptr, _vars = vars, _funcs = funcs }

    local numMth = 0
    if methods then
        for mthname, mth in pairs(methods) do
            shobj[mthname] = mth
            if type(mth) == "function" then
                numMth = numMth + 1
            end
        end
    end

    debugLog("Created Lua shader '" .. name .. "' with " .. numUniforms .. " uniforms, " .. numMth .. " methods")

    -- HACK: Finalizers on tables do not work in Lua 5.1 (they do in 5.2);
    -- they only work on userdata. The *only* way to create userdata from Lua
    -- which have a metatable attached is to use the undocumented newproxy() function.
    -- In 5.2, newproxy() does not exist and this workaround is not needed.
    if rawget(_G, "newproxy") then -- _VERSION == "Lua 5.1"
        shobj._proxy = newproxy(true)
        local pmeta = getmetatable(shobj._proxy)
        pmeta.__gc = GC_Lua51
        pmeta.shobj = shobj -- crosslink
    end

    shobj.setAsAfterEffect = applyAfterEffectShader
    shobj.set = setUniform
    shobj.setOpt = setUniformOpt
    shobj.get = getUniform

    if uniforms then
        debugLog(" Init uniforms...")
        for varname, vals in pairs(vars) do
            debugLog("  " .. varname .. " = { " .. table.concat(vals, ", ") .. " }")
            setUniform(shobj, varname, unpack(vals))
        end
    end

    return setmetatable(shobj, SHmeta)
end


return {
    loadLuaShader = loadLuaShader,
}

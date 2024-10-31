local C = {}

function C:__index(name)
    local fn = "src/utilclasses/" .. name .. ".lua"
    local cached = { dofile(fn) }
    if not next(cached) then
        error(fn .. " -- should return something")
    end
    C[name] = cached
    return cached
end
setmetatable(C, C)

local function utilclass(name) 
    return unpack(C[name])
end

return {
    utilclass = utilclass
}

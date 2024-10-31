local select = select

local function _gc_finalizer(proxy)
    local meta = getmetatable(proxy)
    meta.f(unpack(meta, 1, meta.n))
end

local newproxy = rawget(_G, "newproxy")

local function createFinalizer(f, ...)
    local proxy, meta
    
    -- HACK: Finalizers on tables do not work in Lua 5.1 (they do in 5.2);
    -- they only work on userdata. The *only* way to create userdata from Lua
    -- which have a metatable attached is to use the undocumented newproxy() function.
    -- In 5.2, newproxy() does not exist, and table finalizers are allowed, so just that.
    if newproxy then -- _VERSION == "Lua 5.1"
        proxy = newproxy(true)
        meta = getmetatable(proxy)
        meta.__gc = _gc_finalizer
    else
        -- in Lua 5.2 and up, __gc must be set BEFORE setmetatable() is used
        proxy = { __gc = _gc_finalizer }
        setmetatable(proxy, proxy)
        meta = proxy
    end
    
    local nargs = select("#", ...)
    meta.n = nargs
    meta.f = f
    for i = 1, nargs do
        meta[i] = select(i, ...)
    end
    
    return proxy
end


return {
    createFinalizer = createFinalizer,
}

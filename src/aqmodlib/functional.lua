local tremove = table.remove
local next = next
local pairs = pairs

local function fun_map(t, f, ...)
    local o = {}
    for i, e in pairs(t) do
        o[i] = f(e, ...)
    end
    return o
end

local function fun_map_inplace(t, f, ...)
    for i, e in pairs(t) do
        t[i] = f(e, ...)
    end
    return t
end

local function fun_replace_inplace(t, q)
    for i, e in pairs(q) do
        t[i] = e
    end
    return t
end

local function fun_replace(t, q)
    return fun_replace_inplace(table.shallowcopy(t), q)
end

local function _callCascade(t, idx, ...)
    local func = t[idx]
    if func then
        return _callCascade(t, idx+1, func(...))
    end
    return ...
end

local function fun_cascade(...)
    local t = {...}
    return function(...)
        return _callCascade(t, 1, ...)
    end
end

local function fun_lt(a, b) return a < b end
local function fun_gt(a, b) return a > b end
local function fun_le(a, b) return a <= b end
local function fun_ge(a, b) return a >= b end
local function fun_eq(a, b) return a == b end
local function fun_ne(a, b) return a ~= b end

local function fun_add(a, b) return a + b end
local function fun_sub(a, b) return a - b end
local function fun_mul(a, b) return a * b end
local function fun_div(a, b) return a / b end
local function fun_mod(a, b) return a % b end
local function fun_pow(a, b) return a ^ b end

local function fun_not(a) return not a end

local optab = {
    lt = fun_lt,
    gt = fun_gt,
    le = fun_le,
    ge = fun_ge,
    eq = fun_eq,
    ne = fun_ne,
    
    add = fun_add,
    sub = fun_sub,
    mul = fun_mul,
    div = fun_div,
    mod = fun_mod,
    pow = fun_pow,
    
    ["not"] = fun_not,
}

local function fun_str2op(op)
    return optab[op]
end

return {
    fun_map = fun_map,
    fun_map_inplace = fun_map_inplace,
    fun_replace = fun_replace,
    fun_cascade = fun_cascade,
    fun_str2op = fun_str2op,
    fun_lt = fun_lt,
    fun_gt = fun_gt,
    fun_le = fun_le,
    fun_ge = fun_ge,
    fun_eq = fun_eq,
    fun_ne = fun_ne,
    fun_add = fun_add,
    fun_sub = fun_sub,
    fun_mul = fun_mul,
    fun_div = fun_div,
    fun_mod = fun_mod,
    fun_pow = fun_pow,
    fun_not = fun_not,
}

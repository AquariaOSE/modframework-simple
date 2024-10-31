-- recursive serializer that ignores userdata and errors on functions/coroutines/other things

local strmatch = string.match
local tins = table.insert
local type = type
local pairs = pairs
local tostring = tostring
local strfmt = string.format
local strrep = string.rep

local isSafeTableKey

do
    local lua_reserved_keywords = {
        'and',    'break',  'do',
        'else',   'elseif', 'end',
        'false',  'for',    'function',
        'if',     'in',     'local',
        'nil',    'not',    'or',
        'repeat', 'return', 'then',
        'true',   'until',  'while',
    }

    local keywords = {}
    for _, w in pairs(lua_reserved_keywords) do
        keywords[w] = true
    end

    isSafeTableKey = function(s)
        return type(s) == "string" and not (s == "" or keywords[s] or strmatch(s, "[^a-zA-Z_]"))
    end
end

local function doindent(tab, n)
    return n and n > 0 and tins(tab, strrep("    ", n))
end

local dump_simple_i

local function dump_simple_table(t, buf, indent)
    tins(buf, "{")
    local idd = indent and (indent+1)
    local usedkeys = {}
    if rawget(t, 1) ~= nil then -- check that this table is really numerically indexed
        for i, val in ipairs(t) do
            usedkeys[i] = true
            dump_simple_i(val, buf, indent)
            tins(buf, ", ")
        end
    end
    
    local big
    for key, val in pairs(t) do
        if not usedkeys[key] then
            local lastlen = #buf
            local revert
            if indent then
                tins(buf, "\n")
                doindent(buf, idd)
            end
            if isSafeTableKey(key) then
                tins(buf, key .. "=")
            else
                tins(buf, "[")
                revert = not dump_simple_i(key, buf)
                tins(buf, "]=")
            end
            if not revert then
                revert = not dump_simple_i(val, buf, idd)
                if not revert then
                    tins(buf, ",")
                    big = true
                end
            end
            if revert then
                for i = lastlen+1, #buf do
                    buf[i] = nil
                end
            end
        end
    end
    if big and indent then
        tins(buf, "\n")
        doindent(buf, indent)
    end
    tins(buf, "}")
    return true
end

local function dump_simple_string(t, buf, indent)
    tins(buf, strfmt("%q", t))
    return true
end

local function dump_simple_value(t, buf, indent)
    tins(buf, tostring(t))
    return true
end

local function dump_ignore(t, buf)
    tins(buf, "nil")
end

local function dump_debug(t, buf)
    tins(buf, debugx.formatVariable(t, 8))
end

local dumpfunc = {
    table = dump_simple_table,
    string = dump_simple_string,
    number = dump_simple_value,
    boolean = dump_simple_value,
    userdata = dump_ignore,
}
local function dump_error(t, buf)
    error("serialize: Cannot dump type " .. type(t) .. " (\"" .. tostring(t) .. "\")")
end
local DUMP_FALLBACK = dump_error
setmetatable(dumpfunc, {
    __index = function(t, k)
        return DUMP_FALLBACK
    end
})

dump_simple_i = function(t, buf, indent)
    return dumpfunc[type(t)](t, buf, indent)
end


local function dump_simple(t, indent, unsafe)
    local buf = { "return " }
    local function f()
        return dump_simple_i(t, buf, indent and 0)
    end
    xpcall(f, errorLog)
    return table.concat(buf)
end

local function restore(s)
    return assert(loadstring(s, ""))()
end

local function serialize_save(tab, indent)
    DUMP_FALLBACK = dump_error
    return tostring(dump_simple(tab, indent))
end

local function serialize_save_debug(tab, indent)
    DUMP_FALLBACK = dump_debug
    return tostring(dump_simple(tab, indent))
end

local function serialize_restore(s)
    local r
    local ok, ret = pcall(restore, s)
    if not ok then
        return nil, ret
    end
    return ret
end

--[[
local function test()
    local t, s
    
    t = {1, 2, 3, [5] = { "a", "b", {{},{a=0}}}, test="[test]", ['._secret'] = {"secret", 0, 0, x={y={z={}}}}, [6] = {6}, [0] = 0}
    s = serialize_save(t, true)
    print(s)
    assert(serialize_restore(s))
    
    
    local ud = newproxy()
    
    t = { { a = ud, b = true }, {c = false}, {1, ud, 2, ud, 3, ud, 4, {ud=ud}, {[ud] = "ud"}, {[ud] = ud}}, [ud] = {1,2,3} }
    s = serialize_save(t, true)
    print(s)
    assert(serialize_restore(s))
    
    print("works!")
end
test()
]]

return {
    serialize_restore = serialize_restore,
    serialize_save = serialize_save,
    serialize_save_debug = serialize_save_debug,
}

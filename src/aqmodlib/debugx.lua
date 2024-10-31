
local debugx = {}
rawset(_G, "debugx", debugx)

local function formatVariable(x, depth)
    local recurse
    if depth then
        depth = depth - 1
        recurse = depth >= 0
    end
    local ty = type(x)
    local s = ""
    if ty == "table" then
        local c = 0
        for _, _ in pairs(x) do
            c = c + 1
        end
        if recurse then
            if getmetatable(x) then
                s = s .. "<MT>"
            end
            s = s .. "{#" .. c .. " "
            local idx, val = next(x)
            for i = 1, 100 do
                if idx == nil then
                    break
                end
                s = s .. formatVariable(idx) .. "=" .. formatVariable(val, depth) .. ", "
                idx, val = next(x, idx)
            end
            if idx then
                s = s .. "..."
            end
            s = s .. "}"
        else
            s = "{#" .. c .. "}"
        end
    elseif ty == "string" then
        if #x < 20 then
            s = "'" .. x:gsub("\n", "\\n") .. "'"
        else
            s = "'" .. x:sub(1, 20):gsub("\n", "\\n") .. "'..."
        end
    elseif ty == "function" then
        s = "FUNC"
        local info = debug and debug.getinfo(x)
        if info and info.source then
            local file = info.source:gsub("\\\\", "\/"):explode("/", true)
            file = file[#file]
            if not file then
                file = info.source
            end
            s = s ..":[" .. tostring(file) .. ":" .. tostring(info.linedefined) .. "]"
        end
    elseif ty == "userdata" then
        if isEntity(x) then
            s = ("Entity[%d, %s]"):format(entity_getID(x), entity_getName(x))
        elseif isNode(x) then
            s = ("Node[%s]"):format(node_getLabel(x))
        else
            s = tostring(x)
        end
    elseif ty == "proto" then -- HACK: undocumented Lua edge case? I've had this happen, DO NOT try to tostring() this, because it will segfault trying to look up __tostring metamethod
        s = "PROTO?"
    else
        s = tostring(x)
    end
    return s
end
debugx.formatVariable = formatVariable

local function formatLocals(level)
    if not debug then
        return "[No local variables available]"
    end
    -- go up the stack until we hit the first Lua frame
    local lvl = level or 1
    while true do
        local info = debug.getinfo(lvl)
        if not info then
            lvl = level -- oops.
            break
        elseif info.what == "Lua" then
            break
        else
            lvl = lvl + 1
            if lvl > 100 then
                --OG.errorLog("Something is strange! Too deep nesting")
                return "TOO DEEP NESTING"
            end
        end
    end
    local t = { false }
    local name, val
    local i = 0
    while true do
        i = i + 1
        name, val = debug.getlocal(lvl, i)
        if name then
            table.insert(t, "#" .. i .. " (" .. type(val) .. "): " .. name .. " = " .. formatVariable(val, 1))
        else
            break
        end
    end
    t[1] = "Local variables (" .. i .. "):"
    return table.concat(t, "\n")
end
debugx.formatLocals = formatLocals


local function formatStack(lvl)
    if debug then
        if not lvl then lvl = 1 end
        return debug.traceback("", lvl) or "[No traceback available]"
    end
    return "[No debug library available]"
end
debugx.formatStack = formatStack


local function findIdentInTable(t, x, startstr)
    for k, val in pairs(t) do
        if rawequal(val, x) and (not startstr or k:startsWith(startstr)) then
            return k
        end
    end
    return "unknown"
end
debugx.findIdentInTable = findIdentInTable

local function findGlobalIdent(x, startstr)
    return findIdentInTable(_G, x, startstr)
end
debugx.findGlobalIdent = findGlobalIdent

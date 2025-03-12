-- Circuit networks for script-less logic.
-- Inspired by Factorio, originally written for Timpansi
-- See logic/cn.lua for the code that uses this.

local tremove = table.remove
local tins = table.insert
local min = math.min
local max = math.max
local floor = math.floor
local next = next
local pairs = pairs
local debugLog = debugLog or print
local tpack = table.pack or function(...) return {n=select("#", ...), ...} end

local M = { modules = {} }


local autoextendMeta =
{
    __index = function(t, k)
        local x = {}
        t[k] = x
        return x
    end,
}

local function kunion(...)
    local N = select("#", ...)
    local t = {}
    for i = 1, N do
        local q = select(i, ...)
        if q then -- tolerate nils in the args
            for k, val in pairs(q) do
                t[k] = val
            end
        end
    end
    return t
end
M.kunion = kunion

local function dfs(neighbors, root, f, ...)
    local tmp = {root, [root] = true} -- array part: nodes to be traversed, hash part: seen flag
    while true do
        local node = tremove(tmp)
        if node == nil then
            break
        end
        local ns = neighbors[node]
        if ns then
            for nx in pairs(ns) do
                if not tmp[nx] then
                    tins(tmp, nx)
                    tmp[nx] = true
                end
            end
        end
        f(node, ...)
    end
end

function M.collect(label)
    label = label or "cn"
    local cns = getNodesByLabel(label)
    if not cns then
        return
    end
    local neighbors = setmetatable({}, autoextendMeta)
    local todo = {}
    for _, node in pairs(cns) do
        local covered = node_getNodesOnPath(node, label)
        todo[node] = true
        for _, nb in pairs(covered) do
            neighbors[node][nb] = true
            neighbors[nb][node] = true
            todo[nb] = true
        end
    end

    local subnets = setmetatable({}, autoextendMeta)
    local curnetid = 0

    local function visit(x)
        todo[x] = nil
        tins(subnets[curnetid],  x)
    end

    while true do
        local node = next(todo)
        if not node then
            break
        end
        curnetid = curnetid + 1
        dfs(neighbors, node, visit) -- visit() removes node from todo
    end

    debugLog("CN:collect(" .. label .. "): Found " .. curnetid .. " separate networks")

    setmetatable(subnets, nil)
    return subnets
end

local Keywords = { ["and"] = true, ["or"] = true, ["not"] = true }
local function parseReferenced(expr)
    local referenced = {}
    for x in expr:gmatch"([%a_][%w_]*)" do
        if not (x:match"^_" or Keywords[x]) then -- HACK: don't include things prefixed with _
            local num = tonumber(x)
            if not num then
                referenced[x] = true
            end
        end
    end
    return referenced
end

local function prepareExpr(expr)
    local num = tonumber(expr)
    if num then -- small optimization: embed valid numbers directly
        return tostring(floor(num))
    end

    return "_toint(" .. expr .. ")"
end

-- a=b+c+1 (var -> "a")
-- a<b+1 (var -> nil)
local function splitExpr(expr)
    expr = expr:lower()
    local var, rest = expr:lower():match"(%a[%w_]*)=([^=].*)"
    if not var then
        rest = expr
    end
    if rest == "" then
        rest = nil
    end
    local referenced = parseReferenced(rest)
    return var, rest, referenced
end
M.splitExpr = splitExpr

local _ilut = { [true] = 1, [false] = 0 }
local function toint(x) return _ilut[x] or (x and floor(x)) or 0 end
M.toint = toint

local function _compile(code, expr, ...)
    --debugLog("CN: Generated code for expr [" .. expr .. "]:\n" .. code .. "----\n")
    local template = assert(loadstring(code, expr))
    return template(toint, ...)
end

local function compileExpr(expr)
    local var, rest, referenced = splitExpr(expr)
    assert(var == nil or type(var) == "string")

    local deflocals = ""
    if referenced then
        local decls = {}
        local fetches = {}
        for k in pairs(referenced) do
            tins(decls, k)
            tins(fetches, "((_in." .. k .. ") or 0)")
        end

        if #fetches > 0 then
            deflocals = "local " .. table.concat(decls, ", ") .. " = " .. table.concat(fetches, ", ") .. "\n"
        end
    end

    local body = "local _result = 0 -- NO EXPR\n"
    if rest then
        body = "local _result = " .. prepareExpr(rest) .. "\n"
        if var then
            -- expr is an assignment to a variable
            local out = "_out." .. var
            body = body .. out .. " = ((" .. out .. ") or 0) + _result\n"
        end
    end

    local code = [[
local _toint = ...
return function(_in, _out)
]] .. deflocals .. body .. [[
return _result
end
]]

    local f = _compile(code, expr)

    return {var=var, f=f, referenced=referenced, fullexpr=expr, rest=rest}
end
M.compileExpr = compileExpr

local function evalCallback(var, userfunc)
    local out = "_out." .. var
    local code = [[
local _toint, _f = ...
return function(_in, _out)
local _result = _toint(_f(_in))
]] .. out .. " = ((" .. out .. [[) or 0) + _result
return _result
end]]
    local wrap = _compile(code, "CB:" .. var, userfunc)

    return {var=assert(var), f=assert(wrap), fullexpr="(callback)" }
end
M.evalCallback = evalCallback

-- first is array, second is a set (var names as keys)
local function configureEvalK(provideVars, referenced)
    local var
    if type(provideVars) == "string" then
        var = provideVars
        provideVars = nil
    end
    return {var=var, vars=provideVars, referenced=referenced, _evalMethodMarker=true, fullexpr="(eval)"} -- the marker is checked below
end
M.configureEvalK = configureEvalK

-- both tables are arrays of strings
local function configureEval(provideVars, reqVars)
    local referenced
    if reqVars then
        referenced = {}
        for _, k in pairs(reqVars) do
            assert(type(k) == "string")
            referenced[k] = true
        end
    end
   return configureEvalK(provideVars, referenced)
end
M.configureEval = configureEval

local function valexpr(expr)
    local x = compileExpr(expr)
    local f = assert(x.f)
    if x.var then
        warnLog("Expr [" .. expr .. "] also assigns to variable [" .. x.var .. "], which is incorrect in this context")
        x.var = nil
    end
    return x, f
end
M.valexpr = valexpr

local function condition(expr)
    local x, f = valexpr(expr)
    return x, function(_in, _out)
        return f(_in, _out) > 0
    end
end
M.condition = condition

local function _sortByOrder(a, b)
    return a.order > b.order
end

local function groupby(groups, var, n)
    assert(type(var) == "string")
    local g = groups[var]
    if g then
        tins(g, n)
    else
        groups[var] = {n}
    end
end

-- inp is a table as returned by compileExpr() and friends
local function resolve(inp)
    debugLog("CN: Resolve step for " .. #inp .. " exprs...")
    local nodelist = {}
    local groupedByVar = {}
    local groupedReferencing = {}

    -- Create graph nodes for each input expr
    for idx, ex in ipairs(inp) do
        local var, f, referenced = ex.var, ex.f, ex.referenced

        local n = { var = var, f=f, require=referenced,
            before = {}, after = {}, -- arrays of nodes that are evaluated directly before and after this one
            order = -1,
            originalIdx = idx,
            vars = ex.vars, -- in case this code provides multiple vars at once
            fullexpr = ex.fullexpr,
        }
        tins(nodelist, n)

        if var then
            groupby(groupedByVar, var, n)
        end
        if n.vars then
            for _, va in pairs(n.vars) do
                assert(type(va) == "string")
                groupby(groupedByVar, va, n)
            end
        end

        if referenced then
            for r in pairs(referenced) do
                groupby(groupedReferencing, r, n)
            end
        end
    end

    -- figure out relation between graph nodes and link them up
    for _, n in pairs(nodelist) do
        if n.require then
            local before = n.before
            for rname in pairs(n.require) do -- my own requirements
                local byvar = groupedByVar[rname] -- all nodes that fulfill this variable
                if byvar then
                    for _, nn in pairs(byvar) do
                        before[nn] = true -- do those nodes first, then me
                    end
                end
            end
        end
        if n.var then -- i fulfill this
            local refsme = groupedReferencing[n.var] -- all nodes that reference this variable
            if refsme then
                for _, nn in pairs(refsme) do
                    nn.after[n] = true -- do this node after me
                end
            end
        end
        if n.vars then
            for _, va in pairs(n.vars) do
                local refsme = groupedReferencing[va] -- all nodes that reference one my of variables, if multiple
                if refsme then
                    for _, nn in pairs(refsme) do
                        nn.after[n] = true -- do this node after me
                    end
                end
            end
        end
    end

    --[[
    local foreign = {}
    for r in pairs(groupedReferencing) do
        if not groupedByVar[r] then -- nobody fulfills this?
            tins(foreign, r)
            foreign[r] = true
        end
    end
    ]]

    local todo = {}
    for _, g in pairs(groupedByVar) do
        for _, nn in pairs(g) do
            todo[nn] = 0
        end
    end
    --[[for _, g in pairs(groupedReferencing) do
        for _, nn in pairs(g) do
            todo[nn] = 0
        end
    end]]

    -- perform max-ordering so that nodes with no deps get order 0,
    -- those depending on them get order 1, and so on.
    while true do
        local n, ord = next(todo)
        if not n then
            break
        end
        --print("resolve", n.fullexpr, ord)
        todo[n] = nil
        if not n.order or n.order < ord then
            n.order = ord
            todo[n] = ord
            for nx in pairs(n.before) do
                todo[nx] = max(todo[nx] or -1, ord + 1)
            end
        end

        if ord > 100 then
            local onode = inp[n.originalIdx]._originNode
            warnLog("CN[" .. node_getName(onode) .. "]: Dependency circle detected! Aborting further ordering attempts")
            break
        end
    end

    table.sort(nodelist, _sortByOrder)

    local callList = {}
    for i = 1, #nodelist do
        local n = nodelist[i]
        tins(callList, n.f)

        -- transfer some variables
        local x = inp[n.originalIdx]
        x.order = assert(n.order)
    end
    local N = #callList
    local function callAll(_in, _out)
        for i = 1, N do
            callList[i](_in, _out)
        end
    end

    return callAll
end

local Net = {}
Net.__index = Net

function Net:update(dt)
    local old = self._prevvals
    local now = self.values
    for k, val in pairs(old) do
        old[k] = 0
    end
    for k, val in pairs(now) do -- move previously new vars to old vars, and use those as input
        old[k] = val
        now[k] = nil
    end
    self:_call("preEval", old)
    -- update exprs
    self._f(old, now)
    -- update modules after all values have been calculated
    self:_call("update", dt, old, now)
end

function Net:_call(name, ...)
    for node, m in pairs(self._mod) do
        local f = m.funcs[name]
        if f then
            f(m.data, node, ...)
        end
    end
end

-- for debugging only
function Net:inspectNode(node)
    local name = node_getName(node)
    local m = self._mod[node]
    local myfuncs = self._funcsByNode[node]
    local vals
    if myfuncs then
        local _in, _out = self.values, {}
        for _, f in ipairs(myfuncs) do -- produce values in isolation
            f(_in, _out)
        end
        if next(_out) then
            vals = {}
            for k, val in pairs(_out) do
                tins(vals, ("%s = %d"):format(k, val))
            end
            table.sort(vals)
        end
    end

    local reqs
    local myreq = self._inputsByNode[node] -- sorted array
    if myreq then
        reqs = {}
        for i = 1, #myreq do
            local r = myreq[i]
            local val = self.values[r]
            local s = ("%s = %d"):format(r, val or 0)
            if val == nil then
                s = s .. " (undefined)"
            end
            reqs[i] = s
        end
    end

    local ins
    if m then
        local f = m.funcs.inspect
        if f then
            ins = f(m.data, node)
        end
    end
    local namestr = node_getName(node):match("^%S+%s+(.*)$")
    namestr = (namestr and (" (" .. namestr .. ")")) or ""
    return "-CN[" .. tostring(self.identifier) .. "]" .. namestr
        .. ((ins and ("\n--Info--\n" .. ins)) or "")
        .. ((reqs and ("\n--Used inputs--\n" .. table.concat(reqs, "\n"))) or "")
        .. ((vals and ("\n--Outputs--\n" .. table.concat(vals, "\n"))) or "")
end

local function appendall(dst, m, node, data, ...)
    local N = select("#", ...)
    for i = 1, N do
        local a = select(i, ...)
        if a then
            if a._evalMethodMarker then
                assert(not a.f)
                a._evalMethodMarker = nil
                local eval = m.eval
                a.f = function(_in, _out)
                    return eval(data, node, _in, _out)
                end
            end
            a._originNode = node
            tins(dst, a)
        end
    end
    return dst, N
end

-- this splits a text into words, but takes parentheses into account
-- ie. "a b+c" is two words, "a+(b * c) q+w" is also two words because any space between parens
-- is skipped
local function argsplit(s)
    local ret = {}
    local balance = 0
    local accu = ""
    for p in s:gmatch"%S+" do
        local _, open = p:gsub("%(", "")
        local _, close = p:gsub("%)", "")
        balance = balance + open - close
        assert(balance >= 0, "parse error - too many closing ))))")
        accu = accu .. " " .. p .. " " -- yeah, add those spaces back in, i know
        if balance == 0 then
            local a = accu:match"^%s*(.-)%s*$" -- clip off leading and trailing spaces
            if #a > 0 then
                tins(ret, a)
            end
            accu = ""
        end
    end
    assert(balance == 0, "parse error - parentheses unbalanced")
    return ret
end

function M.new(nodes, identifier)
    debugLog("CN: New network [" .. tostring(identifier) .. "] spanning " .. #nodes .. " nodes:")
    local funcsByNode = {}
    local inputsByNode = {}
    local self = setmetatable({
        identifier = identifier, values = {}, _prevvals = {}, nodes = nodes, _mod = {},
          _funcsByNode = funcsByNode, _inputsByNode = inputsByNode, -- for debugging
     }, Net)
    local prepared = {}
    local nodestrings = {}
    for _, n in pairs(nodes) do
        local s = node_getName(n)
        local x, y = node_getPosition(n)
        tins(nodestrings, ("%s:%d:%d"):format(s, math.floor(x), math.floor(y)))
        debugLog(s)
        local parts = argsplit(s)
        if #parts > 1 then -- [1] is "cn", [2] is a verb or expr
            local verb = parts[2]
            if verb:match"=" then
                for i = 2, #parts do -- "verb" is already an expression
                    local x = compileExpr(parts[i])
                    x._originNode = n
                    tins(prepared, x)
                end
            else
                local m = M.modules[verb]
                if m then
                    local data = { _net = self }
                    local xlat = {}
                    self._mod[n] = { funcs = m, data = data }
                    if m.init then
                        appendall(prepared, m, n, data, m.init(data, n, unpack(parts, 3)))
                    end
                else
                    warnLog("Unrecognized circuit command: [" .. verb .. "]")
                end
            end
        end
    end

    -- a unique string that we'll notice if the network topology changed
    self.idstr = table.concat(nodestrings, "##")

    -- this also reorders prepared so that expressions are executed after their dependencies
    self._f = resolve(prepared)

    -- this is needed for inspecting, to see where each value comes from.
    -- important that this happens after reordering
    for _, nn in pairs(prepared) do
        local node = nn._originNode
        if node then
            if nn.f then
                local t = funcsByNode[node]
                if not t then
                    t = {}
                    funcsByNode[node] = t
                end
                tins(t, nn.f)
            end
            if nn.referenced then
                local req = inputsByNode[node]
                if not req then
                    req = {}
                    inputsByNode[node] = req
                end
                for k in pairs(nn.referenced) do
                    req[k] = true -- needs to be a set for now because requirements may appear multiple times
                end
            end
        end
    end

    for node, req in pairs(inputsByNode) do
        local t = {}
        for k in pairs(req) do
            tins(t, k)
        end
        table.sort(t)
        inputsByNode[node] = t
    end

    debugLog("CN: Done constructing network [" .. tostring(identifier) .. "]")

    return self
end


rawset(_G, "circuitnetwork", M)


-------------
--[=[

local function klist(a, extra)
    if not (a or extra) then
        return
    end
    local t = {}
    if extra ~= nil then
        tins(t, extra)
    end
    if a then
        for k in pairs(a) do
            tins(t, k)
        end
    end
    return "[" .. table.concat(t, ",") .. "]"
end

local function vlist(a, extra)
    if not (a or extra) then
        return
    end
    local t = {}
    if a then
        for _, val in pairs(a) do
            tins(t, val)
        end
    end
    if extra ~= nil then
        tins(t, extra)
    end
    return "[" .. table.concat(t, ",") .. "]"
end


local exprs =
{
    "d=c*y",
    "a=2",
    "a=-1",
    "b=a+1",
    "c=b+a",
    "a+b<10",
    "z=q+c",
    "zz=aa+q",
}

local inp = {}
for _, e in pairs(exprs) do
    local x = compileExpr(e)
    --print(x.fullexpr, x.var, x.rest, x.f)
    tins(inp, x)
end
tins(inp, evalCallback("q", function() return 42 end))
tins(inp, configureEval({"aa", "bb"}, {"b", "z"}))
local evalAll = resolve(inp)
table.sort(inp, _sortByOrder)
for _, x in pairs(inp) do
    print(x.fullexpr, vlist(x.vars, x.var), x.rest, x.order, x.f, klist(x.referenced))
end

]=]

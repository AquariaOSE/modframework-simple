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

local M = { modules = {} }


local autoextendMeta =
{
    __index = function(t, k)
        local x = {}
        t[k] = x
        return x
    end,
}

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

local function parseReferenced(expr)
    local referenced = {}
    for x in expr:gmatch"([%a_][%w_]*)" do
        if not x:match"^_" then -- HACK: don't include things prefixed with _
            local num = tonumber(x)
            if not num then
                referenced[x] = true
            end
        end
    end
    return referenced
end

local function prepareExpr(expr)
    if tonumber(expr) then -- small optimization: embed valid numbers directly
        return tostring(floor(expr))
    end
    
    return "_toint(" .. expr .. ")"
end

-- a=b+c+1 (var -> "a")
-- a<b+1 (var -> nil)
local function splitExpr(expr)
    expr = expr:lower()
    local var, rest = expr:lower():match"(%a[%w_]*)=(.+)"
    if not var then
        rest = expr
    end
    local referenced = parseReferenced(rest)
    return var, rest, referenced
end
M.splitexpr = splitExpr

local function _sortByOrder(a, b)
    return a.order < b.order
end

local _ilut = { [true] = 1, [false] = 0 }
local function toint(x) return _ilut[x] or (x and floor(x)) or 0 end
M.toint = toint

local function exprconcat(exprs)
    local tmp = {}
    for _, ex in pairs(exprs) do
        ex = "(_toint(" .. ex .. ") > 0)"
        tins(tmp, ex)
    end
    local code = "_toint(" .. table.concat(tmp, " and ") .. ")"
    debugLog("CN: Generated expression for " .. #tmp .. " parts:" .. code)
    return code
end

local function codegen(exprs)
    debugLog("CN: Codegen for " .. #exprs .. " assignments...")
    local gnodes = {}
    local unrefd = {}
    local varsLut = {}
    local idx = 0
    for origIdx, e in pairs(exprs) do
        local nocode = string.byte(e) == 1 -- HACK: "provide-only" exprs are tagged with a 0x01-byte
        if nocode then
            e = e:sub(2)
        end
        local var, code, referenced = splitExpr(e)
        if nocode then
            code = nil
            referenced = nil
        end
        local assignment = not not var
        if not var then
            idx = idx + 1
            var = "_" .. idx
        end
        local n = gnodes[var]
        if not n then
            n = { var = var, code = {}, require = {}, before = {}, after = {}, order = -1,
                assignment = assignment, originalIdx = origIdx }

            gnodes[var] = n
        end
        if code then
            tins(n.code, code)
        end
        if referenced then
            for r in pairs(referenced) do
                n.require[r] = true
            end
        end
        unrefd[n] = true
        varsLut[var] = true
        if referenced then
            for rv in pairs(referenced) do
                varsLut[rv] = true
            end
        end
    end
    for _, n in pairs(gnodes) do
        for rname in pairs(n.require) do
            local pre = gnodes[rname] or false
            n.before[rname] = pre
            if pre then
                unrefd[pre] = nil
                pre.after[n] = true
            end
        end
    end

    local todo = {}
    for n in pairs(unrefd) do
        debugLog("CN: unrefd: " .. n.var)
    end
    for _, n in pairs(gnodes) do
        if not next(n.before) then
            debugLog("CN: leaf: " .. n.var)
            todo[n] = 0
        end
    end

    -- perform max-ordering so that nodes with no deps get order 0,
    -- those depending on them get order 1, and so on.
    while true do
        local n, ord = next(todo)
        if not n then
            break
        end
        todo[n] = nil
        if n.order < ord then
            n.order = ord
            todo[n] = ord
            for nx in pairs(n.after) do
                todo[nx] = max(todo[nx] or -1, ord + 1)
            end
        end
    end

    local i = 0
    local sorted = {}
    for _, n in pairs(gnodes) do
        i = i + 1
        sorted[i] = n
    end
    table.sort(sorted, _sortByOrder)

    local tmp, tmp2 = {}, {}
    local gets = {}
    local assigns = {}
    local mapping = {}
    for j = 1, #sorted do
        local n = sorted[j]
        if #n.code > 0 then
            local target
            if n.order >= 0 then
                target = tmp
            else
                target = tmp2
            end
            if next(n.before) then -- don't fetch leaf exprs
                tins(gets, n.var .. " = " .. "_toint(_prev." .. n.var .. ")\n")
            end
            tins(target, "--[[" .. n.order .. "]] " .. n.var .. " = " .. table.concat(n.code, " + ") .. "\n")
            local a = "_vals." .. n.var
            tins(assigns, a .. " = ((" .. a .. ") or 0) + (" .. n.var .. ")\n")
        end
        mapping[n.originalIdx] = n.var
    end
    
    local vars = {}
    local foreign = {}
    for var in pairs(varsLut) do
        tins(vars, var)
        local n = gnodes[var]
        if not n or #n.code == 0 then
            tins(foreign, "--[[foreign]] " .. var .. " = " .. "_toint(_prev." .. var .. ")\n")
        end
    end
    table.sort(vars)

    local prelude = [[
local _toint = ...
return function(_vals, _prev)
]]
    local varlist = table.concat(vars, ", ")
    local decl = (next(vars) and ("local " .. varlist .. "\n")) or ""
    local main = table.concat(tmp)
    local get = table.concat(gets)
    local foreigns = table.concat(foreign)
    local late = table.concat(tmp2)
    local asg = table.concat(assigns)

    return prelude .. decl .. get .. foreigns .. main .. late .. asg .. "end", vars, mapping
end

local function compile(code, vars)
    debugLog("CN: --- Compiling generated code: ---\n" .. code)
    local varlist = table.concat(vars, ",")
    local gen = assert(loadstring(code, "(CN:" .. varlist .. ")"))
    local f = assert(gen(toint))
    return f
end

-- return index under which this expr is evaluated. registers itself.
local function compileexpr_v(d, ...)
    local net = assert(d._net)
    local exprs = {...}
    local combined = exprconcat(exprs)
    tins(net._externalexprs, combined)
    return #net._externalexprs
end
M.compileexpr_v = compileexpr_v

local function provideexpr_v(d, ...)
    local net = assert(d._net)
    local exprs = {...}
    local tag = string.char(1) -- HACK
    for _, e in pairs(exprs) do
        tins(net._externalexprs, tag .. e)
    end
end
M.provideexpr_v = provideexpr_v

local Net = {}
Net.__index = Net

function Net:update(dt)
    local old = self._prevvals
    local now = self.values
    for k, val in pairs(old) do
        old[k] = 0
    end
    for k, val in pairs(now) do
        old[k] = val
        now[k] = nil
    end
    -- collect values from modules
    local tmp = self._evaltmp
    for node, m in pairs(self._mod) do
        local f = m.funcs.eval
        if f then
            f(m.data, node, tmp, old)
            for k, val in pairs(tmp) do
                now[k] = (now[k] or 0) + toint(val)
                tmp[k] = nil
            end
        end
    end
    -- update remaining exprs
    self._f(now, old)
    -- update modules after all values have been calculated
    self:_call("update", now, dt)
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
    local m = self._mod[node]
    if m then
        local f = m.funcs.eval
        local vals, ins
        if f then
            vals = {}
            f(m.data, node, vals, self._prevvals)
            for k, val in pairs(vals) do
                vals[k] = toint(val)
            end
        end
        f = m.funcs.inspect
        if f then
            ins = f(m.data, node)
        end
        return vals, ins
    end
end

function M.new(nodes)
    debugLog("CN: New network spanning " .. #nodes .. " nodes:")
    local self = setmetatable(
        { values = {}, _prevvals = {}, nodes = nodes, _mod = {}, _evaltmp = {}, _externalexprs = {} }
        , Net)
    local exprs = {}
    local nodestrings = {}
    for _, n in pairs(nodes) do
        local parts = {}
        local s = node_getName(n)
        tins(nodestrings, s)
        debugLog(s)
        for p in s:gmatch"%S+" do
            tins(parts, p)
        end
        if #parts > 1 then -- [1] is "cn", [2] is a verb or expr
            local verb = parts[2]
            if verb:match"=" then
                for i = 2, #parts do -- "verb" is already an expression
                    tins(exprs, parts[i])
                end
            else
                local m = M.modules[verb]
                if m then
                    local data = { _net = self }
                    local xlat = {}
                    self._mod[n] = { funcs = m, data = data }
                    if m.init then
                        m.init(data, n, unpack(parts, 3))
                    end
                 end
            end
        end
    end
    
    for i, e in pairs(self._externalexprs) do
        tins(exprs, e)
        local where = #exprs 
        self._externalexprs[i] = where -- remember which index those exprs are at
        debugLog("expr #" .. i .. ": " .. where .. "  [" .. e .. "]")
    end

    local code, vars, mapping = codegen(exprs)
    local eval = compile(code, vars)
    
    local xlat = {}
    for i, where in pairs(self._externalexprs) do
        local newkey = assert(mapping[where])
        local e = exprs[where]
        debugLog("remap expr #" .. where .. " (ext.idx " .. i .. ") to key " .. newkey .. "  [" .. e .. "]")
        xlat[i] = newkey
    end
    
    for _, n in pairs(nodes) do
        local m = self._mod[n]
        local f = m and m.funcs.assign
        if f then
            f(m.data, xlat)
        end
    end
    
    -- one random string that we'll notice if the network topology changed
    local idstr = table.concat(nodestrings, "##")

    self._f = eval
    self.idstr = idstr

    return self
end


rawset(_G, "circuitnetwork", M)


--[[
local exprs =
{
    "d=c*y",
    "a=1",
    "a=-2",
    "a=z",
    "b=a+1",
    "c=b+a",
    "z=10",
    "y=a+z",
    "i=i+1",
    "k=i*2",
    "j=i+k+a+z",
    "a+b<10"
}

local code = codegen(exprs)
local f = compile(code)
local vals, pre = {}, {}
for i = 1, 3 do
    print("---------")
    tclear(vals)
    f(vals, pre)
    for k, val in pairs(vals) do
        pre[k] = val
    end
    for k, v in pairs(vals) do
        print(k, "=", v)
    end
end
]]
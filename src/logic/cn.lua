-- requires aqmodlib/circuitnetwork.lua

local tins = table.insert

local M = {}
M.nets = {}
M.node2net = {}

local function getNetworkForNode(node)
    return M.node2net[node]
end

local function refreshNetworks()
    local oldbyid = {}
    for _, net in pairs(M.nets) do
        oldbyid[net.idstr] = net
    end
    M.nets = {}
    table.clear(M.node2net)
    local groups = circuitnetwork.collect("cn")
    if not groups then
        return
    end
    for idx, nodes in pairs(groups) do
        local net = circuitnetwork.new(nodes, idx)
        if net then
            local old = oldbyid[net.idstr]
            if old and old.idstr == net.idstr then
                net = old -- old network didn't change -> throw away the new one and keep using the old one
            end
            net.idx = idx
            tins(M.nets, net)
            for _, node in pairs(nodes) do
                M.node2net[node] = net
            end
        end
    end
end

M.init = function()
    -- "cn" nodes have no script, and can therefore be processed during regular init
    refreshNetworks()
end

M.postInit = function()
end

M.update = function(dt)
    for _, net in pairs(M.nets) do
        net:update(dt)
    end
end

if not MOD_DEVMODE then
    return M
end

-------------------------------------------------------------------
-- Debug stuff follows
-------------------------------------------------------------------

M._inspectText = false

local function maketext(s, lr)
    local text = createArialTextSmall(10, s)
    text_setLayer(text, lr or LR_SCENE_COLOR)
    return text
end

local function formatValues(kv)
    local tmp = {}
    local i = 0
    for k, val in pairs(kv) do
        i = i + 1
        tmp[i] = ("%4s = %d"):format(k, val)
    end
    table.sort(tmp)
    return table.concat(tmp, "\n")
end

local function deleteCursorText()
    if M._inspectText then
        text_delete(M._inspectText)
        M._inspectText = false
    end
end

local function getNodeAtCursor()
    local mwx, mwy = getMouseWorldPos()
    local nn = getNearestNodeToPosition(mwx, mwy, "cn")
    if nn ~= 0 and not node_isPositionIn(nn, mwx, mwy) then
        nn = 0
    end
    return nn
end

M._junk = {}
M._textfornode = {}
M._seen = {}

local function checkEditor()
    local edit = isInEditor()
    if not edit then
        if M.wasInEditor then
            refreshNetworks()
        end
        M.wasInEditor = false
        deleteCursorText()
        for obj in pairs(M._junk) do
            obj_delete(obj)
            M._junk[obj] = nil
        end
    end
    return edit
end

local function updateTexts()
    if not next(M._textfornode) then
        return
    end
    local seen = M._seen
    for idx, net in pairs(M.nets) do
        local prefix = "--CN[" .. idx .. "]--\n"
        for _, node in pairs(net.nodes) do
            seen[node] = true
            local tt = M._textfornode[node]
            if tt then
                local x, y = node_getUpperLeftCorner(node)
                text_setPosition(tt, x, y)
                --[[local vals, ins = net:inspectNode(node)
                local s = prefix
                if vals then
                    s = s .. formatValues(vals)
                end
                if ins then
                    s = s .. "\n" .. ins
                end]]
                local s = net:inspectNode(node)
                text_setText(tt, s)
            end
        end
    end
    
    -- delete texts for nodes that got deleted in the editor
    for _, node in pairs(getAllNodes("cn")) do
        if seen[node] then
            seen[node] = false
        else
            local tt = M._textfornode[node]
            if tt then
                text_delete(tt)
                M._textfornode[node] = nil
            end
        end
    end
end

M.updateAlways = function(dt)
    updateTexts()
    checkEditor()
end

M.updatePaused = function(dt)
    updateTexts()
    if not checkEditor() then
        return
    end
    
    if not M.wasInEditor then
        --debugLog("logic/cn entered editor, " .. #M.nets .. " networks")
        M.wasInEditor = true
        for idx, net in pairs(M.nets) do
            local prefix = "--CN[" .. idx .. "]--\n"
            for _, node in pairs(net.nodes) do
                if not M._textfornode[node] then
                    local tt = maketext(prefix)
                    M._textfornode[node] = tt
                end
            end
        end
    end

    local nn = getNodeAtCursor()
    if nn == 0 then
        deleteCursorText()
        return
    end
    local T = M._inspectText
    if not T then
        T = maketext("", LR_DEBUG_TEXT)
        text_followCamera(T, 1)
        M._inspectText = T
        text_color(T, 1, 0.7, 1)
    end
    text_setPosition(T, getMousePos())
    local net = getNetworkForNode(nn)
    local s
    if net then
        s = "--CN[" .. net.idx .. "], " .. #net.nodes .. " nodes--\n" .. formatValues(net.values)
    else
        s = "Node doesn't belong to a network!"
    end
    text_setText(T, s)
end

return M

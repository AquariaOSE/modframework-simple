
if not MOD_DEVMODE then
    return
end


local M = {}
M.txt = 0
M.t = 10

M.init = function()
end

M.postInit = function()
    local todos = MOD_DEVMODE and getNodesByLabel("todo")
    if todos then
        local t = table.concat(fun_map_inplace(todos, node_getName), "\n")
        M.txt = createBitmapText(t, 12, 400, 30) -- FIXME
        obj_setLayer(M.txt, LR_DEBUG_TEXT)
        obj_followCamera(M.txt, 1)
        obj_scale(M.txt, 0.8, 0.8)
        obj_color(M.txt, 1, 0.5, 0.5)
        
        for _, node in pairs(todos) do
            local q = createQuad("debugcircle")
            quad_setPosition(q, node_getPosition(node))
            quad_scale(q, 1.2, 1.2, 1, -1, true)
        end
    end
end

M.update = function(dt)
    if M.txt ~= 0 and M.t > 0 then
        M.t = M.t - dt
        if M.t <= 0 then
            obj_delete(M.txt, 2)
            M.txt = 0
        end
    end
end


return M

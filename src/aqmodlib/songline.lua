local quad_setPosition = quad_setPosition
local tremove = table.remove
local tins = table.insert
local quad_color = quad_color
local quad_offset = quad_offset
local ipairs = ipairs
local quad_alphaMod = quad_alphaMod
local quad_delete = quad_delete

local M = {}
local meta = { __index = M }

function M.new(maxPoints)
    return setmetatable({
        qs = {},
        maxPoints = maxPoints or 40,
    }, meta)
end

function M:addPointNoRefresh(x, y, r, g, b)
    local q
    local qs = self.qs
    local t
    if #qs < self.maxPoints then
        q = createQuad("particles/glow")
        quad_followCamera(q, 1)
        quad_setBlendType(q, BLEND_ADD)
        quad_scale(q, 0.4, 0.4)
        quad_setPauseLevel(q, 2)
        quad_setLayer(q, LR_HUD)
    else
        q = tremove(qs, 1)
    end
    quad_color(q, r, g, b)
    quad_offset(q, x, y)
    tins(qs, q)
end

function M:refresh()
    local num = #self.qs
    for i, q in ipairs(self.qs) do
        local a = i / num
        quad_alphaMod(q, a)
    end
end

function M:addPoint(...)
    self:addPointNoRefresh(...)
    self:refresh()
end

function M:setPosition(x, y)
    for _, q in ipairs(self.qs) do
        quad_setPosition(q, x, y)
    end
end

function M:clear(t)
    for i, q in ipairs(self.qs) do
        quad_delete(q, t)
        self.qs[i] = nil
    end
end




rawset(_G, "SongLine", M)

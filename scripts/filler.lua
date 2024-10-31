
function init(me)
    setupEntity(me, "black")
    entity_makePassive(me)
    -- black and additive blend never shows, but still counts for collision
    entity_setBlendType(me, BLEND_ADD)
    entity_setState(me, STATE_IDLE)
end

function enterState(me)
    local state = entity_getState(me)
    entity_setFillGrid(me, (state ~= STATE_DISABLED) and 2)
    reconstructEntityGrid()
end

function exitState(me)
end

function update()
end

if MOD_RELEASE then
local dummy = function() end
init = dummy
update = dummy
else

v.txt = 0

function init(me)
    local s = node_getParamString(me)
    local x, y = node_getPosition(me)
    local txt = createArialTextBig(s, 12, x, y)
    text_setPosition(txt, x, y)
    text_setLayer(txt, LR_SCENE_COLOR)
    v.txt = txt
    node_setSpiritFreeze(me, false)
    node_setPauseFreeze(me, false)
end
function update(me, dt)
    local x, y = node_getPosition(me)
    text_setPosition(v.txt, x, y)
end

end

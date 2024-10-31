v.dx = false
v.dy = false
v.pe = 0
v.on = true

function init(me)
    local p = node_getParams(me)
    if p[1] then
        local dst = getNode(p[1])
        if dst ~= 0 then
            v.dx, v.dy = node_getPosition(dst)
        end
    end
    if not v.dx then
        local dx, dy = node_getPathPosition(me, 1)
        if dx ~= 0 or dy ~= 0 then
            v.dx, v.dy = dx, dy
        end
    end
    local x, y = node_getPosition(me)
    v.pe = spawnParticleEffect("warpspiral2", x, y)
end

local function checkAndWarp(e, me, n)
    if node_isEntityIn(me, e) then
    
        local x, y = v.dx, v.dy
        if e == n then
            if isObstructed(x, y) then
                warnLog("localwarp warning: warping to obstructed spot")
            end
            screenFadeCapture()
        end
        spawnParticleEffect("spiritbeacon", entity_getPosition(e))
        
        entity_setPosition(e, x, y)
        fade(0.4, 0, 1, 1, 1)
        fade(0, 0.36, 1, 1, 1)
        
        if e == n then
            playSfx("spirit-return", nil, 1.66)
            spawnParticleEffect("spirit-big", x, y)
            screenFadeGo(0.3)
            cam_snap()
            --wait(FRAME_TIME) -- HACK: otherwise some teleporters warp to crazy locations in the wall -- eh, just wiggling the target point around usually solves this, so out this goes again
            entity_setPosition(e, x, y)
        elseif entity_isEntityInRange(e, v.n, 2000) then
            entity_playSfx(e, "spirit-return", nil, 0.7)
            spawnParticleEffect("spiritbeacon", x, y)
        end
    end
end

function update(me, dt)
    local on = node_isActive(me)
    if on and v.dx then
        local n = getNaija()
        --forAllEntities(checkAndWarp, me) -- FIXME: all other ents too (that are not helpers or special)
        checkAndWarp(n, me, n)
    end

    pe_setPosition(v.pe, node_getPosition(me))

    if v.on ~= on then
        v.on = on
        if on then
            pe_start(v.pe)
        else
            pe_stop(v.pe)
        end
    end
end



function song() end
function songNote() end
function songNoteDone() end


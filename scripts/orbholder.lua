-- Copyright (C) 2007, 2010 - Bit-Blot
--
-- This file is part of Aquaria.
--
-- Aquaria is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--
-- See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

-- fg: modified script to integrate into the circuit network and support dropping a captured orb again
-- reacts to "save" node: 
-- stores last orb's entity ID as flag (negative if charged)
-- changed default behavior to keep an orb locked even across map reloads

-- orb holder
v.energyOrb = 0
v.openedDoors = false
v.savedOrb = false
v.orbWeight = false

function init(me)
	setupEntity(me, "OrbHolder", -2)
	entity_setActivationType(me, AT_NONE)	
	entity_setAllDamageTargets(me, false)
    -- make this a switch compatible with 'cn readswitch' nodes
    -- STATE_IDLE: try to capture nearby orb; cn sees this as "not active"
    -- STATE_OFF: release orb; don't try to capture; cn sees this as "not active"
    -- STATE_ON: holding orb; don't try to capture; cn sees this as "active"
    esetv(me, EV_TYPEID, EVT_ACTIVATOR) 
end

local function releaseOrb(me)
    local orb = v.energyOrb
    if orb ~= 0 then
        v.energyOrb = 0
        entity_setProperty(orb, EP_MOVABLE, true)
        entity_setWeight(orb, v.orbWeight)
        entity_setFlag(me, 0)
    end
end

local function lockOrb(me, orb)
    v.energyOrb = orb
    v.orbWeight = entity_getWeight(orb)
    entity_setWeight(orb, 0)
    entity_clearVel(orb)
    entity_setProperty(orb, EP_MOVABLE, false)
end

function update(me, dt)
    local orb = v.energyOrb
    local state = entity_getState(me)
    if orb == 0 then
        if state == STATE_ON then
            entity_setState(me, STATE_IDLE)
        elseif state == STATE_IDLE then
            local near = entity_getNearestEntity(me, "EnergyOrb")
            if near ~= 0 then
                if entity_isEntityInRange(me, near, 64) then
                    orb = near
                    lockOrb(me, orb)
                end
            end
        end
    end
    
    if orb ~= 0 then
        local orbstate = entity_getState(orb)
        if orbstate == STATE_DEAD then
            entity_setState(me, STATE_OFF)
            return
        end
        entity_clearVel(orb)
        entity_setPosition(orb, entity_getPosition(me))
        -- compatibility stuff for openenergydoor node
        if not v.openedDoors and orbstate == STATE_CHARGED then
            v.openedDoors = true
            entity_setState(me, STATE_ON)
            local node = entity_getNearestNode(me)
            node_activate(node)
        end
        if not v.savedOrb and orbstate == STATE_IDLE then
            local node = entity_getNearestNode(me)
            node_activate(node)
            v.savedOrb = true
        end
        if v.openedDoors and orbstate == STATE_IDLE then
            v.openedDoors = false
        end
    end
end

function enterState(me)
    local state = entity_getState(me)
	if state == STATE_OFF then
        releaseOrb(me)
        entity_setStateTime(me, 1) -- don't accept any orb while in STATE_OFF
    elseif state == STATE_ON then
        if v.energyOrb == 0 then
            entity_setState(me, STATE_IDLE, nil, true) -- NO YOU DON'T
        end
    end
end

function exitState(me)
    local state = entity_getState(me)
	if state == STATE_OFF then
        entity_setState(me, STATE_IDLE)
    end
end

function hitSurface(me)
end

-- Standalone script -- no library dependencies!

-- Use this instead of 'openenergydoor'.
-- Improvements:
-- - If you place a tail point, it'll open the door closest to that
-- - It works for any entity that is EVT_DOOR, not just the 'energydoor' entity

local function findDoor(x, y)
    -- the filter sorts by distance, so the first entity that's a door is the correct one
    filterNearestEntities(x, y)
    while true do
        local e = getNextFilteredEntity()
        if e == 0 or eisv(e, EV_TYPEID, EVT_DOOR) then
            return e
        end
    end
end

function init(me)
end

function update(me, dt)
end

function activate(me)
	local energyOrb = node_getNearestEntity(me, "EnergyOrb")
	if energyOrb ~= 0 and entity_isState(energyOrb, STATE_CHARGED) then
        local x, y = node_getPathPosition(me, 1)
        if x == 0 and y == 0 then
            x, y = node_getPosition(me)
        end
		local door = findDoor(x, y)
		if door ~= 0 then
            if getMapTime() < 0.1 then
                entity_setState(door, STATE_OPENED)
            else
                entity_setState(door, STATE_OPEN)
            end
		end
	end
end

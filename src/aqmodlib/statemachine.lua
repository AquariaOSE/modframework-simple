-- slightly different semantics than Aquaria's built-in state machine

local M = {}

-- dummy
function M.onExitState()
end

-- dummy
function M.onEnterState()
end

function M:setState(state)
    local oldstate = self._state
    if oldstate ~= state then
        self._state = state
        self.onExitState(oldstate, state)
        self.onEnterState(state, oldstate)
    end
end

function M:getState()
    return self._state
end

function M:isState(state)
    return self._state == state
end



local meta = { __index = M }

local function statemachine_create(user, initState)
    return setmetatable( { user = user, _state = initState or false }, meta)
end

return {
    statemachine_create = statemachine_create,
}

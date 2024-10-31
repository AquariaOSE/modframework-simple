
-- -[ linear finite automaton ]-
-- supports an arbitrary amount of states with an adjustable failure tolerance

local tins = table.insert

local lfa = {}
lfa.__index = lfa

local function b2i(b)
    if b then return 1 end
    return 0
end

local function lfa_create(s, cb, tol)
    local self =
    {
        _seq = s,
        _tolerance = tonumber(tol) or 0,
        _callback = cb,
        _state = {}, -- last accepted positions, with fails
        _armed = false -- true if at least one accepting state was reached and no further input given
    }
    setmetatable(self, lfa)
    return self
end

function lfa:reset()
    table.clear(self._state)
    self._armed = false
end

function lfa:trigger()
    if self._armed then
        self._callback()
    end
end

function lfa:input(x)
    self._armed = false
    
    for i, state in pairs(self._state) do
        if state then
            local fails = state.fails
            local newpos = state.p + 1
            local want = self._seq[newpos]
            local final = #self._seq == newpos
            local accepted = want == x
            
            --debugLog(string.format("[%d] pos: (%d/%d), want: %d, got: %d, good: %d, final: %d, fails: %d", i, newpos, #self._seq, want, x, b2i(accepted), b2i(final), state.fails))
            
            if accepted then
                state.fails = 0
                if final then
                    self._armed = true
                    self._state[i] = nil -- drop this state
                else
                    state.p = newpos
                end
            else
                state.fails = state.fails + 1
                if state.fails <= self._tolerance then
                    -- still okay
                else
                    self._state[i] = nil -- drop this state
                end
            end
        end
    end
    
    if x == self._seq[1] then
        if #self._seq == 1 then
            self._armed = true
        else
            --debugLog("new lfa state")
            tins(self._state, { p = 1, fails = 0 })
        end
    end
end

return {
    lfa_create = lfa_create,
}

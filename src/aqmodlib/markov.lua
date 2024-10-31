-- markov chain

local tins = table.insert
local random = math.random
local function lowerbound(...)
    lowerbound = table.lowerbound
    return lowerbound(...)
end

local M = {}
M.__index = M

local function autogenState(t, k)
    local state = { _probs = {}, _maxprob = 0, name = k }
    t[k] = state
    return state
end
local autogenMeta = { __index = autogenState }

function M.chain(problist, allowSelfLoop)
    local chain = setmetatable({}, autogenMeta)
    for k, entry in pairs(problist) do
        if type(k) == "number" then
            local nFrom, nTo, p = unpack(entry)
            if not allowSelfLoop and nFrom == nTo then
                error("markov chain contains a self loop: [" .. nFrom .. "]")
            end
            local from = chain[nFrom]
            local to = chain[nTo]
            tins(from, to)
            local newmaxprob = from._maxprob + p
            tins(from._probs, newmaxprob)
            from._maxprob = newmaxprob
        else
            local from = chain[k]
            for var, val in pairs(entry) do
                from[var] = val
            end
        end
    end
    setmetatable(chain, nil)
    
    -- cheap check for terminals / dead ends
    for k, state in pairs(chain) do
        assert(#state == #state._probs)
        if #state == 0 then
            error("markov: state [" .. k .. "] does not have any followers")
        end
    end
    
    return chain
end

function M.new(states, initName)
    local begin = states[initName]
    if not begin then
        error("markov: no such state: " .. tostring(initName))
    end
    local self = { curState = begin }
    return setmetatable(self, M)
end

function M:next()
    local state = self.curState
    local nextstate = state[lowerbound(state._probs, random() * state._maxprob)]
    self.curState = nextstate
    return nextstate.name
end

rawset(_G, "markov", M)

--[[
local function test()
    math.randomseed(os.time())
    local states = {
        { "A", "B", 0.5 },
        { "B", "A", 0.2 },
        { "B", "C", 0.8 },
        { "C", "C", 0.8 },
        { "C", "A", 0.2 },
        { "A", "D", 0.3 },
        { "D", "D", 0.6 },
        { "D", "B", 0.2 },
    }
    local chain = markov.chain(states, true)
    local m = markov.new(chain, "A")
    
    for i = 1, 100 do
        local s = m:next()
        io.write(s)
    end
        
end
dofile("table.lua")
test()
]]



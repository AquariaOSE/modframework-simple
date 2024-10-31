-- v table hackery
-- also check entity_callContext(), node_callContext()

-- switches to a new v. returns current v. call v_restoreContext() with return value later.
local function v_pushContext(vv)
    assert(type(vv) == "table")
    local oldv = v
    v = vv
    return oldv
end

-- switches back to a v previously returned from v_pushContext()
local function v_restoreContext(prev)
    assert(type(prev) == "table") -- likely incorrect
    v = prev
end

return {
    v_pushContext = v_pushContext,
    v_restoreContext = v_restoreContext,
}

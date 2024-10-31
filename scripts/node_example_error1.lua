-- Script should throw an error on click

function init(me)
    node_setCursorActivation(me, true)
end

function update(me, dt)
end

-- Upon calling this, node_setCursorActivatio() will result in 'attempt to call a nil value',
-- which would normally be silently ignored aside from an entry in the game's log.
-- The script framework should however first complain about 'node_setCursorActivatio' being an undefined
-- global variable to make this kind of error easier to spot.
function activate(me)
    node_setCursorActivatio(me, false) -- <<< TYPO!
    playSfx("secret") -- will never reach this
end

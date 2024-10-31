-- Script should throw warnings on click

-- setting globals that are ALL_CAPS_WITH_UNDERSCORES is fine
-- (but if only this script uses a variable, this should be a local, not a global!)
MY_GLOBAL_TEST = 42

function init(me)
    node_setCursorActivation(me, true)
end

function update(me, dt)
end

-- while technically not errors, both statements in this function are highly fishy
-- and usually an indication for a bug. The framework code that comes with this mod template
-- catches these problems and throws a hard error.
function activate(me)

    -- this "accidentally" sets a global variable.
    -- globals are a source of so many problems and should be avoided.
    numberr = 1
    
    -- on its own this would do nothing,
    -- but an access to an undefined global is now a hard error.
    -- (not reached if the above line already throws an error)
    local a = does_not_exist 
    
    -- The above lines both causes a hard error, so this line is not reached.
    -- Without the error handler in place, this would play normally.
    playSfx("secret") 
end

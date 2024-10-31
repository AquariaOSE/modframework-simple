-- FIXME: implement pingpong

-- index: (using plain numbers for speed)
-- [1] = current value
-- [2] = current time
-- [3] = max time
-- [4] = start value
-- [5] = ease?
-- [6] = end value
-- [7] = interpolation on?

local interpolated = {}
local interp_meta -- pre-decl

function interpolated.new(val, valend, t, loops, pingpong, ease)
    -- loops, pingpong NYI
    val = val or 0
    local ip = { val, 0, t or 0, val, ease, valend or val }
    return setmetatable(ip, interp_meta)
end

function interpolated:get()
    return self[1]
end

function interpolated:getStart()
    return self[4]
end

function interpolated:getEnd()
    return self[6], self[3]
end

function interpolated:setEnd(val)
    self[6] = val
end

function interpolated:isInterpolating()
    return self[7]
end

local abs = math.abs

function interpolated:interpolateTo(newval, t, loops, pingpong, ease)
    -- loops, pingpong NYI
    self[5] = ease or false
    
    if abs(self[1] - newval) < 0.001 then
        self[1] = newval
        self[6] = newval
        self[7] = false
        return
    end
    
    t = t or 0
    
    if t < 0 then
        t = (newval - self[1]) / -t
    end
    
    self[2] = 0
    self[3] = t
    if t == 0 then
        self[1] = newval
        self[6] = newval
        self[7] = false
    else
        self[4] = self[1]
        self[6] = newval
        self[7] = true
    end
end

function interpolated:update(dt)
    if self[7] then
        local passed = self[2] + dt
        self[2] = passed
        
        if passed >= self[3] then
            self[1] = self[6]
            self[7] = false
        elseif self[5] then
            local dt = passed / self[3]
            local m = 2*dt*dt*dt
            local n = 3*dt*dt
            self[1] = (self[4] * (m - n + 1)) + (self[6] * (n - m))
        else
            self[1] = self[4] + (self[6] - self[4]) * (passed / self[3])
        end
    end
    return self[1]
end

interp_meta = { __index = interpolated, __call = interpolated.get }


rawset(_G, "interpolated", interpolated)

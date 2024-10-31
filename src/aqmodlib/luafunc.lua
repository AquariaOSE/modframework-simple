local unpack = unpack
local select = select

-- same as xpcall(f, errf), but additional args can follow: xxpcall(f, errf, ...)
local xxpcall
do
    -- code is slightly convoluted to prevent additional per-call memory allocation
    local ARGS = {}
    local CALLFUNC
    local NUMARGS
    local function _fillArgs(f, ...)
        CALLFUNC = f
        NUMARGS = select("#", ...)
        for i = 1, NUMARGS do
            ARGS[i] = select(i, ...)
        end
    end
    local function _callHelper()
        return CALLFUNC(unpack(ARGS, 1, NUMARGS)) -- this safely handles returned NILs or NILs in ARGS
    end
    xxpcall = function(f, errf, ...)
        _fillArgs(f, ...)
        return xpcall(_callHelper, errf)
    end
end


-- like select(), but returns the first n parameters. Returns exactly n results.
local selectfirst
do
    local function makesel(n)
        local p = {}
        for i = 1, n do
            p[i] = "_" .. i
        end
        local a = table.concat(p, ",")
        -- TODO: This would be way more efficient with some hackery or asm (don't need the MOVE instructions for the locals)
        return assert(loadstring("local " .. a .. " = ...; return " .. a))
    end
    local SEL = setmetatable({ [0] = function() end }, {
        __index = function(t, k)
            local f = makesel(k)
            t[k] = f
            return f
        end
    })

    selectfirst = function(n, ...)
        return SEL[n](...)
    end 
end


return {
    xxpcall = xxpcall,
    selectfirst = selectfirst
}




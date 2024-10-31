local tins = table.insert

local function argsplit(s)
    local ret = {}
    local balance = 0
    local accu = ""
    for p in s:gmatch"%S+" do
        local _, open = p:gsub("%(", "")
        local _, close = p:gsub("%)", "")
        balance = balance + open - close
        assert(balance >= 0, "parse error - too many closing ))))")
        accu = accu .. " " .. p .. " "
        if balance == 0 then
            tins(ret, accu)
            accu = ""
        end
    end
    assert(balance == 0, "parse error - parentheses unbalanced")
    return ret
end

print(unpack(argsplit(" a b   c")))
print(unpack(argsplit(" a+b   c")))
print(unpack(argsplit(" (a + b)   (c) ")))
print(unpack(argsplit(" a*(a + b)+c   ( c)+1 ")))

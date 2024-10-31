
local string = string
local random = math.random
local strfmt = string.format
local gsub = string.gsub
local strfind = string.find
local strsub = string.sub
local tins = table.insert
local strbyte = string.byte
local upper = string.upper
local lower = string.lower

-- explode(string, seperator, skipEmpty)
function string.explode(p, d, skip)
  if(#p == 1) then return {p} end
  local t, ll, l, nw
  
  ll = 0
  t = {}
    while true do
        l = strfind(p,d,ll,true) -- find the next d in the string
        if l ~= nil then -- if "not not" found then..
            nw = strsub(p,ll,l-1)
            if not skip or #nw > 0 then
                tins(t, nw) -- Save it in our array.
            end
            ll=l+1 -- save just after where we found it for searching next time.
        else
            nw = strsub(p,ll)
            if not skip or #nw > 0 then
                tins(t, nw) -- Save what's left in our array.
            end
            break -- Break at end, as it should be, according to the lua manual.
        end
    end
    return t
end

function string.startsWith(String,Start)
   return strsub(String,1,#Start)==Start
end

function string.endsWith(String,End)
   return End=='' or strsub(String,-#End)==End
end

local function _char2hex(c)
    return strfmt("%02X",strbyte(c))
end

function string.tohex(s)
    return gsub(s, "(.)", _char2hex)
end

function string.hash(s)
  local c = 1
  local len = #s
  local strbyte = strbyte
  local fmod = math.fmod
  for i = 1, len, 3 do 
    c = fmod(c*8161, 4294967279)
      + (strbyte(s, i) * 16776193)
      + ((strbyte(s, i+1) or (len-i+256)) * 8372226)
      + ((strbyte(s, i+2) or (len-i+256)) * 3932164)
  end
  return fmod(c, 4294967291)
end

do
    local DRUNK_CHANCE
    local function doit(mul)
        return (not DRUNK_CHANCE or random() < DRUNK_CHANCE * (mul or 1)) or nil
    end
    local function drunk_replace_sh(a, b)
        return (doit(2) and (a .. "h" .. b)) or (a .. b)
    end
    local simpleRep = {
        ["in"] = "a",
        f = "fff",
        ll = "lll",
        ould = "oul",
    }
    local function simple(x)
        return doit() and simpleRep[x]
    end
    local function g_aeiou(_, x) -- drop "g"
        return doit() and ("w" .. x)
    end
    local function y_ley(x)
        return doit() and (x .. "ey")
    end
    local function nd_n(x)
        return doit() and  ("n" .. x)
    end
    function string.drunkenize(s, chance)
        DRUNK_CHANCE = chance
        s= s:gsub("([Ss])([^SsHh])", drunk_replace_sh)
            :gsub("in", simple)
            :gsub("f", simple)
            :gsub("ll", simple)
            :gsub("ould", simple)
            :gsub("(g)([aeiou])", g_aeiou)
            :gsub("(%S)y", y_ley)
            :gsub("nd[%s%.](%S)", nd_n)
        return s
    end 
end

local function _capsub(first, rest)
    return upper(first) .. lower(rest)
end
function string.capitalize(s)
    return (s:gsub("%f[%S](.)(%S*)", _capsub):gsub("^%l", upper))
end

function string.killws(s)
    return (gsub(s, "%s+", ""))
end

function string.split(s)
    local t = {}
    local i = 1
    for x in s:gmatch("%S+") do
        t[i] = x
        i = i + 1
    end
    return t
end

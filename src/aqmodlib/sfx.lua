
-- Sound loop wrapper class
-- Simplifies dealing with sound loops as it helps to move away from global pointers and things.
-- Also prevents the "endless sound loop" problem that carries on until the game is closed
-- (Sound never stopped will play forever, as the channel pointers get lost)
-- Still not perfect, but hooking into Lua's GC counters the problem.

local S = {}

function S:stop(t)
    if self._loop then
        fadeSfx(self._loop, t or 0)
        self._loop = nil
    end
end

function S:play(freq, vol, ...) -- x, y, maxdist, ...
    if self._loop then
        errorLog("sfxloop " .. self._file .. " already playing")
    else
        local ptr = playSfx(self._file, freq, vol, -1, ...) -- infinite loop
        if ptr and ptr ~= 0 then
            self._loop = ptr
        elseif MOD_DEVMODE then
            errorLog("sfxloop: playSfx null pointer for file " .. tostring(self._file))
        end
    end
end

function S:playEntity(e, freq, vol, ...) -- maxdist, ...
    if self._loop then
        errorLog("sfxloop " .. self._file .. " already playing")
    else
        self._loop = entity_playSfx(e, self._file, freq, vol, -1, nil, ...) -- infinite loop, no fadeout
    end
end

function S:isPlaying()
    return not not self._loop
end

function S:getFileName()
    return self._file
end

function S:setFileName(fn)
    self._file = fn
end

local Smeta = {
    __index = S,
    __gc = S.stop, -- Does not get called in Lua 5.1, but works in 5.2
}

-- Workaround function for 5.1
local function GC_Lua51(proxy)
    getmetatable(proxy).sfx:stop()
end

local function createSoundLoop(file)
    assert(type(file) == "string", "createSoundLoop(): Expected string")
    debugLog("createSoundLoop(" .. file .. ")")
    loadSound(file)

    local sfx = { _file = file }

    -- HACK: Finalizers on tables do not work in Lua 5.1 (they do in 5.2);
    -- they only work on userdata. The *only* way to create userdata from Lua
    -- which have a metatable attached is to use the undocumented newproxy() function.
    -- In 5.2, newproxy() does not exist and this workaround is not needed.
    if rawget(_G, "newproxy") then -- _VERSION == "Lua 5.1"
        sfx._proxy = newproxy(true)
        local pmeta = getmetatable(sfx._proxy)
        pmeta.__gc = GC_Lua51
        pmeta.sfx = sfx -- crosslink
    end

    return setmetatable(sfx, Smeta)
end



local soundcache = {
    bbbounce = true,
    bbpoweron = true,
    bbsplash = true,
    beastburst = true,
    beastform = true,
    bigrockhit = true,
    bind = true,
    bite = true,
    blasterfire = true,
    boil = true,
    ["bubble-lid"] = true,
    burst = true,
    changeclothes1 = true,
    changeclothes2 = true,
    chargeloop = true,
    click = true,
    collectible = true,
    collectmana = true,
    controlhint = true,
    cook = true,
    currentloop = true,
    death = true,
    defense = true,
    denied = true,
    drop = true,
    ["dualform-absorb"] = true,
    ["dualform-charge"] = true,
    ["dualform-scream"] = true,
    ["dualform-shot"] = true,
    ["dualform-switch"] = true,
    dualform = true,
    emerge = true,
    energy = true,
    energyblastfire = true,
    energyblasthit = true,
    energyform = true,
    energyorbcharge = true,
    fishform = true,
    fizzlebarrier = true,
    ["gem-collect"] = true,
    genericdeath = true,
    gounder = true,
    gulp = true,
    ["healthupgrade-collect"] = true,
    ["healthupgrade-open"] = true,
    heartbeat = true,
    ["hit-soft"] = true,
    hit1 = true,
    hit2 = true,
    hit3 = true,
    hit4 = true,
    hit5 = true,
    hit6 = true,
    hit7 = true,
    hit8 = true,
    ink = true,
    invincible = true,
    jellyblup = true,
    leach = true,
    locktowall = true,
    ["low-note0"] = true,
    ["low-note1"] = true,
    ["low-note2"] = true,
    ["low-note3"] = true,
    ["low-note4"] = true,
    ["low-note5"] = true,
    ["low-note6"] = true,
    ["low-note6b"] = true,
    ["low-note7"] = true,
    ["memory-flash"] = true,
    ["memory-found"] = true,
    memorycrystalactivate = true,
    ["menu-close"] = true,
    ["menu-open"] = true,
    ["menu-switch"] = true,
    menunote0 = true,
    menunote1 = true,
    menunote2 = true,
    menunote3 = true,
    menunote4 = true,
    menunote5 = true,
    menunote6 = true,
    menunote6b = true,
    menunote7 = true,
    menuselect = true,
    metalexplode = true,
    naijachildgiggle = true,
    naijaevillaugh1 = true,
    naijaevillaugh2 = true,
    naijaevillaugh3 = true,
    naijaew1 = true,
    naijaew2 = true,
    naijaew3 = true,
    naijagasp = true,
    naijagiggle1 = true,
    naijagiggle2 = true,
    naijagiggle3 = true,
    naijagiggle4 = true,
    naijagiggle5 = true,
    naijalaugh1 = true,
    naijalaugh2 = true,
    naijalaugh3 = true,
    naijali1 = true,
    naijali2 = true,
    naijalow1 = true,
    naijalow2 = true,
    naijalow3 = true,
    naijalow4 = true,
    naijasadsigh1 = true,
    naijasadsigh2 = true,
    naijasadsigh3 = true,
    naijasigh1 = true,
    naijasigh2 = true,
    naijasigh3 = true,
    naijaugh1 = true,
    naijaugh2 = true,
    naijaugh3 = true,
    naijaugh4 = true,
    naijawow1 = true,
    naijawow2 = true,
    naijawow3 = true,
    naijayum = true,
    naijazapped = true,
    natureform = true,
    nautilus = true,
    noeffect = true,
    normalform = true,
    note0 = true,
    note1 = true,
    note2 = true,
    note3 = true,
    note4 = true,
    note5 = true,
    note6 = true,
    note6b = true,
    note7 = true,
    ompo = true,
    originalraspberryshot = true,
    pain = true,
    ["pet-off"] = true,
    ["pet-on"] = true,
    ["pickup-ingredient"] = true,
    ping = true,
    ["plant-open"] = true,
    poison = true,
    popshell = true,
    powerup = true,
    pushstone = true,
    ["recipemenu-close"] = true,
    ["recipemenu-open"] = true,
    ["recipemenu-pageturn"] = true,
    regen = true,
    ["rockhit-big"] = true,
    rockhit = true,
    rockstep = true,
    roll = true,
    roll2 = true,
    rollloop = true,
    saved = true,
    scuttle = true,
    secret = true,
    ["shield-hit"] = true,
    ["shield-loop"] = true,
    ["shield-on"] = true,
    shockwave = true,
    shuffle = true,
    speedup = true,
    spiderweb = true,
    spinefire = true,
    spinehit = true,
    ["spirit-beacon"] = true,
    ["spirit-enter"] = true,
    ["spirit-return"] = true,
    ["splash-into"] = true,
    ["splash-outof"] = true,
    splish = true,
    ["squishy-die"] = true,
    starmieshot = true,
    sunform = true,
    swimkick = true,
    ["target-lock"] = true,
    ["target-unlock"] = true,
    throwseed = true,
    thud = true,
    titleaction = true,
    ["treasure-select"] = true,
    triploop = true,
    tubeflower = true,
    tubeflowersuck = true,
    ubervinegrow = true,
    ubervineshrink = true,
    ["urchin-hit"] = true,
    vinehit = true,
    visionwakeup = true,
    wok = true,
}

local function soundIsPrecached(s)
    return soundcache[s:lower()] or false
end

return {
    createSoundLoop = createSoundLoop,
    soundIsPrecached = soundIsPrecached,
}


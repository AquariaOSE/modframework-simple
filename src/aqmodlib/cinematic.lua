
local BARS

local function createBar(x, y, sz2, t)
    local q = createQuad()
    quad_followCamera(q, 1)
    quad_color(q, 0, 0, 0)
    quad_setPosition(q, x, y)
    quad_setWidth(q, 2 * sz2)
    quad_setHeight(q, 600)
    quad_setCull(q, false)
    quad_setLayer(q, LR_BLACKBARS)
    table.insert(BARS, q)
    quad_alpha(q, 0)
    quad_alpha(q, 1, t)
    return q
end

local function createFadeBar(x, y, t)
    local q = createQuad("gui/edge")
    quad_followCamera(q, 1)
    quad_color(q, 0, 0, 0)
    quad_setPosition(q, x, y)
    quad_setWidth(q, 34);
    quad_setHeight(q, 620)
    quad_setCull(q, false)
    quad_setLayer(q, LR_BLACKBARS)
    table.insert(BARS, q)
    quad_alpha(q, 0)
    quad_alpha(q, 1, t)
    return q
end

local function createBlackBarsWide(t, xres)
    t = t or 0
    xres = (xres or 1200) - 800 -- FIXME: what is this?
    if #BARS > 0 then
        destroyBlackBarsWide(t)
    end
    local baseL = xres * -0.5
    local baseR = 800 + xres * 0.5
    
    local vw, vh = getScreenVirtualOff()
    -- int sz2 = (core->getVirtualWidth() - baseVirtualWidth)/2.0f;
    local sz2 = vw --* 0.5
    debugLog("baseL: " .. baseL .. "; baseR: " .. baseR .. "; sz2: " .. sz2)
    createBar(baseL - sz2, 300, sz2, t)
    createBar(baseR + sz2, 300, sz2, t)
    
    createFadeBar(baseL + 17, 300, t)
    quad_fh(createFadeBar(baseR - 17, 300, t))
end


local function destroyBlackBarsWide(t)
    if not BARS then
        return
    end
    t = t or 0
    while #BARS > 0 do
        quad_delete(table.remove(BARS), t)
    end
end


local function visionWide(folder, num, ignoreMusic, t, imgt, w, h)
    num = num or 0
    t = t or 0.1                -- fade time
    imgt = imgt or 0.1          -- image display time
    w = w or 1200 -- 600 * 2 (= 2:1 aspect ratio)
    h = h or 600
    
    toggleCursor(false)
    local hasInput = isInputEnabled()
    if hasInput then
        disableInput() -- hides the minimap
    end
    
    pause()
    fade(0, 0, 1, 1, 1)
    
    
    fade(1, t, 1, 1, 1)
    
    local vw, vh = getScreenVirtualOff()
    local totalw = 2 * vw + 800
    if w < totalw then
        createBlackBarsWide(t, w)
    end
    wait(t)
    
    
    
    local images = {}
    
    -- TODO: automatic scaling based on min width/height?
    
    for i = num-1, 0, -1 do
        local tex = string.format("visions/%s/%02d", folder, i)
        local q = createQuad(tex)
        quad_setLayer(q, LR_HUD)
        quad_setWidth(q, w)
        quad_setHeight(q, h)
        quad_followCamera(q, 1)
        quad_setPosition(q, 400, 300)
        quad_alpha(q, 0)
        table.insert(images, q)
    end
    
    if not ignoreMusic then
        musicVolume(0, t)
    end
    
    while #images > 0 do
        playSfx("memory-flash")
        local q = table.remove(images)
        quad_scale(q, 1.1, 1.1, (2 * t) + imgt)
        quad_alpha(q, 1)
        
        fade(0, t, 1, 1, 1)
        wait(t)
        
        wait(imgt)
        
        fade(1, t, 1, 1, 1)
        wait(t)
        
        quad_delete(q)
    end
    
    unpause()
    
    if hasInput then
        enableInput() -- re-enables the minimap
    end
    
    toggleCursor(true)
    
    playSfx("memory-flash")
    fade(0, t, 1, 1, 1)
    destroyBlackBarsWide(t)
    wait(t)
    
    if not ignoreMusic then
        musicVolume(1, t)
    end
    
    fade(0, 0, 0, 0, 0)
end

local function cs_quickFlash(t)
    fade2(1, t, 1, 1, 1)
    playSfx("memory-flash", 0, 0.5)
    watch(t)
    fade2(0, t, 1, 1, 1)
    watch(t)
end



local function cleanup(mapchange)
    if mapchange then
        BARS = rawget(_G, "._cinematic_blackbars")
        if not BARS or #BARS > 0 then
            BARS = {}
            rawset(_G, "._cinematic_blackbars", BARS)
        end
    end
    modlib_onClean(cleanup)
end
cleanup()


return {
    createBlackBarsWide = createBlackBarsWide,
    destroyBlackBarsWide = destroyBlackBarsWide,
    visionWide = visionWide,
    cs_quickFlash = cs_quickFlash,
}


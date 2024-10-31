
-- SuperFX: Rudimentary 3D support functions
-- The name hints at the acceleration chip utilized in some SNES games. :)

local P2 = 2 * 3.1415926

local sin = math.sin
local cos = math.cos

local function initPoints(count)
    local t = {}
    local ins = table.insert
    for i = 1,count do
        ins(t, { 0, 0, 0, 1 } )
    end
    return t
end

local function scale(points, s)
    for _, p in pairs(points) do
        p[1] = p[1] * s
        p[2] = p[2] * s
        p[3] = p[3] * s
        p[4] = p[4] * s
    end
end

local function scaleXYZ(points, x, y, z)
    for _, p in pairs(points) do
        p[1] = p[1] * x
        p[2] = p[2] * y
        p[3] = p[3] * z
    end
end

local function translate(points, x, y, z)
    for _, p in pairs(points) do
        p[1] = p[1] + x
        p[2] = p[2] + y
        p[3] = p[3] + z
    end
end

local function loadModel(file, s)
    local t = dofile("models/" .. file .. ".lua")
    for _, r in pairs(t) do
        -- add scale factor if missing
        if not r[4] then
            r[4] = 1
        end
    end
    if s then
        scaleXYZ(t, s, s, s)
    end
    return t
end

local function createLine(fromx, fromy, fromz, tox, toy, toz, pointCount, points)
    local ins = table.insert
    local t = points or {}
    local dx = tox - fromx
    local dy = toy - fromy
    local dz = toz - fromz
    local stepx = dx / pointCount
    local stepy = dy / pointCount
    local stepz = dz / pointCount
    
    local x = fromx
    local y = fromy
    local z = fromz
    
    for i = 1, pointCount do
        ins(t, { x, y, z, 1 } )
        x = x + stepx
        y = y + stepy
        z = z + stepz
    end
    return t
end

local function createCube(size, pointsPerEdge)
    local d = size
    local t = {}
    
    -- first rect
    createLine( d,  d,  d,  -d,  d,  d,   pointsPerEdge, t)
    createLine(-d,  d,  d,  -d, -d,  d,   pointsPerEdge, t)
    createLine(-d, -d,  d,   d, -d,  d,   pointsPerEdge, t)
    createLine( d, -d,  d,   d,  d,  d,   pointsPerEdge, t)
    
    -- second rect
    createLine( d,  d, -d,  -d,  d, -d,   pointsPerEdge, t)
    createLine(-d,  d, -d,  -d, -d, -d,   pointsPerEdge, t)
    createLine(-d, -d, -d,   d, -d, -d,   pointsPerEdge, t)
    createLine( d, -d, -d,   d,  d, -d,   pointsPerEdge, t)
    
    -- columns
    createLine(-d,  d,  d,  -d,  d, -d,   pointsPerEdge, t)
    createLine(-d, -d,  d,  -d, -d, -d,   pointsPerEdge, t)
    createLine( d, -d,  d,   d, -d, -d,   pointsPerEdge, t)
    createLine( d,  d,  d,   d,  d, -d,   pointsPerEdge, t)
    
    return t
end

-- calculates the perspective-corrected projection of a point cloud
-- each point in pin[i] must correspond to out[i]
local function transform(pin, out, rx, ry, rz, F)
    
    local sx = sin(rx)
    local cx = cos(rx)
    local sy = sin(ry)
    local cy = cos(ry)
    local sz = sin(rz)
    local cz = cos(rz)
    
    local x,y,z, xy,xz, yx,yz, zx,zy, scaleFactor
    local pt
        
    for i, p in pairs(pin) do
        x = p[1]
        y = p[2]
        z = p[3]

        -- rotation around x
        xy = cx*y - sx*z
        xz = sx*y + cx*z
        -- rotation around y
        yz = cy*xz - sy*x
        yx = sy*xz + cy*x
        -- rotation around z
        zx = cz*yx - sz*xy
        zy = sz*yx + cz*xy
        
        scaleFactor = F/(F + yz)
        
        pt = out[i]
        pt[1] = zx*scaleFactor
        pt[2] = zy*scaleFactor
        pt[3] = yz*scaleFactor -- FIXME: use 2 values, one perspective-corrected, and one for the actual Z value
        pt[4] = scaleFactor
    end 
end


rawset(_G, "superfx", {
    initPoints = initPoints,
    loadModel = loadModel,
    createLine = createLine,
    createCube = createCube,
    transform = transform,
    translate = translate,
    scale = scale,
    scaleXYZ = scaleXYZ,
})

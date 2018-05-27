Hills = class()

function Hills:init(tex, textureScale, maxKeyPoints)
    self.maxKeyPoints = maxKeyPoints
    self.textureScale = textureScale    --the greater, the smaller
    self:generateKeyPoints()
    self.texture = tex
    self.prevFromKeyPoint = -1
    self.prevToKeyPoint = -1
    borderVerticesTable = {}
    hillVerticesTable = {}
    hillTexCoordsTable = {}
end

function Hills:draw()
    self:generateVisible()
    for _,m in pairs(self.meshHills) do
        m:draw()
    end
end

function Hills:generateKeyPoints()
    self.keyPoints = {}
    local minDX = 220
    local minDY = 60
    local rangeDX = 100
    local rangeDY = 100
 
    local x = -minDX
    local y = HEIGHT / 2 - minDY
 
    local dy, ny 
    local sign = 1 -- +1 - going up, -1 - going  down
    local paddingTop = 100
    local paddingBottom = 100
 
    for i = 0, self.maxKeyPoints do
        self.keyPoints[i] = vec2(x, y)

        if (i == 0) then
            x = 0
            y = HEIGHT / 2
        else
            x = x + math.random(rangeDX) + minDX
            while(true) do
                dy = math.random(rangeDY) + minDY
                ny = y + dy * sign
                if(ny < HEIGHT - paddingTop and ny > paddingBottom) then
                    break
                end
                sign = -sign
            end
            y = ny
        end
        if (math.random()>.05) then
            sign = -sign
        end
    end
    for i = 1, 5 do    --create a flat surface at the beginning
        self.keyPoints[i].y = 300
    end
end

function Hills:generateVisible()
--Creates the visible part of the active (foremost) hills, 
--taking the key points generated by generateHillsKeyPoints()
--and creating a Box2D object as well as the corresponding textured surface

    -- key points interval for drawing
    self.fromKeyPoint = 0
    self.toKeyPoint = 0

    while (self.keyPoints[self.fromKeyPoint + 1].x <  offsetX - WIDTH / 8 / pScale) do
        self.fromKeyPoint = self.fromKeyPoint + 1
    end

    while (self.keyPoints[self.toKeyPoint].x < offsetX + WIDTH * 9 / 8 / pScale) do
        self.toKeyPoint = self.toKeyPoint + 1
    end

    if (self.prevFromKeyPoint == self.fromKeyPoint and 
        self.prevToKeyPoint == self.toKeyPoint) then return end  --exit if there are no changes

    local p0, p1
    
    self.meshHills = {}
    self.border = {}    --Is it necessary to destroy it before reusing????? Don't think so...
    --Destroy the unnecessary meshes/borders
    for i = self.prevFromKeyPoint, self.fromKeyPoint-1 do
        hillVerticesTable[i] = nil
        hillTexCoordsTable[i] = nil
        borderVerticesTable[i] = nil
    end
    --Create only the necessary sectors
    for i = self.fromKeyPoint, self.toKeyPoint-1 do
        p0 = self.keyPoints[i]
        p1 = self.keyPoints[i+1]

        if (hillVerticesTable[i] == nil) then
            hillVerticesTable[i], hillTexCoordsTable[i], borderVerticesTable[i], nBorderVertices =
                 self:calculatePoints(i, p0, p1)
            --finish the shape of the hills
            borderVerticesTable[i][nBorderVertices]=
                    vec2(borderVerticesTable[i][nBorderVertices-1].x, 0)
            borderVerticesTable[i][nBorderVertices+1]=
                    vec2(borderVerticesTable[i][1].x, 0)
        end
        local m = mesh()
        m.texture = self.texture
        m.vertices = hillVerticesTable[i]
        m.texCoords = hillTexCoordsTable[i]
        m:setColors(255,255,255,255)
        table.insert(self.meshHills, m)

        --load vertices in Box2D engine
        self.border[i] = physics.body(CHAIN,true,unpack(borderVerticesTable[i]))
    end


    self.prevFromKeyPoint = self.fromKeyPoint
    self.prevToKeyPoint = self.toKeyPoint
end

function Hills:calculatePoints(i, p0, p1)
    local nHillVertices = 1
    local nBorderVertices = 1
    local borderVertices = {}
    local hillVertices = {}
    local hillTexCoords = {}
    local pt1 = vec2()
        -- triangle strip between p0 and p1
    local hSegments = math.floor((p1.x-p0.x)/hillSegmentWidth)
    local dx = (p1.x - p0.x) / hSegments
    local da = math.pi / hSegments
    local ymid = (p0.y + p1.y) / 2
    local ampl = (p0.y - p1.y) / 2
    local pt0 = p0:copy()
    local incTex = dx / WIDTH * self.textureScale
    local pxTex = (self.keyPoints[i].x / 
                   WIDTH * self.textureScale) % maxTex
    borderVertices[nBorderVertices] = pt0:copy()
    nBorderVertices = nBorderVertices + 1
        
        for j = 1, hSegments do
            pt1.x = p0.x + j*dx
            pt1.y = ymid + ampl * math.cos(da*j)
            borderVertices[nBorderVertices] = pt1:copy()
            nBorderVertices = nBorderVertices + 1

            pxTex = pxTex + incTex
            pxTex = pxTex % maxTex
            local pxTex1 = (pxTex + incTex)
            
            --first triangle
            hillVertices[nHillVertices] = vec2(pt0.x, 0)
            hillTexCoords[nHillVertices] = vec2(pxTex, 1)
            nHillVertices = nHillVertices + 1

            hillVertices[nHillVertices] = vec2(pt1.x, 0)
            hillTexCoords[nHillVertices] = vec2(pxTex1, 1)
            nHillVertices = nHillVertices + 1
            
            hillVertices[nHillVertices] = vec2(pt0.x, pt0.y)
            hillTexCoords[nHillVertices] = vec2(pxTex, 0)
            nHillVertices = nHillVertices + 1

            --second triangle
            hillVertices[nHillVertices] = vec2(pt0.x, pt0.y)
            hillTexCoords[nHillVertices] = vec2(pxTex, 0)
            nHillVertices = nHillVertices + 1
            
            hillVertices[nHillVertices] = vec2(pt1.x, 0)
            hillTexCoords[nHillVertices] = vec2(pxTex1, 1)
            nHillVertices = nHillVertices + 1
            
            hillVertices[nHillVertices] = vec2(pt1.x, pt1.y)
            hillTexCoords[nHillVertices] = vec2(pxTex1, 0)
            nHillVertices = nHillVertices + 1
 
            pt0 = pt1:copy()
        end
    return hillVertices, hillTexCoords, borderVertices, nBorderVertices
end
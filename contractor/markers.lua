-- =============================================================================
-- markers.lua  --  3D markers in the game world for the current contract.
--
--   Spots still to build: a light blue tile highlight plus a wireframe box
--   around the object (each can be turned off in Preferences).
--   Stairs/ladders: highlighted in yellow while furniture is still needed on a
--   different floor, but only those going the right way (a "Climb-up" option
--   when it's upstairs, "Climb-down" when it's downstairs).
--
-- The game only knows about objects near you, so every couple of seconds (while
-- you're near the house) we look for spots and stairs we haven't found yet.
-- =============================================================================

local Util = require("util")
local Prefs = require("prefs")

local Markers = {}

-- ---- Settings -----------------------------------------------------------------
-- Distances are in "fine" units: 512 = one tile.
local TILE        = 512
local LIFT        = 8               -- small gap above the ground so it doesn't flicker
local WALL_HEIGHT = 1000            -- box height when we can't work out a better one
local FADE_START  = 25 * TILE       -- markers start fading out this far away...
local FADE_END    = 35 * TILE       -- ...and are gone by here
local SCAN_EVERY  = 3               -- look for new objects every 3 server ticks (~1.8s)
local NEAR_HOUSE  = 40              -- only look when within this many tiles of the house
local STAIRS_RANGE  = 25            -- tiles around you to look for stairs
local STAIRS_MARGIN = 3             -- stairs can be this many tiles outside the house box

-- Colours as 0xRRGGBBAA (red, green, blue, opacity)
local SPOT_COLOURS   = { edge = 0x66CCFFFF, fill = 0x99D9FF60 }   -- light blue
local STAIRS_COLOURS = { edge = 0xFFCC33FF, fill = 0xFFCC3360 }   -- yellow

-- Some spots' objects are placed under a different name. The Aereck pews'
-- objects are all "<name>_RIGHT"; nothing in the world uses the plain name.
local SPOT_SUFFIXES = { "", "_RIGHT" }

-- ---- State --------------------------------------------------------------------
local house = nil          -- current contract's house (nil = no contract)
local wanted = {}          -- spot variable name -> spot, for spots still to build
local spotMarkers = {}     -- spot variable name -> marker name
local missing = 0          -- wanted spots without a marker yet
local stairMarkers = {}    -- marker names for the stairs currently highlighted
local stairsFor = nil      -- the floor + direction those stairs are for, e.g. "0up"
local tick = 0

-- ---- Object size --------------------------------------------------------------------
-- How tall to make the box. The API doesn't give an object's model size. Some
-- objects have a "custom bounding" box (used for clicking on them), which is the
-- best guide. Otherwise, as high as the walls: the gap to the floor above.
local function objectHeight(loc, bounds)
    if bounds ~= nil then
        local h = math.abs(bounds.maximum.y - bounds.minimum.y)
        if h >= 100 and h <= 3000 then return h end
    end
    local c = loc.coordGrid
    if c.level < 3 then
        local ok, h = pcall(function()
            local p = c:ToCoordFine(true).position
            return math.abs(World.GetGroundHeight(c.level + 1, p.x, p.z)
                          - World.GetGroundHeight(c.level, p.x, p.z))
        end)
        if ok and h ~= nil and h >= 200 and h <= 3000 then return h end
    end
    return WALL_HEIGHT
end

-- The area the marker covers, as x1, z1, x2, z2 in fine units, measured from the
-- centre of the object's first tile (where a marker is placed). Uses the first
-- of: the object's size box (follows its model), the parent object's size (the
-- spot itself rather than its "space" ghost), or the object's own size.
local function footprint(loc, bounds)
    local w, l = math.max(1, loc.width), math.max(1, loc.length)
    local turns = (loc.rotationType or 0) % 4

    if bounds ~= nil then
        local x1, z1, x2, z2 = bounds.minimum.x, bounds.minimum.z, bounds.maximum.x, bounds.maximum.z
        -- Turn it to match the object, 90 degrees per step (direction is a guess)
        for _ = 1, turns do x1, z1, x2, z2 = z1, -x2, z2, -x1 end
        if x2 - x1 >= 64 and z2 - z1 >= 64 then
            -- The box is around the middle of the footprint, not the first tile
            local cx, cz = (w - 1) * TILE / 2, (l - 1) * TILE / 2
            return cx + x1, cz + z1, cx + x2, cz + z2
        end
    end

    local parent = loc.parentConfig
    if parent ~= nil then
        local pw, pl = parent.width, parent.length
        if turns % 2 == 1 then pw, pl = pl, pw end   -- a quarter turn swaps them
        if pw * pl > w * l then w, l = pw, pl end
    end
    return -TILE / 2, -TILE / 2, w * TILE - TILE / 2, l * TILE - TILE / 2
end

-- ---- Building the shape ---------------------------------------------------------
-- withTile: a tile highlight (outline + see-through fill) over the footprint.
-- withBox: a wireframe box around the object, height tall.
local function makeShape(x1, z1, x2, z2, colours, withTile, withBox, height)
    local corners = { { x1, z1 }, { x2, z1 }, { x2, z2 }, { x1, z2 } }
    local positions, rgba = {}, {}
    local function addCorners(y, colour)
        for _, p in ipairs(corners) do
            positions[#positions + 1] = Vector3.new(p[1], y, p[2])
            rgba[#rgba + 1] = colour
        end
    end

    -- 0-3: ground outline (used by both the tile highlight and the box)
    addCorners(0, colours.edge)
    local lines = { 0, 1, 1, 2, 2, 3, 3, 0 }
    local tris = {}
    if withTile then
        addCorners(0, colours.fill)                    -- 4-7: see-through fill
        tris = { 4, 5, 6, 4, 6, 7 }
    end
    if withBox then
        local top = #positions                         -- first top corner
        addCorners(height, colours.edge)
        for i = 0, 3 do
            local nextI = (i + 1) % 4
            lines[#lines + 1], lines[#lines + 2] = top + i, top + nextI   -- top edge
            lines[#lines + 1], lines[#lines + 2] = i, top + i              -- upright
        end
    end

    local data = ShapeData.new()
    data.positions, data.rgba, data.lines, data.tris = positions, rgba, lines, tris
    return data
end

local function removeMarker(name)
    if ShapeList.GetEntity(name) ~= nil then ShapeList.DestroyEntity(name) end
end

-- Creates (or replaces) a marker on an object. Returns the marker name, or nil
-- if nothing was drawn (both tile and box turned off, or the game refused it).
local function placeMarker(name, loc, colours, withTile, withBox)
    removeMarker(name)
    if not withTile and not withBox then return nil end

    local cfg = loc.config or loc.parentConfig
    local bounds = cfg ~= nil and cfg.hasCustomBounding and cfg.customBounding or nil
    local x1, z1, x2, z2 = footprint(loc, bounds)
    local entity = ShapeList.CreateEntity(name)
    if entity == nil then return nil end
    if not entity:SetShapeData(makeShape(x1, z1, x2, z2, colours, withTile, withBox,
                                         objectHeight(loc, bounds))) then
        ShapeList.DestroyEntity(entity)
        return nil
    end
    entity.coordGrid = loc.coordGrid     -- also puts it on the right floor
    entity.heightOffset = LIFT
    entity.ignoreDepth = Prefs.get("throughWalls")   -- true = visible through walls
    entity:SetDrawDistance(FADE_START, FADE_END)
    return name
end

-- ---- Spots --------------------------------------------------------------------
-- Finds a spot's object. Each spot variable has an object with the same name
-- (its "parent config"), or a SPOT_SUFFIXES variant. Only nearby objects can be
-- found. pcall in case looking up a name the game doesn't have is an error.
local function findSpotLoc(name)
    for _, suffix in ipairs(SPOT_SUFFIXES) do
        local ok, cfg = pcall(function() return config.Loc[name .. suffix] end)
        local loc = ok and cfg and LocList.ByParentConfig(cfg)[1]
        if loc and loc.isValid then return loc end
    end
    return nil
end

-- Looks for spots we haven't marked yet
local function findSpots()
    if missing == 0 then return end
    local withTile, withBox = Prefs.get("tiles"), Prefs.get("boxes")
    if not withTile and not withBox then return end
    for name in pairs(wanted) do
        if spotMarkers[name] == nil then
            local loc = findSpotLoc(name)
            if loc ~= nil then
                spotMarkers[name] = placeMarker("spot_" .. name, loc, SPOT_COLOURS, withTile, withBox)
                if spotMarkers[name] ~= nil then missing = missing - 1 end
            end
        end
    end
end

-- ---- Stairs -------------------------------------------------------------------
local function clearStairs()
    for _, name in ipairs(stairMarkers) do removeMarker(name) end
    stairMarkers, stairsFor = {}, nil
end

-- Does this object have a menu option climbing the way we want?
-- Matches "Climb-up", "Climb up" and "Climb-upstairs" (and the same for down).
local function hasClimbOption(loc, direction)
    local cfg = loc.config or loc.parentConfig
    if cfg == nil or cfg.opNames == nil then return false end
    local pattern = "^climb[%s%-]?" .. direction
    for _, opName in pairs(cfg.opNames) do
        if tostring(opName):lower():find(pattern) then return true end
    end
    return false
end

-- Highlights the house's stairs on your floor if anything is left on another
-- floor: ones going up if it's above you, down if it's below you.
local function updateStairs(here)
    if not Prefs.get("stairs") then clearStairs() return end

    local direction = nil
    for _, spot in pairs(wanted) do
        if spot.level > here.level then direction = "up" break end
        if spot.level < here.level then direction = "down" end
    end
    if direction == nil then clearStairs() return end

    -- Stairs don't move: once found for this floor and direction, keep them
    local key = here.level .. direction
    if key == stairsFor and #stairMarkers > 0 then return end
    clearStairs()

    local found = LocList.Filter({
        coordGrid = here, range = STAIRS_RANGE, sameLevel = true,
        func = function(loc)
            if not loc.isValid then return false end
            local c = loc.coordGrid
            return c.x >= house.minX - STAIRS_MARGIN and c.x <= house.maxX + STAIRS_MARGIN
               and c.z >= house.minZ - STAIRS_MARGIN and c.z <= house.maxZ + STAIRS_MARGIN
               and hasClimbOption(loc, direction)
        end,
    })
    stairsFor = key
    for i, loc in ipairs(found) do
        local name = placeMarker("stairs_" .. i, loc, STAIRS_COLOURS, true, true)
        if name ~= nil then stairMarkers[#stairMarkers + 1] = name end
    end
end

-- ---- Scanning -------------------------------------------------------------------
local function scan()
    if house == nil then return end
    local player = Player.GetEntity()
    if player == nil then return end
    local here = player.coordGrid
    if Util.distanceToBox(house, here) > NEAR_HOUSE then return end   -- objects won't be loaded
    findSpots()
    updateStairs(here)
end

local function clearSpots()
    for _, name in pairs(spotMarkers) do removeMarker(name) end
    spotMarkers = {}
end

-- ---- Public functions ---------------------------------------------------------
-- c is the result of Tracker.read(). Removes markers for spots that are built,
-- and looks for the rest straight away.
function Markers.setContract(c)
    house = (c.id ~= 0) and c.house or nil
    wanted, missing = {}, 0
    for _, spot in ipairs(c.spots) do wanted[spot.name] = spot end

    for name, markerName in pairs(spotMarkers) do
        if wanted[name] == nil then
            removeMarker(markerName)
            spotMarkers[name] = nil
        end
    end
    for name in pairs(wanted) do
        if spotMarkers[name] == nil then missing = missing + 1 end
    end

    -- What's left may now be on a different floor, so look at the stairs again
    clearStairs()
    if house == nil then clearSpots() else scan() end
end

-- A marker preference changed: remove every marker and draw them again
local MARKER_PREFS = { tiles = true, boxes = true, stairs = true, throughWalls = true }
Prefs.onChange(function(key)
    if not MARKER_PREFS[key] then return end
    clearSpots()
    clearStairs()
    missing = 0
    for _ in pairs(wanted) do missing = missing + 1 end
    scan()
end)

-- Every few server ticks, look for objects that have come into range
Event.ServerLogic.Subscribe("contractorMarkers", function()
    tick = tick + 1
    if tick % SCAN_EVERY == 0 then scan() end
end)

return Markers

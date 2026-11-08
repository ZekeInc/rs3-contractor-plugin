-- =============================================================================
-- hints.lua  --  The contract house on the world map and minimap, and the
-- game's own yellow hint arrow over it.
--
-- Uses the game's HintList (undocumented; see CLAUDE.md):
--   AddPolygon  a see-through box over the house, drawn by the game on the
--               world map and the minimap
--   AddArrow    the hint arrow over the house (the game also shows it on the minimap)
-- Both are turned on/off in Preferences. Turning the plugin off removes them too.
-- The arrow hides while you're within 10 tiles of the house, and comes back
-- when you leave.
--
-- WARNING: never pass a HintList function straight to pcall
-- (pcall(HintList.AddArrow, t)): the game looks up which plugin called it, finds
-- none, and crashes. Always call it inside a function, as call() below does.
-- =============================================================================

local Util = require("util")
local Prefs = require("prefs")

local Hints = {}

local BOX_NAME, ARROW_NAME = "contractor:house", "contractor:arrow"
local BOX_FILL    = 0x3399FF55   -- see-through light blue (colours are 0xRRGGBBAA)
local BOX_OUTLINE = 0x3399FFFF   -- solid light blue
local ARROW_HEIGHT = 900         -- how high the arrow floats, in fine units (1/512 tile)

local house = nil    -- the current contract's house from houses.lua (nil = no contract)
local dirty = true   -- something changed: redo the hints on the next tick
local added = {}     -- name -> "Arrow" or "Polygon", for hints the game accepted

local NEAR_TILES  = 10   -- the arrow hides when you're this close to the house (or inside)
local CHECK_TICKS = 25   -- how often to check where you are, in Logic ticks (25 = half a second)
local near = false       -- were you near the house at the last check
local checkTick = 0

-- Calls HintList.<fnName>(arg) safely; true if the game said it worked
local function call(fnName, arg)
    local ok, result = pcall(function() return HintList[fnName](arg) end)
    if not ok then Util.log("HintList." .. fnName .. " failed:", result) end
    return ok and result == true
end

-- A ground-floor tile from world x/z (a CoordGrid is built from map square + local tile)
local function tile(x, z) return CoordGrid.new(0, x // 64, z // 64, x % 64, z % 64) end

local function removeAll()
    for name, kind in pairs(added) do call("Remove" .. kind, name) end
    added = {}
end

local function addAll()
    if house == nil then return end
    if Prefs.get("mapBox") then
        -- The box's corners, in tiles from its south-west corner. +1 so the box
        -- covers the last row and column of tiles too.
        local w = house.maxX - house.minX + 1
        local l = house.maxZ - house.minZ + 1
        if call("AddPolygon", {
            name = BOX_NAME, coordGrid = tile(house.minX, house.minZ),
            polygon = { 0, 0, w, 0, w, l, 0, l },
            drawOnWorldMap = true, drawOnMiniMap = true,
            fillRGBA = BOX_FILL, outlineRGBA = BOX_OUTLINE,
        }) then added[BOX_NAME] = "Polygon" end
    end
    if Prefs.get("hintArrow") and not near then   -- hidden while you're at the house
        -- Over the middle of the house; the arrow's position is in fine units
        local f = tile((house.minX + house.maxX) // 2, (house.minZ + house.maxZ) // 2):ToCoordFine(true)
        if call("AddArrow", {
            name = ARROW_NAME, arrowID = 0,   -- 0 = the yellow arrow
            coordFine = CoordFine.new(f.level, f.x, ARROW_HEIGHT, f.z),
        }) then added[ARROW_NAME] = "Arrow" end
    end
end

-- Called by main.lua whenever the contract changes (nil = no contract)
function Hints.setHouse(h)
    if h == house then return end
    house = h
    dirty = true
end

-- Redo the hints on the tick after anything changes (from the plugin's one
-- Logic handler, as Quest Helper does)
Util.onTick(function()
    -- Every half second: if you've come within NEAR_TILES of the house, or left
    -- it, redo the hints so the arrow hides or comes back
    checkTick = (checkTick + 1) % CHECK_TICKS
    if checkTick == 0 and house ~= nil then
        local player = Player.GetEntity()
        local nowNear = player ~= nil and Util.distanceToBox(house, player.coordGrid) <= NEAR_TILES
        if nowNear ~= near then
            near = nowNear
            dirty = true
        end
    end

    if not dirty then return end
    dirty = false
    removeAll()
    addAll()
end)

Prefs.onChange(function(key)
    if key == "mapBox" or key == "hintArrow" then dirty = true end
end)

-- When the game reloads the world it can drop hints, so add them again
-- (Quest Helper does the same on these events)
for _, name in ipairs({ "WorldCreated", "WorldUpdated", "RegionCreated", "RegionUpdated" }) do
    local event = Event[name]
    if event ~= nil then event.Subscribe("contractorHints", function() dirty = true end) end
end

return Hints

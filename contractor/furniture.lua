-- =============================================================================
-- furniture.lua  --  What each furniture spot is, and what it costs.
--
-- A spot variable is named CON_CONTRACTS_<HOUSE>_<FLOOR>_<TYPE>[_<number>], e.g.
-- CON_CONTRACTS_VARROCK_SHOPKEEPER_UPSTAIRS_WALL_SHELF_5. We turn <TYPE> into the
-- item name the contract scroll shows, then look up its cost.
-- =============================================================================

local HOUSES = require("houses")

local Furniture = {}

-- ---- Costs (from the wiki) ----------------------------------------------------
-- planks, nails, and any extra items. Extras are { count, singular, plural }.
-- These are the most you need: traits like Proficient Construction can save some.
local CANDLE = { "white candle", "white candles" }
local CLOTH  = { "bolt of cloth", "bolts of cloth" }
local STEEL  = { "steel bar", "steel bars" }
local BAR    = { "metal bar (match your plank)", "metal bars (match your plank)" }

local COSTS = {
    ["Altar"]       = { planks = 10, nails = 4, extras = { { 2, CANDLE }, { 1, CLOTH } } },
    ["Bed (large)"] = { planks = 10, nails = 4, extras = { { 2, CLOTH } } },
    ["Bed (small)"] = { planks = 8,  nails = 2, extras = { { 1, CLOTH } } },
    ["Bench"]       = { planks = 5,  nails = 4 },
    ["Bookcase"]    = { planks = 8,  nails = 4 },
    ["Chair"]       = { planks = 5,  nails = 4 },
    ["Chest"]       = { planks = 4,  nails = 2 },
    ["Counter"]     = { planks = 6,  nails = 4 },
    ["Desk"]        = { planks = 8,  nails = 2 },
    ["Drawers"]     = { planks = 4,  nails = 2 },
    ["Ladder"]      = { planks = 5,  nails = 4 },
    ["Lighting"]    = { planks = 2,  nails = 4, extras = { { 1, CANDLE } } },
    ["Organ"]       = { planks = 12, nails = 4, extras = { { 4, STEEL } } },
    ["Pew"]         = { planks = 5,  nails = 4 },
    ["Portrait"]    = { planks = 2,  nails = 2 },
    ["Shelf"]       = { planks = 4,  nails = 2 },
    ["Shelves"]     = { planks = 6,  nails = 4 },
    ["Sink"]        = { planks = 4,  nails = 4, extras = { { 2, STEEL } } },
    ["Stand"]       = { planks = 3,  nails = 4, extras = { { 1, CANDLE } } },
    ["Stool"]       = { planks = 4,  nails = 4 },
    -- Stove bars: iron with planks, steel with oak, mithril with teak,
    -- adamant with mahogany, rune with eternal
    ["Stove"]       = { planks = 2,  nails = 4, extras = { { 2, BAR } } },
    ["Table"]       = { planks = 6,  nails = 4 },
    ["Votary"]      = { planks = 3,  nails = 4, extras = { { 1, CANDLE } } },
    ["Wardrobe"]    = { planks = 8,  nails = 4 },
    ["Wheel"]       = { planks = 2,  nails = 2 },
}

-- ---- Spot type -> scroll item -------------------------------------------------
-- Checked in game: TABLE, SHELVES, WALL_SHELF, WALL_LAMP, PICTURE, BOOKCASE,
-- DRAWERS. The rest are matched against the wiki's list for each house.
-- Plain BED depends on the house (houses.lua "bed").
local TYPES = {
    TABLE = "Table", LARGE_TABLE = "Table", ROUND_TABLE = "Table",
    SHELVES = "Shelves", SHELF = "Shelves", BOOKCASE_SHELVES = "Shelves", LARGE_SHELF = "Shelves",
    WALL_SHELF = "Shelf", WALL_SHELVES = "Shelf",
    WALL_LAMP = "Lighting", WALL_CANDLES = "Lighting", WALL_CANDLE = "Lighting",
    WALL_SCONCE = "Lighting",
    PICTURE = "Portrait", PORTRAIT = "Portrait",
    BOOKCASE = "Bookcase", BOOKCASE_LARGE = "Bookcase", BOOKCASE_MEDIUM = "Bookcase",
    BOOKCASE_SMALL = "Bookcase",
    DRAWERS = "Drawers",
    DOUBLE_BED = "Bed (large)", SINGLE_BED = "Bed (small)",
    LECTURN = "Stand", VOTARY = "Votary", WALL_LADDER = "Ladder", STEERING_WHEEL = "Wheel",
    CHAIR = "Chair", CHAIRS = "Chair", WALL_CHAIR = "Chair", STOOL = "Stool", BENCH = "Bench",
    DESK = "Desk", STUDY_DESK = "Desk",
    PEW = "Pew", ORGAN = "Organ", ALTAR = "Altar", SINK = "Sink", STOVE = "Stove",
    CHEST = "Chest", WARDROBE = "Wardrobe",
}

-- Floor name shown in the contract window, and the game level (0 = ground)
local FLOORS = {
    DOWNSTAIRS = { label = "1st floor", level = 0 },
    UPSTAIRS   = { label = "2nd floor", level = 1 },
    OUTSIDE    = { label = "Outside",   level = 0 },
}
Furniture.FLOOR_ORDER = { "1st floor", "2nd floor", "Outside" }

-- The game misspells one spot: CON_CONRACTS_DRAYNOR_WOM_OUTSIDE_BENCH (no "T").
-- Read it as if it were spelled correctly. Lookups in the game still use the
-- real (misspelled) name, because the bench object has the same typo.
local function normalise(spotName)
    return (spotName:gsub("^CON_CONRACTS_", "CON_CONTRACTS_"))
end

-- Finds which house a spot variable belongs to, from its name.
function Furniture.houseFor(spotName)
    spotName = normalise(spotName)
    for id, house in pairs(HOUSES) do
        if spotName:sub(1, #house.prefix + 15) == "CON_CONTRACTS_" .. house.prefix .. "_" then
            return house, id
        end
    end
    return nil, nil
end

-- Turns a spot variable name into
--   { floor = "2nd floor", level = 1, item = "Shelf", known = true }.
-- Spots not on the wiki get a readable name and known = false.
function Furniture.describe(spotName, house)
    spotName = normalise(spotName)
    -- e.g. "UPSTAIRS_WALL_SHELF_5" -> floor "UPSTAIRS", type "WALL_SHELF"
    local rest = spotName:sub(#("CON_CONTRACTS_" .. house.prefix .. "_") + 1)
    local floorKey, spotType = rest:match("^(%u+)_(.+)$")
    spotType = (spotType or rest):gsub("_%d+$", "")

    local item = house.overrides and house.overrides[(floorKey or "") .. "_" .. spotType]
    if item == nil and spotType == "BED" then item = house.bed end
    if item == nil then item = TYPES[spotType] end

    local known = item ~= nil and COSTS[item] ~= nil
    if item == nil then
        -- Unknown: "ROUND_THING" -> "Round thing"
        item = spotType:lower():gsub("_", " "):gsub("^%l", string.upper)
    end
    local floor = FLOORS[floorKey] or { label = "Unknown floor", level = 0 }
    return { floor = floor.label, level = floor.level, item = item, known = known }
end

-- Adds up planks, nails and extras for a list of described spots.
-- Returns planks, nails, a list of extra-item text, and how many had no cost.
function Furniture.totals(spots)
    local planks, nails, unknown = 0, 0, 0
    local extraCounts, extraOrder = {}, {}
    for _, spot in ipairs(spots) do
        local cost = COSTS[spot.item]
        if cost == nil then
            unknown = unknown + 1
        else
            planks = planks + cost.planks
            nails = nails + cost.nails
            for _, extra in ipairs(cost.extras or {}) do
                local names = extra[2]
                if extraCounts[names] == nil then
                    extraCounts[names] = 0
                    extraOrder[#extraOrder + 1] = names
                end
                extraCounts[names] = extraCounts[names] + extra[1]
            end
        end
    end
    local extras = {}
    for _, names in ipairs(extraOrder) do
        local count = extraCounts[names]
        extras[#extras + 1] = count .. " " .. (count == 1 and names[1] or names[2])
    end
    return planks, nails, extras, unknown
end

return Furniture

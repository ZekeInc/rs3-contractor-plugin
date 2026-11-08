-- =============================================================================
-- tracker.lua  --  Reads the current contract from the game's variables.
--
-- Tracker.read() returns:
--   id      -- CON_CONTRACTS_CURRENT_ID (0 = no contract)
--   house   -- the house from houses.lua, or nil
--   spots   -- furniture still to build, each:
--              { name = <spot variable>, floor = "2nd floor", level = 1,
--                item = "Shelf", known = true, house = <house> }
-- Tracker.watchedIDs -- IDs of the variables that change when the contract does.
-- These variables can be read from anywhere in the world.
-- =============================================================================

local SPOTS = require("spots")
local HOUSES = require("houses")
local Furniture = require("furniture")
local Util = require("util")

local Tracker = {}

-- ---- Worked out once, at load -------------------------------------------------
-- Each spot is one bit of a "furniture" variable. Grouping spots by variable
-- means an update reads 7 variables instead of 209. Everything about a spot that
-- never changes (house, floor, item) is worked out here, once.
local groups = {}   -- { { var = <base variable>, spots = { { spot, mask }, ... } }, ... }
local direct = {}   -- spots without a known variable and bit: read one at a time

do
    local byBase = {}
    for _, name in ipairs(SPOTS) do
        local house, houseID = Furniture.houseFor(name)
        local v = var.VarPlayer[name]
        if house ~= nil and v ~= nil then
            local spot = Furniture.describe(name, house)
            spot.name, spot.house, spot.houseID = name, house, houseID
            local base, mask = v.baseVar, v.varBitMask
            if base ~= nil and mask ~= nil and mask ~= 0 then
                local group = byBase[base.id]
                if group == nil then
                    group = { var = base, spots = {} }
                    byBase[base.id] = group
                    groups[#groups + 1] = group
                end
                group.spots[#group.spots + 1] = { spot = spot, mask = mask }
            else
                direct[#direct + 1] = spot
            end
        end
    end
end

-- The contract ID and the furniture variables: only changes to these matter.
-- (The build progress counter also changes during a build, but doesn't matter.)
local CURRENT_ID = var.VarPlayer.CON_CONTRACTS_CURRENT_ID
Tracker.watchedIDs = { [CURRENT_ID.baseVar and CURRENT_ID.baseVar.id or CURRENT_ID.id] = true }
for _, group in ipairs(groups) do Tracker.watchedIDs[group.var.id] = true end

local warnedAbout = {}   -- contract IDs we've already printed a warning for

-- ---- Reading the contract ---------------------------------------------------------
function Tracker.read()
    local id = CURRENT_ID.value or 0
    local result = { id = id, house = nil, spots = {} }
    if id == 0 then return result end

    local function add(spot) result.spots[#result.spots + 1] = spot end
    for _, group in ipairs(groups) do
        local value = math.tointeger(group.var.value) or 0
        if value ~= 0 then
            for _, entry in ipairs(group.spots) do
                if (value & entry.mask) ~= 0 then add(entry.spot) end   -- bit set = still needed
            end
        end
    end
    for _, spot in ipairs(direct) do
        local v = var.VarPlayer[spot.name]
        if v ~= nil and v.value == 1 then add(spot) end
    end

    local first = result.spots[1]
    if first == nil then
        -- Nothing left to build: fall back to the contract ID's house
        result.house = HOUSES[id]
    else
        result.house = first.house
        if first.houseID ~= id and not warnedAbout[id] then
            -- houses.lua has this ID wrong; worth knowing, so the order can be fixed
            warnedAbout[id] = true
            Util.log("Note: contract ID " .. id .. " is " .. first.house.prefix
                     .. ", not house " .. tostring(first.houseID) .. " in houses.lua")
        end
    end
    return result
end

return Tracker

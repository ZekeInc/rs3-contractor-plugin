-- =============================================================================
-- Contractor  --  a helper for RuneScape Construction Contracts.
--
-- When you take a contract it shows:
--   - a contract window: who it's for, directions, what's left to build per
--     floor, and the planks, nails and extras to bring
--   - the house on the game's world map and minimap, and a hint arrow over it
--   - 3D markers on each spot still to build, and on the stairs you need
-- Everything updates as you build, and is configured from the Plugins menu tab.
--
-- How it works: the contract is stored in game variables (see tracker.lua), so
-- it can be read from anywhere. Files:
--   tracker.lua    reads the contract        furniture.lua  item names and costs
--   houses.lua     the 11 houses             spots.lua      all spot variable names
--   infowindow.lua contract window           hints.lua      map box + hint arrow
--   markers.lua    3D markers                menu.lua       Plugins menu tab
--   frame.lua      window frame              scroller.lua   scroll bar
--   prefs.lua      preferences               util.lua       shared helpers
-- Debug tools are a separate dev-only plugin: contractor-debug/.
-- =============================================================================

local Util = require("util")
local Prefs = require("prefs")
local Tracker = require("tracker")
local infoWindow = require("infowindow")
local markers = require("markers")
local hints = require("hints")

infoWindow.create()
require("menu").setup(infoWindow)

-- ---- Keeping everything up to date --------------------------------------------
-- The contract window opens when you get a new contract (unless turned off in
-- Preferences), and says so when it completes. With no contract at load, it
-- starts hidden.
local lastID = nil   -- contract ID at the previous update (nil = not checked yet)

local function update()
    local c = Tracker.read()
    local justCompleted = lastID ~= nil and lastID ~= 0 and c.id == 0
    infoWindow.setContract(c, justCompleted)
    hints.setHouse(c.house)
    markers.setContract(c)

    if lastID == nil then
        if c.id == 0 then infoWindow.hide() end
    elseif c.id ~= 0 and c.id ~= lastID then
        if Prefs.get("autoOpen") then infoWindow.show() end
    end
    lastID = c.id
end
update()

-- Several contract variables change at once, so the first change schedules one
-- update for the next tick, and the rest are ignored until it has run.
local pending = false
Event.VarTransmit.Subscribe("contractorUpdate", function(e)
    if pending or e.var == nil or not Tracker.watchedIDs[e.var.id] then return end
    pending = true
    Util.later(function()
        pending = false
        update()
    end)
end)

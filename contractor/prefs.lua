-- =============================================================================
-- prefs.lua  --  The player's preferences, saved between sessions.
--
--   Prefs.get("tiles")          -> true/false
--   Prefs.set("tiles", false)   -- saves, then tells everything listening
--   Prefs.onChange(function(key, value) ... end)
--
-- The menu's Preferences page shows Prefs.OPTIONS in this order.
-- =============================================================================

local Prefs = {}

local SAVE_KEY = "preferences"

-- key: name used in code and in the save. default: value until changed.
Prefs.OPTIONS = {
    { key = "tiles",        label = "Highlight furniture tiles",               default = true },
    { key = "boxes",        label = "Box around furniture",                     default = true },
    { key = "stairs",       label = "Highlight stairs",                         default = true },
    { key = "throughWalls", label = "Show markers through walls",               default = true },
    { key = "autoOpen",     label = "Open the contract window on a new contract", default = true },
    { key = "mapBox",       label = "Show the house on the world map and minimap", default = true },
    { key = "hintArrow",    label = "Hint arrow over the house",                default = true },
}

local values = {}
local listeners = {}

-- Load saved values. A saved false must stay false, so check for nil.
local saved = PersistentDB:GetStructuredData(SAVE_KEY) or {}
for _, option in ipairs(Prefs.OPTIONS) do
    if saved[option.key] ~= nil then
        values[option.key] = saved[option.key]
    else
        values[option.key] = option.default
    end
end

function Prefs.get(key)
    return values[key]
end

function Prefs.set(key, value)
    if values[key] == value then return end
    values[key] = value
    PersistentDB:SetStructuredData(SAVE_KEY, values)
    for _, listener in ipairs(listeners) do listener(key, value) end
end

function Prefs.onChange(listener)
    listeners[#listeners + 1] = listener
end

return Prefs

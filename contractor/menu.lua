-- =============================================================================
-- menu.lua  --  Contractor's tab in the game's Plugins window.
--
-- Needs "hasRibbonIcon": true in plugin.json. When you click the plugin's icon,
-- the game gives us an empty panel (ContentLayerReady) and we fill it in the
-- game's default style. It has two pages: the main buttons, and Preferences.
-- =============================================================================

local Util = require("util")
local Window = require("frame")
local Prefs = require("prefs")

local Menu = {}

local ROW_HEIGHT = 28
local ROW_GAP    = 6
local MARGIN     = 10

local panel = nil   -- the panel the game gave us (cleared each time it opens)
local pages = {}

-- Puts a component on a full-width row (row 1 at the top)
local function placeRow(component, row)
    component:SetSize(-MARGIN * 2, ROW_HEIGHT, 1.0, 0.0)
    component:SetPos(MARGIN, MARGIN + (row - 1) * (ROW_HEIGHT + ROW_GAP))
    return component
end

-- Switching page deletes the button that was pressed, so it waits for the next
-- tick rather than deleting it while it's still handling the press.
local function showPage(name)
    Util.later(function()
        if panel == nil then return end
        panel:DeleteAll()
        pages[name]()
    end)
end

function Menu.setup(infoWindow)
    function pages.main()
        placeRow(Util.button(panel, "Show contract", infoWindow.show), 1)
        placeRow(Util.button(panel, "Hide contract", infoWindow.hide), 2)
        placeRow(Util.button(panel, "Reset position", Window.resetAll), 3)
        placeRow(Util.button(panel, "Preferences", function() showPage("prefs") end), 4)
    end

    function pages.prefs()
        placeRow(Util.button(panel, "Back", function() showPage("main") end), 1)
        placeRow(Util.text(panel, "Preferences", Util.HEADING_COLOUR), 2)

        -- One checkbox per option, in the game's default style
        for i, option in ipairs(Prefs.OPTIONS) do
            local check = placeRow(ui.Check.new(panel), i + 2)
            check.stylesheetID = id.StyleSheet.CHECKBOX_DEFAULT
            check.label = option.label
            check.value = Prefs.get(option.key)
            -- What the press event passes isn't reliable, so flip our own saved
            -- value and make the checkbox match it
            check:Subscribe(ui.Hook.ONBUTTONPRESSED, function(c)
                local newValue = not Prefs.get(option.key)
                Prefs.set(option.key, newValue)
                c.value = newValue
            end)
        end
    end

    -- The game clears the panel each time it's opened, so start on the main page
    Event.ContentLayerReady.Subscribe("contractorMenu", function(e)
        panel = e.component
        pages.main()
    end)
end

return Menu

-- =============================================================================
-- util.lua  --  Small helpers shared by the other files.
-- =============================================================================

local Util = {}

-- ---- Look ---------------------------------------------------------------------
-- Colours are (red, green, blue, opacity), each from 0.0 to 1.0
Util.HEADING_COLOUR = Vector4.new(1.0, 0.8, 0.3, 1.0)    -- gold, like game headings
Util.TEXT_COLOUR    = Vector4.new(1.0, 1.0, 1.0, 1.0)
Util.INVISIBLE      = Vector4.new(0.0, 0.0, 0.0, 0.01)   -- for areas that catch the mouse
Util.FONT           = id.Font.MUSEO_SANS_15PT_REGULAR

-- ---- Numbers --------------------------------------------------------------------
-- Keeps a number between a lowest and highest value
function Util.clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

-- How many tiles a tile is from a box with minX..maxX, minZ..maxZ (0 = inside it):
-- the larger of the east-west and north-south gaps, the way the game counts distance
function Util.distanceToBox(box, c)
    local dx = math.max(box.minX - c.x, 0, c.x - box.maxX)
    local dz = math.max(box.minZ - c.z, 0, c.z - box.maxZ)
    return math.max(dx, dz)
end

-- ---- Console --------------------------------------------------------------------
-- Prints with a [Contractor] tag. Anything can be passed (nil, numbers, configs).
function Util.log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    print("[Contractor] " .. table.concat(parts, " "))
end

-- ---- UI components ----------------------------------------------------------------
-- Text needs a font or it's invisible
function Util.text(parent, content, colour)
    local t = ui.Text.new(parent)
    t.font = Util.FONT
    t.content = content or ""
    if colour ~= nil then t.colour = colour end
    return t
end

-- A button in the game's default style
function Util.button(parent, label, onPress)
    local b = ui.Button.new(parent)
    b.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
    b.label = label
    b:Subscribe(ui.Hook.ONBUTTONPRESSED, onPress)
    return b
end

-- A filled rectangle. catchMouse = true lets it receive clicks, drags and the
-- wheel (without it, rectangles ignore the mouse).
function Util.rect(parent, colour, catchMouse)
    local r = ui.Rectangle.new(parent)
    r.fill = true
    r.colour = colour
    if catchMouse then r.clickthrough = false end
    return r
end

-- An invisible rectangle that catches the mouse (for drag areas)
function Util.mouseArea(parent)
    return Util.rect(parent, Util.INVISIBLE, true)
end

-- ---- Ticks ------------------------------------------------------------------------
-- One logic-tick handler (50 a second) for the whole plugin:
--   Util.onTick(fn)  -- fn(event) runs every tick
--   Util.later(fn)   -- fn() runs once, on the next tick
local tickHandlers, queue = {}, {}

function Util.onTick(fn) tickHandlers[#tickHandlers + 1] = fn end
function Util.later(fn)  queue[#queue + 1] = fn end

Event.Logic.Subscribe("contractorTick", function(e)
    for i = 1, #tickHandlers do tickHandlers[i](e) end
    if #queue > 0 then
        local run = queue
        queue = {}
        for i = 1, #run do run[i]() end
    end
end)

return Util

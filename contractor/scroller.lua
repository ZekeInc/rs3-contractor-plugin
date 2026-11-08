-- =============================================================================
-- scroller.lua  --  A scrollable area with its own scroll bar.
--
-- The API has no ready-made scroll bar for plain windows, so this builds one:
--   - put your components in scroller.inner (positioned from its top-left)
--   - call scroller:update(x, y, width, height, contentHeight) after any change
--   - mouse wheel scrolls; drag the handle; click the track to move a page
-- The bar only appears when the content is taller than the area.
-- =============================================================================

local Util = require("util")
local Window = require("frame")   -- for its drag handling

local Scroller = {}
Scroller.__index = Scroller

-- ---- Settings -----------------------------------------------------------------
Scroller.BAR_WIDTH = 10   -- width of the scroll bar
Scroller.BAR_GAP   = 4    -- gap between the content and the bar
Scroller.BAR_SPACE = Scroller.BAR_WIDTH + Scroller.BAR_GAP   -- room the bar takes up
local MIN_HANDLE   = 20   -- the handle never gets shorter than this
local WHEEL_STEP   = 60   -- pixels per mouse wheel notch (3 lines of text)

-- Dark track, light brown handle
local TRACK_COLOUR  = Vector4.new(0.10, 0.08, 0.06, 0.8)
local HANDLE_COLOUR = Vector4.new(0.55, 0.45, 0.30, 1.0)

function Scroller.new(parent)
    local self = setmetatable({ x = 0, y = 0, w = 0, h = 0, contentH = 0, offset = 0 }, Scroller)

    -- The visible area (a layer cuts off anything outside it). Everything
    -- scrollable goes in .inner, which we move up as you scroll down.
    self.view = ui.Layer.new(parent)
    self.view.clickthrough = false   -- needed to receive the mouse wheel
    self.inner = ui.Layer.new(self.view)

    -- Track: click above or below the handle to move a page
    self.track = Util.rect(parent, TRACK_COLOUR, true)
    self.track:Subscribe(ui.Hook.ONCLICK, function() self:pageClick() end)

    -- Handle: drag it to scroll
    self.handle = Util.rect(parent, HANDLE_COLOUR, true)
    Window.makeDraggable(self.handle, {
        start = function() return self.offset end,
        move  = function(start, _, dy) self:scrollTo(start + dy * self:contentPerHandlePixel()) end,
    })

    -- Mouse wheel over the content, track or handle (wheel up = negative)
    local function onWheel(_, delta)
        if delta ~= 0 then self:scrollTo(self.offset + (delta > 0 and WHEEL_STEP or -WHEEL_STEP)) end
    end
    for _, c in ipairs({ self.view, self.track, self.handle }) do
        c:Subscribe(ui.Hook.ONSCROLLWHEEL, onWheel)
    end
    return self
end

function Scroller:maxOffset()    return math.max(0, self.contentH - self.h) end
function Scroller:barShown()     return self.contentH > self.h end
-- Width available for content (narrower when the bar is showing)
function Scroller:viewWidth()    return self.w - (self:barShown() and Scroller.BAR_SPACE or 0) end

function Scroller:handleHeight()
    if self.contentH <= 0 then return self.h end
    return math.max(MIN_HANDLE, self.h * self.h // self.contentH)
end

-- Content pixels moved per pixel of handle movement
function Scroller:contentPerHandlePixel()
    local travel = self.h - self:handleHeight()
    return travel > 0 and self:maxOffset() / travel or 0
end

-- Sets the area and content height, then redraws, keeping the scroll position
-- if it's still in range.
function Scroller:update(x, y, width, height, contentHeight)
    self.x, self.y, self.w, self.h, self.contentH = x, y, width, height, contentHeight
    self:scrollTo(self.offset)
end

-- Scrolls to an offset (kept in range) and places everything.
function Scroller:scrollTo(offset)
    local maxOffset = self:maxOffset()
    self.offset = math.floor(Util.clamp(offset, 0, maxOffset))
    local viewW = self:viewWidth()
    self.view:SetSize(viewW, self.h)
    self.view:SetPos(self.x, self.y)
    self.inner:SetSize(viewW, math.max(self.contentH, self.h))
    self.inner:SetPos(0, -self.offset)

    local shown = self:barShown()
    self.track.hidden = not shown
    self.handle.hidden = not shown
    if shown then
        local barX = self.x + self.w - Scroller.BAR_WIDTH
        local handleH = self:handleHeight()
        self.track:SetSize(Scroller.BAR_WIDTH, self.h)
        self.track:SetPos(barX, self.y)
        self.handle:SetSize(Scroller.BAR_WIDTH, handleH)
        self.handle:SetPos(barX, self.y + (self.h - handleH) * self.offset // math.max(1, maxOffset))
    end
end

-- Clicking the track moves a page towards where you clicked
function Scroller:pageClick()
    local mouse = Mouse.GetPosition()
    if mouse == nil then return end
    self:scrollTo(self.offset + (mouse.y < self.handle.xyGlobal.y and -self.h or self.h))
end

return Scroller

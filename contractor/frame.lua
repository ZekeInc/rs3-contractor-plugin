-- =============================================================================
-- frame.lua  --  A shared window frame: title bar, close button, and moving and
-- resizing by dragging. The contract window is built on this.
--
--   local Window = require("frame")
--   local win = Window.new({
--       key = "myWindow",                  -- name used to save position/size
--       title = "My window",
--       x = 20, y = 20, w = 300, h = 200,  -- default position and size
--       minW = 200, minH = 150,            -- smallest it can be resized to
--       onLayout = function(contentW, contentH) ... end,  -- after every resize
--   })
--   -- Put your own components in win.content (a layer below the title bar).
--
--   Move:   drag the title bar
--   Resize: drag any edge or corner
--   Close:  the X button (hides it; win:show() brings it back)
-- =============================================================================

local Util = require("util")

local Window = {}
Window.__index = Window

-- ---- Frame settings -----------------------------------------------------------
local PADDING     = 10    -- gap between the window edge and the content
local TITLE_SPACE = 36    -- title bar height (also the area you drag to move)
local CLOSE_SIZE  = 24    -- the X button
local EDGE        = 6     -- thickness of the invisible edge resize handles
local CORNER      = 12    -- size of the invisible corner resize handles
local RELEASE_TICKS = 5   -- no ONHOLD for this many ticks = mouse button released

-- Which sides of the window each resize handle moves
local SIDES = {
    { left = true },  { right = true },  { top = true },  { bottom = true },
    { top = true, left = true },     { top = true, right = true },
    { bottom = true, left = true },  { bottom = true, right = true },
}

-- ---- Shared state -------------------------------------------------------------
local parent = nil         -- the plugin UI layer over the game window
local windows = {}         -- every window created, for "Reset positions"
local drag = nil           -- the drag in progress, if any (only one at a time)
local currentTick = 0      -- logic tick count, used to notice when holding stops

local function getParent()
    if parent == nil then
        parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
    end
    return parent
end

-- The parent's size, or nil, nil while it isn't known yet (very early on)
local function parentSize()
    local p = getParent()
    if p.width > 0 and p.height > 0 then return p.width, p.height end
    return nil, nil
end

-- ---- Dragging -----------------------------------------------------------------
-- A drag "handler" is a table of up to three functions:
--   start()                 -> returns whatever needs remembering (a "state")
--   move(state, dx, dy)     -> called every tick with how far the mouse has moved
--   finish(state)           -> called when the drag ends (optional)

local function startDrag(handler)
    local mouse = Mouse.GetPosition()
    if mouse == nil then return end   -- mouse outside the game window
    drag = { handler = handler, mouseX = mouse.x, mouseY = mouse.y, state = handler.start() }
end

local function endDrag()
    if drag == nil then return end
    local finished = drag
    drag = nil
    if finished.handler.finish then finished.handler.finish(finished.state) end
end

Util.onTick(function(e)
    currentTick = e.logicTick
    if drag == nil then return end
    if drag.lastHoldTick ~= nil and currentTick - drag.lastHoldTick > RELEASE_TICKS then
        endDrag()
        return
    end
    local mouse = Mouse.GetPosition()
    if mouse ~= nil then
        drag.handler.move(drag.state, mouse.x - drag.mouseX, mouse.y - drag.mouseY)
    end
end)

-- Makes a component catch the mouse and run a drag handler when dragged.
-- Also used for the scroll bar handle.
function Window.makeDraggable(component, handler)
    pcall(function()
        component.dragConfig.renderBehaviour = ui.DragRenderBehaviour.INVISIBLE
        component.dragConfig.dragDelayTicks = 0
        component.dragConfig.deadZone = 2
    end)
    component.clickthrough = false   -- without this, it ignores the mouse
    component.enabled = true

    component:Subscribe(ui.Hook.ONDRAG, function() startDrag(handler) end)
    component:Subscribe(ui.Hook.ONDRAGCOMPLETE, endDrag)
    -- Fallback: ONHOLD fires again and again while the mouse button is held.
    -- Start on the first one; the tick handler ends the drag when they stop.
    component:Subscribe(ui.Hook.ONHOLD, function()
        if drag == nil then startDrag(handler) end
        if drag ~= nil and drag.handler == handler then drag.lastHoldTick = currentTick end
    end)
end

-- ---- Creating a window --------------------------------------------------------
function Window.new(opts)
    local self = setmetatable({ opts = opts }, Window)

    -- Load the saved position and size, or use the defaults
    local saved = PersistentDB:GetStructuredData(opts.key) or {}
    self.x = saved.x or opts.x
    self.y = saved.y or opts.y
    self.w = math.max(opts.minW, saved.w or opts.w)
    self.h = math.max(opts.minH, saved.h or opts.h)

    -- A plain layer holds everything. The background box sits inside it, so the
    -- box's inner border can't cut off the edge handles.
    self.root = ui.Layer.new(getParent())
    self.root.clickthrough = false   -- clicks on the window stay in the window

    -- Background, in the game's default style (without a stylesheet it's invisible)
    self.background = ui.GroupBox.new(self.root)
    self.background.stylesheetID = id.StyleSheet.DEFAULT
    self.background:SetHeaderLayout(0, 0, 0, 0, 0)
    self.background.clickthrough = false

    self.title = Util.text(self.root, opts.title)

    -- Invisible bar over the title: drag to move the window
    self.dragBar = Util.mouseArea(self.root)
    Window.makeDraggable(self.dragBar, {
        start  = function() return { x = self.x, y = self.y } end,
        move   = function(s, dx, dy) self:moveTo(s.x + dx, s.y + dy) end,
        finish = function() self:save() end,
    })

    -- Where each window puts its own components
    self.content = ui.Layer.new(self.root)
    self.content.clickthrough = false

    self.closeButton = Util.button(self.root, "X", function() self:hide() end)

    -- Invisible resize handles on every edge and corner. Created last so they
    -- sit on top and catch the mouse first.
    self.handles = {}
    for _, side in ipairs(SIDES) do
        local c = Util.mouseArea(self.root)
        self.handles[#self.handles + 1] = { side = side, component = c }
        Window.makeDraggable(c, {
            start  = function() return { x = self.x, y = self.y, w = self.w, h = self.h } end,
            move   = function(s, dx, dy) self:resizeFrom(side, s, dx, dy) end,
            finish = function() self:save() end,
        })
    end

    self:layout()
    self:moveTo(self.x, self.y)
    windows[#windows + 1] = self
    return self
end

-- ---- Window methods -----------------------------------------------------------
function Window:contentWidth()  return self.w - PADDING * 2 end
function Window:contentHeight() return self.h - TITLE_SPACE - PADDING end

-- Places one resize handle along its edge or in its corner.
function Window:placeHandle(handle)
    local s, c = handle.side, handle.component
    local w, h = self.w, self.h
    if (s.left or s.right) and (s.top or s.bottom) then
        c:SetSize(CORNER, CORNER)
        c:SetPos(s.left and 0 or (w - CORNER), s.top and 0 or (h - CORNER))
    elseif s.left or s.right then
        c:SetSize(EDGE, h - CORNER * 2)
        c:SetPos(s.left and 0 or (w - EDGE), CORNER)
    else
        c:SetSize(w - CORNER * 2, EDGE)
        c:SetPos(CORNER, s.top and 0 or (h - EDGE))
    end
end

-- Positions and sizes the frame for the current size, then lets the window
-- lay out its own contents.
function Window:layout()
    local w, h = self.w, self.h
    self.root:SetSize(w, h)
    self.background:SetSize(w, h)
    self.background:SetPos(0, 0)

    self.title:SetSize(w - PADDING * 2 - CLOSE_SIZE - 4, TITLE_SPACE)
    self.title:SetPos(PADDING, 0)
    self.dragBar:SetSize(w - PADDING - CLOSE_SIZE - 4, TITLE_SPACE)
    self.dragBar:SetPos(0, 0)
    self.closeButton:SetSize(CLOSE_SIZE, CLOSE_SIZE)
    self.closeButton:SetPos(w - PADDING - CLOSE_SIZE, (TITLE_SPACE - CLOSE_SIZE) // 2)

    self.content:SetSize(self:contentWidth(), self:contentHeight())
    self.content:SetPos(PADDING, TITLE_SPACE)

    for _, handle in ipairs(self.handles) do self:placeHandle(handle) end
    if self.opts.onLayout then self.opts.onLayout(self:contentWidth(), self:contentHeight()) end
end

-- Moves the window, keeping it inside the game window.
function Window:moveTo(x, y)
    local pw, ph = parentSize()
    if pw ~= nil then
        x = Util.clamp(x, 0, math.max(0, pw - self.w))
        y = Util.clamp(y, 0, math.max(0, ph - self.h))
    end
    self.x, self.y = math.floor(x), math.floor(y)
    self.root:SetPos(self.x, self.y)
end

-- Resizes from a dragged edge or corner; the opposite side stays still.
function Window:resizeFrom(side, s, dx, dy)
    local pw, ph = parentSize()
    local w = side.right and s.w + dx or side.left and s.w - dx or s.w
    local h = side.bottom and s.h + dy or side.top and s.h - dy or s.h
    self.w = math.floor(Util.clamp(w, self.opts.minW, pw or w))
    self.h = math.floor(Util.clamp(h, self.opts.minH, ph or h))
    self:layout()
    -- Move left or up when growing that way, so the opposite side stays put
    self:moveTo(side.left and (s.x + s.w - self.w) or s.x,
                side.top  and (s.y + s.h - self.h) or s.y)
end

function Window:save()
    PersistentDB:SetStructuredData(self.opts.key, { x = self.x, y = self.y, w = self.w, h = self.h })
end

function Window:setTitle(text) self.title.content = text end
function Window:show()         self.root.hidden = false end
function Window:hide()         self.root.hidden = true end

-- Puts every window back at its default position and size, and shows it.
function Window.resetAll()
    for _, win in ipairs(windows) do
        win.x, win.y, win.w, win.h = win.opts.x, win.opts.y, win.opts.w, win.opts.h
        win:layout()
        win:moveTo(win.x, win.y)
        win:save()
        win:show()
    end
end

return Window

-- =============================================================================
-- infowindow.lua  --  The contract window: who the contract is for, where they
-- are, what's left to build and what to bring. Updated whenever the contract
-- changes (see main.lua).
-- =============================================================================

local Util = require("util")
local Window = require("frame")
local Furniture = require("furniture")
local Scroller = require("scroller")

local InfoWindow = {}

local LINE_HEIGHT = 20
local CHAR_WIDTH  = 8     -- rough average character width, used to wrap lines

local win
local scroller            -- scrollable area holding the text
local textPool = {}       -- Text components, reused each time the window redraws
local paragraphs = {}     -- what to show: { text, heading }, before wrapping
local completed = false   -- true right after a contract is finished

-- Splits text into lines that fit the given width (an estimate: the API doesn't
-- tell us the real text width).
local function wrap(text, width, out)
    local maxChars = math.max(10, width // CHAR_WIDTH)
    local line = ""
    for word in text:gmatch("%S+") do
        if line == "" then
            line = word
        elseif #line + 1 + #word <= maxChars then
            line = line .. " " .. word
        else
            out[#out + 1] = line
            line = word
        end
    end
    out[#out + 1] = line   -- also keeps blank paragraphs as blank lines
end

-- "2nd floor: Bookcase x3, Drawers" for each floor with something left
local function buildList(spots, add)
    for _, floor in ipairs(Furniture.FLOOR_ORDER) do
        local counts, order = {}, {}
        for _, spot in ipairs(spots) do
            if spot.floor == floor then
                if counts[spot.item] == nil then
                    counts[spot.item] = 0
                    order[#order + 1] = spot.item
                end
                counts[spot.item] = counts[spot.item] + 1
            end
        end
        if #order > 0 then
            for i, item in ipairs(order) do
                if counts[item] > 1 then order[i] = item .. " x" .. counts[item] end
            end
            add(floor .. ": " .. table.concat(order, ", "))
        end
    end
end

-- Works out what to show for a contract. Only done when the contract changes;
-- resizing just re-wraps these.
local function buildParagraphs(c)
    local out = {}
    local function add(text, heading) out[#out + 1] = { text = text, heading = heading } end

    if c.id == 0 or c.house == nil then
        add(completed and "Contract complete." or "No contract.", true)
        add("Speak to an estate agent to get a new one.")
        return out
    end

    add(c.house.name .. " - " .. c.house.town, true)
    add(c.house.directions)
    add("")
    add("Still to build", true)
    if #c.spots == 0 then
        add("Everything is built.")
    else
        buildList(c.spots, add)
    end
    add("")
    add("Bring", true)
    if #c.spots == 0 then
        add("Nothing.")
    else
        local planks, nails, extras, unknown = Furniture.totals(c.spots)
        add("Up to " .. planks .. " planks, " .. nails .. " nails")
        for _, extra in ipairs(extras) do add(extra) end
        if unknown > 0 then add(unknown .. " item(s) have no known cost; ask the contractee.") end
    end
    return out
end

-- Wraps the paragraphs to a width; returns { text, heading } lines
local function wrapAll(width)
    local lines = {}
    for _, p in ipairs(paragraphs) do
        local first = #lines + 1
        local texts = {}
        wrap(p.text, width, texts)
        for i, t in ipairs(texts) do lines[first + i - 1] = { text = t, heading = p.heading } end
    end
    return lines
end

-- Redraws the text for the current size. Called on every resize and update.
local function redraw(contentW, contentH)
    if scroller == nil then return end
    -- Wrap to the full width first. If that's too tall, a scroll bar will
    -- appear, so wrap again to the narrower width beside it.
    local lines = wrapAll(contentW)
    if #lines * LINE_HEIGHT > contentH then lines = wrapAll(contentW - Scroller.BAR_SPACE) end
    scroller:update(0, 0, contentW, contentH, #lines * LINE_HEIGHT)

    local textW = scroller:viewWidth()
    for i, line in ipairs(lines) do
        local t = textPool[i]
        if t == nil then
            t = Util.text(scroller.inner)
            textPool[i] = t
        end
        t.content = line.text
        t.colour = line.heading and Util.HEADING_COLOUR or Util.TEXT_COLOUR
        t:SetSize(textW, LINE_HEIGHT)
        t:SetPos(0, (i - 1) * LINE_HEIGHT)
        t.hidden = false
    end
    -- Hide leftover lines from a longer, earlier version
    for i = #lines + 1, #textPool do textPool[i].hidden = true end
end

function InfoWindow.create()
    win = Window.new({
        key = "infoWindow", title = "Contract",
        x = 20, y = 20, w = 320, h = 260, minW = 200, minH = 120,
        onLayout = redraw,
    })
    scroller = Scroller.new(win.content)
end

-- c is the result of Tracker.read(). justCompleted shows "Contract complete."
function InfoWindow.setContract(c, justCompleted)
    if justCompleted then completed = true end
    if c.id ~= 0 then completed = false end
    paragraphs = buildParagraphs(c)
    redraw(win:contentWidth(), win:contentHeight())
end

function InfoWindow.show() win:show() end
function InfoWindow.hide() win:hide() end

return InfoWindow

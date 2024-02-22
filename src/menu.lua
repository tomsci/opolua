--[[

Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]

_ENV = module()

local kMenuFont = KFontArialNormal15
local kShortcutFont = KFontArialNormal11
local kChoiceUpArrow = "," -- in KFontEiksym15
local kChoiceDownArrow = "-" -- in KFontEiksym15

local DrawStyle = enum {
    normal = 0,
    highlighted = 1,
    dismissing = 2,
    unfocussedHighlighted = 3,
}

local Scrollbar = class {}

function Scrollbar:draw()
    local x, y, w, h = self.x, self.y, self.w, self.h
    local widgetHeight = self:widgetHeight()
    gAT(x, y)

    local barOffset = self:barOffset()
    local barAreaHeight = self:barAreaHeight()
    -- printf("x=%d y=%d widgetHeight=%d, barOffset=%d\n", x, y, widgetHeight, barOffset)
    if barOffset > 0 then
        gFILL(w, barOffset, KgModeClear)
        gMOVE(0, barOffset)
    end
    gFILL(w, widgetHeight, KgModeClear)
    gBUTTON("", KButtS5, w, widgetHeight, self.tracking and KButtS5SemiPressed or KButtS5Raised)
    if barOffset + widgetHeight < barAreaHeight then
        gAT(x, y + barOffset + widgetHeight)
        gFILL(w, barAreaHeight - (barOffset + widgetHeight), KgModeClear)
    end

    local kStripeGap = 5
    -- Make sure we don't draw any more strips than fill half the widgetHeight
    local numStripes = math.min(10, (widgetHeight // 2) // kStripeGap)
    local stripeWidth = w // 2
    gAT(x + (w // 4) + 1, y + barOffset + (widgetHeight // 2) - ((numStripes * kStripeGap) // 2))
    for i = 1, numStripes do
        white()
        gLINEBY(stripeWidth, 0)
        gMOVE(-stripeWidth, 1)
        black()
        gLINEBY(stripeWidth, 0)
        gMOVE(-stripeWidth, kStripeGap - 1)
    end

    -- Draw up and down arrows
    black()
    gFONT(KFontEiksym15)
    gAT(x, y + barAreaHeight)
    gBUTTON(kChoiceUpArrow, KButtS5, w, w, 0)
    gMOVE(0, w - 1)
    gBUTTON(kChoiceDownArrow, KButtS5, w, w, 0)
end

function Scrollbar:setContentOffset(offset)
    -- printf("setContentOffset(%d)\n", offset)
    self.contentOffset = math.min(math.max(offset, 0), self:maxContentOffset())
    self:draw()
end

function Scrollbar:handlePointerEvent(x, y, type)
    local widgetHeight = self:widgetHeight()
    local barOffset = self:barOffset()
    local barAreaHeight = self:barAreaHeight()
    local yoffset = y - self.y
    local deltaOffset = 0
    if self.tracking then
        if type == KEvPtrPenUp then
            self.tracking = nil
            self:draw()
            return
        else
            deltaOffset = y - self.tracking
            self.tracking = y
        end
    elseif yoffset < barOffset then
        -- Scroll up a page
        if type == KEvPtrPenDown then
            deltaOffset = -widgetHeight
        end
    elseif yoffset < barOffset + widgetHeight then
        -- Start dragging on the scroll widget
        if type == KEvPtrPenDown then
            self.tracking = y
        end
    elseif yoffset < barAreaHeight then
        -- Scroll down a page
        if type == KEvPtrPenDown then
            deltaOffset = widgetHeight
        end
    elseif yoffset < barAreaHeight + self.w then
        -- Up arrow
        if type == KEvPtrPenDown and self.observer then
            self.observer:scrollbarDidScroll(-1)
        end
    elseif yoffset < barAreaHeight + 2 * self.w then
        -- Down arrow
        if type == KEvPtrPenDown and self.observer then
            self.observer:scrollbarDidScroll(1)
        end
    end

    if deltaOffset ~= 0 then
        self:setContentOffset(self.contentOffset + deltaOffset)
        if self.observer then
            self.observer:scrollbarContentOffsetChanged(self)
        end
    end
end

function Scrollbar:maxContentOffset()
    -- Assuming we never want to be able to scroll to reveal beyond the content size
    return self.contentHeight - self:barAreaHeight() - (2 * self.w) + 2
end

function Scrollbar:barOffset()
    return math.floor(self:barAreaHeight() * (self.contentOffset / self.contentHeight))
end

-- The space the scrollbar can move in, total height minus the size of the buttons
function Scrollbar:barAreaHeight()
    return self.h - (self.w * 2)
end

function Scrollbar:widgetHeight()
    return math.floor((self:barAreaHeight() - 1) * (self.h / self.contentHeight))
end

function Scrollbar.newVertical(x, y, h, contentHeight)
    local w = 23
    local barAreaHeight = h - (w * 2)
    local scrollbar = Scrollbar {
        x = x,
        y = y,
        w = w,
        h = h,
        contentHeight = contentHeight,
        contentOffset = 0,
    }

    return scrollbar
end

local MenuPane = class {
    borderWidth = 5,
    textGap = 6,
    lineGap = 5, -- 2 pixels space each side of the horizontal line
    leftMargin = 15, -- This is part of the highlighted area
    rightMargin = 20, -- ditto
    textYPad = 3,
}

function MenuPane:drawItems()
    for i, item in ipairs(self.items) do
        if i >= self.firstVisibleItem and i < self.firstVisibleItem + self.numVisibleItems then
            self:drawItem(i, i == self.selected)
            if item.lineAfter then
                black()
                gAT(self.borderWidth, self:drawPosForContentPos(item.y) + self.lineHeight + (self.lineGap // 2))
                gLINEBY(self.contentWidth, 0)
            end
        end
    end
end

function MenuPane:drawItem(i, style)
        local item = self.items[i]
        local borderWidth, contentWidth, lineHeight = self.borderWidth, self.contentWidth, self.lineHeight
        local leftMargin, textGap, textYPad = self.leftMargin, self.textGap, self.textYPad
        assert(item, "Index out of range in drawItem! "..tostring(i))
        local y = self:drawPosForContentPos(item.y)
        gAT(borderWidth, y)
        if style == false then
            style = DrawStyle.normal
        elseif style == true then
            style = DrawStyle.highlighted
        end
        if style == DrawStyle.unfocussedHighlighted then
            darkGrey()
        else
            black()
        end
        local highlighted = style == DrawStyle.highlighted or style == DrawStyle.unfocussedHighlighted
        gFILL(contentWidth, lineHeight, highlighted and KgModeSet or KgModeClear)
        if style == DrawStyle.dismissing then
            gAT(borderWidth, y)
            gCOLOR(0, 0, 0)
            gBOX(contentWidth, lineHeight)
        end
        if item.key & KMenuDimmed > 0 then
            darkGrey()
        elseif highlighted then
            white()
        end
        if item.key & (KMenuSymbolOn|KMenuCheckBox) == (KMenuSymbolOn|KMenuCheckBox) then
            gAT(borderWidth, y + textYPad)
            gFONT(KFontEiksym15)
            runtime:drawCmd("text", { string = "." })
        end
        gAT(borderWidth + leftMargin, y + textYPad)
        gFONT(kMenuFont)
        runtime:drawCmd("text", { string = item.text })
        if item.shortcutText then
            local tx = borderWidth + leftMargin + self.maxTextWidth + textGap
            local ty = y + textYPad + self.shortcutTextYOffset
            gFONT(kShortcutFont)
            runtime:drawCmd("text", { string = item.shortcutText, x = tx, y = ty })
        end
        if item.submenu then
            gFONT(KFontEiksym15)
            local tx = self.w - self.rightMargin
            local ty = y + textYPad
            item.submenuXPos = tx + gTWIDTH('"')
            runtime:drawCmd("text", { string = '"', x = tx, y = ty })
        end
    end


function MenuPane:moveSelectionTo(i)
    if i == self.selected then
        return
    elseif i == 0 then
        i = #self.items
    elseif i and i > #self.items then
        i = 1
    end
    local firstVisible = self.firstVisibleItem
    local newFirstVisible = firstVisible
    local numvis = self.numVisibleItems
    if i and i < firstVisible then
        newFirstVisible = i
    elseif i and i >= firstVisible + numvis then
        newFirstVisible = i - numvis + 1
    end

    if newFirstVisible == firstVisible then
        if self.selected and self.selected >= firstVisible and self.selected < firstVisible + numvis then
            self:drawItem(self.selected, false)
        end
        self.selected = i
        if self.selected then
            self:drawItem(self.selected, true)
        end
    else
        self.selected = i
        self.firstVisibleItem = newFirstVisible
        self:drawItems()
        self:updateScrollbar()
    end
end

function MenuPane:updateScrollbar()
    if self.scrollbar then
        self.scrollbar:setContentOffset(self.items[self.firstVisibleItem].y - self.items[1].y)
    end
end

function MenuPane:choose(i)
    if not i then
        return nil
    end
    local item = self.items[i]
    local key = item.key
    if key & KMenuDimmed > 0 then
        gIPRINT("This item is not available", KBusyTopRight)
        return nil
    end
    self:drawItem(i, DrawStyle.dismissing)
    -- wait a bit to make it obvious it's been selected
    PAUSE(5)
    return key & 0xFF
end

function MenuPane:openSubmenu()
    assert(self.submenu == nil, "Submenu already open?!")
    local item = self.items[self.selected]
    self:drawItem(self.selected, DrawStyle.unfocussedHighlighted)
    assert(item.submenu, "No submenu to open!")
    self.submenu = MenuPane.new(self.x + item.submenuXPos, self:drawPosForContentPos(self.y) + item.y, KMPopupPosTopLeft, item.submenu)
end

function MenuPane:closeSubmenu()
    if self.submenu then
        gCLOSE(self.submenu.id)
        self.submenu = nil
        gUSE(self.id)
        local selected = self.selected
        self.selected = nil -- To force the move to redraw
        self:moveSelectionTo(selected)
    end
end

function MenuPane:drawPosForContentPos(y)
    return y - (self.items[self.firstVisibleItem].y - self.items[1].y)
end

function MenuPane:scrollbarContentOffsetChanged(scrollbar)
    local contentOffset = scrollbar.contentOffset
    local newFirstVisible
    for i, item in ipairs(self.items) do
        local itemContentPos = item.y - self.items[1].y
        -- printf("Item %d contentPos=%d vs scrollbar contentOffset %d\n", i, itemContentPos, contentOffset)
        if itemContentPos > contentOffset then
            break
        else
            newFirstVisible = i
        end
    end

    self.firstVisibleItem = newFirstVisible
    self:drawItems()
end

function MenuPane:scrollbarDidScroll(inc)
    local newFirstVisible = self.firstVisibleItem + inc
    if newFirstVisible < 1 or newFirstVisible + self.numVisibleItems - 1 > #self.items then
        return
    end
    self.firstVisibleItem = newFirstVisible
    self:drawItems()
    self:updateScrollbar()
end

function MenuPane.new(x, y, pos, values, selected, cutoutLen)
    -- Get required font metrics
    gFONT(kMenuFont)
    local _, textHeight, ascent = gTWIDTH("0")
    -- local textYPad = 3
    local lineHeight = textHeight + MenuPane.textYPad * 2
    gFONT(kShortcutFont)
    local _, _, shortcutAscent = gTWIDTH("0")
    local shortcutTextYOffset = ascent - shortcutAscent

    -- Work out content and window size
    local borderWidth = MenuPane.borderWidth
    local textGap = MenuPane.textGap
    local lineGap = MenuPane.lineGap -- 2 pixels space each side of the horizontal line
    local numItems = #values
    local items = {}
    local itemY = borderWidth + 3
    local maxTextWidth = 20
    local maxShortcutTextWidth = 0
    local shortcuts = {}
    for i, value in ipairs(values) do
        assert(value.key and value.key ~= 0 and value.text, KErrInvalidArgs)
        local key = value.key
        local lineAfter = key < 0
        if lineAfter then
            key = -key
        end
        local keyNoFlags = key & 0xFF
        local shortcutText
        if keyNoFlags <= 32 then
            shortcutText = nil
        elseif keyNoFlags >= 0x41 and keyNoFlags <= 0x5A then
            shortcutText = string.format("Shift+Ctrl+%c", keyNoFlags)
        elseif keyNoFlags >= 0x61 and keyNoFlags <= 0x7A then
            shortcutText = string.format("Ctrl+%c", keyNoFlags - 0x20)
        end
        gFONT(kMenuFont)
        local w = gTWIDTH(value.text)
        if shortcutText then
            shortcuts[keyNoFlags] = i
            gFONT(kShortcutFont)
            local sw = gTWIDTH(shortcutText)
            maxShortcutTextWidth = math.max(maxShortcutTextWidth, textGap + sw)
        end
        if w > maxTextWidth then
            maxTextWidth = w
        end
        items[i] = {
            text = value.text,
            shortcutText = shortcutText,
            key = key,
            y = itemY,
            h = lineHeight + (lineAfter and lineGap or 0),
            lineAfter = lineAfter,
            submenu = value.submenu,
        }
        -- printf("Item %d y=%d\n", i, itemY)
        itemY = itemY + items[i].h
    end

    local leftMargin = 15 -- This is part of the highlighted area
    local rightMargin = 20 -- ditto
    local contentWidth = leftMargin + maxTextWidth + maxShortcutTextWidth + rightMargin
    local screenWidth, screenHeight = runtime:getScreenInfo()
    local w = math.min(contentWidth + borderWidth * 2, screenWidth)
    local h = itemY + borderWidth
    local scrollbar = nil

    local numVisibleItems
    if h > screenHeight then
        numVisibleItems = (screenHeight - borderWidth - items[1].y) // lineHeight
        h = items[numVisibleItems].y + lineHeight + borderWidth
        local scrollbarTop = borderWidth
        local scrollbarContentHeight = (items[#items].y + items[#items].h) - scrollbarTop
        -- Where is this -3 from...?
        scrollbar = Scrollbar.newVertical(w - borderWidth + 2, scrollbarTop, h - borderWidth - 3, scrollbarContentHeight)
        w = w + scrollbar.w + 1
        if w > screenWidth then
            scrollbar.x = screenWidth - scrollbar.w
            w = screenWidth
        end
    else
        numVisibleItems = #items
    end

    if pos == KMPopupPosTopLeft then
        -- coords correct as-is
    elseif pos == KMPopupPosTopRight then
        x = x - w
    elseif pos == KMPopupPosBottomLeft then
        y = y - h
    elseif pos == KMPopupPosBottomRight then
        x = x - w
        y = y - h
    else
        error("Bad pos arg for menu")
    end
    x = math.max(0, x)
    y = math.max(0, y)

    -- Move x,y up/left to ensure it fits on screen
    if x + w > screenWidth then
        x = screenWidth - w
    end
    if y + h + 8 > screenHeight then
        y = math.max(0, screenHeight - h - 8) -- 8 for the shadow
    end

    local win = gCREATE(x, y, w, h, false, KgCreate4GrayMode | KgCreateHasShadow | 0x400)
    gBOX(w, h)
    gAT(1, 1)
    gXBORDER(2, 0x94, w - 2, h - 2)
    if scrollbar then
        darkGrey()
        gAT(scrollbar.x - 1, scrollbar.y)
        gLINEBY(0, scrollbar.h)
    end

    -- TODO this doesn't look right yet...
    -- if cutoutLen then
    --     gAT(borderWidth, 0)
    --     gFILL(cutoutLen, borderWidth, KgModeClear)
    -- end

    local pane = MenuPane {
        id = win,
        x = x,
        y = y,
        w = w,
        h = h,
        contentWidth = contentWidth,
        lineHeight = lineHeight,
        items = items,
        selected = 1,
        numVisibleItems = numVisibleItems,
        firstVisibleItem = 1,
        scrollbar = scrollbar,
        shortcutTextYOffset = shortcutTextYOffset,
        maxTextWidth = maxTextWidth,
    }

    pane:drawItems()
    if pane.scrollbar then
        pane.scrollbar.observer = pane
        pane.scrollbar:draw()
    end
    if selected then
        pane:moveSelectionTo(selected)
    end
    gVISIBLE(true)

    return pane
end

local function within(x, y, rect)
    return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

local function runMenuEventLoop(bar, pane, shortcuts)
    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local ev = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local evAddr = ev:addressOf()
    local result = nil
    local highlight = nil
    local seenPointerDown = false
    local capturedByControl = nil
    while result == nil do
        if bar then
            pane = bar.pane
        end
        highlight = nil
        GETEVENTA32(stat, evAddr)
        runtime:waitForRequest(stat)
        local current = pane.submenu or pane
        local k = ev[KEvAType]()
        if k == KKeyMenu then
            result = 0
        elseif k == KKeyUpArrow then
            current:moveSelectionTo(current.selected - 1)
        elseif k == KKeyDownArrow then
            current:moveSelectionTo(current.selected + 1)
        elseif k == KKeyLeftArrow then
            if pane.submenu then
                pane:closeSubmenu()
            elseif bar then
                bar.moveSelectionTo(bar.selected - 1)
            end
        elseif k == KKeyRightArrow then
            if pane.submenu == nil and pane.items[pane.selected].submenu then
                pane:openSubmenu()
            elseif bar then
                bar.moveSelectionTo(bar.selected + 1)
            end
        elseif k == KKeyEsc then
            if pane.submenu then
                pane:closeSubmenu()
            else
                result = 0
            end
        elseif k == KKeyEnter then
            if current.items[current.selected].submenu then
                current:openSubmenu()
            else
                result = current:choose(current.selected)
                highlight = bar and (bar.selected - 1) * 256 + (pane.selected - 1)
            end
        elseif k <= 26 then
            -- Check for a control-X shortcut (control modifier is implied by the code being 1-26)
            local shift = ev[KEvAKMod]() & KKmodShift > 0
            local cmd = (shift and 0x40 or 0x60) + k
            if shortcuts[cmd] then
                result = cmd
            end
        elseif k == KEvPtr then
            local evWinId = ev[KEvAPtrWindowId]()
            local x, y = ev[KEvAPtrPositionX](), ev[KEvAPtrPositionY]()
            local eventType = ev[KEvAPtrType]()
            local handled = false
            if capturedByControl then
                capturedByControl:handlePointerEvent(x, y, eventType)
                handled = true
                if eventType == KEvPtrPenUp then
                    capturedByControl = nil
                end
            elseif evWinId ~= current.id then
                if evWinId == pane.id then
                    pane:closeSubmenu()
                    current = pane
                    -- And keep going to handle it
                elseif bar and bar.selectionWin and evWinId == bar.selectionWin then
                    pane:closeSubmenu()
                    pane:moveSelectionTo(1)
                    handled = true
                elseif bar and evWinId == bar.id then
                    for i, item in ipairs(bar.items) do
                        if within(x, y, item) then
                            pane:closeSubmenu()
                            bar.moveSelectionTo(i)
                            break
                        end
                    end
                    handled = true
                elseif not seenPointerDown then
                    -- Ignore everything that might've resulted from a pen down before mPOPUP was called
                    if eventType == KEvPtrPenDown then
                        seenPointerDown = true
                    end
                    handled = true
                else
                    -- printf("Event not in any window!\n")
                    result = 0
                    break
                end
            end
            local idx
            if not handled then
                if x >= 0 and x < current.w and y >= 0 and y < current.h then
                    if current.scrollbar and x >= current.scrollbar.x and eventType == KEvPtrPenDown then
                        capturedByControl = current.scrollbar
                        current.scrollbar:handlePointerEvent(x, y, eventType)
                        handled = true
                    else
                        idx = #current.items
                        while idx and y < current:drawPosForContentPos(current.items[idx].y) do
                            idx = idx - 1
                            if idx == 0 then idx = nil end
                        end
                    end
                end
            end
            if not handled then
                current:moveSelectionTo(idx)
                if eventType == KEvPtrPenUp then
                    -- Pen up outside the window (ie when idx is nil) should always mean dismiss
                    if idx == nil then
                        result = 0
                    elseif current.items[current.selected].submenu then
                        current:openSubmenu()
                    else
                        result = current:choose(idx)
                        highlight = bar and (bar.selected - 1) * 256 + (pane.selected - 1)
                    end
                end
            end
        end
    end

    if pane.submenu then
        gCLOSE(pane.submenu.id)
    end
    gCLOSE(pane.id)
    if bar then
        if bar.selectionWin then
            gCLOSE(bar.selectionWin)
        end
        gCLOSE(bar.id)
    end
    return result, highlight
end

function mPOPUP(x, y, pos, values, init)
    -- Note, init isn't part of the actual OPL mPOPUP API but is needed to implement dialog choicelists properly
    local state = runtime:saveGraphicsState()

    local shortcuts = {}
    for _, item in ipairs(values) do
        local key = item.key
        if key < 0 then
            key = -key
        end
        if key > 32 then
            shortcuts[key & 0xFF] = true
        end
    end

    local pane = MenuPane.new(x, y, pos, values, init)
    local result = runMenuEventLoop(nil, pane, shortcuts)
    runtime:restoreGraphicsState(state)
    return result
end

function MENU(menubar)
    local state = runtime:saveGraphicsState()

    -- Draw the menu bar
    local barGap = 21
    local borderWidth = 5
    local barItems = {}
    local textx = borderWidth + barGap
    gFONT(kMenuFont)
    local _, textHeight, ascent = gTWIDTH("0")
    local textYPad = 2
    local barHeight = borderWidth * 2 + textHeight + textYPad * 2
    for i, card in ipairs(menubar) do
        local textw = gTWIDTH(card.title)
        barItems[i] = {
            x = textx - barGap // 2,
            textx = textx,
            text = card.title,
            y = borderWidth + textYPad,
            w = textw + barGap,
            h = barHeight,

        }
        textx = textx + textw + barGap
    end
    
    local barWidth = textx + borderWidth
    local barWin = gCREATE(2, 2, barWidth, barHeight, false, KgCreate4GrayMode | KgCreateHasShadow | 0x200)
    lightGrey()
    gFILL(barWidth, barHeight)
    black()
    gBOX(barWidth, barHeight)
    gAT(1, 1)
    gXBORDER(2, 0x94, barWidth - 2, barHeight - 2)
    for _, item in ipairs(barItems) do
        gAT(item.textx, item.y)
        runtime:drawCmd("text", { string = item.text })
    end
    gVISIBLE(true)

    -- There are at most 4 UI elements in play while displaying the menubar:
    -- 1: bar itself.
    -- 2: bar.selectionWin, which hovers over bar drawing the highlighted menu name.
    -- 3: pane, the currently displayed top-level menu.
    -- 4: pane.submenu, optionally. OPL doesn't support nested submenus.

    local bar = {
        x = 1,
        y = 1,
        w = barWidth,
        h = barHeight,
        id = barWin,
        items = barItems,
        selected = nil,
        selectionWin = nil,
    }
    local firstMenuY = bar.y + barHeight - borderWidth
    local initBarIdx = menubar.highlight and (1 + (menubar.highlight // 256)) or 1
    if initBarIdx > #bar.items then
        initBarIdx = 1
    end
    local initPaneIdx = menubar.highlight and (1 + (menubar.highlight - ((initBarIdx - 1) * 256))) or 1
    if initPaneIdx > #menubar[initBarIdx] then
        initPaneIdx = 1
    end

    local function drawBarSelection()
        if not bar.selectionWin then
            bar.selectionWin = gCREATE(-1, -1, 1, 1, true, KgCreate4GrayMode | KgCreateHasShadow | 0x200)
        end
        gUSE(bar.selectionWin)
        gFONT(kMenuFont)
        local item = bar.items[bar.selected]
        local w = item.w
        local h = firstMenuY - bar.y
        gSETWIN(bar.x + item.x, bar.y, w, h)
        gAT(0, 0)
        black()
        gFILL(w, h, KgModeClear)
        gBOX(w, h + 5)
        gAT(1, 1)
        gXBORDER(2, 0x94, w - 2, h + 5)
        runtime:drawCmd("text", { string = item.text, x = item.textx - item.x, y = item.y })
    end

    bar.moveSelectionTo = function(i)
        if i == bar.selected then
            return
        elseif i == 0 then
            i = #bar.items
        elseif i and i > #bar.items then
            i = 1
        end
        bar.selected = i
        drawBarSelection()
        if bar.pane then
           bar.pane:closeSubmenu()
           gCLOSE(bar.pane.id)
           bar.pane = nil
        end
        local item = bar.items[bar.selected]
        bar.pane = MenuPane.new(bar.x + item.x, firstMenuY, KMPopupPosTopLeft, menubar[bar.selected], 1, item.w)
    end

    bar.moveSelectionTo(initBarIdx)
    bar.pane:moveSelectionTo(initPaneIdx)

    -- Construct shorcuts
    local shortcuts = {}
    for _, pane in ipairs(menubar) do
        for _, item in ipairs(pane) do
            local key = item.key
            if key < 0 then
                key = -key
            end
            if key > 32 then
                shortcuts[key & 0xFF] = true
            end
        end
    end

    local result, highlight = runMenuEventLoop(bar, nil, shortcuts)
    runtime:restoreGraphicsState(state)
    return result, highlight
end

return _ENV

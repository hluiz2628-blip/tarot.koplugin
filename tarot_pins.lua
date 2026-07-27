-- Marcados: persistência de pins e popup da Home.

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local logger = require("logger")

local M = {}

function M.register(deps)
    deps = deps or {}
    local TarotPlugin = assert(deps.TarotPlugin, "TarotPlugin is required")
    local T = assert(deps.T, "translator is required")
    local FULL_DECK = assert(deps.FULL_DECK, "FULL_DECK is required")
    local LENORMAND_DECK = assert(deps.LENORMAND_DECK, "LENORMAND_DECK is required")
    local journalTrim = assert(deps.journalTrim, "journalTrim is required")
    local journalEscape = assert(deps.journalEscape, "journalEscape is required")
    local journalUnescape = assert(deps.journalUnescape, "journalUnescape is required")
    local journalReadAll = assert(deps.journalReadAll, "journalReadAll is required")
    local journalWriteAll = assert(deps.journalWriteAll, "journalWriteAll is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local getTopIconMetrics = assert(deps.getTopIconMetrics, "getTopIconMetrics is required")
    local getTarotButtonRadius = assert(deps.getTarotButtonRadius, "getTarotButtonRadius is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

    local PINLIST_MAGIC = "TAROT_PINLIST_V1"
    local PINLIST_MAX_PINS = 8
    local PINLIST_MENU_PIN_LIMIT = 5

    function TarotPlugin:makePinKey(item)
        if not item then return "" end
        if item.type == "card" then
            return "card:" .. tostring(item.deck or "") .. ":" .. tostring(item.id or "")
        elseif item.type == "journal" then
            return "journal:" .. tostring(item.id or "")
        end
        return ""
    end

    function TarotPlugin:makeCardPinItem(card, deck_is_lenormand)
        if not card then return nil end
        return {
            type = "card",
            id = tostring(card.id or ""),
            deck = deck_is_lenormand and "lenormand" or "tarot",
            title = T(card.name),
            updated_at = os.time(),
        }
    end

    function TarotPlugin:makeJournalPinItem(entry)
        if not entry then return nil end
        return {
            type = "journal",
            id = tostring(entry.id or ""),
            deck = tostring(entry.deck or ""),
            title = self:getJournalDisplayTitle(entry),
            updated_at = os.time(),
        }
    end

    function TarotPlugin:readPinListData()
        local data = { pins = {} }
        local content = self.pinlist_path and journalReadAll(self.pinlist_path) or nil
        if not content or content:sub(1, #PINLIST_MAGIC) ~= PINLIST_MAGIC then
            return data
        end

        local function parseItem(payload)
            local parts = {}
            for part in (tostring(payload or "") .. "|"):gmatch("([^|]*)|") do
                table.insert(parts, journalUnescape(part))
            end
            if #parts < 5 then return nil end
            local item = {
                type = parts[1],
                id = parts[2],
                deck = parts[3],
                title = parts[4],
                updated_at = tonumber(parts[5]) or 0,
            }
            if self:makePinKey(item) == "" then return nil end
            return item
        end

        for line in content:gmatch("[^\r\n]+") do
            local section, payload = line:match("^(pin)=(.*)$")
            if section == "pin" then
                local item = parseItem(payload)
                if item then table.insert(data.pins, item) end
            end
        end

        return data
    end

    function TarotPlugin:writePinListData(data)
        data = data or {}
        local lines = { PINLIST_MAGIC }
        local function writeItem(prefix, item)
            if not item or self:makePinKey(item) == "" then return end
            table.insert(lines, prefix .. "=" .. table.concat({
                journalEscape(item.type),
                journalEscape(item.id),
                journalEscape(item.deck or ""),
                journalEscape(item.title or ""),
                journalEscape(tostring(item.updated_at or os.time())),
            }, "|"))
        end

        for index, item in ipairs(data.pins or {}) do
            if index > PINLIST_MAX_PINS then break end
            writeItem("pin", item)
        end

        local ok, err = journalWriteAll(self.pinlist_path, table.concat(lines, "\n") .. "\n")
        if not ok then
            logger.warn("tarot.koplugin: erro ao salvar Marcados:", err)
        end
        return ok
    end

    function TarotPlugin:isPinnedItem(item)
        local key = self:makePinKey(item)
        if key == "" then return false end
        local data = self:readPinListData()
        for _, pinned in ipairs(data.pins or {}) do
            if self:makePinKey(pinned) == key then return true end
        end
        return false
    end

    function TarotPlugin:togglePinnedItem(item)
        if not item then return false end
        local key = self:makePinKey(item)
        if key == "" then return false end
        item.updated_at = os.time()

        local data = self:readPinListData()
        local removed = false
        local pins = {}
        for _, pinned in ipairs(data.pins or {}) do
            if self:makePinKey(pinned) == key then
                removed = true
            else
                table.insert(pins, pinned)
            end
        end
        if not removed then
            table.insert(pins, 1, item)
        end
        while #pins > PINLIST_MAX_PINS do table.remove(pins) end
        self:writePinListData{ pins = pins }
        return not removed
    end

    function TarotPlugin:findJournalEntryById(id)
        id = tostring(id or "")
        if id == "" then return nil end
        for _, from_trash in ipairs({ false, true }) do
            for _, entry in ipairs(self:getJournalEntries(from_trash)) do
                if tostring(entry.id or "") == id then return entry end
            end
        end
        return nil
    end

    function TarotPlugin:resolvePinItem(item)
        if not item then return nil end
        if item.type == "card" then
            local deck_is_lenormand = item.deck == "lenormand"
            local deck = deck_is_lenormand and LENORMAND_DECK or FULL_DECK
            for _, card in ipairs(deck) do
                if tostring(card.id or "") == tostring(item.id or "") then
                    item.title = T(card.name)
                    return item, card
                end
            end
        elseif item.type == "journal" then
            local entry = self:findJournalEntryById(item.id)
            if entry then
                item.title = self:getJournalDisplayTitle(entry)
                item.deck = tostring(entry.deck or "")
                return item, entry
            end
        end
        return item, nil
    end

    function TarotPlugin:formatPinListItemLabel(item)
        local title = journalTrim(item and item.title or "")
        if title == "" then title = self:getTranslation("untitled_reflection") end
        if item.type == "card" then
            return string.format(self:getTranslation("pin_card_label"), title)
        elseif item.type == "journal" then
            return string.format(self:getTranslation("pin_journal_label"), title)
        end
        return title
    end

    function TarotPlugin:getPinListMenuRows()
        local data = self:readPinListData()
        local rows = {}

        if #(data.pins or {}) > 0 then
            table.insert(rows, { label = true, text = self:getTranslation("marked") })
            local shown = 0
            for _, item in ipairs(data.pins or {}) do
                local resolved = self:resolvePinItem(item)
                local key = self:makePinKey(item)
                if key ~= "" then
                    shown = shown + 1
                    table.insert(rows, {
                        text = self:formatPinListItemLabel(resolved or item),
                        item = item,
                    })
                    if shown >= PINLIST_MENU_PIN_LIMIT then break end
                end
            end
        end

        if #rows == 0 then
            table.insert(rows, { label = true, text = self:getTranslation("marked_empty") })
        end

        return rows
    end

    function TarotPlugin:openPinListItem(item)
        local resolved_item, target = self:resolvePinItem(item)
        if not target then
            UIManager:show(InfoMessage:new{ text = self:getTranslation("pin_item_missing") })
            return
        end

        if item.type == "card" then
            self:showCardInBook(target, item.deck == "lenormand")
        elseif item.type == "journal" then
            self:showJournalEntry(target)
        end
    end

    local PinListPopup = InputContainer:extend{
        plugin = nil,
        layout = nil,
        slot = 1,
        box = nil,
        box_x = 0,
        box_y = 0,
    }

    function PinListPopup:init()
        local layout = self.layout or getFullscreenLayout(0.92)
        local rows = self.plugin:getPinListMenuRows()
        local metrics = getTopIconMetrics(layout)
        local touch_size = metrics.touch_size
        local gap = metrics.gap
        local slot = tonumber(self.slot) or 1
        local padding = Size.padding.default
        local box_w = math.floor(
            math.min(math.floor(layout.safe_w * 0.72), math.floor(layout.content_w * 0.82)) * 2 / 3
        )
        if box_w < math.floor(layout.content_w * 0.36) then
            box_w = math.floor(layout.content_w * 0.36)
        end
        local inner_w = math.max(80, box_w - padding * 2)
        local header_h = math.max(24, math.floor(touch_size * 0.70))
        local row_h = math.max(34, math.min(46, math.floor(layout.safe_h * 0.048)))

        self.box_x = layout.outer_pad + slot * (touch_size + gap)
        if self.box_x + box_w > layout.screen_w - layout.outer_pad then
            self.box_x = math.max(layout.outer_pad, layout.screen_w - layout.outer_pad - box_w)
        end
        self.box_y = layout.outer_pad + touch_size + gap

        self.dimen = Geom:new{ x = 0, y = 0, w = layout.screen_w, h = layout.screen_h }
        self.ges_events = {}

        local content = VerticalGroup:new{ align = "center" }
        local cursor_y = self.box_y + padding
        local action_index = 0

        local function addHeader(text)
            table.insert(content, CenterContainer:new{
                dimen = Geom:new{ w = inner_w, h = header_h },
                TextWidget:new{
                    text = text,
                    face = Font:getFace("x_smallinfofont"),
                    bold = true,
                    fgcolor = Blitbuffer.gray(0.45),
                    max_width = inner_w,
                    alignment = "center",
                },
            })
            cursor_y = cursor_y + header_h
        end

        local function addActionRow(row)
            action_index = action_index + 1
            local event_name = "TapPinListRow" .. tostring(action_index)
            local item = row.item
            table.insert(content, Button:new{
                text = row.text,
                width = inner_w,
                height = row_h,
                bordersize = 0,
                radius = 0,
                align = "left",
                padding_h = Size.padding.small,
                text_font_face = "x_smallinfofont",
                text_font_size = math.max(13, math.min(18, math.floor(row_h * 0.46))),
                text_font_bold = false,
            })
            self.ges_events[event_name] = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{
                        x = self.box_x + padding,
                        y = cursor_y,
                        w = inner_w,
                        h = row_h,
                    },
                },
            }
            self["on" .. event_name] = function()
                UIManager:close(self)
                setTarotDirty(self.plugin or self)
                self.plugin:openPinListItem(item)
                return true
            end
            cursor_y = cursor_y + row_h
        end

        for _, row in ipairs(rows) do
            if row.label then
                addHeader(row.text)
            else
                addActionRow(row)
            end
        end

        self.box = FrameContainer:new{
            width = box_w,
            background = Blitbuffer.COLOR_WHITE,
            bordersize = 1,
            radius = getTarotButtonRadius(),
            padding = padding,
            content,
        }

        local box_h = self.box:getSize().h
        local function addCloseRange(name, x, y, w, h)
            if w <= 0 or h <= 0 then return end
            self.ges_events[name] = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{ x = x, y = y, w = w, h = h },
                },
            }
            self["on" .. name] = function()
                UIManager:close(self)
                setTarotDirty(self.plugin or self)
                return true
            end
        end

        addCloseRange("TapPinListCloseTop", 0, 0, layout.screen_w, self.box_y)
        addCloseRange("TapPinListCloseLeft", 0, self.box_y, self.box_x, box_h)
        addCloseRange(
            "TapPinListCloseRight",
            self.box_x + box_w,
            self.box_y,
            layout.screen_w - self.box_x - box_w,
            box_h
        )
        addCloseRange(
            "TapPinListCloseBottom",
            0,
            self.box_y + box_h,
            layout.screen_w,
            layout.screen_h - self.box_y - box_h
        )
    end

    function PinListPopup:paintTo(bb, x, y)
        if self.box then
            self.box:paintTo(bb, x + self.box_x, y + self.box_y)
        end
    end

    function TarotPlugin:showPinListPopup(layout)
        UIManager:show(PinListPopup:new{
            plugin = self,
            layout = layout,
            slot = 1,
        })
        setTarotDirty(self.plugin or self, "partial")
    end


end

return M

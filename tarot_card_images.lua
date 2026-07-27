-- Suporte a imagens de cartas e fallbacks textuais.

local Blitbuffer     = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font           = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local InputContainer = require("ui/widget/container/inputcontainer")
local Screen         = require("device").screen
local TextWidget     = require("ui/widget/textwidget")

local M = {}

function M.register(deps)
    deps = deps or {}
    local TarotPlugin = assert(deps.TarotPlugin, "TarotPlugin is required")
    local T = assert(deps.T, "translator is required")
    local isRegularFile = assert(deps.isRegularFile, "isRegularFile is required")
    local makeSafeImageWidget = assert(deps.makeSafeImageWidget, "makeSafeImageWidget is required")

    function TarotPlugin:getCardImagePath(card)
        if type(card) ~= "table" then
            return nil
        end
        local plugin_dir = self.plugin_dir or self:getPluginDirectory()
        if card.symbol and card.name and card.number then
            local en_clean = card.name:gsub("^The%s+", "")
            return plugin_dir .. "/cards_lenormand/" .. tostring(card.number) .. "._" .. en_clean .. ".png"
        elseif card.roman and card.id and card.name then
            local id_str = string.format("%02d", card.id)
            local name_en_clean = card.name:gsub(" ", ""):gsub("'", "")
            return plugin_dir .. "/cards_tarot/" .. id_str .. "-" .. name_en_clean .. ".jpg"
        elseif card.suit and card.suit.name and card.rank and card.rank.name then
            local suit_en = card.suit.name
            local rank_map = {
                Ace=1, Two=2, Three=3, Four=4, Five=5, Six=6, Seven=7,
                Eight=8, Nine=9, Ten=10, Page=11, Knight=12, Queen=13, King=14,
            }
            local rank_val = rank_map[card.rank.name] or 0
            local rank_str = string.format("%02d", rank_val)
            return plugin_dir .. "/cards_tarot/" .. suit_en .. rank_str .. ".jpg"
        end
        return nil
    end

    function TarotPlugin:getCardImageWidget(card, w_override, h_override, rotation_angle)
        card = type(card) == "table" and card or {}
        local path = self:getCardImagePath(card)
        local screen_w = Screen:getWidth()
        local card_w, card_h
        if card.symbol then
            card_w = w_override or 250
            card_h = h_override or 250
        else
            local base_w = math.floor(screen_w * 0.25)
            card_w = w_override or base_w
            card_h = h_override or math.floor(card_w * (439 / 250))
        end
        card_w = math.max(1, tonumber(card_w) or 1)
        card_h = math.max(1, tonumber(card_h) or 1)

        if isRegularFile(path) then
            local image = makeSafeImageWidget{
                file = path,
                width = card_w,
                height = card_h,
                scale_for_dpi = false,
                rotation_angle = rotation_angle or 0,
            }
            if image then
                return image
            end
        end

        local text
        if card.symbol and card.name then
            text = card.symbol .. "\n" .. T(card.name)
        elseif card.roman and card.name then
            text = card.roman .. "\n" .. T(card.name)
        elseif card.suit then
            local suit_symbol = card.suit.symbol or ""
            local rank_text = card.rank and card.rank.name and T(card.rank.name) or "?"
            text = suit_symbol .. "\n" .. rank_text
        else
            text = "?"
        end

        return FrameContainer:new{
            width = card_w,
            height = card_h,
            bordersize = 0,
            background = Blitbuffer.COLOR_WHITE,
            CenterContainer:new{
                dimen = { w = card_w, h = card_h },
                TextWidget:new{
                    text = text,
                    face = Font:getFace("tfont"),
                    bold = true,
                    alignment = "center",
                },
            },
        }
    end

    local DimmedCard = InputContainer:extend{
        image_widget = nil,
        width = 0,
        height = 0,
    }

    function DimmedCard:init()
        self[1] = self.image_widget
    end

    function DimmedCard:paintTo(bb, x, y)
        if not self.image_widget then
            return
        end
        self.image_widget:paintTo(bb, x, y)
        local spacing = 2
        for i = 0, self.height - 1, spacing do
            bb:paintRect(x, y + i, self.width, 1, Blitbuffer.COLOR_BLACK)
        end
    end

    function TarotPlugin:getDimmedCardWidget(card, w, h, rotation_angle)
        local img = self:getCardImageWidget(card, w, h, rotation_angle)
        return DimmedCard:new{
            image_widget = img,
            width = math.max(1, tonumber(w) or 1),
            height = math.max(1, tonumber(h) or 1),
        }
    end

    function TarotPlugin:getDefaultCardSize(card)
        local screen_w = Screen:getWidth()
        if type(card) == "table" and card.symbol then
            return 250, 250
        end
        local w = math.floor(screen_w * 0.25)
        local h = math.floor(w * (439 / 250))
        return math.max(1, w), math.max(1, h)
    end

    function TarotPlugin:getBackCardImageWidget(w_override, h_override, deck_is_lenormand)
        local screen_w = Screen:getWidth()
        local card_w, card_h
        local plugin_dir = self.plugin_dir or self:getPluginDirectory()
        local path
        if deck_is_lenormand == nil then
            deck_is_lenormand = self.use_lenormand == true
        end
        if deck_is_lenormand then
            path = plugin_dir .. "/cards_lenormand/Card_Back.png"
            card_w = w_override or 250
            card_h = h_override or 250
        else
            path = plugin_dir .. "/cards_tarot/CardBacks.jpg"
            card_w = w_override or math.floor(screen_w * 0.25)
            card_h = h_override or math.floor(card_w * (439 / 250))
        end
        card_w = math.max(1, tonumber(card_w) or 1)
        card_h = math.max(1, tonumber(card_h) or 1)

        if isRegularFile(path) then
            local image = makeSafeImageWidget{
                file = path,
                width = card_w,
                height = card_h,
                scale_for_dpi = false,
            }
            if image then
                return image
            end
        end

        return FrameContainer:new{
            width = card_w,
            height = card_h,
            bordersize = 0,
            background = Blitbuffer.gray(0.8),
            CenterContainer:new{
                dimen = { w = card_w, h = card_h },
                TextWidget:new{
                    text = "?",
                    face = Font:getFace("tfont"),
                    bold = true,
                    alignment = "center",
                },
            },
        }
    end
end

return M

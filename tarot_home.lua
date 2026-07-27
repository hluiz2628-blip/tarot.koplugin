-- Home do plugin: Carta Diária, atalhos principais, Configurações e Marcados.

local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local M = {}

function M.create(deps)
    deps = deps or {}
    local T = assert(deps.T, "translator is required")
    local CardDialog = assert(deps.CardDialog, "CardDialog is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local getTarotButtonRadius = assert(deps.getTarotButtonRadius, "getTarotButtonRadius is required")
    local getCompactEmptyFooterHeight = assert(deps.getCompactEmptyFooterHeight, "getCompactEmptyFooterHeight is required")
    local makeTarotDivider = assert(deps.makeTarotDivider, "makeTarotDivider is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local makeFloatingIconButton = assert(deps.makeFloatingIconButton, "makeFloatingIconButton is required")
    local makeTopCloseIconButton = assert(deps.makeTopCloseIconButton, "makeTopCloseIconButton is required")
    local makeInlineIconButton = assert(deps.makeInlineIconButton, "makeInlineIconButton is required")
    local makeRoundedButton = assert(deps.makeRoundedButton, "makeRoundedButton is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

    -- ╔══════════════════════════════════════════════════════════════════════════════╗
    -- ║          SEÇÃO 9: TELA INICIAL EM TELA CHEIA (TarotHomeDialog)              ║
    -- ╚══════════════════════════════════════════════════════════════════════════════╝
    local TarotHomeDialog = InputContainer:extend{
        plugin = nil,
    }

    function TarotHomeDialog:init()
        local layout = getFullscreenLayout(0.92)
        local iw = layout.content_w
        local tile_gap = Size.span.horizontal_default
        local tile_button_w = math.floor((iw - tile_gap) / 2)
        local home_button_radius = math.max(getTarotButtonRadius(), math.floor(layout.safe_h * 0.018))

        -- Ao tocar num botão da Home, alguns aparelhos e-ink deixam o feedback de
        -- toque quadrado preso atrás da próxima tela. O pequeno agendamento abaixo
        -- dá tempo para o botão arredondado redesenhar antes de abrir o submenu.
        local function runHomeAction(action)
            setTarotDirty(self.plugin or self, "partial")
            UIManager:scheduleIn(0.05, function()
                if action then action() end
                setTarotDirty(self.plugin or self, "partial")
            end)
        end

        local daily_data = self.plugin:getDailyCardData()
        local daily_card = daily_data.card
        local daily_is_lenormand = daily_data.is_lenormand == true
        local daily_cards = {{
            card = daily_card,
            is_reversed = daily_data.is_reversed,
        }}

        local home_title = daily_is_lenormand
            and self.plugin:getTranslation("lenormand_deck")
            or self.plugin:getTranslation("tarot_deck")

        local daily_title_w = TextWidget:new{
            text      = "— " .. self.plugin:getTranslation("daily_card") .. " —",
            face      = Font:getFace("smalltfont"),
            bold      = true,
            max_width = iw,
            alignment = "center",
        }

        local card_w
        local card_h
        local is_square_card = daily_card.symbol ~= nil
        local ratio = is_square_card and 1 or (439 / 250)

        -- Tamanho adaptativo e conservador para a Carta Diária da Home.
        -- Evitamos medir TextWidget/VerticalGroup extras aqui porque alguns builds
        -- de KOReader/e-ink são sensíveis a medições antecipadas durante a abertura.
        -- Em vez disso, usamos a área segura da tela e reservamos uma faixa para
        -- cabeçalho, nome da carta e rodapé. Assim a imagem cresce em telas altas,
        -- mas continua segura em Kindle Basic 2022 e janelas pequenas.
        local reserved_ratio = self.plugin.hide_daily_card_name == true and 0.36 or 0.39
        local reserved_h = math.floor(layout.safe_h * reserved_ratio)
        local min_reserved_h = layout.safe_h < 1000 and 260 or 340
        local max_reserved_h = math.floor(layout.safe_h * 0.50)
        if min_reserved_h > max_reserved_h then min_reserved_h = max_reserved_h end
        if reserved_h < min_reserved_h then reserved_h = min_reserved_h end
        if reserved_h > max_reserved_h then
            reserved_h = max_reserved_h
        end

        local max_card_h = layout.safe_h - reserved_h
        local min_card_h = math.floor(layout.safe_h * (layout.safe_h < 1000 and 0.26 or 0.34))
        if max_card_h < min_card_h then
            max_card_h = min_card_h
        end
        local max_card_h_ratio = layout.safe_h < 1000 and 0.46 or 0.60
        if max_card_h > math.floor(layout.safe_h * max_card_h_ratio) then
            max_card_h = math.floor(layout.safe_h * max_card_h_ratio)
        end

        local max_card_w = math.floor(iw * (is_square_card and 0.82 or 0.58))
        local by_height_w = math.floor(max_card_h / ratio)
        card_w = math.min(max_card_w, by_height_w)

        local min_card_w = is_square_card and 92 or 74
        if card_w < min_card_w then card_w = min_card_w end

        local hard_max_w
        if is_square_card then
            hard_max_w = math.floor(layout.safe_h * 0.34)
            if hard_max_w < 320 then hard_max_w = 320 end
            if hard_max_w > 480 then hard_max_w = 480 end
        else
            hard_max_w = math.floor(layout.safe_h * 0.27)
            if hard_max_w < 250 then hard_max_w = 250 end
            if hard_max_w > 380 then hard_max_w = 380 end
        end
        if card_w > hard_max_w then card_w = hard_max_w end

        card_h = math.floor(card_w * ratio)
        if card_h > max_card_h then
            local scale = max_card_h / card_h
            card_w = math.max(48, math.floor(card_w * scale))
            card_h = math.max(48, math.floor(card_h * scale))
        end

        local daily_image
        if daily_data.is_revealed then
            daily_image = self.plugin:getCardImageWidget(
                daily_card,
                card_w,
                card_h,
                (daily_data.is_reversed and not daily_is_lenormand) and 180 or 0
            )
        else
            daily_image = self.plugin:getBackCardImageWidget(card_w, card_h, daily_is_lenormand)
        end

        local daily_name_w
        if daily_data.is_revealed then
            if self.plugin.hide_daily_card_name ~= true then
                local daily_name = T(daily_card.name)
                if daily_data.is_reversed
                    and not daily_is_lenormand
                    and self.plugin.show_reversed_label ~= false then
                    daily_name = daily_name .. " (" .. self.plugin:getTranslation("reversed") .. ")"
                end
                daily_name_w = TextWidget:new{
                    text      = daily_name,
                    face      = Font:getFace("cfont"),
                    bold      = true,
                    max_width = iw,
                    alignment = "center",
                }
            end
        else
            daily_name_w = TextWidget:new{
                text      = self.plugin:getTranslation("hidden_card"),
                face      = Font:getFace("cfont"),
                bold      = true,
                max_width = iw,
                alignment = "center",
            }
        end

        local daily_button
        if daily_data.is_revealed then
            daily_button = makeInlineIconButton{
                plugin = self.plugin,
                icon_name = "book-open",
                fallback_text = self.plugin:getTranslation("open_daily_card"),
                width = math.floor(iw * 0.72),
                callback = function()
                    UIManager:show(CardDialog:new{
                        cards = daily_cards,
                        current_index = 1,
                        plugin = self.plugin,
                        title_label = self.plugin:getTranslation("daily_card"),
                        on_new = function()
                            self.plugin:showDailyCard()
                        end,
                        is_daily = true,
                        deck_is_lenormand = daily_is_lenormand,
                    })
                    setTarotDirty(self.plugin or self)
                end,
            }
        else
            daily_button = makeRoundedButton{
                text   = self.plugin:getTranslation("reveal_daily_card"),
                width  = math.floor(iw * 0.72),
                radius = home_button_radius,
                bordersize = 1,
                callback = function()
                    self.plugin:markDailyCardRevealed(daily_data)
                    UIManager:close(self)
                    UIManager:show(TarotHomeDialog:new{ plugin = self.plugin })
                    setTarotDirty(self.plugin or self)
                end,
            }
        end

        local btn_spreads = makeRoundedButton{
            text   = self.plugin:getTranslation("spreads"),
            width  = tile_button_w,
            radius = home_button_radius,
            bordersize = 1,
            callback = function()
                runHomeAction(function() self.plugin:showSpreadsMenu() end)
            end,
        }

        local btn_journal = makeRoundedButton{
            text   = self.plugin:getTranslation("journal"),
            width  = tile_button_w,
            radius = home_button_radius,
            bordersize = 1,
            callback = function()
                runHomeAction(function() self.plugin:showSavedReadingsMenu() end)
            end,
        }

        local btn_book = makeRoundedButton{
            text   = self.plugin:getTranslation("card_book"),
            width  = iw,
            radius = home_button_radius,
            bordersize = 1,
            callback = function()
                runHomeAction(function() self.plugin:showCardBook() end)
            end,
        }

        local body_items = { align = "center" }
        table.insert(body_items, daily_title_w)
        table.insert(body_items, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(body_items, daily_image)
        if daily_name_w then
            table.insert(body_items, VerticalSpan:new{ width = Size.span.vertical_small })
            table.insert(body_items, daily_name_w)
        end
        local body = VerticalGroup:new(body_items)

        local footer = VerticalGroup:new{ align = "center" }
        table.insert(footer, daily_button)
        table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(footer, makeTarotDivider(iw))
        table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(footer, HorizontalGroup:new{
            align = "center",
            btn_spreads,
            HorizontalSpan:new{ width = tile_gap },
            btn_journal,
        })
        table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(footer, btn_book)
        table.insert(footer, VerticalSpan:new{ width = getCompactEmptyFooterHeight(iw) })

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            title = home_title,
            body = body,
            footer = footer,
            footer_gap = Size.span.vertical_small,
        }

        self[1] = OverlapGroup:new{
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
            makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = "settings",
                fallback_text = self.plugin:getTranslation("configuration"),
                side = "left",
                callback = function()
                    self.plugin:showSettings(self)
                end,
            },
            makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = "pin-list",
                fallback_text = self.plugin:getTranslation("marked"),
                side = "left",
                slot = 1,
                callback = function()
                    self.plugin:showPinListPopup(layout)
                end,
            },
            makeTopCloseIconButton(self.plugin, layout, function()
                UIManager:close(self)
                setTarotDirty(self.plugin or self)
            end),
        }
    end


    return TarotHomeDialog
end

return M

-- Baralho físico: lista textual, seleção manual, inversão e abertura da tiragem.

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local Screen = require("device").screen
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local M = {}

function M.create(deps)
    deps = deps or {}
    local T = assert(deps.T, "translator is required")
    local UI_TEXT = assert(deps.UI_TEXT, "UI_TEXT is required")
    local CardDialog = assert(deps.CardDialog, "CardDialog is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local makeSectionHeader = assert(deps.makeSectionHeader, "makeSectionHeader is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local makeFullscreenFooter = assert(deps.makeFullscreenFooter, "makeFullscreenFooter is required")
    local makeTransparentTextButton = assert(deps.makeTransparentTextButton, "makeTransparentTextButton is required")
    local makeTopBackIconButton = assert(deps.makeTopBackIconButton, "makeTopBackIconButton is required")
    local addHorizontalSwipeNavigation = assert(deps.addHorizontalSwipeNavigation, "addHorizontalSwipeNavigation is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

    local function getPhysicalDeckListStyle(layout)
        local sh = layout and layout.screen_h or Screen:getHeight()
        if sh < 720 then
            return { font_size = 16, padding_v = Size.padding.tiny, max_items = 10, min_items = 3 }
        elseif sh < 950 then
            return { font_size = 18, padding_v = Size.padding.small, max_items = 12, min_items = 4 }
        elseif sh < 1200 then
            return { font_size = 20, padding_v = Size.padding.small, max_items = 15, min_items = 5 }
        end
        return { font_size = 20, padding_v = Size.padding.small, max_items = 20, min_items = 6 }
    end

    -- Calcula quantas cartas cabem na página do Baralho Físico usando a altura
    -- realmente restante entre cabeçalho e rodapé. Isso substitui os antigos
    -- valores fixos e adapta melhor Kindle Basic 2022, desktop redimensionado e
    -- celulares com barras de navegação.
    local function getAdaptivePhysicalDeckItemsPerPage(layout, header_widget, style)
        style = style or getPhysicalDeckListStyle(layout)
        local iw = layout.content_w

        local sample_row = Button:new{
            text = "☑ 16  78. " .. T("Eight of Pentacles") .. " — " .. T(UI_TEXT.reversed),
            width = iw,
            bordersize = 0,
            radius = 0,
            align = "left",
            text_font_face = "smallinfofont",
            text_font_size = style.font_size,
            text_font_bold = false,
            padding_h = Size.padding.default,
            padding_v = style.padding_v,
            callback = function() end,
        }

        local sample_footer = makeFullscreenFooter(iw, VerticalGroup:new{
            align = "center",
            HorizontalGroup:new{
                align = "center",
                makeTransparentTextButton{ text = "<", width = math.floor(iw * 0.22), enabled = false },
                TextWidget:new{
                    text = "999 / 999",
                    face = Font:getFace("x_smallinfofont"),
                    max_width = math.floor(iw * 0.44),
                    alignment = "center",
                },
                makeTransparentTextButton{ text = ">", width = math.floor(iw * 0.22), enabled = false },
            },
            VerticalSpan:new{ width = Size.span.vertical_small },
            HorizontalGroup:new{
                align = "center",
                makeTransparentTextButton{ text = T(UI_TEXT.back), width = math.floor(iw * 0.38) },
                HorizontalSpan:new{ width = math.floor(iw * 0.08) },
                makeTransparentTextButton{ text = T(UI_TEXT.done), width = math.floor(iw * 0.38) },
            },
        })

        local header_h = header_widget and header_widget:getSize().h or 0
        local footer_h = sample_footer:getSize().h
        local vertical_gaps = Size.span.vertical_default * 2
        local available_h = layout.safe_h - header_h - footer_h - vertical_gaps
        local row_h = math.max(1, sample_row:getSize().h)
        local count = math.floor(available_h / row_h)

        if count < style.min_items then count = style.min_items end
        if count > style.max_items then count = style.max_items end
        return count
    end

    -- Menu simples em fullscreen, usado para substituir ButtonDialog nos fluxos
    -- de navegação do plugin. Caixas de texto continuam como InputDialog para
    -- preservar o teclado e o comportamento nativo do KOReader.
    -- ╔══════════════════════════════════════════════════════════════════════════════╗
    -- ║      SELETOR DE BARALHO FÍSICO — LISTA TEXTUAL COM ATÉ 16 CARTAS           ║
    -- ╚══════════════════════════════════════════════════════════════════════════════╝
    -- O seletor não sorteia cartas e não exibe imagens. Ele apenas registra, na
    -- ordem dos toques, até dezesseis cartas que o usuário retirou do próprio baralho.
    -- Ao confirmar, as cartas escolhidas são abertas no CardDialog já existente.
    local PHYSICAL_DECK_MAX_CARDS = 16

    local PhysicalDeckDialog = InputContainer:extend{
        plugin = nil,
        deck = nil,
        deck_is_lenormand = false,
        selected_indices = nil,
        reversed_indices = nil,
        page = 1,
    }

    function PhysicalDeckDialog:init()
        local layout = getFullscreenLayout()
        local iw = layout.content_w
        local sh = layout.screen_h

        self.deck = self.deck or {}
        self.selected_indices = self.selected_indices or {}
        self.reversed_indices = self.reversed_indices or {}
        self.page = tonumber(self.page) or 1

        local list_style = getPhysicalDeckListStyle(layout)

        local header_w = makeSectionHeader(
            self.plugin:getTranslation("physical_deck"),
            iw,
            self.plugin:getTranslation("physical_deck_hint")
        )

        -- A quantidade de linhas por página agora nasce do espaço real disponível.
        -- Em telas altas cabem mais cartas; em janelas baixas o número recua antes
        -- de sobrepor rodapé, paginação ou botões de ação.
        local items_per_page = getAdaptivePhysicalDeckItemsPerPage(layout, header_w, list_style)

        local total_pages = math.max(1, math.ceil(#self.deck / items_per_page))
        if self.page < 1 then self.page = 1 end
        if self.page > total_pages then self.page = total_pages end

        -- Retorna a ordem em que a carta foi selecionada. Além de informar se a
        -- carta está marcada, isso permite exibir claramente as posições 1 a 16.
        local function getSelectionPosition(index)
            for position, selected_index in ipairs(self.selected_indices) do
                if selected_index == index then return position end
            end
            return nil
        end

        local function copySelection()
            local copy = {}
            for _, index in ipairs(self.selected_indices) do
                table.insert(copy, index)
            end
            return copy
        end

        local function copyReversedSelection()
            local copy = {}
            for index, is_reversed in pairs(self.reversed_indices) do
                if is_reversed == true then
                    copy[index] = true
                end
            end
            return copy
        end

        local function reopen(page)
            UIManager:close(self)
            UIManager:show(PhysicalDeckDialog:new{
                plugin = self.plugin,
                deck = self.deck,
                deck_is_lenormand = self.deck_is_lenormand,
                selected_indices = copySelection(),
                reversed_indices = copyReversedSelection(),
                page = page or self.page,
            })
            setTarotDirty(self.plugin or self)
        end

        local function toggleCard(index)
            local selected_position = getSelectionPosition(index)

            if selected_position then
                table.remove(self.selected_indices, selected_position)
                self.reversed_indices[index] = nil
                reopen(self.page)
                return
            end

            if #self.selected_indices >= PHYSICAL_DECK_MAX_CARDS then
                UIManager:show(InfoMessage:new{
                    text = self.plugin:getTranslation("physical_deck_limit"),
                })
                return
            end

            table.insert(self.selected_indices, index)
            self.reversed_indices[index] = nil
            reopen(self.page)
        end

        -- No Tarot, o toque longo alterna a orientação. Se a carta ainda não foi
        -- escolhida, ela entra na próxima posição já como invertida. O Lenormand
        -- permanece sem invertidas, coerente com os dados e diálogos do plugin.
        local function toggleCardReversed(index)
            if self.deck_is_lenormand then return end

            local selected_position = getSelectionPosition(index)
            if not selected_position then
                if #self.selected_indices >= PHYSICAL_DECK_MAX_CARDS then
                    UIManager:show(InfoMessage:new{
                        text = self.plugin:getTranslation("physical_deck_limit"),
                    })
                    return
                end
                table.insert(self.selected_indices, index)
                self.reversed_indices[index] = true
            else
                self.reversed_indices[index] = not (self.reversed_indices[index] == true)
            end

            reopen(self.page)
        end

        local content = VerticalGroup:new{ align = "center" }

        local first_index = (self.page - 1) * items_per_page + 1
        local last_index = math.min(first_index + items_per_page - 1, #self.deck)

        for index = first_index, last_index do
            -- Variável local por linha para impedir que callbacks de versões Lua
            -- antigas compartilhem o último valor do laço numérico.
            local card_index = index
            local card = self.deck[card_index]
            local selected_position = getSelectionPosition(card_index)
            local mark = selected_position and "☑" or "☐"
            local order_label = selected_position and string.format("%d", selected_position) or " "
            local orientation_label = ""
            if selected_position and self.reversed_indices[card_index] == true then
                orientation_label = " — " .. self.plugin:getTranslation("reversed")
            end
            local label = string.format(
                "%s %2s  %d. %s%s",
                mark, order_label, card_index, T(card.name), orientation_label
            )

            table.insert(content, Button:new{
                text = label,
                width = iw,
                bordersize = 0,
                radius = 0,
                align = "left",
                text_font_face = "smallinfofont",
                text_font_size = list_style.font_size,
                text_font_bold = false,
                padding_h = Size.padding.default,
                padding_v = list_style.padding_v,
                callback = function()
                    toggleCard(card_index)
                end,
                hold_callback = function()
                    toggleCardReversed(card_index)
                end,
            })
        end

        -- A lista navega por swipe horizontal. O rodapé mostra apenas a posição.
        local nav_row = CenterContainer:new{
            dimen = Geom:new{ w = iw, h = 32 },
            TextWidget:new{
                text = string.format(self.plugin:getTranslation("page_count"), self.page, total_pages),
                face = Font:getFace("x_smallinfofont"),
                fgcolor = Blitbuffer.gray(0.45),
                max_width = iw,
                alignment = "center",
            },
        }

        local footer_row = HorizontalGroup:new{
            align = "center",
            makeTransparentTextButton{
                text = self.plugin:getTranslation("done"),
                width = math.floor(iw * 0.50),
                callback = function()
                    if #self.selected_indices == 0 then
                        UIManager:show(InfoMessage:new{
                            text = self.plugin:getTranslation("physical_deck_empty"),
                        })
                        return
                    end

                    local cards = {}
                    for _, selected_index in ipairs(self.selected_indices) do
                        local selected_card = self.deck[selected_index]
                        if selected_card then
                            table.insert(cards, {
                                card = selected_card,
                                -- A orientação é escolhida manualmente por toque
                                -- longo e independe da configuração das tiragens
                                -- virtuais. No Lenormand permanece sempre normal.
                                is_reversed = (not self.deck_is_lenormand)
                                    and self.reversed_indices[selected_index] == true,
                            })
                        end
                    end

                    if #cards == 0 then
                        UIManager:show(InfoMessage:new{
                            text = self.plugin:getTranslation("physical_deck_empty"),
                        })
                        return
                    end

                    UIManager:close(self)
                    UIManager:show(CardDialog:new{
                        cards = cards,
                        current_index = 1,
                        plugin = self.plugin,
                        title_label = self.plugin:getTranslation("physical_deck"),
                        deck_is_lenormand = self.deck_is_lenormand,
                        on_new = function()
                            self.plugin:showPhysicalDeckSelector()
                        end,
                        is_daily = false,
                    })
                    setTarotDirty(self.plugin or self)
                end,
            },
        }

        local footer = makeFullscreenFooter(iw, VerticalGroup:new{
            align = "center",
            nav_row,
            VerticalSpan:new{ width = Size.span.vertical_small },
            footer_row,
        })

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            header = header_w,
            body = content,
            footer = footer,
        }

        self[1] = OverlapGroup:new{
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
            makeTopBackIconButton(self.plugin, layout, function()
                UIManager:close(self)
                self.plugin:showSpreadsMenu()
                setTarotDirty(self.plugin or self)
            end),
        }

        addHorizontalSwipeNavigation(self, "tarot_physical_deck_swipe_nav",
            self.page > 1 and function() reopen(self.page - 1) end or nil,
            self.page < total_pages and function() reopen(self.page + 1) end or nil
        )
    end


    return PhysicalDeckDialog
end

return M

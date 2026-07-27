-- CardDialog: visualização de carta, zoom, significados, pins e navegação.

local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
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
    local TappableImageContainer = assert(deps.TappableImageContainer, "TappableImageContainer is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local makeFullscreenFrame = assert(deps.makeFullscreenFrame, "makeFullscreenFrame is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local makeSectionHeader = assert(deps.makeSectionHeader, "makeSectionHeader is required")
    local makeMutedText = assert(deps.makeMutedText, "makeMutedText is required")
    local makeFloatingIconButton = assert(deps.makeFloatingIconButton, "makeFloatingIconButton is required")
    local makeTopBackIconButton = assert(deps.makeTopBackIconButton, "makeTopBackIconButton is required")
    local addHorizontalSwipeNavigation = assert(deps.addHorizontalSwipeNavigation, "addHorizontalSwipeNavigation is required")
    local getPositionNameDisplay = assert(deps.getPositionNameDisplay, "getPositionNameDisplay is required")
    local isRegularFile = assert(deps.isRegularFile, "isRegularFile is required")
    local journalTrim = assert(deps.journalTrim, "journalTrim is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

    -- Exibe apenas a imagem da carta em tamanho máximo seguro. Tocar novamente na
    -- carta fecha a ampliação e retorna ao CardDialog sem alterar a leitura.
    local ZoomCardDialog = InputContainer:extend{
        plugin = nil,
        card = nil,
        deck_is_lenormand = false,
        is_reversed = false,
    }

    function ZoomCardDialog:init()
        local layout = getFullscreenLayout(0.98)
        local base_w, base_h = self.plugin:getDefaultCardSize(self.card)
        local max_w = math.floor(layout.safe_w * 0.90)
        local max_h = math.floor(layout.safe_h * 0.94)
        local scale = math.min(max_w / base_w, max_h / base_h)
        if scale <= 0 then scale = 1 end

        local image_w = math.max(1, math.floor(base_w * scale))
        local image_h = math.max(1, math.floor(base_h * scale))
        local rotation = (self.is_reversed and not self.deck_is_lenormand) and 180 or 0

        local zoomed_image = self.plugin:getCardImageWidget(
            self.card, image_w, image_h, rotation
        )
        local tappable = TappableImageContainer:new{
            content = zoomed_image,
            callback = function()
                UIManager:close(self)
                setTarotDirty(self.plugin or self)
            end,
        }

        self[1] = makeFullscreenFrame(
            VerticalGroup:new{ align = "center", tappable },
            layout
        )
    end

    -- Produz um resumo UTF-8 seguro sem cortar caracteres no meio.
    local function summarizeCardMeaning(text, max_chars)
        text = tostring(text or ""):gsub("%s+", " ")
        max_chars = tonumber(max_chars) or 180
        local chars = {}
        for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            chars[#chars + 1] = char
            if #chars >= max_chars then break end
        end
        if #chars >= max_chars then
            return table.concat(chars) .. "…"
        end
        return text
    end

    -- ╔══════════════════════════════════════════════════════════════════════════════╗
    -- ║   SEÇÃO 8: DIÁLOGO DA CARTA (CardDialog) – CENTRAL FIXA + MINIATURAS        ║
    -- ╚══════════════════════════════════════════════════════════════════════════════╝
    local CardDialog = InputContainer:extend{
        cards = nil,
        current_index = 1,
        card_labels = nil,
        revealed_count = nil,
        on_new = nil,
        plugin = nil,
        title_label = nil,
        is_daily = false,
        read_only = false,
        deck_is_lenormand = nil,
        on_close = nil,
        auto_save_state = nil,
        manual_save_state = nil,
        hidden_grid_view = false,
    }

    function CardDialog:init()
        local layout = getFullscreenLayout()
        local sw  = layout.screen_w
        local iw  = layout.content_w
        self.cards = type(self.cards) == "table" and self.cards or {}
        local function showEmptyCardDialog()
            local empty_text = self.plugin and self.plugin:getTranslation("no_results") or "No cards found."
            local fullscreen_scaffold = makeFullscreenScaffold{
                layout = layout,
                title = self.title_label or (self.plugin and self.plugin:getTranslation("title") or ""),
                body = TextWidget:new{
                    text = empty_text,
                    face = Font:getFace("cfont"),
                    max_width = iw,
                    alignment = "center",
                },
            }
            self[1] = OverlapGroup:new{
                dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
                fullscreen_scaffold,
                self.plugin and makeTopBackIconButton(self.plugin, layout, function()
                    UIManager:close(self)
                    setTarotDirty(self.plugin or self)
                end) or nil,
            }
        end
        local use_lenormand = self.deck_is_lenormand
        if use_lenormand == nil then
            use_lenormand = self.plugin and self.plugin.use_lenormand
        end

        local total_cards = #self.cards
        if total_cards == 0 then
            showEmptyCardDialog()
            return
        end
        local revealed_count = tonumber(self.revealed_count) or total_cards
        if revealed_count < 1 then revealed_count = 1 end
        if revealed_count > total_cards then revealed_count = total_cards end
        if self.current_index < 1 then
            self.current_index = 1
        end
        if self.current_index > revealed_count then
            self.current_index = revealed_count
        end
        local card_data = self.cards[self.current_index]
        if type(card_data) ~= "table" or type(card_data.card) ~= "table" then
            showEmptyCardDialog()
            return
        end
        local card = card_data.card
        local is_reversed = card_data.is_reversed
        local has_unrevealed_cards = revealed_count < total_cards
        -- Carta Diária e registros reabertos mantêm o significado completo. Nas
        -- tiragens, o usuário pode escolher entre completo, resumido e oculto.
        local is_spread_view = not self.is_daily and not self.read_only
        local meaning_mode = is_spread_view and self.plugin.spread_meaning_mode or "full"
        local show_meaning = meaning_mode ~= "hidden"

        -- Ao revelar a última carta, salva uma única vez e mantém o estado entre
        -- todas as reconstruções do CardDialog.
        if is_spread_view
            and self.plugin.auto_save_spreads == true
            and not self.hidden_grid_view
            and not has_unrevealed_cards
            and self.auto_save_state == nil then
            self.auto_save_state = self.plugin:autoSaveReading(self.cards) and "saved" or "failed"
        end

        local card_path = self.plugin:getCardImagePath(card)
        local has_image = isRegularFile(card_path)
        local hide_name = use_lenormand and T.current_lang == "C" and has_image

        local position_title = getPositionNameDisplay(self.plugin, card_data.position_name)
        local title_suffix = position_title ~= ""
            and position_title
            or (self.title_label or self.plugin:getTranslation("title"))
        if position_title == "" and not self.title_label and use_lenormand then
            title_suffix = self.plugin:getTranslation("lenormand_title")
        end
        local title_text = title_suffix

        -- Título fixo no topo em todas as telas de carta, inclusive nas tiragens.
        -- A área central e o rodapé são calculados separadamente para evitar
        -- sobreposição em telas e-ink pequenas.
        local header_w = makeSectionHeader(title_text, iw)

        -- Mostra o progresso somente durante a revelação sequencial. Quando todas
        -- as cartas já foram abertas, o diálogo volta ao visual convencional.
        local reveal_progress_w
        if self.revealed_count and total_cards > 1 and has_unrevealed_cards then
            reveal_progress_w = TextWidget:new{
                text = string.format(
                    self.plugin:getTranslation("revealed_count"),
                    revealed_count,
                    total_cards
                ),
                face = Font:getFace("x_smallinfofont"),
                fgcolor = Blitbuffer.gray(0.5),
                max_width = iw,
                alignment = "center",
            }
        end

        local function reopenAt(target_index)
            if target_index < 1 or target_index > revealed_count then return end
            UIManager:close(self)
            UIManager:show(CardDialog:new{
                cards = self.cards,
                current_index = target_index,
                card_labels = self.card_labels,
                revealed_count = self.revealed_count,
                on_new = self.on_new,
                plugin = self.plugin,
                title_label = self.title_label,
                is_daily = self.is_daily,
                read_only = self.read_only,
                deck_is_lenormand = self.deck_is_lenormand,
                on_close = self.on_close,
                auto_save_state = self.auto_save_state,
                manual_save_state = self.manual_save_state,
                hidden_grid_view = self.hidden_grid_view,
            })
            setTarotDirty(self.plugin or self)
        end

        local function revealNextCard()
            if not has_unrevealed_cards then return end
            local next_revealed = revealed_count + 1
            UIManager:close(self)
            UIManager:show(CardDialog:new{
                cards = self.cards,
                current_index = next_revealed,
                card_labels = self.card_labels,
                revealed_count = next_revealed,
                on_new = self.on_new,
                plugin = self.plugin,
                title_label = self.title_label,
                is_daily = self.is_daily,
                read_only = self.read_only,
                deck_is_lenormand = self.deck_is_lenormand,
                on_close = self.on_close,
                auto_save_state = self.auto_save_state,
                manual_save_state = self.manual_save_state,
                hidden_grid_view = self.hidden_grid_view,
            })
            setTarotDirty(self.plugin or self)
        end

        local function revealAllCards()
            if not has_unrevealed_cards then return end

            local confirm
            confirm = ConfirmBox:new{
                text = self.plugin:getTranslation("reveal_all_confirm"),
                ok_text = self.plugin:getTranslation("yes"),
                cancel_text = self.plugin:getTranslation("no"),
                ok_callback = function()
                    UIManager:close(confirm)
                    UIManager:close(self)
                    UIManager:show(CardDialog:new{
                        cards = self.cards,
                        current_index = total_cards,
                        card_labels = self.card_labels,
                        revealed_count = total_cards,
                        on_new = self.on_new,
                        plugin = self.plugin,
                        title_label = self.title_label,
                        is_daily = self.is_daily,
                        read_only = self.read_only,
                        deck_is_lenormand = self.deck_is_lenormand,
                        on_close = self.on_close,
                        auto_save_state = self.auto_save_state,
                        manual_save_state = self.manual_save_state,
                        hidden_grid_view = self.hidden_grid_view,
                    })
                    setTarotDirty(self.plugin or self)
                end,
            }
            UIManager:show(confirm)
        end

        local card_image
        if total_cards > 1 then
            local spacing = 24
            local has_left = self.current_index > 1
            local has_right = self.current_index < total_cards

            local main_w, main_h = self.plugin:getDefaultCardSize(card)
            local center_img = self.plugin:getCardImageWidget(
                card, main_w, main_h,
                (is_reversed and not use_lenormand) and 180 or 0
            )
            center_img = TappableImageContainer:new{
                content = center_img,
                callback = function()
                    UIManager:show(ZoomCardDialog:new{
                        plugin = self.plugin,
                        card = card,
                        deck_is_lenormand = use_lenormand,
                        is_reversed = is_reversed,
                    })
                    setTarotDirty(self.plugin or self)
                end,
            }

            local mini_w = math.floor(main_w * 2/3)
            local mini_h = math.floor(main_h * 2/3)

            local remaining = iw - main_w
            local half_remaining = math.floor(remaining / 2)

            local left_img, right_img
            if has_left then
                local left_data = self.cards[self.current_index - 1]
                local left_card = left_data.card
                if use_lenormand then
                    left_img = self.plugin:getCardImageWidget(left_card, mini_w, mini_h)
                else
                    left_img = self.plugin:getDimmedCardWidget(
                        left_card, mini_w, mini_h,
                        left_data.is_reversed and 180 or 0
                    )
                end
                left_img = TappableImageContainer:new{
                    content = left_img,
                    callback = function() reopenAt(self.current_index - 1) end,
                }
            end
            if has_right then
                if self.current_index + 1 > revealed_count then
                    -- O próximo verso funciona como a própria ação de revelação.
                    -- Isso elimina o botão inferior e mantém a interação ligada à
                    -- carta que será aberta.
                    right_img = TappableImageContainer:new{
                        content = self.plugin:getBackCardImageWidget(mini_w, mini_h, use_lenormand),
                        callback = revealNextCard,
                        hold_callback = revealAllCards,
                    }
                else
                    local right_data = self.cards[self.current_index + 1]
                    local right_card = right_data.card
                    if use_lenormand then
                        right_img = self.plugin:getCardImageWidget(right_card, mini_w, mini_h)
                    else
                        right_img = self.plugin:getDimmedCardWidget(
                            right_card, mini_w, mini_h,
                            right_data.is_reversed and 180 or 0
                        )
                    end
                    right_img = TappableImageContainer:new{
                        content = right_img,
                        callback = function() reopenAt(self.current_index + 1) end,
                    }
                end
            end

            local hgroup = HorizontalGroup:new{ align = "center" }

            if has_left then
                local left_padding = half_remaining - mini_w - spacing
                if left_padding < 0 then left_padding = 0 end
                table.insert(hgroup, HorizontalSpan:new{ width = left_padding })
                table.insert(hgroup, left_img)
                table.insert(hgroup, HorizontalSpan:new{ width = spacing })
            else
                table.insert(hgroup, HorizontalSpan:new{ width = half_remaining })
            end

            table.insert(hgroup, center_img)

            if has_right then
                local right_padding = half_remaining - mini_w - spacing
                if right_padding < 0 then right_padding = 0 end
                table.insert(hgroup, HorizontalSpan:new{ width = spacing })
                table.insert(hgroup, right_img)
                table.insert(hgroup, HorizontalSpan:new{ width = right_padding })
            else
                table.insert(hgroup, HorizontalSpan:new{ width = half_remaining })
            end

            card_image = hgroup
        else
            local single_image = self.plugin:getCardImageWidget(
                card, nil, nil,
                (is_reversed and not use_lenormand) and 180 or 0
            )
            card_image = TappableImageContainer:new{
                content = single_image,
                callback = function()
                    UIManager:show(ZoomCardDialog:new{
                        plugin = self.plugin,
                        card = card,
                        deck_is_lenormand = use_lenormand,
                        is_reversed = is_reversed,
                    })
                    setTarotDirty(self.plugin or self)
                end,
            }
        end

        local name_w
        if not hide_name then
            local name_text = T(card.name)
            if is_reversed and not use_lenormand and self.plugin.show_reversed_label ~= false then
                name_text = name_text .. " (" .. self.plugin:getTranslation("reversed") .. ")"
            end
            name_w = TextWidget:new{
                text      = name_text,
                face      = Font:getFace("cfont"),
                bold      = true,
                max_width = iw,
                alignment = "center",
            }
        end

        local keywords_w
        if card.keywords then
            keywords_w = makeMutedText(T(card.keywords), math.floor(iw * 0.82))
        end

        local function makeDialogDivider()
            return TextWidget:new{
                text      = "─ ─ ─ ─ ─ ─ ─ ─",
                face      = Font:getFace("x_smallinfofont"),
                fgcolor   = Blitbuffer.gray(0.5),
                max_width = iw,
                alignment = "center",
            }
        end

        local current_orientation = (is_reversed and not use_lenormand) and "reversed" or "upright"
        local base_meaning_text
        if use_lenormand then
            base_meaning_text = T(card.meaning)
        else
            base_meaning_text = is_reversed and T(card.reversed_meaning) or T(card.meaning)
        end

        local custom_meaning_entries = {}
        if meaning_mode == "full" then
            custom_meaning_entries = self.plugin:getCustomMeaningsForCard(
                card,
                use_lenormand,
                current_orientation
            )
        end
        local has_custom_meanings = #custom_meaning_entries > 0
        local show_only_custom = meaning_mode == "full"
            and has_custom_meanings
            and self.plugin.show_only_custom_meanings == true

        local meaning_text
        if show_only_custom then
            meaning_text = self.plugin:formatCustomMeaningEntries(custom_meaning_entries, false)
        else
            meaning_text = base_meaning_text
            if meaning_mode == "summary" then
                meaning_text = summarizeCardMeaning(meaning_text, 180)
            elseif meaning_mode == "full" and has_custom_meanings then
                meaning_text = journalTrim(table.concat({
                    meaning_text,
                    self.plugin:getTranslation("personal_meanings") .. ":",
                    self.plugin:formatCustomMeaningEntries(custom_meaning_entries, false),
                }, "\n\n"))
            end
        end

        local meaning_face_name = "cfont"
        local configured_meaning_size = is_spread_view and self.plugin.meaning_text_size or "standard"
        if configured_meaning_size == "compact" then
            meaning_face_name = "smallinfofont"
        elseif configured_meaning_size == "large" then
            -- smalltfont amplia de forma moderada sem tornar textos longos
            -- impraticáveis em telas pequenas.
            meaning_face_name = "smalltfont"
        end

        local should_scroll_meaning = meaning_mode == "full"
            and (has_custom_meanings or #meaning_text > 520 or meaning_text:find("\n"))
        local meaning_h = math.floor(layout.safe_h * 0.24)
        if total_cards > 1 then
            meaning_h = math.floor(layout.safe_h * 0.21)
        end
        if meaning_h < 110 then meaning_h = 110 end
        if meaning_h > math.floor(layout.safe_h * 0.34) then
            meaning_h = math.floor(layout.safe_h * 0.34)
        end

        local meaning_w
        if should_scroll_meaning then
            meaning_w = ScrollTextWidget:new{
                text = meaning_text,
                face = Font:getFace(meaning_face_name),
                width = iw,
                height = meaning_h,
                alignment = "left",
                scroll_by_pan = true,
                dialog = self,
            }
        else
            meaning_w = TextBoxWidget:new{
                text      = meaning_text,
                face      = Font:getFace(meaning_face_name),
                width     = iw,
                alignment = "center",
            }
        end

        local meaning_label_text = self.plugin:getTranslation("meaning_label")
        if show_only_custom then
            meaning_label_text = self.plugin:getTranslation("personal_meanings")
        elseif is_reversed and not use_lenormand then
            meaning_label_text = self.plugin:getTranslation("reversed_meaning_label")
        end
        local meaning_label_w = TextWidget:new{
            text      = "— " .. meaning_label_text .. " —",
            face      = Font:getFace("smalltfont"),
            bold      = true,
            max_width = iw,
            alignment = "center",
        }

        -- A navegação é feita tocando as miniaturas laterais; os antigos
        -- botões < e > foram removidos para liberar espaço no Kindle.

        local was_auto_saved = self.auto_save_state == "saved"
        local was_manually_saved = self.manual_save_state == "saved"
        local can_save_reading = not self.hidden_grid_view
            and not self.read_only
            and not has_unrevealed_cards
            and not was_auto_saved
        local can_view_in_book = not self.read_only and not self.plugin.disable_view_in_book

        local function closeCardDialogNow()
            UIManager:close(self)
            setTarotDirty(self.plugin or self)
            if self.on_close then self.on_close() end
        end

        local function requestCloseCardDialog()
            local should_warn = is_spread_view
                and not self.hidden_grid_view
                and not has_unrevealed_cards
                and not was_auto_saved
                and not was_manually_saved
                and self.plugin.disable_unsaved_close_warning ~= true

            if not should_warn then
                closeCardDialogNow()
                return
            end

            local warning
            warning = ConfirmBox:new{
                text = self.plugin:getTranslation("unsaved_close_warning"),
                ok_text = self.plugin:getTranslation("close_without_saving"),
                cancel_text = self.plugin:getTranslation("continue_reading"),
                ok_callback = function()
                    UIManager:close(warning)
                    closeCardDialogNow()
                end,
            }
            UIManager:show(warning)
        end

        local body = VerticalGroup:new{ align = "center" }

        if reveal_progress_w then
            table.insert(body, reveal_progress_w)
            table.insert(body, VerticalSpan:new{ width = Size.span.vertical_default })
        end

        table.insert(body, card_image)
        table.insert(body, VerticalSpan:new{ width = Size.span.vertical_default })

        if name_w then
            table.insert(body, name_w)
            table.insert(body, VerticalSpan:new{ width = Size.span.vertical_small })
        end

        if show_meaning then
            table.insert(body, VerticalSpan:new{ width = Size.span.vertical_large })
            table.insert(body, meaning_label_w)
            table.insert(body, VerticalSpan:new{ width = Size.span.vertical_small })
            table.insert(body, meaning_w)
        end

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            header = header_w,
            body = body,
        }

        local card_pin_item = self.plugin:makeCardPinItem(card, use_lenormand)
        local function showCurrentCardDialog()
            UIManager:show(CardDialog:new{
                cards = self.cards,
                current_index = self.current_index,
                card_labels = self.card_labels,
                revealed_count = self.revealed_count,
                on_new = self.on_new,
                plugin = self.plugin,
                title_label = self.title_label,
                is_daily = self.is_daily,
                read_only = self.read_only,
                deck_is_lenormand = self.deck_is_lenormand,
                on_close = self.on_close,
                auto_save_state = self.auto_save_state,
                manual_save_state = self.manual_save_state,
                hidden_grid_view = self.hidden_grid_view,
            })
            setTarotDirty(self.plugin or self)
        end
        local function reopenCurrentCardDialog()
            UIManager:close(self)
            showCurrentCardDialog()
        end

        local overlay_buttons = {
            makeTopBackIconButton(self.plugin, layout, requestCloseCardDialog),
        }
        local top_slot = 0
        if card_pin_item then
            local is_pinned = self.plugin:isPinnedItem(card_pin_item)
            table.insert(overlay_buttons, makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = is_pinned and "pin-filled" or "pin",
                fallback_text = is_pinned and "●" or "○",
                side = "left",
                slot = 1,
                callback = function()
                    self.plugin:togglePinnedItem(card_pin_item)
                    reopenCurrentCardDialog()
                end,
            })
        end
        if can_save_reading then
            table.insert(overlay_buttons, makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = was_manually_saved and "check-square" or "add-square",
                fallback_text = was_manually_saved and "✓" or "+",
                slot = top_slot,
                callback = (not was_manually_saved) and function()
                    setTarotDirty(self.plugin or self)
                    self.plugin:showSaveTitleInput(self.cards, self.is_daily and "daily" or "spread", function()
                        self.manual_save_state = "saved"
                        reopenCurrentCardDialog()
                    end)
                end or nil,
            })
            top_slot = top_slot + 1
        end
        if can_view_in_book then
            table.insert(overlay_buttons, makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = "book-open",
                fallback_text = self.plugin:getTranslation("view_in_book"),
                slot = top_slot,
                callback = function()
                    self.plugin:showCardInBook(card, use_lenormand)
                end,
            })
        end

        if #overlay_buttons > 0 then
            local layers = {
                dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
                fullscreen_scaffold,
            }
            for _, overlay_button in ipairs(overlay_buttons) do
                table.insert(layers, overlay_button)
            end
            self[1] = OverlapGroup:new(layers)
        else
            self[1] = fullscreen_scaffold
        end

        addHorizontalSwipeNavigation(self, "tarot_card_dialog_swipe_nav",
            self.current_index > 1 and function()
                reopenAt(self.current_index - 1)
            end or nil,
            self.current_index < revealed_count and function()
                reopenAt(self.current_index + 1)
            end or (has_unrevealed_cards and revealNextCard or nil)
        )

        if total_cards > 1 and is_spread_view then
            if has_unrevealed_cards then
                UIManager:scheduleIn(0.1, function()
                    self.plugin:showNextCardRevealHint()
                end)
            else
                -- A orientação sobre navegar pelas miniaturas reveladas só aparece
                -- quando toda a tiragem estiver aberta.
                UIManager:scheduleIn(0.1, function()
                    self.plugin:showCardDialogNavigationHint()
                end)
            end
        end
    end


    return CardDialog
end

return M

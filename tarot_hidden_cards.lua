-- Carta Oculta: grade 4x4, revelação, nomes de posição, mover/excluir/desfazer.

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local OverlapGroup = require("ui/widget/overlapgroup")
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
    local CardDialog = assert(deps.CardDialog, "CardDialog is required")
    local TappableImageContainer = assert(deps.TappableImageContainer, "TappableImageContainer is required")
    local POSITION_NAME_PRESETS = assert(deps.POSITION_NAME_PRESETS, "POSITION_NAME_PRESETS is required")
    local trimPositionName = assert(deps.trimPositionName, "trimPositionName is required")
    local makeStoredPresetPositionName = assert(deps.makeStoredPresetPositionName, "makeStoredPresetPositionName is required")
    local makeStoredCustomPositionName = assert(deps.makeStoredCustomPositionName, "makeStoredCustomPositionName is required")
    local getPositionNameDisplay = assert(deps.getPositionNameDisplay, "getPositionNameDisplay is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local makeSectionHeader = assert(deps.makeSectionHeader, "makeSectionHeader is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local makeFloatingIconButton = assert(deps.makeFloatingIconButton, "makeFloatingIconButton is required")
    local makeTopBackIconButton = assert(deps.makeTopBackIconButton, "makeTopBackIconButton is required")
    local getTarotBaseButtonRadius = assert(deps.getTarotBaseButtonRadius, "getTarotBaseButtonRadius is required")
    local getTarotButtonRadius = assert(deps.getTarotButtonRadius, "getTarotButtonRadius is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

    local HiddenCardDialog

    -- ╔══════════════════════════════════════════════════════════════════════════════╗
    -- ║ CARTA OCULTA — GRADE FIXA 4×4, INSERÇÃO DIRETA E ORGANIZAÇÃO POR TOQUE      ║
    -- ╚══════════════════════════════════════════════════════════════════════════════╝
    HiddenCardDialog = InputContainer:extend{
        plugin = nil,
        cards = nil,
        position_names = nil,
        on_new = nil,
        is_daily = false,
        on_reveal = nil,
        title_label = nil,
        allow_add_card = false,
        max_cards = 16,
        deck_is_lenormand = nil,
        read_only = false,
        on_close = nil,
        selected_action_index = nil,
        moving_index = nil,
        show_opening_hint = false,
        manual_save_state = nil,
        pending_deleted_card = nil,
    }

    function HiddenCardDialog:init()
        local layout = getFullscreenLayout(0.96)
        local iw = layout.content_w

        self.cards = self.cards or {}
        self.position_names = self.position_names or {}
        self.max_cards = math.max(1, math.min(16, tonumber(self.max_cards) or 16))
        if self.read_only or self.is_daily then
            self.pending_deleted_card = nil
        end

        -- Mantém apenas nomes válidos associados às 16 posições fixas.
        local normalized_position_names = {}
        for slot, stored_name in pairs(self.position_names) do
            slot = tonumber(slot)
            stored_name = trimPositionName(stored_name)
            if slot and slot >= 1 and slot <= 16 and stored_name ~= "" then
                normalized_position_names[slot] = stored_name
            end
        end
        self.position_names = normalized_position_names

        local use_lenormand = self.deck_is_lenormand
        if use_lenormand == nil then
            use_lenormand = self.plugin.use_lenormand == true
        end

        local header_title = self.title_label or self.plugin:getTranslation("draw_cards")

        for _, item in ipairs(self.cards) do
            if item.is_revealed == nil then item.is_revealed = false end
        end

        -- Nas tiragens livres, cada carta ocupa uma das 16 posições fixas. Isso
        -- permite iniciar com zero cartas e montar cruzes, linhas ou diagonais sem
        -- que o tamanho e a posição das cartas existentes mudem.
        local function normalizeGridSlots()
            if self.is_daily then return end
            local used = {}
            for _, item in ipairs(self.cards) do
                local slot = tonumber(item.grid_slot)
                if slot and slot >= 1 and slot <= 16 and not used[slot] then
                    item.grid_slot = slot
                    used[slot] = true
                else
                    item.grid_slot = nil
                end
            end
            for _, item in ipairs(self.cards) do
                if not item.grid_slot then
                    for slot = 1, 16 do
                        if not used[slot] then
                            item.grid_slot = slot
                            used[slot] = true
                            break
                        end
                    end
                end
            end
        end
        normalizeGridSlots()

        local function markReadingChanged()
            -- Qualquer alteração depois de um salvamento manual torna a grade
            -- novamente diferente do registro salvo no Diário.
            self.manual_save_state = nil
        end

        local function allCardsRevealed()
            if #self.cards == 0 then return false end
            for _, item in ipairs(self.cards) do
                if item.is_revealed ~= true then return false end
            end
            return true
        end

        local function orderedCardsForReading()
            local ordered = {}
            for _, item in ipairs(self.cards) do
                local slot = tonumber(item.grid_slot)
                table.insert(ordered, {
                    card = item.card,
                    is_reversed = item.is_reversed == true,
                    is_revealed = item.is_revealed == true,
                    grid_slot = slot,
                    position_name = slot and self.position_names[slot] or nil,
                })
            end
            if not self.is_daily then
                table.sort(ordered, function(a, b)
                    return (tonumber(a.grid_slot) or 99) < (tonumber(b.grid_slot) or 99)
                end)
            end
            ordered.position_names = {}
            for slot, stored_name in pairs(self.position_names) do
                ordered.position_names[slot] = stored_name
            end
            return ordered
        end

        local function refreshHiddenDialog()
            UIManager:close(self)
            UIManager:show(HiddenCardDialog:new{
                plugin = self.plugin,
                cards = self.cards,
                position_names = self.position_names,
                on_new = self.on_new,
                is_daily = self.is_daily,
                on_reveal = self.on_reveal,
                title_label = self.title_label,
                allow_add_card = self.allow_add_card,
                max_cards = self.max_cards,
                deck_is_lenormand = use_lenormand,
                read_only = self.read_only,
                on_close = self.on_close,
                selected_action_index = self.selected_action_index,
                moving_index = self.moving_index,
                manual_save_state = self.manual_save_state,
                pending_deleted_card = self.pending_deleted_card,
                -- O aviso pertence à abertura da tiragem, nunca às reconstruções
                -- internas causadas por revelar, mover, excluir ou adicionar cartas.
                show_opening_hint = false,
            })
            setTarotDirty(self.plugin or self)
        end

        local function clearTransientSelection()
            self.selected_action_index = nil
            self.moving_index = nil
        end

        local function clearPendingDeletedCard()
            self.pending_deleted_card = nil
        end

        local function slotIsOccupied(slot)
            for index, item in ipairs(self.cards) do
                if tonumber(item.grid_slot) == slot then return true, index end
            end
            return false, nil
        end

        local function findFirstEmptySlot()
            for slot = 1, 16 do
                local occupied = slotIsOccupied(slot)
                if not occupied then return slot end
            end
            return nil
        end

        local function restorePendingDeletedCard()
            if self.read_only or self.is_daily or not self.pending_deleted_card then return end
            if #self.cards >= self.max_cards then
                clearPendingDeletedCard()
                refreshHiddenDialog()
                return
            end

            local pending = self.pending_deleted_card
            local slot = tonumber(pending.grid_slot)
            if not slot or slot < 1 or slot > 16 or slotIsOccupied(slot) then
                slot = findFirstEmptySlot()
            end
            if not slot then
                clearPendingDeletedCard()
                refreshHiddenDialog()
                return
            end

            local restored_card = {
                card = pending.card,
                is_reversed = pending.is_reversed == true,
                is_revealed = pending.is_revealed == true,
                grid_slot = slot,
            }
            local restore_index = tonumber(pending.index) or (#self.cards + 1)
            restore_index = math.max(1, math.min(#self.cards + 1, restore_index))

            table.insert(self.cards, restore_index, restored_card)
            clearPendingDeletedCard()
            markReadingChanged()
            clearTransientSelection()
            normalizeGridSlots()
            refreshHiddenDialog()
        end

        local function addCardAtSlot(slot)
            if self.read_only or self.is_daily or not self.allow_add_card then return end
            if self.selected_action_index or self.moving_index then return end
            if #self.cards >= self.max_cards then return end
            local occupied = slotIsOccupied(slot)
            if occupied then return end

            local new_card = self.plugin:drawAdditionalUniqueCard(self.cards)
            if not new_card then return end
            clearPendingDeletedCard()
            new_card.is_revealed = self.plugin.spread_cards_always_revealed == true
            new_card.grid_slot = slot
            table.insert(self.cards, new_card)
            markReadingChanged()
            refreshHiddenDialog()
        end

        local function deleteCard(index)
            if self.read_only or self.is_daily or not self.cards[index] then return end
            local removed_card = table.remove(self.cards, index)
            self.pending_deleted_card = {
                card = removed_card.card,
                is_reversed = removed_card.is_reversed == true,
                is_revealed = removed_card.is_revealed == true,
                grid_slot = tonumber(removed_card.grid_slot),
                index = index,
            }
            markReadingChanged()
            clearTransientSelection()
            normalizeGridSlots()
            refreshHiddenDialog()
        end

        local function openRevealedCard(source_item)
            local revealed_cards = {}
            local dialog_index = nil
            for _, item in ipairs(orderedCardsForReading()) do
                if item.is_revealed == true then
                    table.insert(revealed_cards, item)
                    if tonumber(item.grid_slot) == tonumber(source_item.grid_slot) then
                        dialog_index = #revealed_cards
                    end
                end
            end
            if not dialog_index or #revealed_cards == 0 then return end

            local cleared_pending_before_open = self.pending_deleted_card ~= nil
            clearPendingDeletedCard()
            UIManager:show(CardDialog:new{
                cards = revealed_cards,
                current_index = dialog_index,
                plugin = self.plugin,
                title_label = self.title_label or self.plugin:getTranslation("draw_cards"),
                is_daily = false,
                read_only = self.read_only,
                deck_is_lenormand = use_lenormand,
                hidden_grid_view = true,
                on_close = function()
                    setTarotDirty(self.plugin or self)
                    if cleared_pending_before_open then
                        UIManager:scheduleIn(0.05, function()
                            refreshHiddenDialog()
                        end)
                    end
                end,
            })
            setTarotDirty(self.plugin or self)
        end

        local function tapCard(index)
            local item = self.cards[index]
            if not item then return end

            -- Enquanto o menu de uma carta está aberto, somente as ações desse menu
            -- são aceitas. Isso evita revelar ou adicionar cartas por acidente.
            if self.selected_action_index then return end

            if self.read_only then
                if item.is_revealed == true then openRevealedCard(item) end
                return
            end

            if self.moving_index then
                clearPendingDeletedCard()
                if self.moving_index == index then
                    self.moving_index = nil
                else
                    local source = self.cards[self.moving_index]
                    if source then
                        source.grid_slot, item.grid_slot = item.grid_slot, source.grid_slot
                        markReadingChanged()
                    end
                    self.moving_index = nil
                end
                refreshHiddenDialog()
                return
            end

            if self.is_daily and item.is_revealed ~= true then
                UIManager:close(self)
                setTarotDirty(self.plugin or self)
                if self.on_reveal then self.on_reveal() end
                return
            end

            if item.is_revealed == true then
                openRevealedCard(item)
            else
                clearPendingDeletedCard()
                item.is_revealed = true
                markReadingChanged()
                refreshHiddenDialog()
            end
        end

        local function tapEmptySlot(slot)
            if self.read_only or self.is_daily then return end
            if self.selected_action_index then return end

            if self.moving_index then
                clearPendingDeletedCard()
                local source = self.cards[self.moving_index]
                if source then
                    source.grid_slot = slot
                    markReadingChanged()
                end
                self.moving_index = nil
                refreshHiddenDialog()
                return
            end

            addCardAtSlot(slot)
        end

        local function holdCard(index)
            if self.read_only or self.is_daily or not self.cards[index] then return end
            clearPendingDeletedCard()
            self.selected_action_index = index
            self.moving_index = nil
            refreshHiddenDialog()
        end

        local function showPositionNamePopup(slot)
            if self.read_only or self.is_daily then return end
            slot = tonumber(slot)
            if not slot or slot < 1 or slot > 16 then return end
            clearPendingDeletedCard()

            local position_dialog

            local function finishPositionNaming(stored_name)
                if position_dialog then UIManager:close(position_dialog) end
                stored_name = trimPositionName(stored_name)
                self.position_names[slot] = stored_name ~= "" and stored_name or nil
                markReadingChanged()
                clearTransientSelection()
                refreshHiddenDialog()
            end

            local function cancelPositionNaming()
                if position_dialog then UIManager:close(position_dialog) end
                clearTransientSelection()
                refreshHiddenDialog()
            end

            local function openCustomPositionInput()
                if position_dialog then UIManager:close(position_dialog) end
                local current_display = getPositionNameDisplay(self.plugin, self.position_names[slot])
                local input_dialog
                input_dialog = InputDialog:new{
                    title = self.plugin:getTranslation("custom_position_name"),
                    input = current_display,
                    input_hint = self.plugin:getTranslation("custom_position_name_hint"),
                    input_type = "string",
                    buttons = {
                        {
                            {
                                text = self.plugin:getTranslation("cancel"),
                                callback = function()
                                    UIManager:close(input_dialog)
                                    clearTransientSelection()
                                    refreshHiddenDialog()
                                end,
                            },
                            {
                                text = self.plugin:getTranslation("confirm"),
                                is_enter_default = true,
                                callback = function()
                                    local custom_name = trimPositionName(input_dialog:getInputText())
                                    UIManager:close(input_dialog)
                                    self.position_names[slot] = custom_name ~= ""
                                        and makeStoredCustomPositionName(custom_name) or nil
                                    markReadingChanged()
                                    clearTransientSelection()
                                    refreshHiddenDialog()
                                end,
                            },
                        },
                    },
                }
                UIManager:show(input_dialog)
                input_dialog:onShowKeyboard()
            end

            local buttons = {}
            for index = 1, #POSITION_NAME_PRESETS, 2 do
                local row = {}
                for offset = 0, 1 do
                    local preset = POSITION_NAME_PRESETS[index + offset]
                    if preset then
                        local preset_id = preset.id
                        local preset_key = preset.key
                        table.insert(row, {
                            text = self.plugin:getTranslation(preset_key),
                            callback = function()
                                finishPositionNaming(makeStoredPresetPositionName(preset_id))
                            end,
                        })
                    end
                end
                table.insert(buttons, row)
            end

            table.insert(buttons, {
                {
                    text = self.plugin:getTranslation("custom_position_name"),
                    callback = openCustomPositionInput,
                },
            })

            if self.position_names[slot] then
                table.insert(buttons, {
                    {
                        text = self.plugin:getTranslation("remove_position_name"),
                        callback = function() finishPositionNaming(nil) end,
                    },
                })
            end

            table.insert(buttons, {
                {
                    text = self.plugin:getTranslation("cancel"),
                    callback = cancelPositionNaming,
                },
            })

            position_dialog = ButtonDialog:new{
                title = self.plugin:getTranslation("position_name_title"),
                title_align = "center",
                width_factor = 0.72,
                buttons = buttons,
                tap_close_callback = function()
                    clearTransientSelection()
                    UIManager:scheduleIn(0.05, function()
                        refreshHiddenDialog()
                    end)
                end,
            }
            UIManager:show(position_dialog)
            setTarotDirty(self.plugin or self)
        end

        local function holdEmptySlot(slot)
            if self.read_only or self.is_daily then return end
            if self.moving_index then return end
            showPositionNamePopup(slot)
        end

        local function shouldShowPendingDeleteUndo()
            return self.pending_deleted_card ~= nil
                and not self.read_only
                and not self.is_daily
                and not self.selected_action_index
                and not self.moving_index
        end

        local function shouldShowSaveStateIcon()
            return allCardsRevealed()
                and not self.read_only
                and not self.is_daily
        end

        local function makePendingDeleteUndoOverlay()
            return makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = "undo",
                fallback_text = self.plugin:getTranslation("undo_action"),
                slot = 0,
                callback = restorePendingDeletedCard,
            }
        end

        local header_w = makeSectionHeader(header_title, iw)

        local function closeHiddenNow()
            UIManager:close(self)
            setTarotDirty(self.plugin or self)
            if self.on_close then self.on_close() end
        end

        local function closeHidden()
            local complete = allCardsRevealed()
            local ordered_cards = orderedCardsForReading()

            local was_manually_saved = self.manual_save_state == "saved"

            if complete and self.plugin.auto_save_spreads == true and not was_manually_saved then
                if self.plugin:autoSaveReading(ordered_cards) then
                    closeHiddenNow()
                else
                    UIManager:show(InfoMessage:new{
                        text = self.plugin:getTranslation("journal_save_error"),
                    })
                end
                return
            end

            local should_warn = complete
                and not was_manually_saved
                and self.plugin.auto_save_spreads ~= true
                and self.plugin.disable_unsaved_close_warning ~= true

            if not should_warn then
                closeHiddenNow()
                return
            end

            local warning
            warning = ConfirmBox:new{
                text = self.plugin:getTranslation("unsaved_close_warning"),
                ok_text = self.plugin:getTranslation("close_without_saving"),
                cancel_text = self.plugin:getTranslation("continue_reading"),
                ok_callback = function()
                    UIManager:close(warning)
                    closeHiddenNow()
                end,
            }
            UIManager:show(warning)
        end

        local function requestHiddenBack()
            if self.is_daily or self.read_only then
                closeHiddenNow()
            else
                closeHidden()
            end
        end

        local gap_x = math.max(4, math.floor(iw * 0.012))
        local gap_y = math.max(4, math.floor(layout.safe_h * 0.006))
        local header_h = header_w:getSize().h
        local grid_footer_gap = math.max(Size.span.vertical_default, gap_y * 2)
        local available_grid_h = layout.safe_h - header_h - grid_footer_gap
        if available_grid_h < 80 then available_grid_h = 80 end

        local ratio = use_lenormand and 1 or (439 / 250)
        local card_w
        local card_h
        local grid

        local function makeActionMenu(index, width, height)
            local item = self.cards[index]
            local action_count = item and item.is_revealed == true and 5 or 4
            local menu_w = width
            -- Mantém o box e as áreas de toque compactos. O destaque visual vem
            -- apenas da fonte maior, não de botões ou bordas mais grossos.
            local menu_h = math.max(54, math.floor(height * 0.82))
            if menu_h > height then menu_h = height end
            local outer_pad = math.max(2, Size.padding.tiny)
            local button_gap = math.max(0, math.floor(height * 0.004))
            local inner_h = math.max(1, menu_h - outer_pad * 2)
            local button_h = math.max(1, math.floor((inner_h - button_gap * (action_count - 1)) / action_count))
            local font_size = math.max(8, math.min(
                18,
                math.floor(width / 5.8),
                math.floor(button_h * 0.70)
            ))

            local function largeTextActionButton(text, callback)
                return Button:new{
                    text = text,
                    width = math.max(24, menu_w - outer_pad * 2),
                    height = button_h,
                    bordersize = 0,
                    margin = 0,
                    padding = 0,
                    padding_h = 0,
                    padding_v = 0,
                    background = nil,
                    radius = 0,
                    text_font_face = "x_smallinfofont",
                    text_font_size = font_size,
                    text_font_bold = true,
                    callback = callback,
                }
            end

            local menu_content = VerticalGroup:new{ align = "center" }
            local slot = item and tonumber(item.grid_slot)
            local position_button_text = slot
                and getPositionNameDisplay(self.plugin, self.position_names[slot]) or ""
            if position_button_text == "" then
                position_button_text = self.plugin:getTranslation("name_position")
            end

            -- A nomeação ocupa sempre o topo. Depois da escolha, o próprio nome da
            -- posição substitui o texto genérico "Nomear posição".
            table.insert(menu_content, largeTextActionButton(position_button_text, function()
                if slot then showPositionNamePopup(slot) end
            end))
            table.insert(menu_content, VerticalSpan:new{ width = button_gap })

            table.insert(menu_content, largeTextActionButton(self.plugin:getTranslation("move_card"), function()
                clearPendingDeletedCard()
                self.moving_index = index
                self.selected_action_index = nil
                refreshHiddenDialog()
            end))
            table.insert(menu_content, VerticalSpan:new{ width = button_gap })

            table.insert(menu_content, largeTextActionButton(self.plugin:getTranslation("delete_card"), function()
                deleteCard(index)
            end))

            if item and item.is_revealed == true then
                table.insert(menu_content, VerticalSpan:new{ width = button_gap })
                table.insert(menu_content, largeTextActionButton(self.plugin:getTranslation("turn_face_down"), function()
                    clearPendingDeletedCard()
                    item.is_revealed = false
                    markReadingChanged()
                    clearTransientSelection()
                    refreshHiddenDialog()
                end))
            end

            table.insert(menu_content, VerticalSpan:new{ width = button_gap })
            table.insert(menu_content, largeTextActionButton(self.plugin:getTranslation("undo_action"), function()
                clearPendingDeletedCard()
                clearTransientSelection()
                refreshHiddenDialog()
            end))

            return FrameContainer:new{
                width = menu_w,
                height = menu_h,
                bordersize = 1,
                radius = getTarotBaseButtonRadius(),
                padding = outer_pad,
                background = Blitbuffer.COLOR_WHITE,
                CenterContainer:new{
                    dimen = Geom:new{ w = menu_w - outer_pad * 2, h = menu_h - outer_pad * 2 },
                    menu_content,
                },
            }
        end

        local function makeMoveInstructionMenu(index, width, height)
            local menu_w = width
            local menu_h = math.max(58, math.floor(height * 0.82))
            if menu_h > height then menu_h = height end
            local outer_pad = math.max(3, Size.padding.tiny)
            local gap = math.max(3, math.floor(height * 0.025))
            local undo_h = math.max(22, math.floor(menu_h * 0.30))
            local text_h = math.max(18, menu_h - undo_h - gap - outer_pad * 2)
            local font_size = math.max(9, math.min(15, math.floor(width / 7.0)))

            local instruction = TextBoxWidget:new{
                text = self.plugin:getTranslation("tap_another_location_to_move"),
                face = Font:getFace("x_smallinfofont", font_size),
                bold = true,
                width = math.max(20, menu_w - outer_pad * 2),
                height = text_h,
                alignment = "center",
            }

            local undo_font_size = math.max(9, math.min(
                18,
                math.floor(width / 5.8),
                math.floor(undo_h * 0.72)
            ))
            local undo_button = Button:new{
                text = self.plugin:getTranslation("undo_action"),
                width = math.max(24, menu_w - outer_pad * 2),
                height = undo_h,
                bordersize = 0,
                margin = 0,
                padding = 0,
                padding_h = 0,
                padding_v = 0,
                background = nil,
                radius = 0,
                text_font_face = "x_smallinfofont",
                text_font_size = undo_font_size,
                text_font_bold = true,
                callback = function()
                    clearPendingDeletedCard()
                    clearTransientSelection()
                    refreshHiddenDialog()
                end,
            }

            return FrameContainer:new{
                width = menu_w,
                height = menu_h,
                bordersize = 1,
                radius = getTarotBaseButtonRadius(),
                padding = outer_pad,
                background = Blitbuffer.COLOR_WHITE,
                CenterContainer:new{
                    dimen = Geom:new{ w = menu_w - outer_pad * 2, h = menu_h - outer_pad * 2 },
                    VerticalGroup:new{
                        align = "center",
                        instruction,
                        VerticalSpan:new{ width = gap },
                        undo_button,
                    },
                },
            }
        end

        local function makeCardVisual(index, width, height)
            local item = self.cards[index]
            local visual
            if item.is_revealed == true then
                visual = self.plugin:getCardImageWidget(
                    item.card,
                    width,
                    height,
                    (item.is_reversed and not use_lenormand) and 180 or 0
                )
            else
                visual = self.plugin:getBackCardImageWidget(width, height, use_lenormand)
            end

            local card_touch = TappableImageContainer:new{
                content = visual,
                callback = function() tapCard(index) end,
                hold_callback = (not self.is_daily and not self.read_only)
                    and function() holdCard(index) end or nil,
            }

            if self.selected_action_index ~= index and self.moving_index ~= index then
                return card_touch
            end

            -- A carta continua visível por baixo; o menu arredondado é pintado por
            -- cima sem borda preta de seleção, exatamente no mesmo espaço da carta.
            -- Enquanto qualquer um dos dois boxes está aberto, a imagem deixa de ser
            -- uma camada tocável, para que somente os botões recebam os eventos.
            local overlay_menu
            if self.moving_index == index then
                overlay_menu = makeMoveInstructionMenu(index, width, height)
            else
                overlay_menu = makeActionMenu(index, width, height)
            end

            return OverlapGroup:new{
                dimen = Geom:new{ w = width, h = height },
                visual,
                CenterContainer:new{
                    dimen = Geom:new{ w = width, h = height },
                    overlay_menu,
                },
            }
        end

        if self.is_daily then
            local count = math.max(1, #self.cards)
            card_w = math.min(math.floor(iw * 0.52), math.floor(available_grid_h / ratio))
            card_w = math.max(36, card_w)
            card_h = math.max(36, math.floor(card_w * ratio))
            local row = HorizontalGroup:new{ align = "center" }
            for index = 1, count do
                table.insert(row, makeCardVisual(index, card_w, card_h))
                if index < count then table.insert(row, HorizontalSpan:new{ width = gap_x }) end
            end
            grid = CenterContainer:new{
                dimen = Geom:new{ w = iw, h = available_grid_h },
                row,
            }
        else
            local columns, rows = 4, 4
            local max_w_by_width = math.floor((iw - gap_x * (columns - 1)) / columns)
            local max_h_per_card = math.floor((available_grid_h - gap_y * (rows - 1)) / rows)
            local max_w_by_height = math.floor(max_h_per_card / ratio)
            card_w = math.max(36, math.min(max_w_by_width, max_w_by_height))
            card_h = math.max(36, math.floor(card_w * ratio))

            local slot_to_index = {}
            for index, item in ipairs(self.cards) do
                local slot = tonumber(item.grid_slot)
                if slot and slot >= 1 and slot <= 16 then slot_to_index[slot] = index end
            end

            grid = VerticalGroup:new{ align = "center" }
            for row = 1, rows do
                local row_widget = HorizontalGroup:new{ align = "center" }
                for column = 1, columns do
                    local slot = (row - 1) * columns + column
                    local card_index = slot_to_index[slot]
                    if card_index then
                        table.insert(row_widget, makeCardVisual(card_index, card_w, card_h))
                    else
                        local placeholder = FrameContainer:new{
                            width = card_w,
                            height = card_h,
                            bordersize = 1,
                            radius = getTarotBaseButtonRadius(),
                            padding = 0,
                            background = Blitbuffer.COLOR_WHITE,
                            CenterContainer:new{
                                dimen = Geom:new{ w = card_w, h = card_h },
                                TextWidget:new{
                                    text = "",
                                    face = Font:getFace("x_smallinfofont"),
                                },
                            },
                        }
                        table.insert(row_widget, TappableImageContainer:new{
                            content = placeholder,
                            callback = function() tapEmptySlot(slot) end,
                            hold_callback = (not self.read_only)
                                and function() holdEmptySlot(slot) end or nil,
                        })
                    end
                    if column < columns then table.insert(row_widget, HorizontalSpan:new{ width = gap_x }) end
                end
                table.insert(grid, CenterContainer:new{
                    dimen = Geom:new{ w = iw, h = card_h },
                    row_widget,
                })
                if row < rows then table.insert(grid, VerticalSpan:new{ width = gap_y }) end
            end
        end

        local grid_area = self.is_daily and grid or CenterContainer:new{
            dimen = Geom:new{ w = iw, h = available_grid_h },
            grid,
        }

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            header = header_w,
            body = grid_area,
        }

        local overlay_buttons = {
            makeTopBackIconButton(self.plugin, layout, requestHiddenBack),
        }
        if shouldShowPendingDeleteUndo() then
            table.insert(overlay_buttons, makePendingDeleteUndoOverlay())
        end
        if shouldShowSaveStateIcon() then
            local is_manually_saved = self.manual_save_state == "saved"
            table.insert(overlay_buttons, makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = is_manually_saved and "check-square" or "add-square",
                fallback_text = is_manually_saved and "✓" or "+",
                slot = shouldShowPendingDeleteUndo() and 1 or 0,
                callback = (not is_manually_saved) and function()
                    clearTransientSelection()
                    setTarotDirty(self.plugin or self)
                    self.plugin:showSaveTitleInput(orderedCardsForReading(), "spread", function()
                        -- Salvar não fecha a grade. O usuário continua olhando a
                        -- tiragem e decide sozinho quando sair.
                        self.manual_save_state = "saved"
                        refreshHiddenDialog()
                    end)
                end or nil,
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

        if not self.is_daily and self.show_opening_hint == true then
            UIManager:scheduleIn(0.1, function()
                self.plugin:showHiddenCardRevealHint()
            end)
        end
    end


    return HiddenCardDialog
end

return M

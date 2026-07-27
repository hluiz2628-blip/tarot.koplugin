-- Significados pessoais: grifos, edição manual e menu rápido por carta.

local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local OverlapGroup = require("ui/widget/overlapgroup")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local logger = require("logger")
local util = require("util")

local M = {}

function M.register(deps)
    deps = deps or {}
    local TarotPlugin = assert(deps.TarotPlugin, "TarotPlugin is required")
    local T = assert(deps.T, "translator is required")
    local FULL_DECK = assert(deps.FULL_DECK, "FULL_DECK is required")
    local LENORMAND_DECK = assert(deps.LENORMAND_DECK, "LENORMAND_DECK is required")
    local FullscreenMenuDialog = assert(deps.FullscreenMenuDialog, "FullscreenMenuDialog is required")
    local journalTrim = assert(deps.journalTrim, "journalTrim is required")
    local journalEscape = assert(deps.journalEscape, "journalEscape is required")
    local journalUnescape = assert(deps.journalUnescape, "journalUnescape is required")
    local journalReadAll = assert(deps.journalReadAll, "journalReadAll is required")
    local journalWriteAll = assert(deps.journalWriteAll, "journalWriteAll is required")
    local journalPreview = assert(deps.journalPreview, "journalPreview is required")
    local journalSafeLower = assert(deps.journalSafeLower, "journalSafeLower is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local makeRoundedButton = assert(deps.makeRoundedButton, "makeRoundedButton is required")
    local makeSettingsCard = assert(deps.makeSettingsCard, "makeSettingsCard is required")
    local makeSectionHeader = assert(deps.makeSectionHeader, "makeSectionHeader is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local makeTopBackIconButton = assert(deps.makeTopBackIconButton, "makeTopBackIconButton is required")
    local getTopIconMetrics = assert(deps.getTopIconMetrics, "getTopIconMetrics is required")
    local getTarotButtonRadius = assert(deps.getTarotButtonRadius, "getTarotButtonRadius is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

    -- ╔══════════════════════════════════════════════════════════════════════════════╗
    -- ║      SEÇÃO 7.1: SIGNIFICADOS PESSOAIS A PARTIR DE GRIFOS                    ║
    -- ╚══════════════════════════════════════════════════════════════════════════════╝
    -- O arquivo fica fora de l10n porque não é tradução: é conteúdo pessoal do
    -- usuário. Cada linha é independente, escapada e tolerante a caracteres UTF-8.
    local CUSTOM_MEANINGS_MAGIC = "TAROT_CUSTOM_MEANINGS_V1"

    local function getDeckStorageId(deck_is_lenormand)
        return deck_is_lenormand and "lenormand" or "tarot"
    end

    local function normalizeMeaningOrientation(orientation, deck_is_lenormand)
        if deck_is_lenormand then return "upright" end
        return orientation == "reversed" and "reversed" or "upright"
    end

    local function titleCaseAsciiWord(word)
        return word:gsub("^%l", string.upper)
    end

    local function normalizeCustomMeaningSourceTitle(title)
        title = journalTrim(tostring(title or ""):gsub("%z", ""))
        if title == "" then return "" end

        -- Quando o KOReader entrega caminho/arquivo em vez de metadado de título,
        -- exibimos uma fonte humana: "nome_exemplo.epub" vira "Nome Exemplo".
        title = title:match("([^/\\]+)$") or title
        title = title:gsub("%.[A-Za-z0-9]+$", "")
        title = title:gsub("[_%-]+", " ")
        title = title:gsub("%s+", " ")
        title = journalTrim(title)

        -- Se o texto veio todo em minúsculas/slug, aplicamos título simples. Não
        -- tentamos normalização Unicode pesada para não depender de libs extras.
        if not title:find("%u") then
            title = title:gsub("(%S+)", titleCaseAsciiWord)
        end
        return title
    end

    local function normalizeCustomMeaningAuthorName(author)
        if type(author) == "table" then
            local parts = {}
            for _, value in ipairs(author) do
                value = journalTrim(tostring(value or ""))
                if value ~= "" then
                    table.insert(parts, value)
                end
            end
            author = table.concat(parts, ", ")
        end

        author = journalTrim(tostring(author or ""):gsub("%z", ""))
        author = author:gsub("%s+", " ")
        return journalTrim(author)
    end

    local function formatCustomMeaningSourceTitle(title, author)
        title = normalizeCustomMeaningSourceTitle(title)
        author = normalizeCustomMeaningAuthorName(author)

        if title == "" then
            return ""
        end
        if author == "" or journalSafeLower(author) == journalSafeLower(title) then
            return title
        end

        -- Exibição pedida: "Nome do Livro, Autor".
        return title .. ", " .. author
    end

    function TarotPlugin:getCurrentBookTitleForMeaning()
        local title = nil
        local author = nil
        local document = self.ui and self.ui.document
        if document and type(document) == "table" then
            if document.info and type(document.info) == "table" then
                title = document.info.title or document.info.doc_title or document.info.name
                author = document.info.author or document.info.authors
                    or document.info.creator or document.info.creators
            end
            title = title or document.title or document.file or document.filename
            author = author or document.author or document.authors
        end

        if (not title or title == "") and self.ui then
            title = self.ui.document_title or self.ui.filename
        end

        title = formatCustomMeaningSourceTitle(title, author)
        if title == "" then
            return self:getTranslation("unknown_book")
        end
        return title
    end

    function TarotPlugin:cleanHighlightMeaningText(selected_text)
        if type(selected_text) == "table" then
            selected_text = selected_text.text or selected_text[1] or ""
        end
        selected_text = tostring(selected_text or "")
        if util and type(util.cleanupSelectedText) == "function" then
            selected_text = util.cleanupSelectedText(selected_text)
        end
        selected_text = journalTrim(selected_text:gsub("%z", ""))
        return selected_text
    end

    function TarotPlugin:readCustomMeanings()
        local path = self.custom_meanings_path or (self:getPluginDirectory() .. "/significados_cartas.trcm")
        local content = journalReadAll(path)
        if not content or content:sub(1, #CUSTOM_MEANINGS_MAGIC) ~= CUSTOM_MEANINGS_MAGIC then
            return {}
        end

        local entries = {}
        local entry_index = 0
        for line in content:gmatch("[^\n]+") do
            local payload = line:match("^entry=(.*)$")
            if payload then
                local deck, card_id, orientation, created_at, source_title, text = payload:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
                card_id = tonumber(card_id)
                if deck and card_id and orientation and text then
                    entry_index = entry_index + 1
                    table.insert(entries, {
                        index = entry_index,
                        deck = journalUnescape(deck),
                        card_id = card_id,
                        orientation = normalizeMeaningOrientation(journalUnescape(orientation), deck == "lenormand"),
                        created_at = tonumber(journalUnescape(created_at)) or 0,
                        source_title = normalizeCustomMeaningSourceTitle(journalUnescape(source_title or "")),
                        text = journalUnescape(text or ""),
                    })
                end
            end
        end
        return entries
    end

    function TarotPlugin:getCustomMeaningsForCard(card, deck_is_lenormand, orientation)
        local wanted_deck = getDeckStorageId(deck_is_lenormand)
        local wanted_id = card and tonumber(card.id)
        local wanted_orientation = normalizeMeaningOrientation(orientation, deck_is_lenormand)
        local result = {}

        if not wanted_id then return result end

        for _, entry in ipairs(self:readCustomMeanings()) do
            if entry.deck == wanted_deck
                and tonumber(entry.card_id) == wanted_id
                and entry.orientation == wanted_orientation
                and journalTrim(entry.text) ~= "" then
                table.insert(result, entry)
            end
        end

        return result
    end

    function TarotPlugin:appendCustomMeaning(card, deck_is_lenormand, orientation, text, source_title)
        text = self:cleanHighlightMeaningText(text)
        if text == "" then
            UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_empty") })
            return false
        end

        local id = card and tonumber(card.id)
        if not id then return false end

        local path = self.custom_meanings_path or (self:getPluginDirectory() .. "/significados_cartas.trcm")
        local existing = journalReadAll(path)
        if not existing or existing:sub(1, #CUSTOM_MEANINGS_MAGIC) ~= CUSTOM_MEANINGS_MAGIC then
            existing = CUSTOM_MEANINGS_MAGIC .. "\n"
        end

        local line = table.concat({
            journalEscape(getDeckStorageId(deck_is_lenormand)),
            journalEscape(tostring(id)),
            journalEscape(normalizeMeaningOrientation(orientation, deck_is_lenormand)),
            journalEscape(tostring(os.time())),
            journalEscape(normalizeCustomMeaningSourceTitle(source_title or self:getCurrentBookTitleForMeaning())),
            journalEscape(text),
        }, "|")

        local ok, err = journalWriteAll(path, existing .. "entry=" .. line .. "\n")
        if not ok then
            logger.warn("tarot.koplugin: erro ao salvar significado pessoal:", err)
            UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_error") })
            return false
        end

        UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_saved") })
        return true
    end

    function TarotPlugin:registerHighlightMeaningAction()
        if self._tarot_highlight_meaning_registered then
            return true
        end

        local highlight = self.ui and self.ui.highlight
        if not highlight or type(highlight.addToHighlightDialog) ~= "function" then
            return false
        end

        local plugin = self
        highlight:addToHighlightDialog("04a_tarot_add_meaning", function(reader_highlight)
            local selected_text = plugin:cleanHighlightMeaningText(reader_highlight and reader_highlight.selected_text)
            return {
                text = plugin:getTranslation("add_highlight_to_card_meaning"),
                enabled = selected_text ~= "",
                callback = function()
                    selected_text = plugin:cleanHighlightMeaningText(reader_highlight and reader_highlight.selected_text)
                    if selected_text == "" then
                        UIManager:show(InfoMessage:new{ text = plugin:getTranslation("highlight_meaning_empty") })
                        return
                    end

                    if reader_highlight and type(reader_highlight.onClose) == "function" then
                        reader_highlight:onClose(true)
                    end

                    UIManager:scheduleIn(0.1, function()
                        plugin:showHighlightMeaningDeckMenu(selected_text)
                    end)
                end,
            }
        end)

        self._tarot_highlight_meaning_registered = true
        return true
    end

    function TarotPlugin:showHighlightMeaningDeckMenu(selected_text)
        local buttons = {
            {{ label = true, text = self:getTranslation("choose_deck") }},
            {{ text = self:getTranslation("tarot_deck"), close_before = true, callback = function()
                self:showHighlightMeaningCardSelect(selected_text, false, 1)
            end }},
            {{ text = self:getTranslation("lenormand_deck"), close_before = true, callback = function()
                self:showHighlightMeaningCardSelect(selected_text, true, 1)
            end }},
            {{ text = self:getTranslation("cancel"), footer = true, close_before = true }},
        }

        UIManager:show(FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("highlight_meaning_title"),
            buttons = buttons,
        })
        setTarotDirty(self)
    end

    function TarotPlugin:showHighlightMeaningCardSelect(selected_text, deck_is_lenormand, page)
        local deck = deck_is_lenormand and LENORMAND_DECK or FULL_DECK
        local per_page = 9
        local page_count = math.max(1, math.ceil(#deck / per_page))
        page = tonumber(page) or 1
        if page < 1 then page = 1 end
        if page > page_count then page = page_count end

        local buttons = {
            {{ label = true, text = string.format(self:getTranslation("page_count"), page, page_count) }},
        }

        local start_index = (page - 1) * per_page + 1
        local end_index = math.min(#deck, start_index + per_page - 1)
        for index = start_index, end_index do
            local card = deck[index]
            local prefix = deck_is_lenormand and string.format("%02d. ", index) or ""
            table.insert(buttons, {{
                text = prefix .. T(card.name),
                close_before = true,
                callback = function()
                    if deck_is_lenormand then
                        if self:appendCustomMeaning(card, true, "upright", selected_text) then
                            self:showCardInBook(card, true)
                        end
                    else
                        self:showHighlightMeaningOrientationMenu(selected_text, card)
                    end
                end,
            }})
        end

        local footer_row = {}
        table.insert(footer_row, {
            text = self:getTranslation("prev"),
            footer = true,
            enabled = page > 1,
            close_before = true,
            callback = function()
                self:showHighlightMeaningCardSelect(selected_text, deck_is_lenormand, page - 1)
            end,
        })
        table.insert(footer_row, {
            text = self:getTranslation("next"),
            footer = true,
            enabled = page < page_count,
            close_before = true,
            callback = function()
                self:showHighlightMeaningCardSelect(selected_text, deck_is_lenormand, page + 1)
            end,
        })
        table.insert(buttons, footer_row)
        table.insert(buttons, {{
            text = self:getTranslation("back"),
            footer = true,
            close_before = true,
            callback = function()
                self:showHighlightMeaningDeckMenu(selected_text)
            end,
        }})

        UIManager:show(FullscreenMenuDialog:new{
            plugin = self,
            title = deck_is_lenormand and self:getTranslation("choose_lenormand_card") or self:getTranslation("choose_tarot_card"),
            buttons = buttons,
        })
        setTarotDirty(self)
    end

    function TarotPlugin:showHighlightMeaningOrientationMenu(selected_text, card)
        local buttons = {
            {{ label = true, text = T(card.name) }},
            {{ text = self:getTranslation("upright_meaning_choice"), close_before = true, callback = function()
                if self:appendCustomMeaning(card, false, "upright", selected_text) then
                    self:showCardInBook(card, false)
                end
            end }},
            {{ text = self:getTranslation("reversed_meaning_choice"), close_before = true, callback = function()
                if self:appendCustomMeaning(card, false, "reversed", selected_text) then
                    self:showCardInBook(card, false)
                end
            end }},
            {{ text = self:getTranslation("back"), footer = true, close_before = true, callback = function()
                self:showHighlightMeaningCardSelect(selected_text, false, 1)
            end }},
        }

        UIManager:show(FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("choose_orientation"),
            buttons = buttons,
        })
        setTarotDirty(self)
    end

    function TarotPlugin:formatCustomMeaningEntries(entries, show_source)
        local lines = {}
        for _, entry in ipairs(entries or {}) do
            local source = normalizeCustomMeaningSourceTitle(entry.source_title or "")
            if show_source and source ~= "" then
                table.insert(lines, string.format(
                    '%s: "%s"',
                    self:getTranslation("highlight_source_label"),
                    source
                ))
            end
            table.insert(lines, journalTrim(entry.text))
            table.insert(lines, "")
        end
        return journalTrim(table.concat(lines, "\n"))
    end


    function TarotPlugin:cleanCustomMeaningEditorText(text)
        text = tostring(text or ""):gsub("%z", "")
        return journalTrim(text)
    end

    function TarotPlugin:writeCustomMeanings(entries)
        local path = self.custom_meanings_path or (self:getPluginDirectory() .. "/significados_cartas.trcm")
        local lines = { CUSTOM_MEANINGS_MAGIC }

        for _, entry in ipairs(entries or {}) do
            local deck = entry.deck == "lenormand" and "lenormand" or "tarot"
            local card_id = tonumber(entry.card_id)
            local text = self:cleanCustomMeaningEditorText(entry.text)
            if card_id and text ~= "" then
                table.insert(lines, "entry=" .. table.concat({
                    journalEscape(deck),
                    journalEscape(tostring(card_id)),
                    journalEscape(normalizeMeaningOrientation(entry.orientation, deck == "lenormand")),
                    journalEscape(tostring(tonumber(entry.created_at) or os.time())),
                    journalEscape(normalizeCustomMeaningSourceTitle(entry.source_title or "")),
                    journalEscape(text),
                }, "|"))
            end
        end

        local ok, err = journalWriteAll(path, table.concat(lines, "\n") .. "\n")
        if not ok then
            logger.warn("tarot.koplugin: erro ao gravar significados pessoais:", err)
            UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_error") })
            return false
        end
        return true
    end

    function TarotPlugin:insertCustomMeaning(card, deck_is_lenormand, orientation, text, source_title)
        text = self:cleanCustomMeaningEditorText(text)
        if text == "" then
            UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_empty") })
            return false
        end

        local id = card and tonumber(card.id)
        if not id then return false end

        local entries = self:readCustomMeanings()
        table.insert(entries, {
            deck = getDeckStorageId(deck_is_lenormand),
            card_id = id,
            orientation = normalizeMeaningOrientation(orientation, deck_is_lenormand),
            created_at = os.time(),
            source_title = normalizeCustomMeaningSourceTitle(source_title or ""),
            text = text,
        })

        if not self:writeCustomMeanings(entries) then return false end
        UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_saved") })
        return true
    end

    function TarotPlugin:updateCustomMeaningByIndex(entry_index, text)
        entry_index = tonumber(entry_index)
        text = self:cleanCustomMeaningEditorText(text)
        if not entry_index then return false end
        if text == "" then
            UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_empty") })
            return false
        end

        local changed = false
        local entries = self:readCustomMeanings()
        for _, entry in ipairs(entries) do
            if tonumber(entry.index) == entry_index then
                entry.text = text
                changed = true
                break
            end
        end

        if not changed then return false end
        if not self:writeCustomMeanings(entries) then return false end
        UIManager:show(InfoMessage:new{ text = self:getTranslation("custom_meaning_updated") })
        return true
    end

    function TarotPlugin:removeCustomMeaningByIndex(entry_index)
        entry_index = tonumber(entry_index)
        if not entry_index then return false end

        local changed = false
        local remaining = {}
        for _, entry in ipairs(self:readCustomMeanings()) do
            if tonumber(entry.index) == entry_index then
                changed = true
            else
                table.insert(remaining, entry)
            end
        end

        if not changed then return false end
        if not self:writeCustomMeanings(remaining) then return false end
        UIManager:show(InfoMessage:new{ text = self:getTranslation("custom_meaning_removed") })
        return true
    end

    function TarotPlugin:getCustomMeaningByIndex(entry_index)
        entry_index = tonumber(entry_index)
        if not entry_index then return nil end
        for _, entry in ipairs(self:readCustomMeanings()) do
            if tonumber(entry.index) == entry_index then
                return entry
            end
        end
        return nil
    end

    function TarotPlugin:showCustomMeaningEditorStart(parent_dialog)
        -- Primeiro abre o menu real do editor (Tarot / Lenormand) e só depois
        -- exibe o aviso por cima dele. Assim o usuário já entende onde está e não
        -- vê o aviso surgir ainda sobre o Livro de Cartas.
        self:showCustomMeaningEditorDeckMenu()

        UIManager:scheduleIn(0.1, function()
            -- Fecha o Livro de Cartas somente depois que o novo menu já está na
            -- pilha da UI. Isso evita o salto visual para a Home.
            if parent_dialog then
                pcall(function() UIManager:close(parent_dialog) end)
            end
            self:showCustomMeaningEditorHint()
        end)
    end

    function TarotPlugin:showCustomMeaningEditorDeckMenu()
        local dialog
        local layout = getFullscreenLayout()
        local iw = layout.content_w
        local card_w = math.floor(iw * 0.92)
        local card_inner_w = card_w - Size.padding.default * 2
        local selector_gap = Size.span.horizontal_default
        local selector_w = math.floor((card_inner_w - selector_gap) / 2)

        local function openEditorDeck(deck_is_lenormand)
            UIManager:close(dialog)
            self:showCustomMeaningEditorCardSelect(deck_is_lenormand, 1)
            setTarotDirty(self)
        end

        local deck_selector = HorizontalGroup:new{
            align = "center",
            makeRoundedButton{
                text = self:getTranslation("tarot_deck"),
                width = selector_w,
                callback = function() openEditorDeck(false) end,
            },
            HorizontalSpan:new{ width = selector_gap },
            makeRoundedButton{
                text = self:getTranslation("lenormand_deck"),
                width = selector_w,
                callback = function() openEditorDeck(true) end,
            },
        }

        local deck_box = makeSettingsCard(
            self:getTranslation("deck_type"),
            deck_selector,
            card_w
        )
        local header_w = makeSectionHeader(
            self:getTranslation("edit_custom_meanings"),
            iw,
            nil,
            deck_box,
            false
        )

        dialog = InputContainer:new{}
        dialog.plugin = self
        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            header = header_w,
            body = VerticalGroup:new{ align = "center", VerticalSpan:new{ width = 1 } },
        }
        dialog[1] = OverlapGroup:new{
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
            makeTopBackIconButton(self, layout, function()
                UIManager:close(dialog)
                self:showCardBook()
                setTarotDirty(self)
            end),
        }

        UIManager:show(dialog)
        setTarotDirty(self)
    end

    function TarotPlugin:showCustomMeaningEditorCardSelect(deck_is_lenormand, page)
        local deck = deck_is_lenormand and LENORMAND_DECK or FULL_DECK
        local per_page = 9
        local page_count = math.max(1, math.ceil(#deck / per_page))
        page = tonumber(page) or 1
        if page < 1 then page = 1 end
        if page > page_count then page = page_count end

        local buttons = {
            {{ label = true, text = string.format(self:getTranslation("page_count"), page, page_count) }},
        }

        local start_index = (page - 1) * per_page + 1
        local end_index = math.min(#deck, start_index + per_page - 1)
        for index = start_index, end_index do
            local card = deck[index]
            local prefix = deck_is_lenormand and string.format("%02d. ", index) or ""
            table.insert(buttons, {{
                text = prefix .. T(card.name),
                close_before = true,
                callback = function()
                    if deck_is_lenormand then
                        self:showCustomMeaningManageMenu(card, true, "upright", 1)
                    else
                        self:showCustomMeaningEditorOrientationMenu(card)
                    end
                end,
            }})
        end

        local footer_row = {}
        table.insert(footer_row, {
            text = self:getTranslation("prev"),
            footer = true,
            enabled = page > 1,
            close_before = true,
            callback = function()
                self:showCustomMeaningEditorCardSelect(deck_is_lenormand, page - 1)
            end,
        })
        table.insert(footer_row, {
            text = self:getTranslation("next"),
            footer = true,
            enabled = page < page_count,
            close_before = true,
            callback = function()
                self:showCustomMeaningEditorCardSelect(deck_is_lenormand, page + 1)
            end,
        })
        table.insert(buttons, footer_row)
        table.insert(buttons, {{
            text = self:getTranslation("back"),
            footer = true,
            close_before = true,
            callback = function()
                self:showCustomMeaningEditorDeckMenu()
            end,
        }})

        UIManager:show(FullscreenMenuDialog:new{
            plugin = self,
            title = deck_is_lenormand and self:getTranslation("choose_lenormand_card") or self:getTranslation("choose_tarot_card"),
            buttons = buttons,
        })
        setTarotDirty(self)
    end

    function TarotPlugin:showCustomMeaningEditorOrientationMenu(card, back_callback)
        local buttons = {
            {{ label = true, text = T(card.name) }},
            {{ text = self:getTranslation("upright_meaning_choice"), close_before = true, callback = function()
                self:showCustomMeaningManageMenu(card, false, "upright", 1, back_callback)
            end }},
            {{ text = self:getTranslation("reversed_meaning_choice"), close_before = true, callback = function()
                self:showCustomMeaningManageMenu(card, false, "reversed", 1, back_callback)
            end }},
            {{ text = self:getTranslation("back"), footer = true, close_before = true, callback = function()
                if type(back_callback) == "function" then
                    back_callback()
                else
                    self:showCustomMeaningEditorCardSelect(false, 1)
                end
            end }},
        }

        UIManager:show(FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("choose_orientation"),
            buttons = buttons,
        })
        setTarotDirty(self)
    end

    function TarotPlugin:showCustomMeaningInput(card, deck_is_lenormand, orientation, entry_index, back_callback)
        local current_entry = entry_index and self:getCustomMeaningByIndex(entry_index) or nil
        local input_dialog
        input_dialog = InputDialog:new{
            title = current_entry and self:getTranslation("edit_custom_meaning") or self:getTranslation("add_custom_meaning"),
            input = current_entry and current_entry.text or "",
            input_hint = self:getTranslation("custom_meaning_input_hint"),
            fullscreen = true,
            condensed = true,
            allow_newline = true,
            add_nav_bar = true,
            buttons = {
                {
                    {
                        text = self:getTranslation("cancel"),
                        callback = function()
                            UIManager:close(input_dialog)
                            self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1, back_callback)
                        end,
                    },
                    {
                        text = self:getTranslation("save"),
                        is_enter_default = true,
                        callback = function()
                            local text = input_dialog:getInputText()
                            local ok
                            if current_entry then
                                ok = self:updateCustomMeaningByIndex(current_entry.index, text)
                            else
                                ok = self:insertCustomMeaning(card, deck_is_lenormand, orientation, text, "")
                            end
                            if ok then
                                UIManager:close(input_dialog)
                                self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1, back_callback)
                            end
                        end,
                    },
                },
            },
        }
        UIManager:show(input_dialog)
        input_dialog:onShowKeyboard()
    end

    function TarotPlugin:showCustomMeaningEntryActions(card, deck_is_lenormand, orientation, entry_index, back_callback)
        local entry = self:getCustomMeaningByIndex(entry_index)
        if not entry then
            self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1, back_callback)
            return
        end

        local buttons = {
            {{ label = true, text = journalPreview(entry.text, 160) }},
            {{ text = self:getTranslation("edit_custom_meaning"), icon_name = "pen", close_before = true, callback = function()
                self:showCustomMeaningInput(card, deck_is_lenormand, orientation, entry.index, back_callback)
            end }},
            {{ text = self:getTranslation("remove_custom_meaning"), icon_name = "trash-bin", close_before = true, callback = function()
                local confirm
                confirm = ConfirmBox:new{
                    text = self:getTranslation("remove_custom_meaning_confirm"),
                    ok_text = self:getTranslation("yes"),
                    cancel_text = self:getTranslation("no"),
                    ok_callback = function()
                        if self:removeCustomMeaningByIndex(entry.index) then
                            self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1, back_callback)
                        end
                    end,
                    cancel_callback = function()
                        self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1, back_callback)
                    end,
                }
                UIManager:show(confirm)
            end }},
            {{ text = self:getTranslation("back"), footer = true, close_before = true, callback = function()
                self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1, back_callback)
            end }},
        }

        UIManager:show(FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("choose_custom_meaning"),
            buttons = buttons,
        })
        setTarotDirty(self)
    end

    function TarotPlugin:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, page, back_callback)
        local entries = self:getCustomMeaningsForCard(card, deck_is_lenormand, orientation)
        local per_page = 5
        local page_count = math.max(1, math.ceil(math.max(1, #entries) / per_page))
        page = tonumber(page) or 1
        if page < 1 then page = 1 end
        if page > page_count then page = page_count end

        local orientation_label = deck_is_lenormand and self:getTranslation("upright")
            or (orientation == "reversed" and self:getTranslation("reversed") or self:getTranslation("upright"))
        local buttons = {
            {{ label = true, text = T(card.name) .. " — " .. orientation_label }},
            {{ text = self:getTranslation("add_custom_meaning"), icon_name = "pen", close_before = true, callback = function()
                self:showCustomMeaningInput(card, deck_is_lenormand, orientation, nil, back_callback)
            end }},
        }

        if #entries == 0 then
            table.insert(buttons, {{ label = true, text = self:getTranslation("no_custom_meanings") }})
        else
            table.insert(buttons, {{ label = true, text = string.format(self:getTranslation("page_count"), page, page_count) }})
            local start_index = (page - 1) * per_page + 1
            local end_index = math.min(#entries, start_index + per_page - 1)
            for index = start_index, end_index do
                local entry = entries[index]
                table.insert(buttons, {{
                    text = journalPreview(entry.text, 180),
                    close_before = true,
                    callback = function()
                        self:showCustomMeaningEntryActions(card, deck_is_lenormand, orientation, entry.index, back_callback)
                    end,
                }})
            end

            if page_count > 1 then
                table.insert(buttons, {
                    {
                        text = self:getTranslation("prev"),
                        footer = true,
                        enabled = page > 1,
                        close_before = true,
                        callback = function()
                            self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, page - 1, back_callback)
                        end,
                    },
                    {
                        text = self:getTranslation("next"),
                        footer = true,
                        enabled = page < page_count,
                        close_before = true,
                        callback = function()
                            self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, page + 1, back_callback)
                        end,
                    },
                })
            end
        end

        table.insert(buttons, {{
            text = self:getTranslation("back"),
            footer = true,
            close_before = true,
            callback = function()
                if type(back_callback) == "function" then
                    back_callback()
                elseif deck_is_lenormand then
                    self:showCustomMeaningEditorCardSelect(true, 1)
                else
                    self:showCustomMeaningEditorOrientationMenu(card)
                end
            end,
        }})

        UIManager:show(FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("edit_custom_meanings"),
            buttons = buttons,
        })
        setTarotDirty(self)
    end

    function TarotPlugin:showCustomMeaningEditorForCard(card, deck_is_lenormand, back_callback, options)
        if not card then return end
        local function goBack()
            if type(back_callback) == "function" then
                back_callback()
            else
                self:showCardInBook(card, deck_is_lenormand)
            end
        end

        if deck_is_lenormand then
            options = options or {}
            if options.parent_dialog then
                pcall(function() UIManager:close(options.parent_dialog) end)
            end
            self:showCustomMeaningManageMenu(card, true, "upright", 1, goBack)
            UIManager:scheduleIn(0.1, function()
                self:showCustomMeaningEditorHint()
            end)
        else
            self:showCustomMeaningOrientationPopup(card, goBack, options)
        end
        setTarotDirty(self)
    end

    local CustomMeaningOrientationPopup = InputContainer:extend{
        plugin = nil,
        layout = nil,
        card = nil,
        parent_dialog = nil,
        back_callback = nil,
        side = "right",
        slot = 0,
        box = nil,
        box_x = 0,
        box_y = 0,
    }

    function CustomMeaningOrientationPopup:init()
        local layout = self.layout or getFullscreenLayout(0.92)
        local metrics = getTopIconMetrics(layout)
        local touch_size = metrics.touch_size
        local gap = metrics.gap
        local slot = tonumber(self.slot) or 0
        local padding = Size.padding.default
        local box_w = math.floor(
            math.min(math.floor(layout.safe_w * 0.72), math.floor(layout.content_w * 0.82)) * 2 / 3
        )
        if box_w < math.floor(layout.content_w * 0.36) then
            box_w = math.floor(layout.content_w * 0.36)
        end
        local inner_w = math.max(80, box_w - padding * 2)
        local row_h = math.max(34, math.min(46, math.floor(layout.safe_h * 0.048)))

        if self.side == "left" then
            self.box_x = layout.outer_pad + slot * (touch_size + gap)
        else
            self.box_x = layout.screen_w - layout.outer_pad - box_w - slot * (touch_size + gap)
        end
        if self.box_x < layout.outer_pad then
            self.box_x = layout.outer_pad
        end
        if self.box_x + box_w > layout.screen_w - layout.outer_pad then
            self.box_x = math.max(layout.outer_pad, layout.screen_w - layout.outer_pad - box_w)
        end
        self.box_y = layout.outer_pad + touch_size + gap

        self.dimen = Geom:new{ x = 0, y = 0, w = layout.screen_w, h = layout.screen_h }
        self.ges_events = {}

        local content = VerticalGroup:new{ align = "center" }
        local cursor_y = self.box_y + padding
        local action_index = 0

        local header_widget = TextBoxWidget:new{
            text = self.plugin:getTranslation("edit_custom_meaning"),
            face = Font:getFace("x_smallinfofont"),
            width = inner_w,
            alignment = "center",
        }
        local header_h = math.max(math.floor(touch_size * 0.85), header_widget:getSize().h)
        table.insert(content, CenterContainer:new{
            dimen = Geom:new{ w = inner_w, h = header_h },
            header_widget,
        })
        cursor_y = cursor_y + header_h

        local function openOrientation(orientation)
            UIManager:close(self)
            if self.parent_dialog then
                pcall(function() UIManager:close(self.parent_dialog) end)
            end
            self.plugin:showCustomMeaningManageMenu(
                self.card,
                false,
                orientation,
                1,
                self.back_callback
            )
            UIManager:scheduleIn(0.1, function()
                self.plugin:showCustomMeaningEditorHint()
            end)
            setTarotDirty(self.plugin or self)
            return true
        end

        local function addActionRow(text, orientation)
            action_index = action_index + 1
            local event_name = "TapCustomMeaningOrientation" .. tostring(action_index)
            table.insert(content, Button:new{
                text = text,
                width = inner_w,
                height = row_h,
                bordersize = 0,
                radius = 0,
                align = "center",
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
                return openOrientation(orientation)
            end
            cursor_y = cursor_y + row_h
        end

        addActionRow(self.plugin:getTranslation("upright"), "upright")
        addActionRow(self.plugin:getTranslation("reversed"), "reversed")

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

        addCloseRange("TapCustomMeaningCloseTop", 0, 0, layout.screen_w, self.box_y)
        addCloseRange("TapCustomMeaningCloseLeft", 0, self.box_y, self.box_x, box_h)
        addCloseRange(
            "TapCustomMeaningCloseRight",
            self.box_x + box_w,
            self.box_y,
            layout.screen_w - self.box_x - box_w,
            box_h
        )
        addCloseRange(
            "TapCustomMeaningCloseBottom",
            0,
            self.box_y + box_h,
            layout.screen_w,
            layout.screen_h - self.box_y - box_h
        )
    end

    function CustomMeaningOrientationPopup:paintTo(bb, x, y)
        if self.box then
            self.box:paintTo(bb, x + self.box_x, y + self.box_y)
        end
    end

    function TarotPlugin:showCustomMeaningOrientationPopup(card, back_callback, options)
        options = options or {}
        UIManager:show(CustomMeaningOrientationPopup:new{
            plugin = self,
            layout = options.layout,
            card = card,
            parent_dialog = options.parent_dialog,
            back_callback = back_callback,
            side = options.side or "right",
            slot = options.slot or 0,
        })
        setTarotDirty(self.plugin or self, "partial")
    end


end

return M

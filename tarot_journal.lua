-- Diário de Reflexões: persistência, busca, filtros, lixeira, backups e UI.

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
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = require("device").screen
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")

local M = {}

function M.register(deps)
    deps = deps or {}
    local TarotPlugin = assert(deps.TarotPlugin, "TarotPlugin is required")
    local T = assert(deps.T, "translator is required")
    local FULL_DECK = assert(deps.FULL_DECK, "FULL_DECK is required")
    local LENORMAND_DECK = assert(deps.LENORMAND_DECK, "LENORMAND_DECK is required")
    local JOURNAL_MAGIC = assert(deps.JOURNAL_MAGIC, "JOURNAL_MAGIC is required")
    local FullscreenMenuDialog = assert(deps.FullscreenMenuDialog, "FullscreenMenuDialog is required")
    local CardDialog = assert(deps.CardDialog, "CardDialog is required")
    local HiddenCardDialog = assert(deps.HiddenCardDialog, "HiddenCardDialog is required")
    local journalTrim = assert(deps.journalTrim, "journalTrim is required")
    local journalEscape = assert(deps.journalEscape, "journalEscape is required")
    local journalUnescape = assert(deps.journalUnescape, "journalUnescape is required")
    local journalReadAll = assert(deps.journalReadAll, "journalReadAll is required")
    local journalWriteAll = assert(deps.journalWriteAll, "journalWriteAll is required")
    local journalCopyFile = assert(deps.journalCopyFile, "journalCopyFile is required")
    local journalUniquePath = assert(deps.journalUniquePath, "journalUniquePath is required")
    local journalShallowCopy = assert(deps.journalShallowCopy, "journalShallowCopy is required")
    local journalSafeLower = assert(deps.journalSafeLower, "journalSafeLower is required")
    local journalPreview = assert(deps.journalPreview, "journalPreview is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local getTopIconMetrics = assert(deps.getTopIconMetrics, "getTopIconMetrics is required")
    local makeSectionHeader = assert(deps.makeSectionHeader, "makeSectionHeader is required")
    local makeMutedText = assert(deps.makeMutedText, "makeMutedText is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local makeFullscreenFooter = assert(deps.makeFullscreenFooter, "makeFullscreenFooter is required")
    local makeFloatingIconButton = assert(deps.makeFloatingIconButton, "makeFloatingIconButton is required")
    local makeTopBackIconButton = assert(deps.makeTopBackIconButton, "makeTopBackIconButton is required")
    local makeRoundedButton = assert(deps.makeRoundedButton, "makeRoundedButton is required")
    local getTarotButtonRadius = assert(deps.getTarotButtonRadius, "getTarotButtonRadius is required")
    local addHorizontalSwipeNavigation = assert(deps.addHorizontalSwipeNavigation, "addHorizontalSwipeNavigation is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

    function TarotPlugin:writeJournalEntry(entry)
        self:ensureJournalDirs()
        if not entry then return false end

        entry.id = entry.id or os.date("%Y%m%d-%H%M%S") .. "-" .. tostring(math.random(1000, 9999))
        entry.created_at = tonumber(entry.created_at) or os.time()
        entry.updated_at = tonumber(entry.updated_at) or entry.created_at
        entry.entry_type = entry.entry_type or "free"
        entry.deck = entry.deck or "none"
        entry.title = journalTrim(entry.title)
        entry.note = tostring(entry.note or "")
        entry.outcome = tostring(entry.outcome or "")
        entry.outcome_at = tonumber(entry.outcome_at) or 0
        entry.favorite = entry.favorite == true
        entry.cards = entry.cards or {}
        entry.position_names = entry.position_names or {}

        local lines = {
            JOURNAL_MAGIC,
            "id=" .. journalEscape(entry.id),
            "created_at=" .. tostring(entry.created_at),
            "updated_at=" .. tostring(entry.updated_at),
            "entry_type=" .. journalEscape(entry.entry_type),
            "deck=" .. journalEscape(entry.deck),
            "spread_type=" .. journalEscape(entry.spread_type or ""),
            "layout_mode=" .. journalEscape(entry.layout_mode or "auto"),
            "title=" .. journalEscape(entry.title),
            "note=" .. journalEscape(entry.note),
            "outcome=" .. journalEscape(entry.outcome),
            "outcome_at=" .. tostring(entry.outcome_at),
            "favorite=" .. (entry.favorite and "1" or "0"),
        }

        for slot = 1, 16 do
            local stored_name = journalTrim(entry.position_names[slot])
            if stored_name ~= "" then
                table.insert(lines, "position=" .. tostring(slot) .. "|" .. journalEscape(stored_name))
            end
        end

        for _, card_data in ipairs(entry.cards) do
            local id = tonumber(card_data.id)
            if id then
                local card_line = "card=" .. tostring(id) .. "|" .. (card_data.is_reversed and "1" or "0")
                local grid_slot = tonumber(card_data.grid_slot)
                if grid_slot and grid_slot >= 1 and grid_slot <= 16 then
                    card_line = card_line .. "|" .. tostring(grid_slot)
                end
                table.insert(lines, card_line)
            end
        end

        local filepath = entry.filepath or (self.journal_dir .. "/" .. entry.id .. ".trj")
        local ok, err = journalWriteAll(filepath, table.concat(lines, "\n") .. "\n")
        if not ok then
            logger.warn("tarot.koplugin: erro ao salvar registro do Diário:", err)
            return false
        end

        entry.filepath = filepath
        entry.filename = filepath:match("([^/]+)$")
        entry.source = "structured"
        return true
    end

    function TarotPlugin:readJournalEntry(path)
        local content = journalReadAll(path)
        if not content or content:sub(1, #JOURNAL_MAGIC) ~= JOURNAL_MAGIC then
            return nil
        end

        local entry = { cards = {}, position_names = {}, filepath = path, source = "structured" }
        for line in content:gmatch("[^\r\n]+") do
            local key, value = line:match("^([^=]+)=(.*)$")
            if key == "position" then
                local slot, stored_name = value:match("^(%d+)|(.*)$")
                slot = tonumber(slot)
                if slot and slot >= 1 and slot <= 16 then
                    stored_name = journalTrim(journalUnescape(stored_name))
                    if stored_name ~= "" then
                        entry.position_names[slot] = stored_name
                    end
                end
            elseif key == "card" then
                local id, reversed, grid_slot = value:match("^(%-?%d+)|([01])|(%d+)$")
                if not id then
                    id, reversed = value:match("^(%-?%d+)|([01])$")
                end
                if id then
                    table.insert(entry.cards, {
                        id = tonumber(id),
                        is_reversed = reversed == "1",
                        grid_slot = tonumber(grid_slot),
                    })
                end
            elseif key then
                value = journalUnescape(value)
                if key == "created_at" or key == "updated_at" or key == "outcome_at" then
                    entry[key] = tonumber(value) or 0
                elseif key == "favorite" then
                    entry.favorite = value == "1"
                else
                    entry[key] = value
                end
            end
        end

        entry.id = entry.id or path:match("([^/]+)%.trj$")
        entry.created_at = tonumber(entry.created_at) or 0
        entry.updated_at = tonumber(entry.updated_at) or entry.created_at
        entry.title = entry.title or ""
        entry.note = entry.note or ""
        entry.outcome = entry.outcome or ""
        entry.entry_type = entry.entry_type or "free"
        entry.deck = entry.deck or "none"
        entry.layout_mode = entry.layout_mode == "custom" and "custom" or "auto"
        entry.position_names = entry.position_names or {}
        entry.filename = path:match("([^/]+)$")
        return entry
    end

    function TarotPlugin:makeJournalEntryFromCards(cards, title, note, entry_type)
        local is_lenormand = cards and cards[1] and cards[1].card and cards[1].card.symbol ~= nil
        local card_refs = {}
        local position_names = {}
        for slot, stored_name in pairs((cards and cards.position_names) or {}) do
            slot = tonumber(slot)
            stored_name = journalTrim(stored_name)
            if slot and slot >= 1 and slot <= 16 and stored_name ~= "" then
                position_names[slot] = stored_name
            end
        end
        for _, card_data in ipairs(cards or {}) do
            if card_data.card and card_data.card.id ~= nil then
                table.insert(card_refs, {
                    id = card_data.card.id,
                    is_reversed = card_data.is_reversed == true,
                    grid_slot = tonumber(card_data.grid_slot),
                })
                local slot = tonumber(card_data.grid_slot)
                local stored_name = journalTrim(card_data.position_name)
                if slot and slot >= 1 and slot <= 16 and stored_name ~= "" then
                    position_names[slot] = stored_name
                end
            end
        end

        local spread_type = ""
        if #card_refs == 1 then
            spread_type = "one_card"
        elseif #card_refs == 3 then
            spread_type = "three_cards"
        elseif #card_refs > 0 then
            spread_type = tostring(#card_refs) .. "_cards"
        end

        return {
            id = os.date("%Y%m%d-%H%M%S") .. "-" .. tostring(math.random(1000, 9999)),
            created_at = os.time(),
            updated_at = os.time(),
            entry_type = entry_type or "spread",
            deck = is_lenormand and "lenormand" or "tarot",
            spread_type = spread_type,
            layout_mode = (function()
                for _, card_data in ipairs(cards or {}) do
                    if tonumber(card_data.grid_slot) then return "custom" end
                end
                return "auto"
            end)(),
            title = title or "",
            note = note or "",
            outcome = "",
            outcome_at = 0,
            favorite = false,
            cards = card_refs,
            position_names = position_names,
        }
    end

    function TarotPlugin:saveReading(cards, title, note, entry_type)
        local entry = self:makeJournalEntryFromCards(cards, title, note, entry_type or "spread")
        if not self:writeJournalEntry(entry) then
            UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_error") })
            return false
        end
        UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_success") })
        return true
    end

    -- Cria um registro estruturado sem interromper a leitura com teclado ou caixa
    -- de confirmação. A reflexão fica vazia e pode ser preenchida depois no Diário.
    function TarotPlugin:autoSaveReading(cards)
        local first_card = cards and cards[1] and cards[1].card
        if not first_card then return false end

        local deck_name = first_card.symbol ~= nil
            and self:getTranslation("lenormand_deck")
            or self:getTranslation("tarot_deck")
        local timestamp = os.date("%d/%m/%Y %H:%M")
        local title = string.format(
            self:getTranslation("automatic_reading_title"),
            deck_name,
            timestamp
        )
        local entry = self:makeJournalEntryFromCards(cards, title, "", "spread")
        return self:writeJournalEntry(entry)
    end

    function TarotPlugin:makeLegacyJournalEntry(filename, filepath, modification)
        local content = journalReadAll(filepath) or ""
        local first_line = content:match("^([^\r\n]+)") or ""
        local y, m, d, hh, mm, ss = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)_(%d%d)%-(%d%d)%-(%d%d)")
        local created_at = tonumber(modification) or 0
        if y then
            created_at = os.time{
                year = tonumber(y), month = tonumber(m), day = tonumber(d),
                hour = tonumber(hh), min = tonumber(mm), sec = tonumber(ss),
            }
        end

        local fallback_title = filename:gsub("%.txt$", "")
        fallback_title = fallback_title:gsub("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d_", "")
        fallback_title = fallback_title:gsub("_", " ")

        return {
            id = "legacy:" .. filename,
            filename = filename,
            filepath = filepath,
            source = "legacy",
            entry_type = "legacy",
            deck = "unknown",
            title = journalTrim(first_line) ~= "" and journalTrim(first_line) or fallback_title,
            note = content,
            outcome = "",
            favorite = false,
            cards = {},
            created_at = created_at,
            updated_at = tonumber(modification) or created_at,
            legacy_content = content,
        }
    end

    function TarotPlugin:getJournalEntries(from_trash)
        self:ensureSavesDir()
        self:ensureJournalDirs()
        local entries = {}
        local directory = from_trash and self.journal_trash_dir or self.journal_dir

        if lfs.attributes(directory) then
            for filename in lfs.dir(directory) do
                if filename ~= "." and filename ~= ".." and filename:match("%.trj$") then
                    local path = directory .. "/" .. filename
                    local attr = lfs.attributes(path)
                    if attr and attr.mode == "file" then
                        local entry = self:readJournalEntry(path)
                        if entry then
                            entry.in_trash = from_trash == true
                            table.insert(entries, entry)
                        end
                    end
                end
            end
        end

        local legacy_directory = from_trash and self.journal_trash_dir or self.saves_dir
        if lfs.attributes(legacy_directory) then
            for filename in lfs.dir(legacy_directory) do
                if filename ~= "." and filename ~= ".." and filename:match("%.txt$") then
                    local path = legacy_directory .. "/" .. filename
                    local attr = lfs.attributes(path)
                    if attr and attr.mode == "file" then
                        local entry = self:makeLegacyJournalEntry(filename, path, attr.modification)
                        entry.in_trash = from_trash == true
                        table.insert(entries, entry)
                    end
                end
            end
        end

        return entries
    end

    -- Mantém o nome antigo desta função para compatibilidade com eventuais chamadas
    -- externas, mas agora devolve todos os tipos de registro do Diário.
    function TarotPlugin:getSavedReadings()
        return self:getJournalEntries(false)
    end

    function TarotPlugin:getJournalCard(entry, card_data)
        if not entry or not card_data then return nil end
        local deck = entry.deck == "lenormand" and LENORMAND_DECK or FULL_DECK
        for _, card in ipairs(deck) do
            if card.id == card_data.id then return card end
        end
        return nil
    end

    function TarotPlugin:getJournalEntrySearchText(entry)
        local chunks = {
            entry.title or "", entry.note or "", entry.outcome or "",
            entry.entry_type or "", entry.deck or "", entry.legacy_content or "",
        }
        for _, card_data in ipairs(entry.cards or {}) do
            local card = self:getJournalCard(entry, card_data)
            if card then
                table.insert(chunks, T(card.name))
                table.insert(chunks, T(card.keywords or ""))
            end
        end
        return journalSafeLower(table.concat(chunks, " "))
    end

    function TarotPlugin:getFilteredJournalEntries()
        local state = self.journal_state or {}
        local entries = self:getJournalEntries(false)
        local filtered = {}
        local query = journalSafeLower(journalTrim(state.query or ""))

        for _, entry in ipairs(entries) do
            local type_allowed = state.types and state.types[entry.entry_type] ~= false
            if entry.entry_type == "legacy" then
                type_allowed = state.types and state.types.legacy ~= false
            end
            local deck_allowed = state.deck == nil or state.deck == "all" or entry.deck == state.deck
            local favorite_allowed = not state.favorites_only or entry.favorite == true
            local month_allowed = not state.month or os.date("%Y-%m", entry.created_at or 0) == state.month
            local query_allowed = query == "" or self:getJournalEntrySearchText(entry):find(query, 1, true) ~= nil

            if type_allowed and deck_allowed and favorite_allowed and month_allowed and query_allowed then
                table.insert(filtered, entry)
            end
        end

        local sort_mode = state.sort or "newest"
        table.sort(filtered, function(a, b)
            if sort_mode == "oldest" then
                return (a.created_at or 0) < (b.created_at or 0)
            elseif sort_mode == "title" then
                local at, bt = journalSafeLower(a.title), journalSafeLower(b.title)
                if at == bt then return (a.created_at or 0) > (b.created_at or 0) end
                return at < bt
            elseif sort_mode == "edited" then
                return (a.updated_at or 0) > (b.updated_at or 0)
            end
            return (a.created_at or 0) > (b.created_at or 0)
        end)

        return filtered
    end

    function TarotPlugin:getJournalItemsPerPage()
        local height = Screen:getHeight()
        if height < 1050 then return 3 end
        if height < 1600 then return 4 end
        return 5
    end

    function TarotPlugin:getJournalEntryTypeText(entry)
        if entry.entry_type == "daily" then
            return self:getTranslation("daily_entry")
        elseif entry.entry_type == "free" then
            return self:getTranslation("free_entry")
        elseif entry.entry_type == "legacy" then
            return self:getTranslation("legacy_entry")
        end

        if entry.spread_type == "one_card" then
            return self:getTranslation("one_card_entry")
        elseif entry.spread_type == "three_cards" then
            return self:getTranslation("three_card_entry")
        elseif #(entry.cards or {}) > 0 then
            return string.format(self:getTranslation("card_total_entry"), #(entry.cards or {}))
        end
        return self:getTranslation("spread_entry")
    end

    function TarotPlugin:getJournalDeckText(entry)
        -- Reflexões Livres não pertencem a nenhum baralho. Retornar texto vazio
        -- evita que o valor interno "none" seja exibido incorretamente como
        -- "Registro Antigo" na lista do Diário.
        if entry.entry_type == "free" then return "" end
        if entry.deck == "tarot" then return self:getTranslation("tarot_deck") end
        if entry.deck == "lenormand" then return self:getTranslation("lenormand_deck") end
        return self:getTranslation("legacy_entry")
    end

    function TarotPlugin:getJournalDisplayTitle(entry)
        local title = journalTrim(entry.title)
        if title == "" then return self:getTranslation("untitled_reflection") end
        return title
    end

    function TarotPlugin:formatJournalListItem(entry)
        local star = entry.favorite and "★ " or ""
        local date_text = os.date("%d/%m/%Y", entry.created_at or 0)
        local metadata_parts = { star .. date_text }
        local deck_text = self:getJournalDeckText(entry)
        if deck_text and deck_text ~= "" then
            table.insert(metadata_parts, deck_text)
        end
        table.insert(metadata_parts, self:getJournalEntryTypeText(entry))
        local metadata = table.concat(metadata_parts, " · ")
        local preview_source = entry.entry_type == "legacy" and entry.legacy_content or entry.note
        local preview = journalPreview(preview_source, 90)
        local title = self:getJournalDisplayTitle(entry)
        if preview ~= "" and journalSafeLower(preview) ~= journalSafeLower(title) then
            return metadata .. "\n" .. title .. " — " .. preview
        end
        return metadata .. "\n" .. title
    end

    function TarotPlugin:closeJournalDialog()
        if self.journal_dialog then
            UIManager:close(self.journal_dialog)
            self.journal_dialog = nil
            setTarotDirty(self.plugin or self)
        end
    end

    function TarotPlugin:showSavedReadingsMenu(page)
        self.journal_state = self.journal_state or {
            page = 1, query = "", deck = "all",
            types = { spread = true, daily = true, free = true, legacy = true },
            favorites_only = false, sort = "newest", month = nil,
        }
        local state = self.journal_state
        if page then state.page = page end

        local entries = self:getFilteredJournalEntries()
        local per_page = self:getJournalItemsPerPage()
        local total_pages = math.max(1, math.ceil(#entries / per_page))
        if state.page < 1 then state.page = 1 end
        if state.page > total_pages then state.page = total_pages end

        self:closeJournalDialog()

        local layout = getFullscreenLayout(0.94)
        local iw = layout.content_w
        local subtitle = string.format(self:getTranslation("journal_records"), #entries)
        local header_w = makeSectionHeader(self:getTranslation("saved_readings"), iw, subtitle)
        local body = VerticalGroup:new{ align = "center" }

        if #entries == 0 then
            table.insert(body, makeMutedText(self:getTranslation("no_journal_results"), math.floor(iw * 0.88)))
        else
            local start_index = (state.page - 1) * per_page + 1
            local end_index = math.min(#entries, start_index + per_page - 1)
            local previous_month
            local item_height = math.max(72, math.floor(layout.safe_h * 0.075))

            for index = start_index, end_index do
                local entry = entries[index]
                local month_key = os.date("%m/%Y", entry.created_at or 0)
                if month_key ~= previous_month then
                    table.insert(body, TextWidget:new{
                        text = "— " .. month_key .. " —",
                        face = Font:getFace("x_smallinfofont"),
                        fgcolor = Blitbuffer.gray(0.48),
                        max_width = iw,
                        alignment = "center",
                    })
                    table.insert(body, VerticalSpan:new{ width = Size.span.vertical_small })
                    previous_month = month_key
                end

                table.insert(body, makeRoundedButton{
                    text = self:formatJournalListItem(entry),
                    width = iw,
                    height = item_height,
                    radius = getTarotButtonRadius(),
                    align = "left",
                    text_font_face = "smallinfofont",
                    text_font_size = 19,
                    text_font_bold = false,
                    callback = function()
                        self:closeJournalDialog()
                        self:showJournalEntry(entry)
                    end,
                    hold_callback = entry.entry_type ~= "legacy" and function()
                        entry.favorite = not entry.favorite
                        entry.updated_at = os.time()
                        if self:writeJournalEntry(entry) then
                            self:showSavedReadingsMenu(state.page)
                        else
                            UIManager:show(InfoMessage:new{
                                text = self:getTranslation("journal_save_error"),
                            })
                        end
                    end or nil,
                })
                table.insert(body, VerticalSpan:new{ width = Size.span.vertical_small })
            end
        end

        local nav_button_w = math.floor(iw * 0.23)
        local page_label_w = math.floor(iw * 0.32)
        local nav_row = HorizontalGroup:new{
            align = "center",
            makeRoundedButton{
                text = "‹", width = nav_button_w, enabled = state.page > 1,
                callback = function() self:showSavedReadingsMenu(state.page - 1) end,
            },
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            CenterContainer:new{
                dimen = Geom:new{ w = page_label_w, h = 40 },
                TextWidget:new{
                    text = string.format(self:getTranslation("page_count"), state.page, total_pages),
                    face = Font:getFace("smallinfofont"),
                    max_width = page_label_w,
                    alignment = "center",
                },
            },
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            makeRoundedButton{
                text = "›", width = nav_button_w, enabled = state.page < total_pages,
                callback = function() self:showSavedReadingsMenu(state.page + 1) end,
            },
        }

        local footer_content = VerticalGroup:new{ align = "center" }
        if #entries == 0 then
            table.insert(footer_content, makeRoundedButton{
                text = self:getTranslation("clear_filters"), width = math.floor(iw * 0.72),
                callback = function()
                    self:clearJournalFilters()
                    self:showSavedReadingsMenu(1)
                end,
            })
            table.insert(footer_content, VerticalSpan:new{ width = Size.span.vertical_default })
        end
        table.insert(footer_content, nav_row)

        self.journal_dialog = InputContainer:new{}
        self.journal_dialog.plugin = self
        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            header = header_w,
            body = body,
            footer = makeFullscreenFooter(iw, footer_content),
        }

        local overlay_buttons = {
            makeTopBackIconButton(self, layout, function()
                self:closeJournalDialog()
            end),
            makeFloatingIconButton{
                plugin = self,
                layout = layout,
                icon_name = "search",
                fallback_text = self:getTranslation("search"),
                slot = 0,
                callback = function()
                    self:closeJournalDialog()
                    self:showJournalSearchInput()
                end,
            },
            makeFloatingIconButton{
                plugin = self,
                layout = layout,
                icon_name = "pen",
                fallback_text = self:getTranslation("new_reflection"),
                slot = 1,
                callback = function()
                    self:closeJournalDialog()
                    self:showNewReflectionTitleInput()
                end,
            },
            makeFloatingIconButton{
                plugin = self,
                layout = layout,
                icon_name = "filter",
                fallback_text = self:getTranslation("filter"),
                side = "left",
                slot = 1,
                callback = function()
                    self:closeJournalDialog()
                    self:showJournalFilterMenu()
                end,
            },
            makeFloatingIconButton{
                plugin = self,
                layout = layout,
                fallback_text = "...",
                side = "left",
                slot = 2,
                callback = function()
                    self:closeJournalDialog()
                    self:showJournalMoreMenu()
                end,
            },
        }

        local layers = {
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
        }
        for _, overlay_button in ipairs(overlay_buttons) do
            table.insert(layers, overlay_button)
        end
        self.journal_dialog[1] = OverlapGroup:new(layers)

        addHorizontalSwipeNavigation(self.journal_dialog, "tarot_journal_swipe_nav",
            state.page > 1 and function() self:showSavedReadingsMenu(state.page - 1) end or nil,
            state.page < total_pages and function() self:showSavedReadingsMenu(state.page + 1) end or nil
        )
        UIManager:show(self.journal_dialog)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:showEmptyJournal()
        self:showSavedReadingsMenu(1)
    end

    function TarotPlugin:showJournalSearchInput()
        local dialog
        dialog = InputDialog:new{
            title = self:getTranslation("journal_search_title"),
            input = self.journal_state.query or "",
            input_hint = self:getTranslation("journal_search_hint"),
            input_type = "string",
            buttons = {
                {
                    {
                        text = self:getTranslation("clear_search"),
                        callback = function()
                            self.journal_state.query = ""
                            self.journal_state.page = 1
                            UIManager:close(dialog)
                            self:showSavedReadingsMenu(1)
                        end,
                    },
                    {
                        text = self:getTranslation("search"),
                        is_enter_default = true,
                        callback = function()
                            self.journal_state.query = journalTrim(dialog:getInputText())
                            self.journal_state.page = 1
                            UIManager:close(dialog)
                            self:showSavedReadingsMenu(1)
                        end,
                    },
                },
                {
                    {
                        text = self:getTranslation("cancel"),
                        callback = function()
                            UIManager:close(dialog)
                            self:showSavedReadingsMenu()
                        end,
                    },
                },
            },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end

    function TarotPlugin:showJournalFilterMenu(draft)
        local original = journalShallowCopy(self.journal_state)
        draft = draft or journalShallowCopy(self.journal_state)

        local deck_names = {
            all = self:getTranslation("all"),
            tarot = self:getTranslation("tarot_deck"),
            lenormand = self:getTranslation("lenormand_deck"),
        }
        local sort_names = {
            newest = self:getTranslation("newest_first"),
            oldest = self:getTranslation("oldest_first"),
            title = self:getTranslation("title_order"),
            edited = self:getTranslation("last_edited"),
        }
        local function checked(value)
            return value and "[✓] " or "[ ] "
        end
        local function reopen()
            self:showJournalFilterMenu(draft)
        end

        local buttons = {
            {
                {
                    text = string.format(self:getTranslation("deck_filter"), deck_names[draft.deck or "all"]),
                    close_before = true,
                    callback = function()
                        if draft.deck == "all" then draft.deck = "tarot"
                        elseif draft.deck == "tarot" then draft.deck = "lenormand"
                        else draft.deck = "all" end
                        reopen()
                    end,
                },
            },
            {
                {
                    text = checked(draft.types.spread) .. self:getTranslation("spread_entries"),
                    close_before = true,
                    callback = function() draft.types.spread = not draft.types.spread; reopen() end,
                },
                {
                    text = checked(draft.types.daily) .. self:getTranslation("daily_entries"),
                    close_before = true,
                    callback = function() draft.types.daily = not draft.types.daily; reopen() end,
                },
            },
            {
                {
                    text = checked(draft.types.free) .. self:getTranslation("free_entries"),
                    close_before = true,
                    callback = function() draft.types.free = not draft.types.free; reopen() end,
                },
                {
                    text = checked(draft.types.legacy) .. self:getTranslation("legacy_entries"),
                    close_before = true,
                    callback = function() draft.types.legacy = not draft.types.legacy; reopen() end,
                },
            },
            {
                {
                    text = checked(draft.favorites_only) .. self:getTranslation("favorites_only"),
                    close_before = true,
                    callback = function() draft.favorites_only = not draft.favorites_only; reopen() end,
                },
            },
            {
                {
                    text = string.format(self:getTranslation("sort_order"), sort_names[draft.sort or "newest"]),
                    close_before = true,
                    callback = function()
                        if draft.sort == "newest" then draft.sort = "oldest"
                        elseif draft.sort == "oldest" then draft.sort = "title"
                        elseif draft.sort == "title" then draft.sort = "edited"
                        else draft.sort = "newest" end
                        reopen()
                    end,
                },
            },
            {
                {
                    text = self:getTranslation("cancel"), footer = true, close_before = true,
                    callback = function()
                        self.journal_state = original
                        self:showSavedReadingsMenu()
                    end,
                },
                {
                    text = self:getTranslation("apply"), footer = true, close_before = true,
                    callback = function()
                        if not draft.types.spread and not draft.types.daily and not draft.types.free and not draft.types.legacy then
                            UIManager:show(InfoMessage:new{ text = self:getTranslation("select_entry_type") })
                            self:showJournalFilterMenu(draft)
                            return
                        end
                        draft.page = 1
                        self.journal_state = draft
                        self:showSavedReadingsMenu(1)
                    end,
                },
            },
        }

        self.journal_filter_dialog = FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("journal_filter_title"),
            buttons = buttons,
        }
        UIManager:show(self.journal_filter_dialog)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:clearJournalFilters()
        self.journal_state.query = ""
        self.journal_state.deck = "all"
        self.journal_state.types = { spread = true, daily = true, free = true, legacy = true }
        self.journal_state.favorites_only = false
        self.journal_state.sort = "newest"
        self.journal_state.month = nil
        self.journal_state.page = 1
    end

    function TarotPlugin:showJournalMoreMenu()
        local trash_entries = self:getJournalEntries(true)
        local trash_icon = #trash_entries > 0 and "trash-bin" or "trash-bin-empty"
        local buttons = {
            {
                { text = self:getTranslation("go_to_month"), icon_name = "calendar", close_before = true, callback = function() self:showJournalMonthInput() end },
                { text = self:getTranslation("journal_summary"), icon_name = "chart", close_before = true, callback = function() self:showJournalSummary() end },
            },
            {
                { text = self:getTranslation("trash"), icon_name = trash_icon, close_before = true, callback = function() self:showJournalTrash(1) end },
                { text = self:getTranslation("export_journal"), icon_name = "export", close_before = true, callback = function() self:exportJournal() end },
            },
            {
                { text = self:getTranslation("create_backup"), icon_name = "archive-up", close_before = true, callback = function() self:createJournalBackup() end },
                { text = self:getTranslation("restore_backup"), icon_name = "archive-down", close_before = true, callback = function() self:showJournalBackupsMenu() end },
            },
            {
                { text = self:getTranslation("clear_filters"), icon_name = "filter", close_before = true, callback = function() self:clearJournalFilters(); self:showSavedReadingsMenu(1) end },
            },
            {
                { text = self:getTranslation("back"), footer = true, close_before = true, callback = function() self:showSavedReadingsMenu() end },
            },
        }
        self.journal_more_dialog = FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("more"), buttons = buttons,
        }
        UIManager:show(self.journal_more_dialog)
    end

    function TarotPlugin:showJournalMonthInput()
        local dialog
        dialog = InputDialog:new{
            title = self:getTranslation("month_input_title"),
            input = self.journal_state.month or "",
            input_hint = self:getTranslation("month_input_hint"),
            input_type = "string",
            buttons = {
                {
                    {
                        text = self:getTranslation("clear_month"),
                        callback = function()
                            self.journal_state.month = nil
                            self.journal_state.page = 1
                            UIManager:close(dialog)
                            self:showSavedReadingsMenu(1)
                        end,
                    },
                    {
                        text = self:getTranslation("apply"), is_enter_default = true,
                        callback = function()
                            local value = journalTrim(dialog:getInputText())
                            local year, month = value:match("^(%d%d%d%d)%-(%d%d)$")
                            local month_number = tonumber(month)
                            if not year or not month_number or month_number < 1 or month_number > 12 then
                                UIManager:show(InfoMessage:new{ text = self:getTranslation("invalid_month") })
                                return
                            end
                            self.journal_state.month = value
                            self.journal_state.page = 1
                            UIManager:close(dialog)
                            self:showSavedReadingsMenu(1)
                        end,
                    },
                },
                {
                    { text = self:getTranslation("cancel"), callback = function() UIManager:close(dialog); self:showSavedReadingsMenu() end },
                },
            },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end

    function TarotPlugin:showJournalSummary()
        local entries = self:getJournalEntries(false)
        local tarot_count, lenormand_count, favorites, this_month = 0, 0, 0, 0
        local current_month = os.date("%Y-%m")
        local card_counts, card_names = {}, {}

        for _, entry in ipairs(entries) do
            if entry.deck == "tarot" then tarot_count = tarot_count + 1 end
            if entry.deck == "lenormand" then lenormand_count = lenormand_count + 1 end
            if entry.favorite then favorites = favorites + 1 end
            if os.date("%Y-%m", entry.created_at or 0) == current_month then this_month = this_month + 1 end
            for _, card_data in ipairs(entry.cards or {}) do
                local key = entry.deck .. ":" .. tostring(card_data.id)
                card_counts[key] = (card_counts[key] or 0) + 1
                local card = self:getJournalCard(entry, card_data)
                if card then card_names[key] = T(card.name) end
            end
        end

        local most_key, most_count
        for key, count in pairs(card_counts) do
            if not most_count or count > most_count then most_key, most_count = key, count end
        end

        local lines = {
            string.format(self:getTranslation("summary_total"), #entries),
            string.format(self:getTranslation("summary_tarot"), tarot_count),
            string.format(self:getTranslation("summary_lenormand"), lenormand_count),
            string.format(self:getTranslation("summary_this_month"), this_month),
            string.format(self:getTranslation("summary_favorites"), favorites),
            "",
        }
        if most_key then
            table.insert(lines, string.format(self:getTranslation("summary_most_frequent"), card_names[most_key] or "—", most_count))
        else
            table.insert(lines, self:getTranslation("summary_no_card"))
        end

        local layout = getFullscreenLayout()
        local iw = layout.content_w
        local dialog = InputContainer:new{}
        dialog.plugin = self
        local body = TextBoxWidget:new{
            text = table.concat(lines, "\n"),
            face = Font:getFace("cfont"),
            width = iw,
            alignment = "left",
        }
        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            title = self:getTranslation("journal_summary"),
            body = body,
        }
        dialog[1] = OverlapGroup:new{
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
            makeTopBackIconButton(self, layout, function()
                UIManager:close(dialog)
                self:showSavedReadingsMenu()
            end),
        }
        UIManager:show(dialog)
    end

    function TarotPlugin:formatJournalEntryText(entry)
        if entry.entry_type == "legacy" then
            return self:getTranslation("legacy_read_only") .. "\n\n" .. (entry.legacy_content or entry.note or "")
        end

        local lines = {
            self:getJournalDisplayTitle(entry),
            "",
            self:getTranslation("created_on") .. ": " .. os.date("%d/%m/%Y %H:%M", entry.created_at or 0),
        }
        if (entry.updated_at or 0) > (entry.created_at or 0) + 1 then
            table.insert(lines, self:getTranslation("updated_on") .. ": " .. os.date("%d/%m/%Y %H:%M", entry.updated_at))
        end
        local deck_text = self:getJournalDeckText(entry)
        local type_text = self:getJournalEntryTypeText(entry)
        if deck_text and deck_text ~= "" then
            table.insert(lines, deck_text .. " · " .. type_text)
        else
            table.insert(lines, type_text)
        end
        table.insert(lines, "")
        table.insert(lines, self:getTranslation("my_reflection"))
        table.insert(lines, "")
        if journalTrim(entry.note) ~= "" then
            table.insert(lines, entry.note)
        else
            -- Mantém a seção de reflexão disponível e visualmente vazia. O espaço
            -- não é preenchido por uma mensagem substituta nem comprimido.
            table.insert(lines, "")
            table.insert(lines, "")
            table.insert(lines, "")
        end

        -- Continuação construída abaixo; os campos acima são inseridos
        -- programaticamente para que a data de edição seja opcional.
        if journalTrim(entry.outcome) ~= "" then
            table.insert(lines, "")
            table.insert(lines, self:getTranslation("outcome_label"))
            table.insert(lines, "")
            table.insert(lines, entry.outcome)
            if (entry.outcome_at or 0) > 0 then
                table.insert(lines, "")
                table.insert(lines, os.date("%d/%m/%Y %H:%M", entry.outcome_at))
            end
        end

        if #(entry.cards or {}) > 0 then
            table.insert(lines, "")
            table.insert(lines, self:getTranslation("cards_label"))
            table.insert(lines, "")
            for index, card_data in ipairs(entry.cards) do
                local card = self:getJournalCard(entry, card_data)
                if card then
                    local position = card_data.is_reversed and self:getTranslation("reversed") or self:getTranslation("upright")
                    table.insert(lines, string.format("%d. %s — %s", index, T(card.name), position))
                end
            end
        end

        return table.concat(lines, "\n")
    end

    local JournalEditPopup = InputContainer:extend{
        plugin = nil,
        entry = nil,
        layout = nil,
        parent_dialog = nil,
        slot = 1,
        box = nil,
        box_x = 0,
        box_y = 0,
    }

    function JournalEditPopup:init()
        local layout = self.layout or getFullscreenLayout(0.94)
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
        local header_h = math.max(26, math.floor(touch_size * 0.60))
        local row_h = math.max(40, math.min(54, math.floor(layout.safe_h * 0.052)))

        self.box_x = layout.screen_w - layout.outer_pad - box_w - slot * (touch_size + gap)
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

        table.insert(content, CenterContainer:new{
            dimen = Geom:new{ w = inner_w, h = header_h },
            TextWidget:new{
                text = self.plugin:getTranslation("edit"),
                face = Font:getFace("x_smallinfofont"),
                bold = true,
                fgcolor = Blitbuffer.gray(0.45),
                max_width = inner_w,
                alignment = "center",
            },
        })
        cursor_y = cursor_y + header_h

        local function closePopupOnly()
            UIManager:close(self)
            setTarotDirty(self.plugin or self, "partial")
            return true
        end

        local function runEditAction(action)
            UIManager:close(self)
            if self.parent_dialog then
                pcall(function() UIManager:close(self.parent_dialog) end)
            end
            setTarotDirty(self.plugin or self)
            action()
            return true
        end

        local function addActionRow(text, action)
            action_index = action_index + 1
            local event_name = "TapJournalEditRow" .. tostring(action_index)
            table.insert(content, Button:new{
                text = text,
                width = inner_w,
                height = row_h,
                bordersize = 0,
                radius = 0,
                align = "left",
                padding_h = Size.padding.small,
                text_font_face = "x_smallinfofont",
                text_font_size = math.max(14, math.min(19, math.floor(row_h * 0.46))),
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
                return runEditAction(action)
            end
            cursor_y = cursor_y + row_h
        end

        addActionRow(self.plugin:getTranslation("edit_title"), function()
            self.plugin:showEditJournalTitle(self.entry)
        end)
        addActionRow(self.plugin:getTranslation("edit_reflection"), function()
            self.plugin:showEditJournalReflection(self.entry)
        end)
        addActionRow(
            journalTrim(self.entry and self.entry.outcome) == ""
                and self.plugin:getTranslation("add_outcome")
                or self.plugin:getTranslation("edit_outcome"),
            function()
                self.plugin:showEditJournalOutcome(self.entry)
            end
        )

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
            self["on" .. name] = closePopupOnly
        end

        addCloseRange("TapJournalEditCloseTop", 0, 0, layout.screen_w, self.box_y)
        addCloseRange("TapJournalEditCloseLeft", 0, self.box_y, self.box_x, box_h)
        addCloseRange(
            "TapJournalEditCloseRight",
            self.box_x + box_w,
            self.box_y,
            layout.screen_w - self.box_x - box_w,
            box_h
        )
        addCloseRange(
            "TapJournalEditCloseBottom",
            0,
            self.box_y + box_h,
            layout.screen_w,
            layout.screen_h - self.box_y - box_h
        )
    end

    function JournalEditPopup:paintTo(bb, x, y)
        if self.box then
            self.box:paintTo(bb, x + self.box_x, y + self.box_y)
        end
    end

    function TarotPlugin:showJournalEditPopup(entry, layout, parent_dialog, slot)
        UIManager:show(JournalEditPopup:new{
            plugin = self,
            entry = entry,
            layout = layout,
            parent_dialog = parent_dialog,
            slot = slot or 1,
        })
        setTarotDirty(self.plugin or self, "partial")
    end

    function TarotPlugin:showJournalEntry(entry)
        local layout = getFullscreenLayout(0.94)
        local iw = layout.content_w
        local dialog = InputContainer:new{}
        dialog.plugin = self

        local header_w = makeSectionHeader(self:getJournalDisplayTitle(entry), iw)
        local body_h = layout.safe_h
            - header_w:getSize().h
            - Size.span.vertical_default
        if body_h < 120 then
            body_h = math.max(80, math.floor(layout.safe_h * 0.55))
        end

        local body = ScrollTextWidget:new{
            text = self:formatJournalEntryText(entry),
            face = Font:getFace("smallinfofont"),
            width = iw,
            height = body_h,
            alignment = "left",
            scroll_by_pan = true,
            dialog = dialog,
        }

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            header = header_w,
            body = body,
        }

        local overlay_buttons = {
            makeTopBackIconButton(self, layout, function()
                UIManager:close(dialog)
                setTarotDirty(self.plugin or self)
                self:showSavedReadingsMenu()
            end),
        }
        local right_slot = 0
        local journal_pin_item = self:makeJournalPinItem(entry)
        if journal_pin_item then
            local is_pinned = self:isPinnedItem(journal_pin_item)
            table.insert(overlay_buttons, makeFloatingIconButton{
                plugin = self,
                layout = layout,
                icon_name = is_pinned and "pin-filled" or "pin",
                fallback_text = is_pinned and "●" or "○",
                side = "left",
                slot = 1,
                callback = function()
                    self:togglePinnedItem(journal_pin_item)
                    UIManager:close(dialog)
                    setTarotDirty(self.plugin or self)
                    self:showJournalEntry(entry)
                end,
            })
        end

        if entry.entry_type ~= "legacy" then
            table.insert(overlay_buttons, makeFloatingIconButton{
                plugin = self,
                layout = layout,
                icon_name = entry.favorite and "star-filled" or "star",
                fallback_text = entry.favorite and "★" or "☆",
                slot = right_slot,
                callback = function()
                    entry.favorite = not entry.favorite
                    entry.updated_at = os.time()
                    if self:writeJournalEntry(entry) then
                        UIManager:close(dialog)
                        setTarotDirty(self.plugin or self)
                        self:showJournalEntry(entry)
                    else
                        UIManager:show(InfoMessage:new{
                            text = self:getTranslation("journal_save_error"),
                        })
                    end
                end,
            })
            right_slot = right_slot + 1

            local edit_slot = right_slot
            table.insert(overlay_buttons, makeFloatingIconButton{
                plugin = self,
                layout = layout,
                icon_name = "pen",
                fallback_text = self:getTranslation("edit"),
                slot = edit_slot,
                callback = function()
                    self:showJournalEditPopup(entry, layout, dialog, edit_slot)
                end,
            })
            right_slot = right_slot + 1

            if #(entry.cards or {}) > 0 then
                table.insert(overlay_buttons, makeFloatingIconButton{
                    plugin = self,
                    layout = layout,
                    icon_name = "book-open",
                    fallback_text = self:getTranslation("view_cards"),
                    slot = right_slot,
                    callback = function()
                        UIManager:close(dialog)
                        setTarotDirty(self.plugin or self)
                        self:showJournalCards(entry)
                    end,
                })
                right_slot = right_slot + 1
            end
        end

        table.insert(overlay_buttons, makeFloatingIconButton{
            plugin = self,
            layout = layout,
            icon_name = "trash-bin",
            fallback_text = "!",
            slot = right_slot,
            callback = function()
                UIManager:close(dialog)
                setTarotDirty(self.plugin or self)
                self:confirmDeleteFile(entry)
            end,
        })
        right_slot = right_slot + 1

        local layers = {
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
        }
        for _, overlay_button in ipairs(overlay_buttons) do
            table.insert(layers, overlay_button)
        end
        dialog[1] = OverlapGroup:new(layers)
        UIManager:show(dialog)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:showEditJournalTitle(entry)
        local dialog
        dialog = InputDialog:new{
            title = self:getTranslation("edit_title"),
            input = entry.title or "",
            input_hint = self:getTranslation("reflection_title_hint"),
            buttons = {
                {
                    { text = self:getTranslation("cancel"), callback = function() UIManager:close(dialog); self:showJournalEntry(entry) end },
                    {
                        text = self:getTranslation("save"), is_enter_default = true,
                        callback = function()
                            entry.title = journalTrim(dialog:getInputText())
                            entry.updated_at = os.time()
                            if not self:writeJournalEntry(entry) then
                                UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_error") })
                                return
                            end
                            UIManager:close(dialog)
                            self:showJournalEntry(entry)
                        end,
                    },
                },
            },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end

    function TarotPlugin:showEditJournalReflection(entry)
        local dialog
        dialog = InputDialog:new{
            title = self:getTranslation("edit_reflection"),
            input = entry.note or "",
            input_hint = self:getTranslation("reflection_text_hint"),
            fullscreen = true,
            condensed = true,
            allow_newline = true,
            add_nav_bar = true,
            buttons = {
                {
                    { text = self:getTranslation("cancel"), callback = function() UIManager:close(dialog); self:showJournalEntry(entry) end },
                    {
                        text = self:getTranslation("save"),
                        callback = function()
                            entry.note = dialog:getInputText()
                            entry.updated_at = os.time()
                            if not self:writeJournalEntry(entry) then
                                UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_error") })
                                return
                            end
                            UIManager:close(dialog)
                            self:showJournalEntry(entry)
                        end,
                    },
                },
            },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end

    function TarotPlugin:showEditJournalOutcome(entry)
        local dialog
        dialog = InputDialog:new{
            title = journalTrim(entry.outcome) == "" and self:getTranslation("add_outcome") or self:getTranslation("edit_outcome"),
            input = entry.outcome or "",
            input_hint = self:getTranslation("outcome_text_hint"),
            fullscreen = true,
            condensed = true,
            allow_newline = true,
            add_nav_bar = true,
            buttons = {
                {
                    { text = self:getTranslation("cancel"), callback = function() UIManager:close(dialog); self:showJournalEntry(entry) end },
                    {
                        text = self:getTranslation("save"),
                        callback = function()
                            entry.outcome = dialog:getInputText()
                            entry.outcome_at = journalTrim(entry.outcome) ~= "" and os.time() or 0
                            entry.updated_at = os.time()
                            if not self:writeJournalEntry(entry) then
                                UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_error") })
                                return
                            end
                            UIManager:close(dialog)
                            self:showJournalEntry(entry)
                        end,
                    },
                },
            },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end

    function TarotPlugin:showNewReflectionTitleInput()
        local dialog
        dialog = InputDialog:new{
            title = self:getTranslation("reflection_title"),
            input_hint = self:getTranslation("reflection_title_hint"),
            input_type = "string",
            buttons = {
                {
                    { text = self:getTranslation("cancel"), callback = function() UIManager:close(dialog); self:showSavedReadingsMenu() end },
                    {
                        text = self:getTranslation("next"), is_enter_default = true,
                        callback = function()
                            local title = journalTrim(dialog:getInputText())
                            UIManager:close(dialog)
                            self:showNewReflectionEditor(title)
                        end,
                    },
                },
            },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end

    function TarotPlugin:showNewReflectionEditor(title)
        local dialog
        dialog = InputDialog:new{
            title = self:getTranslation("reflection_text"),
            input_hint = self:getTranslation("reflection_text_hint"),
            fullscreen = true,
            condensed = true,
            allow_newline = true,
            add_nav_bar = true,
            buttons = {
                {
                    { text = self:getTranslation("cancel"), callback = function() UIManager:close(dialog); self:showSavedReadingsMenu() end },
                    {
                        text = self:getTranslation("save_reflection"),
                        callback = function()
                            local now = os.time()
                            local entry = {
                                id = os.date("%Y%m%d-%H%M%S") .. "-" .. tostring(math.random(1000, 9999)),
                                created_at = now, updated_at = now,
                                entry_type = "free", deck = "none", spread_type = "",
                                title = title, note = dialog:getInputText(), outcome = "", outcome_at = 0,
                                favorite = false, cards = {},
                            }
                            if not self:writeJournalEntry(entry) then
                                UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_error") })
                                return
                            end
                            UIManager:close(dialog)
                            UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_success") })
                            self:showSavedReadingsMenu(1)
                        end,
                    },
                },
            },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end

    function TarotPlugin:showFileOptions(file)
        self:showJournalEntry(file)
    end

    function TarotPlugin:moveJournalEntryToTrash(entry)
        self:ensureJournalDirs()
        local target = journalUniquePath(self.journal_trash_dir, entry.filename or (entry.id .. ".trj"))
        local ok = os.rename(entry.filepath, target)
        if not ok then
            ok = journalCopyFile(entry.filepath, target)
            if ok then os.remove(entry.filepath) end
        end
        return ok == true
    end

    function TarotPlugin:confirmDeleteFile(entry)
        local dialog
        dialog = FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("delete_confirm"),
            buttons = {
                {
                    {
                        text = self:getTranslation("cancel"), footer = true, close_before = true,
                        callback = function() self:showJournalEntry(entry) end,
                    },
                    {
                        text = self:getTranslation("delete_reading"), footer = true, close_before = true,
                        callback = function()
                            if self:moveJournalEntryToTrash(entry) then
                                UIManager:show(InfoMessage:new{ text = self:getTranslation("delete_success") })
                                self:showSavedReadingsMenu()
                            else
                                UIManager:show(InfoMessage:new{ text = self:getTranslation("delete_error") })
                                self:showJournalEntry(entry)
                            end
                        end,
                    },
                },
            },
        }
        UIManager:show(dialog)
    end

    function TarotPlugin:showJournalTrash(page)
        local entries = self:getJournalEntries(true)
        table.sort(entries, function(a, b) return (a.updated_at or 0) > (b.updated_at or 0) end)
        local per_page = self:getJournalItemsPerPage()
        local total_pages = math.max(1, math.ceil(#entries / per_page))
        page = math.max(1, math.min(page or 1, total_pages))

        local buttons = {}
        local start_index = (page - 1) * per_page + 1
        local end_index = math.min(#entries, start_index + per_page - 1)
        for index = start_index, end_index do
            local entry = entries[index]
            table.insert(buttons, {
                {
                    -- Na lixeira, usamos uma linha compacta para evitar truncamento
                    -- nos botões do FullscreenMenuDialog em telas pequenas.
                    text = (entry.favorite and "★ " or "")
                        .. os.date("%d/%m/%Y", entry.created_at or 0)
                        .. " · " .. self:getJournalDisplayTitle(entry),
                    close_before = true,
                    callback = function() self:showTrashEntryOptions(entry, page) end,
                },
            })
        end
        if #entries == 0 then
            table.insert(buttons, {{ text = self:getTranslation("trash_empty"), enabled = false }})
        end
        table.insert(buttons, {
            {
                text = "‹", enabled = page > 1, footer = true, close_before = true,
                callback = function() self:showJournalTrash(page - 1) end,
            },
            {
                text = string.format(self:getTranslation("page_count"), page, total_pages), enabled = false, footer = true,
            },
            {
                text = "›", enabled = page < total_pages, footer = true, close_before = true,
                callback = function() self:showJournalTrash(page + 1) end,
            },
        })
        table.insert(buttons, {
            { text = self:getTranslation("back_to_journal"), footer = true, close_before = true, callback = function() self:showSavedReadingsMenu() end },
        })

        self.journal_trash_dialog = FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("trash_title"), buttons = buttons,
        }
        UIManager:show(self.journal_trash_dialog)
    end

    function TarotPlugin:showTrashEntryOptions(entry, page)
        local dialog
        dialog = FullscreenMenuDialog:new{
            plugin = self,
            title = self:getJournalDisplayTitle(entry),
            buttons = {
                {
                    {
                        text = self:getTranslation("restore_entry"), icon_name = "undo", close_before = true,
                        callback = function()
                            local target_dir = entry.entry_type == "legacy" and self.saves_dir or self.journal_dir
                            local target = journalUniquePath(target_dir, entry.filename)
                            local ok = os.rename(entry.filepath, target)
                            if not ok then ok = journalCopyFile(entry.filepath, target); if ok then os.remove(entry.filepath) end end
                            UIManager:show(InfoMessage:new{ text = ok and self:getTranslation("restore_success") or self:getTranslation("delete_error") })
                            self:showJournalTrash(page)
                        end,
                    },
                },
                {
                    {
                        text = self:getTranslation("delete_permanently"), icon_name = "trash-bin", close_before = true,
                        callback = function() self:confirmPermanentDelete(entry, page) end,
                    },
                },
                {
                    { text = self:getTranslation("back"), footer = true, close_before = true, callback = function() self:showJournalTrash(page) end },
                },
            },
        }
        UIManager:show(dialog)
    end

    function TarotPlugin:confirmPermanentDelete(entry, page)
        local dialog
        dialog = FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("delete_permanent_confirm"),
            buttons = {
                {
                    { text = self:getTranslation("cancel"), footer = true, close_before = true, callback = function() self:showTrashEntryOptions(entry, page) end },
                    {
                        text = self:getTranslation("delete_permanently"), footer = true, close_before = true,
                        callback = function()
                            local ok = os.remove(entry.filepath)
                            UIManager:show(InfoMessage:new{ text = ok and self:getTranslation("delete_permanent_success") or self:getTranslation("delete_error") })
                            self:showJournalTrash(page)
                        end,
                    },
                },
            },
        }
        UIManager:show(dialog)
    end

    function TarotPlugin:formatJournalMarkdown(entry)
        if entry.entry_type == "legacy" then
            return "# " .. self:getJournalDisplayTitle(entry) .. "\n\n" .. (entry.legacy_content or "") .. "\n"
        end
        local lines = {
            "# " .. self:getJournalDisplayTitle(entry),
            "",
            "**" .. self:getTranslation("created_on") .. ":** " .. os.date("%d/%m/%Y %H:%M", entry.created_at or 0),
        }
        local deck_text = self:getJournalDeckText(entry)
        if deck_text and deck_text ~= "" then
            table.insert(lines, "**" .. self:getTranslation("deck_type") .. ":** " .. deck_text)
        end
        table.insert(lines, "**" .. self:getTranslation("type_label") .. ":** " .. self:getJournalEntryTypeText(entry))
        table.insert(lines, "")
        table.insert(lines, "## " .. self:getTranslation("reflection_text"))
        table.insert(lines, "")
        table.insert(lines, entry.note or "")
        if journalTrim(entry.outcome) ~= "" then
            table.insert(lines, "")
            table.insert(lines, "## " .. self:getTranslation("outcome_text"))
            table.insert(lines, "")
            table.insert(lines, entry.outcome)
        end
        if #(entry.cards or {}) > 0 then
            table.insert(lines, "")
            table.insert(lines, "## " .. self:getTranslation("cards_label"))
            table.insert(lines, "")
            for index, card_data in ipairs(entry.cards) do
                local card = self:getJournalCard(entry, card_data)
                if card then
                    local position = card_data.is_reversed and self:getTranslation("reversed") or self:getTranslation("upright")
                    table.insert(lines, string.format("%d. %s — %s", index, T(card.name), position))
                end
            end
        end
        return table.concat(lines, "\n") .. "\n"
    end

    function TarotPlugin:exportJournal()
        self:ensureJournalDirs()
        local entries = self:getFilteredJournalEntries()
        local path = self.journal_export_dir .. "/diario-" .. os.date("%Y%m%d-%H%M%S") .. ".md"
        local chunks = { "# " .. self:getTranslation("saved_readings"), "" }
        for _, entry in ipairs(entries) do
            table.insert(chunks, self:formatJournalMarkdown(entry))
            table.insert(chunks, "\n---\n")
        end
        local ok = journalWriteAll(path, table.concat(chunks, "\n"))
        UIManager:show(InfoMessage:new{
            text = ok and string.format(self:getTranslation("export_success"), path) or self:getTranslation("export_error"),
        })
        self:showSavedReadingsMenu()
    end

    function TarotPlugin:createJournalBackup()
        self:ensureJournalDirs()
        local backup_path = self.journal_backup_dir .. "/" .. os.date("%Y%m%d-%H%M%S")
        local entries_path = backup_path .. "/entries"
        local legacy_path = backup_path .. "/legacy"
        local trash_path = backup_path .. "/trash"
        local ok = lfs.mkdir(backup_path)
        if ok then ok = lfs.mkdir(entries_path) and lfs.mkdir(legacy_path) and lfs.mkdir(trash_path) end

        local function copy_matching(source, target, pattern)
            if not ok or not lfs.attributes(source) then return end
            for filename in lfs.dir(source) do
                if filename ~= "." and filename ~= ".." and filename:match(pattern) then
                    local attr = lfs.attributes(source .. "/" .. filename)
                    if attr and attr.mode == "file" and not journalCopyFile(source .. "/" .. filename, target .. "/" .. filename) then
                        ok = false
                        return
                    end
                end
            end
        end

        copy_matching(self.journal_dir, entries_path, "%.trj$")
        copy_matching(self.saves_dir, legacy_path, "%.txt$")
        copy_matching(self.journal_trash_dir, trash_path, ".+")

        UIManager:show(InfoMessage:new{
            text = ok and string.format(self:getTranslation("backup_success"), backup_path) or self:getTranslation("backup_error"),
        })
        self:showSavedReadingsMenu()
    end

    function TarotPlugin:getJournalBackups()
        self:ensureJournalDirs()
        local backups = {}
        for name in lfs.dir(self.journal_backup_dir) do
            if name ~= "." and name ~= ".." then
                local path = self.journal_backup_dir .. "/" .. name
                local attr = lfs.attributes(path)
                if attr and attr.mode == "directory" then
                    table.insert(backups, { name = name, path = path, modification = attr.modification or 0 })
                end
            end
        end
        table.sort(backups, function(a, b) return a.modification > b.modification end)
        return backups
    end

    function TarotPlugin:showJournalBackupsMenu()
        local backups = self:getJournalBackups()
        local buttons = {}
        for _, backup in ipairs(backups) do
            table.insert(buttons, {{
                text = backup.name, close_before = true,
                callback = function() self:restoreJournalBackup(backup) end,
            }})
        end
        if #backups == 0 then
            table.insert(buttons, {{ text = self:getTranslation("no_backups"), enabled = false }})
        end
        table.insert(buttons, {{ text = self:getTranslation("back"), footer = true, close_before = true, callback = function() self:showSavedReadingsMenu() end }})
        self.journal_backup_dialog = FullscreenMenuDialog:new{
            plugin = self,
            title = self:getTranslation("restore_backup"), buttons = buttons,
        }
        UIManager:show(self.journal_backup_dialog)
    end

    function TarotPlugin:restoreJournalBackup(backup)
        local ok = true
        local function restore_dir(source, target, pattern)
            if not lfs.attributes(source) then return end
            for filename in lfs.dir(source) do
                if filename ~= "." and filename ~= ".." and filename:match(pattern) then
                    local source_path = source .. "/" .. filename
                    local attr = lfs.attributes(source_path)
                    if attr and attr.mode == "file" then
                        local target_path = journalUniquePath(target, filename)
                        if not journalCopyFile(source_path, target_path) then ok = false end
                    end
                end
            end
        end
        restore_dir(backup.path .. "/entries", self.journal_dir, "%.trj$")
        restore_dir(backup.path .. "/legacy", self.saves_dir, "%.txt$")
        restore_dir(backup.path .. "/trash", self.journal_trash_dir, ".+")
        UIManager:show(InfoMessage:new{ text = ok and self:getTranslation("backup_restored") or self:getTranslation("backup_error") })
        self:showSavedReadingsMenu(1)
    end

    function TarotPlugin:clearDirectoryRecursive(path, keep_root)
        local attr = path and lfs.attributes(path)
        if not attr or attr.mode ~= "directory" then return true end
        local ok = true
        for name in lfs.dir(path) do
            if name ~= "." and name ~= ".." then
                local child = path .. "/" .. name
                local child_attr = lfs.attributes(child)
                if child_attr and child_attr.mode == "directory" then
                    if not self:clearDirectoryRecursive(child, false) then ok = false end
                elseif not os.remove(child) then
                    ok = false
                end
            end
        end
        if not keep_root and not lfs.rmdir(path) then ok = false end
        return ok
    end

    function TarotPlugin:showSaveTitleInput(cards, entry_type, on_saved)
        local title_input
        title_input = InputDialog:new{
            title = self:getTranslation("save_title"),
            input_hint = self:getTranslation("save_title_hint"),
            input_type = "string",
            buttons = {
                {
                    {
                        text = self:getTranslation("cancel"),
                        callback = function() UIManager:close(title_input) end,
                    },
                    {
                        text = self:getTranslation("next"),
                        is_enter_default = true,
                        callback = function()
                            local title = journalTrim(title_input:getInputText())
                            UIManager:close(title_input)
                            self:showSaveNoteInput(cards, title, entry_type or "spread", on_saved)
                        end,
                    },
                },
            },
        }
        UIManager:show(title_input)
        title_input:onShowKeyboard()
    end

    function TarotPlugin:showSaveNoteInput(cards, title, entry_type, on_saved)
        local note_input
        note_input = InputDialog:new{
            title = self:getTranslation("save_note"),
            input_hint = self:getTranslation("save_note_hint"),
            fullscreen = true,
            condensed = true,
            allow_newline = true,
            add_nav_bar = true,
            buttons = {
                {
                    {
                        text = self:getTranslation("cancel"),
                        callback = function() UIManager:close(note_input) end,
                    },
                    {
                        text = self:getTranslation("save"),
                        callback = function()
                            local note = note_input:getInputText()
                            if self:saveReading(cards, title, note, entry_type or "spread") then
                                UIManager:close(note_input)
                                if type(on_saved) == "function" then
                                    on_saved()
                                end
                            end
                        end,
                    },
                },
            },
        }
        UIManager:show(note_input)
        note_input:onShowKeyboard()
    end


    -- Abre as cartas de um registro em modo somente leitura. Tiragens montadas na
    -- grade 4×4 são reabertas no layout original; registros antigos continuam com
    -- a navegação linear pelas miniaturas laterais.
    function TarotPlugin:showJournalCards(entry)
        local cards = {}
        local has_custom_slot = false
        local position_names = entry.position_names or {}

        for _, saved_card in ipairs(entry.cards or {}) do
            local card = self:getJournalCard(entry, saved_card)
            if card then
                local slot = tonumber(saved_card.grid_slot)
                if slot and slot >= 1 and slot <= 16 then
                    has_custom_slot = true
                end
                table.insert(cards, {
                    card = card,
                    is_reversed = saved_card.is_reversed == true,
                    is_revealed = true,
                    grid_slot = slot,
                    position_name = slot and position_names[slot] or nil,
                })
            end
        end

        if #cards == 0 then
            self:showJournalEntry(entry)
            return
        end

        local function returnToJournalEntry()
            self:showJournalEntry(entry)
        end

        if entry.layout_mode == "custom" and has_custom_slot then
            UIManager:show(HiddenCardDialog:new{
                plugin = self,
                cards = cards,
                position_names = position_names,
                title_label = self:getJournalDisplayTitle(entry),
                read_only = true,
                allow_add_card = false,
                deck_is_lenormand = entry.deck == "lenormand",
                on_close = returnToJournalEntry,
            })
        else
            UIManager:show(CardDialog:new{
                cards = cards,
                current_index = 1,
                plugin = self,
                title_label = self:getJournalDisplayTitle(entry),
                read_only = true,
                deck_is_lenormand = entry.deck == "lenormand",
                on_close = returnToJournalEntry,
            })
        end
        setTarotDirty(self.plugin or self)
    end


end

return M

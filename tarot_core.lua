-- Núcleo do plugin: inicialização, preferências, sorteio e restauração.

local CheckButton = require("ui/widget/checkbutton")
local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")

local M = {}

function M.register(deps)
    deps = deps or {}
    local TarotPlugin = assert(deps.TarotPlugin, "TarotPlugin is required")
    local T = assert(deps.T, "translator is required")
    local UI_TEXT = assert(deps.UI_TEXT, "UI_TEXT is required")
    local PLUGIN_DIR = assert(deps.PLUGIN_DIR, "PLUGIN_DIR is required")
    local MAJOR_ARCANA = assert(deps.MAJOR_ARCANA, "MAJOR_ARCANA is required")
    local FULL_DECK = assert(deps.FULL_DECK, "FULL_DECK is required")
    local LENORMAND_DECK = assert(deps.LENORMAND_DECK, "LENORMAND_DECK is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")
    local isPluginLanguageEnglish = assert(deps.isPluginLanguageEnglish, "isPluginLanguageEnglish is required")
    local getTranslatedFallback = assert(deps.getTranslatedFallback, "getTranslatedFallback is required")

    -- Inicializa o gerador pseudoaleatório uma única vez por carregamento do
    -- plugin. Usar apenas os.time() podia repetir exatamente a mesma sequência
    -- quando o KOReader ou o plugin eram reabertos dentro do mesmo segundo.
    local random_seeded = false
    local function seedRandomOnce()
        if random_seeded then return end

        local wall_time = os.time() or 0
        local cpu_ticks = math.floor((os.clock() or 0) * 1000000)
        local address_hex = tostring({}):match("0x(%x+)")
        local address_entropy = tonumber(address_hex or "0", 16) or 0
        local modulus = 2147483647
        local seed = (
            (wall_time % modulus)
            + (cpu_ticks % modulus) * 97
            + (address_entropy % modulus) * 131
        ) % modulus
        if seed <= 0 then seed = wall_time % modulus end
        if seed <= 0 then seed = 1 end

        math.randomseed(seed)
        -- Descarta os primeiros valores, que podem ter correlação maior em
        -- implementações antigas de libc/Lua usadas por alguns dispositivos.
        for _ = 1, 4 do math.random() end
        random_seeded = true
    end

    function TarotPlugin:init()
        seedRandomOnce()

        -- Recarrega o catálogo ao abrir o plugin. Isso cobre o caso em que o
        -- usuário troca o idioma do KOReader e reabre o plugin na mesma sessão.
        if type(T.reload) == "function" then
            T.reload()
            self.fullname = T(UI_TEXT.title)
        end

        self.ui.menu:registerToMainMenu(self)
        self.plugin_dir = self:getPluginDirectory()
        self.saves_dir = self.plugin_dir .. "/tiragens_salvas"
        self.journal_dir = self.plugin_dir .. "/diario_reflexoes"
        self.journal_trash_dir = self.journal_dir .. "/lixeira"
        self.journal_export_dir = self.journal_dir .. "/exportacoes"
        self.journal_backup_dir = self.journal_dir .. "/backups"
        -- Significados pessoais adicionados a partir de grifos ficam em um único
        -- arquivo simples na raiz do plugin. Assim evitamos criar mais pastas e
        -- mantemos a instalação fácil de copiar no Kindle.
        self.custom_meanings_path = self.plugin_dir .. "/significados_cartas.trcm"
        self.pinlist_path = self.plugin_dir .. "/marcados.trpins"
        self.journal_state = {
            page = 1,
            query = "",
            deck = "all",
            types = { spread = true, daily = true, free = true, legacy = true },
            favorites_only = false,
            sort = "newest",
            month = nil,
        }
        self.allow_reversed = G_reader_settings:readSetting("tarot_allow_reversed")
        if self.allow_reversed == nil then
            self.allow_reversed = true
        end
        self.major_only = G_reader_settings:readSetting("tarot_major_only")
        if self.major_only == nil then
            self.major_only = false
        end
        self.use_lenormand = G_reader_settings:readSetting("tarot_use_lenormand")
        if self.use_lenormand == nil then
            self.use_lenormand = false
        end
        self.daily_card_deck_mode = G_reader_settings:readSetting("tarot_daily_deck_mode")
        if self.daily_card_deck_mode ~= "tarot"
            and self.daily_card_deck_mode ~= "lenormand"
            and self.daily_card_deck_mode ~= "either" then
            -- A Carta Diária escolhe um dos dois baralhos por padrão. A escolha
            -- fica estável durante todo o dia e é independente das tiragens.
            self.daily_card_deck_mode = "either"
        end

        self.hide_daily_card_name = G_reader_settings:readSetting("tarot_hide_daily_card_name")
        if self.hide_daily_card_name == nil then
            -- Em inglês, o nome pode aparecer diretamente na própria arte da carta.
            -- Por isso, instalações novas em inglês ocultam o rótulo por padrão.
            self.hide_daily_card_name = isPluginLanguageEnglish()
        end

        self.daily_card_always_revealed = G_reader_settings:readSetting("tarot_daily_card_always_revealed")
        if self.daily_card_always_revealed == nil then
            self.daily_card_always_revealed = false
        end

        self.spread_cards_always_revealed = G_reader_settings:readSetting("tarot_spread_cards_always_revealed")
        if self.spread_cards_always_revealed == nil then
            self.spread_cards_always_revealed = false
        end

        self.show_only_custom_meanings = G_reader_settings:readSetting("tarot_show_only_custom_meanings")
        if self.show_only_custom_meanings == nil then
            self.show_only_custom_meanings = false
        end

        -- A antiga opção booleana de ocultar significados é migrada para um
        -- seletor com três estados: completo, resumido e oculto.
        local old_disable_meanings = G_reader_settings:readSetting("tarot_disable_spread_meanings")
        self.spread_meaning_mode = G_reader_settings:readSetting("tarot_spread_meaning_mode")
        if self.spread_meaning_mode ~= "full"
            and self.spread_meaning_mode ~= "summary"
            and self.spread_meaning_mode ~= "hidden" then
            self.spread_meaning_mode = old_disable_meanings == true and "hidden" or "full"
        end
        self.disable_spread_meanings = self.spread_meaning_mode == "hidden"

        self.disable_view_in_book = G_reader_settings:readSetting("tarot_disable_view_in_book")
        if self.disable_view_in_book == nil then
            self.disable_view_in_book = false
        end

        self.auto_save_spreads = G_reader_settings:readSetting("tarot_auto_save_spreads")
        if self.auto_save_spreads == nil then
            self.auto_save_spreads = false
        end

        self.disable_unsaved_close_warning = G_reader_settings:readSetting("tarot_disable_unsaved_close_warning")
        if self.disable_unsaved_close_warning == nil then
            self.disable_unsaved_close_warning = false
        end

        self.show_reversed_label = G_reader_settings:readSetting("tarot_show_reversed_label")
        if self.show_reversed_label == nil then
            self.show_reversed_label = true
        end

        self.meaning_text_size = G_reader_settings:readSetting("tarot_meaning_text_size")
        if self.meaning_text_size ~= "compact"
            and self.meaning_text_size ~= "standard"
            and self.meaning_text_size ~= "large" then
            self.meaning_text_size = "standard"
        end

        self.screen_refresh_mode = G_reader_settings:readSetting("tarot_screen_refresh_mode")
        if self.screen_refresh_mode ~= "standard"
            and self.screen_refresh_mode ~= "smooth"
            and self.screen_refresh_mode ~= "clean" then
            self.screen_refresh_mode = "smooth"
        end
        -- A Carta Oculta agora é parte obrigatória do fluxo de tiragem. A antiga
        -- preferência é removida para que instalações atualizadas não preservem
        -- silenciosamente o estado desativado de versões anteriores.
        self.hidden_card = true
        G_reader_settings:delSetting("tarot_hidden_card")

        -- Evita repetir avisos a cada reconstrução de tela durante a mesma sessão.
        -- Se o usuário não marcar "não mostrar novamente", eles voltam apenas na
        -- próxima abertura do plugin.
        self.card_dialog_hint_shown_this_session = false
        self.physical_deck_hint_shown_this_session = false
        self.hidden_grid_hint_v2_shown_this_session = false
        self.next_card_reveal_hint_shown_this_session = false
    
        self:ensureSavesDir()
        self:ensureJournalDirs()

        -- Integra o plugin ao menu de seleção/grifo do leitor quando esse módulo
        -- estiver disponível. Em alguns ciclos de inicialização, o ReaderHighlight
        -- ainda pode não estar pronto; nesse caso tentamos novamente no pós-init.
        if not self:registerHighlightMeaningAction()
            and self.ui
            and type(self.ui.registerPostInitCallback) == "function" then
            self.ui:registerPostInitCallback(function()
                self:registerHighlightMeaningAction()
            end)
        end
    end

    function TarotPlugin:getTranslation(key)
        local msgid = UI_TEXT[key]
        if not msgid then
            logger.warn("tarot.koplugin: chave de tradução desconhecida:", tostring(key))
            return tostring(key)
        end
        local translated = T(msgid)
        if translated == msgid then
            local fallback = getTranslatedFallback(key)
            if fallback then
                return fallback
            end
        end
        return translated
    end

    function TarotPlugin:refreshMenu()
        self.ui.menu:registerToMainMenu(self)
    end

    function TarotPlugin:getPluginDirectory()
        if self.path then return self.path end
        if PLUGIN_DIR then return PLUGIN_DIR end
        local source = debug.getinfo(1, "S").source
        if source and source:match("^@") then
            local dir = source:match("^@(.*/)main%.lua$") or source:match("^@(.*/)[^/]+$")
            if dir then return dir end
        end
        local ok, DataStorage = pcall(require, "datastorage")
        if ok and DataStorage then
            return DataStorage:getDataDir() .. "/plugins/tarot.koplugin"
        end
        return "./plugins/tarot.koplugin"
    end

    function TarotPlugin:ensureSavesDir()
        local attr = lfs.attributes(self.saves_dir)
        if not attr then
            local success = lfs.mkdir(self.saves_dir)
            if not success then
                logger.warn("tarot.koplugin: Não foi possível criar o diretório de tiragens salvas:", self.saves_dir)
            end
        end
    end

    -- Cria separadamente o armazenamento estruturado do Diário, a lixeira,
    -- exportações e backups. Cada registro permanece em seu próprio arquivo para
    -- que uma eventual corrupção nunca comprometa o Diário inteiro.
    function TarotPlugin:ensureJournalDirs()
        local dirs = {
            self.journal_dir,
            self.journal_trash_dir,
            self.journal_export_dir,
            self.journal_backup_dir,
        }
        for _, dir in ipairs(dirs) do
            if dir and not lfs.attributes(dir) then
                local ok = lfs.mkdir(dir)
                if not ok then
                    logger.warn("tarot.koplugin: não foi possível criar diretório do Diário:", dir)
                end
            end
        end
    end

    function TarotPlugin:getActiveDeck()
        if self.use_lenormand then
            return LENORMAND_DECK
        end
        if self.major_only then
            return MAJOR_ARCANA
        end
        return FULL_DECK
    end

    function TarotPlugin:drawCard()
        local deck = self:getActiveDeck()
        local card = deck[math.random(1, #deck)]
        local is_reversed = false
        if self.allow_reversed and not self.use_lenormand then
            is_reversed = math.random(2) == 1
        end
        return card, is_reversed
    end

    function TarotPlugin:drawUniqueCards(count)
        local deck = self:getActiveDeck()
        local selected_cards = {}
        count = math.max(0, math.min(tonumber(count) or 0, #deck))

        -- Embaralhamento parcial de Fisher–Yates: garante término, ausência de
        -- repetição e a mesma probabilidade para cada carta e ordem possível.
        local indices = {}
        for index = 1, #deck do indices[index] = index end

        for position = 1, count do
            local random_position = math.random(position, #deck)
            indices[position], indices[random_position] = indices[random_position], indices[position]

            local card = deck[indices[position]]
            local is_reversed = false
            if self.allow_reversed and not self.use_lenormand then
                is_reversed = math.random(2) == 1
            end
            selected_cards[position] = { card = card, is_reversed = is_reversed }
        end

        return selected_cards
    end

    -- Sorteia uma carta que ainda não pertence à tiragem atual. A comparação usa
    -- a própria tabela da carta, evitando colisões entre identificadores de Tarot
    -- e Lenormand. Retorna nil somente quando não existem cartas disponíveis.
    function TarotPlugin:drawAdditionalUniqueCard(existing_cards)
        local deck = self:getActiveDeck()
        local used = {}
        for _, item in ipairs(existing_cards or {}) do
            if item and item.card then
                used[item.card] = true
            end
        end

        local available = {}
        for _, card in ipairs(deck) do
            if not used[card] then
                table.insert(available, card)
            end
        end

        if #available == 0 then return nil end

        local card = available[math.random(1, #available)]
        local is_reversed = false
        if self.allow_reversed and not self.use_lenormand then
            is_reversed = math.random(2) == 1
        end

        return { card = card, is_reversed = is_reversed }
    end

    function TarotPlugin:toggleReversed()
        self.allow_reversed = not self.allow_reversed
        G_reader_settings:saveSetting("tarot_allow_reversed", self.allow_reversed)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:toggleMajorOnly()
        self.major_only = not self.major_only
        G_reader_settings:saveSetting("tarot_major_only", self.major_only)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:setReadingDeck(use_lenormand)
        self.use_lenormand = use_lenormand == true
        G_reader_settings:saveSetting("tarot_use_lenormand", self.use_lenormand)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:toggleLenormand()
        self:setReadingDeck(not self.use_lenormand)
    end

    function TarotPlugin:setDailyCardDeckMode(mode)
        if mode ~= "tarot" and mode ~= "lenormand" and mode ~= "either" then
            return
        end
        self.daily_card_deck_mode = mode
        G_reader_settings:saveSetting("tarot_daily_deck_mode", mode)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:setHideDailyCardName(hide_name)
        self.hide_daily_card_name = hide_name == true
        G_reader_settings:saveSetting("tarot_hide_daily_card_name", self.hide_daily_card_name)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:toggleHideDailyCardName()
        self:setHideDailyCardName(not self.hide_daily_card_name)
    end

    function TarotPlugin:toggleDailyCardAlwaysRevealed()
        self.daily_card_always_revealed = not self.daily_card_always_revealed
        G_reader_settings:saveSetting(
            "tarot_daily_card_always_revealed",
            self.daily_card_always_revealed
        )
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:toggleSpreadCardsAlwaysRevealed()
        self.spread_cards_always_revealed = not self.spread_cards_always_revealed
        G_reader_settings:saveSetting(
            "tarot_spread_cards_always_revealed",
            self.spread_cards_always_revealed
        )
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:toggleShowOnlyCustomMeanings()
        self.show_only_custom_meanings = not self.show_only_custom_meanings
        G_reader_settings:saveSetting(
            "tarot_show_only_custom_meanings",
            self.show_only_custom_meanings
        )
        setTarotDirty(self.plugin or self)
    end

    -- Resolve o baralho da Carta Diária sem alterar o baralho escolhido para as
    -- tiragens. No modo "either", a escolha é sorteada uma única vez por data.
    function TarotPlugin:getDailyCardDeckChoice(today)
        local mode = self.daily_card_deck_mode or "either"
        if mode == "tarot" then return false end
        if mode == "lenormand" then return true end

        today = today or self:getCurrentDateStr()
        local date_key = "tarot_daily_deck_choice_date"
        local deck_key = "tarot_daily_deck_choice_is_lenormand"
        local stored_date = G_reader_settings:readSetting(date_key) or ""
        local stored_choice = G_reader_settings:readSetting(deck_key)

        if stored_date == today and type(stored_choice) == "boolean" then
            return stored_choice
        end

        local use_lenormand = math.random(2) == 2
        G_reader_settings:saveSetting(date_key, today)
        G_reader_settings:saveSetting(deck_key, use_lenormand)
        return use_lenormand
    end

    function TarotPlugin:setSpreadMeaningMode(mode)
        if mode ~= "full" and mode ~= "summary" and mode ~= "hidden" then
            return
        end
        self.spread_meaning_mode = mode
        self.disable_spread_meanings = mode == "hidden"
        G_reader_settings:saveSetting("tarot_spread_meaning_mode", mode)
        -- Mantém a chave antiga sincronizada para facilitar eventual downgrade.
        G_reader_settings:saveSetting("tarot_disable_spread_meanings", self.disable_spread_meanings)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:toggleSpreadMeanings()
        self:setSpreadMeaningMode(self.spread_meaning_mode == "hidden" and "full" or "hidden")
    end

    function TarotPlugin:setMeaningTextSize(size)
        if size ~= "compact" and size ~= "standard" and size ~= "large" then
            return
        end
        self.meaning_text_size = size
        G_reader_settings:saveSetting("tarot_meaning_text_size", size)
        setTarotDirty(self)
    end

    function TarotPlugin:setScreenRefreshMode(mode)
        if mode ~= "standard" and mode ~= "smooth" and mode ~= "clean" then
            return
        end
        self.screen_refresh_mode = mode
        G_reader_settings:saveSetting("tarot_screen_refresh_mode", mode)
        setTarotDirty(self)
    end

    function TarotPlugin:toggleShowReversedLabel()
        self.show_reversed_label = not self.show_reversed_label
        G_reader_settings:saveSetting("tarot_show_reversed_label", self.show_reversed_label)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:toggleAutoSaveSpreads()
        self.auto_save_spreads = not self.auto_save_spreads
        G_reader_settings:saveSetting("tarot_auto_save_spreads", self.auto_save_spreads)
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:toggleUnsavedCloseWarning()
        self.disable_unsaved_close_warning = not self.disable_unsaved_close_warning
        G_reader_settings:saveSetting(
            "tarot_disable_unsaved_close_warning",
            self.disable_unsaved_close_warning
        )
        setTarotDirty(self.plugin or self)
    end

    function TarotPlugin:toggleViewInBookButton()
        self.disable_view_in_book = not self.disable_view_in_book
        G_reader_settings:saveSetting("tarot_disable_view_in_book", self.disable_view_in_book)
        setTarotDirty(self.plugin or self)
    end

    -- Exibe uma orientação com caixa de seleção e um único botão "Confirmar".
    -- A preferência só é gravada quando o usuário marca explicitamente
    -- "Não mostrar novamente" antes de confirmar.
    --
    -- Quando session_field é informado, cada orientação aparece apenas uma vez
    -- por abertura do plugin. Quando session_field é nil, o aviso reaparece em
    -- novas entradas até que o usuário marque “Não mostrar novamente”.
    function TarotPlugin:showDismissibleHint(setting_key, session_field, message_key, after_close_callback)
        local function runAfterClose()
            if type(after_close_callback) == "function" then
                UIManager:scheduleIn(0.1, after_close_callback)
            end
        end

        if G_reader_settings:readSetting(setting_key) == true then
            runAfterClose()
            return
        end
        if session_field and self[session_field] == true then
            runAfterClose()
            return
        end

        if session_field then
            self[session_field] = true
        end

        local checkbox
        local hint = ConfirmBox:new{
            text = self:getTranslation(message_key),
            -- ConfirmBox sempre cria primeiro o botão de cancelamento. Usamos esse
            -- único botão como "Confirmar" e removemos o botão OK, garantindo uma
            -- única ação centralizada no rodapé do aviso.
            cancel_text = self:getTranslation("confirm"),
            no_ok_button = true,
            dismissable = false,
            flush_events_on_show = true,
            cancel_callback = function()
                if checkbox and checkbox.checked == true then
                    G_reader_settings:saveSetting(setting_key, true)
                end
                runAfterClose()
            end,
        }
        checkbox = CheckButton:new{
            text = self:getTranslation("do_not_show_again"),
            parent = hint,
            checked = false,
        }
        hint:addWidget(checkbox)
        UIManager:show(hint)
    end

    function TarotPlugin:showCardDialogNavigationHint()
        self:showDismissibleHint(
            "tarot_card_dialog_navigation_hint_dismissed",
            "card_dialog_hint_shown_this_session",
            "card_dialog_navigation_hint"
        )
    end

    function TarotPlugin:showPhysicalDeckReverseHint()
        self:showDismissibleHint(
            "tarot_physical_deck_reverse_hint_dismissed",
            "physical_deck_hint_shown_this_session",
            "physical_deck_reverse_hint"
        )
    end

    -- Orientações de revelação exibidas como avisos descartáveis. Elas não ocupam
    -- espaço permanente nas telas e cada uma possui sua própria preferência.
    function TarotPlugin:showHiddenCardRevealHint()
        self:showDismissibleHint(
            "tarot_hidden_grid_hint_v2_dismissed",
            "hidden_grid_hint_v2_shown_this_session",
            "click_card_to_reveal"
        )
    end

    function TarotPlugin:showNextCardRevealHint()
        self:showDismissibleHint(
            "tarot_next_card_reveal_hint_dismissed",
            "next_card_reveal_hint_shown_this_session",
            "click_next_card_to_reveal"
        )
    end

    function TarotPlugin:showCustomMeaningEditorHint(after_close_callback)
        -- Este aviso é chamado quando o usuário entra no editor manual de
        -- significados. Diferente dos avisos de uso da grade, ele NÃO deve ser
        -- limitado a uma única vez por sessão: se o usuário não marcar
        -- "Não mostrar novamente", precisa aparecer novamente na próxima entrada.
        self:showDismissibleHint(
            "tarot_custom_meaning_editor_hint_dismissed",
            nil,
            "custom_meaning_editor_hint",
            after_close_callback
        )
    end

    function TarotPlugin:restoreAll()
        -- Todas as chaves persistentes utilizadas pelo plugin, incluindo opções
        -- removidas em versões anteriores e avisos exibidos uma única vez.
        local setting_keys = {
            "tarot_allow_reversed",
            "tarot_major_only",
            "tarot_use_lenormand",
            "tarot_daily_deck_mode",
            "tarot_hide_daily_card_name",
            "tarot_daily_card_always_revealed",
            "tarot_daily_deck_choice_date",
            "tarot_daily_deck_choice_is_lenormand",
            "tarot_disable_spread_meanings",
            "tarot_spread_meaning_mode",
            "tarot_disable_view_in_book",
            "tarot_spread_cards_always_revealed",
            "tarot_show_only_custom_meanings",
            "tarot_auto_save_spreads",
            "tarot_disable_unsaved_close_warning",
            "tarot_show_reversed_label",
            "tarot_meaning_text_size",
            "tarot_screen_refresh_mode",
            "tarot_hidden_card",
            "tarot_physical_deck_reverse_hint_seen",
            "tarot_physical_deck_reverse_hint_dismissed",
            "tarot_card_dialog_navigation_hint_dismissed",
            "tarot_hidden_card_reveal_hint_dismissed",
            "tarot_hidden_grid_hint_v2_dismissed",
            "tarot_next_card_reveal_hint_dismissed",
            "tarot_custom_meaning_editor_hint_dismissed",
            "tarot_daily_date",
            "tarot_daily_card_id",
            "tarot_daily_card_is_reversed",
            "tarot_daily_is_reversed",
            "tarot_daily_revealed_date",
            "tarot_daily_card_is_lenormand",
            "lenormand_daily_date",
            "lenormand_daily_card_id",
            "lenormand_daily_card_is_reversed",
            "lenormand_daily_is_reversed",
            "lenormand_daily_revealed_date",
        }

        for _, key in ipairs(setting_keys) do
            G_reader_settings:delSetting(key)
        end

        -- Apaga por completo os diretórios e arquivos gerados pelo plugin. Isso
        -- inclui registros antigos e novos, lixeira, exportações, backups e os
        -- Significados Pessoais criados por grifos ou pelo editor manual.
        local ok = true
        if self.saves_dir and not self:clearDirectoryRecursive(self.saves_dir, false) then
            ok = false
        end
        if self.journal_dir and not self:clearDirectoryRecursive(self.journal_dir, false) then
            ok = false
        end
        local custom_attr = self.custom_meanings_path and lfs.attributes(self.custom_meanings_path)
        if custom_attr then
            if custom_attr.mode == "directory" then
                if not self:clearDirectoryRecursive(self.custom_meanings_path, false) then
                    ok = false
                end
            elseif not os.remove(self.custom_meanings_path) then
                ok = false
            end
        end
        local pinlist_attr = self.pinlist_path and lfs.attributes(self.pinlist_path)
        if pinlist_attr then
            if pinlist_attr.mode == "directory" then
                if not self:clearDirectoryRecursive(self.pinlist_path, false) then
                    ok = false
                end
            elseif not os.remove(self.pinlist_path) then
                ok = false
            end
        end

        -- Recria somente as pastas vazias necessárias ao funcionamento normal.
        self:ensureSavesDir()
        self:ensureJournalDirs()

        local function directoryIsEmpty(path)
            local attr = path and lfs.attributes(path)
            if not attr or attr.mode ~= "directory" then
                return false
            end
            for name in lfs.dir(path) do
                if name ~= "." and name ~= ".." then
                    return false
                end
            end
            return true
        end

        -- Confere o resultado físico da exclusão. A raiz do Diário deve conter
        -- apenas as três subpastas vazias recriadas pelo plugin. Qualquer arquivo
        -- residual faz a operação ser reportada como incompleta.
        local journal_root_clean = true
        local expected_journal_dirs = {
            lixeira = self.journal_trash_dir,
            exportacoes = self.journal_export_dir,
            backups = self.journal_backup_dir,
        }
        local journal_attr = self.journal_dir and lfs.attributes(self.journal_dir)
        if not journal_attr or journal_attr.mode ~= "directory" then
            journal_root_clean = false
        else
            for name in lfs.dir(self.journal_dir) do
                if name ~= "." and name ~= ".." and not expected_journal_dirs[name] then
                    journal_root_clean = false
                    break
                end
            end
        end
        for _, path in pairs(expected_journal_dirs) do
            if not directoryIsEmpty(path) then
                journal_root_clean = false
                break
            end
        end

        if not directoryIsEmpty(self.saves_dir) or not journal_root_clean then
            ok = false
        end
        if self.custom_meanings_path and lfs.attributes(self.custom_meanings_path) then
            ok = false
        end

        -- Zera também todo estado mantido em memória na sessão atual.
        self.journal_state = {
            page = 1, query = "", deck = "all",
            types = { spread = true, daily = true, free = true, legacy = true },
            favorites_only = false, sort = "newest", month = nil,
        }
        self.allow_reversed = true
        self.major_only = false
        self.use_lenormand = false
        self.daily_card_deck_mode = "either"
        self.hide_daily_card_name = isPluginLanguageEnglish()
        self.daily_card_always_revealed = false
        self.spread_cards_always_revealed = false
        self.show_only_custom_meanings = false
        self.spread_meaning_mode = "full"
        self.disable_spread_meanings = false
        self.disable_view_in_book = false
        self.auto_save_spreads = false
        self.disable_unsaved_close_warning = false
        self.show_reversed_label = true
        self.meaning_text_size = "standard"
        self.hidden_card = true
        self.card_dialog_hint_shown_this_session = false
        self.physical_deck_hint_shown_this_session = false
        self.hidden_grid_hint_v2_shown_this_session = false
        self.next_card_reveal_hint_shown_this_session = false
        self.screen_refresh_mode = "smooth"

        -- Descarta referências a telas e estados antigos para impedir que uma tela
        -- já aberta reapresente dados apagados depois da restauração.
        self.journal_dialog = nil
        self.journal_filter_dialog = nil
        self.journal_more_dialog = nil
        self.journal_edit_menu = nil
        self.journal_trash_dialog = nil
        self.journal_backup_dialog = nil

        setTarotDirty(self.plugin or self)
        return ok
    end


end

return M

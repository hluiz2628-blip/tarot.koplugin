-- ── dependências ──────────────────────────────────────────────────────────────
local Blitbuffer       = require("ffi/blitbuffer")
local Button           = require("ui/widget/button")
local CenterContainer  = require("ui/widget/container/centercontainer")
local CheckButton      = require("ui/widget/checkbutton")
local ConfirmBox       = require("ui/widget/confirmbox")
local Event            = require("ui/event")
local Font             = require("ui/font")
local Geom             = require("ui/geometry")
local GestureRange     = require("ui/gesturerange")
local FrameContainer   = require("ui/widget/container/framecontainer")
local HorizontalGroup  = require("ui/widget/horizontalgroup")
local HorizontalSpan   = require("ui/widget/horizontalspan")
local ImageWidget      = require("ui/widget/imagewidget")
local InfoMessage      = require("ui/widget/infomessage")
local InputContainer   = require("ui/widget/container/inputcontainer")
local InputDialog      = require("ui/widget/inputdialog")
local Menu             = require("ui/widget/menu")
local ReaderUI         = require("apps/reader/readerui")
local Screen           = require("device").screen
local Size             = require("ui/size")
local TextBoxWidget    = require("ui/widget/textboxwidget")
local TextWidget       = require("ui/widget/textwidget")
local UIManager        = require("ui/uimanager")
local VerticalGroup    = require("ui/widget/verticalgroup")
local VerticalSpan     = require("ui/widget/verticalspan")
local WidgetContainer  = require("ui/widget/container/widgetcontainer")
local ffiutil          = require("ffi/util")
local logger           = require("logger")
local lfs              = require("libs/libkoreader-lfs")
local util             = require("util")

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 1: INTERNACIONALIZAÇÃO (gettext)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- O inglês é o idioma-fonte. Todas as traduções ficam fora deste arquivo,
-- em l10n/<idioma>/koreader.po. O carregamento pelo caminho absoluto evita
-- diferenças no package.path entre o aplicativo de computador e o Kindle.
local function loadPluginGetText()
    local source = debug.getinfo(1, "S").source or ""
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end

    local plugin_dir = source:match("^(.*[/\\])[^/\\]+$")
    assert(plugin_dir, "tarot.koplugin: não foi possível localizar a pasta do plugin")

    local loader_path = plugin_dir .. "tarot_gettext.lua"
    local loader, load_error = loadfile(loader_path)
    assert(loader, "tarot.koplugin: falha ao abrir " .. loader_path .. ": " .. tostring(load_error))

    return loader()
end

local T = loadPluginGetText()

local UI_TEXT = {
    title = "Tarot Reading",
    tarot_home = "Tarot Home",
    spreads = "Spreads",
    open_spreads = "Open spreads",
    draw_cards = "Draw cards",
    draw_one_more = "Draw one more card",
    remove_last_card = "Remove last card",
    drawn_card_count = "Cards drawn: %d of %d",
    physical_deck = "Physical deck",
    physical_deck_hint = "Select up to 10 cards",
    physical_deck_empty = "Select at least one card.",
    physical_deck_limit = "You can select up to 10 cards.",
    physical_deck_reverse_hint = "Press and hold a card in the list to reverse it.",
    card_dialog_navigation_hint = "Click the card beside it to access it.",
    do_not_show_again = "Do not show this message again",
    done = "Done",
    daily_card = "Daily Card",
    daily_card_deck_mode = "Daily Card deck",
    daily_card_tarot_only = "Show Tarot only",
    daily_card_lenormand_only = "Show Lenormand only",
    daily_card_either = "Show either one",
    reveal_daily_card = "Reveal daily card",
    daily_card_revealed = "Daily card revealed",
    open_daily_card = "View meaning",
    draw_card = "Draw a card",
    draw_three = "3 card spread",
    draw_daily = "Card of the day",
    settings = "Settings",
    configuration = "Config",
    close = "Close",
    prev = "< Prev",
    next = "Next >",
    language = "Language",
    portuguese = "Português",
    english = "English",
    upright = "Upright",
    reversed = "Reversed",
    loading = "Shuffling the cards...",
    card_count = "Card %d of %d",
    allow_reversed = "Reversed cards",
    allow_reversed_desc = "Allow cards to appear reversed",
    major_only = "Major Arcana only",
    major_only_desc = "Draw only from the 22 Major Arcana",
    reading_display = "Reading display",
    disable_spread_meanings = "Disable Card Book meanings in spreads",
    disable_view_in_book = "Disable \"view in book\" button",
    auto_save_spreads = "Save readings automatically",
    disable_unsaved_close_warning = "Disable close-without-saving question",
    unsaved_close_warning = "This reading has not been saved. Close without saving?",
    continue_reading = "Continue reading",
    close_without_saving = "Close without saving",
    saved_automatically = "Saved automatically",
    automatic_reading_title = "Automatic %s reading — %s",
    show_reversed_label = "Show \"Reversed\" label",
    meaning_text_size = "Meaning text size",
    text_size_compact = "Compact",
    text_size_standard = "Standard",
    text_size_large = "Large",
    meaning_mode = "Meanings in readings",
    meaning_mode_full = "Full",
    meaning_mode_summary = "Summarized",
    meaning_mode_hidden = "Hidden",
    settings_page = "Page %d of %d",
    journal_system = "Journal and system",
    major_arcana = "Major Arcana",
    minor_arcana = "Minor Arcana",
    deck_type = "Deck Type",
    deck_type_desc = "Choose between Tarot and Lenormand",
    tarot_deck = "Tarot",
    lenormand_deck = "Lenormand",
    lenormand_reading = "Lenormand Reading",
    lenormand_title = "Lenormand Deck",
    save = "Save",
    save_title = "Record title",
    save_title_hint = "Ex: Daily reflection",
    save_note = "Reflection about the reading",
    save_note_hint = "Ex: What I felt seeing these cards...",
    save_success = "Spread saved successfully!",
    save_error = "Error saving the spread.",
    journal = "Journal",
    saved_readings = "Reflection Journal",
    no_saved = "No journal entries found.",
    journal_empty_desc = "Save a spread, record the daily card, or create a free reflection.",
    open_reading = "Open record",
    delete_reading = "Move to trash",
    delete_confirm = "Move this record to the trash?",
    delete_success = "Record moved to the trash.",
    delete_error = "Error moving the record.",
    journal_records = "%d records",
    new_reflection = "New reflection",
    search = "Search",
    filter = "Filter",
    more = "More",
    page_count = "%d of %d",
    no_journal_results = "No journal entries match the current search or filters.",
    clear_filters = "Clear search and filters",
    clear_search = "Clear search",
    journal_search_title = "Search journal",
    journal_search_hint = "Title, reflection, card, or outcome",
    journal_filter_title = "Journal filters",
    apply = "Apply",
    all = "All",
    deck_filter = "Deck: %s",
    entry_types = "Entry types",
    spread_entries = "Spreads",
    daily_entries = "Daily cards",
    free_entries = "Free reflections",
    legacy_entries = "Old records",
    favorites_only = "Favorites only",
    sort_order = "Order: %s",
    newest_first = "Newest first",
    oldest_first = "Oldest first",
    title_order = "Title",
    last_edited = "Last edited",
    select_entry_type = "Select at least one entry type.",
    go_to_month = "Go to month",
    month_input_title = "Month",
    month_input_hint = "YYYY-MM, for example 2026-07",
    invalid_month = "Use the YYYY-MM format.",
    clear_month = "Clear month filter",
    journal_summary = "Journal summary",
    trash = "Trash",
    trash_title = "Journal Trash",
    trash_empty = "The journal trash is empty.",
    restore_entry = "Restore",
    restore_success = "Record restored.",
    delete_permanently = "Delete permanently",
    delete_permanent_confirm = "Permanently delete this record?",
    delete_permanent_success = "Record permanently deleted.",
    export_journal = "Export journal",
    export_success = "Journal exported to:\n%s",
    export_error = "Error exporting the journal.",
    create_backup = "Create backup",
    backup_success = "Backup created at:\n%s",
    backup_error = "Error creating the backup.",
    restore_backup = "Restore backup",
    no_backups = "No journal backups found.",
    backup_restored = "Backup restored. Existing records were preserved.",
    reflection_title = "Reflection title",
    reflection_title_hint = "What is this reflection about?",
    reflection_text = "Reflection",
    reflection_text_hint = "Write your reflection...",
    save_reflection = "Save reflection",
    edit = "Edit",
    edit_title = "Edit title",
    edit_reflection = "Edit reflection",
    add_outcome = "Add outcome",
    edit_outcome = "Edit outcome",
    outcome_text = "Outcome",
    outcome_text_hint = "What happened after this reflection?",
    favorite = "Favorite",
    unfavorite = "Remove favorite",
    view_cards = "View cards and meanings",
    back_to_journal = "Back to journal",
    add_to_journal = "Add to journal",
    my_reflection = "MY REFLECTION",
    outcome_label = "OUTCOME",
    cards_label = "CARDS",
    created_on = "Created on",
    updated_on = "Updated on",
    type_label = "Type",
    spread_entry = "Spread",
    daily_entry = "Daily card",
    free_entry = "Free reflection",
    legacy_entry = "Old record",
    one_card_entry = "1 card",
    three_card_entry = "3 cards",
    card_total_entry = "%d cards",
    untitled_reflection = "Untitled reflection",
    no_reflection_text = "No reflection text.",
    journal_save_error = "Error saving the journal record.",
    journal_save_success = "Journal record saved.",
    legacy_read_only = "Old records are read-only, but they can be searched, opened, exported, or moved to the trash.",
    summary_total = "Total records: %d",
    summary_tarot = "Tarot: %d",
    summary_lenormand = "Lenormand: %d",
    summary_this_month = "This month: %d",
    summary_favorites = "Favorites: %d",
    summary_most_frequent = "Most frequent card: %s (%d)",
    summary_no_card = "Most frequent card: —",
    saved_on = "Saved on",
    title_label = "Title",
    note_label = "Note",
    card_position = "Position",
    restore = "Restore",
    restore_desc = "Erase all plugin data",
    restore_confirm_first = "ATTENTION: EVERYTHING will be DELETED. Continue?",
    restore_confirm_second = "This action cannot be undone. Continue?",
    reset_success = "All plugin data was deleted. The app is now reset.",
    reset_error = "The reset could not be completed. Some data could not be deleted.",
    yes = "Yes",
    no = "No",
    confirm = "Confirm",
    cancel = "Cancel",
    reset_section = "Reset",
    card_book = "Card Book",
    major_arcana_list = "Major Arcana (22)",
    minor_arcana_list = "Minor Arcana (56)",
    lenormand_list = "Lenormand Deck (36)",
    all_cards = "View All Cards",
    search_card = "Search Card",
    search_tarot = "Search Tarot",
    search_lenormand = "Search Lenormand",
    cards_count = "%d cards",
    search_hint = "Type a card name or keyword",
    search_empty = "Enter a search term.",
    meaning_label = "Meaning",
    reversed_meaning_label = "Reversed Meaning",
    number_label = "Number",
    arcana_label = "Arcana",
    filter_title = "Filter Cards",
    no_results = "No cards found.",
    back = "Back",
    suit_wands = "Wands",
    suit_cups = "Cups",
    suit_swords = "Swords",
    suit_pentacles = "Pentacles",
    hidden_card = "Hidden Card",
    click_on_card = "click on the card",
    exit = "Exit",
    reveal = "Reveal",
    reveal_next = "Reveal next card",
    click_card_to_reveal = "Click the card to reveal it.",
    click_next_card_to_reveal = "Click the next card to reveal it. Press and hold to reveal all remaining cards.",
    reveal_all_confirm = "Reveal all remaining cards?",
    revealed_count = "Revealed %d of %d",
    about = "About",
    about_title = "About Tarot and Lenormand",
    about_text = [[Tarot is a deck of 78 cards, divided into Major Arcana (22) and Minor Arcana (56), used for reflection and self-knowledge. The Lenormand deck has 36 cards with direct symbolism for practical guidance.

Credits for the free card images:
• Lenormand Cards by Yve Lepkowski (https://stolen-thyme.com/)
• Tarot Cards by Luciella Elisabeth Scarlett (https://luciellaes.itch.io/)]],
    view_in_book = "view in book",
    keywords_label = "Keywords",
    planet_sign_label = "Planet / Sign",
    timing_label = "Timing",
    saved_card_line = "Card %d — %s (%s)",
    plugin_description = "Draw Tarot and Lenormand cards for reflection, save readings, and browse the complete card book.",
}

-- Cria métricas reutilizáveis para telas fullscreen.
-- O objetivo é evitar janelas centrais em dispositivos diferentes: Kindle,
-- Kobo, Android e desktop passam a receber um container do tamanho real da
-- tela do KOReader, com apenas uma margem interna segura.
local function getFullscreenLayout(content_factor)
    local sw = Screen:getWidth()
    local sh = Screen:getHeight()
    local outer_pad = Size.padding.default
    local safe_w = sw - outer_pad * 2
    local safe_h = sh - outer_pad * 2

    if safe_w < 1 then safe_w = sw end
    if safe_h < 1 then safe_h = sh end

    local content_w = math.floor(safe_w * (content_factor or 0.92))
    if content_w < math.floor(sw * 0.72) then
        content_w = math.floor(sw * 0.72)
    end
    if content_w > safe_w then
        content_w = safe_w
    end

    return {
        screen_w = sw,
        screen_h = sh,
        outer_pad = outer_pad,
        safe_w = safe_w,
        safe_h = safe_h,
        content_w = content_w,
    }
end

-- Envolve qualquer conteúdo em uma tela fullscreen branca.
-- Diferente do padrão antigo de popup, este wrapper não usa borda nem radius.
local function makeFullscreenFrame(content, layout)
    layout = layout or getFullscreenLayout()

    local centered_content = CenterContainer:new{
        dimen = {
            w = layout.safe_w,
            h = layout.safe_h,
        },
        content,
    }

    return FrameContainer:new{
        width      = layout.screen_w,
        height     = layout.screen_h,
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        radius     = 0,
        padding    = layout.outer_pad,
        margin     = 0,
        centered_content,
    }
end

-- Divisor visual padrão do plugin. É usado antes de ações de rodapé como
-- "Fechar" e "Voltar", para separar navegação principal de saída/retorno.
local function makeTarotDivider(width, shade)
    return TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(shade or 0.55),
        max_width = width,
        alignment = "center",
    }
end

-- Cabeçalho padrão das telas fullscreen do plugin. Mantém uma identidade
-- visual única: título centralizado, subtítulo opcional e divisor discreto.
local function makeSectionHeader(title, width, subtitle)
    local header = VerticalGroup:new{ align = "center" }

    table.insert(header, TextWidget:new{
        text      = title,
        face      = Font:getFace("tfont"),
        bold      = true,
        max_width = width,
        alignment = "center",
    })

    if subtitle and subtitle ~= "" then
        table.insert(header, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(header, TextBoxWidget:new{
            text      = subtitle,
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.45),
            width     = width,
            alignment = "center",
        })
    end

    table.insert(header, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(header, makeTarotDivider(width))

    return header
end

-- Texto auxiliar discreto, usado em empty states e descrições curtas de menu.
local function makeMutedText(text, width)
    return TextBoxWidget:new{
        text      = text,
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.45),
        width     = width,
        alignment = "center",
    }
end

-- Raio seguro para botões. Alguns builds/dispositivos podem não preencher
-- `Size.radius.button`; nesse caso, usamos fallbacks conhecidos antes de cair
-- em um valor fixo pequeno. Isso evita botões quadrados no Kindle.
local function getTarotButtonRadius()
    if Size.radius then
        return Size.radius.button or Size.radius.default or Size.radius.window or 8
    end
    return 8
end

-- Cartão visual simples para agrupar configurações relacionadas. Usa borda
-- leve e padding padrão para criar blocos claros sem parecer popup.
local function makeSettingsCard(title, body, width)
    local inner = VerticalGroup:new{
        align = "center",
        TextWidget:new{
            text      = title,
            face      = Font:getFace("smalltfont"),
            bold      = true,
            max_width = width,
            alignment = "center",
        },
        VerticalSpan:new{ width = Size.span.vertical_default },
        body,
    }

    return FrameContainer:new{
        width      = width,
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 1,
        radius     = getTarotButtonRadius(),
        padding    = Size.padding.default,
        inner,
    }
end

-- Botão padrão com cantos arredondados. Não forçamos `bordersize` aqui: o
-- KOReader gerencia melhor o estado pressionado quando o botão mantém o
-- comportamento nativo de borda/desenho.
local function makeRoundedButton(spec)
    spec = spec or {}
    return Button:new{
        text             = spec.text,
        width            = spec.width,
        radius           = spec.radius or getTarotButtonRadius(),
        enabled          = spec.enabled,
        is_enter_default = spec.is_enter_default,
        callback         = spec.callback,
    }
end

-- Botão textual e discreto, sem borda nem fundo, no mesmo estilo do botão
-- "ver no livro". Usado para ações de rodapé e links secundários.
local function makeTransparentTextButton(spec)
    spec = spec or {}
    local button = Button:new{
        text             = spec.text,
        width            = spec.width,
        bordersize       = 0,
        background       = nil,
        font_face        = spec.font_face or Font:getFace("x_smallinfofont"),
        radius           = 0,
        enabled          = spec.enabled,
        is_enter_default = spec.is_enter_default,
        callback         = spec.callback,
    }

    if button.textwidget then
        button.textwidget.fgcolor = spec.fgcolor or Blitbuffer.gray(0.5)
    end

    return button
end

-- Menu simples em fullscreen, usado para substituir ButtonDialog nos fluxos
-- de navegação do plugin. Caixas de texto continuam como InputDialog para
-- preservar o teclado e o comportamento nativo do KOReader.
local FullscreenMenuDialog = InputContainer:extend{
    title = nil,
    buttons = nil,
}

function FullscreenMenuDialog:init()
    local layout = getFullscreenLayout(0.88)
    local iw = layout.content_w

    local content = VerticalGroup:new{ align = "center" }
    local footer_rows = {}

    local function makeMenuButton(spec, width, button_dialog, is_footer)
        local button_spec = spec
        local callback = function()
            -- Em telas fullscreen, o próprio menu deve saber se precisa fechar
            -- antes/depois da ação. Isso evita callbacks presos a variáveis
            -- externas de diálogos antigos, causa comum de botões sem efeito.
            if button_spec.close_before or button_spec.close_dialog then
                UIManager:close(button_dialog)
                UIManager:setDirty(nil, "full")
            end

            if button_spec.callback then
                button_spec.callback(button_dialog)
            end

            if button_spec.close_after then
                UIManager:close(button_dialog)
                UIManager:setDirty(nil, "full")
            end
        end

        local params = {
            text             = spec.text,
            width            = width,
            enabled          = spec.enabled,
            is_enter_default = spec.is_enter_default,
            callback         = callback,
        }

        if is_footer then
            return makeTransparentTextButton(params)
        end

        return makeRoundedButton(params)
    end

    local function appendRows(target, rows, is_footer)
        for _, row in ipairs(rows) do
            local row_count = #row

            if row_count <= 1 then
                local spec = row[1]
                if spec then
                    if spec.label then
                        table.insert(target, TextWidget:new{
                            text = spec.text or "",
                            face = Font:getFace("smalltfont"),
                            bold = true,
                            max_width = iw,
                            alignment = "center",
                        })
                    else
                        table.insert(target, makeMenuButton(spec, iw, self, is_footer))
                    end
                    table.insert(target, VerticalSpan:new{ width = Size.span.vertical_default })
                end
            else
                local group = HorizontalGroup:new{ align = "center" }
                local btn_w = math.floor((iw - Size.span.horizontal_default * (row_count - 1)) / row_count)

                for index, spec in ipairs(row) do
                    table.insert(group, makeMenuButton(spec, btn_w, self, is_footer))
                    if index < row_count then
                        table.insert(group, HorizontalSpan:new{ width = Size.span.horizontal_default })
                    end
                end

                table.insert(target, group)
                table.insert(target, VerticalSpan:new{ width = Size.span.vertical_default })
            end
        end
    end

    if self.title and self.title ~= "" then
        table.insert(content, makeSectionHeader(self.title, iw))
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
    end

    for _, row in ipairs(self.buttons or {}) do
        local is_footer = false
        for _, spec in ipairs(row) do
            if spec.footer then
                is_footer = true
                break
            end
        end

        if is_footer then
            table.insert(footer_rows, row)
        else
            appendRows(content, { row }, false)
        end
    end

    if #footer_rows > 0 then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(content, makeTarotDivider(iw))
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        appendRows(content, footer_rows, true)
    end

    self[1] = makeFullscreenFrame(content, layout)
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 2: CARTAS - ARCANOS MAIORES (22)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local MAJOR_ARCANA = {
    {
        id = 0, roman = "0",
        name = "The Fool",
        keywords = "New beginning, spontaneity, faith, risk",
        planet = "Uranus",
        timing = "Immediate, unpredictable",
        meaning = "New beginnings. Spontaneity. Take a leap of faith. Venture without fear, the universe supports you.",
        reversed_meaning = "Recklessness. Lack of direction. Think before acting. Blind risk may bring consequences."
    },
    {
        id = 1, roman = "I",
        name = "The Magician",
        keywords = "Power, skill, manifestation, focus",
        planet = "Mercury",
        timing = "Fast, now is the time",
        meaning = "Personal power. Skill. You have everything you need. Manifest your desires with confidence.",
        reversed_meaning = "Manipulation. Wasted talent. Deceit. Beware of illusions of power."
    },
    {
        id = 2, roman = "II",
        name = "The High Priestess",
        keywords = "Intuition, mystery, subconscious, wisdom",
        planet = "Moon",
        timing = "Lunar cycles, 28 days",
        meaning = "Intuition. Mystery. Trust your inner voice. Hidden knowledge reveals itself in silence.",
        reversed_meaning = "Secrets revealed. Intuitive disconnection. Silence broken. Listen to your inner voice again."
    },
    {
        id = 3, roman = "III",
        name = "The Empress",
        keywords = "Abundance, fertility, nature, nurturing",
        planet = "Venus",
        timing = "9 months, spring",
        meaning = "Abundance. Fertility. Nurture yourself. Nature flourishes around you.",
        reversed_meaning = "Neglect. Creative block. Dependence. Return to tending your inner garden."
    },
    {
        id = 4, roman = "IV",
        name = "The Emperor",
        keywords = "Authority, structure, leadership, stability",
        planet = "Aries",
        timing = "1 year, soon",
        meaning = "Authority. Structure. Take control. Firm leadership brings stability.",
        reversed_meaning = "Tyranny. Rigidity. Lack of discipline. Excess control suffocates."
    },
    {
        id = 5, roman = "V",
        name = "The Hierophant",
        keywords = "Tradition, wisdom, guidance, teaching",
        planet = "Taurus",
        timing = "5 weeks, slow but steady",
        meaning = "Tradition. Wisdom. Seek guidance. Masters appear when the student is ready.",
        reversed_meaning = "Rebellion. Dogma. Necessary questioning. Breaking with traditions can be liberating."
    },
    {
        id = 6, roman = "VI",
        name = "The Lovers",
        keywords = "Love, choice, harmony, partnership",
        planet = "Gemini",
        timing = "Imminent decision",
        meaning = "Love. Choice. Harmony in relationships. The heart knows the way.",
        reversed_meaning = "Conflict. Imbalance. Difficult decision. Avoid impulsive choices in love."
    },
    {
        id = 7, roman = "VII",
        name = "The Chariot",
        keywords = "Victory, determination, control, progress",
        planet = "Cancer",
        timing = "7 weeks",
        meaning = "Victory. Determination. Move forward with confidence. Triumph awaits the perseverant.",
        reversed_meaning = "Lack of direction. Defeat. Loss of control. Reevaluate your route before proceeding."
    },
    {
        id = 8, roman = "VIII",
        name = "Strength",
        keywords = "Courage, inner strength, compassion, mastery",
        planet = "Leo",
        timing = "8 weeks",
        meaning = "Courage. Inner strength. Master your impulses with kindness, not violence.",
        reversed_meaning = "Weakness. Insecurity. Lack of self-control. True strength comes from vulnerability."
    },
    {
        id = 9, roman = "IX",
        name = "The Hermit",
        keywords = "Introspection, solitude, wisdom, inner search",
        planet = "Virgo",
        timing = "9 months, slow",
        meaning = "Introspection. Inner wisdom. Seek silence. The light you seek is within you.",
        reversed_meaning = "Isolation. Loneliness. Refusing to see the truth. Prolonged retreat becomes escape."
    },
    {
        id = 10, roman = "X",
        name = "Wheel of Fortune",
        keywords = "Change, destiny, cycles, luck",
        planet = "Jupiter",
        timing = "In motion, cyclical",
        meaning = "Change. Destiny. Luck is turning in your favor. Everything passes, cycles renew.",
        reversed_meaning = "Bad luck. Resistance to change. Negative cycle. Accept that nothing is permanent."
    },
    {
        id = 11, roman = "XI",
        name = "Justice",
        keywords = "Balance, truth, law, cause and effect",
        planet = "Libra",
        timing = "Under review, fair",
        meaning = "Balance. Truth. Justice will prevail. Reap what you have sown with serenity.",
        reversed_meaning = "Injustice. Dishonesty. Consequences coming. The scales weigh against you now."
    },
    {
        id = 12, roman = "XII",
        name = "The Hanged Man",
        keywords = "Sacrifice, suspension, new perspective, surrender",
        planet = "Neptune",
        timing = "Indeterminate, pause",
        meaning = "Sacrifice. New perspective. Let go, trust. Sometimes stopping is advancing.",
        reversed_meaning = "Stagnation. Procrastination. Resist change. The pause has become paralysis."
    },
    {
        id = 13, roman = "XIII",
        name = "Death",
        keywords = "Transformation, ending, rebirth, transition",
        planet = "Scorpio",
        timing = "Autumn, shortly",
        meaning = "Transformation. End of a cycle. Rebirth near. The old dies so the new can be born.",
        reversed_meaning = "Resistance to change. Stagnation. Fear of endings. Let go of what no longer serves."
    },
    {
        id = 14, roman = "XIV",
        name = "Temperance",
        keywords = "Patience, balance, moderation, harmony",
        planet = "Sagittarius",
        timing = "Patience, gradual",
        meaning = "Patience. Moderation. Find balance. Water finds its level.",
        reversed_meaning = "Excess. Impatience. Disharmony. Return to center, breathe deeply."
    },
    {
        id = 15, roman = "XV",
        name = "The Devil",
        keywords = "Temptation, attachment, shadow, materialism",
        planet = "Capricorn",
        timing = "15 days",
        meaning = "Temptation. Negative patterns. Free yourself from chains. You have the power to break free.",
        reversed_meaning = "Liberation. Breaking addictions. Recovery. Light enters where darkness once was."
    },
    {
        id = 16, roman = "XVI",
        name = "The Tower",
        keywords = "Revelation, upheaval, chaos, reconstruction",
        planet = "Mars",
        timing = "Sudden, unexpected",
        meaning = "Sudden revelation. Rupture. Necessary reconstruction. What is false crumbles.",
        reversed_meaning = "Avoiding disaster. Fear of change. Denial. The fall is inevitable, accept it."
    },
    {
        id = 17, roman = "XVII",
        name = "The Star",
        keywords = "Hope, faith, inspiration, renewal",
        planet = "Aquarius",
        timing = "17 days",
        meaning = "Hope. Faith. Follow your intuition. Light guides you in darkness. Trust the universe.",
        reversed_meaning = "Hopelessness. Lack of faith. Spiritual disconnection. The light is there, you just don't see it."
    },
    {
        id = 18, roman = "XVIII",
        name = "The Moon",
        keywords = "Illusion, intuition, fear, subconscious",
        planet = "Pisces",
        timing = "28 days, nocturnal",
        meaning = "Illusion. Intuition. Not everything is as it seems. Walk carefully in the twilight.",
        reversed_meaning = "Confusion cleared. Fear overcome. Truth revealed. The fog is lifting."
    },
    {
        id = 19, roman = "XIX",
        name = "The Sun",
        keywords = "Joy, success, vitality, clarity",
        planet = "Sun",
        timing = "19 days, diurnal",
        meaning = "Joy. Success. Vitality. Everything is illuminated. Happiness overflows.",
        reversed_meaning = "Temporary sadness. Delay. Lack of enthusiasm. The sun always shines again."
    },
    {
        id = 20, roman = "XX",
        name = "Judgement",
        keywords = "Renewal, awakening, forgiveness, calling",
        planet = "Pluto",
        timing = "Renewal, awakening",
        meaning = "Renewal. Inner calling. Time to awaken. The past has been forgiven.",
        reversed_meaning = "Self-criticism. Regret. Denial of the calling. Free yourself from guilt."
    },
    {
        id = 21, roman = "XXI",
        name = "The World",
        keywords = "Completion, fulfillment, integration, success",
        planet = "Saturn",
        timing = "21 days/months, full cycle",
        meaning = "Completion. Fulfillment. Cycle successfully concluded. The universe celebrates with you.",
        reversed_meaning = "Incompleteness. Delay. Lack of closure. There is still one step to take."
    },
}

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 3: CARTAS - ARCANOS MENORES (56)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local suits = {
    { name = "Wands", symbol = "♣" },
    { name = "Cups", symbol = "♥" },
    { name = "Swords", symbol = "♠" },
    { name = "Pentacles", symbol = "♦" },
}

local ranks = {
    { name = "Ace" },
    { name = "Two" },
    { name = "Three" },
    { name = "Four" },
    { name = "Five" },
    { name = "Six" },
    { name = "Seven" },
    { name = "Eight" },
    { name = "Nine" },
    { name = "Ten" },
    { name = "Page" },
    { name = "Knight" },
    { name = "Queen" },
    { name = "King" },
}

local MINOR_ARCANA = {
    -- ═══════════════════════  NAIPE DE PAUS (Wands) ═══════════════════════
    {
        id = 22, suit = suits[1], rank = ranks[1],
        name = "Ace of Wands",
        keywords = "Inspiration, creativity, new beginning, energy",
        timing = "Fast (days)",
        meaning = "Creative inspiration. A new beginning full of energy. Seize the initial impulse to start projects.",
        reversed_meaning = "False start. Procrastination. Lack of motivation. Rekindle your passion before moving on."
    },
    {
        id = 23, suit = suits[1], rank = ranks[2],
        name = "Two of Wands",
        keywords = "Planning, vision, decision, expansion",
        timing = "Weeks",
        meaning = "Planning. Looking ahead. You have the world in your hands, but you must choose the path.",
        reversed_meaning = "Fear of the unknown. Lack of planning. Letting go of the reins. Define your goals."
    },
    {
        id = 24, suit = suits[1], rank = ranks[3],
        name = "Three of Wands",
        keywords = "Expansion, progress, anticipation, trade",
        timing = "Soon",
        meaning = "Expansion. Progress. Your plans are sailing. Await the return of the seeds you planted.",
        reversed_meaning = "Unexpected obstacles. Delay. Frustration with results. Reassess your strategy."
    },
    {
        id = 25, suit = suits[1], rank = ranks[4],
        name = "Four of Wands",
        keywords = "Celebration, home, harmony, stability",
        timing = "4 weeks",
        meaning = "Celebration. Harmony at home. Shared achievements. A well-deserved rest after effort.",
        reversed_meaning = "Lack of unity. Domestic instability. Postponed celebration. Recover simple joy."
    },
    {
        id = 26, suit = suits[1], rank = ranks[5],
        name = "Five of Wands",
        keywords = "Competition, conflict, debate, growth",
        timing = "5 weeks",
        meaning = "Healthy competition. Creative conflict. Different viewpoints enrich the search.",
        reversed_meaning = "Internal quarrels. Avoiding confrontation. Energy drain. Seek cooperation instead of dispute."
    },
    {
        id = 27, suit = suits[1], rank = ranks[6],
        name = "Six of Wands",
        keywords = "Victory, recognition, triumph, confidence",
        timing = "6 weeks",
        meaning = "Victory. Public recognition. High self-esteem. Reap the laurels with humility.",
        reversed_meaning = "Inflated ego. Short-lived recognition. Envy. True victory is internal."
    },
    {
        id = 28, suit = suits[1], rank = ranks[7],
        name = "Seven of Wands",
        keywords = "Defense, perseverance, courage, resistance",
        timing = "7 weeks",
        meaning = "Defense of positions. Perseverance. Stand firm despite opposition. You have the upper hand.",
        reversed_meaning = "Exhaustion. Feeling cornered. Giving up. Reinforce your boundaries wisely."
    },
    {
        id = 29, suit = suits[1], rank = ranks[8],
        name = "Eight of Wands",
        keywords = "Speed, action, progress, communication",
        timing = "Very fast",
        meaning = "Swift movement. News arriving. Accelerated action. Take advantage of the tailwind.",
        reversed_meaning = "Delay. Lack of direction. Scattered energy. Wait for the right moment to act."
    },
    {
        id = 30, suit = suits[1], rank = ranks[9],
        name = "Nine of Wands",
        keywords = "Resilience, persistence, last stand, fatigue",
        timing = "9 weeks",
        meaning = "Resilience. Last battle. You are almost there, even if tired. Keep your guard up.",
        reversed_meaning = "Stubbornness. Refusing help. Exhaustion. Let down your defense and allow yourself to rest."
    },
    {
        id = 31, suit = suits[1], rank = ranks[10],
        name = "Ten of Wands",
        keywords = "Overload, responsibility, burden, effort",
        timing = "10 weeks, end of cycle",
        meaning = "Overload. Heavy responsibilities. The burden is great, but the end is near. Delegate tasks.",
        reversed_meaning = "Inability to delegate. Burnout. Refusing help. Let go of what doesn't belong to you."
    },
    {
        id = 32, suit = suits[1], rank = ranks[11],
        name = "Page of Wands",
        keywords = "Enthusiasm, exploration, discovery, new idea",
        timing = "Youthful, fast",
        meaning = "Enthusiasm. New ideas. A young messenger brings inspiration. Explore your curiosity without fear.",
        reversed_meaning = "Lack of plans. Impulsiveness. Ideas without execution. Set goals before acting."
    },
    {
        id = 33, suit = suits[1], rank = ranks[12],
        name = "Knight of Wands",
        keywords = "Action, passion, impulse, adventure",
        timing = "Immediate, intense",
        meaning = "Passionate action. Courage to take risks. Go ahead boldly, but don't forget the destination.",
        reversed_meaning = "Impatience. Rushing without direction. Conflict. Slow down and choose the right path."
    },
    {
        id = 34, suit = suits[1], rank = ranks[13],
        name = "Queen of Wands",
        keywords = "Charisma, leadership, warmth, confidence",
        timing = "Summer, mature",
        meaning = "Warmth, determination and magnetism. Inspiring leadership. Use your charisma to attract what you want.",
        reversed_meaning = "Jealousy. Insecurity. Explosive temper. The inner flame can burn those nearby."
    },
    {
        id = 35, suit = suits[1], rank = ranks[14],
        name = "King of Wands",
        keywords = "Vision, entrepreneurship, authority, honor",
        timing = "Long term, leadership",
        meaning = "Entrepreneurial vision. Strong leadership. Take command with integrity and inspire others.",
        reversed_meaning = "Authoritarianism. Empty promises. Lack of vision. Leading by fear builds nothing lasting."
    },

    -- ═══════════════════════  NAIPE DE COPAS (Cups) ═══════════════════════
    {
        id = 36, suit = suits[2], rank = ranks[1],
        name = "Ace of Cups",
        keywords = "Love, emotion, intuition, new feeling",
        timing = "Lunar, emotional",
        meaning = "Overflowing love. New emotional cycle. Open yourself to deep feelings and true connections.",
        reversed_meaning = "Repressed love. Emotional block. Inner emptiness. Allow yourself to feel in order to heal."
    },
    {
        id = 37, suit = suits[2], rank = ranks[2],
        name = "Two of Cups",
        keywords = "Union, partnership, commitment, attraction",
        timing = "Meeting soon",
        meaning = "Union. Loving partnership. Soul meeting. Mutual respect and commitment strengthen the bond.",
        reversed_meaning = "Disconnection. Quarrels. Emotional imbalance. A sincere conversation can restore harmony."
    },
    {
        id = 38, suit = suits[2], rank = ranks[3],
        name = "Three of Cups",
        keywords = "Friendship, celebration, community, joy",
        timing = "Social event",
        meaning = "Friendship. Celebration. Shared joy. Gather with those you love and celebrate life.",
        reversed_meaning = "Gossip. Isolation. Excess partying. Beware of superficial friendships and hidden resentments."
    },
    {
        id = 39, suit = suits[2], rank = ranks[4],
        name = "Four of Cups",
        keywords = "Contemplation, apathy, boredom, introspection",
        timing = "Stagnant",
        meaning = "Contemplation. Apathy. New invitation ignored. Look beyond boredom to notice opportunities.",
        reversed_meaning = "Awakening. Acceptance. New perspectives. Leave your comfort zone and seize the chance offered."
    },
    {
        id = 40, suit = suits[2], rank = ranks[5],
        name = "Five of Cups",
        keywords = "Grief, loss, regret, focus on negative",
        timing = "Recent past",
        meaning = "Grief. Loss. Focus on what is gone. Two cups still stand – look at what remains.",
        reversed_meaning = "Overcoming. Recovery. Learning from pain. Accept the past and move forward."
    },
    {
        id = 41, suit = suits[2], rank = ranks[6],
        name = "Six of Cups",
        keywords = "Nostalgia, memory, childhood, gift",
        timing = "Revisiting the past",
        meaning = "Nostalgia. Fond memories. Reunion with the past. Cherish your roots with affection.",
        reversed_meaning = "Clinging to the past. Immaturity. Inability to move on. Live the present."
    },
    {
        id = 42, suit = suits[2], rank = ranks[7],
        name = "Seven of Cups",
        keywords = "Illusion, choices, fantasy, dreams",
        timing = "Confusing, indefinite",
        meaning = "Illusions. Fantasies. Multiple options. Discernment is needed to choose the true cup.",
        reversed_meaning = "Clarity. Firm decision. End of illusions. Focus on what really matters."
    },
    {
        id = 43, suit = suits[2], rank = ranks[8],
        name = "Eight of Cups",
        keywords = "Withdrawal, search, disillusion, departure",
        timing = "Emotional transition",
        meaning = "Withdrawal. Spiritual search. Leaving behind what doesn't fulfill. Follow your intuition.",
        reversed_meaning = "Fear of change. Staying out of convenience. Silent dissatisfaction. Courage to leave."
    },
    {
        id = 44, suit = suits[2], rank = ranks[9],
        name = "Nine of Cups",
        keywords = "Wish fulfilled, satisfaction, contentment, luxury",
        timing = "Soon fulfillment",
        meaning = "Wish fulfilled. Satisfaction. The “dream cup” is full. Enjoy emotional abundance.",
        reversed_meaning = "Dissatisfaction. Unmet desires. Empty materialism. True happiness lies in simplicity."
    },
    {
        id = 45, suit = suits[2], rank = ranks[10],
        name = "Ten of Cups",
        keywords = "Happiness, family, harmony, blessing",
        timing = "Happy ending",
        meaning = "Full happiness. Family love. Lasting harmony. The heart overflows with shared joy.",
        reversed_meaning = "Family conflicts. Broken bonds. Idealization of happiness. Work on emotional communication."
    },
    {
        id = 46, suit = suits[2], rank = ranks[11],
        name = "Page of Cups",
        keywords = "Sensitivity, creativity, message, intuition",
        timing = "Emotional surprise",
        meaning = "Creative sensitivity. Message of love. Open up to intuition and heart surprises.",
        reversed_meaning = "Emotional immaturity. Love disappointment. Childish jealousy. Put fantasy aside and face reality."
    },
    {
        id = 47, suit = suits[2], rank = ranks[12],
        name = "Knight of Cups",
        keywords = "Romanticism, charm, proposal, idealism",
        timing = "Invitation soon",
        meaning = "Romanticism. Charming proposal. Search for the beautiful and ideal. Follow your heart with elegance.",
        reversed_meaning = "Love illusion. Empty promises. Excess of idealization. Keep your feet on the ground."
    },
    {
        id = 48, suit = suits[2], rank = ranks[13],
        name = "Queen of Cups",
        keywords = "Empathy, intuition, care, compassion",
        timing = "Lunar cycle, mature",
        meaning = "Deep intuition. Empathy. Emotional caregiver. Trust your ability to love and heal.",
        reversed_meaning = "Emotional dependence. Exacerbated sensitivity. Emotional manipulation. Set healthy boundaries."
    },
    {
        id = 49, suit = suits[2], rank = ranks[14],
        name = "King of Cups",
        keywords = "Emotional mastery, diplomacy, calm, wisdom",
        timing = "Emotional stability",
        meaning = "Emotional mastery. Mature compassion. Leadership with heart. Calm turbulent waters with wisdom.",
        reversed_meaning = "Coldness. Emotional repression. Manipulation. The repressed heart becomes a silent tyrant."
    },

    -- ═══════════════════════  NAIPE DE ESPADAS (Swords) ═══════════════════════
    {
        id = 50, suit = suits[3], rank = ranks[1],
        name = "Ace of Swords",
        keywords = "Clarity, truth, justice, sharp mind",
        timing = "Quick decision",
        meaning = "Mental clarity. Truth revealed. Sharp idea. Use the power of the word with justice.",
        reversed_meaning = "Confusion. Lies. Verbal abuse. Distorted truth hurts. Seek clean communication."
    },
    {
        id = 51, suit = suits[3], rank = ranks[2],
        name = "Two of Swords",
        keywords = "Impasse, difficult choice, denial, balance",
        timing = "Stalled",
        meaning = "Difficult decision. Impasse. Precarious balance. Remove the blindfold and face the situation.",
        reversed_meaning = "Postponed decision. Escape from truth. Internal conflict. Free yourself from paralysis and choose."
    },
    {
        id = 52, suit = suits[3], rank = ranks[3],
        name = "Three of Swords",
        keywords = "Pain, betrayal, sadness, heartbreak",
        timing = "Recent pain",
        meaning = "Emotional pain. Betrayal. Broken heart. Suffering is real, but it's the first step toward healing.",
        reversed_meaning = "Slow recovery. Holding grudges. Difficulty forgiving. Free yourself from the poison of resentment."
    },
    {
        id = 53, suit = suits[3], rank = ranks[4],
        name = "Four of Swords",
        keywords = "Rest, recovery, contemplation, pause",
        timing = "Necessary pause",
        meaning = "Mental rest. Retreat. Recovery. Step away from the noise and recharge your mind.",
        reversed_meaning = "Insomnia. Mental exhaustion. Inability to relax. Excessive thinking makes you sick."
    },
    {
        id = 54, suit = suits[3], rank = ranks[5],
        name = "Five of Swords",
        keywords = "Conflict, defeat, hostility, hollow victory",
        timing = "Current conflict",
        meaning = "Conflict. Empty victory. Humiliation. Sometimes winning the battle means losing the war.",
        reversed_meaning = "Reconciliation. Remorse. Putting pride aside. Seek peace instead of being right."
    },
    {
        id = 55, suit = suits[3], rank = ranks[6],
        name = "Six of Swords",
        keywords = "Transition, healing, journey, moving on",
        timing = "Gradual transition",
        meaning = "Smooth transition. Healing journey. Leaving turbulent waters behind. Toward calm waters.",
        reversed_meaning = "Resistance to change. Emotional baggage. Staying stuck in the problem. Release what you cannot carry."
    },
    {
        id = 56, suit = suits[3], rank = ranks[7],
        name = "Seven of Swords",
        keywords = "Strategy, deception, escape, cunning",
        timing = "Fast, stealthy",
        meaning = "Strategy. Subtle escape. Not everything needs to be faced head-on. Act with intelligence.",
        reversed_meaning = "Deception. Theft. Lack of ethics. Lies have short legs. Act with honesty."
    },
    {
        id = 57, suit = suits[3], rank = ranks[8],
        name = "Eight of Swords",
        keywords = "Imprisonment, self-sabotage, limitation, fear",
        timing = "Mental prison, temporary",
        meaning = "Feeling trapped. Self-sabotage. Imaginary limitations. The prison is mental – the key is within you.",
        reversed_meaning = "Liberation. New perspective. Overcoming limiting beliefs. Break the bonds and see the light."
    },
    {
        id = 58, suit = suits[3], rank = ranks[9],
        name = "Nine of Swords",
        keywords = "Anxiety, nightmare, worry, anguish",
        timing = "Nocturnal, insomnia",
        meaning = "Anxiety. Nightmares. Nocturnal worries. The mind is its own tormentor. Seek to calm your thoughts.",
        reversed_meaning = "Recovery from anguish. Learning from pain. The worst is over. Take a deep breath."
    },
    {
        id = 59, suit = suits[3], rank = ranks[10],
        name = "Ten of Swords",
        keywords = "Painful ending, betrayal, crisis, rebirth",
        timing = "Rock bottom, new dawn",
        meaning = "Painful ending. Final betrayal. Rock bottom. From this abyss one can only rise – dawn arrives.",
        reversed_meaning = "Recovery. Resistance. Avoiding the final collapse. Suffering can be transformed into strength."
    },
    {
        id = 60, suit = suits[3], rank = ranks[11],
        name = "Page of Swords",
        keywords = "Curiosity, communication, ideas, vigilance",
        timing = "News shortly",
        meaning = "Intellectual curiosity. New ideas. Agile communication. Speak your truth, but with tact.",
        reversed_meaning = "Gossip. Superficial thinking. Baseless criticism. Use your mind to build, not destroy."
    },
    {
        id = 61, suit = suits[3], rank = ranks[12],
        name = "Knight of Swords",
        keywords = "Swift action, impulse, determination, conflict",
        timing = "Now, urgent",
        meaning = "Impetuous action. Intellectual determination. Advance with momentum, but don't trample others.",
        reversed_meaning = "Blind impulsiveness. Unnecessary confrontation. Aggressiveness. Think before brandishing the sword."
    },
    {
        id = 62, suit = suits[3], rank = ranks[13],
        name = "Queen of Swords",
        keywords = "Rationality, independence, discernment, truth",
        timing = "Mature decision",
        meaning = "Clear rationality. Independence. Weighted justice. Make decisions with the mind, but without losing empathy.",
        reversed_meaning = "Emotional coldness. Bitterness. Harsh judgment. Reason without heart becomes cruelty."
    },
    {
        id = 63, suit = suits[3], rank = ranks[14],
        name = "King of Swords",
        keywords = "Intellectual authority, ethics, clarity, justice",
        timing = "Legal authority, long term",
        meaning = "Intellectual authority. Ethics. Just and lucid leadership. Truth is your sharpest sword.",
        reversed_meaning = "Mental tyranny. Manipulation of truth. Abuse of power. Intellect without morals oppresses."
    },

    -- ═══════════════════════  NAIPE DE OUROS (Pentacles) ═══════════════════════
    {
        id = 64, suit = suits[4], rank = ranks[1],
        name = "Ace of Pentacles",
        keywords = "Opportunity, prosperity, new resource, security",
        timing = "Material beginning",
        meaning = "New material opportunity. Prosperity at hand. Get to work to reap solid fruits.",
        reversed_meaning = "Missed opportunity. Greed. Financial delay. The foundation needs to be set before growing."
    },
    {
        id = 65, suit = suits[4], rank = ranks[2],
        name = "Two of Pentacles",
        keywords = "Balance, adaptation, juggling, priorities",
        timing = "Fluctuating",
        meaning = "Financial balance. Juggling. Adapt to changes without losing control of your accounts.",
        reversed_meaning = "Disorganization. Debt overload. Inability to prioritize. Reorganize your finances."
    },
    {
        id = 66, suit = suits[4], rank = ranks[3],
        name = "Three of Pentacles",
        keywords = "Teamwork, collaboration, mastery, skill",
        timing = "Project in progress",
        meaning = "Teamwork. Mastery. Productive collaboration. Together, the result is greater than the sum.",
        reversed_meaning = "Lack of collaboration. Carelessness. Poor workmanship. Restore respect for excellence."
    },
    {
        id = 67, suit = suits[4], rank = ranks[4],
        name = "Four of Pentacles",
        keywords = "Security, attachment, saving, control",
        timing = "Stable, stagnant",
        meaning = "Material security. Attachment to possessions. Healthy saving, but without closing off to the new.",
        reversed_meaning = "Miserliness. Fear of loss. Blocking abundance. Let go a little control to receive."
    },
    {
        id = 68, suit = suits[4], rank = ranks[5],
        name = "Five of Pentacles",
        keywords = "Hardship, scarcity, exclusion, aid",
        timing = "Difficult period",
        meaning = "Material hardship. Feeling of exclusion. Help is closer than you think. Ask for assistance.",
        reversed_meaning = "Financial recovery. End of scarcity. Re-inclusion. Light shines at the end of the tunnel."
    },
    {
        id = 69, suit = suits[4], rank = ranks[6],
        name = "Six of Pentacles",
        keywords = "Generosity, sharing, charity, balance",
        timing = "Give and receive",
        meaning = "Generosity. Sharing. Giving and receiving in balance. Prosperity circulates when the hand opens.",
        reversed_meaning = "Self-interested charity. Debts. Imbalance in giving. Beware of those who only ask and never give back."
    },
    {
        id = 70, suit = suits[4], rank = ranks[7],
        name = "Seven of Pentacles",
        keywords = "Patience, harvest, evaluation, investment",
        timing = "Long term",
        meaning = "Patience. Harvest in progress. Evaluate if your efforts are yielding the expected fruits.",
        reversed_meaning = "Impatience. Fruitless work. Frustration with results. Recalculate the route and continue."
    },
    {
        id = 71, suit = suits[4], rank = ranks[8],
        name = "Eight of Pentacles",
        keywords = "Dedication, learning, improvement, work",
        timing = "Daily, constant",
        meaning = "Dedicated learning. Craftsmanship. Constant improvement. Mastery requires daily practice.",
        reversed_meaning = "Perfectionism. Monotonous work. Lack of motivation. Rekindle the pleasure in doing."
    },
    {
        id = 72, suit = suits[4], rank = ranks[9],
        name = "Nine of Pentacles",
        keywords = "Self-sufficiency, luxury, achievement, independence",
        timing = "Personal harvest",
        meaning = "Self-sufficiency. Personal luxury. Material achievement with independence. Enjoy what you have built.",
        reversed_meaning = "Financial dependence. Empty ostentation. Material insecurity. Real value lies in who you are."
    },
    {
        id = 73, suit = suits[4], rank = ranks[10],
        name = "Ten of Pentacles",
        keywords = "Wealth, legacy, family, stability",
        timing = "Permanent, long term",
        meaning = "Lasting wealth. Family legacy. Material and emotional security. Strong roots nourish the future.",
        reversed_meaning = "Loss of inheritance. Family conflicts over money. Financial instability. Rebuild the foundations."
    },
    {
        id = 74, suit = suits[4], rank = ranks[11],
        name = "Page of Pentacles",
        keywords = "Study, ambition, focus, new project",
        timing = "Slow start",
        meaning = "Applied study. New skill. Constructive ambition. Start small, dream big.",
        reversed_meaning = "Lack of focus. Slow progress. Premature abandonment. Persist in studies and work."
    },
    {
        id = 75, suit = suits[4], rank = ranks[12],
        name = "Knight of Pentacles",
        keywords = "Hard work, routine, patience, reliability",
        timing = "Step by step",
        meaning = "Hard work. Reliable routine. Patience to build. Steady steps take you far.",
        reversed_meaning = "Stagnation. Boredom. Lack of ambition. Move before inertia becomes permanent."
    },
    {
        id = 76, suit = suits[4], rank = ranks[13],
        name = "Queen of Pentacles",
        keywords = "Prosperity, practical care, home, security",
        timing = "Domestic cycle",
        meaning = "Homely prosperity. Practical care. Generous mother. Your material security sustains those you love.",
        reversed_meaning = "Neglect of home. Selfish materialism. Work-home imbalance. Take care of your nest first."
    },
    {
        id = 77, suit = suits[4], rank = ranks[14],
        name = "King of Pentacles",
        keywords = "Success, abundance, stability, business",
        timing = "Financial maturity",
        meaning = "Financial success. Prosperous leadership. Abundance with stability. Your business acumen is a gift.",
        reversed_meaning = "Miserliness. Extreme materialism. Corruption. Wealth without purpose is empty and corrupts."
    },
}

-- Montagem final do baralho completo
local FULL_DECK = {}
for _, card in ipairs(MAJOR_ARCANA) do
    table.insert(FULL_DECK, card)
end
for _, card in ipairs(MINOR_ARCANA) do
    table.insert(FULL_DECK, card)
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 4: CARTAS - LENORMAND (36)                             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local LENORMAND_DECK = {
    {
        id = 1, number = 1,
        name = "The Rider",
        symbol = "♞",
        keywords = "News, message, visitor, swiftness",
        meaning = "News arriving. A visitor or important message. Swift movement and good tidings on the horizon."
    },
    {
        id = 2, number = 2,
        name = "The Clover",
        symbol = "♣",
        keywords = "Luck, opportunity, lightness, moment",
        meaning = "Passing luck. Fleeting opportunity. Simple joy. Enjoy the present moment with lightness."
    },
    {
        id = 3, number = 3,
        name = "The Ship",
        symbol = "⛵",
        keywords = "Travel, change, adventure, movement",
        meaning = "Travel. Change of scenery. New horizons. Venture forth, the world awaits you."
    },
    {
        id = 4, number = 4,
        name = "The House",
        symbol = "⌂",
        keywords = "Home, family, security, roots",
        meaning = "Home. Family security. Firm roots. Care for your sacred space with love and dedication."
    },
    {
        id = 5, number = 5,
        name = "The Tree",
        symbol = "♧",
        keywords = "Health, growth, nature, vitality",
        meaning = "Health. Personal growth. Connection with nature. Your roots are deep, your fruits will come."
    },
    {
        id = 6, number = 6,
        name = "The Clouds",
        symbol = "☁",
        keywords = "Confusion, uncertainty, doubt, fog",
        meaning = "Confusion. Temporary uncertainty. Lingering doubts. Clarity will come after the storm passes."
    },
    {
        id = 7, number = 7,
        name = "The Snake",
        symbol = "≈",
        keywords = "Seduction, betrayal, manipulation, cunning",
        meaning = "Seduction. Betrayal or manipulation. Beware of false promises. Wisdom lies in seeing beyond appearances."
    },
    {
        id = 8, number = 8,
        name = "The Coffin",
        symbol = "⚰",
        keywords = "Ending, transformation, loss, rebirth",
        meaning = "End of a cycle. Deep transformation. Let the past rest. The new is born from what has gone."
    },
    {
        id = 9, number = 9,
        name = "The Bouquet",
        symbol = "⚘",
        keywords = "Gift, compliment, beauty, gratitude",
        meaning = "Gift. Compliment. Recognition. The beauty of life reveals itself in small kindnesses."
    },
    {
        id = 10, number = 10,
        name = "The Scythe",
        symbol = "⚔",
        keywords = "Cut, decision, rupture, warning",
        meaning = "Necessary cut. Drastic decision. Imminent rupture. Sometimes you must cut to heal."
    },
    {
        id = 11, number = 11,
        name = "The Whip",
        symbol = "≈≈",
        keywords = "Conflict, debate, passion, repetition",
        meaning = "Conflict. Heated discussions. Intense passion. Channel energy into productive actions."
    },
    {
        id = 12, number = 12,
        name = "The Birds",
        symbol = "♫",
        keywords = "Talk, gossip, communication, nervousness",
        meaning = "Important conversations. Gossip or news. Communication in focus. Choose your words wisely."
    },
    {
        id = 13, number = 13,
        name = "The Child",
        symbol = "☺",
        keywords = "Innocence, new start, purity, playfulness",
        meaning = "Innocence. New beginning. Purity of intention. Embrace your inner child with tenderness."
    },
    {
        id = 14, number = 14,
        name = "The Fox",
        symbol = "≈≈",
        keywords = "Cunning, cleverness, deceit, adaptation",
        meaning = "Cunning. Cleverness. Beware of deception. Use your intelligence for good, not manipulation."
    },
    {
        id = 15, number = 15,
        name = "The Bear",
        symbol = "♚",
        keywords = "Strength, protection, power, authority",
        meaning = "Protective strength. Financial power. Natural authority. Leadership with generosity brings prosperity."
    },
    {
        id = 16, number = 16,
        name = "The Star",
        symbol = "★",
        keywords = "Hope, clarity, purpose, light",
        meaning = "Hope. Clarity of purpose. Follow your inner light. The universe conspires in your favor."
    },
    {
        id = 17, number = 17,
        name = "The Stork",
        symbol = "♆",
        keywords = "Positive change, renewal, transition, blessing",
        meaning = "Positive change. Renewal. Blessed transition. New energies arrive to transform your life."
    },
    {
        id = 18, number = 18,
        name = "The Dog",
        symbol = "♉",
        keywords = "Friendship, loyalty, companionship, trust",
        meaning = "Loyal friendship. Fidelity. Sincere companionship. Value those who walk beside you."
    },
    {
        id = 19, number = 19,
        name = "The Tower",
        symbol = "♜",
        keywords = "Authority, structure, isolation, institution",
        meaning = "Institutional authority. Protection. Solid structure. Build firm foundations for the future."
    },
    {
        id = 20, number = 20,
        name = "The Garden",
        symbol = "❦",
        keywords = "Social life, community, meeting, public",
        meaning = "Social life. Community. Public encounters. Open yourself to new connections and environments."
    },
    {
        id = 21, number = 21,
        name = "The Mountain",
        symbol = "▲",
        keywords = "Obstacle, challenge, blockage, persistence",
        meaning = "Obstacle. Challenge to overcome. Temporary blockage. The view from the top justifies the climb."
    },
    {
        id = 22, number = 22,
        name = "The Crossroads",
        symbol = "⛗",
        keywords = "Choice, decision, direction, alternative",
        meaning = "Important choice. Crucial decision. Multiple paths. Follow your intuition at the crossroads."
    },
    {
        id = 23, number = 23,
        name = "The Mice",
        symbol = "🐭",
        keywords = "Loss, wear, worry, corrosion",
        meaning = "Gradual loss. Wear and tear. Corroding worries. Attention to details that go unnoticed."
    },
    {
        id = 24, number = 24,
        name = "The Heart",
        symbol = "♥",
        keywords = "Love, passion, affection, romance",
        meaning = "True love. Passion. Deep affection. Open your heart without fear of being happy."
    },
    {
        id = 25, number = 25,
        name = "The Ring",
        symbol = "◎",
        keywords = "Commitment, alliance, cycle, union",
        meaning = "Commitment. Alliance. Completed cycle. Honor your pacts and promises with integrity."
    },
    {
        id = 26, number = 26,
        name = "The Book",
        symbol = "▣",
        keywords = "Secret, knowledge, study, mystery",
        meaning = "Secret. Hidden knowledge. Mystery to be revealed. The answer lies between the lines."
    },
    {
        id = 27, number = 27,
        name = "The Letter",
        symbol = "✉",
        keywords = "Message, document, communication, news",
        meaning = "Written message. Important document. Formal communication. News arriving on paper."
    },
    {
        id = 28, number = 28,
        name = "The Gentleman",
        symbol = "♂",
        keywords = "Man, partner, action, yang",
        meaning = "Influential male figure. Partner or seeker. Yang force. Action and initiative."
    },
    {
        id = 29, number = 29,
        name = "The Lady",
        symbol = "♀",
        keywords = "Woman, partner, intuition, yin",
        meaning = "Influential female figure. Partner or seeker. Yin force. Intuition and nurturing."
    },
    {
        id = 30, number = 30,
        name = "The Lilies",
        symbol = "⚜",
        keywords = "Peace, harmony, wisdom, virtue",
        meaning = "Peace. Harmony. Mature wisdom. The virtue of patience blooms in your garden."
    },
    {
        id = 31, number = 31,
        name = "The Sun",
        symbol = "☼",
        keywords = "Success, victory, energy, happiness",
        meaning = "Success. Victory. Full vital energy. Everything is illuminated, enjoy this moment."
    },
    {
        id = 32, number = 32,
        name = "The Moon",
        symbol = "☽",
        keywords = "Recognition, fame, creativity, intuition",
        meaning = "Intuition. Recognition. Fame and creativity. Your talents are recognized under moonlight."
    },
    {
        id = 33, number = 33,
        name = "The Key",
        symbol = "⚷",
        keywords = "Solution, opening, opportunity, answer",
        meaning = "Solution. Opening doors. Decisive opportunity. The answer you seek is within reach."
    },
    {
        id = 34, number = 34,
        name = "The Fish",
        symbol = "♓",
        keywords = "Abundance, finances, flow, prosperity",
        meaning = "Financial abundance. Prosperity. Flow of resources. Wealth flows like clean water."
    },
    {
        id = 35, number = 35,
        name = "The Anchor",
        symbol = "⚓",
        keywords = "Stability, security, work, steadfastness",
        meaning = "Stability. Lasting security. Steady work. Build solid foundations for tomorrow."
    },
    {
        id = 36, number = 36,
        name = "The Cross",
        symbol = "✚",
        keywords = "Destiny, trial, burden, transcendence",
        meaning = "Destiny. Necessary trial. Sacred burden. Suffering brings wisdom and transcendence."
    },
}

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                  SEÇÃO 5: PLUGIN PRINCIPAL (TarotPlugin)                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local TarotPlugin = InputContainer:extend{
    name        = "tarot",
    fullname    = T(UI_TEXT.title),
    is_doc_only = false,
}

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

    self.ui.menu:registerToMainMenu(self)
    self.plugin_dir = self:getPluginDirectory()
    self.saves_dir = self.plugin_dir .. "/tiragens_salvas"
    self.journal_dir = self.plugin_dir .. "/diario_reflexoes"
    self.journal_trash_dir = self.journal_dir .. "/lixeira"
    self.journal_export_dir = self.journal_dir .. "/exportacoes"
    self.journal_backup_dir = self.journal_dir .. "/backups"
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
    self.hidden_card_reveal_hint_shown_this_session = false
    self.next_card_reveal_hint_shown_this_session = false
    
    self:ensureSavesDir()
    self:ensureJournalDirs()
end

function TarotPlugin:getTranslation(key)
    local msgid = UI_TEXT[key]
    if not msgid then
        logger.warn("tarot.koplugin: chave de tradução desconhecida:", tostring(key))
        return tostring(key)
    end
    return T(msgid)
end

function TarotPlugin:refreshMenu()
    self.ui.menu:registerToMainMenu(self)
end

function TarotPlugin:getPluginDirectory()
    if self.path then return self.path end
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
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:toggleMajorOnly()
    self.major_only = not self.major_only
    G_reader_settings:saveSetting("tarot_major_only", self.major_only)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:setReadingDeck(use_lenormand)
    self.use_lenormand = use_lenormand == true
    G_reader_settings:saveSetting("tarot_use_lenormand", self.use_lenormand)
    UIManager:setDirty(nil, "full")
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
    UIManager:setDirty(nil, "full")
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
    UIManager:setDirty(nil, "full")
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
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:toggleShowReversedLabel()
    self.show_reversed_label = not self.show_reversed_label
    G_reader_settings:saveSetting("tarot_show_reversed_label", self.show_reversed_label)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:toggleAutoSaveSpreads()
    self.auto_save_spreads = not self.auto_save_spreads
    G_reader_settings:saveSetting("tarot_auto_save_spreads", self.auto_save_spreads)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:toggleUnsavedCloseWarning()
    self.disable_unsaved_close_warning = not self.disable_unsaved_close_warning
    G_reader_settings:saveSetting(
        "tarot_disable_unsaved_close_warning",
        self.disable_unsaved_close_warning
    )
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:toggleViewInBookButton()
    self.disable_view_in_book = not self.disable_view_in_book
    G_reader_settings:saveSetting("tarot_disable_view_in_book", self.disable_view_in_book)
    UIManager:setDirty(nil, "full")
end

-- Exibe uma orientação com caixa de seleção e um único botão "Confirmar".
-- A preferência só é gravada quando o usuário marca explicitamente
-- "Não mostrar novamente" antes de confirmar. Sem essa marcação, o aviso
-- continuará aparecendo sempre que o mesmo passo for acessado novamente.
function TarotPlugin:showDismissibleHint(setting_key, _session_field, message_key)
    if G_reader_settings:readSetting(setting_key) == true then return end

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
        "tarot_hidden_card_reveal_hint_dismissed",
        "hidden_card_reveal_hint_shown_this_session",
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

function TarotPlugin:restoreAll()
    -- Todas as chaves persistentes utilizadas pelo plugin, incluindo opções
    -- removidas em versões anteriores e avisos exibidos uma única vez.
    local setting_keys = {
        "tarot_allow_reversed",
        "tarot_major_only",
        "tarot_use_lenormand",
        "tarot_daily_deck_mode",
        "tarot_daily_deck_choice_date",
        "tarot_daily_deck_choice_is_lenormand",
        "tarot_disable_spread_meanings",
        "tarot_spread_meaning_mode",
        "tarot_disable_view_in_book",
        "tarot_auto_save_spreads",
        "tarot_disable_unsaved_close_warning",
        "tarot_show_reversed_label",
        "tarot_meaning_text_size",
        "tarot_hidden_card",
        "tarot_physical_deck_reverse_hint_seen",
        "tarot_physical_deck_reverse_hint_dismissed",
        "tarot_card_dialog_navigation_hint_dismissed",
        "tarot_hidden_card_reveal_hint_dismissed",
        "tarot_next_card_reveal_hint_dismissed",
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

    -- Apaga por completo os dois diretórios gerados pelo plugin. Isso inclui
    -- registros antigos e novos, lixeira, exportações e todos os backups.
    local ok = true
    if self.saves_dir and not self:clearDirectoryRecursive(self.saves_dir, false) then
        ok = false
    end
    if self.journal_dir and not self:clearDirectoryRecursive(self.journal_dir, false) then
        ok = false
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
    self.hidden_card_reveal_hint_shown_this_session = false
    self.next_card_reveal_hint_shown_this_session = false

    -- Descarta referências a telas e estados antigos para impedir que uma tela
    -- já aberta reapresente dados apagados depois da restauração.
    self.journal_dialog = nil
    self.journal_filter_dialog = nil
    self.journal_more_dialog = nil
    self.journal_edit_menu = nil
    self.journal_trash_dialog = nil
    self.journal_backup_dialog = nil

    UIManager:setDirty(nil, "full")
    return ok
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           SEÇÃO 6: IMAGENS DAS CARTAS (suporte a PNG/JPG)                    ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

function TarotPlugin:getCardImagePath(card)
    if card.symbol then
        local en_clean = card.name:gsub("^The%s+", "")
        return self.plugin_dir .. "/cards_lenormand/" .. tostring(card.number) .. "._" .. en_clean .. ".png"
    elseif card.roman then
        local id_str = string.format("%02d", card.id)
        local name_en_clean = card.name:gsub(" ", ""):gsub("'", "")
        return self.plugin_dir .. "/cards_tarot/" .. id_str .. "-" .. name_en_clean .. ".jpg"
    elseif card.suit then
        local suit_en = card.suit.name
        local rank_map = { Ace=1, Two=2, Three=3, Four=4, Five=5, Six=6, Seven=7, Eight=8, Nine=9, Ten=10, Page=11, Knight=12, Queen=13, King=14 }
        local rank_val = rank_map[card.rank.name] or 0
        local rank_str = string.format("%02d", rank_val)
        return self.plugin_dir .. "/cards_tarot/" .. suit_en .. rank_str .. ".jpg"
    end
end

function TarotPlugin:getCardImageWidget(card, w_override, h_override, rotation_angle)
    local path = self:getCardImagePath(card)
    local screen_w = Screen:getWidth()
    local card_w, card_h
    if card.symbol then
        card_w = w_override or 250
        card_h = h_override or 250
    else
        local base_w = math.floor(screen_w * 0.25)
        card_w = w_override or base_w
        if h_override then
            card_h = h_override
        else
            card_h = math.floor(card_w * (439 / 250))
        end
    end
    
    local attr = lfs.attributes(path)
    if attr and attr.mode == "file" then
        return ImageWidget:new{
            file = path,
            width = card_w,
            height = card_h,
            scale_for_dpi = false,
            rotation_angle = rotation_angle or 0,
        }
    else
        local text = ""
        if card.symbol then
            text = card.symbol .. "\n" .. T(card.name)
        elseif card.roman then
            text = card.roman .. "\n" .. T(card.name)
        elseif card.suit then
            local suit_symbol = card.suit.symbol or ""
            local rank_pt = T(card.rank.name)
            text = suit_symbol .. "\n" .. rank_pt
        end
        local fallback = TextWidget:new{
            text = text,
            face = Font:getFace("tfont"),
            bold = true,
            alignment = "center",
        }
        return FrameContainer:new{
            width = card_w,
            height = card_h,
            bordersize = 0,
            background = Blitbuffer.COLOR_WHITE,
            CenterContainer:new{
                dimen = { w = card_w, h = card_h },
                fallback,
            },
        }
    end
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
        width = w,
        height = h,
    }
end

function TarotPlugin:getDefaultCardSize(card)
    local screen_w = Screen:getWidth()
    if card.symbol then
        return 250, 250
    else
        local w = math.floor(screen_w * 0.25)
        local h = math.floor(w * (439 / 250))
        return w, h
    end
end

function TarotPlugin:getBackCardImageWidget(w_override, h_override, deck_is_lenormand)
    local screen_w = Screen:getWidth()
    local card_w, card_h
    local path
    if deck_is_lenormand == nil then
        deck_is_lenormand = self.use_lenormand == true
    end
    if deck_is_lenormand then
        path = self.plugin_dir .. "/cards_lenormand/Card_Back.png"
        card_w = w_override or 250
        card_h = h_override or 250
    else
        path = self.plugin_dir .. "/cards_tarot/CardBacks.jpg"
        card_w = w_override or math.floor(screen_w * 0.25)
        card_h = h_override or math.floor(card_w * (439 / 250))
    end
    
    local attr = lfs.attributes(path)
    if attr and attr.mode == "file" then
        return ImageWidget:new{
            file = path,
            width = card_w,
            height = card_h,
            scale_for_dpi = false,
        }
    else
        local fallback = TextWidget:new{
            text = "?",
            face = Font:getFace("tfont"),
            bold = true,
            alignment = "center",
        }
        return FrameContainer:new{
            width = card_w,
            height = card_h,
            bordersize = 0,
            background = Blitbuffer.gray(0.8),
            CenterContainer:new{
                dimen = { w = card_w, h = card_h },
                fallback,
            },
        }
    end
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║        SEÇÃO 7: DIÁRIO DE REFLEXÕES (armazenamento, busca e UI)             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- Os registros novos usam arquivos .trj de texto simples e não executável.
-- O formato é deliberadamente pequeno e tolerante a caracteres especiais.
-- Tiragens antigas em .txt continuam intactas e aparecem como registros antigos.
local JOURNAL_MAGIC = "TAROT_JOURNAL_V1"

local function journalTrim(text)
    text = tostring(text or "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function journalEscape(text)
    text = tostring(text or "")
    text = text:gsub("%%", "%%25")
    text = text:gsub("\r", "%%0D")
    text = text:gsub("\n", "%%0A")
    text = text:gsub("\t", "%%09")
    return text
end

local function journalUnescape(text)
    text = tostring(text or "")
    text = text:gsub("%%09", "\t")
    text = text:gsub("%%0A", "\n")
    text = text:gsub("%%0D", "\r")
    text = text:gsub("%%25", "%%")
    return text
end

local function journalReadAll(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local function journalWriteAll(path, content)
    local file, err = io.open(path, "wb")
    if not file then return false, err end
    file:write(content or "")
    file:close()
    return true
end

local function journalCopyFile(source, target)
    local content = journalReadAll(source)
    if content == nil then return false end
    return journalWriteAll(target, content)
end

local function journalUniquePath(directory, filename)
    local stem, extension = filename:match("^(.*)(%.[^%.]+)$")
    stem = stem or filename
    extension = extension or ""
    local candidate = directory .. "/" .. filename
    local counter = 2
    while lfs.attributes(candidate) do
        candidate = directory .. "/" .. stem .. "_" .. counter .. extension
        counter = counter + 1
    end
    return candidate
end

local function journalShallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            local nested = {}
            for nested_key, nested_value in pairs(value) do
                nested[nested_key] = nested_value
            end
            copy[key] = nested
        else
            copy[key] = value
        end
    end
    return copy
end

local function journalSafeLower(text)
    text = tostring(text or "")
    local replacements = {
        ["Á"]="á", ["À"]="à", ["Â"]="â", ["Ã"]="ã", ["Ä"]="ä",
        ["É"]="é", ["È"]="è", ["Ê"]="ê", ["Ë"]="ë",
        ["Í"]="í", ["Ì"]="ì", ["Î"]="î", ["Ï"]="ï",
        ["Ó"]="ó", ["Ò"]="ò", ["Ô"]="ô", ["Õ"]="õ", ["Ö"]="ö",
        ["Ú"]="ú", ["Ù"]="ù", ["Û"]="û", ["Ü"]="ü",
        ["Ç"]="ç", ["Ñ"]="ñ",
    }
    for upper, lower in pairs(replacements) do
        text = text:gsub(upper, lower)
    end
    return text:lower()
end

local function journalPreview(text, max_bytes)
    text = journalTrim(tostring(text or ""):gsub("[%s\r\n]+", " "))
    -- Não cortamos por bytes para não partir caracteres UTF-8. O botão possui
    -- altura fixa e o próprio KOReader aplica reticências de maneira segura.
    return text
end

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

    local lines = {
        JOURNAL_MAGIC,
        "id=" .. journalEscape(entry.id),
        "created_at=" .. tostring(entry.created_at),
        "updated_at=" .. tostring(entry.updated_at),
        "entry_type=" .. journalEscape(entry.entry_type),
        "deck=" .. journalEscape(entry.deck),
        "spread_type=" .. journalEscape(entry.spread_type or ""),
        "title=" .. journalEscape(entry.title),
        "note=" .. journalEscape(entry.note),
        "outcome=" .. journalEscape(entry.outcome),
        "outcome_at=" .. tostring(entry.outcome_at),
        "favorite=" .. (entry.favorite and "1" or "0"),
    }

    for _, card_data in ipairs(entry.cards) do
        local id = tonumber(card_data.id)
        if id then
            table.insert(lines, "card=" .. tostring(id) .. "|" .. (card_data.is_reversed and "1" or "0"))
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

    local entry = { cards = {}, filepath = path, source = "structured" }
    for line in content:gmatch("[^\r\n]+") do
        local key, value = line:match("^([^=]+)=(.*)$")
        if key == "card" then
            local id, reversed = value:match("^(%-?%d+)|([01])$")
            if id then
                table.insert(entry.cards, {
                    id = tonumber(id),
                    is_reversed = reversed == "1",
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
    entry.filename = path:match("([^/]+)$")
    return entry
end

function TarotPlugin:makeJournalEntryFromCards(cards, title, note, entry_type)
    local is_lenormand = cards and cards[1] and cards[1].card and cards[1].card.symbol ~= nil
    local card_refs = {}
    for _, card_data in ipairs(cards or {}) do
        if card_data.card and card_data.card.id ~= nil then
            table.insert(card_refs, {
                id = card_data.card.id,
                is_reversed = card_data.is_reversed == true,
            })
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
        title = title or "",
        note = note or "",
        outcome = "",
        outcome_at = 0,
        favorite = false,
        cards = card_refs,
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
    local metadata = star .. date_text .. " · " .. self:getJournalDeckText(entry) .. " · " .. self:getJournalEntryTypeText(entry)
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
        UIManager:setDirty(nil, "full")
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
    local content = VerticalGroup:new{ align = "center" }
    local subtitle = string.format(self:getTranslation("journal_records"), #entries)
    table.insert(content, makeSectionHeader(self:getTranslation("saved_readings"), iw, subtitle))
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    local action_w = math.floor((iw - Size.span.horizontal_default) / 2)
    table.insert(content, HorizontalGroup:new{
        align = "center",
        makeRoundedButton{
            text = self:getTranslation("new_reflection"), width = action_w,
            callback = function()
                self:closeJournalDialog()
                self:showNewReflectionTitleInput()
            end,
        },
        HorizontalSpan:new{ width = Size.span.horizontal_default },
        makeRoundedButton{
            text = self:getTranslation("search"), width = action_w,
            callback = function()
                self:closeJournalDialog()
                self:showJournalSearchInput()
            end,
        },
    })
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, HorizontalGroup:new{
        align = "center",
        makeRoundedButton{
            text = self:getTranslation("filter"), width = action_w,
            callback = function()
                self:closeJournalDialog()
                self:showJournalFilterMenu()
            end,
        },
        HorizontalSpan:new{ width = Size.span.horizontal_default },
        makeRoundedButton{
            text = self:getTranslation("more"), width = action_w,
            callback = function()
                self:closeJournalDialog()
                self:showJournalMoreMenu()
            end,
        },
    })
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    if #entries == 0 then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(content, makeMutedText(self:getTranslation("no_journal_results"), math.floor(iw * 0.88)))
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(content, makeRoundedButton{
            text = self:getTranslation("clear_filters"), width = math.floor(iw * 0.72),
            callback = function()
                self:clearJournalFilters()
                self:showSavedReadingsMenu(1)
            end,
        })
    else
        local start_index = (state.page - 1) * per_page + 1
        local end_index = math.min(#entries, start_index + per_page - 1)
        local previous_month
        local item_height = math.max(72, math.floor(layout.safe_h * 0.075))

        for index = start_index, end_index do
            local entry = entries[index]
            local month_key = os.date("%m/%Y", entry.created_at or 0)
            if month_key ~= previous_month then
                table.insert(content, TextWidget:new{
                    text = "— " .. month_key .. " —",
                    face = Font:getFace("x_smallinfofont"),
                    fgcolor = Blitbuffer.gray(0.48),
                    max_width = iw,
                    alignment = "center",
                })
                table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
                previous_month = month_key
            end

            table.insert(content, Button:new{
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
            table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
        end
    end

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    local nav_button_w = math.floor(iw * 0.23)
    local page_label_w = math.floor(iw * 0.32)
    table.insert(content, HorizontalGroup:new{
        align = "center",
        makeRoundedButton{
            text = "‹", width = nav_button_w, enabled = state.page > 1,
            callback = function() self:showSavedReadingsMenu(state.page - 1) end,
        },
        HorizontalSpan:new{ width = Size.span.horizontal_default },
        CenterContainer:new{
            dimen = { w = page_label_w, h = 40 },
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
    })

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, makeTarotDivider(iw))
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    table.insert(content, makeTransparentTextButton{
        text = self:getTranslation("close"), width = math.floor(iw * 0.42),
        callback = function() self:closeJournalDialog() end,
    })

    self.journal_dialog = makeFullscreenFrame(content, layout)
    UIManager:show(self.journal_dialog)
    UIManager:setDirty(nil, "full")
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
        title = self:getTranslation("journal_filter_title"),
        buttons = buttons,
    }
    UIManager:show(self.journal_filter_dialog)
    UIManager:setDirty(nil, "full")
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
    local buttons = {
        {
            { text = self:getTranslation("go_to_month"), close_before = true, callback = function() self:showJournalMonthInput() end },
            { text = self:getTranslation("journal_summary"), close_before = true, callback = function() self:showJournalSummary() end },
        },
        {
            { text = self:getTranslation("trash"), close_before = true, callback = function() self:showJournalTrash(1) end },
            { text = self:getTranslation("export_journal"), close_before = true, callback = function() self:exportJournal() end },
        },
        {
            { text = self:getTranslation("create_backup"), close_before = true, callback = function() self:createJournalBackup() end },
            { text = self:getTranslation("restore_backup"), close_before = true, callback = function() self:showJournalBackupsMenu() end },
        },
        {
            { text = self:getTranslation("clear_filters"), close_before = true, callback = function() self:clearJournalFilters(); self:showSavedReadingsMenu(1) end },
        },
        {
            { text = self:getTranslation("back"), footer = true, close_before = true, callback = function() self:showSavedReadingsMenu() end },
        },
    }
    self.journal_more_dialog = FullscreenMenuDialog:new{
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

    local dialog
    dialog = InputDialog:new{
        title = self:getTranslation("journal_summary"),
        input = table.concat(lines, "\n"),
        readonly = true,
        fullscreen = true,
        condensed = true,
        add_nav_bar = true,
        buttons = {
            {
                { text = self:getTranslation("back"), callback = function() UIManager:close(dialog); self:showSavedReadingsMenu() end },
            },
        },
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
    table.insert(lines, self:getJournalDeckText(entry) .. " · " .. self:getJournalEntryTypeText(entry))
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

function TarotPlugin:showJournalEntry(entry)
    local dialog
    local buttons

    if entry.entry_type == "legacy" then
        buttons = {
            {
                {
                    text = self:getTranslation("delete_reading"),
                    callback = function()
                        UIManager:close(dialog)
                        self:confirmDeleteFile(entry)
                    end,
                },
                {
                    text = self:getTranslation("back_to_journal"),
                    callback = function()
                        UIManager:close(dialog)
                        self:showSavedReadingsMenu()
                    end,
                },
            },
        }
    else
        buttons = {
            {
                {
                    text = self:getTranslation("view_cards"),
                    enabled = #(entry.cards or {}) > 0,
                    callback = function()
                        UIManager:close(dialog)
                        self:showJournalCards(entry)
                    end,
                },
            },
            {
                {
                    text = self:getTranslation("edit"),
                    callback = function()
                        UIManager:close(dialog)
                        self:showJournalEditMenu(entry)
                    end,
                },
                {
                    text = entry.favorite and self:getTranslation("unfavorite") or self:getTranslation("favorite"),
                    callback = function()
                        entry.favorite = not entry.favorite
                        entry.updated_at = os.time()
                        self:writeJournalEntry(entry)
                        UIManager:close(dialog)
                        self:showJournalEntry(entry)
                    end,
                },
            },
            {
                {
                    text = self:getTranslation("delete_reading"),
                    callback = function()
                        UIManager:close(dialog)
                        self:confirmDeleteFile(entry)
                    end,
                },
                {
                    text = self:getTranslation("back_to_journal"),
                    callback = function()
                        UIManager:close(dialog)
                        self:showSavedReadingsMenu()
                    end,
                },
            },
        }
    end

    dialog = InputDialog:new{
        title = self:getJournalDisplayTitle(entry),
        input = self:formatJournalEntryText(entry),
        readonly = true,
        fullscreen = true,
        -- A área de leitura ocupa o espaço disponível mesmo quando a reflexão
        -- está vazia, em vez de reduzir o conteúdo ao mínimo.
        condensed = false,
        add_nav_bar = true,
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function TarotPlugin:showJournalEditMenu(entry)
    local buttons = {
        {
            { text = self:getTranslation("edit_title"), close_before = true, callback = function() self:showEditJournalTitle(entry) end },
        },
        {
            { text = self:getTranslation("edit_reflection"), close_before = true, callback = function() self:showEditJournalReflection(entry) end },
        },
        {
            {
                text = journalTrim(entry.outcome) == "" and self:getTranslation("add_outcome") or self:getTranslation("edit_outcome"),
                close_before = true,
                callback = function() self:showEditJournalOutcome(entry) end,
            },
        },
        {
            { text = self:getTranslation("back"), footer = true, close_before = true, callback = function() self:showJournalEntry(entry) end },
        },
    }
    self.journal_edit_menu = FullscreenMenuDialog:new{
        title = self:getTranslation("edit"), buttons = buttons,
    }
    UIManager:show(self.journal_edit_menu)
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
        title = self:getTranslation("trash_title"), buttons = buttons,
    }
    UIManager:show(self.journal_trash_dialog)
end

function TarotPlugin:showTrashEntryOptions(entry, page)
    local dialog
    dialog = FullscreenMenuDialog:new{
        title = self:getJournalDisplayTitle(entry),
        buttons = {
            {
                {
                    text = self:getTranslation("restore_entry"), close_before = true,
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
                    text = self:getTranslation("delete_permanently"), close_before = true,
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
        "**" .. self:getTranslation("deck_type") .. ":** " .. self:getJournalDeckText(entry),
        "**" .. self:getTranslation("type_label") .. ":** " .. self:getJournalEntryTypeText(entry),
        "",
        "## " .. self:getTranslation("reflection_text"),
        "",
        entry.note or "",
    }
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

function TarotPlugin:showSaveTitleInput(cards, entry_type)
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
                        self:showSaveNoteInput(cards, title, entry_type or "spread")
                    end,
                },
            },
        },
    }
    UIManager:show(title_input)
    title_input:onShowKeyboard()
end

function TarotPlugin:showSaveNoteInput(cards, title, entry_type)
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
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(note_input)
    note_input:onShowKeyboard()
end


-- Contêiner transparente que adiciona toque a qualquer widget visual sem
-- alterar sua aparência. É usado nas miniaturas laterais do CardDialog.
local TappableImageContainer = InputContainer:extend{
    content = nil,
    callback = nil,
    hold_callback = nil,
}

function TappableImageContainer:init()
    self[1] = self.content
    local size = self.content and self.content:getSize() or Geom:new{ w = 0, h = 0 }
    self.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    self.ges_events = {
        TapImage = {
            GestureRange:new{
                ges = "tap",
                range = self.dimen,
            },
        },
    }
    if self.hold_callback then
        self.ges_events.HoldImage = {
            GestureRange:new{
                ges = "hold",
                range = self.dimen,
            },
        }
    end
end

function TappableImageContainer:onTapImage()
    if self.callback then self.callback() end
    return true
end

function TappableImageContainer:onHoldImage()
    if self.hold_callback then self.hold_callback() end
    return true
end

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
            UIManager:setDirty(nil, "full")
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
}

function CardDialog:init()
    local layout = getFullscreenLayout()
    local sw  = layout.screen_w
    local iw  = layout.content_w
    local use_lenormand = self.deck_is_lenormand
    if use_lenormand == nil then
        use_lenormand = self.plugin.use_lenormand
    end

    local total_cards = #self.cards
    local revealed_count = tonumber(self.revealed_count) or total_cards
    if revealed_count < 1 then revealed_count = 1 end
    if revealed_count > total_cards then revealed_count = total_cards end
    if self.current_index > revealed_count then
        self.current_index = revealed_count
    end
    local card_data = self.cards[self.current_index]
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
        and not has_unrevealed_cards
        and self.auto_save_state == nil then
        self.auto_save_state = self.plugin:autoSaveReading(self.cards) and "saved" or "failed"
    end

    local card_path = self.plugin:getCardImagePath(card)
    local has_image = card_path and lfs.attributes(card_path) and lfs.attributes(card_path).mode == "file"
    local hide_name = use_lenormand and T.current_lang == "C" and has_image

    local title_suffix = self.title_label or self.plugin:getTranslation("title")
    if not self.title_label and use_lenormand then
        title_suffix = self.plugin:getTranslation("lenormand_title")
    end
    local title_text = title_suffix

    -- O fluxo principal de tiragem já informa seu contexto antes da revelação.
    -- Para ganhar espaço útil no Kindle, o CardDialog não repete "Tirar Cartas"
    -- nem o divisor do cabeçalho. Outros usos do CardDialog mantêm seus títulos.
    local header_w
    if self.title_label ~= self.plugin:getTranslation("draw_cards") then
        header_w = makeSectionHeader(title_text, iw)
    end

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
        })
        UIManager:setDirty(nil, "full")
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
        })
        UIManager:setDirty(nil, "full")
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
                })
                UIManager:setDirty(nil, "full")
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
                UIManager:setDirty(nil, "full")
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
                UIManager:setDirty(nil, "full")
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

    local meaning_text
    if use_lenormand then
        meaning_text = T(card.meaning)
    else
        meaning_text = is_reversed and T(card.reversed_meaning) or T(card.meaning)
    end
    if meaning_mode == "summary" then
        meaning_text = summarizeCardMeaning(meaning_text, 180)
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

    local meaning_w = TextBoxWidget:new{
        text      = meaning_text,
        face      = Font:getFace(meaning_face_name),
        width     = iw,
        alignment = "center",
    }

    local meaning_label_text = self.plugin:getTranslation("meaning_label")
    if is_reversed and not use_lenormand then
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
    local btn_save = makeRoundedButton{
        text = was_auto_saved
            and self.plugin:getTranslation("saved_automatically")
            or (self.is_daily and self.plugin:getTranslation("add_to_journal") or self.plugin:getTranslation("save")),
        width = self.is_daily and math.floor(iw * 0.46) or math.floor(iw * 0.45),
        enabled = not has_unrevealed_cards and not was_auto_saved,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
            self.plugin:showSaveTitleInput(self.cards, self.is_daily and "daily" or "spread")
        end,
    }

    local function closeCardDialogNow()
        UIManager:close(self)
        UIManager:setDirty(nil, "full")
        if self.on_close then self.on_close() end
    end

    local btn_close = makeTransparentTextButton{
        text     = self.plugin:getTranslation("close"),
        width    = math.floor(iw * 0.40),
        callback = function()
            local should_warn = is_spread_view
                and not has_unrevealed_cards
                and not was_auto_saved
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
        end,
    }

    local btns_row
    if self.read_only or (has_unrevealed_cards and not self.is_daily) then
        -- Durante a revelação, a instrução é mostrada em um aviso descartável.
        -- Nenhum texto ou botão ocupa o rodapé permanentemente.
        btns_row = nil
    else
        btns_row = HorizontalGroup:new{
            align = "center",
            btn_save,
        }
    end

    local content = VerticalGroup:new{
        align = "center",
    }
    if header_w then
        table.insert(content, header_w)
    end

    if reveal_progress_w then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, reveal_progress_w)
    end

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, card_image)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    if name_w then
        table.insert(content, name_w)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    end

  

   
    if show_meaning then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(content, meaning_w)
    end

    -- Botão textual discreto para abrir a carta no livro.
    local btn_view_in_book = makeTransparentTextButton{
        text = self.plugin:getTranslation("view_in_book"),
        width = math.floor(iw * 0.5),
        callback = function()
            self.plugin:showCardInBook(card, use_lenormand)
        end,
    }
    if not self.read_only and not self.plugin.disable_view_in_book then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(content, btn_view_in_book)
    end

    -- Quando existe uma ação (Salvar), ela fica visualmente isolada entre
    -- dois divisores. Sem ação, usamos apenas um divisor antes de Fechar para
    -- impedir linhas duplicadas ou vazios artificiais.
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, makeDialogDivider())
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    if btns_row then
        table.insert(content, btns_row)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(content, makeDialogDivider())
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    end
    table.insert(content, btn_close)

    self[1] = makeFullscreenFrame(content, layout)

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

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║      SELETOR DE BARALHO FÍSICO — LISTA TEXTUAL COM ATÉ 10 CARTAS           ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- O seletor não sorteia cartas e não exibe imagens. Ele apenas registra, na
-- ordem dos toques, até dez cartas que o usuário retirou do próprio baralho.
-- Ao confirmar, as cartas escolhidas são abertas no CardDialog já existente.
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

    -- Quantidade conservadora de linhas por página. O cálculo evita que os
    -- rodapés sejam empurrados para fora da tela em Kindles de menor altura.
    local items_per_page
    if sh < 720 then
        items_per_page = 7
    elseif sh < 950 then
        items_per_page = 9
    else
        items_per_page = 11
    end

    local total_pages = math.max(1, math.ceil(#self.deck / items_per_page))
    if self.page < 1 then self.page = 1 end
    if self.page > total_pages then self.page = total_pages end

    -- Retorna a ordem em que a carta foi selecionada. Além de informar se a
    -- carta está marcada, isso permite exibir claramente as posições 1 a 10.
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
        UIManager:setDirty(nil, "full")
    end

    local function toggleCard(index)
        local selected_position = getSelectionPosition(index)

        if selected_position then
            table.remove(self.selected_indices, selected_position)
            self.reversed_indices[index] = nil
            reopen(self.page)
            return
        end

        if #self.selected_indices >= 10 then
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
            if #self.selected_indices >= 10 then
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

    local content = VerticalGroup:new{
        align = "center",
        makeSectionHeader(
            self.plugin:getTranslation("physical_deck"),
            iw,
            self.plugin:getTranslation("physical_deck_hint")
        ),
        VerticalSpan:new{ width = Size.span.vertical_default },
    }

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
            text_font_size = 20,
            text_font_bold = false,
            padding_h = Size.padding.default,
            padding_v = Size.padding.small,
            callback = function()
                toggleCard(card_index)
            end,
            hold_callback = function()
                toggleCardReversed(card_index)
            end,
        })
    end

    -- Navegação da lista. Os controles também são textuais e sem bordas para
    -- manter o seletor leve e coerente com o rodapé solicitado.
    local nav_row = HorizontalGroup:new{
        align = "center",
        makeTransparentTextButton{
            text = "<",
            width = math.floor(iw * 0.22),
            enabled = self.page > 1,
            callback = function()
                if self.page > 1 then reopen(self.page - 1) end
            end,
        },
        TextWidget:new{
            text = string.format(self.plugin:getTranslation("page_count"), self.page, total_pages),
            face = Font:getFace("x_smallinfofont"),
            fgcolor = Blitbuffer.gray(0.45),
            max_width = math.floor(iw * 0.44),
            alignment = "center",
        },
        makeTransparentTextButton{
            text = ">",
            width = math.floor(iw * 0.22),
            enabled = self.page < total_pages,
            callback = function()
                if self.page < total_pages then reopen(self.page + 1) end
            end,
        },
    }

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    table.insert(content, nav_row)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    table.insert(content, makeTarotDivider(iw))
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })

    local footer_row = HorizontalGroup:new{
        align = "center",
        makeTransparentTextButton{
            text = self.plugin:getTranslation("back"),
            width = math.floor(iw * 0.38),
            callback = function()
                UIManager:close(self)
                self.plugin:showSpreadsMenu()
                UIManager:setDirty(nil, "full")
            end,
        },
        HorizontalSpan:new{ width = math.floor(iw * 0.08) },
        makeTransparentTextButton{
            text = self.plugin:getTranslation("done"),
            width = math.floor(iw * 0.38),
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
                UIManager:setDirty(nil, "full")
            end,
        },
    }

    table.insert(content, footer_row)
    self[1] = makeFullscreenFrame(content, layout)
end

-- Abre as cartas de um registro em modo somente leitura. A navegação entre
-- cartas é feita pelas miniaturas laterais e nunca troca de registro do Diário.
function TarotPlugin:showJournalCards(entry)
    local cards = {}
    for _, saved_card in ipairs(entry.cards or {}) do
        local card = self:getJournalCard(entry, saved_card)
        if card then
            table.insert(cards, {
                card = card,
                is_reversed = saved_card.is_reversed == true,
            })
        end
    end

    if #cards == 0 then
        self:showJournalEntry(entry)
        return
    end

    UIManager:show(CardDialog:new{
        cards = cards,
        current_index = 1,
        plugin = self,
        title_label = self:getJournalDisplayTitle(entry),
        read_only = true,
        deck_is_lenormand = entry.deck == "lenormand",
        on_close = function()
            self:showJournalEntry(entry)
        end,
    })
    UIManager:setDirty(nil, "full")
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║   NOVO DIÁLOGO: CARTA OCULTA (HiddenCardDialog) – VERSÃO FINAL              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local HiddenCardDialog = InputContainer:extend{
    plugin = nil,
    cards = nil,
    on_new = nil,
    is_daily = false,
    on_reveal = nil,
    title_label = nil,
    allow_add_card = false,
    max_cards = 10,
    deck_is_lenormand = nil,
}

function HiddenCardDialog:init()
    local layout = getFullscreenLayout()
    local iw  = layout.content_w

    self.cards = self.cards or {}
    self.max_cards = tonumber(self.max_cards) or 10
    local use_lenormand = self.deck_is_lenormand
    if use_lenormand == nil then
        use_lenormand = self.plugin.use_lenormand == true
    end
    if self.max_cards < 1 then self.max_cards = 1 end

    local header_w = makeSectionHeader(
        self.title_label or self.plugin:getTranslation("title"),
        iw
    )

    -- Reconstrói a tela preservando exatamente a pilha atual. O gesto é usado
    -- pelos controles +/− e atualiza contagem, miniatura e estados desativados.
    local function refreshHiddenDialog()
        UIManager:close(self)
        UIManager:show(HiddenCardDialog:new{
            plugin = self.plugin,
            cards = self.cards,
            on_new = self.on_new,
            is_daily = self.is_daily,
            on_reveal = self.on_reveal,
            title_label = self.title_label,
            allow_add_card = self.allow_add_card,
            max_cards = self.max_cards,
            deck_is_lenormand = use_lenormand,
        })
        UIManager:setDirty(nil, "full")
    end

    local function revealCards()
        UIManager:close(self)
        UIManager:setDirty(nil, "full")
        if self.on_reveal then
            self.on_reveal()
        end
    end

    local function addCard()
        if #self.cards >= self.max_cards then return end
        local new_card = self.plugin:drawAdditionalUniqueCard(self.cards)
        if not new_card then return end
        table.insert(self.cards, new_card)
        refreshHiddenDialog()
    end

    local function removeCard()
        if #self.cards <= 1 then return end
        table.remove(self.cards)
        refreshHiddenDialog()
    end

    local back_path
    if use_lenormand then
        back_path = self.plugin.plugin_dir .. "/cards_lenormand/Card_Back.png"
    else
        back_path = self.plugin.plugin_dir .. "/cards_tarot/CardBacks.jpg"
    end
    local back_attr = lfs.attributes(back_path)
    local has_back_image = back_attr and back_attr.mode == "file"

    local screen_w = Screen:getWidth()
    local card_w, card_h

    -- Mede os símbolos reais antes de calcular o layout. Assim, o box +/−
    -- nunca recebe uma largura menor do que a necessária para renderizá-los.
    -- O hífen ASCII é usado no controle de remoção porque existe em todas as
    -- fontes suportadas pelo KOReader e não sofre recorte em fontes e-ink.
    local control_font_size = 28
    local control_face = Font:getFace("tfont", control_font_size)
    local plus_probe = TextWidget:new{ text = "+", face = control_face, bold = true }
    local minus_probe = TextWidget:new{ text = "-", face = control_face, bold = true }
    local control_symbol_w = math.max(plus_probe:getSize().w, minus_probe:getSize().w)
    local control_symbol_h = math.max(plus_probe:getSize().h, minus_probe:getSize().h)
    plus_probe:free()
    minus_probe:free()

    local control_inner_pad = math.max(4, math.floor((Size.padding.default or 12) / 3))
    local control_box_pad = math.max(2, math.floor((Size.padding.default or 12) / 4))
    local control_button_w = math.max(44, control_symbol_w + control_inner_pad * 2)
    local control_button_h = math.max(42, control_symbol_h + control_inner_pad * 2)
    local control_outer_w = control_button_w + control_box_pad * 2 + 2
    local side_spacing = math.max(4, math.min(18, math.floor(iw * 0.025)))

    -- Reserva dois espaços laterais simétricos antes de dimensionar a carta.
    -- Isso mantém a carta centralizada e impede que o box invada ou seja
    -- comprimido em qualquer largura de tela normalmente aceita pelo KOReader.
    local max_card_w_with_controls = math.max(72, iw - 2 * (control_outer_w + side_spacing))
    if use_lenormand then
        card_w = math.min(250, max_card_w_with_controls)
        card_h = card_w
    else
        local desired_card_w = math.floor(screen_w * 0.25)
        card_w = math.min(desired_card_w, max_card_w_with_controls)
        card_h = math.floor(card_w * (439 / 250))
    end

    local function makeBackWidget(width, height)
        if has_back_image then
            return ImageWidget:new{
                file = back_path,
                width = width,
                height = height,
                scale_for_dpi = false,
            }
        end
        return FrameContainer:new{
            width = width,
            height = height,
            bordersize = 0,
            background = Blitbuffer.gray(0.8),
            CenterContainer:new{
                dimen = { w = width, h = height },
                TextWidget:new{
                    text = "?",
                    face = Font:getFace("tfont"),
                    bold = true,
                    alignment = "center",
                },
            },
        }
    end

    -- A carta central é o próprio controle de revelação. O contêiner não muda
    -- sua aparência, apenas adiciona uma área de toque sobre o verso.
    local main_back_widget = TappableImageContainer:new{
        content = makeBackWidget(card_w, card_h),
        callback = revealCards,
    }
    local image_widget = main_back_widget

    if self.allow_add_card then
        local side_slot = math.floor((iw - card_w) / 2)
        if side_slot < control_outer_w + side_spacing then
            side_slot = control_outer_w + side_spacing
        end
        local spacing = side_spacing
        local available_side = math.max(control_outer_w, side_slot - spacing)

        -- À esquerda permanece uma única miniatura quando há mais cartas. À
        -- direita, no espaço equivalente à miniatura futura do CardDialog,
        -- surge um único box com + e −.
        local left_widget
        local left_padding
        if #self.cards > 1 then
            local desired_mini_w = math.floor(card_w * 2 / 3)
            local mini_w = math.min(desired_mini_w, available_side)
            local mini_h = math.floor(card_h * mini_w / card_w)
            left_widget = makeBackWidget(mini_w, mini_h)
            left_padding = side_slot - mini_w - spacing
            if left_padding < 0 then left_padding = 0 end
        end

        -- O box tem dimensões mínimas derivadas da fonte, botões com altura
        -- explícita e divisor gráfico real. Nenhum elemento depende de uma
        -- sequência de caracteres que possa ser truncada ou virar reticências.
        local outer_control_w = math.min(available_side, control_outer_w)
        local inner_control_w = math.max(control_button_w, outer_control_w - control_box_pad * 2 - 2)

        local btn_add = Button:new{
            text = "+",
            width = inner_control_w,
            height = control_button_h,
            padding_h = 0,
            padding_v = 0,
            margin = 0,
            bordersize = 0,
            background = nil,
            radius = 0,
            enabled = #self.cards < self.max_cards,
            text_font_face = "tfont",
            text_font_size = control_font_size,
            text_font_bold = true,
            avoid_text_truncation = false,
            callback = addCard,
        }
        local btn_remove = Button:new{
            text = "-",
            width = inner_control_w,
            height = control_button_h,
            padding_h = 0,
            padding_v = 0,
            margin = 0,
            bordersize = 0,
            background = nil,
            radius = 0,
            enabled = #self.cards > 1,
            text_font_face = "tfont",
            text_font_size = control_font_size,
            text_font_bold = true,
            avoid_text_truncation = false,
            callback = removeCard,
        }

        local control_divider = FrameContainer:new{
            width = inner_control_w,
            height = math.max(1, Screen:scaleBySize(1)),
            bordersize = 0,
            padding = 0,
            margin = 0,
            background = Blitbuffer.gray(0.65),
            HorizontalSpan:new{ width = inner_control_w },
        }

        local control_box = FrameContainer:new{
            width = outer_control_w,
            background = Blitbuffer.COLOR_WHITE,
            bordersize = 1,
            radius = getTarotButtonRadius(),
            padding = control_box_pad,
            VerticalGroup:new{
                align = "center",
                btn_add,
                control_divider,
                btn_remove,
            },
        }

        local right_padding = side_slot - spacing - outer_control_w
        if right_padding < 0 then right_padding = 0 end
        local hgroup = HorizontalGroup:new{ align = "center" }

        if left_widget then
            table.insert(hgroup, HorizontalSpan:new{ width = left_padding })
            table.insert(hgroup, left_widget)
            table.insert(hgroup, HorizontalSpan:new{ width = spacing })
        else
            table.insert(hgroup, HorizontalSpan:new{ width = side_slot })
        end

        table.insert(hgroup, main_back_widget)
        table.insert(hgroup, HorizontalSpan:new{ width = spacing })
        table.insert(hgroup, control_box)
        table.insert(hgroup, HorizontalSpan:new{ width = right_padding })
        image_widget = hgroup
    end

    local count_w
    if self.allow_add_card then
        count_w = TextWidget:new{
            text = string.format(
                self.plugin:getTranslation("drawn_card_count"),
                #self.cards,
                self.max_cards
            ),
            face = Font:getFace("smallinfofont"),
            bold = true,
            max_width = iw,
            alignment = "center",
        }
    end

    local btn_exit = makeTransparentTextButton{
        text     = self.plugin:getTranslation("exit"),
        width    = math.floor(iw * 0.40),
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    }

    local content = VerticalGroup:new{
        align = "center",
        header_w,
    }

    if count_w then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, count_w)
    end

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(content, image_widget)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    -- Usa exatamente o mesmo divisor visual do cabeçalho antes de Sair.
    table.insert(content, makeTarotDivider(iw))
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, btn_exit)

    self[1] = makeFullscreenFrame(content, layout)

    -- A instrução de revelar a carta é um aviso descartável, não conteúdo fixo.
    UIManager:scheduleIn(0.1, function()
        self.plugin:showHiddenCardRevealHint()
    end)
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║          SEÇÃO 9: TELA INICIAL EM TELA CHEIA (TarotHomeDialog)              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local TarotHomeDialog = InputContainer:extend{
    plugin = nil,
}

function TarotHomeDialog:init()
    local sw  = Screen:getWidth()
    local sh  = Screen:getHeight()
    -- A Home precisa pintar a tela inteira em qualquer dispositivo suportado
    -- pelo KOReader. Por isso usamos diretamente as dimensões da tela como
    -- área externa e calculamos apenas uma área interna segura para o conteúdo.
    local outer_pad = Size.padding.default
    local inner_w = sw - outer_pad * 2
    if inner_w < math.floor(sw * 0.72) then
        inner_w = math.floor(sw * 0.72)
    end
    local iw = math.floor(inner_w * 0.92)
    local tile_gap = Size.span.horizontal_default
    local tile_button_w = math.floor((iw - tile_gap) / 2)

    local daily_data = self.plugin:getDailyCardData()
    local daily_card = daily_data.card
    local daily_is_lenormand = daily_data.is_lenormand == true
    local daily_cards = {{
        card = daily_card,
        is_reversed = daily_data.is_reversed,
    }}

    local home_title = daily_is_lenormand and "Lenormand" or "Tarot"
    local header_w = makeSectionHeader(home_title, iw)

    local daily_title_w = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("daily_card") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local card_w
    local card_h
    if daily_card.symbol then
        card_w = math.floor(sw * 0.24)
        if card_w > 170 then card_w = 170 end
        if card_w < 120 then card_w = 120 end
        card_h = card_w
    else
        card_w = math.floor(sw * 0.20)
        if card_w > 150 then card_w = 150 end
        if card_w < 95 then card_w = 95 end
        card_h = math.floor(card_w * (439 / 250))
    end

    -- Na Home, a Carta Diária mantém 2/3 do tamanho usado na versão anterior.
    -- Isso equivale a reduzir em 1/3 as dimensões atuais, preservando a proporção.
    card_w = math.floor(card_w * 4 / 3)
    card_h = math.floor(card_h * 4 / 3)

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
        daily_button = makeTransparentTextButton{
            text   = self.plugin:getTranslation("open_daily_card"),
            width  = math.floor(iw * 0.72),
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
                UIManager:setDirty(nil, "full")
            end,
        }
    else
        daily_button = makeRoundedButton{
            text   = self.plugin:getTranslation("reveal_daily_card"),
            width  = math.floor(iw * 0.72),
            callback = function()
                self.plugin:markDailyCardRevealed(daily_data)
                UIManager:close(self)
                UIManager:show(TarotHomeDialog:new{ plugin = self.plugin })
                UIManager:setDirty(nil, "full")
            end,
        }
    end

    local btn_spreads = makeRoundedButton{
        text   = self.plugin:getTranslation("spreads"),
        width  = tile_button_w,
        callback = function()
            self.plugin:showSpreadsMenu()
        end,
    }

    local btn_journal = makeRoundedButton{
        text   = self.plugin:getTranslation("journal"),
        width  = tile_button_w,
        callback = function()
            self.plugin:showSavedReadingsMenu()
        end,
    }

    local btn_book = makeRoundedButton{
        text   = self.plugin:getTranslation("card_book"),
        width  = iw,
        callback = function()
            self.plugin:showCardBook()
        end,
    }

    -- O acesso a "Sobre" já existe dentro de Configurações. Na Home, o
    -- rodapé usa esse espaço para o atalho de Configuração, enquanto o Livro
    -- de Cartas passa a ocupar sozinho toda a segunda linha.
    local btn_settings = makeTransparentTextButton{
        text        = self.plugin:getTranslation("configuration"),
        width       = math.floor(iw * 0.38),
        callback = function()
            self.plugin:showSettings(self)
        end,
    }

    local btn_close = makeTransparentTextButton{
        text        = self.plugin:getTranslation("close"),
        width       = math.floor(iw * 0.38),
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    }

    local actions_row_1 = HorizontalGroup:new{
        align = "center",
        btn_spreads,
        HorizontalSpan:new{ width = tile_gap },
        btn_journal,
    }

    local actions_row_2 = HorizontalGroup:new{
        align = "center",
        btn_book,
    }

    local footer_row = HorizontalGroup:new{
        align = "center",
        btn_settings,
        HorizontalSpan:new{ width = math.floor(iw * 0.08) },
        btn_close,
    }

    local separator = TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.55),
        max_width = iw,
        alignment = "center",
    }

    local content = VerticalGroup:new{
        align = "center",
        header_w,
        VerticalSpan:new{ width = Size.span.vertical_default },
        daily_title_w,
        VerticalSpan:new{ width = Size.span.vertical_small },
        daily_image,
        VerticalSpan:new{ width = Size.span.vertical_small },
        daily_name_w,
    }

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })

    table.insert(content, daily_button)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, separator)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, actions_row_1)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, actions_row_2)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(content, separator)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, footer_row)

    local centered_content = CenterContainer:new{
        dimen = {
            w = sw - outer_pad * 2,
            h = sh - outer_pad * 2,
        },
        content,
    }

    local fullscreen_frame = FrameContainer:new{
        width      = sw,
        height     = sh,
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        radius     = 0,
        padding    = outer_pad,
        margin     = 0,
        centered_content,
    }

    self[1] = fullscreen_frame
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║          SEÇÃO 10: DIÁLOGO DE CONFIGURAÇÕES (SettingsDialog)                 ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local SettingsDialog = InputContainer:extend{
    plugin = nil,
    page = 1,
    parent_dialog = nil,
}

function SettingsDialog:init()
    local layout = getFullscreenLayout()
    local iw = layout.content_w
    local page_count = 4
    self.page = tonumber(self.page) or 1
    if self.page < 1 then self.page = 1 end
    if self.page > page_count then self.page = page_count end

    local page_titles = {
        self.plugin:getTranslation("daily_card"),
        self.plugin:getTranslation("tarot_deck"),
        self.plugin:getTranslation("reading_display"),
        self.plugin:getTranslation("journal_system"),
    }
    local header_w = makeSectionHeader(
        self.plugin:getTranslation("settings"),
        iw,
        page_titles[self.page]
    )
    local card_w = math.floor(iw * 0.92)
    local card_inner_w = card_w - Size.padding.default * 2

    local function reopen(page)
        UIManager:close(self)
        UIManager:show(SettingsDialog:new{
            plugin = self.plugin,
            page = page or self.page,
            parent_dialog = self.parent_dialog,
        })
        UIManager:setDirty(nil, "full")
    end

    local rows = VerticalGroup:new{ align = "center" }

    if self.page == 1 then
        local function dailyDeckButton(mode, label_key)
            local mark = self.plugin.daily_card_deck_mode == mode and "☑" or "☐"
            return makeRoundedButton{
                text = "  " .. mark .. "  " .. self.plugin:getTranslation(label_key),
                width = card_inner_w,
                callback = function()
                    self.plugin:setDailyCardDeckMode(mode)
                    reopen(1)
                end,
            }
        end
        local daily_body = VerticalGroup:new{
            align = "center",
            dailyDeckButton("tarot", "daily_card_tarot_only"),
            VerticalSpan:new{ width = Size.span.vertical_small },
            dailyDeckButton("lenormand", "daily_card_lenormand_only"),
            VerticalSpan:new{ width = Size.span.vertical_small },
            dailyDeckButton("either", "daily_card_either"),
        }
        table.insert(rows, makeSettingsCard(
            self.plugin:getTranslation("daily_card_deck_mode"),
            daily_body,
            card_w
        ))

    elseif self.page == 2 then
        local rev_mark = self.plugin.allow_reversed and "☑" or "☐"
        local btn_rev = makeRoundedButton{
            text = "  " .. rev_mark .. "  " .. self.plugin:getTranslation("allow_reversed_desc"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleReversed()
                reopen(2)
            end,
        }
        local maj_mark = self.plugin.major_only and "☑" or "☐"
        local btn_maj = makeRoundedButton{
            text = "  " .. maj_mark .. "  " .. self.plugin:getTranslation("major_only_desc"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleMajorOnly()
                reopen(2)
            end,
        }
        local tarot_options_body = VerticalGroup:new{
            align = "center",
            btn_rev,
            VerticalSpan:new{ width = Size.span.vertical_default },
            btn_maj,
        }
        table.insert(rows, makeSettingsCard(
            self.plugin:getTranslation("tarot_deck"),
            tarot_options_body,
            card_w
        ))

    elseif self.page == 3 then
        local function modeButton(mode, label_key)
            local mark = self.plugin.spread_meaning_mode == mode and "☑" or "☐"
            return makeRoundedButton{
                text = "  " .. mark .. "  " .. self.plugin:getTranslation(label_key),
                width = card_inner_w,
                callback = function()
                    self.plugin:setSpreadMeaningMode(mode)
                    reopen(3)
                end,
            }
        end
        local meanings_body = VerticalGroup:new{
            align = "center",
            modeButton("full", "meaning_mode_full"),
            VerticalSpan:new{ width = Size.span.vertical_small },
            modeButton("summary", "meaning_mode_summary"),
            VerticalSpan:new{ width = Size.span.vertical_small },
            modeButton("hidden", "meaning_mode_hidden"),
        }
        table.insert(rows, makeSettingsCard(
            self.plugin:getTranslation("meaning_mode"),
            meanings_body,
            card_w
        ))
        table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

        local function sizeButton(size, label_key)
            local mark = self.plugin.meaning_text_size == size and "☑" or "☐"
            return makeRoundedButton{
                text = mark .. " " .. self.plugin:getTranslation(label_key),
                width = math.floor(card_inner_w * 0.31),
                callback = function()
                    self.plugin:setMeaningTextSize(size)
                    reopen(3)
                end,
            }
        end
        local size_body = HorizontalGroup:new{
            align = "center",
            sizeButton("compact", "text_size_compact"),
            HorizontalSpan:new{ width = math.floor(card_inner_w * 0.035) },
            sizeButton("standard", "text_size_standard"),
            HorizontalSpan:new{ width = math.floor(card_inner_w * 0.035) },
            sizeButton("large", "text_size_large"),
        }
        table.insert(rows, makeSettingsCard(
            self.plugin:getTranslation("meaning_text_size"),
            size_body,
            card_w
        ))
        table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

        local display_controls = VerticalGroup:new{ align = "center" }
        local reversed_mark = self.plugin.show_reversed_label and "☑" or "☐"
        table.insert(display_controls, makeRoundedButton{
            text = "  " .. reversed_mark .. "  " .. self.plugin:getTranslation("show_reversed_label"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleShowReversedLabel()
                reopen(3)
            end,
        })
        table.insert(display_controls, VerticalSpan:new{ width = Size.span.vertical_default })
        local book_mark = self.plugin.disable_view_in_book and "☑" or "☐"
        table.insert(display_controls, makeRoundedButton{
            text = "  " .. book_mark .. "  " .. self.plugin:getTranslation("disable_view_in_book"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleViewInBookButton()
                reopen(3)
            end,
        })
        table.insert(rows, makeSettingsCard(
            self.plugin:getTranslation("reading_display"),
            display_controls,
            card_w
        ))

    else
        local auto_mark = self.plugin.auto_save_spreads and "☑" or "☐"
        local btn_auto_save = makeRoundedButton{
            text = "  " .. auto_mark .. "  " .. self.plugin:getTranslation("auto_save_spreads"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleAutoSaveSpreads()
                reopen(4)
            end,
        }
        local warning_disabled_mark = self.plugin.disable_unsaved_close_warning and "☑" or "☐"
        local btn_unsaved_warning = makeRoundedButton{
            text = "  " .. warning_disabled_mark .. "  "
                .. self.plugin:getTranslation("disable_unsaved_close_warning"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleUnsavedCloseWarning()
                reopen(4)
            end,
        }
        local journal_body = VerticalGroup:new{
            align = "center",
            btn_auto_save,
            VerticalSpan:new{ width = Size.span.vertical_default },
            btn_unsaved_warning,
        }
        table.insert(rows, makeSettingsCard(
            self.plugin:getTranslation("journal"),
            journal_body,
            card_w
        ))
        table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

        local restore_label = "  ⚠  " .. self.plugin:getTranslation("restore_desc")
        local btn_restore = makeRoundedButton{
            text = restore_label,
            width = card_inner_w,
            callback = function()
                -- ConfirmBox usa TextBoxWidget internamente, quebrando linhas e
                -- reduzindo a fonte se necessário. Assim os dois avisos nunca
                -- ficam truncados, mesmo na tela do Kindle Basic.
                local first_confirm
                first_confirm = ConfirmBox:new{
                    text = self.plugin:getTranslation("restore_confirm_first"),
                    ok_text = self.plugin:getTranslation("yes"),
                    cancel_text = self.plugin:getTranslation("no"),
                    keep_dialog_open = true,
                    flush_events_on_show = true,
                    ok_callback = function()
                        UIManager:close(first_confirm)

                        local second_confirm
                        second_confirm = ConfirmBox:new{
                            text = self.plugin:getTranslation("restore_confirm_second"),
                            ok_text = self.plugin:getTranslation("yes"),
                            cancel_text = self.plugin:getTranslation("no"),
                            keep_dialog_open = true,
                            flush_events_on_show = true,
                            ok_callback = function()
                                UIManager:close(second_confirm)
                                local reset_ok = self.plugin:restoreAll()
                                UIManager:close(self)
                                -- Configurações é aberta sobre a Home. Fechar o
                                -- diálogo pai encerra o app do Tarot e devolve o
                                -- usuário ao KOReader após a restauração.
                                if self.parent_dialog then
                                    UIManager:close(self.parent_dialog)
                                end
                                UIManager:show(InfoMessage:new{
                                    text = self.plugin:getTranslation(
                                        reset_ok and "reset_success" or "reset_error"
                                    ),
                                })
                                self.plugin:refreshMenu()
                                UIManager:setDirty(nil, "full")
                            end,
                        }
                        UIManager:show(second_confirm)
                    end,
                }
                UIManager:show(first_confirm)
                UIManager:setDirty(nil, "full")
            end,
        }
        table.insert(rows, makeSettingsCard(
            self.plugin:getTranslation("reset_section"),
            btn_restore,
            card_w
        ))
        table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

        table.insert(rows, makeRoundedButton{
            text = self.plugin:getTranslation("about"),
            width = card_w,
            callback = function()
                UIManager:close(self)
                self.plugin:showAboutDialog()
            end,
        })
    end

    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(rows, makeTarotDivider(iw))
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

    local page_counter = TextWidget:new{
        text = string.format(self.plugin:getTranslation("settings_page"), self.page, page_count),
        face = Font:getFace("x_smallinfofont"),
        fgcolor = Blitbuffer.gray(0.5),
        max_width = math.floor(iw * 0.42),
        alignment = "center",
    }
    local nav_row = HorizontalGroup:new{
        align = "center",
        makeRoundedButton{
            text = "‹",
            width = math.floor(iw * 0.20),
            enabled = self.page > 1,
            callback = function() reopen(self.page - 1) end,
        },
        HorizontalSpan:new{ width = math.floor(iw * 0.05) },
        page_counter,
        HorizontalSpan:new{ width = math.floor(iw * 0.05) },
        makeRoundedButton{
            text = "›",
            width = math.floor(iw * 0.20),
            enabled = self.page < page_count,
            callback = function() reopen(self.page + 1) end,
        },
    }
    table.insert(rows, nav_row)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

    table.insert(rows, makeTransparentTextButton{
        text = self.plugin:getTranslation("close"),
        width = math.floor(iw * 0.40),
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    })

    local content = VerticalGroup:new{
        align = "center",
        header_w,
        VerticalSpan:new{ width = Size.span.vertical_large },
        rows,
    }
    self[1] = makeFullscreenFrame(content, layout)
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           SEÇÃO 10: DIÁLOGO DO LIVRO DE CARTAS (CardBookDialog)             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local CardBookDialog = InputContainer:extend{
    plugin = nil,
    card_list = nil,
    current_index = 1,
    parent_callback = nil,
}

function CardBookDialog:init()
    local layout = getFullscreenLayout()
    local iw  = layout.content_w

    local card = self.card_list[self.current_index]

    local name_text = T(card.name)
    local header_w = makeSectionHeader(
        self.plugin:getTranslation("card_book"),
        iw,
        name_text
    )

    -- 2. Imagem à esquerda, informações à direita
    local default_w, default_h = self.plugin:getDefaultCardSize(card)
    local img_w = math.floor(default_w * 2/3)
    local img_h = math.floor(default_h * 2/3)
    local img_widget = self.plugin:getCardImageWidget(card, img_w, img_h)

    -- Largura disponível para a coluna da direita
    local right_col_w = iw - img_w - Size.span.horizontal_default

    -- Coluna da direita (VerticalGroup)
    local right_col = VerticalGroup:new{ align = "left" }

    -- Função auxiliar para adicionar um rótulo (cinza, small) + valor (normal)
    local function addInfoField(label, value)
        -- Rótulo
        local label_w = TextWidget:new{
            text      = label .. ":",
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = right_col_w,
            alignment = "left",
        }
        table.insert(right_col, label_w)
        -- Valor
        local value_w = TextBoxWidget:new{
            text      = value,
            face      = Font:getFace("cfont"),
            width     = right_col_w,
            alignment = "left",
        }
        table.insert(right_col, value_w)
        table.insert(right_col, VerticalSpan:new{ width = Size.span.vertical_small })
    end

    -- Keywords
    if card.keywords then
        local kw = T(card.keywords)
        addInfoField(self.plugin:getTranslation("keywords_label"), kw)
    end
    -- Planet / Sign
    if card.planet then
        local planet = T(card.planet)
        addInfoField(self.plugin:getTranslation("planet_sign_label"), planet)
    end
    -- Timing
    if card.timing then
        local timing = T(card.timing)
        addInfoField(self.plugin:getTranslation("timing_label"), timing)
    end

    -- Pequeno divisor se houver informações
    if card.keywords or card.planet or card.timing then
        local info_divider = TextWidget:new{
            text      = "─ ─ ─ ─ ─ ─ ─ ─",
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = right_col_w,
            alignment = "left",
        }
        table.insert(right_col, info_divider)
        table.insert(right_col, VerticalSpan:new{ width = Size.span.vertical_small })
    end

    -- Layout lado a lado: imagem (esquerda) + coluna de informações (direita)
    local image_info_row = HorizontalGroup:new{
        align = "top",
        img_widget,
        HorizontalSpan:new{ width = Size.span.horizontal_default },
        right_col,
    }

    -- Significado normal (Upright) – ALINHADO À ESQUERDA COMO O REVERSO
    local upright_label = self.plugin:getTranslation("upright") .. ":"
    local upright_label_w = TextWidget:new{
        text      = upright_label,
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "left",
    }
    local meaning_text = T(card.meaning)
    local meaning_w = TextBoxWidget:new{
        text      = meaning_text,
        face      = Font:getFace("cfont"),
        width     = iw,
        alignment = "left",
    }
    local upright_section = VerticalGroup:new{
        align = "left",
        upright_label_w,
        VerticalSpan:new{ width = Size.span.vertical_small },
        meaning_w,
    }

    -- Significado invertido (apenas se não for Lenormand e existir)
    local reversed_section
    if not self.plugin.use_lenormand and card.reversed_meaning then
        local reversed_label = self.plugin:getTranslation("reversed") .. ":"
        local reversed_label_w = TextWidget:new{
            text      = reversed_label,
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = iw,
            alignment = "left",
        }
        local reversed_meaning_text = T(card.reversed_meaning)
        local reversed_meaning_w = TextBoxWidget:new{
            text      = reversed_meaning_text,
            face      = Font:getFace("cfont"),
            width     = iw,
            alignment = "left",
        }
        reversed_section = VerticalGroup:new{
            align = "left",
            reversed_label_w,
            VerticalSpan:new{ width = Size.span.vertical_small },
            reversed_meaning_w,
        }
    end

    -- Divisor padrão
    local divider = TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "center",
    }

    -- Navegação entre cartas
    local nav_row
    if #self.card_list > 1 then
        local btn_prev = Button:new{
            text     = self.plugin:getTranslation("prev"),
            width    = math.floor(iw * 0.30),
            radius   = getTarotButtonRadius(),
            enabled  = self.current_index > 1,
            callback = function()
                if self.current_index > 1 then
                    UIManager:close(self)
                    UIManager:show(CardBookDialog:new{
                        plugin = self.plugin,
                        card_list = self.card_list,
                        current_index = self.current_index - 1,
                        parent_callback = self.parent_callback,
                    })
                    UIManager:setDirty(nil, "full")
                end
            end,
        }
        
        local counter_w = TextWidget:new{
            text      = string.format(self.plugin:getTranslation("card_count"), self.current_index, #self.card_list),
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = math.floor(iw * 0.36),
            alignment = "center",
        }
        
        local btn_next = Button:new{
            text     = self.plugin:getTranslation("next"),
            width    = math.floor(iw * 0.30),
            radius   = getTarotButtonRadius(),
            enabled  = self.current_index < #self.card_list,
            callback = function()
                if self.current_index < #self.card_list then
                    UIManager:close(self)
                    UIManager:show(CardBookDialog:new{
                        plugin = self.plugin,
                        card_list = self.card_list,
                        current_index = self.current_index + 1,
                        parent_callback = self.parent_callback,
                    })
                    UIManager:setDirty(nil, "full")
                end
            end,
        }
        
        nav_row = HorizontalGroup:new{
            align = "center",
            btn_prev,
            HorizontalSpan:new{ width = math.floor(iw * 0.02) },
            counter_w,
            HorizontalSpan:new{ width = math.floor(iw * 0.02) },
            btn_next,
        }
    end

    -- Botão Voltar
    local btn_back = makeTransparentTextButton{
        text     = self.plugin:getTranslation("back"),
        width    = math.floor(iw * 0.40),
        callback = function()
            UIManager:close(self)
            if self.parent_callback then
                self.parent_callback()
            end
            UIManager:setDirty(nil, "full")
        end,
    }

    -- Montagem final do conteúdo
    local content = VerticalGroup:new{
        align = "center",
        header_w,
        VerticalSpan:new{ width = Size.span.vertical_large },
        image_info_row,
        VerticalSpan:new{ width = Size.span.vertical_large },
        upright_section,   -- ← agora alinhado à esquerda dentro do grupo
    }

    if reversed_section then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, divider)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, reversed_section)
    end

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(content, divider)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    if nav_row then
        table.insert(content, nav_row)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    end

    table.insert(content, btn_back)

    self[1] = makeFullscreenFrame(content, layout)
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║      SEÇÃO 11: MENU DO LIVRO DE CARTAS (CardBookMenu)                        ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- Normaliza a pesquisa sem exigir bibliotecas Unicode externas. A tabela cobre
-- os acentos usados nas traduções em português; os demais alfabetos, inclusive
-- chinês, continuam sendo comparados diretamente em UTF-8.
local function normalizeCardSearchText(text)
    if type(text) ~= "string" then return "" end

    text = text:lower()
    local accents = {
        ["á"] = "a", ["à"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a",
        ["Á"] = "a", ["À"] = "a", ["Â"] = "a", ["Ã"] = "a", ["Ä"] = "a",
        ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
        ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
        ["í"] = "i", ["ì"] = "i", ["î"] = "i", ["ï"] = "i",
        ["Í"] = "i", ["Ì"] = "i", ["Î"] = "i", ["Ï"] = "i",
        ["ó"] = "o", ["ò"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o",
        ["Ó"] = "o", ["Ò"] = "o", ["Ô"] = "o", ["Õ"] = "o", ["Ö"] = "o",
        ["ú"] = "u", ["ù"] = "u", ["û"] = "u", ["ü"] = "u",
        ["Ú"] = "u", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u",
        ["ç"] = "c", ["Ç"] = "c",
    }

    for accented, plain in pairs(accents) do
        text = text:gsub(accented, plain)
    end

    return text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Reúne somente dados úteis para a pesquisa: nome, palavras-chave, número,
-- naipe e figura. Os significados longos não entram para evitar resultados
-- excessivamente amplos.
local function getCardSearchText(card)
    local values = {}
    local function addValue(value)
        if value and value ~= "" then
            table.insert(values, value)
        end
    end

    addValue(card.name)
    addValue(T(card.name))
    addValue(card.keywords)
    if card.keywords then addValue(T(card.keywords)) end
    addValue(card.roman)
    if card.number then addValue(tostring(card.number)) end
    if card.rank then
        addValue(card.rank.name)
        addValue(T(card.rank.name))
    end
    if card.suit then
        addValue(card.suit.name)
        addValue(T(card.suit.name))
    end

    return normalizeCardSearchText(table.concat(values, " "))
end

local CardBookMenu = InputContainer:extend{
    plugin = nil,
    -- Estado exclusivo do Livro de Cartas. Ele é inicializado a partir da
    -- configuração do usuário, mas nunca altera o baralho usado nas tiragens.
    book_use_lenormand = nil,
}

-- Retorna o baralho atualmente selecionado apenas dentro do Livro de Cartas.
function CardBookMenu:getSelectedBookDeck()
    return self.book_use_lenormand and LENORMAND_DECK or FULL_DECK
end

-- Retorna o título contextual da busca conforme a aba ativa.
function CardBookMenu:getBookSearchTitle()
    local key = self.book_use_lenormand and "search_lenormand" or "search_tarot"
    return self.plugin:getTranslation(key)
end

-- Formata as quantidades sem duplicar textos específicos para cada conjunto.
function CardBookMenu:formatCardCount(count)
    return string.format(self.plugin:getTranslation("cards_count"), count)
end

-- Cria a legenda pequena exibida abaixo dos botões de categorias.
function CardBookMenu:makeCardCountLabel(count, width)
    return TextWidget:new{
        text      = self:formatCardCount(count),
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.35),
        max_width = width,
        alignment = "center",
    }
end

-- Reabre o Livro na aba solicitada. O refresh completo é deliberado para
-- dispositivos e-ink e evita resíduos visuais entre layouts diferentes.
function CardBookMenu:openBookDeck(use_lenormand)
    if self.book_use_lenormand == use_lenormand then
        return
    end

    UIManager:close(self)
    UIManager:show(CardBookMenu:new{
        plugin = self.plugin,
        book_use_lenormand = use_lenormand,
    })
    UIManager:setDirty(nil, "full")
end

function CardBookMenu:init()
    local layout = getFullscreenLayout()
    local iw = layout.content_w

    -- Na primeira abertura, acompanha a escolha geral do usuário. Depois disso,
    -- a navegação permanece local ao Livro de Cartas.
    if self.book_use_lenormand == nil then
        self.book_use_lenormand = self.plugin.use_lenormand == true
    end

    local header_w = makeSectionHeader(self.plugin:getTranslation("card_book"), iw)
    local column_gap = Size.span.horizontal_default
    local column_w = math.floor((iw - column_gap) / 2)

    -- Seletor contextual Tarot | Lenormand. Os círculos mantêm a seleção clara
    -- mesmo em telas monocromáticas, sem depender de cores ou animações.
    local btn_tarot_tab = Button:new{
        text = (self.book_use_lenormand and "○ Tarot" or "● Tarot"),
        width = column_w,
        radius = getTarotButtonRadius(),
        callback = function()
            self:openBookDeck(false)
        end,
    }

    local btn_lenormand_tab = Button:new{
        text = (self.book_use_lenormand and "● Lenormand" or "○ Lenormand"),
        width = column_w,
        radius = getTarotButtonRadius(),
        callback = function()
            self:openBookDeck(true)
        end,
    }

    local deck_selector = HorizontalGroup:new{
        align = "center",
        btn_tarot_tab,
        HorizontalSpan:new{ width = column_gap },
        btn_lenormand_tab,
    }

    -- A busca usa diretamente o baralho da aba ativa, eliminando a antiga tela
    -- intermediária de escolha de baralho.
    local btn_search = makeTransparentTextButton{
        text = self:getBookSearchTitle(),
        width = math.floor(iw * 0.70),
        callback = function()
            self:showSearchInput(self:getSelectedBookDeck())
        end,
    }

    local deck_content = VerticalGroup:new{ align = "center" }

    if self.book_use_lenormand then
        -- Lenormand possui uma única coleção completa de 36 cartas.
        local btn_all_lenormand = Button:new{
            text = self.plugin:getTranslation("all_cards"),
            width = iw,
            radius = getTarotButtonRadius(),
            callback = function()
                UIManager:close(self)
                self:showCardList(LENORMAND_DECK)
            end,
        }

        table.insert(deck_content, btn_all_lenormand)
        table.insert(deck_content, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(deck_content, self:makeCardCountLabel(36, iw))
    else
        -- Tarot usa no máximo duas colunas para evitar textos comprimidos em
        -- Kindles e celulares estreitos.
        local btn_all_tarot = Button:new{
            text = self.plugin:getTranslation("all_cards"),
            width = column_w,
            radius = getTarotButtonRadius(),
            callback = function()
                UIManager:close(self)
                self:showCardList(FULL_DECK)
            end,
        }

        local btn_major = Button:new{
            text = self.plugin:getTranslation("major_arcana"),
            width = column_w,
            radius = getTarotButtonRadius(),
            callback = function()
                UIManager:close(self)
                self:showCardList(MAJOR_ARCANA)
            end,
        }

        local all_tarot_group = VerticalGroup:new{
            align = "center",
            btn_all_tarot,
            VerticalSpan:new{ width = Size.span.vertical_small },
            self:makeCardCountLabel(78, column_w),
        }

        local major_group = VerticalGroup:new{
            align = "center",
            btn_major,
            VerticalSpan:new{ width = Size.span.vertical_small },
            self:makeCardCountLabel(22, column_w),
        }

        local tarot_categories_row = HorizontalGroup:new{
            align = "center",
            all_tarot_group,
            HorizontalSpan:new{ width = column_gap },
            major_group,
        }

        local btn_minor = Button:new{
            text = self.plugin:getTranslation("minor_arcana"),
            width = iw,
            radius = getTarotButtonRadius(),
            callback = function()
                UIManager:close(self)
                self:showMinorArcanaMenu()
            end,
        }

        table.insert(deck_content, tarot_categories_row)
        table.insert(deck_content, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(deck_content, btn_minor)
        table.insert(deck_content, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(deck_content, self:makeCardCountLabel(56, iw))
    end

    local btn_close = makeTransparentTextButton{
        text = self.plugin:getTranslation("close"),
        width = math.floor(iw * 0.40),
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    }

    local content = VerticalGroup:new{
        align = "center",
        header_w,
        VerticalSpan:new{ width = Size.span.vertical_large },
        deck_selector,
        VerticalSpan:new{ width = Size.span.vertical_large },
        btn_search,
        VerticalSpan:new{ width = Size.span.vertical_large },
        deck_content,
        VerticalSpan:new{ width = Size.span.vertical_large },
        makeTarotDivider(iw),
        VerticalSpan:new{ width = Size.span.vertical_default },
        btn_close,
    }

    self[1] = makeFullscreenFrame(content, layout)
end

function CardBookMenu:showSearchInput(deck)
    local search_input
    search_input = InputDialog:new{
        title = self:getBookSearchTitle(),
        input_hint = self.plugin:getTranslation("search_hint"),
        input_type = "string",
        buttons = {
            {
                {
                    text = self.plugin:getTranslation("search_card"),
                    is_enter_default = true,
                    callback = function()
                        local query = normalizeCardSearchText(
                            search_input:getInputText()
                        )

                        if query == "" then
                            UIManager:show(InfoMessage:new{
                                text = self.plugin:getTranslation("search_empty"),
                            })
                            return
                        end

                        local results = {}
                        for _, card in ipairs(deck) do
                            if getCardSearchText(card):find(query, 1, true) then
                                table.insert(results, card)
                            end
                        end

                        UIManager:close(search_input)
                        if #results == 0 then
                            self:showNoSearchResults()
                            return
                        end

                        UIManager:close(self)
                        self:showCardList(results)
                    end,
                },
            },
            {
                {
                    text = self.plugin:getTranslation("cancel"),
                    callback = function()
                        UIManager:close(search_input)
                    end,
                },
            },
        },
    }

    UIManager:show(search_input)
    UIManager:setDirty(nil, "full")
end

function CardBookMenu:showNoSearchResults()
    local layout = getFullscreenLayout()
    local iw = layout.content_w

    local btn_back = makeTransparentTextButton{
        text = self.plugin:getTranslation("back"),
        width = math.floor(iw * 0.40),
        callback = function()
            UIManager:close(self.no_results_dialog)
            UIManager:setDirty(nil, "full")
        end,
    }

    local content = VerticalGroup:new{
        align = "center",
        makeSectionHeader(self:getBookSearchTitle(), iw),
        VerticalSpan:new{ width = Size.span.vertical_large },
        TextWidget:new{
            text = self.plugin:getTranslation("no_results"),
            face = Font:getFace("cfont"),
            bold = true,
            max_width = iw,
            alignment = "center",
        },
        VerticalSpan:new{ width = Size.span.vertical_large },
        makeTarotDivider(iw),
        VerticalSpan:new{ width = Size.span.vertical_default },
        btn_back,
    }

    self.no_results_dialog = makeFullscreenFrame(content, layout)
    UIManager:show(self.no_results_dialog)
    UIManager:setDirty(nil, "full")
end

function CardBookMenu:showMinorArcanaMenu()
    local layout = getFullscreenLayout()
    local iw = layout.content_w
    local column_gap = Size.span.horizontal_default
    local column_w = math.floor((iw - column_gap) / 2)

    local suit_keys = {
        { name = self.plugin:getTranslation("suit_wands"), symbol = "♣", start = 22, end_ = 35 },
        { name = self.plugin:getTranslation("suit_cups"), symbol = "♥", start = 36, end_ = 49 },
        { name = self.plugin:getTranslation("suit_swords"), symbol = "♠", start = 50, end_ = 63 },
        { name = self.plugin:getTranslation("suit_pentacles"), symbol = "♦", start = 64, end_ = 77 },
    }

    local plugin = self.plugin

    local MinorArcanaMenu = InputContainer:extend{
        plugin = plugin,
    }

    function MinorArcanaMenu:formatCardCount(count)
        return string.format(self.plugin:getTranslation("cards_count"), count)
    end

    function MinorArcanaMenu:makeCountLabel(count, width)
        return TextWidget:new{
            text = self:formatCardCount(count),
            face = Font:getFace("x_smallinfofont"),
            fgcolor = Blitbuffer.gray(0.35),
            max_width = width,
            alignment = "center",
        }
    end

    function MinorArcanaMenu:showCardList(cards)
        UIManager:show(CardBookDialog:new{
            plugin = self.plugin,
            card_list = cards,
            current_index = 1,
            parent_callback = function()
                UIManager:show(CardBookMenu:new{
                    plugin = self.plugin,
                    book_use_lenormand = false,
                })
            end,
        })
        UIManager:setDirty(nil, "full")
    end

    function MinorArcanaMenu:getSuitCards(suit)
        local cards = {}
        for _, card in ipairs(MINOR_ARCANA) do
            if card.id >= suit.start and card.id <= suit.end_ then
                table.insert(cards, card)
            end
        end
        return cards
    end

    function MinorArcanaMenu:makeSuitGroup(suit)
        local btn_suit = Button:new{
            text = suit.symbol .. " " .. suit.name,
            width = column_w,
            radius = getTarotButtonRadius(),
            callback = function()
                local cards = self:getSuitCards(suit)
                UIManager:close(self)
                self:showCardList(cards)
            end,
        }

        return VerticalGroup:new{
            align = "center",
            btn_suit,
            VerticalSpan:new{ width = Size.span.vertical_small },
            self:makeCountLabel(14, column_w),
        }
    end

    function MinorArcanaMenu:init()
        local btn_all_minor = Button:new{
            text = self.plugin:getTranslation("all_cards"),
            width = iw,
            radius = getTarotButtonRadius(),
            callback = function()
                UIManager:close(self)
                self:showCardList(MINOR_ARCANA)
            end,
        }

        local row1 = HorizontalGroup:new{
            align = "center",
            self:makeSuitGroup(suit_keys[1]),
            HorizontalSpan:new{ width = column_gap },
            self:makeSuitGroup(suit_keys[2]),
        }

        local row2 = HorizontalGroup:new{
            align = "center",
            self:makeSuitGroup(suit_keys[3]),
            HorizontalSpan:new{ width = column_gap },
            self:makeSuitGroup(suit_keys[4]),
        }

        local btn_back = makeTransparentTextButton{
            text = self.plugin:getTranslation("back"),
            width = math.floor(iw * 0.40),
            callback = function()
                UIManager:close(self)
                UIManager:show(CardBookMenu:new{
                    plugin = self.plugin,
                    book_use_lenormand = false,
                })
                UIManager:setDirty(nil, "full")
            end,
        }

        local content = VerticalGroup:new{
            align = "center",
            makeSectionHeader(self.plugin:getTranslation("minor_arcana"), iw),
            VerticalSpan:new{ width = Size.span.vertical_small },
            self:makeCountLabel(56, iw),
            VerticalSpan:new{ width = Size.span.vertical_large },
            btn_all_minor,
            VerticalSpan:new{ width = Size.span.vertical_small },
            self:makeCountLabel(56, iw),
            VerticalSpan:new{ width = Size.span.vertical_large },
            row1,
            VerticalSpan:new{ width = Size.span.vertical_large },
            row2,
            VerticalSpan:new{ width = Size.span.vertical_large },
            makeTarotDivider(iw),
            VerticalSpan:new{ width = Size.span.vertical_default },
            btn_back,
        }

        self[1] = makeFullscreenFrame(content, layout)
    end

    UIManager:show(MinorArcanaMenu:new{
        plugin = self.plugin,
    })
    UIManager:setDirty(nil, "full")
end

function CardBookMenu:showCardList(cards)
    local book_use_lenormand = self.book_use_lenormand

    UIManager:show(CardBookDialog:new{
        plugin = self.plugin,
        card_list = cards,
        current_index = 1,
        parent_callback = function()
            UIManager:show(CardBookMenu:new{
                plugin = self.plugin,
                book_use_lenormand = book_use_lenormand,
            })
        end,
    })
    UIManager:setDirty(nil, "full")
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                  SEÇÃO 12: MENU E ORQUESTRAÇÃO                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
function TarotPlugin:addToMainMenu(menu_items)
    menu_items.tarot = {
        text         = self:getTranslation("title"),
        sorting_hint = "tools",
        callback = function()
            self:showHome()
        end,
    }
end

function TarotPlugin:showHome()
    UIManager:show(TarotHomeDialog:new{ plugin = self })
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showPhysicalDeckSelector()
    -- O seletor usa o baralho escolhido diretamente no menu Tiragens:
    -- Lenormand, Tarot completo ou somente Arcanos Maiores.
    local deck_is_lenormand = self.use_lenormand == true
    local deck = self:getActiveDeck()

    UIManager:show(PhysicalDeckDialog:new{
        plugin = self,
        deck = deck,
        deck_is_lenormand = deck_is_lenormand,
        selected_indices = {},
        reversed_indices = {},
        page = 1,
    })

    -- No Tarot, a dica inclui a opção explícita de não ser mostrada novamente.
    -- Fechá-la sem marcar mantém a orientação disponível na próxima sessão.
    if not deck_is_lenormand then
        self:showPhysicalDeckReverseHint()
    end

    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showSpreadsMenu()
    -- Menu próprio em tela cheia para manter o seletor de baralho visualmente
    -- agrupado, no mesmo padrão dos cartões usados em Configurações.
    local SpreadsDialog = InputContainer:extend{
        plugin = nil,
    }

    function SpreadsDialog:init()
        local layout = getFullscreenLayout()
        local iw = layout.content_w
        local card_w = math.floor(iw * 0.92)
        local card_inner_w = card_w - Size.padding.default * 2
        local selector_gap = Size.span.horizontal_default
        local selector_w = math.floor((card_inner_w - selector_gap) / 2)

        local function reopen()
            UIManager:close(self)
            self.plugin:showSpreadsMenu()
            UIManager:setDirty(nil, "full")
        end

        -- Bolinhas preenchida/vazia deixam o estado claro em telas monocromáticas
        -- e repetem exatamente a linguagem visual do Livro de Cartas.
        local btn_tarot = makeRoundedButton{
            text = (self.plugin.use_lenormand and "○ " or "● ")
                .. self.plugin:getTranslation("tarot_deck"),
            width = selector_w,
            callback = function()
                self.plugin:setReadingDeck(false)
                reopen()
            end,
        }

        local btn_lenormand = makeRoundedButton{
            text = (self.plugin.use_lenormand and "● " or "○ ")
                .. self.plugin:getTranslation("lenormand_deck"),
            width = selector_w,
            callback = function()
                self.plugin:setReadingDeck(true)
                reopen()
            end,
        }

        local deck_selector = HorizontalGroup:new{
            align = "center",
            btn_tarot,
            HorizontalSpan:new{ width = selector_gap },
            btn_lenormand,
        }

        local deck_box = makeSettingsCard(
            self.plugin:getTranslation("deck_type"),
            deck_selector,
            card_w
        )

        local action_gap = Size.span.horizontal_default
        local action_w = math.floor((iw - action_gap) / 2)
        local actions_row = HorizontalGroup:new{
            align = "center",
            makeRoundedButton{
                text = self.plugin:getTranslation("draw_cards"),
                width = action_w,
                callback = function()
                    UIManager:close(self)
                    self.plugin:showDrawCards()
                end,
            },
            HorizontalSpan:new{ width = action_gap },
            makeRoundedButton{
                text = self.plugin:getTranslation("physical_deck"),
                width = action_w,
                callback = function()
                    UIManager:close(self)
                    self.plugin:showPhysicalDeckSelector()
                end,
            },
        }

        local btn_close = makeTransparentTextButton{
            text = self.plugin:getTranslation("close"),
            width = math.floor(iw * 0.40),
            is_enter_default = true,
            callback = function()
                UIManager:close(self)
                UIManager:setDirty(nil, "full")
            end,
        }

        local content = VerticalGroup:new{
            align = "center",
            makeSectionHeader(self.plugin:getTranslation("spreads"), iw),
            VerticalSpan:new{ width = Size.span.vertical_large },
            deck_box,
            -- Espaço extra entre o seletor de baralho e as ações principais.
            -- A soma usa medidas nativas do KOReader e continua adaptativa ao DPI.
            VerticalSpan:new{
                width = Size.span.vertical_large + Size.span.vertical_default,
            },
            actions_row,
            VerticalSpan:new{ width = Size.span.vertical_large },
            makeTarotDivider(iw),
            VerticalSpan:new{ width = Size.span.vertical_default },
            btn_close,
        }

        self[1] = makeFullscreenFrame(content, layout)
    end

    UIManager:show(SpreadsDialog:new{ plugin = self })
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showSettings(parent_dialog)
    UIManager:show(SettingsDialog:new{
        plugin = self,
        parent_dialog = parent_dialog,
    })
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showAboutDialog()
    local layout = getFullscreenLayout()
    local iw  = layout.content_w

    local text = self:getTranslation("about_text")
    local textbox = TextBoxWidget:new{
        text      = text,
        face      = Font:getFace("cfont"),
        width     = iw,
        alignment = "left",
    }

    local btn_close = makeTransparentTextButton{
        text     = self:getTranslation("close"),
        width    = math.floor(iw * 0.40),
        callback = function()
            UIManager:close(self.about_dialog)
            UIManager:setDirty(nil, "full")
        end,
    }

    local content = VerticalGroup:new{
        align = "center",
        makeSectionHeader(self:getTranslation("about"), iw),
        VerticalSpan:new{ width = Size.span.vertical_large },
        textbox,
        VerticalSpan:new{ width = Size.span.vertical_large },
        makeTarotDivider(iw),
        VerticalSpan:new{ width = Size.span.vertical_default },
        btn_close,
    }

    self.about_dialog = makeFullscreenFrame(content, layout)

    UIManager:show(self.about_dialog)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showCardBook()
    UIManager:show(CardBookMenu:new{ plugin = self })
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showCardInBook(card, deck_is_lenormand)
    if deck_is_lenormand == nil then
        deck_is_lenormand = card and card.symbol ~= nil
    end
    local deck = deck_is_lenormand and LENORMAND_DECK or FULL_DECK
    local index = 1
    for i, c in ipairs(deck) do
        if c.id == card.id then
            index = i
            break
        end
    end
    UIManager:show(CardBookDialog:new{
        plugin = self,
        card_list = deck,
        current_index = index,
        parent_callback = function()
            UIManager:setDirty(nil, "full")
        end,
    })
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showDrawCards()
    local deck_is_lenormand = self.use_lenormand == true
    local cards = self:drawUniqueCards(1)

    local on_new_func = function()
        self:showDrawCards()
    end

    -- Abre imediatamente a Carta Oculta. O sorteio é local e rápido, portanto
    -- não há necessidade de exibir uma mensagem intermediária de carregamento.
    UIManager:show(HiddenCardDialog:new{
        plugin = self,
        cards = cards,
        on_new = on_new_func,
        is_daily = false,
        title_label = self:getTranslation("draw_cards"),
        allow_add_card = true,
        max_cards = 10,
        deck_is_lenormand = deck_is_lenormand,
        on_reveal = function()
            UIManager:show(CardDialog:new{
                cards = cards,
                current_index = 1,
                -- Com mais de uma carta, o CardDialog mantém sua revelação
                -- sequencial já conhecida; com uma carta, abre normalmente.
                revealed_count = #cards > 1 and 1 or nil,
                plugin = self,
                title_label = self:getTranslation("draw_cards"),
                on_new = on_new_func,
                is_daily = false,
                deck_is_lenormand = deck_is_lenormand,
            })
            UIManager:setDirty(nil, "full")
        end,
    })
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:getCurrentDateStr()
    return os.date("%Y%m%d")
end

function TarotPlugin:getCardById(id, is_lenormand)
    if is_lenormand then
        for _, c in ipairs(LENORMAND_DECK) do
            if c.id == id then return c end
        end
    else
        for _, c in ipairs(FULL_DECK) do
            if c.id == id then return c end
        end
    end
    local deck = self:getActiveDeck()
    return deck[1]
end

function TarotPlugin:getDailyCardData()
    -- A Carta Diária usa uma preferência própria e não muda o baralho das
    -- tiragens. No modo padrão, Tarot ou Lenormand é escolhido uma vez por dia.
    local today = self:getCurrentDateStr()
    local use_lenormand = self:getDailyCardDeckChoice(today)
    local prefix = use_lenormand and "lenormand_daily_" or "tarot_daily_"
    local date_key = prefix .. "date"
    local card_id_key = prefix .. "card_id"
    local is_reversed_key = prefix .. "is_reversed"
    local revealed_key = prefix .. "revealed_date"

    local stored_date = G_reader_settings:readSetting(date_key) or ""
    local deck
    if use_lenormand then
        deck = LENORMAND_DECK
    elseif self.major_only then
        deck = MAJOR_ARCANA
    else
        deck = FULL_DECK
    end

    local card
    local is_new_draw = stored_date ~= today
    if not is_new_draw then
        local card_id = G_reader_settings:readSetting(card_id_key)
        for _, candidate in ipairs(deck) do
            if candidate.id == card_id then
                card = candidate
                break
            end
        end
        if not card then is_new_draw = true end
    end

    if is_new_draw then
        card = deck[math.random(1, #deck)]
        G_reader_settings:saveSetting(date_key, today)
        G_reader_settings:saveSetting(card_id_key, card.id)
        G_reader_settings:saveSetting(revealed_key, "")
    end

    local is_reversed = false
    if not use_lenormand and self.allow_reversed then
        if is_new_draw then
            is_reversed = math.random(2) == 1
            G_reader_settings:saveSetting(is_reversed_key, is_reversed)
        else
            is_reversed = G_reader_settings:readSetting(is_reversed_key) or false
        end
    elseif is_new_draw then
        G_reader_settings:saveSetting(is_reversed_key, false)
    end

    local revealed_date = G_reader_settings:readSetting(revealed_key) or ""
    return {
        card = card,
        is_reversed = is_reversed,
        is_lenormand = use_lenormand,
        today = today,
        revealed_key = revealed_key,
        is_revealed = revealed_date == today,
    }
end

function TarotPlugin:markDailyCardRevealed(daily_data)
    -- Marca a Carta Diária como revelada para que a Home passe a mostrar a
    -- carta aberta até a troca de data.
    if daily_data and daily_data.revealed_key and daily_data.today then
        G_reader_settings:saveSetting(daily_data.revealed_key, daily_data.today)
    end
end

function TarotPlugin:showDailyCard()
    local loading = InfoMessage:new{ text = self:getTranslation("loading") }
    UIManager:show(loading)
    UIManager:setDirty(nil, "full")
    
    UIManager:scheduleIn(0.3, function()
        local daily_data = self:getDailyCardData()
        UIManager:close(loading)
        
        local cards = {{
            card = daily_data.card,
            is_reversed = daily_data.is_reversed,
        }}
        local on_new_func = function() self:showDailyCard() end
        
        if self.hidden_card and not daily_data.is_revealed then
            local hidden_dlg = HiddenCardDialog:new{
                plugin = self,
                cards = cards,
                on_new = on_new_func,
                is_daily = true,
                deck_is_lenormand = daily_data.is_lenormand,
                on_reveal = function()
                    self:markDailyCardRevealed(daily_data)
                    UIManager:show(CardDialog:new{
                        cards = cards,
                        current_index = 1,
                        plugin = self,
                        title_label = self:getTranslation("daily_card"),
                        on_new = on_new_func,
                        is_daily = true,
                        deck_is_lenormand = daily_data.is_lenormand,
                    })
                    UIManager:setDirty(nil, "full")
                end,
            }
            UIManager:show(hidden_dlg)
        else
            local dlg = CardDialog:new{
                cards = cards,
                current_index = 1,
                plugin = self,
                title_label = self:getTranslation("daily_card"),
                on_new = on_new_func,
                is_daily = true,
                deck_is_lenormand = daily_data.is_lenormand,
            }
            UIManager:show(dlg)
        end
        UIManager:setDirty(nil, "full")
    end)
end

return TarotPlugin

-- ── dependências ──────────────────────────────────────────────────────────────
local InputContainer = require("ui/widget/container/inputcontainer")

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 1: INTERNACIONALIZAÇÃO (gettext)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- O inglês é o idioma-fonte. Todas as traduções ficam fora deste arquivo,
-- em l10n/<idioma>/koreader.po. O carregamento pelo caminho absoluto evita
-- diferenças no package.path entre o aplicativo de computador e o Kindle.

local function getCurrentPluginDirectory()
    local source = debug.getinfo(1, "S").source or ""
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end

    local plugin_dir = source:match("^(.*[/\\])[^/\\]+$")
    assert(plugin_dir, "tarot.koplugin: não foi possível localizar a pasta do plugin")
    return plugin_dir
end

local PLUGIN_DIR = getCurrentPluginDirectory()

-- Carrega arquivos próprios pelo caminho absoluto do plugin.
-- Isso evita falhas no Kindle, onde package.path pode não incluir
-- arquivos do plugin instalados manualmente.
local function loadPluginLuaFile(relative_path)
    local path = PLUGIN_DIR .. relative_path
    local loader, load_error = loadfile(path)
    assert(loader, "tarot.koplugin: falha ao abrir " .. path .. ": " .. tostring(load_error))
    return loader()
end

local T = loadPluginLuaFile("tarot_gettext.lua")

-- Módulos próprios mantidos no mesmo diretório do main.lua para facilitar
-- manutenção manual no Kindle. Apenas os catálogos de idioma ficam em l10n/.
local UI_TEXT = loadPluginLuaFile("tarot_strings.lua")
local CARD_DATA = loadPluginLuaFile("tarot_cards.lua")

local MAJOR_ARCANA  = CARD_DATA.MAJOR_ARCANA
local MINOR_ARCANA  = CARD_DATA.MINOR_ARCANA
local FULL_DECK     = CARD_DATA.FULL_DECK
local LENORMAND_DECK = CARD_DATA.LENORMAND_DECK

local UI_HELPERS = loadPluginLuaFile("tarot_ui.lua")
local getFullscreenLayout = UI_HELPERS.getFullscreenLayout
local makeFullscreenFrame = UI_HELPERS.makeFullscreenFrame
local makeTarotDivider = UI_HELPERS.makeTarotDivider
local makeSectionHeader = UI_HELPERS.makeSectionHeader
local makeMutedText = UI_HELPERS.makeMutedText
local getCompactEmptyFooterHeight = UI_HELPERS.getCompactEmptyFooterHeight
local makeFullscreenScaffold = UI_HELPERS.makeFullscreenScaffold
local makeFullscreenFooter = UI_HELPERS.makeFullscreenFooter
local addHorizontalSwipeNavigation = UI_HELPERS.addHorizontalSwipeNavigation
local getTopIconMetrics = UI_HELPERS.getTopIconMetrics
local getTarotBaseButtonRadius = UI_HELPERS.getTarotBaseButtonRadius
local getTarotButtonRadius = UI_HELPERS.getTarotButtonRadius
local makeSettingsCard = UI_HELPERS.makeSettingsCard
local makeRoundedButton = UI_HELPERS.makeRoundedButton
local makeTransparentTextButton = UI_HELPERS.makeTransparentTextButton
local setTarotDirty = UI_HELPERS.setTarotDirty
local isRegularFile = UI_HELPERS.isRegularFile
local makeSafeImageWidget = UI_HELPERS.makeSafeImageWidget
local runTarotCallback = UI_HELPERS.runTarotCallback

local makeFloatingIconButton
local makeInlineIconButton
local makeTopBackIconButton
local makeTopCloseIconButton
local makeInlineIconTextButton
local makeSettingsToggleButton


local function getPluginLanguageCode()
    local language = tostring(T.requested_lang or T.current_lang or "C")
    language = language:match("^([^:]+)") or language
    language = language:gsub("%..*$", ""):gsub("@.*$", ""):gsub("-", "_"):lower()
    return language
end

local function isPluginLanguageEnglish()
    local language = getPluginLanguageCode()
    return language == "" or language == "c" or language:match("^en") ~= nil
end

local function getTranslatedFallback(key)
    if key == "refresh_mode_standard" then
        local language = getPluginLanguageCode()
        if language:match("^pt") then
            return "Equilibrado"
        elseif language:match("^es") then
            return "Equilibrado"
        elseif language:match("^zh") then
            return "均衡"
        end
    end
    return nil
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║             SEÇÕES 2–4: CARTAS MODULARIZADAS EM tarot_cards.lua    ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                  SEÇÃO 5: PLUGIN PRINCIPAL (TarotPlugin)                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local TarotPlugin = InputContainer:extend{
    name        = "tarot",
    fullname    = T(UI_TEXT.title),
    is_doc_only = false,
}

loadPluginLuaFile("tarot_core.lua").register{
    TarotPlugin = TarotPlugin,
    T = T,
    UI_TEXT = UI_TEXT,
    PLUGIN_DIR = PLUGIN_DIR,
    MAJOR_ARCANA = MAJOR_ARCANA,
    FULL_DECK = FULL_DECK,
    LENORMAND_DECK = LENORMAND_DECK,
    setTarotDirty = setTarotDirty,
    isPluginLanguageEnglish = isPluginLanguageEnglish,
    getTranslatedFallback = getTranslatedFallback,
}

-- Nomes predefinidos são salvos por identificador, e não pelo texto já
-- traduzido. Assim, uma tiragem criada em português continua correta caso o
-- idioma do KOReader seja alterado depois.
local POSITION_NAMES = loadPluginLuaFile("tarot_position_names.lua")
local POSITION_NAME_PRESETS = POSITION_NAMES.presets
local trimPositionName = POSITION_NAMES.trim
local makeStoredPresetPositionName = POSITION_NAMES.makeStoredPreset
local makeStoredCustomPositionName = POSITION_NAMES.makeStoredCustom
local getPositionNameDisplay = POSITION_NAMES.getDisplay

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           SEÇÃO 6: IMAGENS DAS CARTAS (módulo)                              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

loadPluginLuaFile("tarot_card_images.lua").register{
    TarotPlugin = TarotPlugin,
    T = T,
    isRegularFile = isRegularFile,
    makeSafeImageWidget = makeSafeImageWidget,
}

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║        SEÇÃO 7: DIÁRIO DE REFLEXÕES (armazenamento, busca e UI)             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- Os registros novos usam arquivos .trj de texto simples e não executável.
-- O formato é deliberadamente pequeno e tolerante a caracteres especiais.
-- Tiragens antigas em .txt continuam intactas e aparecem como registros antigos.
local JOURNAL = loadPluginLuaFile("tarot_journal_utils.lua")
local JOURNAL_MAGIC = JOURNAL.magic
local journalTrim = JOURNAL.trim
local journalEscape = JOURNAL.escape
local journalUnescape = JOURNAL.unescape
local journalReadAll = JOURNAL.readAll
local journalWriteAll = JOURNAL.writeAll
local journalCopyFile = JOURNAL.copyFile
local journalUniquePath = JOURNAL.uniquePath
local journalShallowCopy = JOURNAL.shallowCopy
local journalSafeLower = JOURNAL.safeLower
local journalPreview = JOURNAL.preview

loadPluginLuaFile("tarot_pins.lua").register{
    TarotPlugin = TarotPlugin,
    T = T,
    FULL_DECK = FULL_DECK,
    LENORMAND_DECK = LENORMAND_DECK,
    journalTrim = journalTrim,
    journalEscape = journalEscape,
    journalUnescape = journalUnescape,
    journalReadAll = journalReadAll,
    journalWriteAll = journalWriteAll,
    getFullscreenLayout = getFullscreenLayout,
    getTopIconMetrics = getTopIconMetrics,
    getTarotButtonRadius = getTarotButtonRadius,
    setTarotDirty = setTarotDirty,
}

local WIDGETS = loadPluginLuaFile("tarot_widgets.lua").create{
    makeSafeImageWidget = makeSafeImageWidget,
    getFullscreenLayout = getFullscreenLayout,
    getTopIconMetrics = getTopIconMetrics,
    getTarotButtonRadius = getTarotButtonRadius,
    makeTransparentTextButton = makeTransparentTextButton,
    makeRoundedButton = makeRoundedButton,
    setTarotDirty = setTarotDirty,
    runTarotCallback = runTarotCallback,
    isRegularFile = isRegularFile,
}
local TappableImageContainer = WIDGETS.TappableImageContainer
makeFloatingIconButton = WIDGETS.makeFloatingIconButton
makeInlineIconButton = WIDGETS.makeInlineIconButton
makeTopBackIconButton = WIDGETS.makeTopBackIconButton
makeTopCloseIconButton = WIDGETS.makeTopCloseIconButton
makeInlineIconTextButton = WIDGETS.makeInlineIconTextButton
makeSettingsToggleButton = WIDGETS.makeSettingsToggleButton

local FullscreenMenuDialog = loadPluginLuaFile("tarot_fullscreen_menu.lua").create{
    getFullscreenLayout = getFullscreenLayout,
    makeInlineIconTextButton = makeInlineIconTextButton,
    makeTransparentTextButton = makeTransparentTextButton,
    makeRoundedButton = makeRoundedButton,
    makeFloatingIconButton = makeFloatingIconButton,
    makeFullscreenFooter = makeFullscreenFooter,
    makeFullscreenScaffold = makeFullscreenScaffold,
    addHorizontalSwipeNavigation = addHorizontalSwipeNavigation,
    setTarotDirty = setTarotDirty,
}

loadPluginLuaFile("tarot_custom_meanings.lua").register{
    TarotPlugin = TarotPlugin,
    T = T,
    FULL_DECK = FULL_DECK,
    LENORMAND_DECK = LENORMAND_DECK,
    FullscreenMenuDialog = FullscreenMenuDialog,
    journalTrim = journalTrim,
    journalEscape = journalEscape,
    journalUnescape = journalUnescape,
    journalReadAll = journalReadAll,
    journalWriteAll = journalWriteAll,
    journalPreview = journalPreview,
    journalSafeLower = journalSafeLower,
    getFullscreenLayout = getFullscreenLayout,
    getTopIconMetrics = getTopIconMetrics,
    makeRoundedButton = makeRoundedButton,
    makeSettingsCard = makeSettingsCard,
    makeSectionHeader = makeSectionHeader,
    makeFullscreenScaffold = makeFullscreenScaffold,
    makeTopBackIconButton = makeTopBackIconButton,
    getTarotButtonRadius = getTarotButtonRadius,
    setTarotDirty = setTarotDirty,
}

local CardDialog = loadPluginLuaFile("tarot_card_dialog.lua").create{
    T = T,
    TappableImageContainer = TappableImageContainer,
    getFullscreenLayout = getFullscreenLayout,
    makeFullscreenFrame = makeFullscreenFrame,
    makeFullscreenScaffold = makeFullscreenScaffold,
    makeSectionHeader = makeSectionHeader,
    makeMutedText = makeMutedText,
    makeFloatingIconButton = makeFloatingIconButton,
    makeTopBackIconButton = makeTopBackIconButton,
    addHorizontalSwipeNavigation = addHorizontalSwipeNavigation,
    getPositionNameDisplay = getPositionNameDisplay,
    isRegularFile = isRegularFile,
    journalTrim = journalTrim,
    setTarotDirty = setTarotDirty,
}

local PhysicalDeckDialog = loadPluginLuaFile("tarot_physical_deck.lua").create{
    T = T,
    UI_TEXT = UI_TEXT,
    CardDialog = CardDialog,
    getFullscreenLayout = getFullscreenLayout,
    makeSectionHeader = makeSectionHeader,
    makeFullscreenScaffold = makeFullscreenScaffold,
    makeFullscreenFooter = makeFullscreenFooter,
    makeTransparentTextButton = makeTransparentTextButton,
    makeTopBackIconButton = makeTopBackIconButton,
    addHorizontalSwipeNavigation = addHorizontalSwipeNavigation,
    setTarotDirty = setTarotDirty,
}

local HiddenCardDialog = loadPluginLuaFile("tarot_hidden_cards.lua").create{
    T = T,
    CardDialog = CardDialog,
    TappableImageContainer = TappableImageContainer,
    POSITION_NAME_PRESETS = POSITION_NAME_PRESETS,
    trimPositionName = trimPositionName,
    makeStoredPresetPositionName = makeStoredPresetPositionName,
    makeStoredCustomPositionName = makeStoredCustomPositionName,
    getPositionNameDisplay = getPositionNameDisplay,
    getFullscreenLayout = getFullscreenLayout,
    makeSectionHeader = makeSectionHeader,
    makeFullscreenScaffold = makeFullscreenScaffold,
    makeFloatingIconButton = makeFloatingIconButton,
    makeTopBackIconButton = makeTopBackIconButton,
    getTarotBaseButtonRadius = getTarotBaseButtonRadius,
    getTarotButtonRadius = getTarotButtonRadius,
    setTarotDirty = setTarotDirty,
}

loadPluginLuaFile("tarot_journal.lua").register{
    TarotPlugin = TarotPlugin,
    T = T,
    FULL_DECK = FULL_DECK,
    LENORMAND_DECK = LENORMAND_DECK,
    JOURNAL_MAGIC = JOURNAL_MAGIC,
    FullscreenMenuDialog = FullscreenMenuDialog,
    CardDialog = CardDialog,
    HiddenCardDialog = HiddenCardDialog,
    journalTrim = journalTrim,
    journalEscape = journalEscape,
    journalUnescape = journalUnescape,
    journalReadAll = journalReadAll,
    journalWriteAll = journalWriteAll,
    journalCopyFile = journalCopyFile,
    journalUniquePath = journalUniquePath,
    journalShallowCopy = journalShallowCopy,
    journalSafeLower = journalSafeLower,
    journalPreview = journalPreview,
    getFullscreenLayout = getFullscreenLayout,
    getTopIconMetrics = getTopIconMetrics,
    makeSectionHeader = makeSectionHeader,
    makeMutedText = makeMutedText,
    makeFullscreenScaffold = makeFullscreenScaffold,
    makeFullscreenFooter = makeFullscreenFooter,
    makeFloatingIconButton = makeFloatingIconButton,
    makeTopBackIconButton = makeTopBackIconButton,
    makeRoundedButton = makeRoundedButton,
    getTarotButtonRadius = getTarotButtonRadius,
    addHorizontalSwipeNavigation = addHorizontalSwipeNavigation,
    setTarotDirty = setTarotDirty,
}

local TarotHomeDialog = loadPluginLuaFile("tarot_home.lua").create{
    T = T,
    CardDialog = CardDialog,
    getFullscreenLayout = getFullscreenLayout,
    getTarotButtonRadius = getTarotButtonRadius,
    getCompactEmptyFooterHeight = getCompactEmptyFooterHeight,
    makeTarotDivider = makeTarotDivider,
    makeFullscreenScaffold = makeFullscreenScaffold,
    makeFloatingIconButton = makeFloatingIconButton,
    makeTopCloseIconButton = makeTopCloseIconButton,
    makeInlineIconButton = makeInlineIconButton,
    makeRoundedButton = makeRoundedButton,
    setTarotDirty = setTarotDirty,
}

local SettingsDialog = loadPluginLuaFile("tarot_settings_dialog.lua").create{
    TarotHomeDialog = TarotHomeDialog,
    getFullscreenLayout = getFullscreenLayout,
    makeSectionHeader = makeSectionHeader,
    makeSettingsToggleButton = makeSettingsToggleButton,
    makeMutedText = makeMutedText,
    makeTarotDivider = makeTarotDivider,
    makeSettingsCard = makeSettingsCard,
    makeInlineIconTextButton = makeInlineIconTextButton,
    makeRoundedButton = makeRoundedButton,
    makeFullscreenFooter = makeFullscreenFooter,
    makeFullscreenScaffold = makeFullscreenScaffold,
    makeTopBackIconButton = makeTopBackIconButton,
    makeFloatingIconButton = makeFloatingIconButton,
    addHorizontalSwipeNavigation = addHorizontalSwipeNavigation,
    setTarotDirty = setTarotDirty,
}

local CARD_BOOK_UI = loadPluginLuaFile("tarot_card_book.lua").create{
    T = T,
    MAJOR_ARCANA = MAJOR_ARCANA,
    MINOR_ARCANA = MINOR_ARCANA,
    FULL_DECK = FULL_DECK,
    LENORMAND_DECK = LENORMAND_DECK,
    journalTrim = journalTrim,
    getFullscreenLayout = getFullscreenLayout,
    makeFullscreenScaffold = makeFullscreenScaffold,
    makeFullscreenFooter = makeFullscreenFooter,
    makeSectionHeader = makeSectionHeader,
    makeTopBackIconButton = makeTopBackIconButton,
    makeFloatingIconButton = makeFloatingIconButton,
    makeRoundedButton = makeRoundedButton,
    makeSettingsCard = makeSettingsCard,
    getTarotButtonRadius = getTarotButtonRadius,
    addHorizontalSwipeNavigation = addHorizontalSwipeNavigation,
    setTarotDirty = setTarotDirty,
}
local CardBookDialog = CARD_BOOK_UI.CardBookDialog
local CardBookMenu = CARD_BOOK_UI.CardBookMenu

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                  SEÇÃO 12: MENU E ORQUESTRAÇÃO                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
loadPluginLuaFile("tarot_routes.lua").register{
    TarotPlugin = TarotPlugin,
    TarotHomeDialog = TarotHomeDialog,
    PhysicalDeckDialog = PhysicalDeckDialog,
    HiddenCardDialog = HiddenCardDialog,
    CardDialog = CardDialog,
    SettingsDialog = SettingsDialog,
    CardBookDialog = CardBookDialog,
    CardBookMenu = CardBookMenu,
    MAJOR_ARCANA = MAJOR_ARCANA,
    FULL_DECK = FULL_DECK,
    LENORMAND_DECK = LENORMAND_DECK,
    getFullscreenLayout = getFullscreenLayout,
    makeRoundedButton = makeRoundedButton,
    makeSettingsCard = makeSettingsCard,
    makeSectionHeader = makeSectionHeader,
    makeFullscreenScaffold = makeFullscreenScaffold,
    makeTopBackIconButton = makeTopBackIconButton,
    setTarotDirty = setTarotDirty,
}

return TarotPlugin

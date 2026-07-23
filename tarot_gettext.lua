--[[
Carregador de traduções exclusivo do plugin Tarot.

O módulo gettext do KOReader usa um estado global. Para não substituir as
traduções da interface principal, este arquivo:
  1. guarda o estado gettext atual;
  2. carrega temporariamente o catálogo do plugin;
  3. copia o catálogo carregado;
  4. restaura integralmente o estado do KOReader;
  5. devolve um proxy que consulta primeiro o plugin e depois o KOReader.

Compatível com a organização usada no KOReader 2026.03:
    l10n/<idioma>/koreader.mo
O arquivo .po correspondente permanece junto do .mo para manutenção.
]]

local util = require("util")
local GetText = require("gettext")
local logger = require("logger")

-- Descobre a raiz do plugin sem assumir onde o usuário instalou o KOReader.
local source_path = debug.getinfo(1, "S").source
if source_path:sub(1, 1) == "@" then
    source_path = source_path:sub(2)
end
local plugin_path = source_path:match("^(.*)[/\\][^/\\]+$") or "."
plugin_path = plugin_path:gsub("/+", "/")

local PluginGetText = {
    dirname = plugin_path .. "/l10n",
}

-- Carrega o catálogo do plugin sem deixar alterações no gettext global.
local function loadPluginLanguage(language)
    local original = {
        dirname = GetText.dirname,
        context = GetText.context,
        translation = GetText.translation,
        wrapUntranslated = GetText.wrapUntranslated,
        current_lang = GetText.current_lang,
        getPlural = GetText.getPlural,
    }

    GetText.dirname = PluginGetText.dirname

    local ok, err = pcall(GetText.changeLang, language)
    if ok and (
        (GetText.translation and next(GetText.translation) ~= nil)
        or (GetText.context and next(GetText.context) ~= nil)
    ) then
        local copied = util.tableDeepCopy(GetText)
        if copied then
            PluginGetText = copied
        end
    elseif not ok then
        logger.warn(
            "tarot.koplugin: falha ao carregar idioma",
            tostring(language),
            tostring(err)
        )
    end

    -- Restauração obrigatória: o restante do KOReader não pode perceber que
    -- outro catálogo foi carregado temporariamente.
    GetText.dirname = original.dirname
    GetText.context = original.context
    GetText.translation = original.translation
    GetText.wrapUntranslated = original.wrapUntranslated
    GetText.current_lang = original.current_lang
    GetText.getPlural = original.getPlural
end

-- Cria um objeto chamável: T("Text") e também T.ngettext(...).
local function createProxy(plugin_gettext, koreader_gettext)
    if not plugin_gettext.current_lang
        or plugin_gettext.current_lang == "C"
        or not plugin_gettext.translation
        or not plugin_gettext.wrapUntranslated then
        return koreader_gettext
    end

    local function sourceForMethod(method, args)
        if method == "gettext" then
            return args[1]
        elseif method == "pgettext" then
            return args[2]
        elseif method == "ngettext" then
            local plural = plugin_gettext.getPlural
                and plugin_gettext.getPlural(args[3]) ~= 0
            return plural and args[2] or args[1]
        elseif method == "npgettext" then
            local plural = plugin_gettext.getPlural
                and plugin_gettext.getPlural(args[4]) ~= 0
            return plural and args[3] or args[2]
        end
    end

    return setmetatable({}, {
        __index = function(_, key)
            local value = plugin_gettext[key]
            if type(value) ~= "function" then
                return value
            end

            local fallback = koreader_gettext[key]
            return function(...)
                local args = { ... }
                local translated = value(...)
                local source = sourceForMethod(key, args)
                if translated == source and type(fallback) == "function" then
                    return fallback(...)
                end
                return translated
            end
        end,
        __call = function(_, msgid)
            local translated = plugin_gettext(msgid)
            if translated == msgid then
                return koreader_gettext(msgid)
            end
            return translated
        end,
    })
end

-- O KOReader já resolveu o idioma global durante a inicialização.
local current_language = GetText.current_lang
    or G_reader_settings:readSetting("language")

if current_language and current_language ~= "C" then
    loadPluginLanguage(current_language)
end

return createProxy(PluginGetText, GetText)

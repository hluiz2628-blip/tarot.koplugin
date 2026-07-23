--[[
Carregador de traduções isolado do plugin Tarot.

O gettext do KOReader lê diretamente arquivos .po. A implementação anterior
alterava temporariamente o catálogo global, copiava suas tabelas e depois
tentava restaurá-lo. Embora funcionasse no aplicativo para computador, esse
procedimento podia falhar no Kindle e deixava apenas traduções genéricas do
catálogo principal do KOReader, como "Close" -> "Fechar".

Esta versão:
  1. lê o idioma configurado diretamente em settings.reader.lua;
  2. normaliza variantes como pt-BR, pt_BR.UTF-8 e zh_CN:zh;
  3. abre somente o .po pertencente ao plugin;
  4. nunca altera o gettext global do KOReader;
  5. usa o catálogo global apenas como fallback para entradas ausentes.

Estrutura esperada:
    l10n/pt_BR/koreader.po
    l10n/zh_CN/koreader.po

O inglês permanece como idioma-fonte do código e não precisa de catálogo para
ser exibido. O arquivo l10n/en/koreader.po pode continuar no pacote para
manutenção e distribuição padronizada.
]]

local CoreGetText = require("gettext")
local logger = require("logger")

-- Descobre a pasta real do plugin sem assumir o caminho de instalação.
local source_path = debug.getinfo(1, "S").source or ""
if source_path:sub(1, 1) == "@" then
    source_path = source_path:sub(2)
end

local plugin_path = source_path:match("^(.*)[/\\][^/\\]+$") or "."
plugin_path = plugin_path:gsub("\\", "/"):gsub("/+", "/")

local l10n_path = plugin_path .. "/l10n"

local PluginGetText = {
    current_lang = "C",
    requested_lang = "C",
    catalog_path = nil,
    translation = {},
}

-- Remove espaços externos sem depender de util.trim.
local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Adiciona um item apenas se ele ainda não estiver na lista.
local function addUnique(list, seen, value)
    if value and value ~= "" and not seen[value] then
        seen[value] = true
        table.insert(list, value)
    end
end

-- Normaliza o código informado pelo KOReader ou pelo sistema operacional.
local function normalizeLanguage(language)
    if type(language) ~= "string" then
        return nil
    end

    language = trim(language)
    if language == "" then
        return nil
    end

    -- Listas como "pt_BR:pt" usam o primeiro idioma preferencial.
    language = language:match("^([^:]+)") or language

    -- Remove codificação e modificadores: pt_BR.UTF-8@variant -> pt_BR.
    language = language:gsub("%..*$", "")
    language = language:gsub("@.*$", "")
    language = language:gsub("-", "_")

    return language
end

-- Produz candidatos compatíveis com os códigos usados pelo KOReader.
local function getLanguageCandidates(language)
    local normalized = normalizeLanguage(language)
    local candidates = {}
    local seen = {}

    if not normalized then
        return candidates
    end

    addUnique(candidates, seen, normalized)

    local lower = normalized:lower()
    local base = lower:match("^([a-z][a-z])")

    if base == "pt" then
        -- O plugin fornece português brasileiro como catálogo principal.
        addUnique(candidates, seen, "pt_BR")
        addUnique(candidates, seen, "pt")
    elseif base == "zh" then
        -- zh, zh-Hans e variantes simplificadas usam zh_CN.
        if lower == "zh" or lower:find("hans", 1, true)
            or lower:find("_cn", 1, true)
            or lower:find("_sg", 1, true) then
            addUnique(candidates, seen, "zh_CN")
        end
    elseif base == "en" then
        addUnique(candidates, seen, "en")
    elseif base then
        addUnique(candidates, seen, base)
    end

    return candidates
end

-- Testa um arquivo em modo somente leitura e o fecha imediatamente.
local function fileExists(path)
    local file = io.open(path, "rb")
    if not file then
        return false
    end
    file:close()
    return true
end

-- Decodifica o conteúdo entre aspas usado em msgid e msgstr.
local function decodePOString(quoted)
    if type(quoted) ~= "string" then
        return nil
    end

    local value = quoted:match('^%s*"(.*)"%s*$')
    if value == nil then
        return nil
    end

    local escapes = {
        a = "\a",
        b = "\b",
        f = "\f",
        n = "\n",
        r = "\r",
        t = "\t",
        v = "\v",
        ['"'] = '"',
        ["\\"] = "\\",
    }

    return (value:gsub("\\(.)", function(character)
        return escapes[character] or character
    end))
end

-- Lê o subconjunto padrão de PO utilizado pelos catálogos deste plugin.
local function loadPO(path)
    local file, open_error = io.open(path, "r")
    if not file then
        return nil, open_error or "não foi possível abrir o arquivo"
    end

    local translations = {}
    local entry = {}
    local active_field = nil
    local fuzzy = false

    local function commitEntry()
        if not fuzzy
            and entry.msgid
            and entry.msgid ~= ""
            and entry.msgstr
            and entry.msgstr ~= "" then
            translations[entry.msgid] = entry.msgstr
        end

        entry = {}
        active_field = nil
        fuzzy = false
    end

    for line in file:lines() do
        if line == "" then
            commitEntry()
        elseif line:match("^#,.*fuzzy") then
            fuzzy = true
        else
            local field, quoted = line:match("^(msgid)%s+(.+)$")
            if not field then
                field, quoted = line:match("^(msgstr)%s+(.+)$")
            end

            if field then
                local decoded = decodePOString(quoted)
                if decoded == nil then
                    file:close()
                    return nil, "linha PO inválida: " .. line
                end
                active_field = field
                entry[field] = decoded
            elseif active_field then
                local decoded = decodePOString(line)
                if decoded ~= nil then
                    entry[active_field] = (entry[active_field] or "") .. decoded
                end
            end
        end
    end

    commitEntry()
    file:close()

    return translations
end

-- A configuração persistida é mais confiável que o estado interno do gettext
-- em dispositivos onde os plugins podem ser carregados em momentos distintos.
local function getConfiguredLanguage()
    if G_reader_settings
        and type(G_reader_settings.readSetting) == "function" then
        local ok, language = pcall(
            G_reader_settings.readSetting,
            G_reader_settings,
            "language"
        )
        if ok and language and language ~= "" then
            return language
        end
    end

    return CoreGetText.current_lang or "C"
end

local function loadConfiguredCatalog()
    local requested = getConfiguredLanguage()
    PluginGetText.requested_lang = requested or "C"

    local normalized = normalizeLanguage(requested)
    if not normalized
        or normalized == "C"
        or normalized:lower():match("^en") then
        -- O próprio msgid já é o texto inglês.
        PluginGetText.current_lang = "C"
        return
    end

    local candidates = getLanguageCandidates(requested)
    local attempted = {}

    for _, language in ipairs(candidates) do
        local path = l10n_path .. "/" .. language .. "/koreader.po"
        table.insert(attempted, path)

        if fileExists(path) then
            local translations, load_error = loadPO(path)
            if translations and next(translations) ~= nil then
                PluginGetText.translation = translations
                PluginGetText.current_lang = language
                PluginGetText.catalog_path = path
                logger.info(
                    "tarot.koplugin: catálogo carregado:",
                    language,
                    path
                )
                return
            end

            logger.warn(
                "tarot.koplugin: catálogo inválido ou vazio:",
                path,
                tostring(load_error)
            )
        end
    end

    logger.warn(
        "tarot.koplugin: catálogo não encontrado para",
        tostring(requested),
        table.concat(attempted, ", ")
    )
end

loadConfiguredCatalog()

-- Consulta primeiro o catálogo do Tarot e só depois o gettext principal.
local function translate(msgid)
    if type(msgid) ~= "string" then
        return tostring(msgid)
    end

    local translated = PluginGetText.translation[msgid]
    if translated and translated ~= "" then
        return translated
    end

    return CoreGetText(msgid)
end

-- Métodos mantidos para compatibilidade com o formato do gettext do KOReader.
function PluginGetText.gettext(msgid)
    return translate(msgid)
end

function PluginGetText.pgettext(context, msgid)
    local translated = PluginGetText.translation[msgid]
    if translated and translated ~= "" then
        return translated
    end
    if type(CoreGetText.pgettext) == "function" then
        return CoreGetText.pgettext(context, msgid)
    end
    return CoreGetText(msgid)
end

function PluginGetText.ngettext(msgid, msgid_plural, number)
    local source = number == 1 and msgid or msgid_plural
    return translate(source)
end

function PluginGetText.npgettext(context, msgid, msgid_plural, number)
    local source = number == 1 and msgid or msgid_plural
    return PluginGetText.pgettext(context, source)
end

return setmetatable(PluginGetText, {
    __call = function(_, msgid)
        return translate(msgid)
    end,
})

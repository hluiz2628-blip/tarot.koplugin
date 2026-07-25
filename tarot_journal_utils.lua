-- Utilitários de armazenamento do Diário de Reflexões.
-- Separar essas funções reduz o main.lua e mantém o formato .trj isolado.

local lfs = require("libs/libkoreader-lfs")

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
    text = text:gsub("|", "%%7C")
    return text
end

local function journalUnescape(text)
    text = tostring(text or "")
    text = text:gsub("%%7C", "|")
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



return {
    magic = JOURNAL_MAGIC,
    trim = journalTrim,
    escape = journalEscape,
    unescape = journalUnescape,
    readAll = journalReadAll,
    writeAll = journalWriteAll,
    copyFile = journalCopyFile,
    uniquePath = journalUniquePath,
    shallowCopy = journalShallowCopy,
    safeLower = journalSafeLower,
    preview = journalPreview,
}

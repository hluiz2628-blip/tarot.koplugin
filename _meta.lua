-- Metadados lidos pelo gerenciador de plugins do KOReader.
-- Carrega o tradutor pelo caminho do próprio plugin. Isso impede que o Kindle
-- procure tarot_gettext.lua somente nos diretórios globais do package.path.
local source = debug.getinfo(1, "S").source or ""
if source:sub(1, 1) == "@" then
    source = source:sub(2)
end

local plugin_dir = source:match("^(.*[/\\])[^/\\]+$")
assert(plugin_dir, "tarot.koplugin: não foi possível localizar a pasta do plugin")

local loader_path = plugin_dir .. "tarot_gettext.lua"
local loader, load_error = loadfile(loader_path)
assert(loader, "tarot.koplugin: falha ao abrir " .. loader_path .. ": " .. tostring(load_error))

local T = loader()

return {
    name = "tarot",
    fullname = T("Tarot Reading"),
    description = T("Draw Tarot and Lenormand cards for reflection, save readings, and browse the complete card book."),
    version = "5.1.0",
}

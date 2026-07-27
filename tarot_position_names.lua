-- Identificadores e formatação dos nomes de posições nas tiragens.
-- Os nomes predefinidos são salvos por id para sobreviverem à troca de idioma.

local M = {}

M.presets = {
    { id = "past",      key = "position_past" },
    { id = "present",   key = "position_present" },
    { id = "future",    key = "position_future" },
    { id = "situation", key = "position_situation" },
    { id = "obstacle",  key = "position_obstacle" },
    { id = "advice",    key = "position_advice" },
    { id = "outcome",   key = "position_outcome" },
}

M.keys = {}
for _, preset in ipairs(M.presets) do
    M.keys[preset.id] = preset.key
end

function M.trim(text)
    text = tostring(text or "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.makeStoredPreset(id)
    return "preset:" .. tostring(id or "")
end

function M.makeStoredCustom(text)
    return "custom:" .. M.trim(text)
end

function M.getDisplay(plugin, stored_name)
    stored_name = M.trim(stored_name)
    if stored_name == "" then return "" end

    local preset_id = stored_name:match("^preset:(.+)$")
    if preset_id and M.keys[preset_id] then
        return plugin:getTranslation(M.keys[preset_id])
    end

    local custom_name = stored_name:match("^custom:(.*)$")
    if custom_name ~= nil then
        return M.trim(custom_name)
    end

    return stored_name
end

return M

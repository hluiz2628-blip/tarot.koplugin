-- Menu fullscreen reutilizável com rodapé, overlays e swipe.

local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local M = {}

function M.create(deps)
    deps = deps or {}
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local makeInlineIconTextButton = assert(deps.makeInlineIconTextButton, "makeInlineIconTextButton is required")
    local makeTransparentTextButton = assert(deps.makeTransparentTextButton, "makeTransparentTextButton is required")
    local makeRoundedButton = assert(deps.makeRoundedButton, "makeRoundedButton is required")
    local makeFloatingIconButton = assert(deps.makeFloatingIconButton, "makeFloatingIconButton is required")
    local makeFullscreenFooter = assert(deps.makeFullscreenFooter, "makeFullscreenFooter is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local addHorizontalSwipeNavigation = assert(deps.addHorizontalSwipeNavigation, "addHorizontalSwipeNavigation is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

    local FullscreenMenuDialog = InputContainer:extend{
        plugin = nil,
        title = nil,
        buttons = nil,
    }

    function FullscreenMenuDialog:init()
        local layout = getFullscreenLayout(0.88)
        local iw = layout.content_w

        local body = VerticalGroup:new{ align = "center" }
        local footer_rows = {}
        local top_left_specs = {}
        local top_right_specs = {}
        local swipe_previous_spec
        local swipe_next_spec

        local prev_text = self.plugin and self.plugin.getTranslation
            and self.plugin:getTranslation("prev") or ""
        local next_text = self.plugin and self.plugin.getTranslation
            and self.plugin:getTranslation("next") or ""
        local back_text = self.plugin and self.plugin.getTranslation
            and self.plugin:getTranslation("back") or ""
        local back_to_journal_text = self.plugin and self.plugin.getTranslation
            and self.plugin:getTranslation("back_to_journal") or ""
        local close_text = self.plugin and self.plugin.getTranslation
            and self.plugin:getTranslation("close") or ""
        local exit_text = self.plugin and self.plugin.getTranslation
            and self.plugin:getTranslation("exit") or ""

        local function isPreviousSpec(spec)
            local text = tostring(spec and spec.text or "")
            return text == "<" or text == "‹" or (prev_text ~= "" and text == prev_text)
        end

        local function isNextSpec(spec)
            local text = tostring(spec and spec.text or "")
            return text == ">" or text == "›" or (next_text ~= "" and text == next_text)
        end

        local function isBackSpec(spec)
            local text = tostring(spec and spec.text or "")
            return spec and (
                spec.top_left == true
                or spec.icon_name == "arrow-left"
                or (back_text ~= "" and text == back_text)
                or (back_to_journal_text ~= "" and text == back_to_journal_text)
            )
        end

        local function isCloseSpec(spec)
            local text = tostring(spec and spec.text or "")
            return spec and (
                spec.top_right == true
                or spec.icon_name == "exit"
                or (close_text ~= "" and text == close_text)
                or (exit_text ~= "" and text == exit_text)
            )
        end

        local function invokeMenuSpec(button_spec, button_dialog)
            -- Em telas fullscreen, o próprio menu deve saber se precisa fechar
            -- antes/depois da ação. Isso evita callbacks presos a variáveis
            -- externas de diálogos antigos, causa comum de botões sem efeito.
            if not button_spec or button_spec.enabled == false then return false end

            if button_spec.close_before or button_spec.close_dialog then
                UIManager:close(button_dialog)
                setTarotDirty(self.plugin or self)
            end

            if button_spec.callback then
                button_spec.callback(button_dialog)
            end

            if button_spec.close_after then
                UIManager:close(button_dialog)
                setTarotDirty(self.plugin or self)
            end

            return true
        end

        local function makeMenuButton(spec, width, button_dialog, is_footer)
            local button_spec = spec
            local callback = function()
                invokeMenuSpec(button_spec, button_dialog)
            end

            local params = {
                text             = spec.text,
                width            = width,
                enabled          = spec.enabled,
                is_enter_default = spec.is_enter_default,
                callback         = callback,
            }

            if spec.icon_name and spec.enabled ~= false and not is_footer then
                return makeInlineIconTextButton{
                    plugin = self.plugin,
                    icon_name = spec.icon_name,
                    text = spec.text,
                    fallback_text = spec.text,
                    width = width,
                    rounded = true,
                    callback = callback,
                }
            end

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
                        if spec.widget then
                            -- Permite inserir conteúdo informativo real dentro de
                            -- menus fullscreen, como avisos com caixa de seleção.
                            -- Quando spec.widget é função, ela recebe o diálogo do
                            -- menu como parent, útil para CheckButton.
                            local widget = spec.widget
                            if type(widget) == "function" then
                                widget = widget(self, iw, is_footer)
                            end
                            if widget then table.insert(target, widget) end
                        elseif spec.label then
                            table.insert(target, TextWidget:new{
                                text = spec.text or "",
                                face = Font:getFace("smalltfont"),
                                bold = true,
                                max_width = iw,
                                alignment = "center",
                            })
                        else
                            if spec.callback and spec.enabled ~= false then
                                if isPreviousSpec(spec) then
                                    swipe_previous_spec = swipe_previous_spec or spec
                                elseif isNextSpec(spec) then
                                    swipe_next_spec = swipe_next_spec or spec
                                end
                            end
                            table.insert(target, makeMenuButton(spec, iw, self, is_footer))
                        end
                        table.insert(target, VerticalSpan:new{ width = Size.span.vertical_default })
                    end
                else
                    local group = HorizontalGroup:new{ align = "center" }
                    local btn_w = math.floor((iw - Size.span.horizontal_default * (row_count - 1)) / row_count)

                    for index, spec in ipairs(row) do
                        if spec and spec.callback and spec.enabled ~= false then
                            if isPreviousSpec(spec) then
                                swipe_previous_spec = swipe_previous_spec or spec
                            elseif isNextSpec(spec) then
                                swipe_next_spec = swipe_next_spec or spec
                            end
                        end
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

        for _, row in ipairs(self.buttons or {}) do
            local filtered_row = {}
            for _, spec in ipairs(row) do
                if spec and spec.footer and isBackSpec(spec) then
                    table.insert(top_left_specs, spec)
                elseif spec and spec.footer and isCloseSpec(spec) then
                    table.insert(top_right_specs, spec)
                else
                    table.insert(filtered_row, spec)
                end
            end

            local is_footer = false
            for _, spec in ipairs(filtered_row) do
                if spec.footer then
                    is_footer = true
                    break
                end
            end

            if #filtered_row > 0 and is_footer then
                table.insert(footer_rows, filtered_row)
            elseif #filtered_row > 0 then
                appendRows(body, { filtered_row }, false)
            end
        end

        local top_overlays = {}
        for index, spec in ipairs(top_left_specs) do
            if spec.enabled ~= false then
                local button_spec = spec
                table.insert(top_overlays, makeFloatingIconButton{
                    plugin = self.plugin,
                    layout = layout,
                    icon_name = button_spec.icon_name or "arrow-left",
                    fallback_text = button_spec.fallback_text or back_text,
                    side = "left",
                    slot = index - 1,
                    callback = function()
                        invokeMenuSpec(button_spec, self)
                    end,
                })
            end
        end
        for index, spec in ipairs(top_right_specs) do
            if spec.enabled ~= false then
                local button_spec = spec
                table.insert(top_overlays, makeFloatingIconButton{
                    plugin = self.plugin,
                    layout = layout,
                    icon_name = button_spec.icon_name or "exit",
                    fallback_text = button_spec.fallback_text or close_text or exit_text,
                    side = "right",
                    slot = index - 1,
                    callback = function()
                        invokeMenuSpec(button_spec, self)
                    end,
                })
            end
        end

        local footer
        if #footer_rows > 0 then
            local footer_content = VerticalGroup:new{ align = "center" }
            appendRows(footer_content, footer_rows, true)
            footer = makeFullscreenFooter(iw, footer_content)
        end

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            title = self.title,
            body = body,
            footer = footer,
        }

        if #top_overlays > 0 then
            local layers = {
                dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
                fullscreen_scaffold,
            }
            for _, overlay_button in ipairs(top_overlays) do
                table.insert(layers, overlay_button)
            end
            self[1] = OverlapGroup:new(layers)
        else
            self[1] = fullscreen_scaffold
        end

        addHorizontalSwipeNavigation(self, "tarot_fullscreen_menu_swipe_nav",
            swipe_previous_spec and function()
                invokeMenuSpec(swipe_previous_spec, self)
            end or nil,
            swipe_next_spec and function()
                invokeMenuSpec(swipe_next_spec, self)
            end or nil
        )
    end

    -- ╔══════════════════════════════════════════════════════════════════════════════╗

    return FullscreenMenuDialog
end

return M

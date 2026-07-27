-- Widgets reutilizáveis do Tarot: botões de ícone, toggles e áreas tocáveis.

local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local Screen = require("device").screen
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")

local M = {}

function M.create(deps)
    deps = deps or {}
    local makeSafeImageWidget = assert(deps.makeSafeImageWidget, "makeSafeImageWidget is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local getTopIconMetrics = assert(deps.getTopIconMetrics, "getTopIconMetrics is required")
    local getTarotButtonRadius = assert(deps.getTarotButtonRadius, "getTarotButtonRadius is required")
    local makeTransparentTextButton = assert(deps.makeTransparentTextButton, "makeTransparentTextButton is required")
    local makeRoundedButton = assert(deps.makeRoundedButton, "makeRoundedButton is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")
    local runTarotCallback = assert(deps.runTarotCallback, "runTarotCallback is required")
    local isRegularFile = assert(deps.isRegularFile, "isRegularFile is required")

    local makeFloatingIconButton
    local makeInlineIconButton
    local makeBackIconButton
    local makeTopBackIconButton
    local makeTopCloseIconButton
    local makeInlineIconTextButton
    local makeSettingsToggleButton

    -- Contêiner transparente que adiciona toque a qualquer widget visual sem
    -- alterar sua aparência. É usado nas miniaturas laterais do CardDialog.
    local TappableImageContainer = InputContainer:extend{
        content = nil,
        callback = nil,
        hold_callback = nil,
    }

    function TappableImageContainer:init()
        if not self.content then
            self.content = TextWidget:new{
                text = "",
                face = Font:getFace("x_smallinfofont"),
                max_width = 1,
            }
        end
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
        runTarotCallback(self.callback, "tap image")
        return true
    end

    function TappableImageContainer:onHoldImage()
        runTarotCallback(self.hold_callback, "hold image")
        return true
    end

    local FloatingIconButton = InputContainer:extend{
        content = nil,
        callback = nil,
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        icon_width = 0,
        icon_height = 0,
        screen_width = nil,
        screen_height = nil,
    }

    function FloatingIconButton:init()
        self.screen_width = self.screen_width or Screen:getWidth()
        self.screen_height = self.screen_height or Screen:getHeight()
        self.dimen = Geom:new{ x = 0, y = 0, w = self.screen_width, h = self.screen_height }
        self.ges_events = {
            TapIcon = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{ x = self.x, y = self.y, w = self.width, h = self.height },
                },
            },
        }
    end

    function FloatingIconButton:paintTo(bb, x, y)
        if not self.content then return end
        local icon_x = x + self.x + math.floor((self.width - self.icon_width) / 2)
        local icon_y = y + self.y + math.floor((self.height - self.icon_height) / 2)
        self.content:paintTo(bb, icon_x, icon_y)
    end

    function FloatingIconButton:onTapIcon()
        runTarotCallback(self.callback, "floating icon")
        return true
    end

    function makeFloatingIconButton(spec)
        spec = spec or {}
        local layout = spec.layout or getFullscreenLayout()
        local metrics = getTopIconMetrics(layout, spec)
        local touch_size = metrics.touch_size
        local icon_size = metrics.icon_size
        local slot = tonumber(spec.slot) or 0
        local gap = metrics.gap
        local side = spec.side or "right"
        local icon_path = spec.icon_path
            or (spec.plugin and spec.icon_name
                and (spec.plugin.plugin_dir .. "/icons/" .. spec.icon_name .. ".svg"))

        local icon_widget
        if isRegularFile(icon_path) then
            icon_widget = makeSafeImageWidget{
                file = icon_path,
                width = icon_size,
                height = icon_size,
                alpha = true,
            }
        end
        if not icon_widget then
            icon_widget = TextWidget:new{
                text = tostring(spec.fallback_text or ""),
                face = Font:getFace("x_smallinfofont"),
                max_width = touch_size,
                alignment = "center",
            }
        end
        local icon_widget_size = icon_widget:getSize()

        local x
        if side == "left" then
            x = layout.outer_pad + slot * (touch_size + gap)
        else
            x = layout.screen_w - layout.outer_pad - touch_size - slot * (touch_size + gap)
        end

        return FloatingIconButton:new{
            content = icon_widget,
            x = math.max(0, x),
            y = math.max(0, layout.outer_pad + (spec.y_offset or 0)),
            width = touch_size,
            height = touch_size,
            icon_width = icon_widget_size.w,
            icon_height = icon_widget_size.h,
            screen_width = layout.screen_w,
            screen_height = layout.screen_h,
            callback = spec.callback,
        }
    end

    function makeInlineIconButton(spec)
        spec = spec or {}
        local width = spec.width or 44
        local touch_size = spec.touch_size or math.max(56, math.min(72, math.floor(width * 0.32)))
        local icon_size = spec.icon_size or math.max(40, math.min(52, math.floor(touch_size * 0.70)))
        local icon_path = spec.icon_path
            or (spec.plugin and spec.icon_name
                and (spec.plugin.plugin_dir .. "/icons/" .. spec.icon_name .. ".svg"))

        local icon_image = makeSafeImageWidget{
            file = icon_path,
            width = icon_size,
            height = icon_size,
            alpha = true,
        }
        if not icon_image then
            return makeTransparentTextButton{
                text = tostring(spec.fallback_text or ""),
                width = width,
                callback = spec.callback,
            }
        end

        return TappableImageContainer:new{
            content = CenterContainer:new{
                dimen = Geom:new{ w = width, h = touch_size },
                icon_image,
            },
            callback = spec.callback,
        }
    end

    function makeBackIconButton(plugin, width, callback)
        return makeInlineIconButton{
            plugin = plugin,
            icon_name = "arrow-left",
            fallback_text = plugin and plugin:getTranslation("back") or "",
            width = width,
            callback = callback,
        }
    end

    function makeTopBackIconButton(plugin, layout, callback, slot)
        return makeFloatingIconButton{
            plugin = plugin,
            layout = layout,
            icon_name = "arrow-left",
            fallback_text = plugin and plugin:getTranslation("back") or "",
            side = "left",
            slot = slot or 0,
            callback = callback,
        }
    end

    function makeTopCloseIconButton(plugin, layout, callback, slot)
        return makeFloatingIconButton{
            plugin = plugin,
            layout = layout,
            icon_name = "exit",
            fallback_text = plugin and (plugin:getTranslation("close") or plugin:getTranslation("exit")) or "",
            side = "right",
            slot = slot or 0,
            callback = callback,
        }
    end

    function makeInlineIconTextButton(spec)
        spec = spec or {}
        local width = spec.width or 200
        local touch_size = spec.touch_size or math.max(56, math.min(72, math.floor(width * 0.20)))
        local icon_size = spec.icon_size or math.max(38, math.min(50, math.floor(touch_size * 0.68)))
        local gap = spec.gap or Size.span.horizontal_default
        local icon_path = spec.icon_path
            or (spec.plugin and spec.icon_name
                and (spec.plugin.plugin_dir .. "/icons/" .. spec.icon_name .. ".svg"))

        local icon_image = makeSafeImageWidget{
            file = icon_path,
            width = icon_size,
            height = icon_size,
            alpha = true,
        }
        if not icon_image then
            return makeRoundedButton{
                text = tostring(spec.text or spec.fallback_text or ""),
                width = width,
                callback = spec.callback,
            }
        end

        local text_w = width - icon_size - gap - Size.padding.default * 2
        if text_w < math.floor(width * 0.45) then text_w = math.floor(width * 0.45) end

        local content = CenterContainer:new{
            dimen = Geom:new{ w = width, h = touch_size },
            HorizontalGroup:new{
                align = "center",
                icon_image,
                HorizontalSpan:new{ width = gap },
                TextWidget:new{
                    text = tostring(spec.text or ""),
                    face = Font:getFace(spec.font_face or "x_smallinfofont"),
                    max_width = text_w,
                    alignment = "center",
                },
            },
        }

        if spec.rounded == true then
            content = FrameContainer:new{
                width = width,
                height = touch_size,
                background = Blitbuffer.COLOR_WHITE,
                bordersize = spec.bordersize ~= nil and spec.bordersize or 1,
                radius = spec.radius or getTarotButtonRadius(),
                padding = 0,
                content,
            }
        end

        return TappableImageContainer:new{
            content = content,
            callback = spec.callback,
        }
    end

    function makeSettingsToggleButton(spec)
        spec = spec or {}
        local plugin = spec.plugin
        local width = spec.width or 200
        local toggle_w = spec.toggle_width or 66
        local toggle_h = spec.toggle_height or 38
        local padding = Size.padding.default
        local gap = Size.span.horizontal_default
        local text_w = width - padding * 2 - toggle_w - gap
        if text_w < math.floor(width * 0.45) then text_w = math.floor(width * 0.45) end

        local icon_name = spec.checked and "toggle-on" or "toggle-off"
        local icon_path = plugin and plugin.plugin_dir and (plugin.plugin_dir .. "/icons/" .. icon_name .. ".svg")
        local toggle_widget = makeSafeImageWidget{
            file = icon_path,
            width = toggle_w,
            height = toggle_h,
            alpha = true,
        }
        if not toggle_widget then
            toggle_widget = TextWidget:new{
                text = spec.checked and "ON" or "OFF",
                face = Font:getFace("x_smallinfofont"),
                max_width = toggle_w,
                alignment = "center",
            }
        end

        local row = HorizontalGroup:new{
            align = "center",
            TextBoxWidget:new{
                text = tostring(spec.text or ""),
                face = Font:getFace("smallinfofont"),
                width = text_w,
                alignment = "left",
            },
            HorizontalSpan:new{ width = gap },
            toggle_widget,
        }

        return TappableImageContainer:new{
            content = FrameContainer:new{
                width = width,
                background = Blitbuffer.COLOR_WHITE,
                bordersize = 1,
                radius = getTarotButtonRadius(),
                padding = padding,
                row,
            },
            callback = spec.callback,
        }
    end


    return {
        TappableImageContainer = TappableImageContainer,
        makeFloatingIconButton = makeFloatingIconButton,
        makeInlineIconButton = makeInlineIconButton,
        makeBackIconButton = makeBackIconButton,
        makeTopBackIconButton = makeTopBackIconButton,
        makeTopCloseIconButton = makeTopCloseIconButton,
        makeInlineIconTextButton = makeInlineIconTextButton,
        makeSettingsToggleButton = makeSettingsToggleButton,
    }
end

return M

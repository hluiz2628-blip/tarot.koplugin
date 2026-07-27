-- Helpers visuais e defensivos compartilhados pelo plugin.
-- Mantém o main.lua focado em fluxo e regras, não em infraestrutura de UI.

local Blitbuffer      = require("ffi/blitbuffer")
local Button          = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font            = require("ui/font")
local Geom            = require("ui/geometry")
local FrameContainer  = require("ui/widget/container/framecontainer")
local ImageWidget     = require("ui/widget/imagewidget")
local Screen          = require("device").screen
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local logger          = require("logger")
local lfs             = require("libs/libkoreader-lfs")

local M = {}

function M.getFullscreenLayout(content_factor)
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

function M.makeFullscreenFrame(content, layout)
    layout = layout or M.getFullscreenLayout()

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

function M.makeTarotDivider(width, shade)
    return TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(shade or 0.55),
        max_width = width,
        alignment = "center",
    }
end

function M.makeSectionHeader(title, width, subtitle, extra_content, with_divider)
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

    if extra_content then
        table.insert(header, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(header, extra_content)
    end

    if with_divider ~= false then
        table.insert(header, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(header, M.makeTarotDivider(width))
    end

    return header
end

function M.makeMutedText(text, width)
    return TextBoxWidget:new{
        text      = text,
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.45),
        width     = width,
        alignment = "center",
    }
end

function M.getCompactEmptyFooterHeight(width)
    local vertical_default = tonumber(Size.span and Size.span.vertical_default) or 8
    local vertical_small = tonumber(Size.span and Size.span.vertical_small)
        or math.max(1, math.floor(vertical_default * 0.5))
    local reference_button_w = math.floor((tonumber(width) or 1) * 0.40)
    local reference_touch_h = math.max(32, math.min(46, math.floor(reference_button_w * 0.36)))
    local estimated_divider_h = vertical_default
    local normal_footer_h = estimated_divider_h + vertical_default + reference_touch_h
    local compact_h = math.floor(normal_footer_h * 0.5)
    local max_h = math.max(vertical_default, math.floor(reference_touch_h * 0.65))

    if compact_h > max_h then compact_h = max_h end
    if compact_h < vertical_small then compact_h = vertical_small end
    return compact_h
end

function M.makeFullscreenScaffold(spec)
    spec = spec or {}
    local layout = spec.layout or M.getFullscreenLayout(spec.content_factor)
    local iw = spec.width or layout.content_w
    local header = spec.header
    if not header and spec.title and spec.title ~= "" then
        header = M.makeSectionHeader(spec.title, iw, spec.subtitle)
    end

    local body = spec.body or VerticalGroup:new{ align = "center" }
    local footer = spec.footer
    local header_gap = header and (spec.header_gap or Size.span.vertical_default) or 0
    local footer_gap = footer and (spec.footer_gap or Size.span.vertical_default) or 0
    local compact_empty_footer_h = 0
    local compact_empty_footer_gap = 0
    if not footer and spec.compact_empty_footer ~= false then
        compact_empty_footer_h = spec.compact_empty_footer_h or M.getCompactEmptyFooterHeight(iw)
        local vertical_default = tonumber(Size.span and Size.span.vertical_default) or 8
        compact_empty_footer_gap = spec.compact_empty_footer_gap or math.max(1, math.floor(vertical_default * 0.5))
    end
    local header_h = header and header:getSize().h or 0
    local footer_h = footer and footer:getSize().h or 0
    local body_h = layout.safe_h
        - header_h
        - footer_h
        - header_gap
        - footer_gap
        - compact_empty_footer_h
        - compact_empty_footer_gap
    if body_h < 1 then body_h = 1 end

    local content = VerticalGroup:new{ align = "center" }
    if header then
        table.insert(content, header)
        if header_gap > 0 then table.insert(content, VerticalSpan:new{ width = header_gap }) end
    end

    table.insert(content, CenterContainer:new{
        dimen = Geom:new{ w = iw, h = body_h },
        body,
    })

    if footer then
        if footer_gap > 0 then table.insert(content, VerticalSpan:new{ width = footer_gap }) end
        table.insert(content, footer)
    elseif compact_empty_footer_h > 0 then
        if compact_empty_footer_gap > 0 then
            table.insert(content, VerticalSpan:new{ width = compact_empty_footer_gap })
        end
        table.insert(content, VerticalSpan:new{ width = compact_empty_footer_h })
    end

    return M.makeFullscreenFrame(content, layout)
end

function M.makeFullscreenFooter(width, content, with_divider)
    local footer = VerticalGroup:new{ align = "center" }
    if with_divider ~= false then
        table.insert(footer, M.makeTarotDivider(width))
        table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
    end
    if content then table.insert(footer, content) end
    return footer
end

function M.addHorizontalSwipeNavigation(widget, zone_id, previous_callback, next_callback)
    if not widget or type(widget.registerTouchZones) ~= "function" then return end
    if not previous_callback and not next_callback then return end

    widget:registerTouchZones({
        {
            id = zone_id or "tarot_horizontal_swipe_nav",
            ges = "swipe",
            screen_zone = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 },
            handler = function(ges)
                local direction = ges and ges.direction
                if direction == "west" or direction == "left" then
                    if next_callback then
                        next_callback()
                        return true
                    end
                elseif direction == "east" or direction == "right" then
                    if previous_callback then
                        previous_callback()
                        return true
                    end
                end
                return false
            end,
        },
    })
end

function M.getTarotBaseButtonRadius()
    if Size.radius then
        return Size.radius.button or Size.radius.default or Size.radius.window or 8
    end
    return 8
end

function M.getTarotButtonRadius()
    local base = M.getTarotBaseButtonRadius()
    local screen_h = Screen and Screen.getHeight and Screen:getHeight() or 0
    local responsive = screen_h > 0 and math.floor(screen_h * 0.018) or base
    if responsive < base then responsive = base end
    if responsive > 30 then responsive = 30 end
    return responsive
end

function M.getTopIconMetrics(layout, spec)
    layout = layout or M.getFullscreenLayout()
    spec = spec or {}

    local safe_h = tonumber(layout.safe_h) or Screen:getHeight()
    local safe_w = tonumber(layout.safe_w) or Screen:getWidth()
    local outer_pad = tonumber(layout.outer_pad) or Size.padding.default

    -- Kindle Basic 2022 usa tela de alta densidade: 27px ficava visivelmente
    -- pequeno demais. Mantemos um alvo confortável em e-ink sem ocupar o topo.
    local touch_size = spec.touch_size
        or math.floor(safe_h * 0.058)
    local max_by_width = math.floor((safe_w - outer_pad * 2) * 0.14)
    if max_by_width < 64 then max_by_width = 64 end
    if touch_size < 64 then touch_size = 64 end
    if touch_size > 88 then touch_size = 88 end
    if touch_size > max_by_width then touch_size = max_by_width end

    local icon_size = spec.icon_size
        or math.floor(touch_size * 0.70)
    if icon_size < 42 then icon_size = 42 end
    if icon_size > 62 then icon_size = 62 end

    local gap = spec.gap or math.max(6, math.floor(touch_size * 0.20))
    return {
        touch_size = touch_size,
        icon_size = icon_size,
        gap = gap,
    }
end

function M.makeSettingsCard(title, body, width)
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
        radius     = M.getTarotBaseButtonRadius(),
        padding    = Size.padding.default,
        inner,
    }
end

function M.makeRoundedButton(spec)
    spec = spec or {}
    return Button:new{
        text             = spec.text,
        width            = spec.width,
        height           = spec.height,
        radius           = spec.radius or M.getTarotButtonRadius(),
        bordersize       = spec.bordersize ~= nil and spec.bordersize or 1,
        enabled          = spec.enabled,
        align            = spec.align,
        margin           = spec.margin,
        padding          = spec.padding,
        padding_h        = spec.padding_h,
        padding_v        = spec.padding_v,
        text_font_face   = spec.text_font_face,
        text_font_size   = spec.text_font_size,
        text_font_bold   = spec.text_font_bold,
        font_face        = spec.font_face,
        is_enter_default = spec.is_enter_default,
        callback         = spec.callback,
        hold_callback    = spec.hold_callback,
    }
end

function M.makeTransparentTextButton(spec)
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

function M.getTarotRefreshType(owner, fallback_type)
    local plugin = nil
    if owner then
        if owner.screen_refresh_mode then
            plugin = owner
        elseif owner.plugin and owner.plugin.screen_refresh_mode then
            plugin = owner.plugin
        end
    end

    local mode = plugin and plugin.screen_refresh_mode or "smooth"
    if mode == "smooth" then
        return "partial"
    elseif mode == "clean" then
        return "flashui"
    end

    return fallback_type or "full"
end

function M.setTarotDirty(owner, fallback_type, widget, refreshregion, refreshdither)
    local ok, err = pcall(function()
        UIManager:setDirty(widget or nil, M.getTarotRefreshType(owner, fallback_type), refreshregion, refreshdither)
    end)
    if not ok then
        logger.warn("tarot.koplugin: falha ao atualizar a tela:", tostring(err))
    end
end

function M.safeFileMode(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local ok, mode = pcall(lfs.attributes, path, "mode")
    if ok then
        return mode
    end
    logger.warn("tarot.koplugin: falha ao ler atributo de arquivo:", tostring(path), tostring(mode))
    return nil
end

function M.isRegularFile(path)
    return M.safeFileMode(path) == "file"
end

function M.makeSafeImageWidget(spec)
    spec = spec or {}
    if not M.isRegularFile(spec.file) then
        return nil
    end
    local ok, widget = pcall(function()
        return ImageWidget:new(spec)
    end)
    if ok and widget then
        return widget
    end
    logger.warn("tarot.koplugin: falha ao carregar imagem:", tostring(spec.file), tostring(widget))
    return nil
end

function M.runTarotCallback(callback, context)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback)
    if not ok then
        logger.warn("tarot.koplugin: erro em ação de interface:", tostring(context), tostring(err))
    end
end

return M

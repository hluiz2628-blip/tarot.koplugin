-- ── dependências ──────────────────────────────────────────────────────────────
local Blitbuffer       = require("ffi/blitbuffer")
local Button           = require("ui/widget/button")
local ButtonDialog     = require("ui/widget/buttondialog")
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
local OverlapGroup     = require("ui/widget/overlapgroup")
local ReaderUI         = require("apps/reader/readerui")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
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
        elseif language:match("^zh") then
            return "均衡"
        end
    end
    return nil
end

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


-- Esqueleto padrão para telas fullscreen do plugin. Ele imita a organização
-- usada em Hidden Cards: título fixo no topo, conteúdo respirando no centro e
-- ações principais no rodapé. O cálculo usa a área segura do KOReader para
-- continuar funcionando em Kindle Basic 2022, janelas pequenas de desktop,
-- Android e outros e-ink sem empurrar botões para fora da tela.
local function makeFullscreenScaffold(spec)
    spec = spec or {}
    local layout = spec.layout or getFullscreenLayout(spec.content_factor)
    local iw = spec.width or layout.content_w
    local header = spec.header
    if not header and spec.title and spec.title ~= "" then
        header = makeSectionHeader(spec.title, iw, spec.subtitle)
    end

    local body = spec.body or VerticalGroup:new{ align = "center" }
    local footer = spec.footer
    local header_gap = header and (spec.header_gap or Size.span.vertical_default) or 0
    local footer_gap = footer and (spec.footer_gap or Size.span.vertical_default) or 0
    local header_h = header and header:getSize().h or 0
    local footer_h = footer and footer:getSize().h or 0
    local body_h = layout.safe_h - header_h - footer_h - header_gap - footer_gap
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
    end

    return makeFullscreenFrame(content, layout)
end

-- Rodapé padrão: divisor discreto + ações textuais/botões. Mantém o mesmo
-- lugar visual para Voltar, Fechar, Salvar e paginação em todas as telas.
local function makeFullscreenFooter(width, content, with_divider)
    local footer = VerticalGroup:new{ align = "center" }
    if with_divider ~= false then
        table.insert(footer, makeTarotDivider(width))
        table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
    end
    if content then table.insert(footer, content) end
    return footer
end

-- Raio seguro para botões. Alguns builds/dispositivos podem não preencher
-- `Size.radius.button`; nesse caso, usamos fallbacks conhecidos antes de cair
-- em um valor fixo pequeno. Isso evita botões quadrados no Kindle.
local function getTarotBaseButtonRadius()
    if Size.radius then
        return Size.radius.button or Size.radius.default or Size.radius.window or 8
    end
    return 8
end

-- Estilo principal dos botões do plugin. Usa o mesmo arredondamento reforçado
-- que ficou visualmente melhor na Home, mas com limite superior para não virar
-- “pílula gigante” em janelas muito altas no desktop.
local function getTarotButtonRadius()
    local base = getTarotBaseButtonRadius()
    local screen_h = Screen and Screen.getHeight and Screen:getHeight() or 0
    local responsive = screen_h > 0 and math.floor(screen_h * 0.018) or base
    if responsive < base then responsive = base end
    if responsive > 30 then responsive = 30 end
    return responsive
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
        radius     = getTarotBaseButtonRadius(),
        padding    = Size.padding.default,
        inner,
    }
end

-- Botão principal com cantos arredondados. É o estilo usado nos botões da
-- Home e reaproveitado nos demais menus. Botões textuais/sem borda continuam
-- usando makeTransparentTextButton, para preservar rodapés e links discretos.
local function makeRoundedButton(spec)
    spec = spec or {}
    return Button:new{
        text             = spec.text,
        width            = spec.width,
        height           = spec.height,
        radius           = spec.radius or getTarotButtonRadius(),
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


-- Mapeia a preferência do plugin para o modo de atualização do KOReader.
-- "full" preserva o comportamento antigo; "partial" reduz piscadas; "flashui"
-- força uma limpeza visual mais forte para quem prefere menos ghosting.
local function getTarotRefreshType(owner, fallback_type)
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

local function setTarotDirty(owner, fallback_type, widget, refreshregion, refreshdither)
    UIManager:setDirty(widget or nil, getTarotRefreshType(owner, fallback_type), refreshregion, refreshdither)
end

-- Estilo responsivo da lista do Baralho Físico. A fonte e o espaçamento
-- diminuem levemente em janelas baixas, permitindo mais linhas sem esconder
-- o rodapé; em telas altas, mantemos a leitura confortável.
local function getPhysicalDeckListStyle(layout)
    local sh = layout and layout.screen_h or Screen:getHeight()
    if sh < 720 then
        return { font_size = 16, padding_v = Size.padding.tiny, max_items = 10, min_items = 3 }
    elseif sh < 950 then
        return { font_size = 18, padding_v = Size.padding.small, max_items = 12, min_items = 4 }
    elseif sh < 1200 then
        return { font_size = 20, padding_v = Size.padding.small, max_items = 15, min_items = 5 }
    end
    return { font_size = 20, padding_v = Size.padding.small, max_items = 20, min_items = 6 }
end

-- Calcula quantas cartas cabem na página do Baralho Físico usando a altura
-- realmente restante entre cabeçalho e rodapé. Isso substitui os antigos
-- valores fixos e adapta melhor Kindle Basic 2022, desktop redimensionado e
-- celulares com barras de navegação.
local function getAdaptivePhysicalDeckItemsPerPage(layout, header_widget, style)
    style = style or getPhysicalDeckListStyle(layout)
    local iw = layout.content_w

    local sample_row = Button:new{
        text = "☑ 16  78. " .. T("Eight of Pentacles") .. " — " .. T(UI_TEXT.reversed),
        width = iw,
        bordersize = 0,
        radius = 0,
        align = "left",
        text_font_face = "smallinfofont",
        text_font_size = style.font_size,
        text_font_bold = false,
        padding_h = Size.padding.default,
        padding_v = style.padding_v,
        callback = function() end,
    }

    local sample_footer = makeFullscreenFooter(iw, VerticalGroup:new{
        align = "center",
        HorizontalGroup:new{
            align = "center",
            makeTransparentTextButton{ text = "<", width = math.floor(iw * 0.22), enabled = false },
            TextWidget:new{
                text = "999 / 999",
                face = Font:getFace("x_smallinfofont"),
                max_width = math.floor(iw * 0.44),
                alignment = "center",
            },
            makeTransparentTextButton{ text = ">", width = math.floor(iw * 0.22), enabled = false },
        },
        VerticalSpan:new{ width = Size.span.vertical_small },
        HorizontalGroup:new{
            align = "center",
            makeTransparentTextButton{ text = T(UI_TEXT.back), width = math.floor(iw * 0.38) },
            HorizontalSpan:new{ width = math.floor(iw * 0.08) },
            makeTransparentTextButton{ text = T(UI_TEXT.done), width = math.floor(iw * 0.38) },
        },
    })

    local header_h = header_widget and header_widget:getSize().h or 0
    local footer_h = sample_footer:getSize().h
    local vertical_gaps = Size.span.vertical_default * 2
    local available_h = layout.safe_h - header_h - footer_h - vertical_gaps
    local row_h = math.max(1, sample_row:getSize().h)
    local count = math.floor(available_h / row_h)

    if count < style.min_items then count = style.min_items end
    if count > style.max_items then count = style.max_items end
    return count
end

-- Menu simples em fullscreen, usado para substituir ButtonDialog nos fluxos
-- de navegação do plugin. Caixas de texto continuam como InputDialog para
-- preservar o teclado e o comportamento nativo do KOReader.
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

    local function makeMenuButton(spec, width, button_dialog, is_footer)
        local button_spec = spec
        local callback = function()
            -- Em telas fullscreen, o próprio menu deve saber se precisa fechar
            -- antes/depois da ação. Isso evita callbacks presos a variáveis
            -- externas de diálogos antigos, causa comum de botões sem efeito.
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
            appendRows(body, { row }, false)
        end
    end

    local footer
    if #footer_rows > 0 then
        local footer_content = VerticalGroup:new{ align = "center" }
        appendRows(footer_content, footer_rows, true)
        footer = makeFullscreenFooter(iw, footer_content)
    end

    self[1] = makeFullscreenScaffold{
        layout = layout,
        title = self.title,
        body = body,
        footer = footer,
    }
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
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

    -- Recarrega o catálogo ao abrir o plugin. Isso cobre o caso em que o
    -- usuário troca o idioma do KOReader e reabre o plugin na mesma sessão.
    if type(T.reload) == "function" then
        T.reload()
        self.fullname = T(UI_TEXT.title)
    end

    self.ui.menu:registerToMainMenu(self)
    self.plugin_dir = self:getPluginDirectory()
    self.saves_dir = self.plugin_dir .. "/tiragens_salvas"
    self.journal_dir = self.plugin_dir .. "/diario_reflexoes"
    self.journal_trash_dir = self.journal_dir .. "/lixeira"
    self.journal_export_dir = self.journal_dir .. "/exportacoes"
    self.journal_backup_dir = self.journal_dir .. "/backups"
    -- Significados pessoais adicionados a partir de grifos ficam em um único
    -- arquivo simples na raiz do plugin. Assim evitamos criar mais pastas e
    -- mantemos a instalação fácil de copiar no Kindle.
    self.custom_meanings_path = self.plugin_dir .. "/significados_cartas.trcm"
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

    self.hide_daily_card_name = G_reader_settings:readSetting("tarot_hide_daily_card_name")
    if self.hide_daily_card_name == nil then
        -- Em inglês, o nome pode aparecer diretamente na própria arte da carta.
        -- Por isso, instalações novas em inglês ocultam o rótulo por padrão.
        self.hide_daily_card_name = isPluginLanguageEnglish()
    end

    self.daily_card_always_revealed = G_reader_settings:readSetting("tarot_daily_card_always_revealed")
    if self.daily_card_always_revealed == nil then
        self.daily_card_always_revealed = false
    end

    self.spread_cards_always_revealed = G_reader_settings:readSetting("tarot_spread_cards_always_revealed")
    if self.spread_cards_always_revealed == nil then
        self.spread_cards_always_revealed = false
    end

    self.show_only_custom_meanings = G_reader_settings:readSetting("tarot_show_only_custom_meanings")
    if self.show_only_custom_meanings == nil then
        self.show_only_custom_meanings = false
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

    self.screen_refresh_mode = G_reader_settings:readSetting("tarot_screen_refresh_mode")
    if self.screen_refresh_mode ~= "standard"
        and self.screen_refresh_mode ~= "smooth"
        and self.screen_refresh_mode ~= "clean" then
        self.screen_refresh_mode = "smooth"
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
    self.hidden_grid_hint_v2_shown_this_session = false
    self.next_card_reveal_hint_shown_this_session = false
    
    self:ensureSavesDir()
    self:ensureJournalDirs()

    -- Integra o plugin ao menu de seleção/grifo do leitor quando esse módulo
    -- estiver disponível. Em alguns ciclos de inicialização, o ReaderHighlight
    -- ainda pode não estar pronto; nesse caso tentamos novamente no pós-init.
    if not self:registerHighlightMeaningAction()
        and self.ui
        and type(self.ui.registerPostInitCallback) == "function" then
        self.ui:registerPostInitCallback(function()
            self:registerHighlightMeaningAction()
        end)
    end
end

function TarotPlugin:getTranslation(key)
    local msgid = UI_TEXT[key]
    if not msgid then
        logger.warn("tarot.koplugin: chave de tradução desconhecida:", tostring(key))
        return tostring(key)
    end
    local translated = T(msgid)
    if translated == msgid then
        local fallback = getTranslatedFallback(key)
        if fallback then
            return fallback
        end
    end
    return translated
end

-- Nomes predefinidos são salvos por identificador, e não pelo texto já
-- traduzido. Assim, uma tiragem criada em português continua correta caso o
-- idioma do KOReader seja alterado depois.
local POSITION_NAME_PRESETS = {
    { id = "past",      key = "position_past" },
    { id = "present",   key = "position_present" },
    { id = "future",    key = "position_future" },
    { id = "situation", key = "position_situation" },
    { id = "obstacle",  key = "position_obstacle" },
    { id = "advice",    key = "position_advice" },
    { id = "outcome",   key = "position_outcome" },
}

local POSITION_NAME_KEYS = {}
for _, preset in ipairs(POSITION_NAME_PRESETS) do
    POSITION_NAME_KEYS[preset.id] = preset.key
end

local function trimPositionName(text)
    text = tostring(text or "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function makeStoredPresetPositionName(id)
    return "preset:" .. tostring(id or "")
end

local function makeStoredCustomPositionName(text)
    return "custom:" .. trimPositionName(text)
end

local function getPositionNameDisplay(plugin, stored_name)
    stored_name = trimPositionName(stored_name)
    if stored_name == "" then return "" end

    local preset_id = stored_name:match("^preset:(.+)$")
    if preset_id and POSITION_NAME_KEYS[preset_id] then
        return plugin:getTranslation(POSITION_NAME_KEYS[preset_id])
    end

    local custom_name = stored_name:match("^custom:(.*)$")
    if custom_name ~= nil then
        return trimPositionName(custom_name)
    end

    -- Compatibilidade com eventuais versões de teste que tenham salvo texto
    -- simples antes da adoção dos prefixos preset:/custom:.
    return stored_name
end

function TarotPlugin:refreshMenu()
    self.ui.menu:registerToMainMenu(self)
end

function TarotPlugin:getPluginDirectory()
    if self.path then return self.path end
    if PLUGIN_DIR then return PLUGIN_DIR end
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
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:toggleMajorOnly()
    self.major_only = not self.major_only
    G_reader_settings:saveSetting("tarot_major_only", self.major_only)
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:setReadingDeck(use_lenormand)
    self.use_lenormand = use_lenormand == true
    G_reader_settings:saveSetting("tarot_use_lenormand", self.use_lenormand)
    setTarotDirty(self.plugin or self)
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
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:setHideDailyCardName(hide_name)
    self.hide_daily_card_name = hide_name == true
    G_reader_settings:saveSetting("tarot_hide_daily_card_name", self.hide_daily_card_name)
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:toggleHideDailyCardName()
    self:setHideDailyCardName(not self.hide_daily_card_name)
end

function TarotPlugin:toggleDailyCardAlwaysRevealed()
    self.daily_card_always_revealed = not self.daily_card_always_revealed
    G_reader_settings:saveSetting(
        "tarot_daily_card_always_revealed",
        self.daily_card_always_revealed
    )
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:toggleSpreadCardsAlwaysRevealed()
    self.spread_cards_always_revealed = not self.spread_cards_always_revealed
    G_reader_settings:saveSetting(
        "tarot_spread_cards_always_revealed",
        self.spread_cards_always_revealed
    )
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:toggleShowOnlyCustomMeanings()
    self.show_only_custom_meanings = not self.show_only_custom_meanings
    G_reader_settings:saveSetting(
        "tarot_show_only_custom_meanings",
        self.show_only_custom_meanings
    )
    setTarotDirty(self.plugin or self)
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
    setTarotDirty(self.plugin or self)
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
    setTarotDirty(self)
end

function TarotPlugin:setScreenRefreshMode(mode)
    if mode ~= "standard" and mode ~= "smooth" and mode ~= "clean" then
        return
    end
    self.screen_refresh_mode = mode
    G_reader_settings:saveSetting("tarot_screen_refresh_mode", mode)
    setTarotDirty(self)
end

function TarotPlugin:toggleShowReversedLabel()
    self.show_reversed_label = not self.show_reversed_label
    G_reader_settings:saveSetting("tarot_show_reversed_label", self.show_reversed_label)
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:toggleAutoSaveSpreads()
    self.auto_save_spreads = not self.auto_save_spreads
    G_reader_settings:saveSetting("tarot_auto_save_spreads", self.auto_save_spreads)
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:toggleUnsavedCloseWarning()
    self.disable_unsaved_close_warning = not self.disable_unsaved_close_warning
    G_reader_settings:saveSetting(
        "tarot_disable_unsaved_close_warning",
        self.disable_unsaved_close_warning
    )
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:toggleViewInBookButton()
    self.disable_view_in_book = not self.disable_view_in_book
    G_reader_settings:saveSetting("tarot_disable_view_in_book", self.disable_view_in_book)
    setTarotDirty(self.plugin or self)
end

-- Exibe uma orientação com caixa de seleção e um único botão "Confirmar".
-- A preferência só é gravada quando o usuário marca explicitamente
-- "Não mostrar novamente" antes de confirmar.
--
-- Quando session_field é informado, cada orientação aparece apenas uma vez
-- por abertura do plugin. Quando session_field é nil, o aviso reaparece em
-- novas entradas até que o usuário marque “Não mostrar novamente”.
function TarotPlugin:showDismissibleHint(setting_key, session_field, message_key, after_close_callback)
    local function runAfterClose()
        if type(after_close_callback) == "function" then
            UIManager:scheduleIn(0.1, after_close_callback)
        end
    end

    if G_reader_settings:readSetting(setting_key) == true then
        runAfterClose()
        return
    end
    if session_field and self[session_field] == true then
        runAfterClose()
        return
    end

    if session_field then
        self[session_field] = true
    end

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
            runAfterClose()
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
        "tarot_hidden_grid_hint_v2_dismissed",
        "hidden_grid_hint_v2_shown_this_session",
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

function TarotPlugin:showCustomMeaningEditorHint(after_close_callback)
    -- Este aviso é chamado quando o usuário entra no editor manual de
    -- significados. Diferente dos avisos de uso da grade, ele NÃO deve ser
    -- limitado a uma única vez por sessão: se o usuário não marcar
    -- "Não mostrar novamente", precisa aparecer novamente na próxima entrada.
    self:showDismissibleHint(
        "tarot_custom_meaning_editor_hint_dismissed",
        nil,
        "custom_meaning_editor_hint",
        after_close_callback
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
        "tarot_hide_daily_card_name",
        "tarot_daily_card_always_revealed",
        "tarot_daily_deck_choice_date",
        "tarot_daily_deck_choice_is_lenormand",
        "tarot_disable_spread_meanings",
        "tarot_spread_meaning_mode",
        "tarot_disable_view_in_book",
        "tarot_spread_cards_always_revealed",
        "tarot_show_only_custom_meanings",
        "tarot_auto_save_spreads",
        "tarot_disable_unsaved_close_warning",
        "tarot_show_reversed_label",
        "tarot_meaning_text_size",
        "tarot_screen_refresh_mode",
        "tarot_hidden_card",
        "tarot_physical_deck_reverse_hint_seen",
        "tarot_physical_deck_reverse_hint_dismissed",
        "tarot_card_dialog_navigation_hint_dismissed",
        "tarot_hidden_card_reveal_hint_dismissed",
        "tarot_hidden_grid_hint_v2_dismissed",
        "tarot_next_card_reveal_hint_dismissed",
        "tarot_custom_meaning_editor_hint_dismissed",
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

    -- Apaga por completo os diretórios e arquivos gerados pelo plugin. Isso
    -- inclui registros antigos e novos, lixeira, exportações, backups e os
    -- Significados Pessoais criados por grifos ou pelo editor manual.
    local ok = true
    if self.saves_dir and not self:clearDirectoryRecursive(self.saves_dir, false) then
        ok = false
    end
    if self.journal_dir and not self:clearDirectoryRecursive(self.journal_dir, false) then
        ok = false
    end
    local custom_attr = self.custom_meanings_path and lfs.attributes(self.custom_meanings_path)
    if custom_attr then
        if custom_attr.mode == "directory" then
            if not self:clearDirectoryRecursive(self.custom_meanings_path, false) then
                ok = false
            end
        elseif not os.remove(self.custom_meanings_path) then
            ok = false
        end
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
    if self.custom_meanings_path and lfs.attributes(self.custom_meanings_path) then
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
    self.hide_daily_card_name = isPluginLanguageEnglish()
    self.daily_card_always_revealed = false
    self.spread_cards_always_revealed = false
    self.show_only_custom_meanings = false
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
    self.hidden_grid_hint_v2_shown_this_session = false
    self.next_card_reveal_hint_shown_this_session = false
    self.screen_refresh_mode = "smooth"

    -- Descarta referências a telas e estados antigos para impedir que uma tela
    -- já aberta reapresente dados apagados depois da restauração.
    self.journal_dialog = nil
    self.journal_filter_dialog = nil
    self.journal_more_dialog = nil
    self.journal_edit_menu = nil
    self.journal_trash_dialog = nil
    self.journal_backup_dialog = nil

    setTarotDirty(self.plugin or self)
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

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║      SEÇÃO 7.1: SIGNIFICADOS PESSOAIS A PARTIR DE GRIFOS                    ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- O arquivo fica fora de l10n porque não é tradução: é conteúdo pessoal do
-- usuário. Cada linha é independente, escapada e tolerante a caracteres UTF-8.
local CUSTOM_MEANINGS_MAGIC = "TAROT_CUSTOM_MEANINGS_V1"

local function getDeckStorageId(deck_is_lenormand)
    return deck_is_lenormand and "lenormand" or "tarot"
end

local function normalizeMeaningOrientation(orientation, deck_is_lenormand)
    if deck_is_lenormand then return "upright" end
    return orientation == "reversed" and "reversed" or "upright"
end

local function titleCaseAsciiWord(word)
    return word:gsub("^%l", string.upper)
end

local function normalizeCustomMeaningSourceTitle(title)
    title = journalTrim(tostring(title or ""):gsub("%z", ""))
    if title == "" then return "" end

    -- Quando o KOReader entrega caminho/arquivo em vez de metadado de título,
    -- exibimos uma fonte humana: "nome_exemplo.epub" vira "Nome Exemplo".
    title = title:match("([^/\\]+)$") or title
    title = title:gsub("%.[A-Za-z0-9]+$", "")
    title = title:gsub("[_%-]+", " ")
    title = title:gsub("%s+", " ")
    title = journalTrim(title)

    -- Se o texto veio todo em minúsculas/slug, aplicamos título simples. Não
    -- tentamos normalização Unicode pesada para não depender de libs extras.
    if not title:find("%u") then
        title = title:gsub("(%S+)", titleCaseAsciiWord)
    end
    return title
end

local function normalizeCustomMeaningAuthorName(author)
    if type(author) == "table" then
        local parts = {}
        for _, value in ipairs(author) do
            value = journalTrim(tostring(value or ""))
            if value ~= "" then
                table.insert(parts, value)
            end
        end
        author = table.concat(parts, ", ")
    end

    author = journalTrim(tostring(author or ""):gsub("%z", ""))
    author = author:gsub("%s+", " ")
    return journalTrim(author)
end

local function formatCustomMeaningSourceTitle(title, author)
    title = normalizeCustomMeaningSourceTitle(title)
    author = normalizeCustomMeaningAuthorName(author)

    if title == "" then
        return ""
    end
    if author == "" or journalSafeLower(author) == journalSafeLower(title) then
        return title
    end

    -- Exibição pedida: "Nome do Livro, Autor".
    return title .. ", " .. author
end

function TarotPlugin:getCurrentBookTitleForMeaning()
    local title = nil
    local author = nil
    local document = self.ui and self.ui.document
    if document and type(document) == "table" then
        if document.info and type(document.info) == "table" then
            title = document.info.title or document.info.doc_title or document.info.name
            author = document.info.author or document.info.authors
                or document.info.creator or document.info.creators
        end
        title = title or document.title or document.file or document.filename
        author = author or document.author or document.authors
    end

    if (not title or title == "") and self.ui then
        title = self.ui.document_title or self.ui.filename
    end

    title = formatCustomMeaningSourceTitle(title, author)
    if title == "" then
        return self:getTranslation("unknown_book")
    end
    return title
end

function TarotPlugin:cleanHighlightMeaningText(selected_text)
    if type(selected_text) == "table" then
        selected_text = selected_text.text or selected_text[1] or ""
    end
    selected_text = tostring(selected_text or "")
    if util and type(util.cleanupSelectedText) == "function" then
        selected_text = util.cleanupSelectedText(selected_text)
    end
    selected_text = journalTrim(selected_text:gsub("%z", ""))
    return selected_text
end

function TarotPlugin:readCustomMeanings()
    local path = self.custom_meanings_path or (self:getPluginDirectory() .. "/significados_cartas.trcm")
    local content = journalReadAll(path)
    if not content or content:sub(1, #CUSTOM_MEANINGS_MAGIC) ~= CUSTOM_MEANINGS_MAGIC then
        return {}
    end

    local entries = {}
    local entry_index = 0
    for line in content:gmatch("[^\n]+") do
        local payload = line:match("^entry=(.*)$")
        if payload then
            local deck, card_id, orientation, created_at, source_title, text = payload:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
            card_id = tonumber(card_id)
            if deck and card_id and orientation and text then
                entry_index = entry_index + 1
                table.insert(entries, {
                    index = entry_index,
                    deck = journalUnescape(deck),
                    card_id = card_id,
                    orientation = normalizeMeaningOrientation(journalUnescape(orientation), deck == "lenormand"),
                    created_at = tonumber(journalUnescape(created_at)) or 0,
                    source_title = normalizeCustomMeaningSourceTitle(journalUnescape(source_title or "")),
                    text = journalUnescape(text or ""),
                })
            end
        end
    end
    return entries
end

function TarotPlugin:getCustomMeaningsForCard(card, deck_is_lenormand, orientation)
    local wanted_deck = getDeckStorageId(deck_is_lenormand)
    local wanted_id = card and tonumber(card.id)
    local wanted_orientation = normalizeMeaningOrientation(orientation, deck_is_lenormand)
    local result = {}

    if not wanted_id then return result end

    for _, entry in ipairs(self:readCustomMeanings()) do
        if entry.deck == wanted_deck
            and tonumber(entry.card_id) == wanted_id
            and entry.orientation == wanted_orientation
            and journalTrim(entry.text) ~= "" then
            table.insert(result, entry)
        end
    end

    return result
end

function TarotPlugin:appendCustomMeaning(card, deck_is_lenormand, orientation, text, source_title)
    text = self:cleanHighlightMeaningText(text)
    if text == "" then
        UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_empty") })
        return false
    end

    local id = card and tonumber(card.id)
    if not id then return false end

    local path = self.custom_meanings_path or (self:getPluginDirectory() .. "/significados_cartas.trcm")
    local existing = journalReadAll(path)
    if not existing or existing:sub(1, #CUSTOM_MEANINGS_MAGIC) ~= CUSTOM_MEANINGS_MAGIC then
        existing = CUSTOM_MEANINGS_MAGIC .. "\n"
    end

    local line = table.concat({
        journalEscape(getDeckStorageId(deck_is_lenormand)),
        journalEscape(tostring(id)),
        journalEscape(normalizeMeaningOrientation(orientation, deck_is_lenormand)),
        journalEscape(tostring(os.time())),
        journalEscape(normalizeCustomMeaningSourceTitle(source_title or self:getCurrentBookTitleForMeaning())),
        journalEscape(text),
    }, "|")

    local ok, err = journalWriteAll(path, existing .. "entry=" .. line .. "\n")
    if not ok then
        logger.warn("tarot.koplugin: erro ao salvar significado pessoal:", err)
        UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_error") })
        return false
    end

    UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_saved") })
    return true
end

function TarotPlugin:registerHighlightMeaningAction()
    if self._tarot_highlight_meaning_registered then
        return true
    end

    local highlight = self.ui and self.ui.highlight
    if not highlight or type(highlight.addToHighlightDialog) ~= "function" then
        return false
    end

    local plugin = self
    highlight:addToHighlightDialog("04a_tarot_add_meaning", function(reader_highlight)
        local selected_text = plugin:cleanHighlightMeaningText(reader_highlight and reader_highlight.selected_text)
        return {
            text = plugin:getTranslation("add_highlight_to_card_meaning"),
            enabled = selected_text ~= "",
            callback = function()
                selected_text = plugin:cleanHighlightMeaningText(reader_highlight and reader_highlight.selected_text)
                if selected_text == "" then
                    UIManager:show(InfoMessage:new{ text = plugin:getTranslation("highlight_meaning_empty") })
                    return
                end

                if reader_highlight and type(reader_highlight.onClose) == "function" then
                    reader_highlight:onClose(true)
                end

                UIManager:scheduleIn(0.1, function()
                    plugin:showHighlightMeaningDeckMenu(selected_text)
                end)
            end,
        }
    end)

    self._tarot_highlight_meaning_registered = true
    return true
end

function TarotPlugin:showHighlightMeaningDeckMenu(selected_text)
    local buttons = {
        {{ label = true, text = self:getTranslation("choose_deck") }},
        {{ text = self:getTranslation("tarot_deck"), close_before = true, callback = function()
            self:showHighlightMeaningCardSelect(selected_text, false, 1)
        end }},
        {{ text = self:getTranslation("lenormand_deck"), close_before = true, callback = function()
            self:showHighlightMeaningCardSelect(selected_text, true, 1)
        end }},
        {{ text = self:getTranslation("cancel"), footer = true, close_before = true }},
    }

    UIManager:show(FullscreenMenuDialog:new{
        plugin = self,
        title = self:getTranslation("highlight_meaning_title"),
        buttons = buttons,
    })
    setTarotDirty(self)
end

function TarotPlugin:showHighlightMeaningCardSelect(selected_text, deck_is_lenormand, page)
    local deck = deck_is_lenormand and LENORMAND_DECK or FULL_DECK
    local per_page = 9
    local page_count = math.max(1, math.ceil(#deck / per_page))
    page = tonumber(page) or 1
    if page < 1 then page = 1 end
    if page > page_count then page = page_count end

    local buttons = {
        {{ label = true, text = string.format(self:getTranslation("page_count"), page, page_count) }},
    }

    local start_index = (page - 1) * per_page + 1
    local end_index = math.min(#deck, start_index + per_page - 1)
    for index = start_index, end_index do
        local card = deck[index]
        local prefix = deck_is_lenormand and string.format("%02d. ", index) or ""
        table.insert(buttons, {{
            text = prefix .. T(card.name),
            close_before = true,
            callback = function()
                if deck_is_lenormand then
                    if self:appendCustomMeaning(card, true, "upright", selected_text) then
                        self:showCardInBook(card, true)
                    end
                else
                    self:showHighlightMeaningOrientationMenu(selected_text, card)
                end
            end,
        }})
    end

    local footer_row = {}
    table.insert(footer_row, {
        text = self:getTranslation("prev"),
        footer = true,
        enabled = page > 1,
        close_before = true,
        callback = function()
            self:showHighlightMeaningCardSelect(selected_text, deck_is_lenormand, page - 1)
        end,
    })
    table.insert(footer_row, {
        text = self:getTranslation("next"),
        footer = true,
        enabled = page < page_count,
        close_before = true,
        callback = function()
            self:showHighlightMeaningCardSelect(selected_text, deck_is_lenormand, page + 1)
        end,
    })
    table.insert(buttons, footer_row)
    table.insert(buttons, {{
        text = self:getTranslation("back"),
        footer = true,
        close_before = true,
        callback = function()
            self:showHighlightMeaningDeckMenu(selected_text)
        end,
    }})

    UIManager:show(FullscreenMenuDialog:new{
        plugin = self,
        title = deck_is_lenormand and self:getTranslation("choose_lenormand_card") or self:getTranslation("choose_tarot_card"),
        buttons = buttons,
    })
    setTarotDirty(self)
end

function TarotPlugin:showHighlightMeaningOrientationMenu(selected_text, card)
    local buttons = {
        {{ label = true, text = T(card.name) }},
        {{ text = self:getTranslation("upright_meaning_choice"), close_before = true, callback = function()
            if self:appendCustomMeaning(card, false, "upright", selected_text) then
                self:showCardInBook(card, false)
            end
        end }},
        {{ text = self:getTranslation("reversed_meaning_choice"), close_before = true, callback = function()
            if self:appendCustomMeaning(card, false, "reversed", selected_text) then
                self:showCardInBook(card, false)
            end
        end }},
        {{ text = self:getTranslation("back"), footer = true, close_before = true, callback = function()
            self:showHighlightMeaningCardSelect(selected_text, false, 1)
        end }},
    }

    UIManager:show(FullscreenMenuDialog:new{
        plugin = self,
        title = self:getTranslation("choose_orientation"),
        buttons = buttons,
    })
    setTarotDirty(self)
end

function TarotPlugin:formatCustomMeaningEntries(entries, show_source)
    local lines = {}
    for _, entry in ipairs(entries or {}) do
        local source = normalizeCustomMeaningSourceTitle(entry.source_title or "")
        if show_source and source ~= "" then
            table.insert(lines, string.format(
                '%s: "%s"',
                self:getTranslation("highlight_source_label"),
                source
            ))
        end
        table.insert(lines, journalTrim(entry.text))
        table.insert(lines, "")
    end
    return journalTrim(table.concat(lines, "\n"))
end


function TarotPlugin:cleanCustomMeaningEditorText(text)
    text = tostring(text or ""):gsub("%z", "")
    return journalTrim(text)
end

function TarotPlugin:writeCustomMeanings(entries)
    local path = self.custom_meanings_path or (self:getPluginDirectory() .. "/significados_cartas.trcm")
    local lines = { CUSTOM_MEANINGS_MAGIC }

    for _, entry in ipairs(entries or {}) do
        local deck = entry.deck == "lenormand" and "lenormand" or "tarot"
        local card_id = tonumber(entry.card_id)
        local text = self:cleanCustomMeaningEditorText(entry.text)
        if card_id and text ~= "" then
            table.insert(lines, "entry=" .. table.concat({
                journalEscape(deck),
                journalEscape(tostring(card_id)),
                journalEscape(normalizeMeaningOrientation(entry.orientation, deck == "lenormand")),
                journalEscape(tostring(tonumber(entry.created_at) or os.time())),
                journalEscape(normalizeCustomMeaningSourceTitle(entry.source_title or "")),
                journalEscape(text),
            }, "|"))
        end
    end

    local ok, err = journalWriteAll(path, table.concat(lines, "\n") .. "\n")
    if not ok then
        logger.warn("tarot.koplugin: erro ao gravar significados pessoais:", err)
        UIManager:show(InfoMessage:new{ text = self:getTranslation("journal_save_error") })
        return false
    end
    return true
end

function TarotPlugin:insertCustomMeaning(card, deck_is_lenormand, orientation, text, source_title)
    text = self:cleanCustomMeaningEditorText(text)
    if text == "" then
        UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_empty") })
        return false
    end

    local id = card and tonumber(card.id)
    if not id then return false end

    local entries = self:readCustomMeanings()
    table.insert(entries, {
        deck = getDeckStorageId(deck_is_lenormand),
        card_id = id,
        orientation = normalizeMeaningOrientation(orientation, deck_is_lenormand),
        created_at = os.time(),
        source_title = normalizeCustomMeaningSourceTitle(source_title or ""),
        text = text,
    })

    if not self:writeCustomMeanings(entries) then return false end
    UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_saved") })
    return true
end

function TarotPlugin:updateCustomMeaningByIndex(entry_index, text)
    entry_index = tonumber(entry_index)
    text = self:cleanCustomMeaningEditorText(text)
    if not entry_index then return false end
    if text == "" then
        UIManager:show(InfoMessage:new{ text = self:getTranslation("highlight_meaning_empty") })
        return false
    end

    local changed = false
    local entries = self:readCustomMeanings()
    for _, entry in ipairs(entries) do
        if tonumber(entry.index) == entry_index then
            entry.text = text
            changed = true
            break
        end
    end

    if not changed then return false end
    if not self:writeCustomMeanings(entries) then return false end
    UIManager:show(InfoMessage:new{ text = self:getTranslation("custom_meaning_updated") })
    return true
end

function TarotPlugin:removeCustomMeaningByIndex(entry_index)
    entry_index = tonumber(entry_index)
    if not entry_index then return false end

    local changed = false
    local remaining = {}
    for _, entry in ipairs(self:readCustomMeanings()) do
        if tonumber(entry.index) == entry_index then
            changed = true
        else
            table.insert(remaining, entry)
        end
    end

    if not changed then return false end
    if not self:writeCustomMeanings(remaining) then return false end
    UIManager:show(InfoMessage:new{ text = self:getTranslation("custom_meaning_removed") })
    return true
end

function TarotPlugin:getCustomMeaningByIndex(entry_index)
    entry_index = tonumber(entry_index)
    if not entry_index then return nil end
    for _, entry in ipairs(self:readCustomMeanings()) do
        if tonumber(entry.index) == entry_index then
            return entry
        end
    end
    return nil
end

function TarotPlugin:showCustomMeaningEditorStart(parent_dialog)
    -- Primeiro abre o menu real do editor (Tarot / Lenormand) e só depois
    -- exibe o aviso por cima dele. Assim o usuário já entende onde está e não
    -- vê o aviso surgir ainda sobre o Livro de Cartas.
    self:showCustomMeaningEditorDeckMenu()

    UIManager:scheduleIn(0.1, function()
        -- Fecha o Livro de Cartas somente depois que o novo menu já está na
        -- pilha da UI. Isso evita o salto visual para a Home.
        if parent_dialog then
            pcall(function() UIManager:close(parent_dialog) end)
        end
        self:showCustomMeaningEditorHint()
    end)
end

function TarotPlugin:showCustomMeaningEditorDeckMenu()
    local buttons = {
        {{ label = true, text = self:getTranslation("choose_deck") }},
        {{ text = self:getTranslation("tarot_deck"), close_before = true, callback = function()
            self:showCustomMeaningEditorCardSelect(false, 1)
        end }},
        {{ text = self:getTranslation("lenormand_deck"), close_before = true, callback = function()
            self:showCustomMeaningEditorCardSelect(true, 1)
        end }},
        {{ text = self:getTranslation("back"), footer = true, close_before = true, callback = function()
            self:showCardBook()
        end }},
    }

    UIManager:show(FullscreenMenuDialog:new{
        plugin = self,
        title = self:getTranslation("edit_custom_meanings"),
        buttons = buttons,
    })
    setTarotDirty(self)
end

function TarotPlugin:showCustomMeaningEditorCardSelect(deck_is_lenormand, page)
    local deck = deck_is_lenormand and LENORMAND_DECK or FULL_DECK
    local per_page = 9
    local page_count = math.max(1, math.ceil(#deck / per_page))
    page = tonumber(page) or 1
    if page < 1 then page = 1 end
    if page > page_count then page = page_count end

    local buttons = {
        {{ label = true, text = string.format(self:getTranslation("page_count"), page, page_count) }},
    }

    local start_index = (page - 1) * per_page + 1
    local end_index = math.min(#deck, start_index + per_page - 1)
    for index = start_index, end_index do
        local card = deck[index]
        local prefix = deck_is_lenormand and string.format("%02d. ", index) or ""
        table.insert(buttons, {{
            text = prefix .. T(card.name),
            close_before = true,
            callback = function()
                if deck_is_lenormand then
                    self:showCustomMeaningManageMenu(card, true, "upright", 1)
                else
                    self:showCustomMeaningEditorOrientationMenu(card)
                end
            end,
        }})
    end

    local footer_row = {}
    table.insert(footer_row, {
        text = self:getTranslation("prev"),
        footer = true,
        enabled = page > 1,
        close_before = true,
        callback = function()
            self:showCustomMeaningEditorCardSelect(deck_is_lenormand, page - 1)
        end,
    })
    table.insert(footer_row, {
        text = self:getTranslation("next"),
        footer = true,
        enabled = page < page_count,
        close_before = true,
        callback = function()
            self:showCustomMeaningEditorCardSelect(deck_is_lenormand, page + 1)
        end,
    })
    table.insert(buttons, footer_row)
    table.insert(buttons, {{
        text = self:getTranslation("back"),
        footer = true,
        close_before = true,
        callback = function()
            self:showCustomMeaningEditorDeckMenu()
        end,
    }})

    UIManager:show(FullscreenMenuDialog:new{
        plugin = self,
        title = deck_is_lenormand and self:getTranslation("choose_lenormand_card") or self:getTranslation("choose_tarot_card"),
        buttons = buttons,
    })
    setTarotDirty(self)
end

function TarotPlugin:showCustomMeaningEditorOrientationMenu(card)
    local buttons = {
        {{ label = true, text = T(card.name) }},
        {{ text = self:getTranslation("upright_meaning_choice"), close_before = true, callback = function()
            self:showCustomMeaningManageMenu(card, false, "upright", 1)
        end }},
        {{ text = self:getTranslation("reversed_meaning_choice"), close_before = true, callback = function()
            self:showCustomMeaningManageMenu(card, false, "reversed", 1)
        end }},
        {{ text = self:getTranslation("back"), footer = true, close_before = true, callback = function()
            self:showCustomMeaningEditorCardSelect(false, 1)
        end }},
    }

    UIManager:show(FullscreenMenuDialog:new{
        plugin = self,
        title = self:getTranslation("choose_orientation"),
        buttons = buttons,
    })
    setTarotDirty(self)
end

function TarotPlugin:showCustomMeaningInput(card, deck_is_lenormand, orientation, entry_index)
    local current_entry = entry_index and self:getCustomMeaningByIndex(entry_index) or nil
    local input_dialog
    input_dialog = InputDialog:new{
        title = current_entry and self:getTranslation("edit_custom_meaning") or self:getTranslation("add_custom_meaning"),
        input = current_entry and current_entry.text or "",
        input_hint = self:getTranslation("custom_meaning_input_hint"),
        fullscreen = true,
        condensed = true,
        allow_newline = true,
        add_nav_bar = true,
        buttons = {
            {
                {
                    text = self:getTranslation("cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                        self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1)
                    end,
                },
                {
                    text = self:getTranslation("save"),
                    is_enter_default = true,
                    callback = function()
                        local text = input_dialog:getInputText()
                        local ok
                        if current_entry then
                            ok = self:updateCustomMeaningByIndex(current_entry.index, text)
                        else
                            ok = self:insertCustomMeaning(card, deck_is_lenormand, orientation, text, "")
                        end
                        if ok then
                            UIManager:close(input_dialog)
                            self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1)
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function TarotPlugin:showCustomMeaningEntryActions(card, deck_is_lenormand, orientation, entry_index)
    local entry = self:getCustomMeaningByIndex(entry_index)
    if not entry then
        self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1)
        return
    end

    local buttons = {
        {{ label = true, text = journalPreview(entry.text, 160) }},
        {{ text = self:getTranslation("edit_custom_meaning"), close_before = true, callback = function()
            self:showCustomMeaningInput(card, deck_is_lenormand, orientation, entry.index)
        end }},
        {{ text = self:getTranslation("remove_custom_meaning"), close_before = true, callback = function()
            local confirm
            confirm = ConfirmBox:new{
                text = self:getTranslation("remove_custom_meaning_confirm"),
                ok_text = self:getTranslation("yes"),
                cancel_text = self:getTranslation("no"),
                ok_callback = function()
                    if self:removeCustomMeaningByIndex(entry.index) then
                        self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1)
                    end
                end,
                cancel_callback = function()
                    self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1)
                end,
            }
            UIManager:show(confirm)
        end }},
        {{ text = self:getTranslation("back"), footer = true, close_before = true, callback = function()
            self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, 1)
        end }},
    }

    UIManager:show(FullscreenMenuDialog:new{
        plugin = self,
        title = self:getTranslation("choose_custom_meaning"),
        buttons = buttons,
    })
    setTarotDirty(self)
end

function TarotPlugin:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, page)
    local entries = self:getCustomMeaningsForCard(card, deck_is_lenormand, orientation)
    local per_page = 5
    local page_count = math.max(1, math.ceil(math.max(1, #entries) / per_page))
    page = tonumber(page) or 1
    if page < 1 then page = 1 end
    if page > page_count then page = page_count end

    local orientation_label = deck_is_lenormand and self:getTranslation("upright")
        or (orientation == "reversed" and self:getTranslation("reversed") or self:getTranslation("upright"))
    local buttons = {
        {{ label = true, text = T(card.name) .. " — " .. orientation_label }},
        {{ text = self:getTranslation("add_custom_meaning"), close_before = true, callback = function()
            self:showCustomMeaningInput(card, deck_is_lenormand, orientation)
        end }},
    }

    if #entries == 0 then
        table.insert(buttons, {{ label = true, text = self:getTranslation("no_custom_meanings") }})
    else
        table.insert(buttons, {{ label = true, text = string.format(self:getTranslation("page_count"), page, page_count) }})
        local start_index = (page - 1) * per_page + 1
        local end_index = math.min(#entries, start_index + per_page - 1)
        for index = start_index, end_index do
            local entry = entries[index]
            table.insert(buttons, {{
                text = journalPreview(entry.text, 180),
                close_before = true,
                callback = function()
                    self:showCustomMeaningEntryActions(card, deck_is_lenormand, orientation, entry.index)
                end,
            }})
        end

        if page_count > 1 then
            table.insert(buttons, {
                {
                    text = self:getTranslation("prev"),
                    footer = true,
                    enabled = page > 1,
                    close_before = true,
                    callback = function()
                        self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, page - 1)
                    end,
                },
                {
                    text = self:getTranslation("next"),
                    footer = true,
                    enabled = page < page_count,
                    close_before = true,
                    callback = function()
                        self:showCustomMeaningManageMenu(card, deck_is_lenormand, orientation, page + 1)
                    end,
                },
            })
        end
    end

    table.insert(buttons, {{
        text = self:getTranslation("back"),
        footer = true,
        close_before = true,
        callback = function()
            if deck_is_lenormand then
                self:showCustomMeaningEditorCardSelect(true, 1)
            else
                self:showCustomMeaningEditorOrientationMenu(card)
            end
        end,
    }})

    UIManager:show(FullscreenMenuDialog:new{
        plugin = self,
        title = self:getTranslation("edit_custom_meanings"),
        buttons = buttons,
    })
    setTarotDirty(self)
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
    entry.position_names = entry.position_names or {}

    local lines = {
        JOURNAL_MAGIC,
        "id=" .. journalEscape(entry.id),
        "created_at=" .. tostring(entry.created_at),
        "updated_at=" .. tostring(entry.updated_at),
        "entry_type=" .. journalEscape(entry.entry_type),
        "deck=" .. journalEscape(entry.deck),
        "spread_type=" .. journalEscape(entry.spread_type or ""),
        "layout_mode=" .. journalEscape(entry.layout_mode or "auto"),
        "title=" .. journalEscape(entry.title),
        "note=" .. journalEscape(entry.note),
        "outcome=" .. journalEscape(entry.outcome),
        "outcome_at=" .. tostring(entry.outcome_at),
        "favorite=" .. (entry.favorite and "1" or "0"),
    }

    for slot = 1, 16 do
        local stored_name = journalTrim(entry.position_names[slot])
        if stored_name ~= "" then
            table.insert(lines, "position=" .. tostring(slot) .. "|" .. journalEscape(stored_name))
        end
    end

    for _, card_data in ipairs(entry.cards) do
        local id = tonumber(card_data.id)
        if id then
            local card_line = "card=" .. tostring(id) .. "|" .. (card_data.is_reversed and "1" or "0")
            local grid_slot = tonumber(card_data.grid_slot)
            if grid_slot and grid_slot >= 1 and grid_slot <= 16 then
                card_line = card_line .. "|" .. tostring(grid_slot)
            end
            table.insert(lines, card_line)
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

    local entry = { cards = {}, position_names = {}, filepath = path, source = "structured" }
    for line in content:gmatch("[^\r\n]+") do
        local key, value = line:match("^([^=]+)=(.*)$")
        if key == "position" then
            local slot, stored_name = value:match("^(%d+)|(.*)$")
            slot = tonumber(slot)
            if slot and slot >= 1 and slot <= 16 then
                stored_name = journalTrim(journalUnescape(stored_name))
                if stored_name ~= "" then
                    entry.position_names[slot] = stored_name
                end
            end
        elseif key == "card" then
            local id, reversed, grid_slot = value:match("^(%-?%d+)|([01])|(%d+)$")
            if not id then
                id, reversed = value:match("^(%-?%d+)|([01])$")
            end
            if id then
                table.insert(entry.cards, {
                    id = tonumber(id),
                    is_reversed = reversed == "1",
                    grid_slot = tonumber(grid_slot),
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
    entry.layout_mode = entry.layout_mode == "custom" and "custom" or "auto"
    entry.position_names = entry.position_names or {}
    entry.filename = path:match("([^/]+)$")
    return entry
end

function TarotPlugin:makeJournalEntryFromCards(cards, title, note, entry_type)
    local is_lenormand = cards and cards[1] and cards[1].card and cards[1].card.symbol ~= nil
    local card_refs = {}
    local position_names = {}
    for slot, stored_name in pairs((cards and cards.position_names) or {}) do
        slot = tonumber(slot)
        stored_name = journalTrim(stored_name)
        if slot and slot >= 1 and slot <= 16 and stored_name ~= "" then
            position_names[slot] = stored_name
        end
    end
    for _, card_data in ipairs(cards or {}) do
        if card_data.card and card_data.card.id ~= nil then
            table.insert(card_refs, {
                id = card_data.card.id,
                is_reversed = card_data.is_reversed == true,
                grid_slot = tonumber(card_data.grid_slot),
            })
            local slot = tonumber(card_data.grid_slot)
            local stored_name = journalTrim(card_data.position_name)
            if slot and slot >= 1 and slot <= 16 and stored_name ~= "" then
                position_names[slot] = stored_name
            end
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
        layout_mode = (function()
            for _, card_data in ipairs(cards or {}) do
                if tonumber(card_data.grid_slot) then return "custom" end
            end
            return "auto"
        end)(),
        title = title or "",
        note = note or "",
        outcome = "",
        outcome_at = 0,
        favorite = false,
        cards = card_refs,
        position_names = position_names,
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
    -- Reflexões Livres não pertencem a nenhum baralho. Retornar texto vazio
    -- evita que o valor interno "none" seja exibido incorretamente como
    -- "Registro Antigo" na lista do Diário.
    if entry.entry_type == "free" then return "" end
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
    local metadata_parts = { star .. date_text }
    local deck_text = self:getJournalDeckText(entry)
    if deck_text and deck_text ~= "" then
        table.insert(metadata_parts, deck_text)
    end
    table.insert(metadata_parts, self:getJournalEntryTypeText(entry))
    local metadata = table.concat(metadata_parts, " · ")
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
        setTarotDirty(self.plugin or self)
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
    local subtitle = string.format(self:getTranslation("journal_records"), #entries)
    local header_w = makeSectionHeader(self:getTranslation("saved_readings"), iw, subtitle)
    local body = VerticalGroup:new{ align = "center" }

    if #entries == 0 then
        table.insert(body, makeMutedText(self:getTranslation("no_journal_results"), math.floor(iw * 0.88)))
    else
        local start_index = (state.page - 1) * per_page + 1
        local end_index = math.min(#entries, start_index + per_page - 1)
        local previous_month
        local item_height = math.max(72, math.floor(layout.safe_h * 0.075))

        for index = start_index, end_index do
            local entry = entries[index]
            local month_key = os.date("%m/%Y", entry.created_at or 0)
            if month_key ~= previous_month then
                table.insert(body, TextWidget:new{
                    text = "— " .. month_key .. " —",
                    face = Font:getFace("x_smallinfofont"),
                    fgcolor = Blitbuffer.gray(0.48),
                    max_width = iw,
                    alignment = "center",
                })
                table.insert(body, VerticalSpan:new{ width = Size.span.vertical_small })
                previous_month = month_key
            end

            table.insert(body, makeRoundedButton{
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
            table.insert(body, VerticalSpan:new{ width = Size.span.vertical_small })
        end
    end

    local action_w = math.floor((iw - Size.span.horizontal_default) / 2)
    local shortcuts_row_1 = HorizontalGroup:new{
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
    }
    local shortcuts_row_2 = HorizontalGroup:new{
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
    }

    local nav_button_w = math.floor(iw * 0.23)
    local page_label_w = math.floor(iw * 0.32)
    local nav_row = HorizontalGroup:new{
        align = "center",
        makeRoundedButton{
            text = "‹", width = nav_button_w, enabled = state.page > 1,
            callback = function() self:showSavedReadingsMenu(state.page - 1) end,
        },
        HorizontalSpan:new{ width = Size.span.horizontal_default },
        CenterContainer:new{
            dimen = Geom:new{ w = page_label_w, h = 40 },
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
    }

    local footer_content = VerticalGroup:new{ align = "center" }
    if #entries == 0 then
        table.insert(footer_content, makeRoundedButton{
            text = self:getTranslation("clear_filters"), width = math.floor(iw * 0.72),
            callback = function()
                self:clearJournalFilters()
                self:showSavedReadingsMenu(1)
            end,
        })
        table.insert(footer_content, VerticalSpan:new{ width = Size.span.vertical_default })
    end
    table.insert(footer_content, shortcuts_row_1)
    table.insert(footer_content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(footer_content, shortcuts_row_2)
    table.insert(footer_content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(footer_content, nav_row)
    table.insert(footer_content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(footer_content, makeTransparentTextButton{
        text = self:getTranslation("close"), width = math.floor(iw * 0.42),
        callback = function() self:closeJournalDialog() end,
    })

    self.journal_dialog = makeFullscreenScaffold{
        layout = layout,
        header = header_w,
        body = body,
        footer = makeFullscreenFooter(iw, footer_content),
    }
    UIManager:show(self.journal_dialog)
    setTarotDirty(self.plugin or self)
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
        plugin = self,
        title = self:getTranslation("journal_filter_title"),
        buttons = buttons,
    }
    UIManager:show(self.journal_filter_dialog)
    setTarotDirty(self.plugin or self)
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
        plugin = self,
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
    local deck_text = self:getJournalDeckText(entry)
    local type_text = self:getJournalEntryTypeText(entry)
    if deck_text and deck_text ~= "" then
        table.insert(lines, deck_text .. " · " .. type_text)
    else
        table.insert(lines, type_text)
    end
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
        plugin = self,
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
        plugin = self,
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
        plugin = self,
        title = self:getTranslation("trash_title"), buttons = buttons,
    }
    UIManager:show(self.journal_trash_dialog)
end

function TarotPlugin:showTrashEntryOptions(entry, page)
    local dialog
    dialog = FullscreenMenuDialog:new{
        plugin = self,
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
        plugin = self,
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
    }
    local deck_text = self:getJournalDeckText(entry)
    if deck_text and deck_text ~= "" then
        table.insert(lines, "**" .. self:getTranslation("deck_type") .. ":** " .. deck_text)
    end
    table.insert(lines, "**" .. self:getTranslation("type_label") .. ":** " .. self:getJournalEntryTypeText(entry))
    table.insert(lines, "")
    table.insert(lines, "## " .. self:getTranslation("reflection_text"))
    table.insert(lines, "")
    table.insert(lines, entry.note or "")
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
        plugin = self,
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

function TarotPlugin:showSaveTitleInput(cards, entry_type, on_saved)
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
                        self:showSaveNoteInput(cards, title, entry_type or "spread", on_saved)
                    end,
                },
            },
        },
    }
    UIManager:show(title_input)
    title_input:onShowKeyboard()
end

function TarotPlugin:showSaveNoteInput(cards, title, entry_type, on_saved)
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
                            if type(on_saved) == "function" then
                                on_saved()
                            end
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
            setTarotDirty(self.plugin or self)
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
    hidden_grid_view = false,
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
        and not self.hidden_grid_view
        and not has_unrevealed_cards
        and self.auto_save_state == nil then
        self.auto_save_state = self.plugin:autoSaveReading(self.cards) and "saved" or "failed"
    end

    local card_path = self.plugin:getCardImagePath(card)
    local has_image = card_path and lfs.attributes(card_path) and lfs.attributes(card_path).mode == "file"
    local hide_name = use_lenormand and T.current_lang == "C" and has_image

    local position_title = getPositionNameDisplay(self.plugin, card_data.position_name)
    local title_suffix = position_title ~= ""
        and position_title
        or (self.title_label or self.plugin:getTranslation("title"))
    if position_title == "" and not self.title_label and use_lenormand then
        title_suffix = self.plugin:getTranslation("lenormand_title")
    end
    local title_text = title_suffix

    -- Título fixo no topo em todas as telas de carta, inclusive nas tiragens.
    -- A área central e o rodapé são calculados separadamente para evitar
    -- sobreposição em telas e-ink pequenas.
    local header_w = makeSectionHeader(title_text, iw)

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
            hidden_grid_view = self.hidden_grid_view,
        })
        setTarotDirty(self.plugin or self)
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
            hidden_grid_view = self.hidden_grid_view,
        })
        setTarotDirty(self.plugin or self)
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
            hidden_grid_view = self.hidden_grid_view,
                })
                setTarotDirty(self.plugin or self)
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
                setTarotDirty(self.plugin or self)
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
                setTarotDirty(self.plugin or self)
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

    local current_orientation = (is_reversed and not use_lenormand) and "reversed" or "upright"
    local base_meaning_text
    if use_lenormand then
        base_meaning_text = T(card.meaning)
    else
        base_meaning_text = is_reversed and T(card.reversed_meaning) or T(card.meaning)
    end

    local custom_meaning_entries = {}
    if meaning_mode == "full" then
        custom_meaning_entries = self.plugin:getCustomMeaningsForCard(
            card,
            use_lenormand,
            current_orientation
        )
    end
    local has_custom_meanings = #custom_meaning_entries > 0
    local show_only_custom = meaning_mode == "full"
        and has_custom_meanings
        and self.plugin.show_only_custom_meanings == true

    local meaning_text
    if show_only_custom then
        meaning_text = self.plugin:formatCustomMeaningEntries(custom_meaning_entries, false)
    else
        meaning_text = base_meaning_text
        if meaning_mode == "summary" then
            meaning_text = summarizeCardMeaning(meaning_text, 180)
        elseif meaning_mode == "full" and has_custom_meanings then
            meaning_text = journalTrim(table.concat({
                meaning_text,
                self.plugin:getTranslation("personal_meanings") .. ":",
                self.plugin:formatCustomMeaningEntries(custom_meaning_entries, false),
            }, "\n\n"))
        end
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

    local should_scroll_meaning = meaning_mode == "full"
        and (has_custom_meanings or #meaning_text > 520 or meaning_text:find("\n"))
    local meaning_h = math.floor(layout.safe_h * 0.24)
    if total_cards > 1 then
        meaning_h = math.floor(layout.safe_h * 0.21)
    end
    if meaning_h < 110 then meaning_h = 110 end
    if meaning_h > math.floor(layout.safe_h * 0.34) then
        meaning_h = math.floor(layout.safe_h * 0.34)
    end

    local meaning_w
    if should_scroll_meaning then
        meaning_w = ScrollTextWidget:new{
            text = meaning_text,
            face = Font:getFace(meaning_face_name),
            width = iw,
            height = meaning_h,
            alignment = "left",
            scroll_by_pan = true,
            dialog = self,
        }
    else
        meaning_w = TextBoxWidget:new{
            text      = meaning_text,
            face      = Font:getFace(meaning_face_name),
            width     = iw,
            alignment = "center",
        }
    end

    local meaning_label_text = self.plugin:getTranslation("meaning_label")
    if show_only_custom then
        meaning_label_text = self.plugin:getTranslation("personal_meanings")
    elseif is_reversed and not use_lenormand then
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
            setTarotDirty(self.plugin or self)
            self.plugin:showSaveTitleInput(self.cards, self.is_daily and "daily" or "spread")
        end,
    }

    local function closeCardDialogNow()
        UIManager:close(self)
        setTarotDirty(self.plugin or self)
        if self.on_close then self.on_close() end
    end

    local btn_close = makeTransparentTextButton{
        text     = self.plugin:getTranslation("close"),
        width    = math.floor(iw * 0.40),
        callback = function()
            local should_warn = is_spread_view
                and not self.hidden_grid_view
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
    if self.hidden_grid_view or self.read_only or (has_unrevealed_cards and not self.is_daily) then
        -- Durante a revelação, a instrução é mostrada em um aviso descartável.
        -- Nenhum texto ou botão ocupa o rodapé permanentemente.
        btns_row = nil
    else
        btns_row = HorizontalGroup:new{
            align = "center",
            btn_save,
        }
    end

    local body = VerticalGroup:new{ align = "center" }

    if reveal_progress_w then
        table.insert(body, reveal_progress_w)
        table.insert(body, VerticalSpan:new{ width = Size.span.vertical_default })
    end

    table.insert(body, card_image)
    table.insert(body, VerticalSpan:new{ width = Size.span.vertical_default })

    if name_w then
        table.insert(body, name_w)
        table.insert(body, VerticalSpan:new{ width = Size.span.vertical_small })
    end

    if show_meaning then
        table.insert(body, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(body, meaning_label_w)
        table.insert(body, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(body, meaning_w)
    end

    -- Botão textual discreto para abrir a carta no livro. Continua próximo ao
    -- conteúdo da carta, enquanto salvar/fechar ficam sempre no rodapé.
    local btn_view_in_book = makeTransparentTextButton{
        text = self.plugin:getTranslation("view_in_book"),
        width = math.floor(iw * 0.5),
        callback = function()
            self.plugin:showCardInBook(card, use_lenormand)
        end,
    }
    if not self.read_only and not self.plugin.disable_view_in_book then
        table.insert(body, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(body, btn_view_in_book)
    end

    local footer_content = VerticalGroup:new{ align = "center" }
    if btns_row then
        table.insert(footer_content, btns_row)
        table.insert(footer_content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(footer_content, makeDialogDivider())
        table.insert(footer_content, VerticalSpan:new{ width = Size.span.vertical_default })
    end
    table.insert(footer_content, btn_close)

    self[1] = makeFullscreenScaffold{
        layout = layout,
        header = header_w,
        body = body,
        footer = makeFullscreenFooter(iw, footer_content),
    }

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
-- ║      SELETOR DE BARALHO FÍSICO — LISTA TEXTUAL COM ATÉ 16 CARTAS           ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- O seletor não sorteia cartas e não exibe imagens. Ele apenas registra, na
-- ordem dos toques, até dezesseis cartas que o usuário retirou do próprio baralho.
-- Ao confirmar, as cartas escolhidas são abertas no CardDialog já existente.
local PHYSICAL_DECK_MAX_CARDS = 16

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

    local list_style = getPhysicalDeckListStyle(layout)

    local header_w = makeSectionHeader(
        self.plugin:getTranslation("physical_deck"),
        iw,
        self.plugin:getTranslation("physical_deck_hint")
    )

    -- A quantidade de linhas por página agora nasce do espaço real disponível.
    -- Em telas altas cabem mais cartas; em janelas baixas o número recua antes
    -- de sobrepor rodapé, paginação ou botões de ação.
    local items_per_page = getAdaptivePhysicalDeckItemsPerPage(layout, header_w, list_style)

    local total_pages = math.max(1, math.ceil(#self.deck / items_per_page))
    if self.page < 1 then self.page = 1 end
    if self.page > total_pages then self.page = total_pages end

    -- Retorna a ordem em que a carta foi selecionada. Além de informar se a
    -- carta está marcada, isso permite exibir claramente as posições 1 a 16.
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
        setTarotDirty(self.plugin or self)
    end

    local function toggleCard(index)
        local selected_position = getSelectionPosition(index)

        if selected_position then
            table.remove(self.selected_indices, selected_position)
            self.reversed_indices[index] = nil
            reopen(self.page)
            return
        end

        if #self.selected_indices >= PHYSICAL_DECK_MAX_CARDS then
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
            if #self.selected_indices >= PHYSICAL_DECK_MAX_CARDS then
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

    local content = VerticalGroup:new{ align = "center" }

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
            text_font_size = list_style.font_size,
            text_font_bold = false,
            padding_h = Size.padding.default,
            padding_v = list_style.padding_v,
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

    local footer_row = HorizontalGroup:new{
        align = "center",
        makeTransparentTextButton{
            text = self.plugin:getTranslation("back"),
            width = math.floor(iw * 0.38),
            callback = function()
                UIManager:close(self)
                self.plugin:showSpreadsMenu()
                setTarotDirty(self.plugin or self)
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
                setTarotDirty(self.plugin or self)
            end,
        },
    }

    local footer = makeFullscreenFooter(iw, VerticalGroup:new{
        align = "center",
        nav_row,
        VerticalSpan:new{ width = Size.span.vertical_small },
        footer_row,
    })

    self[1] = makeFullscreenScaffold{
        layout = layout,
        header = header_w,
        body = content,
        footer = footer,
    }
end

local HiddenCardDialog

-- Abre as cartas de um registro em modo somente leitura. Tiragens montadas na
-- grade 4×4 são reabertas no layout original; registros antigos continuam com
-- a navegação linear pelas miniaturas laterais.
function TarotPlugin:showJournalCards(entry)
    local cards = {}
    local has_custom_slot = false
    local position_names = entry.position_names or {}

    for _, saved_card in ipairs(entry.cards or {}) do
        local card = self:getJournalCard(entry, saved_card)
        if card then
            local slot = tonumber(saved_card.grid_slot)
            if slot and slot >= 1 and slot <= 16 then
                has_custom_slot = true
            end
            table.insert(cards, {
                card = card,
                is_reversed = saved_card.is_reversed == true,
                is_revealed = true,
                grid_slot = slot,
                position_name = slot and position_names[slot] or nil,
            })
        end
    end

    if #cards == 0 then
        self:showJournalEntry(entry)
        return
    end

    local function returnToJournalEntry()
        self:showJournalEntry(entry)
    end

    if entry.layout_mode == "custom" and has_custom_slot then
        UIManager:show(HiddenCardDialog:new{
            plugin = self,
            cards = cards,
            position_names = position_names,
            title_label = self:getJournalDisplayTitle(entry),
            read_only = true,
            allow_add_card = false,
            deck_is_lenormand = entry.deck == "lenormand",
            on_close = returnToJournalEntry,
        })
    else
        UIManager:show(CardDialog:new{
            cards = cards,
            current_index = 1,
            plugin = self,
            title_label = self:getJournalDisplayTitle(entry),
            read_only = true,
            deck_is_lenormand = entry.deck == "lenormand",
            on_close = returnToJournalEntry,
        })
    end
    setTarotDirty(self.plugin or self)
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║ CARTA OCULTA — GRADE FIXA 4×4, INSERÇÃO DIRETA E ORGANIZAÇÃO POR TOQUE      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
HiddenCardDialog = InputContainer:extend{
    plugin = nil,
    cards = nil,
    position_names = nil,
    on_new = nil,
    is_daily = false,
    on_reveal = nil,
    title_label = nil,
    allow_add_card = false,
    max_cards = 16,
    deck_is_lenormand = nil,
    read_only = false,
    on_close = nil,
    selected_action_index = nil,
    moving_index = nil,
    show_opening_hint = false,
    manual_save_state = nil,
}

function HiddenCardDialog:init()
    local layout = getFullscreenLayout(0.96)
    local iw = layout.content_w

    self.cards = self.cards or {}
    self.position_names = self.position_names or {}
    self.max_cards = math.max(1, math.min(16, tonumber(self.max_cards) or 16))

    -- Mantém apenas nomes válidos associados às 16 posições fixas.
    local normalized_position_names = {}
    for slot, stored_name in pairs(self.position_names) do
        slot = tonumber(slot)
        stored_name = trimPositionName(stored_name)
        if slot and slot >= 1 and slot <= 16 and stored_name ~= "" then
            normalized_position_names[slot] = stored_name
        end
    end
    self.position_names = normalized_position_names

    local use_lenormand = self.deck_is_lenormand
    if use_lenormand == nil then
        use_lenormand = self.plugin.use_lenormand == true
    end

    local header_w = makeSectionHeader(
        self.title_label or self.plugin:getTranslation("draw_cards"),
        iw
    )

    for _, item in ipairs(self.cards) do
        if item.is_revealed == nil then item.is_revealed = false end
    end

    -- Nas tiragens livres, cada carta ocupa uma das 16 posições fixas. Isso
    -- permite iniciar com zero cartas e montar cruzes, linhas ou diagonais sem
    -- que o tamanho e a posição das cartas existentes mudem.
    local function normalizeGridSlots()
        if self.is_daily then return end
        local used = {}
        for _, item in ipairs(self.cards) do
            local slot = tonumber(item.grid_slot)
            if slot and slot >= 1 and slot <= 16 and not used[slot] then
                item.grid_slot = slot
                used[slot] = true
            else
                item.grid_slot = nil
            end
        end
        for _, item in ipairs(self.cards) do
            if not item.grid_slot then
                for slot = 1, 16 do
                    if not used[slot] then
                        item.grid_slot = slot
                        used[slot] = true
                        break
                    end
                end
            end
        end
    end
    normalizeGridSlots()

    local function markReadingChanged()
        -- Qualquer alteração depois de um salvamento manual torna a grade
        -- novamente diferente do registro salvo no Diário.
        self.manual_save_state = nil
    end

    local function allCardsRevealed()
        if #self.cards == 0 then return false end
        for _, item in ipairs(self.cards) do
            if item.is_revealed ~= true then return false end
        end
        return true
    end

    local function orderedCardsForReading()
        local ordered = {}
        for _, item in ipairs(self.cards) do
            local slot = tonumber(item.grid_slot)
            table.insert(ordered, {
                card = item.card,
                is_reversed = item.is_reversed == true,
                is_revealed = item.is_revealed == true,
                grid_slot = slot,
                position_name = slot and self.position_names[slot] or nil,
            })
        end
        if not self.is_daily then
            table.sort(ordered, function(a, b)
                return (tonumber(a.grid_slot) or 99) < (tonumber(b.grid_slot) or 99)
            end)
        end
        ordered.position_names = {}
        for slot, stored_name in pairs(self.position_names) do
            ordered.position_names[slot] = stored_name
        end
        return ordered
    end

    local function refreshHiddenDialog()
        UIManager:close(self)
        UIManager:show(HiddenCardDialog:new{
            plugin = self.plugin,
            cards = self.cards,
            position_names = self.position_names,
            on_new = self.on_new,
            is_daily = self.is_daily,
            on_reveal = self.on_reveal,
            title_label = self.title_label,
            allow_add_card = self.allow_add_card,
            max_cards = self.max_cards,
            deck_is_lenormand = use_lenormand,
            read_only = self.read_only,
            on_close = self.on_close,
            selected_action_index = self.selected_action_index,
            moving_index = self.moving_index,
            manual_save_state = self.manual_save_state,
            -- O aviso pertence à abertura da tiragem, nunca às reconstruções
            -- internas causadas por revelar, mover, excluir ou adicionar cartas.
            show_opening_hint = false,
        })
        setTarotDirty(self.plugin or self)
    end

    local function clearTransientSelection()
        self.selected_action_index = nil
        self.moving_index = nil
    end

    local function slotIsOccupied(slot)
        for index, item in ipairs(self.cards) do
            if tonumber(item.grid_slot) == slot then return true, index end
        end
        return false, nil
    end

    local function addCardAtSlot(slot)
        if self.read_only or self.is_daily or not self.allow_add_card then return end
        if self.selected_action_index or self.moving_index then return end
        if #self.cards >= self.max_cards then return end
        local occupied = slotIsOccupied(slot)
        if occupied then return end

        local new_card = self.plugin:drawAdditionalUniqueCard(self.cards)
        if not new_card then return end
        new_card.is_revealed = self.plugin.spread_cards_always_revealed == true
        new_card.grid_slot = slot
        table.insert(self.cards, new_card)
        markReadingChanged()
        refreshHiddenDialog()
    end

    local function deleteCard(index)
        if self.read_only or self.is_daily or not self.cards[index] then return end
        table.remove(self.cards, index)
        markReadingChanged()
        clearTransientSelection()
        normalizeGridSlots()
        refreshHiddenDialog()
    end

    local function openRevealedCard(source_item)
        local revealed_cards = {}
        local dialog_index = nil
        for _, item in ipairs(orderedCardsForReading()) do
            if item.is_revealed == true then
                table.insert(revealed_cards, item)
                if tonumber(item.grid_slot) == tonumber(source_item.grid_slot) then
                    dialog_index = #revealed_cards
                end
            end
        end
        if not dialog_index or #revealed_cards == 0 then return end

        UIManager:show(CardDialog:new{
            cards = revealed_cards,
            current_index = dialog_index,
            plugin = self.plugin,
            title_label = self.title_label or self.plugin:getTranslation("draw_cards"),
            is_daily = false,
            read_only = self.read_only,
            deck_is_lenormand = use_lenormand,
            hidden_grid_view = true,
            on_close = function()
                setTarotDirty(self.plugin or self)
            end,
        })
        setTarotDirty(self.plugin or self)
    end

    local function tapCard(index)
        local item = self.cards[index]
        if not item then return end

        -- Enquanto o menu de uma carta está aberto, somente as ações desse menu
        -- são aceitas. Isso evita revelar ou adicionar cartas por acidente.
        if self.selected_action_index then return end

        if self.read_only then
            if item.is_revealed == true then openRevealedCard(item) end
            return
        end

        if self.moving_index then
            if self.moving_index == index then
                self.moving_index = nil
            else
                local source = self.cards[self.moving_index]
                if source then
                    source.grid_slot, item.grid_slot = item.grid_slot, source.grid_slot
                    markReadingChanged()
                end
                self.moving_index = nil
            end
            refreshHiddenDialog()
            return
        end

        if self.is_daily and item.is_revealed ~= true then
            UIManager:close(self)
            setTarotDirty(self.plugin or self)
            if self.on_reveal then self.on_reveal() end
            return
        end

        if item.is_revealed == true then
            openRevealedCard(item)
        else
            item.is_revealed = true
            markReadingChanged()
            refreshHiddenDialog()
        end
    end

    local function tapEmptySlot(slot)
        if self.read_only or self.is_daily then return end
        if self.selected_action_index then return end

        if self.moving_index then
            local source = self.cards[self.moving_index]
            if source then
                source.grid_slot = slot
                markReadingChanged()
            end
            self.moving_index = nil
            refreshHiddenDialog()
            return
        end

        addCardAtSlot(slot)
    end

    local function holdCard(index)
        if self.read_only or self.is_daily or not self.cards[index] then return end
        self.selected_action_index = index
        self.moving_index = nil
        refreshHiddenDialog()
    end

    local function showPositionNamePopup(slot)
        if self.read_only or self.is_daily then return end
        slot = tonumber(slot)
        if not slot or slot < 1 or slot > 16 then return end

        local position_dialog

        local function finishPositionNaming(stored_name)
            if position_dialog then UIManager:close(position_dialog) end
            stored_name = trimPositionName(stored_name)
            self.position_names[slot] = stored_name ~= "" and stored_name or nil
            markReadingChanged()
            clearTransientSelection()
            refreshHiddenDialog()
        end

        local function cancelPositionNaming()
            if position_dialog then UIManager:close(position_dialog) end
            clearTransientSelection()
            refreshHiddenDialog()
        end

        local function openCustomPositionInput()
            if position_dialog then UIManager:close(position_dialog) end
            local current_display = getPositionNameDisplay(self.plugin, self.position_names[slot])
            local input_dialog
            input_dialog = InputDialog:new{
                title = self.plugin:getTranslation("custom_position_name"),
                input = current_display,
                input_hint = self.plugin:getTranslation("custom_position_name_hint"),
                input_type = "string",
                buttons = {
                    {
                        {
                            text = self.plugin:getTranslation("cancel"),
                            callback = function()
                                UIManager:close(input_dialog)
                                clearTransientSelection()
                                refreshHiddenDialog()
                            end,
                        },
                        {
                            text = self.plugin:getTranslation("confirm"),
                            is_enter_default = true,
                            callback = function()
                                local custom_name = trimPositionName(input_dialog:getInputText())
                                UIManager:close(input_dialog)
                                self.position_names[slot] = custom_name ~= ""
                                    and makeStoredCustomPositionName(custom_name) or nil
                                markReadingChanged()
                                clearTransientSelection()
                                refreshHiddenDialog()
                            end,
                        },
                    },
                },
            }
            UIManager:show(input_dialog)
            input_dialog:onShowKeyboard()
        end

        local buttons = {}
        for index = 1, #POSITION_NAME_PRESETS, 2 do
            local row = {}
            for offset = 0, 1 do
                local preset = POSITION_NAME_PRESETS[index + offset]
                if preset then
                    local preset_id = preset.id
                    local preset_key = preset.key
                    table.insert(row, {
                        text = self.plugin:getTranslation(preset_key),
                        callback = function()
                            finishPositionNaming(makeStoredPresetPositionName(preset_id))
                        end,
                    })
                end
            end
            table.insert(buttons, row)
        end

        table.insert(buttons, {
            {
                text = self.plugin:getTranslation("custom_position_name"),
                callback = openCustomPositionInput,
            },
        })

        if self.position_names[slot] then
            table.insert(buttons, {
                {
                    text = self.plugin:getTranslation("remove_position_name"),
                    callback = function() finishPositionNaming(nil) end,
                },
            })
        end

        table.insert(buttons, {
            {
                text = self.plugin:getTranslation("cancel"),
                callback = cancelPositionNaming,
            },
        })

        position_dialog = ButtonDialog:new{
            title = self.plugin:getTranslation("position_name_title"),
            title_align = "center",
            width_factor = 0.72,
            buttons = buttons,
            tap_close_callback = function()
                clearTransientSelection()
                UIManager:scheduleIn(0.05, function()
                    refreshHiddenDialog()
                end)
            end,
        }
        UIManager:show(position_dialog)
        setTarotDirty(self.plugin or self)
    end

    local function holdEmptySlot(slot)
        if self.read_only or self.is_daily then return end
        if self.moving_index then return end
        showPositionNamePopup(slot)
    end

    local action_gap = math.max(6, math.floor(iw * 0.025))
    local action_button_w = math.max(70, math.floor((iw - action_gap) / 2))

    local btn_save = makeTransparentTextButton{
        text = self.plugin:getTranslation("save"),
        width = action_button_w,
        enabled = allCardsRevealed(),
        callback = function()
            clearTransientSelection()
            setTarotDirty(self.plugin or self)
            self.plugin:showSaveTitleInput(orderedCardsForReading(), "spread", function()
                -- Salvar não fecha a grade. O usuário continua olhando a
                -- tiragem e decide sozinho quando sair.
                self.manual_save_state = "saved"
            end)
        end,
    }

    local function closeHiddenNow()
        UIManager:close(self)
        setTarotDirty(self.plugin or self)
        if self.on_close then self.on_close() end
    end

    local function closeHidden()
        local complete = allCardsRevealed()
        local ordered_cards = orderedCardsForReading()

        local was_manually_saved = self.manual_save_state == "saved"

        if complete and self.plugin.auto_save_spreads == true and not was_manually_saved then
            if self.plugin:autoSaveReading(ordered_cards) then
                closeHiddenNow()
            else
                UIManager:show(InfoMessage:new{
                    text = self.plugin:getTranslation("journal_save_error"),
                })
            end
            return
        end

        local should_warn = complete
            and not was_manually_saved
            and self.plugin.auto_save_spreads ~= true
            and self.plugin.disable_unsaved_close_warning ~= true

        if not should_warn then
            closeHiddenNow()
            return
        end

        local warning
        warning = ConfirmBox:new{
            text = self.plugin:getTranslation("unsaved_close_warning"),
            ok_text = self.plugin:getTranslation("close_without_saving"),
            cancel_text = self.plugin:getTranslation("continue_reading"),
            ok_callback = function()
                UIManager:close(warning)
                closeHiddenNow()
            end,
        }
        UIManager:show(warning)
    end

    local btn_close = makeTransparentTextButton{
        text = self.plugin:getTranslation("close"),
        width = action_button_w,
        callback = closeHidden,
    }

    local actions_row = HorizontalGroup:new{
        align = "center",
        btn_save,
        HorizontalSpan:new{ width = action_gap },
        btn_close,
    }

    local footer = makeFullscreenFooter(iw,
        (self.is_daily or self.read_only) and makeTransparentTextButton{
            text = self.plugin:getTranslation("close"),
            width = math.max(100, math.floor(iw * 0.42)),
            callback = closeHiddenNow,
        } or actions_row
    )

    local gap_x = math.max(4, math.floor(iw * 0.012))
    local gap_y = math.max(4, math.floor(layout.safe_h * 0.006))
    local header_h = header_w:getSize().h
    local footer_h = footer:getSize().h
    local grid_footer_gap = math.max(Size.span.vertical_default, gap_y * 2)
    local available_grid_h = layout.safe_h - header_h - footer_h - grid_footer_gap
    if available_grid_h < 80 then available_grid_h = 80 end

    local ratio = use_lenormand and 1 or (439 / 250)
    local card_w
    local card_h
    local grid

    local function makeActionMenu(index, width, height)
        local item = self.cards[index]
        local action_count = item and item.is_revealed == true and 5 or 4
        local menu_w = width
        -- Mantém o box e as áreas de toque compactos. O destaque visual vem
        -- apenas da fonte maior, não de botões ou bordas mais grossos.
        local menu_h = math.max(54, math.floor(height * 0.82))
        if menu_h > height then menu_h = height end
        local outer_pad = math.max(2, Size.padding.tiny)
        local button_gap = math.max(0, math.floor(height * 0.004))
        local inner_h = math.max(1, menu_h - outer_pad * 2)
        local button_h = math.max(1, math.floor((inner_h - button_gap * (action_count - 1)) / action_count))
        local font_size = math.max(8, math.min(
            18,
            math.floor(width / 5.8),
            math.floor(button_h * 0.70)
        ))

        local function largeTextActionButton(text, callback)
            return Button:new{
                text = text,
                width = math.max(24, menu_w - outer_pad * 2),
                height = button_h,
                bordersize = 0,
                margin = 0,
                padding = 0,
                padding_h = 0,
                padding_v = 0,
                background = nil,
                radius = 0,
                text_font_face = "x_smallinfofont",
                text_font_size = font_size,
                text_font_bold = true,
                callback = callback,
            }
        end

        local menu_content = VerticalGroup:new{ align = "center" }
        local slot = item and tonumber(item.grid_slot)
        local position_button_text = slot
            and getPositionNameDisplay(self.plugin, self.position_names[slot]) or ""
        if position_button_text == "" then
            position_button_text = self.plugin:getTranslation("name_position")
        end

        -- A nomeação ocupa sempre o topo. Depois da escolha, o próprio nome da
        -- posição substitui o texto genérico "Nomear posição".
        table.insert(menu_content, largeTextActionButton(position_button_text, function()
            if slot then showPositionNamePopup(slot) end
        end))
        table.insert(menu_content, VerticalSpan:new{ width = button_gap })

        table.insert(menu_content, largeTextActionButton(self.plugin:getTranslation("move_card"), function()
            self.moving_index = index
            self.selected_action_index = nil
            refreshHiddenDialog()
        end))
        table.insert(menu_content, VerticalSpan:new{ width = button_gap })

        table.insert(menu_content, largeTextActionButton(self.plugin:getTranslation("delete_card"), function()
            deleteCard(index)
        end))

        if item and item.is_revealed == true then
            table.insert(menu_content, VerticalSpan:new{ width = button_gap })
            table.insert(menu_content, largeTextActionButton(self.plugin:getTranslation("turn_face_down"), function()
                item.is_revealed = false
                markReadingChanged()
                clearTransientSelection()
                refreshHiddenDialog()
            end))
        end

        table.insert(menu_content, VerticalSpan:new{ width = button_gap })
        table.insert(menu_content, largeTextActionButton(self.plugin:getTranslation("undo_action"), function()
            clearTransientSelection()
            refreshHiddenDialog()
        end))

        return FrameContainer:new{
            width = menu_w,
            height = menu_h,
            bordersize = 1,
            radius = getTarotBaseButtonRadius(),
            padding = outer_pad,
            background = Blitbuffer.COLOR_WHITE,
            CenterContainer:new{
                dimen = Geom:new{ w = menu_w - outer_pad * 2, h = menu_h - outer_pad * 2 },
                menu_content,
            },
        }
    end

    local function makeMoveInstructionMenu(index, width, height)
        local menu_w = width
        local menu_h = math.max(58, math.floor(height * 0.82))
        if menu_h > height then menu_h = height end
        local outer_pad = math.max(3, Size.padding.tiny)
        local gap = math.max(3, math.floor(height * 0.025))
        local undo_h = math.max(22, math.floor(menu_h * 0.30))
        local text_h = math.max(18, menu_h - undo_h - gap - outer_pad * 2)
        local font_size = math.max(9, math.min(15, math.floor(width / 7.0)))

        local instruction = TextBoxWidget:new{
            text = self.plugin:getTranslation("tap_another_location_to_move"),
            face = Font:getFace("x_smallinfofont", font_size),
            bold = true,
            width = math.max(20, menu_w - outer_pad * 2),
            height = text_h,
            alignment = "center",
        }

        local undo_font_size = math.max(9, math.min(
            18,
            math.floor(width / 5.8),
            math.floor(undo_h * 0.72)
        ))
        local undo_button = Button:new{
            text = self.plugin:getTranslation("undo_action"),
            width = math.max(24, menu_w - outer_pad * 2),
            height = undo_h,
            bordersize = 0,
            margin = 0,
            padding = 0,
            padding_h = 0,
            padding_v = 0,
            background = nil,
            radius = 0,
            text_font_face = "x_smallinfofont",
            text_font_size = undo_font_size,
            text_font_bold = true,
            callback = function()
                clearTransientSelection()
                refreshHiddenDialog()
            end,
        }

        return FrameContainer:new{
            width = menu_w,
            height = menu_h,
            bordersize = 1,
            radius = getTarotBaseButtonRadius(),
            padding = outer_pad,
            background = Blitbuffer.COLOR_WHITE,
            CenterContainer:new{
                dimen = Geom:new{ w = menu_w - outer_pad * 2, h = menu_h - outer_pad * 2 },
                VerticalGroup:new{
                    align = "center",
                    instruction,
                    VerticalSpan:new{ width = gap },
                    undo_button,
                },
            },
        }
    end

    local function makeCardVisual(index, width, height)
        local item = self.cards[index]
        local visual
        if item.is_revealed == true then
            visual = self.plugin:getCardImageWidget(
                item.card,
                width,
                height,
                (item.is_reversed and not use_lenormand) and 180 or 0
            )
        else
            visual = self.plugin:getBackCardImageWidget(width, height, use_lenormand)
        end

        local card_touch = TappableImageContainer:new{
            content = visual,
            callback = function() tapCard(index) end,
            hold_callback = (not self.is_daily and not self.read_only)
                and function() holdCard(index) end or nil,
        }

        if self.selected_action_index ~= index and self.moving_index ~= index then
            return card_touch
        end

        -- A carta continua visível por baixo; o menu arredondado é pintado por
        -- cima sem borda preta de seleção, exatamente no mesmo espaço da carta.
        -- Enquanto qualquer um dos dois boxes está aberto, a imagem deixa de ser
        -- uma camada tocável, para que somente os botões recebam os eventos.
        local overlay_menu
        if self.moving_index == index then
            overlay_menu = makeMoveInstructionMenu(index, width, height)
        else
            overlay_menu = makeActionMenu(index, width, height)
        end

        return OverlapGroup:new{
            dimen = Geom:new{ w = width, h = height },
            visual,
            CenterContainer:new{
                dimen = Geom:new{ w = width, h = height },
                overlay_menu,
            },
        }
    end

    if self.is_daily then
        local count = math.max(1, #self.cards)
        card_w = math.min(math.floor(iw * 0.52), math.floor(available_grid_h / ratio))
        card_w = math.max(36, card_w)
        card_h = math.max(36, math.floor(card_w * ratio))
        local row = HorizontalGroup:new{ align = "center" }
        for index = 1, count do
            table.insert(row, makeCardVisual(index, card_w, card_h))
            if index < count then table.insert(row, HorizontalSpan:new{ width = gap_x }) end
        end
        grid = CenterContainer:new{
            dimen = Geom:new{ w = iw, h = available_grid_h },
            row,
        }
    else
        local columns, rows = 4, 4
        local max_w_by_width = math.floor((iw - gap_x * (columns - 1)) / columns)
        local max_h_per_card = math.floor((available_grid_h - gap_y * (rows - 1)) / rows)
        local max_w_by_height = math.floor(max_h_per_card / ratio)
        card_w = math.max(36, math.min(max_w_by_width, max_w_by_height))
        card_h = math.max(36, math.floor(card_w * ratio))

        local slot_to_index = {}
        for index, item in ipairs(self.cards) do
            local slot = tonumber(item.grid_slot)
            if slot and slot >= 1 and slot <= 16 then slot_to_index[slot] = index end
        end

        grid = VerticalGroup:new{ align = "center" }
        for row = 1, rows do
            local row_widget = HorizontalGroup:new{ align = "center" }
            for column = 1, columns do
                local slot = (row - 1) * columns + column
                local card_index = slot_to_index[slot]
                if card_index then
                    table.insert(row_widget, makeCardVisual(card_index, card_w, card_h))
                else
                    local placeholder = FrameContainer:new{
                        width = card_w,
                        height = card_h,
                        bordersize = 1,
                        radius = getTarotBaseButtonRadius(),
                        padding = 0,
                        background = Blitbuffer.COLOR_WHITE,
                        CenterContainer:new{
                            dimen = Geom:new{ w = card_w, h = card_h },
                            TextWidget:new{
                                text = "",
                                face = Font:getFace("x_smallinfofont"),
                            },
                        },
                    }
                    table.insert(row_widget, TappableImageContainer:new{
                        content = placeholder,
                        callback = function() tapEmptySlot(slot) end,
                        hold_callback = (not self.read_only)
                            and function() holdEmptySlot(slot) end or nil,
                    })
                end
                if column < columns then table.insert(row_widget, HorizontalSpan:new{ width = gap_x }) end
            end
            table.insert(grid, CenterContainer:new{
                dimen = Geom:new{ w = iw, h = card_h },
                row_widget,
            })
            if row < rows then table.insert(grid, VerticalSpan:new{ width = gap_y }) end
        end
    end

    local grid_area = self.is_daily and grid or CenterContainer:new{
        dimen = Geom:new{ w = iw, h = available_grid_h },
        grid,
    }

    self[1] = makeFullscreenScaffold{
        layout = layout,
        header = header_w,
        body = grid_area,
        footer = footer,
        footer_gap = grid_footer_gap,
    }

    if not self.is_daily and self.show_opening_hint == true then
        UIManager:scheduleIn(0.1, function()
            self.plugin:showHiddenCardRevealHint()
        end)
    end
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║          SEÇÃO 9: TELA INICIAL EM TELA CHEIA (TarotHomeDialog)              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local TarotHomeDialog = InputContainer:extend{
    plugin = nil,
}

function TarotHomeDialog:init()
    local layout = getFullscreenLayout(0.92)
    local iw = layout.content_w
    local tile_gap = Size.span.horizontal_default
    local tile_button_w = math.floor((iw - tile_gap) / 2)
    local home_button_radius = math.max(getTarotButtonRadius(), math.floor(layout.safe_h * 0.018))

    -- Ao tocar num botão da Home, alguns aparelhos e-ink deixam o feedback de
    -- toque quadrado preso atrás da próxima tela. O pequeno agendamento abaixo
    -- dá tempo para o botão arredondado redesenhar antes de abrir o submenu.
    local function runHomeAction(action)
        setTarotDirty(self.plugin or self, "partial")
        UIManager:scheduleIn(0.05, function()
            if action then action() end
            setTarotDirty(self.plugin or self, "partial")
        end)
    end

    local daily_data = self.plugin:getDailyCardData()
    local daily_card = daily_data.card
    local daily_is_lenormand = daily_data.is_lenormand == true
    local daily_cards = {{
        card = daily_card,
        is_reversed = daily_data.is_reversed,
    }}

    local home_title = daily_is_lenormand
        and self.plugin:getTranslation("lenormand_deck")
        or self.plugin:getTranslation("tarot_deck")

    local daily_title_w = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("daily_card") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local card_w
    local card_h
    local is_square_card = daily_card.symbol ~= nil
    local ratio = is_square_card and 1 or (439 / 250)

    -- Tamanho adaptativo e conservador para a Carta Diária da Home.
    -- Evitamos medir TextWidget/VerticalGroup extras aqui porque alguns builds
    -- de KOReader/e-ink são sensíveis a medições antecipadas durante a abertura.
    -- Em vez disso, usamos a área segura da tela e reservamos uma faixa para
    -- cabeçalho, nome da carta e rodapé. Assim a imagem cresce em telas altas,
    -- mas continua segura em Kindle Basic 2022 e janelas pequenas.
    local reserved_ratio = self.plugin.hide_daily_card_name == true and 0.43 or 0.46
    local reserved_h = math.floor(layout.safe_h * reserved_ratio)
    if reserved_h < 300 then reserved_h = 300 end
    if reserved_h > math.floor(layout.safe_h * 0.58) then
        reserved_h = math.floor(layout.safe_h * 0.58)
    end

    local max_card_h = layout.safe_h - reserved_h
    if max_card_h < math.floor(layout.safe_h * 0.30) then
        max_card_h = math.floor(layout.safe_h * 0.30)
    end
    if max_card_h > math.floor(layout.safe_h * 0.52) then
        max_card_h = math.floor(layout.safe_h * 0.52)
    end

    local max_card_w = math.floor(iw * (is_square_card and 0.74 or 0.52))
    local by_height_w = math.floor(max_card_h / ratio)
    card_w = math.min(max_card_w, by_height_w)

    local min_card_w = is_square_card and 92 or 74
    if card_w < min_card_w then card_w = min_card_w end

    local hard_max_w = is_square_card and 340 or 260
    if card_w > hard_max_w then card_w = hard_max_w end

    card_h = math.floor(card_w * ratio)
    if card_h > max_card_h then
        local scale = max_card_h / card_h
        card_w = math.max(48, math.floor(card_w * scale))
        card_h = math.max(48, math.floor(card_h * scale))
    end

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
        if self.plugin.hide_daily_card_name ~= true then
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
        end
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
                setTarotDirty(self.plugin or self)
            end,
        }
    else
        daily_button = makeRoundedButton{
            text   = self.plugin:getTranslation("reveal_daily_card"),
            width  = math.floor(iw * 0.72),
            radius = home_button_radius,
            bordersize = 1,
            callback = function()
                self.plugin:markDailyCardRevealed(daily_data)
                UIManager:close(self)
                UIManager:show(TarotHomeDialog:new{ plugin = self.plugin })
                setTarotDirty(self.plugin or self)
            end,
        }
    end

    local btn_spreads = makeRoundedButton{
        text   = self.plugin:getTranslation("spreads"),
        width  = tile_button_w,
        radius = home_button_radius,
        bordersize = 1,
        callback = function()
            runHomeAction(function() self.plugin:showSpreadsMenu() end)
        end,
    }

    local btn_journal = makeRoundedButton{
        text   = self.plugin:getTranslation("journal"),
        width  = tile_button_w,
        radius = home_button_radius,
        bordersize = 1,
        callback = function()
            runHomeAction(function() self.plugin:showSavedReadingsMenu() end)
        end,
    }

    local btn_book = makeRoundedButton{
        text   = self.plugin:getTranslation("card_book"),
        width  = iw,
        radius = home_button_radius,
        bordersize = 1,
        callback = function()
            runHomeAction(function() self.plugin:showCardBook() end)
        end,
    }

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
            setTarotDirty(self.plugin or self)
        end,
    }

    local body_items = { align = "center" }
    table.insert(body_items, daily_title_w)
    table.insert(body_items, VerticalSpan:new{ width = Size.span.vertical_small })
    table.insert(body_items, daily_image)
    if daily_name_w then
        table.insert(body_items, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(body_items, daily_name_w)
    end
    local body = VerticalGroup:new(body_items)

    local footer = VerticalGroup:new{ align = "center" }
    table.insert(footer, daily_button)
    table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(footer, makeTarotDivider(iw))
    table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(footer, HorizontalGroup:new{
        align = "center",
        btn_spreads,
        HorizontalSpan:new{ width = tile_gap },
        btn_journal,
    })
    table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(footer, btn_book)
    table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(footer, makeTarotDivider(iw))
    table.insert(footer, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(footer, HorizontalGroup:new{
        align = "center",
        btn_settings,
        HorizontalSpan:new{ width = math.floor(iw * 0.08) },
        btn_close,
    })

    self[1] = makeFullscreenScaffold{
        layout = layout,
        title = home_title,
        body = body,
        footer = footer,
        footer_gap = Size.span.vertical_small,
    }
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║          SEÇÃO 10: DIÁLOGO DE CONFIGURAÇÕES (SettingsDialog)                 ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local SettingsDialog = InputContainer:extend{
    plugin = nil,
    page = 1,
    parent_dialog = nil,
    home_needs_refresh = false,
}

-- Fecha as Configurações e, quando uma opção que afeta a Home foi alterada,
-- reconstrói a Home ao fundo. Isso evita que a Carta Diária continue mostrando
-- Tarot/Lenormand antigo depois de mudar "Apenas Tarot" ou "Apenas Lenormand".
function SettingsDialog:closeAndMaybeRefreshHome()
    UIManager:close(self)

    if self.home_needs_refresh and self.parent_dialog then
        UIManager:close(self.parent_dialog)
        UIManager:show(TarotHomeDialog:new{ plugin = self.plugin })
    end

    setTarotDirty(self.plugin or self)
end

function SettingsDialog:init()
    local layout = getFullscreenLayout()
    local iw = layout.content_w
    local page_count = 5
    self.page = tonumber(self.page) or 1
    if self.page < 1 then self.page = 1 end
    if self.page > page_count then self.page = page_count end

    local page_titles = {
        self.plugin:getTranslation("refresh_mode"),
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
            home_needs_refresh = self.home_needs_refresh == true,
        })
        setTarotDirty(self.plugin or self)
    end

    local rows = VerticalGroup:new{ align = "center" }

    if self.page == 1 then
        local function refreshModeButton(mode, label_key)
            local mark = self.plugin.screen_refresh_mode == mode and "☑" or "☐"
            return makeRoundedButton{
                text = "  " .. mark .. "  " .. self.plugin:getTranslation(label_key),
                width = card_inner_w,
                callback = function()
                    self.plugin:setScreenRefreshMode(mode)
                    reopen(1)
                end,
            }
        end

        local refresh_body = VerticalGroup:new{
            align = "center",
            refreshModeButton("smooth", "refresh_mode_smooth"),
            VerticalSpan:new{ width = Size.span.vertical_small },
            refreshModeButton("standard", "refresh_mode_standard"),
            VerticalSpan:new{ width = Size.span.vertical_small },
            refreshModeButton("clean", "refresh_mode_clean"),
            VerticalSpan:new{ width = Size.span.vertical_default },
            makeMutedText(self.plugin:getTranslation("refresh_mode_hint"), card_inner_w),
        }
        table.insert(rows, makeSettingsCard(
            self.plugin:getTranslation("refresh_mode"),
            refresh_body,
            card_w
        ))


    elseif self.page == 2 then
        local function dailyDeckButton(mode, label_key)
            local mark = self.plugin.daily_card_deck_mode == mode and "☑" or "☐"
            return makeRoundedButton{
                text = "  " .. mark .. "  " .. self.plugin:getTranslation(label_key),
                width = card_inner_w,
                callback = function()
                    if self.plugin.daily_card_deck_mode ~= mode then
                        self.home_needs_refresh = true
                    end
                    self.plugin:setDailyCardDeckMode(mode)
                    reopen(2)
                end,
            }
        end
        local hide_name_mark = self.plugin.hide_daily_card_name and "☑" or "☐"
        local hide_name_button = makeRoundedButton{
            text = "  " .. hide_name_mark .. "  " .. self.plugin:getTranslation("hide_daily_card_name"),
            width = card_inner_w,
            callback = function()
                self.home_needs_refresh = true
                self.plugin:toggleHideDailyCardName()
                reopen(2)
            end,
        }
        local daily_always_mark = self.plugin.daily_card_always_revealed and "☑" or "☐"
        local daily_always_button = makeRoundedButton{
            text = "  " .. daily_always_mark .. "  "
                .. self.plugin:getTranslation("daily_card_always_revealed"),
            width = card_inner_w,
            callback = function()
                self.home_needs_refresh = true
                self.plugin:toggleDailyCardAlwaysRevealed()
                reopen(2)
            end,
        }
        local daily_body = VerticalGroup:new{
            align = "center",
            makeMutedText(self.plugin:getTranslation("daily_card_deck_mode"), card_inner_w),
            VerticalSpan:new{ width = Size.span.vertical_small },
            dailyDeckButton("tarot", "daily_card_tarot_only"),
            VerticalSpan:new{ width = Size.span.vertical_small },
            dailyDeckButton("lenormand", "daily_card_lenormand_only"),
            VerticalSpan:new{ width = Size.span.vertical_small },
            dailyDeckButton("either", "daily_card_either"),
            VerticalSpan:new{ width = Size.span.vertical_default },
            makeTarotDivider(card_inner_w),
            VerticalSpan:new{ width = Size.span.vertical_small },
            hide_name_button,
            VerticalSpan:new{ width = Size.span.vertical_small },
            makeMutedText(self.plugin:getTranslation("hide_daily_card_name_hint"), card_inner_w),
            VerticalSpan:new{ width = Size.span.vertical_default },
            daily_always_button,
        }
        table.insert(rows, makeSettingsCard(
            self.plugin:getTranslation("daily_card"),
            daily_body,
            card_w
        ))



    elseif self.page == 3 then
        local rev_mark = self.plugin.allow_reversed and "☑" or "☐"
        local btn_rev = makeRoundedButton{
            text = "  " .. rev_mark .. "  " .. self.plugin:getTranslation("allow_reversed_desc"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleReversed()
                reopen(3)
            end,
        }
        local maj_mark = self.plugin.major_only and "☑" or "☐"
        local btn_maj = makeRoundedButton{
            text = "  " .. maj_mark .. "  " .. self.plugin:getTranslation("major_only_desc"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleMajorOnly()
                reopen(3)
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



    elseif self.page == 4 then
        local function modeButton(mode, label_key)
            local mark = self.plugin.spread_meaning_mode == mode and "☑" or "☐"
            return makeRoundedButton{
                text = "  " .. mark .. "  " .. self.plugin:getTranslation(label_key),
                width = card_inner_w,
                callback = function()
                    self.plugin:setSpreadMeaningMode(mode)
                    reopen(4)
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
                    reopen(4)
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
                reopen(4)
            end,
        })
        table.insert(display_controls, VerticalSpan:new{ width = Size.span.vertical_default })
        local always_revealed_mark = self.plugin.spread_cards_always_revealed and "☑" or "☐"
        table.insert(display_controls, makeRoundedButton{
            text = "  " .. always_revealed_mark .. "  "
                .. self.plugin:getTranslation("spread_cards_always_revealed"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleSpreadCardsAlwaysRevealed()
                reopen(4)
            end,
        })
        table.insert(display_controls, VerticalSpan:new{ width = Size.span.vertical_default })
        local only_custom_mark = self.plugin.show_only_custom_meanings and "☑" or "☐"
        table.insert(display_controls, makeRoundedButton{
            text = "  " .. only_custom_mark .. "  "
                .. self.plugin:getTranslation("show_only_custom_meanings"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleShowOnlyCustomMeanings()
                reopen(4)
            end,
        })
        table.insert(display_controls, VerticalSpan:new{ width = Size.span.vertical_default })
        local book_mark = self.plugin.disable_view_in_book and "☑" or "☐"
        table.insert(display_controls, makeRoundedButton{
            text = "  " .. book_mark .. "  " .. self.plugin:getTranslation("disable_view_in_book"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleViewInBookButton()
                reopen(4)
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
                reopen(5)
            end,
        }
        local warning_disabled_mark = self.plugin.disable_unsaved_close_warning and "☑" or "☐"
        local btn_unsaved_warning = makeRoundedButton{
            text = "  " .. warning_disabled_mark .. "  "
                .. self.plugin:getTranslation("disable_unsaved_close_warning"),
            width = card_inner_w,
            callback = function()
                self.plugin:toggleUnsavedCloseWarning()
                reopen(5)
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
                                setTarotDirty(self.plugin or self)
                            end,
                        }
                        UIManager:show(second_confirm)
                    end,
                }
                UIManager:show(first_confirm)
                setTarotDirty(self.plugin or self)
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

    local footer = makeFullscreenFooter(iw, VerticalGroup:new{
        align = "center",
        nav_row,
        VerticalSpan:new{ width = Size.span.vertical_default },
        makeTransparentTextButton{
            text = self.plugin:getTranslation("close"),
            width = math.floor(iw * 0.40),
            callback = function()
                self:closeAndMaybeRefreshHome()
            end,
        },
    })

    self[1] = makeFullscreenScaffold{
        layout = layout,
        header = header_w,
        body = rows,
        footer = footer,
    }
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           SEÇÃO 10: DIÁLOGO DO LIVRO DE CARTAS (CardBookDialog)             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local CardBookDialog = InputContainer:extend{
    plugin = nil,
    card_list = nil,
    current_index = 1,
    parent_callback = nil,
    deck_is_lenormand = nil,
}

function CardBookDialog:init()
    local layout = getFullscreenLayout()
    local iw  = layout.content_w

    local card = self.card_list[self.current_index]
    local deck_is_lenormand = self.deck_is_lenormand
    if deck_is_lenormand == nil then
        deck_is_lenormand = card and card.symbol ~= nil
    end
    self.deck_is_lenormand = deck_is_lenormand == true

    local name_text = T(card.name)
    local header_w = makeSectionHeader(
        self.plugin:getTranslation("card_book"),
        iw,
        name_text
    )

    -- Imagem à esquerda, informações à direita. A imagem é mantida compacta
    -- para sobrar uma área rolável grande para significados longos e grifos.
    local default_w, default_h = self.plugin:getDefaultCardSize(card)
    local img_w = math.floor(default_w * 2/3)
    local img_h = math.floor(default_h * 2/3)
    local img_widget = self.plugin:getCardImageWidget(card, img_w, img_h)
    local right_col_w = iw - img_w - Size.span.horizontal_default
    if right_col_w < math.floor(iw * 0.38) then
        right_col_w = math.floor(iw * 0.38)
        img_w = math.floor((iw - right_col_w - Size.span.horizontal_default) * 0.95)
        img_h = math.floor(img_w * (default_h / math.max(1, default_w)))
        img_widget = self.plugin:getCardImageWidget(card, img_w, img_h)
    end

    local right_col = VerticalGroup:new{ align = "left" }
    local function addInfoField(label, value)
        table.insert(right_col, TextWidget:new{
            text      = label .. ":",
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = right_col_w,
            alignment = "left",
        })
        table.insert(right_col, TextBoxWidget:new{
            text      = value,
            face      = Font:getFace("cfont"),
            width     = right_col_w,
            alignment = "left",
        })
        table.insert(right_col, VerticalSpan:new{ width = Size.span.vertical_small })
    end

    if card.keywords then
        addInfoField(self.plugin:getTranslation("keywords_label"), T(card.keywords))
    end
    if card.planet then
        addInfoField(self.plugin:getTranslation("planet_sign_label"), T(card.planet))
    end
    if card.timing then
        addInfoField(self.plugin:getTranslation("timing_label"), T(card.timing))
    end

    local image_info_row = HorizontalGroup:new{
        align = "top",
        img_widget,
        HorizontalSpan:new{ width = Size.span.horizontal_default },
        right_col,
    }

    -- Navegação entre cartas no rodapé.
    local nav_row
    if #self.card_list > 1 then
        local btn_prev = makeRoundedButton{
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
                        deck_is_lenormand = self.deck_is_lenormand,
                    })
                    setTarotDirty(self.plugin or self)
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

        local btn_next = makeRoundedButton{
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
                        deck_is_lenormand = self.deck_is_lenormand,
                    })
                    setTarotDirty(self.plugin or self)
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

    local btn_back = makeTransparentTextButton{
        text     = self.plugin:getTranslation("back"),
        width    = math.floor(iw * 0.40),
        callback = function()
            UIManager:close(self)
            if self.parent_callback then
                self.parent_callback()
            end
            setTarotDirty(self.plugin or self)
        end,
    }

    local footer_content = VerticalGroup:new{ align = "center" }
    if nav_row then
        table.insert(footer_content, nav_row)
        table.insert(footer_content, VerticalSpan:new{ width = Size.span.vertical_default })
    end
    table.insert(footer_content, btn_back)
    local footer_w = makeFullscreenFooter(iw, footer_content)

    local header_h = header_w:getSize().h
    local footer_h = footer_w:getSize().h
    local image_h = image_info_row:getSize().h
    local scroll_h = layout.safe_h
        - header_h
        - footer_h
        - image_h
        - Size.span.vertical_default * 5
    if scroll_h < math.floor(layout.safe_h * 0.38) then
        scroll_h = math.floor(layout.safe_h * 0.38)
    end
    if scroll_h < 120 then scroll_h = 120 end

    -- O Livro de Cartas usa ScrollableContainer com widgets reais, em vez de
    -- texto puro, para permitir rótulos em cinza como "Upright", "Reversed" e
    -- "Significado Pessoal" sem perder rolagem em telas pequenas.
    local meanings_content = VerticalGroup:new{ align = "left" }
    local function addMutedLabel(text)
        table.insert(meanings_content, TextWidget:new{
            text = text,
            face = Font:getFace("smalltfont"),
            bold = true,
            fgcolor = Blitbuffer.gray(0.5),
            max_width = iw,
            alignment = "left",
        })
        table.insert(meanings_content, VerticalSpan:new{ width = Size.span.vertical_small })
    end
    local function addMeaningText(text)
        text = journalTrim(text)
        if text == "" then return end
        table.insert(meanings_content, TextBoxWidget:new{
            text = text,
            face = Font:getFace("cfont"),
            width = iw,
            alignment = "left",
        })
        table.insert(meanings_content, VerticalSpan:new{ width = Size.span.vertical_default })
    end
    local function addSection(title, content, custom_entries)
        local has_custom = custom_entries and #custom_entries > 0
        local show_only_custom = has_custom and self.plugin.show_only_custom_meanings == true
        addMutedLabel(title)
        if not show_only_custom then
            addMeaningText(content)
        end
        if has_custom then
            addMutedLabel(self.plugin:getTranslation("personal_meanings"))
            addMeaningText(self.plugin:formatCustomMeaningEntries(custom_entries, true))
        end
        table.insert(meanings_content, VerticalSpan:new{ width = Size.span.vertical_small })
    end

    addSection(
        self.plugin:getTranslation("upright"),
        T(card.meaning),
        self.plugin:getCustomMeaningsForCard(card, deck_is_lenormand, "upright")
    )

    if not deck_is_lenormand and card.reversed_meaning then
        addSection(
            self.plugin:getTranslation("reversed"),
            T(card.reversed_meaning),
            self.plugin:getCustomMeaningsForCard(card, false, "reversed")
        )
    end

    local meanings_scroll = ScrollableContainer:new{
        dimen = Geom:new{ x = 0, y = 0, w = iw, h = scroll_h },
        meanings_content,
    }
    self.cropping_widget = meanings_scroll

    local body = VerticalGroup:new{
        align = "center",
        image_info_row,
        VerticalSpan:new{ width = Size.span.vertical_default },
        meanings_scroll,
    }

    self[1] = makeFullscreenScaffold{
        layout = layout,
        header = header_w,
        body = body,
        footer = footer_w,
    }
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
    setTarotDirty(self.plugin or self)
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
    local deck_card_w = math.floor(iw * 0.92)
    local deck_card_inner_w = deck_card_w - Size.padding.default * 2
    local selector_w = math.floor((deck_card_inner_w - column_gap) / 2)
    local column_w = math.floor((iw - column_gap) / 2)

    -- Seletor contextual Tarot | Lenormand. Agora fica dentro do mesmo box de
    -- Tiragens, separando visualmente a escolha do baralho das ações do Livro.
    local btn_tarot_tab = makeRoundedButton{
        text = (self.book_use_lenormand and "○ " or "● ")
            .. self.plugin:getTranslation("tarot_deck"),
        width = selector_w,
        callback = function()
            self:openBookDeck(false)
        end,
    }

    local btn_lenormand_tab = makeRoundedButton{
        text = (self.book_use_lenormand and "● " or "○ ")
            .. self.plugin:getTranslation("lenormand_deck"),
        width = selector_w,
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

    local deck_box = makeSettingsCard(
        self.plugin:getTranslation("deck_type"),
        deck_selector,
        deck_card_w
    )

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
        local btn_all_lenormand = makeRoundedButton{
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
        local btn_all_tarot = makeRoundedButton{
            text = self.plugin:getTranslation("all_cards"),
            width = column_w,
            radius = getTarotButtonRadius(),
            callback = function()
                UIManager:close(self)
                self:showCardList(FULL_DECK)
            end,
        }

        local btn_major = makeRoundedButton{
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

        local btn_minor = makeRoundedButton{
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

    local btn_edit_custom = makeTransparentTextButton{
        text = self.plugin:getTranslation("edit_custom_meanings"),
        width = math.floor(iw * 0.48),
        callback = function()
            -- Mantém o Livro de Cartas na tela enquanto o aviso/editor é
            -- preparado. O editor fecha esta tela de forma segura depois,
            -- evitando tanto o salto visual para a Home quanto o crash causado
            -- por abrir um menu novo e fechar o antigo no mesmo callback.
            self.plugin:showCustomMeaningEditorStart(self)
        end,
    }

    local btn_close = makeTransparentTextButton{
        text = self.plugin:getTranslation("close"),
        width = math.floor(iw * 0.36),
        callback = function()
            UIManager:close(self)
            setTarotDirty(self.plugin or self)
        end,
    }

    local footer_actions = HorizontalGroup:new{
        align = "center",
        btn_edit_custom,
        HorizontalSpan:new{ width = math.floor(iw * 0.08) },
        btn_close,
    }

    local body = VerticalGroup:new{
        align = "center",
        deck_box,
        VerticalSpan:new{ width = Size.span.vertical_large },
        btn_search,
        VerticalSpan:new{ width = Size.span.vertical_large },
        deck_content,
    }

    self[1] = makeFullscreenScaffold{
        layout = layout,
        header = header_w,
        body = body,
        footer = makeFullscreenFooter(iw, footer_actions),
    }
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
    setTarotDirty(self.plugin or self)
end

function CardBookMenu:showNoSearchResults()
    local layout = getFullscreenLayout()
    local iw = layout.content_w

    local btn_back = makeTransparentTextButton{
        text = self.plugin:getTranslation("back"),
        width = math.floor(iw * 0.40),
        callback = function()
            UIManager:close(self.no_results_dialog)
            setTarotDirty(self.plugin or self)
        end,
    }

    local body = VerticalGroup:new{
        align = "center",
        TextWidget:new{
            text = self.plugin:getTranslation("no_results"),
            face = Font:getFace("cfont"),
            bold = true,
            max_width = iw,
            alignment = "center",
        },
    }

    self.no_results_dialog = makeFullscreenScaffold{
        layout = layout,
        title = self:getBookSearchTitle(),
        body = body,
        footer = makeFullscreenFooter(iw, btn_back),
    }
    UIManager:show(self.no_results_dialog)
    setTarotDirty(self.plugin or self)
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
            deck_is_lenormand = false,
            parent_callback = function()
                UIManager:show(CardBookMenu:new{
                    plugin = self.plugin,
                    book_use_lenormand = false,
                })
            end,
        })
        setTarotDirty(self.plugin or self)
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
        local btn_suit = makeRoundedButton{
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
        local btn_all_minor = makeRoundedButton{
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
                setTarotDirty(self.plugin or self)
            end,
        }

        local body = VerticalGroup:new{
            align = "center",
            self:makeCountLabel(56, iw),
            VerticalSpan:new{ width = Size.span.vertical_large },
            btn_all_minor,
            VerticalSpan:new{ width = Size.span.vertical_small },
            self:makeCountLabel(56, iw),
            VerticalSpan:new{ width = Size.span.vertical_large },
            row1,
            VerticalSpan:new{ width = Size.span.vertical_large },
            row2,
        }

        self[1] = makeFullscreenScaffold{
            layout = layout,
            title = self.plugin:getTranslation("minor_arcana"),
            body = body,
            footer = makeFullscreenFooter(iw, btn_back),
        }
    end

    UIManager:show(MinorArcanaMenu:new{
        plugin = self.plugin,
    })
    setTarotDirty(self.plugin or self)
end

function CardBookMenu:showCardList(cards)
    local book_use_lenormand = self.book_use_lenormand

    UIManager:show(CardBookDialog:new{
        plugin = self.plugin,
        card_list = cards,
        current_index = 1,
        deck_is_lenormand = book_use_lenormand,
        parent_callback = function()
            UIManager:show(CardBookMenu:new{
                plugin = self.plugin,
                book_use_lenormand = book_use_lenormand,
            })
        end,
    })
    setTarotDirty(self.plugin or self)
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
    setTarotDirty(self.plugin or self)
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

    setTarotDirty(self.plugin or self)
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
            setTarotDirty(self.plugin or self)
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
                setTarotDirty(self.plugin or self)
            end,
        }

        local body = VerticalGroup:new{
            align = "center",
            deck_box,
        }

        local footer = makeFullscreenFooter(iw, VerticalGroup:new{
            align = "center",
            actions_row,
            VerticalSpan:new{ width = Size.span.vertical_default },
            btn_close,
        })

        self[1] = makeFullscreenScaffold{
            layout = layout,
            title = self.plugin:getTranslation("spreads"),
            body = body,
            footer = footer,
        }
    end

    UIManager:show(SpreadsDialog:new{ plugin = self })
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:showSettings(parent_dialog)
    UIManager:show(SettingsDialog:new{
        plugin = self,
        parent_dialog = parent_dialog,
    })
    setTarotDirty(self.plugin or self)
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
            setTarotDirty(self.plugin or self)
        end,
    }

    self.about_dialog = makeFullscreenScaffold{
        layout = layout,
        title = self:getTranslation("about"),
        body = textbox,
        footer = makeFullscreenFooter(iw, btn_close),
    }

    UIManager:show(self.about_dialog)
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:showCardBook()
    UIManager:show(CardBookMenu:new{ plugin = self })
    setTarotDirty(self.plugin or self)
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
        deck_is_lenormand = deck_is_lenormand,
        parent_callback = function()
            setTarotDirty(self.plugin or self)
        end,
    })
    setTarotDirty(self.plugin or self)
end

function TarotPlugin:showDrawCards()
    local deck_is_lenormand = self.use_lenormand == true
    -- A tiragem começa com a grade 4×4 vazia. Cada toque num espaço livre
    -- sorteia e posiciona uma carta diretamente naquele local.
    local cards = {}

    local on_new_func = function()
        self:showDrawCards()
    end

    UIManager:show(HiddenCardDialog:new{
        plugin = self,
        cards = cards,
        on_new = on_new_func,
        is_daily = false,
        title_label = self:getTranslation("draw_cards"),
        allow_add_card = true,
        max_cards = 16,
        deck_is_lenormand = deck_is_lenormand,
        show_opening_hint = true,
    })
    setTarotDirty(self.plugin or self)
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
        is_revealed = self.daily_card_always_revealed == true or revealed_date == today,
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
    setTarotDirty(self.plugin or self)
    
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
                    setTarotDirty(self.plugin or self)
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
        setTarotDirty(self.plugin or self)
    end)
end

return TarotPlugin

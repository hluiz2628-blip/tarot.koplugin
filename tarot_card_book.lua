-- Livro de Cartas: carta detalhada, busca, Tarot/Lenormand e Arcanos Menores.

local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local OverlapGroup = require("ui/widget/overlapgroup")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local M = {}

function M.create(deps)
    deps = deps or {}
    local T = assert(deps.T, "translator is required")
    local MAJOR_ARCANA = assert(deps.MAJOR_ARCANA, "MAJOR_ARCANA is required")
    local MINOR_ARCANA = assert(deps.MINOR_ARCANA, "MINOR_ARCANA is required")
    local FULL_DECK = assert(deps.FULL_DECK, "FULL_DECK is required")
    local LENORMAND_DECK = assert(deps.LENORMAND_DECK, "LENORMAND_DECK is required")
    local journalTrim = assert(deps.journalTrim, "journalTrim is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local makeFullscreenFooter = assert(deps.makeFullscreenFooter, "makeFullscreenFooter is required")
    local makeSectionHeader = assert(deps.makeSectionHeader, "makeSectionHeader is required")
    local makeTopBackIconButton = assert(deps.makeTopBackIconButton, "makeTopBackIconButton is required")
    local makeFloatingIconButton = assert(deps.makeFloatingIconButton, "makeFloatingIconButton is required")
    local makeRoundedButton = assert(deps.makeRoundedButton, "makeRoundedButton is required")
    local makeSettingsCard = assert(deps.makeSettingsCard, "makeSettingsCard is required")
    local getTarotButtonRadius = assert(deps.getTarotButtonRadius, "getTarotButtonRadius is required")
    local addHorizontalSwipeNavigation = assert(deps.addHorizontalSwipeNavigation, "addHorizontalSwipeNavigation is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

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
        self.card_list = type(self.card_list) == "table" and self.card_list or {}
        if #self.card_list == 0 then
            local fullscreen_scaffold = makeFullscreenScaffold{
                layout = layout,
                title = self.plugin:getTranslation("card_book"),
                body = TextWidget:new{
                    text = self.plugin:getTranslation("no_results"),
                    face = Font:getFace("cfont"),
                    max_width = iw,
                    alignment = "center",
                },
            }
            self[1] = OverlapGroup:new{
                dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
                fullscreen_scaffold,
                makeTopBackIconButton(self.plugin, layout, function()
                    UIManager:close(self)
                    if self.parent_callback then
                        self.parent_callback()
                    end
                    setTarotDirty(self.plugin or self)
                end),
            }
            return
        end
        if self.current_index < 1 then
            self.current_index = 1
        elseif self.current_index > #self.card_list then
            self.current_index = #self.card_list
        end

        local card = self.card_list[self.current_index]
        if type(card) ~= "table" then
            self.current_index = 1
            card = self.card_list[self.current_index]
        end
        if type(card) ~= "table" then
            return
        end
        local deck_is_lenormand = self.deck_is_lenormand
        if deck_is_lenormand == nil then
            deck_is_lenormand = card and card.symbol ~= nil
        end
        self.deck_is_lenormand = deck_is_lenormand == true
        local card_pin_item = self.plugin:makeCardPinItem(card, self.deck_is_lenormand)

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
        local function showCardBookAt(index)
            if index < 1 or index > #self.card_list then return end
            UIManager:show(CardBookDialog:new{
                plugin = self.plugin,
                card_list = self.card_list,
                current_index = index,
                parent_callback = self.parent_callback,
                deck_is_lenormand = self.deck_is_lenormand,
            })
            setTarotDirty(self.plugin or self)
        end
        local function reopenCardBookAt(index)
            UIManager:close(self)
            showCardBookAt(index)
        end

        if #self.card_list > 1 then
            local btn_prev = makeRoundedButton{
                text     = self.plugin:getTranslation("prev"),
                width    = math.floor(iw * 0.30),
                radius   = getTarotButtonRadius(),
                enabled  = self.current_index > 1,
                callback = function()
                    reopenCardBookAt(self.current_index - 1)
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
                    reopenCardBookAt(self.current_index + 1)
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

        local footer_w
        if nav_row then
            local footer_content = VerticalGroup:new{ align = "center" }
            table.insert(footer_content, nav_row)
            footer_w = makeFullscreenFooter(iw, footer_content)
        end

        local header_h = header_w:getSize().h
        local footer_h = footer_w and footer_w:getSize().h or 0
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

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            header = header_w,
            body = body,
            footer = footer_w,
        }
        local is_pinned = self.plugin:isPinnedItem(card_pin_item)
        self[1] = OverlapGroup:new{
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
            makeTopBackIconButton(self.plugin, layout, function()
                UIManager:close(self)
                if self.parent_callback then
                    self.parent_callback()
                end
                setTarotDirty(self.plugin or self)
            end),
            makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = is_pinned and "pin-filled" or "pin",
                fallback_text = is_pinned and "●" or "○",
                side = "left",
                slot = 1,
                callback = function()
                    self.plugin:togglePinnedItem(card_pin_item)
                    reopenCardBookAt(self.current_index)
                end,
            },
            makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = "pen",
                fallback_text = self.plugin:getTranslation("edit_custom_meanings"),
                callback = function()
                    self.plugin:showCustomMeaningEditorForCard(card, self.deck_is_lenormand, function()
                        showCardBookAt(self.current_index)
                    end, {
                        layout = layout,
                        parent_dialog = self,
                        side = "right",
                        slot = 0,
                    })
                end,
            },
        }

        addHorizontalSwipeNavigation(self, "tarot_card_book_swipe_nav",
            self.current_index > 1 and function()
                reopenCardBookAt(self.current_index - 1)
            end or nil,
            self.current_index < #self.card_list and function()
                reopenCardBookAt(self.current_index + 1)
            end or nil
        )
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
        local header_w = makeSectionHeader(
            self.plugin:getTranslation("card_book"),
            iw,
            nil,
            deck_box,
            false
        )

        local deck_content = VerticalGroup:new{ align = "center" }

        if self.book_use_lenormand then
            -- Lenormand possui uma única coleção completa de 36 cartas.
            local lenormand_button_w = math.floor(iw * 0.50)
            local btn_all_lenormand = makeRoundedButton{
                text = self.plugin:getTranslation("all_cards"),
                width = lenormand_button_w,
                radius = getTarotButtonRadius(),
                callback = function()
                    UIManager:close(self)
                    self:showCardList(LENORMAND_DECK)
                end,
            }

            table.insert(deck_content, btn_all_lenormand)
            table.insert(deck_content, VerticalSpan:new{ width = Size.span.vertical_small })
            table.insert(deck_content, self:makeCardCountLabel(36, lenormand_button_w))
        else
            -- Tarot usa no máximo duas colunas para evitar textos comprimidos em
            -- Kindles e celulares estreitos.
            local btn_all_tarot = makeRoundedButton{
                text = self.plugin:getTranslation("all_cards"),
                width = iw,
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
                self:makeCardCountLabel(78, iw),
            }

            local major_group = VerticalGroup:new{
                align = "center",
                btn_major,
                VerticalSpan:new{ width = Size.span.vertical_small },
                self:makeCardCountLabel(22, column_w),
            }

            local btn_minor = makeRoundedButton{
                text = self.plugin:getTranslation("minor_arcana"),
                width = column_w,
                radius = getTarotButtonRadius(),
                callback = function()
                    UIManager:close(self)
                    self:showMinorArcanaMenu()
                end,
            }

            local minor_group = VerticalGroup:new{
                align = "center",
                btn_minor,
                VerticalSpan:new{ width = Size.span.vertical_small },
                self:makeCardCountLabel(56, column_w),
            }

            local tarot_categories_row = HorizontalGroup:new{
                align = "center",
                major_group,
                HorizontalSpan:new{ width = column_gap },
                minor_group,
            }

            table.insert(deck_content, tarot_categories_row)
            table.insert(deck_content, VerticalSpan:new{ width = Size.span.vertical_large })
            table.insert(deck_content, all_tarot_group)
        end

        local body = VerticalGroup:new{
            align = "center",
            deck_content,
        }

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            header = header_w,
            body = body,
        }

        self[1] = OverlapGroup:new{
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
            makeTopBackIconButton(self.plugin, layout, function()
                UIManager:close(self)
                setTarotDirty(self.plugin or self)
            end),
            makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = "search",
                fallback_text = self:getBookSearchTitle(),
                callback = function()
                    self:showSearchInput(self:getSelectedBookDeck())
                end,
            },
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

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            title = self:getBookSearchTitle(),
            body = body,
        }
        self.no_results_dialog = OverlapGroup:new{
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
            makeTopBackIconButton(self.plugin, layout, function()
                UIManager:close(self.no_results_dialog)
                setTarotDirty(self.plugin or self)
            end),
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

            local body = VerticalGroup:new{
                align = "center",
                btn_all_minor,
                VerticalSpan:new{ width = Size.span.vertical_small },
                self:makeCountLabel(56, iw),
                VerticalSpan:new{ width = Size.span.vertical_large },
                row1,
                VerticalSpan:new{ width = Size.span.vertical_large },
                row2,
            }

            local fullscreen_scaffold = makeFullscreenScaffold{
                layout = layout,
                title = self.plugin:getTranslation("minor_arcana"),
                body = body,
            }
            self[1] = OverlapGroup:new{
                dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
                fullscreen_scaffold,
                makeTopBackIconButton(self.plugin, layout, function()
                    UIManager:close(self)
                    UIManager:show(CardBookMenu:new{
                        plugin = self.plugin,
                        book_use_lenormand = false,
                    })
                    setTarotDirty(self.plugin or self)
                end),
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


    return {
        CardBookDialog = CardBookDialog,
        CardBookMenu = CardBookMenu,
    }
end

return M

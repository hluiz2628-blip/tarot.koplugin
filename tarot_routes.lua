-- Rotas e orquestração: abre telas principais, tiragens e Carta Diária.

local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")

local M = {}

function M.register(deps)
    deps = deps or {}
    local TarotPlugin = assert(deps.TarotPlugin, "TarotPlugin is required")
    local TarotHomeDialog = assert(deps.TarotHomeDialog, "TarotHomeDialog is required")
    local PhysicalDeckDialog = assert(deps.PhysicalDeckDialog, "PhysicalDeckDialog is required")
    local HiddenCardDialog = assert(deps.HiddenCardDialog, "HiddenCardDialog is required")
    local CardDialog = assert(deps.CardDialog, "CardDialog is required")
    local SettingsDialog = assert(deps.SettingsDialog, "SettingsDialog is required")
    local CardBookDialog = assert(deps.CardBookDialog, "CardBookDialog is required")
    local CardBookMenu = assert(deps.CardBookMenu, "CardBookMenu is required")
    local MAJOR_ARCANA = assert(deps.MAJOR_ARCANA, "MAJOR_ARCANA is required")
    local FULL_DECK = assert(deps.FULL_DECK, "FULL_DECK is required")
    local LENORMAND_DECK = assert(deps.LENORMAND_DECK, "LENORMAND_DECK is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local makeRoundedButton = assert(deps.makeRoundedButton, "makeRoundedButton is required")
    local makeSettingsCard = assert(deps.makeSettingsCard, "makeSettingsCard is required")
    local makeSectionHeader = assert(deps.makeSectionHeader, "makeSectionHeader is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local makeTopBackIconButton = assert(deps.makeTopBackIconButton, "makeTopBackIconButton is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

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
            local header_w = makeSectionHeader(
                self.plugin:getTranslation("spreads"),
                iw,
                nil,
                deck_box,
                false
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

            local body = VerticalGroup:new{
                align = "center",
                actions_row,
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

    function TarotPlugin:showAboutDialog(options)
        options = options or {}
        local layout = getFullscreenLayout()
        local iw  = layout.content_w

        local text = self:getTranslation("about_text")
        local textbox = TextBoxWidget:new{
            text      = text,
            face      = Font:getFace("cfont"),
            width     = iw,
            alignment = "left",
        }

        local function goBackFromAbout()
            UIManager:close(self.about_dialog)
            if type(options.on_back) == "function" then
                options.on_back()
                return
            end
            setTarotDirty(self.plugin or self)
        end

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            title = self:getTranslation("about"),
            body = textbox,
        }
        self.about_dialog = OverlapGroup:new{
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
            makeTopBackIconButton(self, layout, goBackFromAbout),
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


end

return M

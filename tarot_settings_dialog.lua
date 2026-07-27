-- Configurações: diálogo paginado com preferências e restauração.

local Blitbuffer = require("ffi/blitbuffer")
local ConfirmBox = require("ui/widget/confirmbox")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
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
    local TarotHomeDialog = assert(deps.TarotHomeDialog, "TarotHomeDialog is required")
    local getFullscreenLayout = assert(deps.getFullscreenLayout, "getFullscreenLayout is required")
    local makeSectionHeader = assert(deps.makeSectionHeader, "makeSectionHeader is required")
    local makeSettingsToggleButton = assert(deps.makeSettingsToggleButton, "makeSettingsToggleButton is required")
    local makeMutedText = assert(deps.makeMutedText, "makeMutedText is required")
    local makeTarotDivider = assert(deps.makeTarotDivider, "makeTarotDivider is required")
    local makeSettingsCard = assert(deps.makeSettingsCard, "makeSettingsCard is required")
    local makeInlineIconTextButton = assert(deps.makeInlineIconTextButton, "makeInlineIconTextButton is required")
    local makeRoundedButton = assert(deps.makeRoundedButton, "makeRoundedButton is required")
    local makeFullscreenFooter = assert(deps.makeFullscreenFooter, "makeFullscreenFooter is required")
    local makeFullscreenScaffold = assert(deps.makeFullscreenScaffold, "makeFullscreenScaffold is required")
    local makeTopBackIconButton = assert(deps.makeTopBackIconButton, "makeTopBackIconButton is required")
    local makeFloatingIconButton = assert(deps.makeFloatingIconButton, "makeFloatingIconButton is required")
    local addHorizontalSwipeNavigation = assert(deps.addHorizontalSwipeNavigation, "addHorizontalSwipeNavigation is required")
    local setTarotDirty = assert(deps.setTarotDirty, "setTarotDirty is required")

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
        local page_count = 6
        self.page = tonumber(self.page) or 1
        if self.page < 1 then self.page = 1 end
        if self.page > page_count then self.page = page_count end

        local page_titles = {
            self.plugin:getTranslation("daily_card"),
            self.plugin:getTranslation("deck_and_draw"),
            self.plugin:getTranslation("spread_meanings"),
            self.plugin:getTranslation("spread_display"),
            self.plugin:getTranslation("journal_saving"),
            self.plugin:getTranslation("system"),
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
            local function dailyDeckButton(mode, label_key)
                return makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation(label_key),
                    checked = self.plugin.daily_card_deck_mode == mode,
                    width = card_inner_w,
                    callback = function()
                        if self.plugin.daily_card_deck_mode ~= mode then
                            self.home_needs_refresh = true
                        end
                        self.plugin:setDailyCardDeckMode(mode)
                        reopen(1)
                    end,
                }
            end
            local hide_name_button = makeSettingsToggleButton{
                plugin = self.plugin,
                text = self.plugin:getTranslation("hide_daily_card_name"),
                checked = self.plugin.hide_daily_card_name,
                width = card_inner_w,
                callback = function()
                    self.home_needs_refresh = true
                    self.plugin:toggleHideDailyCardName()
                    reopen(1)
                end,
            }
            local daily_always_button = makeSettingsToggleButton{
                plugin = self.plugin,
                text = self.plugin:getTranslation("daily_card_always_revealed"),
                checked = self.plugin.daily_card_always_revealed,
                width = card_inner_w,
                callback = function()
                    self.home_needs_refresh = true
                    self.plugin:toggleDailyCardAlwaysRevealed()
                    reopen(1)
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


        elseif self.page == 2 then
            local btn_rev = makeSettingsToggleButton{
                plugin = self.plugin,
                text = self.plugin:getTranslation("allow_reversed_desc"),
                checked = self.plugin.allow_reversed,
                width = card_inner_w,
                callback = function()
                    self.plugin:toggleReversed()
                    reopen(2)
                end,
            }
            local btn_maj = makeSettingsToggleButton{
                plugin = self.plugin,
                text = self.plugin:getTranslation("major_only_desc"),
                checked = self.plugin.major_only,
                width = card_inner_w,
                callback = function()
                    self.plugin:toggleMajorOnly()
                    reopen(2)
                end,
            }
            local tarot_options_body = VerticalGroup:new{
                align = "center",
                btn_rev,
                VerticalSpan:new{ width = Size.span.vertical_default },
                btn_maj,
            }
            table.insert(rows, makeSettingsCard(
                self.plugin:getTranslation("deck_and_draw"),
                tarot_options_body,
                card_w
            ))


        elseif self.page == 3 then
            local function modeButton(mode, label_key)
                return makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation(label_key),
                    checked = self.plugin.spread_meaning_mode == mode,
                    width = card_inner_w,
                    callback = function()
                        self.plugin:setSpreadMeaningMode(mode)
                        reopen(3)
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
            table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })

            local custom_body = VerticalGroup:new{
                align = "center",
                makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation("show_only_custom_meanings"),
                    checked = self.plugin.show_only_custom_meanings,
                    width = card_inner_w,
                    callback = function()
                        self.plugin:toggleShowOnlyCustomMeanings()
                        reopen(3)
                    end,
                },
            }
            table.insert(rows, makeSettingsCard(
                self.plugin:getTranslation("personal_meanings"),
                custom_body,
                card_w
            ))


        elseif self.page == 4 then
            local function sizeButton(size, label_key)
                return makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation(label_key),
                    checked = self.plugin.meaning_text_size == size,
                    width = card_inner_w,
                    callback = function()
                        self.plugin:setMeaningTextSize(size)
                        reopen(4)
                    end,
                }
            end
            local size_body = VerticalGroup:new{
                align = "center",
                sizeButton("compact", "text_size_compact"),
                VerticalSpan:new{ width = Size.span.vertical_small },
                sizeButton("standard", "text_size_standard"),
                VerticalSpan:new{ width = Size.span.vertical_small },
                sizeButton("large", "text_size_large"),
            }
            table.insert(rows, makeSettingsCard(
                self.plugin:getTranslation("meaning_text_size"),
                size_body,
                card_w
            ))
            table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })

            local display_controls = VerticalGroup:new{
                align = "center",
                makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation("show_reversed_label"),
                    checked = self.plugin.show_reversed_label,
                    width = card_inner_w,
                    callback = function()
                        self.plugin:toggleShowReversedLabel()
                        reopen(4)
                    end,
                },
                VerticalSpan:new{ width = Size.span.vertical_default },
                makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation("spread_cards_always_revealed"),
                    checked = self.plugin.spread_cards_always_revealed,
                    width = card_inner_w,
                    callback = function()
                        self.plugin:toggleSpreadCardsAlwaysRevealed()
                        reopen(4)
                    end,
                },
                VerticalSpan:new{ width = Size.span.vertical_default },
                makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation("show_view_in_book"),
                    checked = not self.plugin.disable_view_in_book,
                    width = card_inner_w,
                    callback = function()
                        self.plugin:toggleViewInBookButton()
                        reopen(4)
                    end,
                },
            }
            table.insert(rows, makeSettingsCard(
                self.plugin:getTranslation("spread_display"),
                display_controls,
                card_w
            ))


        elseif self.page == 5 then
            local journal_body = VerticalGroup:new{
                align = "center",
                makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation("auto_save_spreads"),
                    checked = self.plugin.auto_save_spreads,
                    width = card_inner_w,
                    callback = function()
                        self.plugin:toggleAutoSaveSpreads()
                        reopen(5)
                    end,
                },
                VerticalSpan:new{ width = Size.span.vertical_default },
                makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation("disable_unsaved_close_warning"),
                    checked = self.plugin.disable_unsaved_close_warning,
                    width = card_inner_w,
                    callback = function()
                        self.plugin:toggleUnsavedCloseWarning()
                        reopen(5)
                    end,
                },
            }
            table.insert(rows, makeSettingsCard(
                self.plugin:getTranslation("journal_saving"),
                journal_body,
                card_w
            ))


        else
            local function refreshModeButton(mode, label_key)
                return makeSettingsToggleButton{
                    plugin = self.plugin,
                    text = self.plugin:getTranslation(label_key),
                    checked = self.plugin.screen_refresh_mode == mode,
                    width = card_inner_w,
                    callback = function()
                        self.plugin:setScreenRefreshMode(mode)
                        reopen(6)
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
            table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })

            local btn_restore = makeInlineIconTextButton{
                plugin = self.plugin,
                icon_name = "danger",
                text = self.plugin:getTranslation("restore_desc"),
                fallback_text = self.plugin:getTranslation("restore_desc"),
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
        })

        local fullscreen_scaffold = makeFullscreenScaffold{
            layout = layout,
            header = header_w,
            body = rows,
            footer = footer,
        }

        self[1] = OverlapGroup:new{
            dimen = Geom:new{ w = layout.screen_w, h = layout.screen_h },
            fullscreen_scaffold,
            makeTopBackIconButton(self.plugin, layout, function()
                self:closeAndMaybeRefreshHome()
            end),
            makeFloatingIconButton{
                plugin = self.plugin,
                layout = layout,
                icon_name = "info",
                fallback_text = self.plugin:getTranslation("about"),
                callback = function()
                    local settings_page = self.page
                    local parent_dialog = self.parent_dialog
                    local home_needs_refresh = self.home_needs_refresh == true
                    UIManager:close(self)
                    self.plugin:showAboutDialog{
                        on_back = function()
                            UIManager:show(SettingsDialog:new{
                                plugin = self.plugin,
                                page = settings_page,
                                parent_dialog = parent_dialog,
                                home_needs_refresh = home_needs_refresh,
                            })
                            setTarotDirty(self.plugin or self)
                        end,
                    }
                end,
            },
        }

        addHorizontalSwipeNavigation(self, "tarot_settings_swipe_nav",
            self.page > 1 and function() reopen(self.page - 1) end or nil,
            self.page < page_count and function() reopen(self.page + 1) end or nil
        )
    end


    return SettingsDialog
end

return M

--[[
    tarot.koplugin — Leitura de Tarot / Tarot Reading
    ==================================================
    Exibe cartas de tarot aleatórias com significados.
    Displays random tarot cards with meanings.

    Compatível com Kindle/e-ink.
    Significados em Português e Inglês.
    Tiragem de 3 cartas com navegação < > entre elas.

    Instalação:
      Copie a pasta tarot.koplugin/ para:
        /sdcard/koreader/plugins/   (Android)
        ~/.config/koreader/plugins/ (Linux/PC)
      Reinicie o KOReader. O item aparece em Menu → Ferramentas.
--]]

-- ── dependências ──────────────────────────────────────────────────────────────
local Blitbuffer       = require("ffi/blitbuffer")
local Button           = require("ui/widget/button")
local CenterContainer  = require("ui/widget/container/centercontainer")
local Font             = require("ui/font")
local FrameContainer   = require("ui/widget/container/framecontainer")
local HorizontalGroup  = require("ui/widget/horizontalgroup")
local HorizontalSpan   = require("ui/widget/horizontalspan")
local InfoMessage      = require("ui/widget/infomessage")
local InputContainer   = require("ui/widget/container/inputcontainer")
local Screen           = require("device").screen
local Size             = require("ui/size")
local TextBoxWidget    = require("ui/widget/textboxwidget")
local TextWidget       = require("ui/widget/textwidget")
local UIManager        = require("ui/uimanager")
local VerticalGroup    = require("ui/widget/verticalgroup")
local VerticalSpan     = require("ui/widget/verticalspan")
local logger           = require("logger")
local util             = require("util")

-- ═════════════════════════════════════════════════════════════════════════════
-- Traduções
-- ═════════════════════════════════════════════════════════════════════════════
local translations = {
    pt = {
        title = "Leitura de Tarot",
        draw_card = "Tirar uma carta",
        draw_three = "Tiragem de 3 cartas",
        settings = "Configurações",
        new = "Novas cartas",
        close = "Fechar",
        prev = "< Ant",
        next = "Próx >",
        language = "Idioma",
        portuguese = "Português",
        english = "English",
        upright = "Posição normal",
        reversed = "Invertida",
        loading = "Embaralhando as cartas...",
        card_count = "Carta %d de %d",
        allow_reversed = "Cartas invertidas",
        allow_reversed_desc = "Permitir que cartas apareçam invertidas",
        major_only = "Apenas Arcanos Maiores",
        major_only_desc = "Sortear apenas os 22 Arcanos Maiores",
        major_arcana = "Arcanos Maiores",
        minor_arcana = "Arcanos Menores",
    },
    en = {
        title = "Tarot Reading",
        draw_card = "Draw a card",
        draw_three = "3 card spread",
        settings = "Settings",
        new = "New cards",
        close = "Close",
        prev = "< Prev",
        next = "Next >",
        language = "Language",
        portuguese = "Português",
        english = "English",
        upright = "Upright",
        reversed = "Reversed",
        loading = "Shuffling the cards...",
        card_count = "Card %d of %d",
        allow_reversed = "Reversed cards",
        allow_reversed_desc = "Allow cards to appear reversed",
        major_only = "Major Arcana only",
        major_only_desc = "Draw only from the 22 Major Arcana",
        major_arcana = "Major Arcana",
        minor_arcana = "Minor Arcana",
    }
}

-- ═════════════════════════════════════════════════════════════════════════════
-- Cartas de Tarot - Arcanos Maiores (22 cartas)
-- ═════════════════════════════════════════════════════════════════════════════
local MAJOR_ARCANA = {
    {
        id = 0, roman = "0",
        name = { pt = "O Louco", en = "The Fool" },
        meaning = {
            pt = "Novos começos. Espontaneidade. Dê um salto de fé. Aventure-se sem medo, o universo o ampara.",
            en = "New beginnings. Spontaneity. Take a leap of faith. Venture without fear, the universe supports you."
        },
        reversed_meaning = {
            pt = "Imprudência. Falta de direção. Pense antes de agir. O risco cego pode trazer consequências.",
            en = "Recklessness. Lack of direction. Think before acting. Blind risk may bring consequences."
        }
    },
    {
        id = 1, roman = "I",
        name = { pt = "O Mago", en = "The Magician" },
        meaning = {
            pt = "Poder pessoal. Habilidade. Você tem tudo que precisa. Manifeste seus desejos com confiança.",
            en = "Personal power. Skill. You have everything you need. Manifest your desires with confidence."
        },
        reversed_meaning = {
            pt = "Manipulação. Talento desperdiçado. Falsidade. Cuidado com ilusões de poder.",
            en = "Manipulation. Wasted talent. Deceit. Beware of illusions of power."
        }
    },
    {
        id = 2, roman = "II",
        name = { pt = "A Sacerdotisa", en = "The High Priestess" },
        meaning = {
            pt = "Intuição. Mistério. Confie na sua voz interior. O conhecimento oculto se revela no silêncio.",
            en = "Intuition. Mystery. Trust your inner voice. Hidden knowledge reveals itself in silence."
        },
        reversed_meaning = {
            pt = "Segredos revelados. Desconexão intuitiva. Silêncio rompido. Ouça sua voz interior novamente.",
            en = "Secrets revealed. Intuitive disconnection. Silence broken. Listen to your inner voice again."
        }
    },
    {
        id = 3, roman = "III",
        name = { pt = "A Imperatriz", en = "The Empress" },
        meaning = {
            pt = "Abundância. Fertilidade. Cuide de si mesmo. A natureza floresce ao seu redor.",
            en = "Abundance. Fertility. Nurture yourself. Nature flourishes around you."
        },
        reversed_meaning = {
            pt = "Negligência. Bloqueio criativo. Dependência. Volte a cuidar do seu jardim interior.",
            en = "Neglect. Creative block. Dependence. Return to tending your inner garden."
        }
    },
    {
        id = 4, roman = "IV",
        name = { pt = "O Imperador", en = "The Emperor" },
        meaning = {
            pt = "Autoridade. Estrutura. Assuma o controle. Liderança firme traz estabilidade.",
            en = "Authority. Structure. Take control. Firm leadership brings stability."
        },
        reversed_meaning = {
            pt = "Tirania. Rigidez. Falta de disciplina. O excesso de controle sufoca.",
            en = "Tyranny. Rigidity. Lack of discipline. Excess control suffocates."
        }
    },
    {
        id = 5, roman = "V",
        name = { pt = "O Hierofante", en = "The Hierophant" },
        meaning = {
            pt = "Tradição. Sabedoria. Busque orientação. Os mestres aparecem quando o discípulo está pronto.",
            en = "Tradition. Wisdom. Seek guidance. Masters appear when the student is ready."
        },
        reversed_meaning = {
            pt = "Rebeldia. Dogma. Questionamento necessário. Romper com tradições pode ser libertador.",
            en = "Rebellion. Dogma. Necessary questioning. Breaking with traditions can be liberating."
        }
    },
    {
        id = 6, roman = "VI",
        name = { pt = "Os Enamorados", en = "The Lovers" },
        meaning = {
            pt = "Amor. Escolha. Harmonia nos relacionamentos. O coração sabe o caminho.",
            en = "Love. Choice. Harmony in relationships. The heart knows the way."
        },
        reversed_meaning = {
            pt = "Conflito. Desequilíbrio. Decisão difícil. Evite escolhas impulsivas no amor.",
            en = "Conflict. Imbalance. Difficult decision. Avoid impulsive choices in love."
        }
    },
    {
        id = 7, roman = "VII",
        name = { pt = "O Carro", en = "The Chariot" },
        meaning = {
            pt = "Vitória. Determinação. Siga em frente com confiança. O triunfo espera os perseverantes.",
            en = "Victory. Determination. Move forward with confidence. Triumph awaits the perseverant."
        },
        reversed_meaning = {
            pt = "Falta de direção. Derrota. Perda de controle. Reavalie sua rota antes de prosseguir.",
            en = "Lack of direction. Defeat. Loss of control. Reevaluate your route before proceeding."
        }
    },
    {
        id = 8, roman = "VIII",
        name = { pt = "A Força", en = "Strength" },
        meaning = {
            pt = "Coragem. Força interior. Domine seus impulsos com gentileza, não com violência.",
            en = "Courage. Inner strength. Master your impulses with kindness, not violence."
        },
        reversed_meaning = {
            pt = "Fraqueza. Insegurança. Falta de autocontrole. A verdadeira força vem da vulnerabilidade.",
            en = "Weakness. Insecurity. Lack of self-control. True strength comes from vulnerability."
        }
    },
    {
        id = 9, roman = "IX",
        name = { pt = "O Eremita", en = "The Hermit" },
        meaning = {
            pt = "Introspecção. Sabedoria interior. Busque o silêncio. A luz que procura está dentro de você.",
            en = "Introspection. Inner wisdom. Seek silence. The light you seek is within you."
        },
        reversed_meaning = {
            pt = "Isolamento. Solidão. Recuse-se a ver a verdade. O retiro prolongado vira fuga.",
            en = "Isolation. Loneliness. Refusing to see the truth. Prolonged retreat becomes escape."
        }
    },
    {
        id = 10, roman = "X",
        name = { pt = "Roda da Fortuna", en = "Wheel of Fortune" },
        meaning = {
            pt = "Mudança. Destino. A sorte está girando a seu favor. Tudo passa, ciclos se renovam.",
            en = "Change. Destiny. Luck is turning in your favor. Everything passes, cycles renew."
        },
        reversed_meaning = {
            pt = "Má sorte. Resistência à mudança. Ciclo negativo. Aceite que nada é permanente.",
            en = "Bad luck. Resistance to change. Negative cycle. Accept that nothing is permanent."
        }
    },
    {
        id = 11, roman = "XI",
        name = { pt = "A Justiça", en = "Justice" },
        meaning = {
            pt = "Equilíbrio. Verdade. A justiça prevalecerá. Colha o que plantou com serenidade.",
            en = "Balance. Truth. Justice will prevail. Reap what you have sown with serenity."
        },
        reversed_meaning = {
            pt = "Injustiça. Desonestidade. Consequências chegando. A balança pesa contra você agora.",
            en = "Injustice. Dishonesty. Consequences coming. The scales weigh against you now."
        }
    },
    {
        id = 12, roman = "XII",
        name = { pt = "O Enforcado", en = "The Hanged Man" },
        meaning = {
            pt = "Sacrifício. Nova perspectiva. Deixe ir, confie. Às vezes parar é avançar.",
            en = "Sacrifice. New perspective. Let go, trust. Sometimes stopping is advancing."
        },
        reversed_meaning = {
            pt = "Estagnação. Adiamento. Resista à mudança. A pausa se tornou paralisia.",
            en = "Stagnation. Procrastination. Resist change. The pause has become paralysis."
        }
    },
    {
        id = 13, roman = "XIII",
        name = { pt = "A Morte", en = "Death" },
        meaning = {
            pt = "Transformação. Fim de um ciclo. Renascimento próximo. O velho morre para o novo nascer.",
            en = "Transformation. End of a cycle. Rebirth near. The old dies so the new can be born."
        },
        reversed_meaning = {
            pt = "Resistência à mudança. Estagnação. Medo do fim. Solte o que já não serve mais.",
            en = "Resistance to change. Stagnation. Fear of endings. Let go of what no longer serves."
        }
    },
    {
        id = 14, roman = "XIV",
        name = { pt = "A Temperança", en = "Temperance" },
        meaning = {
            pt = "Paciência. Moderação. Encontre o equilíbrio. A água encontra seu nível.",
            en = "Patience. Moderation. Find balance. Water finds its level."
        },
        reversed_meaning = {
            pt = "Excesso. Impaciência. Desarmonia. Retorne ao centro, respire fundo.",
            en = "Excess. Impatience. Disharmony. Return to center, breathe deeply."
        }
    },
    {
        id = 15, roman = "XV",
        name = { pt = "O Diabo", en = "The Devil" },
        meaning = {
            pt = "Tentação. Padrões negativos. Liberte-se das correntes. Você tem o poder de se soltar.",
            en = "Temptation. Negative patterns. Free yourself from chains. You have the power to break free."
        },
        reversed_meaning = {
            pt = "Libertação. Quebra de vícios. Recuperação. A luz entra onde havia escuridão.",
            en = "Liberation. Breaking addictions. Recovery. Light enters where darkness once was."
        }
    },
    {
        id = 16, roman = "XVI",
        name = { pt = "A Torre", en = "The Tower" },
        meaning = {
            pt = "Revelação súbita. Ruptura. Reconstrução necessária. O que é falso desmorona.",
            en = "Sudden revelation. Rupture. Necessary reconstruction. What is false crumbles."
        },
        reversed_meaning = {
            pt = "Evitando o desastre. Medo da mudança. Negação. A queda é inevitável, aceite-a.",
            en = "Avoiding disaster. Fear of change. Denial. The fall is inevitable, accept it."
        }
    },
    {
        id = 17, roman = "XVII",
        name = { pt = "A Estrela", en = "The Star" },
        meaning = {
            pt = "Esperança. Fé. Siga sua intuição. A luz o guia na escuridão. Confie no universo.",
            en = "Hope. Faith. Follow your intuition. Light guides you in darkness. Trust the universe."
        },
        reversed_meaning = {
            pt = "Desesperança. Falta de fé. Desconexão espiritual. A luz está lá, você só não a vê.",
            en = "Hopelessness. Lack of faith. Spiritual disconnection. The light is there, you just don't see it."
        }
    },
    {
        id = 18, roman = "XVIII",
        name = { pt = "A Lua", en = "The Moon" },
        meaning = {
            pt = "Ilusão. Intuição. Nem tudo é o que parece. Caminhe com cuidado na penumbra.",
            en = "Illusion. Intuition. Not everything is as it seems. Walk carefully in the twilight."
        },
        reversed_meaning = {
            pt = "Confusão dissipada. Medo superado. Verdade revelada. A névoa está se dissipando.",
            en = "Confusion cleared. Fear overcome. Truth revealed. The fog is lifting."
        }
    },
    {
        id = 19, roman = "XIX",
        name = { pt = "O Sol", en = "The Sun" },
        meaning = {
            pt = "Alegria. Sucesso. Vitalidade. Tudo está iluminado. A felicidade transborda.",
            en = "Joy. Success. Vitality. Everything is illuminated. Happiness overflows."
        },
        reversed_meaning = {
            pt = "Tristeza temporária. Atraso. Falta de entusiasmo. O sol sempre volta a brilhar.",
            en = "Temporary sadness. Delay. Lack of enthusiasm. The sun always shines again."
        }
    },
    {
        id = 20, roman = "XX",
        name = { pt = "O Julgamento", en = "Judgement" },
        meaning = {
            pt = "Renovação. Chamado interior. Hora de despertar. O passado foi perdoado.",
            en = "Renewal. Inner calling. Time to awaken. The past has been forgiven."
        },
        reversed_meaning = {
            pt = "Autocrítica. Arrependimento. Negação do chamado. Liberte-se da culpa.",
            en = "Self-criticism. Regret. Denial of the calling. Free yourself from guilt."
        }
    },
    {
        id = 21, roman = "XXI",
        name = { pt = "O Mundo", en = "The World" },
        meaning = {
            pt = "Completude. Realização. Ciclo concluído com sucesso. O universo celebra com você.",
            en = "Completion. Fulfillment. Cycle successfully concluded. The universe celebrates with you."
        },
        reversed_meaning = {
            pt = "Incompletude. Atraso. Falta de fechamento. Ainda há um passo a dar.",
            en = "Incompleteness. Delay. Lack of closure. There is still one step to take."
        }
    },
}

-- ═════════════════════════════════════════════════════════════════════════════
-- Arcanos Menores (56 cartas)
-- ═════════════════════════════════════════════════════════════════════════════
local MINOR_ARCANA = {}

local suits = {
    { pt = "Paus", en = "Wands", symbol = "|" },
    { pt = "Copas", en = "Cups", symbol = "~" },
    { pt = "Espadas", en = "Swords", symbol = "+" },
    { pt = "Ouros", en = "Pentacles", symbol = "*" },
}

local ranks = {
    { pt = "Ás", en = "Ace" },
    { pt = "Dois", en = "Two" },
    { pt = "Três", en = "Three" },
    { pt = "Quatro", en = "Four" },
    { pt = "Cinco", en = "Five" },
    { pt = "Seis", en = "Six" },
    { pt = "Sete", en = "Seven" },
    { pt = "Oito", en = "Eight" },
    { pt = "Nove", en = "Nine" },
    { pt = "Dez", en = "Ten" },
    { pt = "Pajem", en = "Page" },
    { pt = "Cavaleiro", en = "Knight" },
    { pt = "Rainha", en = "Queen" },
    { pt = "Rei", en = "King" },
}

local suit_meanings = {
    {
        upright = {
            pt = "Energia criativa. Paixão. Iniciativa. Novos projetos ganham força.",
            en = "Creative energy. Passion. Initiative. New projects gain strength."
        },
        reversed = {
            pt = "Falta de direção. Adiamento. Energia dispersa. Reavalie seus objetivos.",
            en = "Lack of direction. Delay. Scattered energy. Reevaluate your goals."
        }
    },
    {
        upright = {
            pt = "Emoções. Amor. Conexões afetivas. Siga seu coração com sabedoria.",
            en = "Emotions. Love. Affective connections. Follow your heart with wisdom."
        },
        reversed = {
            pt = "Emoções reprimidas. Desilusão. Distanciamento. Permita-se sentir.",
            en = "Repressed emotions. Disillusion. Distance. Allow yourself to feel."
        }
    },
    {
        upright = {
            pt = "Clareza mental. Decisões. Comunicação. A verdade corta como espada.",
            en = "Mental clarity. Decisions. Communication. Truth cuts like a sword."
        },
        reversed = {
            pt = "Confusão. Conflito. Palavras ferinas. Pense antes de falar.",
            en = "Confusion. Conflict. Hurtful words. Think before speaking."
        }
    },
    {
        upright = {
            pt = "Prosperidade. Trabalho. Resultados concretos. Colha os frutos do seu esforço.",
            en = "Prosperity. Work. Concrete results. Reap the fruits of your effort."
        },
        reversed = {
            pt = "Perda material. Atraso financeiro. Falta de foco. Reorganize suas finanças.",
            en = "Material loss. Financial delay. Lack of focus. Reorganize your finances."
        }
    },
}

local rank_modifiers = {
    { upright_pt = "Novo ciclo.", upright_en = "New cycle.", reversed_pt = "Oportunidade perdida.", reversed_en = "Missed opportunity." },
    { upright_pt = "Equilíbrio e escolha.", upright_en = "Balance and choice.", reversed_pt = "Indecisão.", reversed_en = "Indecision." },
    { upright_pt = "Crescimento e expansão.", upright_en = "Growth and expansion.", reversed_pt = "Estagnação.", reversed_en = "Stagnation." },
    { upright_pt = "Estabilidade e descanso.", upright_en = "Stability and rest.", reversed_pt = "Instabilidade.", reversed_en = "Instability." },
    { upright_pt = "Conflito e superação.", upright_en = "Conflict and overcoming.", reversed_pt = "Derrota temporária.", reversed_en = "Temporary defeat." },
    { upright_pt = "Harmonia e vitória.", upright_en = "Harmony and victory.", reversed_pt = "Desequilíbrio.", reversed_en = "Imbalance." },
    { upright_pt = "Perseverança.", upright_en = "Perseverance.", reversed_pt = "Desânimo.", reversed_en = "Discouragement." },
    { upright_pt = "Movimento rápido.", upright_en = "Swift movement.", reversed_pt = "Atraso.", reversed_en = "Delay." },
    { upright_pt = "Resiliência e força.", upright_en = "Resilience and strength.", reversed_pt = "Esgotamento.", reversed_en = "Exhaustion." },
    { upright_pt = "Conclusão e abundância.", upright_en = "Completion and abundance.", reversed_pt = "Excesso.", reversed_en = "Excess." },
    { upright_pt = "Mensagem ou convite.", upright_en = "Message or invitation.", reversed_pt = "Más notícias.", reversed_en = "Bad news." },
    { upright_pt = "Ação determinada.", upright_en = "Determined action.", reversed_pt = "Impulsividade.", reversed_en = "Impulsiveness." },
    { upright_pt = "Nutrição e intuição.", upright_en = "Nurturing and intuition.", reversed_pt = "Dependência emocional.", reversed_en = "Emotional dependence." },
    { upright_pt = "Liderança e domínio.", upright_en = "Leadership and mastery.", reversed_pt = "Autoritarismo.", reversed_en = "Authoritarianism." },
}

for s = 1, 4 do
    local suit = suits[s]
    for r = 1, 14 do
        local rank = ranks[r]
        local mod = rank_modifiers[r]
        local base = suit_meanings[s]
        local id = 22 + ((s - 1) * 14) + (r - 1)
        table.insert(MINOR_ARCANA, {
            id = id,
            suit = suit,
            rank = rank,
            name = {
                pt = rank.pt .. " de " .. suit.pt,
                en = rank.en .. " of " .. suit.en,
            },
            meaning = {
                pt = base.upright.pt .. " " .. mod.upright_pt,
                en = base.upright.en .. " " .. mod.upright_en,
            },
            reversed_meaning = {
                pt = base.reversed.pt .. " " .. mod.reversed_pt,
                en = base.reversed.en .. " " .. mod.reversed_en,
            }
        })
    end
end

local FULL_DECK = {}
for _, card in ipairs(MAJOR_ARCANA) do
    table.insert(FULL_DECK, card)
end
for _, card in ipairs(MINOR_ARCANA) do
    table.insert(FULL_DECK, card)
end

-- ═════════════════════════════════════════════════════════════════════════════
-- Plugin principal
-- ═════════════════════════════════════════════════════════════════════════════
local TarotPlugin = InputContainer:extend{
    name        = "tarot",
    fullname    = "Leitura de Tarot",
    is_doc_only = false,
}

function TarotPlugin:init()
    math.randomseed(os.time() + math.random(10000))
    self.ui.menu:registerToMainMenu(self)
    self.plugin_dir = self:getPluginDirectory()
    self.language = G_reader_settings:readSetting("tarot_language") or "pt"
    self.allow_reversed = G_reader_settings:readSetting("tarot_allow_reversed")
    if self.allow_reversed == nil then
        self.allow_reversed = true
    end
    self.major_only = G_reader_settings:readSetting("tarot_major_only")
    if self.major_only == nil then
        self.major_only = false
    end
end

function TarotPlugin:getTranslation(key)
    local lang = self.language or "pt"
    local t = translations[lang]
    if t and t[key] then return t[key] end
    if translations.pt and translations.pt[key] then return translations.pt[key] end
    return key
end

function TarotPlugin:refreshMenu()
    self.ui.menu:registerToMainMenu(self)
end

function TarotPlugin:getPluginDirectory()
    if self.path then return self.path end
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

function TarotPlugin:getActiveDeck()
    if self.major_only then return MAJOR_ARCANA end
    return FULL_DECK
end

function TarotPlugin:drawCard()
    local deck = self:getActiveDeck()
    local card = deck[math.random(1, #deck)]
    local is_reversed = false
    if self.allow_reversed then
        is_reversed = math.random(2) == 1
    end
    return card, is_reversed
end

function TarotPlugin:toggleReversed()
    self.allow_reversed = not self.allow_reversed
    G_reader_settings:saveSetting("tarot_allow_reversed", self.allow_reversed)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:toggleMajorOnly()
    self.major_only = not self.major_only
    G_reader_settings:saveSetting("tarot_major_only", self.major_only)
    UIManager:setDirty(nil, "full")
end

-- ═════════════════════════════════════════════════════════════════════════════
-- Diálogo da carta
-- ═════════════════════════════════════════════════════════════════════════════
local CardDialog = InputContainer:extend{
    cards = nil,
    current_index = 1,
    card_labels = nil,
    on_new = nil,
    plugin = nil,
    title_label = nil,
}

function CardDialog:init()
    local sw  = Screen:getWidth()
    local w   = math.floor(sw * 0.84)
    local pad = Size.padding.large
    local iw  = w - pad * 2

    local card_data = self.cards[self.current_index]
    local card = card_data.card
    local is_reversed = card_data.is_reversed
    local lang = self.plugin.language
    local total_cards = #self.cards

    local title_text = "~ * ~\n" .. (self.title_label or self.plugin:getTranslation("title"))

    local title_w = TextWidget:new{
        text      = title_text,
        face      = Font:getFace("tfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local divider = TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "center",
    }

    local number_text = card.roman or (card.rank and (card.rank[lang] or card.rank.pt)) or ""

    local number_w = TextWidget:new{
        text      = number_text,
        face      = Font:getFace("tfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local suit_w
    if card.suit then
        suit_w = TextWidget:new{
            text      = card.suit.symbol .. "  " .. (card.suit[lang] or card.suit.pt) .. "  " .. card.suit.symbol,
            face      = Font:getFace("smalltfont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = iw,
            alignment = "center",
        }
    end

    local name_text = card.name[lang] or card.name.pt
    if is_reversed then
        name_text = name_text .. " (" .. self.plugin:getTranslation("reversed") .. ")"
    end
    local name_w = TextWidget:new{
        text      = name_text,
        face      = Font:getFace("cfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local type_w = TextWidget:new{
        text      = card.roman and self.plugin:getTranslation("major_arcana") or self.plugin:getTranslation("minor_arcana"),
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "center",
    }

    local meaning_text = is_reversed and (card.reversed_meaning[lang] or card.reversed_meaning.pt) or (card.meaning[lang] or card.meaning.pt)
    local meaning_w = TextBoxWidget:new{
        text      = meaning_text,
        face      = Font:getFace("cfont"),
        width     = iw,
        alignment = "center",
    }

    local counter_w
    if total_cards > 1 then
        counter_w = TextWidget:new{
            text      = string.format(self.plugin:getTranslation("card_count"), self.current_index, total_cards),
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = iw,
            alignment = "center",
        }
    end

    local nav_row
    if total_cards > 1 then
        local btn_prev = Button:new{
            text     = self.plugin:getTranslation("prev"),
            width    = math.floor(iw * 0.30),
            radius   = Size.radius.button,
            enabled  = self.current_index > 1,
            callback = function()
                if self.current_index > 1 then
                    self.current_index = self.current_index - 1
                    UIManager:close(self)
                    UIManager:show(CardDialog:new{
                        cards = self.cards,
                        current_index = self.current_index,
                        card_labels = self.card_labels,
                        on_new = self.on_new,
                        plugin = self.plugin,
                        title_label = self.title_label,
                    })
                    UIManager:setDirty(nil, "full")
                end
            end,
        }
        local btn_next = Button:new{
            text     = self.plugin:getTranslation("next"),
            width    = math.floor(iw * 0.30),
            radius   = Size.radius.button,
            enabled  = self.current_index < total_cards,
            callback = function()
                if self.current_index < total_cards then
                    self.current_index = self.current_index + 1
                    UIManager:close(self)
                    UIManager:show(CardDialog:new{
                        cards = self.cards,
                        current_index = self.current_index,
                        card_labels = self.card_labels,
                        on_new = self.on_new,
                        plugin = self.plugin,
                        title_label = self.title_label,
                    })
                    UIManager:setDirty(nil, "full")
                end
            end,
        }
        nav_row = HorizontalGroup:new{
            align = "center",
            btn_prev,
            HorizontalSpan:new{ width = math.floor(iw * 0.04) },
            btn_next,
        }
    end

    local btn_new = Button:new{
        text     = self.plugin:getTranslation("new"),
        width    = math.floor(iw * 0.35),
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
            if self.on_new then self.on_new() end
        end,
    }

    local btn_close = Button:new{
        text     = self.plugin:getTranslation("close"),
        width    = math.floor(iw * 0.35),
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    }

    local btns_row = HorizontalGroup:new{
        align = "center",
        btn_new,
        HorizontalSpan:new{ width = math.floor(iw * 0.10) },
        btn_close,
    }

    local content = VerticalGroup:new{
        align = "center",
        title_w,
        VerticalSpan:new{ width = Size.span.vertical_small },
        divider,
    }

    if counter_w then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(content, counter_w)
    end

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, number_w)
    if suit_w then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(content, suit_w)
    end
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, name_w)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    table.insert(content, type_w)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    table.insert(content, divider)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, meaning_w)

    if nav_row then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, nav_row)
    end

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(content, btns_row)

    local dialog_frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        radius     = Size.radius.window,
        padding    = pad,
        content,
    }

    self[1] = CenterContainer:new{
        dimen = Screen:getSize(),
        dialog_frame,
    }
end

-- ═════════════════════════════════════════════════════════════════════════════
-- Diálogo de Configurações
-- ═════════════════════════════════════════════════════════════════════════════
local SettingsDialog = InputContainer:extend{
    plugin = nil,
}

function SettingsDialog:init()
    local sw  = Screen:getWidth()
    local w   = math.floor(sw * 0.84)
    local pad = Size.padding.large
    local iw  = w - pad * 2

    local title = TextWidget:new{
        text      = self.plugin:getTranslation("settings"),
        face      = Font:getFace("tfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local rows = VerticalGroup:new{ align = "left" }

    local rev_mark = self.plugin.allow_reversed and "☑" or "☐"
    local rev_label = "  " .. rev_mark .. "  " .. self.plugin:getTranslation("allow_reversed_desc")
    local btn_rev = Button:new{
        text     = rev_label,
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            self.plugin:toggleReversed()
            UIManager:close(self)
            UIManager:show(SettingsDialog:new{ plugin = self.plugin })
            UIManager:setDirty(nil, "full")
        end,
    }
    table.insert(rows, btn_rev)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_small })

    local maj_mark = self.plugin.major_only and "☑" or "☐"
    local maj_label = "  " .. maj_mark .. "  " .. self.plugin:getTranslation("major_only_desc")
    local btn_maj = Button:new{
        text     = maj_label,
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            self.plugin:toggleMajorOnly()
            UIManager:close(self)
            UIManager:show(SettingsDialog:new{ plugin = self.plugin })
            UIManager:setDirty(nil, "full")
        end,
    }
    table.insert(rows, btn_maj)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

    local lang_label = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("language") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }
    table.insert(rows, lang_label)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_small })

    local current_lang = self.plugin.language
    local pt_mark = (current_lang == "pt") and "☑" or "☐"
    local en_mark = (current_lang == "en") and "☑" or "☐"

    local lang_btns = HorizontalGroup:new{
        align = "center",
        Button:new{
            text   = pt_mark .. " " .. self.plugin:getTranslation("portuguese"),
            width  = math.floor(iw * 0.47),
            radius = Size.radius.button,
            callback = function()
                self.plugin.language = "pt"
                G_reader_settings:saveSetting("tarot_language", "pt")
                UIManager:close(self)
                self.plugin:refreshMenu()
                UIManager:show(SettingsDialog:new{ plugin = self.plugin })
                UIManager:setDirty(nil, "full")
            end,
        },
        HorizontalSpan:new{ width = math.floor(iw * 0.06) },
        Button:new{
            text   = en_mark .. " " .. self.plugin:getTranslation("english"),
            width  = math.floor(iw * 0.47),
            radius = Size.radius.button,
            callback = function()
                self.plugin.language = "en"
                G_reader_settings:saveSetting("tarot_language", "en")
                UIManager:close(self)
                self.plugin:refreshMenu()
                UIManager:show(SettingsDialog:new{ plugin = self.plugin })
                UIManager:setDirty(nil, "full")
            end,
        },
    }
    table.insert(rows, lang_btns)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })

    local btn_close = Button:new{
        text     = self.plugin:getTranslation("close"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    }
    table.insert(rows, btn_close)

    local content = VerticalGroup:new{
        align = "center",
        title,
        VerticalSpan:new{ width = Size.span.vertical_large },
        rows,
    }

    local dialog_frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        radius     = Size.radius.window,
        padding    = pad,
        content,
    }

    self[1] = CenterContainer:new{
        dimen = Screen:getSize(),
        dialog_frame,
    }
end

-- ═════════════════════════════════════════════════════════════════════════════
-- Menu e orquestração
-- ═════════════════════════════════════════════════════════════════════════════
function TarotPlugin:addToMainMenu(menu_items)
    menu_items.tarot = {
        text         = self:getTranslation("title"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text     = self:getTranslation("draw_card"),
                callback = function()
                    self:showSingleCard()
                end,
            },
            {
                text     = self:getTranslation("draw_three"),
                callback = function()
                    self:showThreeCards()
                end,
            },
            {
                text     = self:getTranslation("settings"),
                callback = function()
                    self:showSettings()
                end,
            },
        },
    }
end

function TarotPlugin:showSettings()
    UIManager:show(SettingsDialog:new{ plugin = self })
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showSingleCard()
    local loading = InfoMessage:new{ text = self:getTranslation("loading") }
    UIManager:show(loading)
    UIManager:setDirty(nil, "full")
    UIManager:scheduleIn(0.5, function()
        local card, is_reversed = self:drawCard()
        UIManager:close(loading)
        local dlg = CardDialog:new{
            cards = {{ card = card, is_reversed = is_reversed }},
            current_index = 1,
            plugin = self,
            on_new = function() self:showSingleCard() end,
        }
        UIManager:show(dlg)
        UIManager:setDirty(nil, "full")
    end)
end

function TarotPlugin:showThreeCards()
    local loading = InfoMessage:new{ text = self:getTranslation("loading") }
    UIManager:show(loading)
    UIManager:setDirty(nil, "full")
    UIManager:scheduleIn(0.5, function()
        local card1, rev1 = self:drawCard()
        local card2, rev2 = self:drawCard()
        local card3, rev3 = self:drawCard()
        UIManager:close(loading)
        local dlg = CardDialog:new{
            cards = {
                { card = card1, is_reversed = rev1 },
                { card = card2, is_reversed = rev2 },
                { card = card3, is_reversed = rev3 },
            },
            current_index = 1,
            card_labels = {
                string.format(self:getTranslation("card_count"), 1, 3),
                string.format(self:getTranslation("card_count"), 2, 3),
                string.format(self:getTranslation("card_count"), 3, 3),
            },
            plugin = self,
            on_new = function() self:showThreeCards() end,
        }
        UIManager:show(dlg)
        UIManager:setDirty(nil, "full")
    end)
end

return TarotPlugin

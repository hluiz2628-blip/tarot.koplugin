-- ── dependências ──────────────────────────────────────────────────────────────
local Blitbuffer       = require("ffi/blitbuffer")
local Button           = require("ui/widget/button")
local ButtonDialog     = require("ui/widget/buttondialog")
local CenterContainer  = require("ui/widget/container/centercontainer")
local Event            = require("ui/event")
local Font             = require("ui/font")
local FrameContainer   = require("ui/widget/container/framecontainer")
local HorizontalGroup  = require("ui/widget/horizontalgroup")
local HorizontalSpan   = require("ui/widget/horizontalspan")
local ImageWidget      = require("ui/widget/imagewidget")
local InfoMessage      = require("ui/widget/infomessage")
local InputContainer   = require("ui/widget/container/inputcontainer")
local InputDialog      = require("ui/widget/inputdialog")
local Menu             = require("ui/widget/menu")
local ReaderUI         = require("apps/reader/readerui")
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
-- ║                     SEÇÃO 1: TRADUÇÕES (translations)                       ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local translations = {
    pt = {
        title = "Leitura de Tarot",
        spreads = "Spreads",
        one_card = "1 Carta",
        three_cards = "3 Cartas",
        daily_card = "Carta Diária",
        draw_card = "Tirar uma carta",
        draw_three = "Tiragem de 3 cartas",
        draw_daily = "Carta do dia",
        settings = "Configurações",
        configuration = "Configuração",
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
        deck_type = "Tipo de Baralho",
        deck_type_desc = "Escolha entre Tarot e Baralho Cigano",
        tarot_deck = "Tarot",
        lenormand_deck = "Baralho Cigano",
        lenormand_reading = "Leitura do Baralho Cigano",
        lenormand_title = "Baralho Cigano",
        save = "Salvar",
        save_title = "Título da tiragem (máx. 50 caracteres)",
        save_title_hint = "Ex: Reflexão do dia",
        save_note = "Nota sobre a leitura (máx. 500 caracteres)",
        save_note_hint = "Ex: O que senti ao ver estas cartas...",
        save_success = "Tiragem salva com sucesso!",
        save_error = "Erro ao salvar a tiragem.",
        saved_readings = "Tiragens Salvas",
        no_saved = "Nenhuma tiragem salva encontrada.",
        open_reading = "Abrir no Leitor",
        delete_reading = "Excluir",
        delete_confirm = "Excluir esta tiragem?",
        delete_success = "Tiragem excluída.",
        delete_error = "Erro ao excluir arquivo.",
        saved_on = "Salvo em",
        title_label = "Título",
        note_label = "Nota",
        card_position = "Posição",
        restore = "Restaurar",
        restore_desc = "Apagar todas as configurações e tiragens salvas",
        restore_confirm = "Tem certeza? Isso apagará TODAS as configurações e tiragens salvas. Esta ação não pode ser desfeita.",
        restore_success = "Tudo foi restaurado. O plugin será reiniciado.",
        restore_error = "Erro ao restaurar. Alguns arquivos não puderam ser removidos.",
        yes = "Sim",
        no = "Não",
        confirm = "Confirmar",
        cancel = "Cancelar",
        reset_section = "Redefinir",
        card_book = "Livro de Cartas",
        major_arcana_list = "Arcanos Maiores (22)",
        minor_arcana_list = "Arcanos Menores (56)",
        lenormand_list = "Baralho Cigano (36)",
        all_cards = "Ver Todas as Cartas",
        search_card = "Buscar Carta",
        meaning_label = "Significado",
        reversed_meaning_label = "Significado Invertido",
        number_label = "Número",
        arcana_label = "Arcano",
        filter_title = "Filtrar Cartas",
        no_results = "Nenhuma carta encontrada.",
        back = "Voltar",
        suit_wands = "Paus",
        suit_cups = "Copas",
        suit_swords = "Espadas",
        suit_pentacles = "Ouros",
        -- Novas traduções para Carta Oculta
        hidden_card = "Carta Oculta",
        hidden_card_desc = "Mostrar verso da carta antes de revelar a tiragem",
        click_on_card = "clique na carta",
        exit = "Sair",
        reveal = "Revelar",
        -- Novo: Sobre
        about = "Sobre",
        about_title = "Sobre o Tarot e Lenormand",
        about_text = [[O Tarot é um baralho de 78 cartas, dividido em Arcanos Maiores (22) e Menores (56), usado para reflexão e autoconhecimento. O Baralho Cigano (Lenormand) possui 36 cartas com simbolismo direto para orientação prática.

Agradecimentos pelas imagens gratuitas:
• Lenormand Cards por Yve Lepkowski (https://stolen-thyme.com/)
• Tarot Cards por Luciella Elisabeth Scarlett (https://luciellaes.itch.io/)]],
    },
    en = {
        title = "Tarot Reading",
        spreads = "Spreads",
        one_card = "1 Card",
        three_cards = "3 Cards",
        daily_card = "Daily Card",
        draw_card = "Draw a card",
        draw_three = "3 card spread",
        draw_daily = "Card of the day",
        settings = "Settings",
        configuration = "Config",
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
        deck_type = "Deck Type",
        deck_type_desc = "Choose between Tarot and Lenormand",
        tarot_deck = "Tarot",
        lenormand_deck = "Lenormand",
        lenormand_reading = "Lenormand Reading",
        lenormand_title = "Lenormand Deck",
        save = "Save",
        save_title = "Spread title (max 50 characters)",
        save_title_hint = "Ex: Daily reflection",
        save_note = "Note about the reading (max 500 characters)",
        save_note_hint = "Ex: What I felt seeing these cards...",
        save_success = "Spread saved successfully!",
        save_error = "Error saving the spread.",
        saved_readings = "Saved Spreads",
        no_saved = "No saved spreads found.",
        open_reading = "Open in Reader",
        delete_reading = "Delete",
        delete_confirm = "Delete this spread?",
        delete_success = "Spread deleted.",
        delete_error = "Error deleting file.",
        saved_on = "Saved on",
        title_label = "Title",
        note_label = "Note",
        card_position = "Position",
        restore = "Restore",
        restore_desc = "Delete all settings and saved spreads",
        restore_confirm = "Are you sure? This will delete ALL settings and saved spreads. This action cannot be undone.",
        restore_success = "Everything has been restored. The plugin will restart.",
        restore_error = "Error restoring. Some files could not be removed.",
        yes = "Yes",
        no = "No",
        confirm = "Confirm",
        cancel = "Cancel",
        reset_section = "Reset",
        card_book = "Card Book",
        major_arcana_list = "Major Arcana (22)",
        minor_arcana_list = "Minor Arcana (56)",
        lenormand_list = "Lenormand Deck (36)",
        all_cards = "View All Cards",
        search_card = "Search Card",
        meaning_label = "Meaning",
        reversed_meaning_label = "Reversed Meaning",
        number_label = "Number",
        arcana_label = "Arcana",
        filter_title = "Filter Cards",
        no_results = "No cards found.",
        back = "Back",
        suit_wands = "Wands",
        suit_cups = "Cups",
        suit_swords = "Swords",
        suit_pentacles = "Pentacles",
        -- New translations for Hidden Card
        hidden_card = "Hidden Card",
        hidden_card_desc = "Show card back before revealing the spread",
        click_on_card = "click on the card",
        exit = "Exit",
        reveal = "Reveal",
        -- New: About
        about = "About",
        about_title = "About Tarot and Lenormand",
        about_text = [[Tarot is a deck of 78 cards, divided into Major Arcana (22) and Minor Arcana (56), used for reflection and self-knowledge. The Lenormand deck has 36 cards with direct symbolism for practical guidance.

Credits for the free card images:
• Lenormand Cards by Yve Lepkowski (https://stolen-thyme.com/)
• Tarot Cards by Luciella Elisabeth Scarlett (https://luciellaes.itch.io/)]],
    }
}

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 2: CARTAS - ARCANOS MAIORES (22)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
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

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 3: CARTAS - ARCANOS MENORES (56)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
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

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 4: CARTAS - LENORMAND (36)                             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local LENORMAND_DECK = {
    {
        id = 1, number = 1,
        name = { pt = "O Cavaleiro", en = "The Rider" },
        symbol = "♞",
        meaning = {
            pt = "Notícias chegando. Um visitante ou mensagem importante. Movimento rápido e boas novas no horizonte.",
            en = "News arriving. A visitor or important message. Swift movement and good tidings on the horizon."
        }
    },
    {
        id = 2, number = 2,
        name = { pt = "O Trevo", en = "The Clover" },
        symbol = "♣",
        meaning = {
            pt = "Sorte passageira. Oportunidade efêmera. Alegria simples. Aproveite o momento presente com leveza.",
            en = "Passing luck. Fleeting opportunity. Simple joy. Enjoy the present moment with lightness."
        }
    },
    {
        id = 3, number = 3,
        name = { pt = "O Navio", en = "The Ship" },
        symbol = "⛵",
        meaning = {
            pt = "Viagem. Mudança de cenário. Novos horizontes. Aventure-se, o mundo espera por você.",
            en = "Travel. Change of scenery. New horizons. Venture forth, the world awaits you."
        }
    },
    {
        id = 4, number = 4,
        name = { pt = "A Casa", en = "The House" },
        symbol = "⌂",
        meaning = {
            pt = "Lar. Segurança familiar. Raízes firmes. Cuide do seu espaço sagrado com amor e dedicação.",
            en = "Home. Family security. Firm roots. Care for your sacred space with love and dedication."
        }
    },
    {
        id = 5, number = 5,
        name = { pt = "A Árvore", en = "The Tree" },
        symbol = "♧",
        meaning = {
            pt = "Saúde. Crescimento pessoal. Conexão com a natureza. Suas raízes são profundas, seus frutos virão.",
            en = "Health. Personal growth. Connection with nature. Your roots are deep, your fruits will come."
        }
    },
    {
        id = 6, number = 6,
        name = { pt = "As Nuvens", en = "The Clouds" },
        symbol = "☁",
        meaning = {
            pt = "Confusão. Incerteza temporária. Dúvidas pairando. A clareza virá após a tempestade passar.",
            en = "Confusion. Temporary uncertainty. Lingering doubts. Clarity will come after the storm passes."
        }
    },
    {
        id = 7, number = 7,
        name = { pt = "A Cobra", en = "The Snake" },
        symbol = "≈",
        meaning = {
            pt = "Sedução. Traição ou manipulação. Cuidado com falsas promessas. A sabedoria está em ver além das aparências.",
            en = "Seduction. Betrayal or manipulation. Beware of false promises. Wisdom lies in seeing beyond appearances."
        }
    },
    {
        id = 8, number = 8,
        name = { pt = "O Caixão", en = "The Coffin" },
        symbol = "⚰",
        meaning = {
            pt = "Fim de um ciclo. Transformação profunda. Deixe o passado descansar. O novo nasce do que se foi.",
            en = "End of a cycle. Deep transformation. Let the past rest. The new is born from what has gone."
        }
    },
    {
        id = 9, number = 9,
        name = { pt = "O Buquê", en = "The Bouquet" },
        symbol = "⚘",
        meaning = {
            pt = "Presente. Elogio. Reconhecimento. A beleza da vida se revela nas pequenas gentilezas.",
            en = "Gift. Compliment. Recognition. The beauty of life reveals itself in small kindnesses."
        }
    },
    {
        id = 10, number = 10,
        name = { pt = "A Foice", en = "The Scythe" },
        symbol = "⚔",
        meaning = {
            pt = "Corte necessário. Decisão drástica. Ruptura iminente. Às vezes é preciso cortar para curar.",
            en = "Necessary cut. Drastic decision. Imminent rupture. Sometimes you must cut to heal."
        }
    },
    {
        id = 11, number = 11,
        name = { pt = "O Chicote", en = "The Whip" },
        symbol = "≈≈",
        meaning = {
            pt = "Conflito. Discussões acaloradas. Paixão intensa. Canalize a energia para ações produtivas.",
            en = "Conflict. Heated discussions. Intense passion. Channel energy into productive actions."
        }
    },
    {
        id = 12, number = 12,
        name = { pt = "Os Pássaros", en = "The Birds" },
        symbol = "♫",
        meaning = {
            pt = "Conversas importantes. Fofocas ou notícias. Comunicação em foco. Escolha bem suas palavras.",
            en = "Important conversations. Gossip or news. Communication in focus. Choose your words wisely."
        }
    },
    {
        id = 13, number = 13,
        name = { pt = "A Criança", en = "The Child" },
        symbol = "☺",
        meaning = {
            pt = "Inocência. Novo começo. Pureza de intenção. Abrace sua criança interior com ternura.",
            en = "Innocence. New beginning. Purity of intention. Embrace your inner child with tenderness."
        }
    },
    {
        id = 14, number = 14,
        name = { pt = "A Raposa", en = "The Fox" },
        symbol = "≈≈",
        meaning = {
            pt = "Astúcia. Esperteza. Cuidado com enganos. Use sua inteligência para o bem, não para manipular.",
            en = "Cunning. Cleverness. Beware of deception. Use your intelligence for good, not manipulation."
        }
    },
    {
        id = 15, number = 15,
        name = { pt = "O Urso", en = "The Bear" },
        symbol = "♚",
        meaning = {
            pt = "Força protetora. Poder financeiro. Autoridade natural. Liderança com generosidade traz prosperidade.",
            en = "Protective strength. Financial power. Natural authority. Leadership with generosity brings prosperity."
        }
    },
    {
        id = 16, number = 16,
        name = { pt = "A Estrela", en = "The Star" },
        symbol = "★",
        meaning = {
            pt = "Esperança. Clareza de propósito. Siga sua luz interior. O universo conspira a seu favor.",
            en = "Hope. Clarity of purpose. Follow your inner light. The universe conspires in your favor."
        }
    },
    {
        id = 17, number = 17,
        name = { pt = "A Cegonha", en = "The Stork" },
        symbol = "♆",
        meaning = {
            pt = "Mudança positiva. Renovação. Transição abençoada. Novas energias chegam para transformar sua vida.",
            en = "Positive change. Renewal. Blessed transition. New energies arrive to transform your life."
        }
    },
    {
        id = 18, number = 18,
        name = { pt = "O Cachorro", en = "The Dog" },
        symbol = "♉",
        meaning = {
            pt = "Amizade leal. Fidelidade. Companheirismo sincero. Valorize quem caminha ao seu lado.",
            en = "Loyal friendship. Fidelity. Sincere companionship. Value those who walk beside you."
        }
    },
    {
        id = 19, number = 19,
        name = { pt = "A Torre", en = "The Tower" },
        symbol = "♜",
        meaning = {
            pt = "Autoridade institucional. Proteção. Estrutura sólida. Construa bases firmes para o futuro.",
            en = "Institutional authority. Protection. Solid structure. Build firm foundations for the future."
        }
    },
    {
        id = 20, number = 20,
        name = { pt = "O Jardim", en = "The Garden" },
        symbol = "❦",
        meaning = {
            pt = "Vida social. Comunidade. Encontros públicos. Abra-se para novas conexões e ambientes.",
            en = "Social life. Community. Public encounters. Open yourself to new connections and environments."
        }
    },
    {
        id = 21, number = 21,
        name = { pt = "A Montanha", en = "The Mountain" },
        symbol = "▲",
        meaning = {
            pt = "Obstáculo. Desafio a superar. Bloqueio temporário. A vista do topo justifica a escalada.",
            en = "Obstacle. Challenge to overcome. Temporary blockage. The view from the top justifies the climb."
        }
    },
    {
        id = 22, number = 22,
        name = { pt = "O Caminho", en = "The Crossroads" },
        symbol = "⛗",
        meaning = {
            pt = "Escolha importante. Decisão crucial. Múltiplos caminhos. Siga sua intuição na encruzilhada.",
            en = "Important choice. Crucial decision. Multiple paths. Follow your intuition at the crossroads."
        }
    },
    {
        id = 23, number = 23,
        name = { pt = "Os Ratos", en = "The Mice" },
        symbol = "🐭",
        meaning = {
            pt = "Perda gradual. Desgaste. Preocupações corroendo. Atenção aos detalhes que passam despercebidos.",
            en = "Gradual loss. Wear and tear. Corroding worries. Attention to details that go unnoticed."
        }
    },
    {
        id = 24, number = 24,
        name = { pt = "O Coração", en = "The Heart" },
        symbol = "♥",
        meaning = {
            pt = "Amor verdadeiro. Paixão. Afeto profundo. Abra seu coração sem medo de ser feliz.",
            en = "True love. Passion. Deep affection. Open your heart without fear of being happy."
        }
    },
    {
        id = 25, number = 25,
        name = { pt = "O Anel", en = "The Ring" },
        symbol = "◎",
        meaning = {
            pt = "Compromisso. Aliança. Ciclo completado. Honre seus pactos e promessas com integridade.",
            en = "Commitment. Alliance. Completed cycle. Honor your pacts and promises with integrity."
        }
    },
    {
        id = 26, number = 26,
        name = { pt = "O Livro", en = "The Book" },
        symbol = "▣",
        meaning = {
            pt = "Segredo. Conhecimento oculto. Mistério a ser revelado. A resposta está nas entrelinhas.",
            en = "Secret. Hidden knowledge. Mystery to be revealed. The answer lies between the lines."
        }
    },
    {
        id = 27, number = 27,
        name = { pt = "A Carta", en = "The Letter" },
        symbol = "✉",
        meaning = {
            pt = "Mensagem escrita. Documento importante. Comunicação formal. Notícias que chegam pelo papel.",
            en = "Written message. Important document. Formal communication. News arriving on paper."
        }
    },
    {
        id = 28, number = 28,
        name = { pt = "O Homem", en = "The Gentleman" },
        symbol = "♂",
        meaning = {
            pt = "Figura masculina influente. Parceiro ou consulente. Força yang. Ação e iniciativa.",
            en = "Influential male figure. Partner or seeker. Yang force. Action and initiative."
        }
    },
    {
        id = 29, number = 29,
        name = { pt = "A Mulher", en = "The Lady" },
        symbol = "♀",
        meaning = {
            pt = "Figura feminina influente. Parceira ou consulente. Força yin. Intuição e acolhimento.",
            en = "Influential female figure. Partner or seeker. Yin force. Intuition and nurturing."
        }
    },
    {
        id = 30, number = 30,
        name = { pt = "Os Lírios", en = "The Lilies" },
        symbol = "⚜",
        meaning = {
            pt = "Paz. Harmonia. Sabedoria madura. A virtude da paciência floresce em seu jardim.",
            en = "Peace. Harmony. Mature wisdom. The virtue of patience blooms in your garden."
        }
    },
    {
        id = 31, number = 31,
        name = { pt = "O Sol", en = "The Sun" },
        symbol = "☼",
        meaning = {
            pt = "Sucesso. Vitória. Energia vital plena. Tudo está iluminado, aproveite este momento.",
            en = "Success. Victory. Full vital energy. Everything is illuminated, enjoy this moment."
        }
    },
    {
        id = 32, number = 32,
        name = { pt = "A Lua", en = "The Moon" },
        symbol = "☽",
        meaning = {
            pt = "Intuição. Reconhecimento. Fama e criatividade. Seus talentos são reconhecidos sob a luz lunar.",
            en = "Intuition. Recognition. Fame and creativity. Your talents are recognized under moonlight."
        }
    },
    {
        id = 33, number = 33,
        name = { pt = "A Chave", en = "The Key" },
        symbol = "⚷",
        meaning = {
            pt = "Solução. Abertura de portas. Oportunidade decisiva. A resposta que você busca está ao seu alcance.",
            en = "Solution. Opening doors. Decisive opportunity. The answer you seek is within reach."
        }
    },
    {
        id = 34, number = 34,
        name = { pt = "Os Peixes", en = "The Fish" },
        symbol = "♓",
        meaning = {
            pt = "Abundância financeira. Prosperidade. Fluxo de recursos. A riqueza flui como água limpa.",
            en = "Financial abundance. Prosperity. Flow of resources. Wealth flows like clean water."
        }
    },
    {
        id = 35, number = 35,
        name = { pt = "A Âncora", en = "The Anchor" },
        symbol = "⚓",
        meaning = {
            pt = "Estabilidade. Segurança duradoura. Trabalho firme. Construa bases sólidas para o amanhã.",
            en = "Stability. Lasting security. Steady work. Build solid foundations for tomorrow."
        }
    },
    {
        id = 36, number = 36,
        name = { pt = "A Cruz", en = "The Cross" },
        symbol = "✚",
        meaning = {
            pt = "Destino. Provação necessária. Fardo sagrado. O sofrimento traz sabedoria e transcendência.",
            en = "Destiny. Necessary trial. Sacred burden. Suffering brings wisdom and transcendence."
        }
    },
}

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                  SEÇÃO 5: PLUGIN PRINCIPAL (TarotPlugin)                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local TarotPlugin = InputContainer:extend{
    name        = "tarot",
    fullname    = "Leitura de Tarot",
    is_doc_only = false,
}

function TarotPlugin:init()
    math.randomseed(os.time())
    math.random()
    math.random()
    math.random()

    self.ui.menu:registerToMainMenu(self)
    self.plugin_dir = self:getPluginDirectory()
    self.saves_dir = self.plugin_dir .. "/tiragens_salvas"
    self.language = G_reader_settings:readSetting("tarot_language") or "pt"
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
    -- NOVA CONFIGURAÇÃO: Carta Oculta (padrão ativado)
    self.hidden_card = G_reader_settings:readSetting("tarot_hidden_card")
    if self.hidden_card == nil then
        self.hidden_card = true
    end
    
    self:ensureSavesDir()
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

function TarotPlugin:ensureSavesDir()
    local attr = lfs.attributes(self.saves_dir)
    if not attr then
        local success = lfs.mkdir(self.saves_dir)
        if not success then
            logger.warn("tarot.koplugin: Não foi possível criar o diretório de tiragens salvas:", self.saves_dir)
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
    local drawn_indices = {}
    
    if count > #deck then count = #deck end

    while #selected_cards < count do
        local index = math.random(1, #deck)
        if not drawn_indices[index] then
            drawn_indices[index] = true
            local card = deck[index]
            local is_reversed = false
            if self.allow_reversed and not self.use_lenormand then
                is_reversed = math.random(2) == 1
            end
            table.insert(selected_cards, { card = card, is_reversed = is_reversed })
        end
    end
    
    return selected_cards
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

function TarotPlugin:toggleLenormand()
    self.use_lenormand = not self.use_lenormand
    G_reader_settings:saveSetting("tarot_use_lenormand", self.use_lenormand)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:toggleHiddenCard()
    self.hidden_card = not self.hidden_card
    G_reader_settings:saveSetting("tarot_hidden_card", self.hidden_card)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:restoreAll()
    G_reader_settings:delSetting("tarot_language")
    G_reader_settings:delSetting("tarot_allow_reversed")
    G_reader_settings:delSetting("tarot_major_only")
    G_reader_settings:delSetting("tarot_use_lenormand")
    G_reader_settings:delSetting("tarot_hidden_card")
    -- Limpa dados da carta diária
    G_reader_settings:delSetting("tarot_daily_date")
    G_reader_settings:delSetting("tarot_daily_card_id")
    G_reader_settings:delSetting("tarot_daily_card_is_lenormand")
    G_reader_settings:delSetting("tarot_daily_card_is_reversed")
    G_reader_settings:delSetting("tarot_daily_revealed_date")
    
    if self.saves_dir then
        for file in lfs.dir(self.saves_dir) do
            if file ~= "." and file ~= ".." then
                local filepath = self.saves_dir .. "/" .. file
                os.remove(filepath)
            end
        end
    end
    
    self.language = "pt"
    self.allow_reversed = true
    self.major_only = false
    self.use_lenormand = false
    self.hidden_card = true
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           SEÇÃO 6: IMAGENS DAS CARTAS (suporte a PNG/JPG)                    ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

--- Retorna o caminho esperado para a imagem da carta.
function TarotPlugin:getCardImagePath(card)
    if card.symbol then
        local en_clean = card.name.en:gsub("^The%s+", "")
        return self.plugin_dir .. "/cards_lenormand/" .. tostring(card.number) .. "._" .. en_clean .. ".png"
    elseif card.roman then
        local id_str = string.format("%02d", card.id)
        local name_en_clean = card.name.en:gsub(" ", ""):gsub("'", "")
        return self.plugin_dir .. "/cards_tarot/" .. id_str .. "-" .. name_en_clean .. ".jpg"
    elseif card.suit then
        local suit_en = card.suit.en
        local rank_map = { Ace=1, Two=2, Three=3, Four=4, Five=5, Six=6, Seven=7, Eight=8, Nine=9, Ten=10, Page=11, Knight=12, Queen=13, King=14 }
        local rank_val = rank_map[card.rank.en] or 0
        local rank_str = string.format("%02d", rank_val)
        return self.plugin_dir .. "/cards_tarot/" .. suit_en .. rank_str .. ".jpg"
    end
end

--- Cria o widget de exibição da carta.
-- Aceita dimensões opcionais apenas para miniaturas.
function TarotPlugin:getCardImageWidget(card, w_override, h_override)
    local path = self:getCardImagePath(card)
    local screen_w = Screen:getWidth()
    local card_w, card_h
    if card.symbol then
        card_w = w_override or 250
        card_h = h_override or 250
    else
        -- Tamanho padrão: 25% da largura da tela para Tarot
        local base_w = math.floor(screen_w * 0.25)
        card_w = w_override or base_w
        -- Se h_override não for fornecido, recalcula com base no w real usado
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
        }
    else
        -- Fallback textual
        local lang = self.language
        local text = ""
        if card.symbol then
            text = card.symbol .. "\n" .. (card.name[lang] or card.name.pt)
        elseif card.roman then
            text = card.roman .. "\n" .. (card.name[lang] or card.name.pt)
        elseif card.suit then
            local suit_symbol = card.suit.symbol or ""
            local rank_pt = card.rank[lang] or card.rank.pt
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

-- WIDGET: Carta com efeito escurecido (hachuras densas) para miniaturas
local DimmedCard = InputContainer:extend{
    image_widget = nil,
    width = 0,
    height = 0,
}

function DimmedCard:init()
    self[1] = self.image_widget
end

function DimmedCard:paintTo(bb, x, y)
    -- Pinta a imagem normalmente
    self.image_widget:paintTo(bb, x, y)
    -- Desenha hachuras horizontais DENSAS (espaçamento de 2px) para escurecer mais
    local spacing = 2
    for i = 0, self.height - 1, spacing do
        bb:paintRect(x, y + i, self.width, 1, Blitbuffer.COLOR_BLACK)
    end
end

--- Cria uma miniatura escurecida de uma carta.
function TarotPlugin:getDimmedCardWidget(card, w, h)
    local img = self:getCardImageWidget(card, w, h)
    return DimmedCard:new{
        image_widget = img,
        width = w,
        height = h,
    }
end

-- Função que retorna as dimensões PADRÃO da carta central (sem override)
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

-- NOVA FUNÇÃO: Retorna o widget da imagem de verso (back card)
function TarotPlugin:getBackCardImageWidget()
    local screen_w = Screen:getWidth()
    local card_w, card_h
    local path
    if self.use_lenormand then
        path = self.plugin_dir .. "/cards_lenormand/Card_Back.png"
        card_w = 250
        card_h = 250
    else
        path = self.plugin_dir .. "/cards_tarot/CardBacks.jpg"
        card_w = math.floor(screen_w * 0.25)
        card_h = math.floor(card_w * (439 / 250))
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
-- ║                  SEÇÃO 7: SALVAMENTO (save/load/delete)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
function TarotPlugin:saveReading(cards, title, note)
    self:ensureSavesDir()
    
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local filename_base
    if title and title ~= "" then
        filename_base = title:gsub("[^%w%d%s]", ""):gsub("%s+", "_"):sub(1, 50)
    else
        filename_base = "tiragem"
    end
    
    local counter = 1
    local filename = timestamp .. "_" .. filename_base .. ".txt"
    local filepath = self.saves_dir .. "/" .. filename
    
    while lfs.attributes(filepath) do
        counter = counter + 1
        filename = timestamp .. "_" .. filename_base .. "_" .. counter .. ".txt"
        filepath = self.saves_dir .. "/" .. filename
    end
    
    local lang = self.language
    local lines = {}
    
    if title and title ~= "" then
        table.insert(lines, title)
        table.insert(lines, "")
    end
    
    if note and note ~= "" then
        table.insert(lines, note)
        table.insert(lines, "")
    end
    
    for i, card_data in ipairs(cards) do
        local card = card_data.card
        local is_reversed = card_data.is_reversed
        
        local position_text = is_reversed and self:getTranslation("reversed") or self:getTranslation("upright")
        local name_text = card.name[lang] or card.name.pt
        
        local meaning
        if self.use_lenormand then
            meaning = card.meaning[lang] or card.meaning.pt
        else
            meaning = is_reversed and (card.reversed_meaning[lang] or card.reversed_meaning.pt) or (card.meaning[lang] or card.meaning.pt)
        end
        
        table.insert(lines, "Carta " .. i .. " — " .. name_text .. " (" .. position_text .. ")")
        table.insert(lines, "")
        table.insert(lines, meaning)
        table.insert(lines, "")
    end
    
    table.insert(lines, "—")
    table.insert(lines, os.date("%d/%m/%Y %H:%M"))
    
    local content = table.concat(lines, "\n")
    
    local file, err = io.open(filepath, "w")
    if not file then
        logger.warn("tarot.koplugin: Erro ao salvar tiragem:", err)
        UIManager:show(InfoMessage:new{ text = self:getTranslation("save_error") })
        return false
    end
    
    file:write(content)
    file:close()
    
    UIManager:show(InfoMessage:new{ text = self:getTranslation("save_success") })
    return true
end

function TarotPlugin:getSavedReadings()
    self:ensureSavesDir()
    local files = {}
    
    for file in lfs.dir(self.saves_dir) do
        if file ~= "." and file ~= ".." and file:match("%.txt$") then
            local filepath = self.saves_dir .. "/" .. file
            local attr = lfs.attributes(filepath)
            if attr and attr.mode == "file" then
                table.insert(files, {
                    filename = file,
                    filepath = filepath,
                    modification = attr.modification,
                })
            end
        end
    end
    
    table.sort(files, function(a, b)
        return a.modification > b.modification
    end)
    
    return files
end

function TarotPlugin:showSavedReadingsMenu()
    local files = self:getSavedReadings()
    
    if #files == 0 then
        UIManager:show(InfoMessage:new{ text = self:getTranslation("no_saved") })
        return
    end
    
    local buttons = {}
    for _, file in ipairs(files) do
        local display_name = file.filename:gsub("%.txt$", "")
        display_name = display_name:gsub("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d_", "")
        display_name = display_name:gsub("_", " ")
        
        table.insert(buttons, {
            {
                text = display_name,
                callback = function()
                    UIManager:close(self.saved_menu_dialog)
                    self:showFileOptions(file)
                end,
            },
        })
    end
    
    table.insert(buttons, {
        {
            text = self:getTranslation("close"),
            is_enter_default = true,
            callback = function()
                UIManager:close(self.saved_menu_dialog)
            end,
        },
    })
    
    self.saved_menu_dialog = ButtonDialog:new{
        title = self:getTranslation("saved_readings"),
        buttons = buttons,
    }
    
    UIManager:show(self.saved_menu_dialog)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showFileOptions(file)
    local buttons = {
        {
            {
                text = self:getTranslation("open_reading"),
                callback = function()
                    UIManager:close(self.file_options_dialog)
                    ReaderUI:showReader(file.filepath)
                end,
            },
        },
        {
            {
                text = self:getTranslation("delete_reading"),
                callback = function()
                    UIManager:close(self.file_options_dialog)
                    self:confirmDeleteFile(file)
                end,
            },
        },
        {
            {
                text = self:getTranslation("close"),
                is_enter_default = true,
                callback = function()
                    UIManager:close(self.file_options_dialog)
                end,
            },
        },
    }
    
    local title_display = file.filename:gsub("%.txt$", "")
    title_display = title_display:gsub("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d_", "")
    title_display = title_display:gsub("_", " ")
    
    self.file_options_dialog = ButtonDialog:new{
        title = title_display,
        buttons = buttons,
    }
    
    UIManager:show(self.file_options_dialog)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:confirmDeleteFile(file)
    local buttons = {
        {
            {
                text = self:getTranslation("delete_reading"),
                callback = function()
                    UIManager:close(self.delete_confirm_dialog)
                    local success = os.remove(file.filepath)
                    if success then
                        UIManager:show(InfoMessage:new{ text = self:getTranslation("delete_success") })
                    else
                        UIManager:show(InfoMessage:new{ text = self:getTranslation("delete_error") })
                    end
                end,
            },
        },
        {
            {
                text = self:getTranslation("close"),
                is_enter_default = true,
                callback = function()
                    UIManager:close(self.delete_confirm_dialog)
                end,
            },
        },
    }
    
    self.delete_confirm_dialog = ButtonDialog:new{
        title = self:getTranslation("delete_confirm"),
        buttons = buttons,
    }
    
    UIManager:show(self.delete_confirm_dialog)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showSaveTitleInput(cards)
    local title_input
    title_input = InputDialog:new{
        title = self:getTranslation("save_title"),
        input_hint = self:getTranslation("save_title_hint"),
        input_type = "string",
        buttons = {
            {
                {
                    text = "OK",
                    is_enter_default = true,
                    callback = function()
                        local title = title_input:getInputText()
                        if #title > 50 then
                            title = title:sub(1, 50)
                        end
                        UIManager:close(title_input)
                        self:showSaveNoteInput(cards, title)
                    end,
                },
            },
            {
                {
                    text = self:getTranslation("close"),
                    callback = function()
                        UIManager:close(title_input)
                    end,
                },
            },
        },
    }
    UIManager:show(title_input)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showSaveNoteInput(cards, title)
    local note_input
    note_input = InputDialog:new{
        title = self:getTranslation("save_note"),
        input_hint = self:getTranslation("save_note_hint"),
        input_type = "string",
        buttons = {
            {
                {
                    text = "OK",
                    is_enter_default = true,
                    callback = function()
                        local note = note_input:getInputText()
                        if #note > 500 then
                            note = note:sub(1, 500)
                        end
                        UIManager:close(note_input)
                        self:saveReading(cards, title, note)
                    end,
                },
            },
            {
                {
                    text = self:getTranslation("close"),
                    callback = function()
                        UIManager:close(note_input)
                    end,
                },
            },
        },
    }
    UIManager:show(note_input)
    UIManager:setDirty(nil, "full")
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║   SEÇÃO 8: DIÁLOGO DA CARTA (CardDialog) – CENTRAL FIXA + MINIATURAS        ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local CardDialog = InputContainer:extend{
    cards = nil,
    current_index = 1,
    card_labels = nil,
    on_new = nil,
    plugin = nil,
    title_label = nil,
    is_daily = false,
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

    -- Verifica se a imagem real existe
    local card_path = self.plugin:getCardImagePath(card)
    local has_image = card_path and lfs.attributes(card_path) and lfs.attributes(card_path).mode == "file"
    local hide_name = (self.plugin.use_lenormand) and (lang == "en") and has_image

    -- 1. Título
    local title_suffix = self.plugin:getTranslation("title")
    if self.plugin.use_lenormand then
        title_suffix = self.plugin:getTranslation("lenormand_title")
    end
    local title_text = title_suffix

    local title_w = TextWidget:new{
        text      = title_text,
        face      = Font:getFace("tfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    -- 2. Imagem da carta (centralizada, tamanho fixo, com miniaturas laterais se houver)
    local card_image
    if total_cards > 1 then
        -- Espaçamento entre carta central e miniaturas
        local spacing = 24
        local has_left = self.current_index > 1
        local has_right = self.current_index < total_cards

        -- Tamanho PADRÃO da carta central (NUNCA muda)
        local main_w, main_h = self.plugin:getDefaultCardSize(card)
        local center_img = self.plugin:getCardImageWidget(card, main_w, main_h)

        -- Tamanho das miniaturas: 2/3 da central
        local mini_w = math.floor(main_w * 2/3)
        local mini_h = math.floor(main_h * 2/3)

        -- Calcula o espaço restante para cada lado após descontar a central
        -- A central ocupará exatamente main_w pixels.
        -- O espaço total disponível é iw.
        -- O espaço restante para os lados é (iw - main_w).
        -- Esse espaço é dividido igualmente entre esquerda e direita.
        local remaining = iw - main_w
        local half_remaining = math.floor(remaining / 2)

        -- Widgets das miniaturas
        local left_img, right_img
        if has_left then
            local left_card = self.cards[self.current_index - 1].card
            left_img = self.plugin:getDimmedCardWidget(left_card, mini_w, mini_h)
        end
        if has_right then
            local right_card = self.cards[self.current_index + 1].card
            right_img = self.plugin:getDimmedCardWidget(right_card, mini_w, mini_h)
        end

        -- Montagem do grupo horizontal com centralização absoluta da carta principal
        local hgroup = HorizontalGroup:new{ align = "center" }

        if has_left then
            -- Lado esquerdo: espaço flexível + miniatura + espaçamento
            -- O espaço restante à esquerda deve acomodar a miniatura + spacing
            local left_padding = half_remaining - mini_w - spacing
            if left_padding < 0 then left_padding = 0 end
            table.insert(hgroup, HorizontalSpan:new{ width = left_padding })
            table.insert(hgroup, left_img)
            table.insert(hgroup, HorizontalSpan:new{ width = spacing })
        else
            -- Sem miniatura à esquerda, apenas o espaço
            table.insert(hgroup, HorizontalSpan:new{ width = half_remaining })
        end

        -- Carta central
        table.insert(hgroup, center_img)

        if has_right then
            -- Lado direito: espaçamento + miniatura + espaço flexível
            local right_padding = half_remaining - mini_w - spacing
            if right_padding < 0 then right_padding = 0 end
            table.insert(hgroup, HorizontalSpan:new{ width = spacing })
            table.insert(hgroup, right_img)
            table.insert(hgroup, HorizontalSpan:new{ width = right_padding })
        else
            -- Sem miniatura à direita, apenas o espaço
            table.insert(hgroup, HorizontalSpan:new{ width = half_remaining })
        end

        card_image = hgroup
    else
        -- Carta única: widget padrão centralizado
        card_image = self.plugin:getCardImageWidget(card)
    end

    -- 3. Nome da carta (condicional)
    local name_w
    if not hide_name then
        local name_text = card.name[lang] or card.name.pt
        if is_reversed and not self.plugin.use_lenormand then
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

    -- 4. Separador
    local divider = TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "center",
    }

    -- 5. Significado
    local meaning_text
    if self.plugin.use_lenormand then
        meaning_text = card.meaning[lang] or card.meaning.pt
    else
        meaning_text = is_reversed and (card.reversed_meaning[lang] or card.reversed_meaning.pt) or (card.meaning[lang] or card.meaning.pt)
    end
    
    local meaning_w = TextBoxWidget:new{
        text      = meaning_text,
        face      = Font:getFace("cfont"),
        width     = iw,
        alignment = "center",
    }

    -- 6. Botões de navegação
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
                        is_daily = self.is_daily,
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
                        is_daily = self.is_daily,
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

    -- Botões fixos: Salvar, (Novo/Diário), Fechar
    local btn_save = Button:new{
        text     = self.plugin:getTranslation("save"),
        width    = math.floor(iw * 0.30),
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
            self.plugin:showSaveTitleInput(self.cards)
        end,
    }

    local btn_close = Button:new{
        text     = self.plugin:getTranslation("close"),
        width    = math.floor(iw * 0.30),
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    }

    local btns_row
    if self.is_daily then
        btns_row = HorizontalGroup:new{
            align = "center",
            btn_save,
            HorizontalSpan:new{ width = math.floor(iw * 0.06) },
            btn_close,
        }
    else
        local btn_new = Button:new{
            text     = self.plugin:getTranslation("new"),
            width    = math.floor(iw * 0.30),
            radius   = Size.radius.button,
            callback = function()
                UIManager:close(self)
                UIManager:setDirty(nil, "full")
                if self.on_new then self.on_new() end
            end,
        }

        btns_row = HorizontalGroup:new{
            align = "center",
            btn_save,
            HorizontalSpan:new{ width = math.floor(iw * 0.03) },
            btn_new,
            HorizontalSpan:new{ width = math.floor(iw * 0.03) },
            btn_close,
        }
    end

    -- Montagem do conteúdo
    local content = VerticalGroup:new{
        align = "center",
        -- 1. Título
        title_w,
        VerticalSpan:new{ width = Size.span.vertical_default },
        -- 2. Imagem (centralizada, tamanho fixo, com miniaturas)
        card_image,
        VerticalSpan:new{ width = Size.span.vertical_default },
    }

    -- 3. Nome
    if name_w then
        table.insert(content, name_w)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    end

    -- 4. Separador
    table.insert(content, divider)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    -- 5. Significado
    table.insert(content, meaning_w)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    -- 6. Navegação
    if nav_row then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, nav_row)
    end

    -- 7. Botões de ação
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

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║   NOVO DIÁLOGO: CARTA OCULTA (HiddenCardDialog) – VERSÃO FINAL              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local HiddenCardDialog = InputContainer:extend{
    plugin = nil,
    cards = nil,
    on_new = nil,
    is_daily = false,
    on_reveal = nil,
}

function HiddenCardDialog:init()
    local sw  = Screen:getWidth()
    local w   = math.floor(sw * 0.84)
    local pad = Size.padding.large
    local iw  = w - pad * 2

    local title_text = self.plugin:getTranslation("title")
    local title_w = TextWidget:new{
        text      = title_text,
        face      = Font:getFace("tfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local back_path
    if self.plugin.use_lenormand then
        back_path = self.plugin.plugin_dir .. "/cards_lenormand/Card_Back.png"
    else
        back_path = self.plugin.plugin_dir .. "/cards_tarot/CardBacks.jpg"
    end
    local back_attr = lfs.attributes(back_path)
    local has_back_image = back_attr and back_attr.mode == "file"

    local screen_w = Screen:getWidth()
    local card_w, card_h
    if self.plugin.use_lenormand then
        card_w = 250
        card_h = 250
    else
        card_w = math.floor(screen_w * 0.25)
        card_h = math.floor(card_w * (439 / 250))
    end

    local image_widget
    if has_back_image then
        image_widget = ImageWidget:new{
            file = back_path,
            width = card_w,
            height = card_h,
            scale_for_dpi = false,
        }
    else
        image_widget = FrameContainer:new{
            width = card_w,
            height = card_h,
            bordersize = 0,
            background = Blitbuffer.gray(0.8),
            CenterContainer:new{
                dimen = { w = card_w, h = card_h },
                TextWidget:new{
                    text = "?",
                    face = Font:getFace("tfont"),
                    bold = true,
                    alignment = "center",
                },
            },
        }
    end

    local btn_reveal = Button:new{
        text     = self.plugin:getTranslation("reveal"),
        width    = math.floor(iw * 0.5),
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
            if self.on_reveal then
                self.on_reveal()
            end
        end,
    }
    local separator = TextWidget:new{
        text      = "━━━━━━━━━━━━━━━━━━━━",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.7),
        max_width = iw,
        alignment = "center",
    }

    local btn_exit = Button:new{
        text     = self.plugin:getTranslation("exit"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    }

    local content = VerticalGroup:new{
        align = "center",
        title_w,
        VerticalSpan:new{ width = Size.span.vertical_large },
        image_widget,
        VerticalSpan:new{ width = Size.span.vertical_large },
        btn_reveal,
        VerticalSpan:new{ width = Size.span.vertical_default },
        separator,
        VerticalSpan:new{ width = Size.span.vertical_default },
        btn_exit,
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

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║          SEÇÃO 9: DIÁLOGO DE CONFIGURAÇÕES (SettingsDialog)                  ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
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

    -- Tipo de Baralho
    local deck_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("deck_type") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }
    table.insert(rows, deck_section)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_small })

    local tarot_mark = not self.plugin.use_lenormand and "☑" or "☐"
    local lenormand_mark = self.plugin.use_lenormand and "☑" or "☐"

    local deck_btns = HorizontalGroup:new{
        align = "center",
        Button:new{
            text   = tarot_mark .. " " .. self.plugin:getTranslation("tarot_deck"),
            width  = math.floor(iw * 0.47),
            radius = Size.radius.button,
            callback = function()
                if self.plugin.use_lenormand then
                    self.plugin:toggleLenormand()
                end
                UIManager:close(self)
                UIManager:show(SettingsDialog:new{ plugin = self.plugin })
                UIManager:setDirty(nil, "full")
            end,
        },
        HorizontalSpan:new{ width = math.floor(iw * 0.06) },
        Button:new{
            text   = lenormand_mark .. " " .. self.plugin:getTranslation("lenormand_deck"),
            width  = math.floor(iw * 0.47),
            radius = Size.radius.button,
            callback = function()
                if not self.plugin.use_lenormand then
                    self.plugin:toggleLenormand()
                end
                UIManager:close(self)
                UIManager:show(SettingsDialog:new{ plugin = self.plugin })
                UIManager:setDirty(nil, "full")
            end,
        },
    }
    table.insert(rows, deck_btns)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

    if not self.plugin.use_lenormand then
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
    end

    -- Carta Oculta
    local hidden_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("hidden_card") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }
    table.insert(rows, hidden_section)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_small })

    local hidden_mark = self.plugin.hidden_card and "☑" or "☐"
    local hidden_label = "  " .. hidden_mark .. "  " .. self.plugin:getTranslation("hidden_card_desc")
    local btn_hidden = Button:new{
        text     = hidden_label,
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            self.plugin:toggleHiddenCard()
            UIManager:close(self)
            UIManager:show(SettingsDialog:new{ plugin = self.plugin })
            UIManager:setDirty(nil, "full")
        end,
    }
    table.insert(rows, btn_hidden)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

    -- Idioma
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
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

    -- Redefinir
    local reset_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("reset_section") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }
    table.insert(rows, reset_section)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_small })

    local restore_label = "  ⚠  " .. self.plugin:getTranslation("restore_desc")
    local btn_restore = Button:new{
        text     = restore_label,
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            local confirm_buttons = {
                {
                    {
                        text = self.plugin:getTranslation("yes"),
                        callback = function()
                            UIManager:close(self.plugin.restore_confirm_dialog)
                            self.plugin:restoreAll()
                            UIManager:close(self)
                            UIManager:show(InfoMessage:new{ text = self.plugin:getTranslation("restore_success") })
                            self.plugin:refreshMenu()
                            UIManager:setDirty(nil, "full")
                        end,
                    },
                },
                {
                    {
                        text = self.plugin:getTranslation("no"),
                        is_enter_default = true,
                        callback = function()
                            UIManager:close(self.plugin.restore_confirm_dialog)
                        end,
                    },
                },
            }
            
            self.plugin.restore_confirm_dialog = ButtonDialog:new{
                title = self.plugin:getTranslation("restore_confirm"),
                buttons = confirm_buttons,
            }
            
            UIManager:show(self.plugin.restore_confirm_dialog)
            UIManager:setDirty(nil, "full")
        end,
    }
    table.insert(rows, btn_restore)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

    -- Botão Sobre (NOVO)
    local btn_about = Button:new{
        text     = self.plugin:getTranslation("about"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            self.plugin:showAboutDialog()
        end,
    }
    table.insert(rows, btn_about)
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

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           SEÇÃO 10: DIÁLOGO DO LIVRO DE CARTAS (CardBookDialog)             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local CardBookDialog = InputContainer:extend{
    plugin = nil,
    card_list = nil,
    current_index = 1,
    parent_callback = nil,
}

function CardBookDialog:init()
    local sw  = Screen:getWidth()
    local w   = math.floor(sw * 0.84)
    local pad = Size.padding.large
    local iw  = w - pad * 2
    local lang = self.plugin.language

    local card = self.card_list[self.current_index]

    local card_path = self.plugin:getCardImagePath(card)
    local has_image = card_path and lfs.attributes(card_path) and lfs.attributes(card_path).mode == "file"
    local hide_ascii = card.symbol and has_image

    local book_title = self.plugin:getTranslation("card_book")
    local title_w = TextWidget:new{
        text      = book_title,
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

    local card_image = self.plugin:getCardImageWidget(card)

    local number_w, suit_w
    if not hide_ascii then
        local number_text = ""
        if card.roman then
            number_text = card.roman .. " - " .. self.plugin:getTranslation("arcana_label") .. " " .. self.plugin:getTranslation("major_arcana")
        elseif card.number then
            number_text = tostring(card.number) .. " - Lenormand"
        elseif card.rank then
            local rank_text = card.rank[lang] or card.rank.pt
            local suit_text = card.suit[lang] or card.suit.pt
            number_text = rank_text .. " - " .. self.plugin:getTranslation("minor_arcana") .. " (" .. suit_text .. ")"
        end
        
        number_w = TextWidget:new{
            text      = number_text,
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = iw,
            alignment = "center",
        }

        if card.symbol then
            suit_w = TextWidget:new{
                text      = card.symbol .. "  " .. card.symbol .. "  " .. card.symbol,
                face      = Font:getFace("smalltfont"),
                fgcolor   = Blitbuffer.gray(0.5),
                max_width = iw,
                alignment = "center",
            }
        elseif card.suit then
            suit_w = TextWidget:new{
                text      = card.suit.symbol .. "  " .. (card.suit[lang] or card.suit.pt) .. "  " .. card.suit.symbol,
                face      = Font:getFace("smalltfont"),
                fgcolor   = Blitbuffer.gray(0.5),
                max_width = iw,
                alignment = "center",
            }
        end
    end

    local name_text = card.name[lang] or card.name.pt
    local name_w = TextWidget:new{
        text      = name_text,
        face      = Font:getFace("cfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local meaning_label_w = TextWidget:new{
        text      = self.plugin:getTranslation("meaning_label") .. ":",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }
    
    local upright_meaning = card.meaning[lang] or card.meaning.pt
    local upright_w = TextBoxWidget:new{
        text      = upright_meaning,
        face      = Font:getFace("cfont"),
        width     = iw,
        alignment = "left",
    }

    local reversed_label_w
    local reversed_w
    if not self.plugin.use_lenormand and card.reversed_meaning then
        reversed_label_w = TextWidget:new{
            text      = self.plugin:getTranslation("reversed_meaning_label") .. ":",
            face      = Font:getFace("smalltfont"),
            bold      = true,
            max_width = iw,
            alignment = "left",
        }
        
        local reversed_meaning = card.reversed_meaning[lang] or card.reversed_meaning.pt
        reversed_w = TextBoxWidget:new{
            text      = reversed_meaning,
            face      = Font:getFace("cfont"),
            width     = iw,
            alignment = "left",
        }
    end

    local nav_row
    if #self.card_list > 1 then
        local btn_prev = Button:new{
            text     = self.plugin:getTranslation("prev"),
            width    = math.floor(iw * 0.30),
            radius   = Size.radius.button,
            enabled  = self.current_index > 1,
            callback = function()
                if self.current_index > 1 then
                    UIManager:close(self)
                    UIManager:show(CardBookDialog:new{
                        plugin = self.plugin,
                        card_list = self.card_list,
                        current_index = self.current_index - 1,
                        parent_callback = self.parent_callback,
                    })
                    UIManager:setDirty(nil, "full")
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
        
        local btn_next = Button:new{
            text     = self.plugin:getTranslation("next"),
            width    = math.floor(iw * 0.30),
            radius   = Size.radius.button,
            enabled  = self.current_index < #self.card_list,
            callback = function()
                if self.current_index < #self.card_list then
                    UIManager:close(self)
                    UIManager:show(CardBookDialog:new{
                        plugin = self.plugin,
                        card_list = self.card_list,
                        current_index = self.current_index + 1,
                        parent_callback = self.parent_callback,
                    })
                    UIManager:setDirty(nil, "full")
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

    local btn_back = Button:new{
        text     = self.plugin:getTranslation("back"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            if self.parent_callback then
                self.parent_callback()
            end
            UIManager:setDirty(nil, "full")
        end,
    }

    local content = VerticalGroup:new{
        align = "center",
        title_w,
        VerticalSpan:new{ width = Size.span.vertical_small },
        divider,
        VerticalSpan:new{ width = Size.span.vertical_default },
    }

    table.insert(content, card_image)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    if number_w then
        table.insert(content, number_w)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    end
    
    if suit_w then
        table.insert(content, suit_w)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    end
    
    table.insert(content, name_w)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, divider)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, meaning_label_w)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    table.insert(content, upright_w)
    
    if reversed_label_w and reversed_w then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, reversed_label_w)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
        table.insert(content, reversed_w)
    end
    
    if nav_row then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, nav_row)
    end
    
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(content, btn_back)

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

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║      SEÇÃO 11: MENU DO LIVRO DE CARTAS (CardBookMenu)                        ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local CardBookMenu = InputContainer:extend{
    plugin = nil,
}

function CardBookMenu:init()
    local sw  = Screen:getWidth()
    local w   = math.floor(sw * 0.84)
    local pad = Size.padding.large
    local iw  = w - pad * 2

    local title = TextWidget:new{
        text      = self.plugin:getTranslation("card_book"),
        face      = Font:getFace("tfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local tarot_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("tarot_deck") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }

    local btn_major = Button:new{
        text     = self.plugin:getTranslation("major_arcana_list"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            self:showCardList(MAJOR_ARCANA)
        end,
    }
    
    local btn_minor = Button:new{
        text     = self.plugin:getTranslation("minor_arcana_list"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            self:showMinorArcanaMenu()
        end,
    }
    
    local btn_all = Button:new{
        text     = self.plugin:getTranslation("all_cards"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            self:showCardList(FULL_DECK)
        end,
    }

    local lenormand_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("lenormand_deck") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }
    
    local btn_lenormand = Button:new{
        text     = self.plugin:getTranslation("lenormand_list"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            self:showCardList(LENORMAND_DECK)
        end,
    }
    
    local btn_close = Button:new{
        text     = self.plugin:getTranslation("close"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    }

    local content = VerticalGroup:new{
        align = "center",
        title,
        VerticalSpan:new{ width = Size.span.vertical_large },
        tarot_section,
        VerticalSpan:new{ width = Size.span.vertical_small },
        btn_major,
        VerticalSpan:new{ width = Size.span.vertical_small },
        btn_minor,
        VerticalSpan:new{ width = Size.span.vertical_small },
        btn_all,
        VerticalSpan:new{ width = Size.span.vertical_default },
        lenormand_section,
        VerticalSpan:new{ width = Size.span.vertical_small },
        btn_lenormand,
        VerticalSpan:new{ width = Size.span.vertical_large },
        btn_close,
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

function CardBookMenu:showMinorArcanaMenu()
    local sw  = Screen:getWidth()
    local w   = math.floor(sw * 0.84)
    local pad = Size.padding.large
    local iw  = w - pad * 2

    local suit_keys = {
        { name = self.plugin:getTranslation("suit_wands"), symbol = "|", start = 22, end_ = 35 },
        { name = self.plugin:getTranslation("suit_cups"), symbol = "~", start = 36, end_ = 49 },
        { name = self.plugin:getTranslation("suit_swords"), symbol = "+", start = 50, end_ = 63 },
        { name = self.plugin:getTranslation("suit_pentacles"), symbol = "*", start = 64, end_ = 77 },
    }
    
    local MinorArcanaMenu = InputContainer:extend{
        plugin = self.plugin,
        showCardList = function(this, cards)
            UIManager:show(CardBookDialog:new{
                plugin = this.plugin,
                card_list = cards,
                current_index = 1,
                parent_callback = function()
                    UIManager:show(CardBookMenu:new{ plugin = this.plugin })
                end,
            })
            UIManager:setDirty(nil, "full")
        end,
    }
    
    function MinorArcanaMenu:init()
        local buttons = {}
        
        for _, suit_data in ipairs(suit_keys) do
            local btn = Button:new{
                text     = suit_data.symbol .. " " .. suit_data.name,
                width    = iw,
                radius   = Size.radius.button,
                callback = function()
                    local cards = {}
                    for _, card in ipairs(MINOR_ARCANA) do
                        if card.id >= suit_data.start and card.id <= suit_data.end_ then
                            table.insert(cards, card)
                        end
                    end
                    
                    UIManager:close(self)
                    self:showCardList(cards)
                end,
            }
            table.insert(buttons, btn)
            table.insert(buttons, VerticalSpan:new{ width = Size.span.vertical_small })
        end
        
        local btn_all_minor = Button:new{
            text     = self.plugin:getTranslation("all_cards") .. " - " .. self.plugin:getTranslation("minor_arcana"),
            width    = iw,
            radius   = Size.radius.button,
            callback = function()
                UIManager:close(self)
                self:showCardList(MINOR_ARCANA)
            end,
        }
        
        table.insert(buttons, btn_all_minor)
        table.insert(buttons, VerticalSpan:new{ width = Size.span.vertical_default })
        
        local btn_back = Button:new{
            text     = self.plugin:getTranslation("back"),
            width    = iw,
            radius   = Size.radius.button,
            callback = function()
                UIManager:close(self)
                UIManager:show(CardBookMenu:new{ plugin = self.plugin })
                UIManager:setDirty(nil, "full")
            end,
        }
        table.insert(buttons, btn_back)

        local title = TextWidget:new{
            text      = self.plugin:getTranslation("minor_arcana_list"),
            face      = Font:getFace("tfont"),
            bold      = true,
            max_width = iw,
            alignment = "center",
        }
        
        local content = VerticalGroup:new{
            align = "center",
            title,
            VerticalSpan:new{ width = Size.span.vertical_large },
            VerticalGroup:new{ align = "center", unpack(buttons) },
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
    
    local submenu = MinorArcanaMenu:new{
        plugin = self.plugin,
    }
    
    UIManager:show(submenu)
    UIManager:setDirty(nil, "full")
end

function CardBookMenu:showCardList(cards)
    UIManager:show(CardBookDialog:new{
        plugin = self.plugin,
        card_list = cards,
        current_index = 1,
        parent_callback = function()
            UIManager:show(CardBookMenu:new{ plugin = self.plugin })
        end,
    })
    UIManager:setDirty(nil, "full")
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                  SEÇÃO 12: MENU E ORQUESTRAÇÃO                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
function TarotPlugin:addToMainMenu(menu_items)
    menu_items.tarot = {
        text         = self:getTranslation("title"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text     = self:getTranslation("spreads"),
                sub_item_table = {
                    {
                        text     = self:getTranslation("daily_card"),
                        callback = function()
                            self:showDailyCard()
                        end,
                    },
                    {
                        text     = self:getTranslation("one_card"),
                        callback = function()
                            self:showSingleCard()
                        end,
                    },
                    {
                        text     = self:getTranslation("three_cards"),
                        callback = function()
                            self:showThreeCards()
                        end,
                    },
                },
            },
            {
                text     = self:getTranslation("saved_readings"),
                callback = function()
                    self:showSavedReadingsMenu()
                end,
            },
            {
                text     = self:getTranslation("card_book"),
                callback = function()
                    self:showCardBook()
                end,
            },
            {
                text     = self:getTranslation("configuration"),
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

function TarotPlugin:showAboutDialog()
    local sw  = Screen:getWidth()
    local w   = math.floor(sw * 0.8)
    local pad = Size.padding.large
    local iw  = w - pad * 2

    local text = self:getTranslation("about_text")
    local textbox = TextBoxWidget:new{
        text      = text,
        face      = Font:getFace("cfont"),
        width     = iw,
        alignment = "left",
    }

    local btn_close = Button:new{
        text     = self:getTranslation("close"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            -- Fecha o widget raiz (CenterContainer) que foi exibido
            UIManager:close(self.about_dialog)
            UIManager:setDirty(nil, "full")
        end,
    }

    local content = VerticalGroup:new{
        align = "center",
        textbox,
        VerticalSpan:new{ width = Size.span.vertical_default },
        btn_close,
    }

    local frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        radius     = Size.radius.window,
        padding    = pad,
        content,
    }

    -- Armazena o CenterContainer (widget raiz) para poder fechá‑lo
    self.about_dialog = CenterContainer:new{
        dimen = Screen:getSize(),
        frame,
    }

    UIManager:show(self.about_dialog)
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showCardBook()
    UIManager:show(CardBookMenu:new{ plugin = self })
    UIManager:setDirty(nil, "full")
end

function TarotPlugin:showSingleCard()
    local loading = InfoMessage:new{ text = self:getTranslation("loading") }
    UIManager:show(loading)
    UIManager:setDirty(nil, "full")
    UIManager:scheduleIn(0.5, function()
        local card, is_reversed = self:drawCard()
        UIManager:close(loading)
        
        local cards = {{ card = card, is_reversed = is_reversed }}
        local on_new_func = function() self:showSingleCard() end
        
        if self.hidden_card then
            local hidden_dlg = HiddenCardDialog:new{
                plugin = self,
                cards = cards,
                on_new = on_new_func,
                is_daily = false,
                on_reveal = function()
                    UIManager:show(CardDialog:new{
                        cards = cards,
                        current_index = 1,
                        plugin = self,
                        on_new = on_new_func,
                        is_daily = false,
                    })
                    UIManager:setDirty(nil, "full")
                end,
            }
            UIManager:show(hidden_dlg)
        else
            local dlg = CardDialog:new{
                cards = cards,
                current_index = 1,
                plugin = self,
                on_new = on_new_func,
                is_daily = false,
            }
            UIManager:show(dlg)
        end
        UIManager:setDirty(nil, "full")
    end)
end

function TarotPlugin:showThreeCards()
    local loading = InfoMessage:new{ text = self:getTranslation("loading") }
    UIManager:show(loading)
    UIManager:setDirty(nil, "full")
    UIManager:scheduleIn(0.5, function()
        local drawn = self:drawUniqueCards(3)
        UIManager:close(loading)
        
        local on_new_func = function() self:showThreeCards() end
        
        if self.hidden_card then
            local hidden_dlg = HiddenCardDialog:new{
                plugin = self,
                cards = drawn,
                on_new = on_new_func,
                is_daily = false,
                on_reveal = function()
                    UIManager:show(CardDialog:new{
                        cards = drawn,
                        current_index = 1,
                        card_labels = {
                            string.format(self:getTranslation("card_count"), 1, 3),
                            string.format(self:getTranslation("card_count"), 2, 3),
                            string.format(self:getTranslation("card_count"), 3, 3),
                        },
                        plugin = self,
                        on_new = on_new_func,
                        is_daily = false,
                    })
                    UIManager:setDirty(nil, "full")
                end,
            }
            UIManager:show(hidden_dlg)
        else
            local dlg = CardDialog:new{
                cards = drawn,
                current_index = 1,
                card_labels = {
                    string.format(self:getTranslation("card_count"), 1, 3),
                    string.format(self:getTranslation("card_count"), 2, 3),
                    string.format(self:getTranslation("card_count"), 3, 3),
                },
                plugin = self,
                on_new = on_new_func,
                is_daily = false,
            }
            UIManager:show(dlg)
        end
        UIManager:setDirty(nil, "full")
    end)
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

function TarotPlugin:showDailyCard()
    local loading = InfoMessage:new{ text = self:getTranslation("loading") }
    UIManager:show(loading)
    UIManager:setDirty(nil, "full")
    
    UIManager:scheduleIn(0.3, function()
        local today = self:getCurrentDateStr()
        local stored_date = G_reader_settings:readSetting("tarot_daily_date") or ""
        local card, is_reversed
        
        if stored_date == today then
            local card_id = G_reader_settings:readSetting("tarot_daily_card_id")
            local is_lenormand = G_reader_settings:readSetting("tarot_daily_card_is_lenormand")
            card = self:getCardById(card_id, is_lenormand)
            is_reversed = G_reader_settings:readSetting("tarot_daily_card_is_reversed") or false
        else
            local deck = self:getActiveDeck()
            card = deck[math.random(1, #deck)]
            is_reversed = false
            if self.allow_reversed and not self.use_lenormand then
                is_reversed = math.random(2) == 1
            end
            G_reader_settings:saveSetting("tarot_daily_date", today)
            G_reader_settings:saveSetting("tarot_daily_card_id", card.id)
            G_reader_settings:saveSetting("tarot_daily_card_is_lenormand", self.use_lenormand)
            G_reader_settings:saveSetting("tarot_daily_card_is_reversed", is_reversed)
            G_reader_settings:saveSetting("tarot_daily_revealed_date", "")
        end
        
        UIManager:close(loading)
        
        local cards = {{ card = card, is_reversed = is_reversed }}
        local on_new_func = function() self:showDailyCard() end
        
        local revealed_date = G_reader_settings:readSetting("tarot_daily_revealed_date") or ""
        
        if self.hidden_card and revealed_date ~= today then
            local hidden_dlg = HiddenCardDialog:new{
                plugin = self,
                cards = cards,
                on_new = on_new_func,
                is_daily = true,
                on_reveal = function()
                    G_reader_settings:saveSetting("tarot_daily_revealed_date", today)
                    UIManager:show(CardDialog:new{
                        cards = cards,
                        current_index = 1,
                        plugin = self,
                        title_label = self:getTranslation("daily_card"),
                        on_new = on_new_func,
                        is_daily = true,
                    })
                    UIManager:setDirty(nil, "full")
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
            }
            UIManager:show(dlg)
        end
        UIManager:setDirty(nil, "full")
    end)
end

return TarotPlugin

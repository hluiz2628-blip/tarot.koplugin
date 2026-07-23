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
-- ║                     SEÇÃO 0: LOCALIZAÇÃO (l10n)                             ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- Carrega traduções da pasta l10n se disponível
local l10n_strings = {}
local function loadL10n(lang_code)
    local plugin_dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
    local l10n_path = plugin_dir .. "l10n/" .. lang_code .. ".po"
    local file = io.open(l10n_path, "r")
    if not file then
        -- Tenta caminho alternativo para KOReader
        l10n_path = "./l10n/" .. lang_code .. ".po"
        file = io.open(l10n_path, "r")
    end
    if not file then return {} end
    
    local content = file:read("*all")
    file:close()
    
    local result = {}
    for msgid, msgstr in content:gmatch('msgid%s*"([^"]+)"%s*msgstr%s*"([^"]*)"') do
        if msgid ~= "" and msgstr ~= "" then
            result[msgid] = msgstr
        end
    end
    return result
end

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
        hidden_card = "Carta Oculta",
        hidden_card_desc = "Mostrar verso da carta antes de revelar a tiragem",
        click_on_card = "clique na carta",
        exit = "Sair",
        reveal = "Revelar",
        about = "Sobre",
        about_title = "Sobre o Tarot e Lenormand",
        about_text = [[O Tarot é um baralho de 78 cartas, dividido em Arcanos Maiores (22) e Menores (56), usado para reflexão e autoconhecimento. O Baralho Cigano (Lenormand) possui 36 cartas com simbolismo direto para orientação prática.

Agradecimentos pelas imagens gratuitas:
• Lenormand Cards por Yve Lepkowski (https://stolen-thyme.com/)
• Tarot Cards por Luciella Elisabeth Scarlett (https://luciellaes.itch.io/)]],
        view_in_book = "ver no livro",
        keywords_label = "Palavras-chave",
        planet_sign_label = "Planeta / Signo",
        timing_label = "Timing",
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
        hidden_card = "Hidden Card",
        hidden_card_desc = "Show card back before revealing the spread",
        click_on_card = "click on the card",
        exit = "Exit",
        reveal = "Reveal",
        about = "About",
        about_title = "About Tarot and Lenormand",
        about_text = [[Tarot is a deck of 78 cards, divided into Major Arcana (22) and Minor Arcana (56), used for reflection and self-knowledge. The Lenormand deck has 36 cards with direct symbolism for practical guidance.

Credits for the free card images:
• Lenormand Cards by Yve Lepkowski (https://stolen-thyme.com/)
• Tarot Cards by Luciella Elisabeth Scarlett (https://luciellaes.itch.io/)]],
        view_in_book = "view in book",
        keywords_label = "Keywords",
        planet_sign_label = "Planet / Sign",
        timing_label = "Timing",
    }
}

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 2: CARTAS - ARCANOS MAIORES (22)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local MAJOR_ARCANA = {
    {
        id = 0, roman = "0",
        name = { pt = "O Louco", en = "The Fool" },
        keywords = { pt = "Recomeço, espontaneidade, fé, risco", en = "New beginning, spontaneity, faith, risk" },
        planet = { pt = "Urano", en = "Uranus" },
        timing = { pt = "Imediato, imprevisível", en = "Immediate, unpredictable" },
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
        keywords = { pt = "Poder, habilidade, manifestação, foco", en = "Power, skill, manifestation, focus" },
        planet = { pt = "Mercúrio", en = "Mercury" },
        timing = { pt = "Rápido, agora é a hora", en = "Fast, now is the time" },
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
        keywords = { pt = "Intuição, mistério, inconsciente, sabedoria", en = "Intuition, mystery, subconscious, wisdom" },
        planet = { pt = "Lua", en = "Moon" },
        timing = { pt = "Ciclos lunares, 28 dias", en = "Lunar cycles, 28 days" },
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
        keywords = { pt = "Abundância, fertilidade, natureza, nutrição", en = "Abundance, fertility, nature, nurturing" },
        planet = { pt = "Vênus", en = "Venus" },
        timing = { pt = "9 meses, primavera", en = "9 months, spring" },
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
        keywords = { pt = "Autoridade, estrutura, liderança, estabilidade", en = "Authority, structure, leadership, stability" },
        planet = { pt = "Áries", en = "Aries" },
        timing = { pt = "1 ano, logo", en = "1 year, soon" },
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
        keywords = { pt = "Tradição, sabedoria, orientação, ensino", en = "Tradition, wisdom, guidance, teaching" },
        planet = { pt = "Touro", en = "Taurus" },
        timing = { pt = "5 semanas, lento mas constante", en = "5 weeks, slow but steady" },
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
        keywords = { pt = "Amor, escolha, harmonia, parceria", en = "Love, choice, harmony, partnership" },
        planet = { pt = "Gêmeos", en = "Gemini" },
        timing = { pt = "Decisão iminente", en = "Imminent decision" },
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
        keywords = { pt = "Vitória, determinação, controle, avanço", en = "Victory, determination, control, progress" },
        planet = { pt = "Câncer", en = "Cancer" },
        timing = { pt = "7 semanas", en = "7 weeks" },
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
        keywords = { pt = "Coragem, força interior, compaixão, domínio", en = "Courage, inner strength, compassion, mastery" },
        planet = { pt = "Leão", en = "Leo" },
        timing = { pt = "8 semanas", en = "8 weeks" },
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
        keywords = { pt = "Introspecção, solidão, sabedoria, busca interior", en = "Introspection, solitude, wisdom, inner search" },
        planet = { pt = "Virgem", en = "Virgo" },
        timing = { pt = "9 meses, lento", en = "9 months, slow" },
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
        keywords = { pt = "Mudança, destino, ciclos, sorte", en = "Change, destiny, cycles, luck" },
        planet = { pt = "Júpiter", en = "Jupiter" },
        timing = { pt = "Em movimento, cíclico", en = "In motion, cyclical" },
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
        keywords = { pt = "Equilíbrio, verdade, lei, causa e efeito", en = "Balance, truth, law, cause and effect" },
        planet = { pt = "Libra", en = "Libra" },
        timing = { pt = "Em avaliação, justo", en = "Under review, fair" },
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
        keywords = { pt = "Sacrifício, suspensão, nova visão, entrega", en = "Sacrifice, suspension, new perspective, surrender" },
        planet = { pt = "Netuno", en = "Neptune" },
        timing = { pt = "Indeterminado, pausa", en = "Indeterminate, pause" },
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
        keywords = { pt = "Transformação, fim, renascimento, transição", en = "Transformation, ending, rebirth, transition" },
        planet = { pt = "Escorpião", en = "Scorpio" },
        timing = { pt = "Outono, breve", en = "Autumn, shortly" },
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
        keywords = { pt = "Paciência, equilíbrio, moderação, harmonia", en = "Patience, balance, moderation, harmony" },
        planet = { pt = "Sagitário", en = "Sagittarius" },
        timing = { pt = "Paciência, gradual", en = "Patience, gradual" },
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
        keywords = { pt = "Tentação, apego, sombra, materialismo", en = "Temptation, attachment, shadow, materialism" },
        planet = { pt = "Capricórnio", en = "Capricorn" },
        timing = { pt = "15 dias", en = "15 days" },
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
        keywords = { pt = "Revelação, ruptura, caos, reconstrução", en = "Revelation, upheaval, chaos, reconstruction" },
        planet = { pt = "Marte", en = "Mars" },
        timing = { pt = "Súbito, inesperado", en = "Sudden, unexpected" },
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
        keywords = { pt = "Esperança, fé, inspiração, renovação", en = "Hope, faith, inspiration, renewal" },
        planet = { pt = "Aquário", en = "Aquarius" },
        timing = { pt = "17 dias", en = "17 days" },
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
        keywords = { pt = "Ilusão, intuição, medo, subconsciente", en = "Illusion, intuition, fear, subconscious" },
        planet = { pt = "Peixes", en = "Pisces" },
        timing = { pt = "28 dias, noturno", en = "28 days, nocturnal" },
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
        keywords = { pt = "Alegria, sucesso, vitalidade, clareza", en = "Joy, success, vitality, clarity" },
        planet = { pt = "Sol", en = "Sun" },
        timing = { pt = "19 dias, diurno", en = "19 days, diurnal" },
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
        keywords = { pt = "Renovação, despertar, perdão, chamado", en = "Renewal, awakening, forgiveness, calling" },
        planet = { pt = "Plutão", en = "Pluto" },
        timing = { pt = "Renovação, despertar", en = "Renewal, awakening" },
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
        keywords = { pt = "Completude, realização, integração, sucesso", en = "Completion, fulfillment, integration, success" },
        planet = { pt = "Saturno", en = "Saturn" },
        timing = { pt = "21 dias/meses, ciclo completo", en = "21 days/months, full cycle" },
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
local suits = {
    { pt = "Paus", en = "Wands", symbol = "♣" },
    { pt = "Copas", en = "Cups", symbol = "♥" },
    { pt = "Espadas", en = "Swords", symbol = "♠" },
    { pt = "Ouros", en = "Pentacles", symbol = "♦" },
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

local MINOR_ARCANA = {
    -- ═══════════════════════  NAIPE DE PAUS (Wands) ═══════════════════════
    {
        id = 22, suit = suits[1], rank = ranks[1],
        name = { pt = "Ás de Paus", en = "Ace of Wands" },
        keywords = { pt = "Inspiração, criatividade, novo começo, energia", en = "Inspiration, creativity, new beginning, energy" },
        timing = { pt = "Rápido (dias)", en = "Fast (days)" },
        meaning = {
            pt = "Inspiração criativa. Um novo começo cheio de energia. Aproveite o impulso inicial para iniciar projetos.",
            en = "Creative inspiration. A new beginning full of energy. Seize the initial impulse to start projects."
        },
        reversed_meaning = {
            pt = "Falsa partida. Adiamento. Falta de motivação. Reacenda sua paixão antes de prosseguir.",
            en = "False start. Procrastination. Lack of motivation. Rekindle your passion before moving on."
        }
    },
    {
        id = 23, suit = suits[1], rank = ranks[2],
        name = { pt = "Dois de Paus", en = "Two of Wands" },
        keywords = { pt = "Planejamento, visão, decisão, expansão", en = "Planning, vision, decision, expansion" },
        timing = { pt = "Semanas", en = "Weeks" },
        meaning = {
            pt = "Planejamento. Olhar para o futuro. Você tem o mundo em suas mãos, mas precisa decidir o caminho.",
            en = "Planning. Looking ahead. You have the world in your hands, but you must choose the path."
        },
        reversed_meaning = {
            pt = "Medo do desconhecido. Falta de planejamento. Deixar as rédeas soltas. Defina seus objetivos.",
            en = "Fear of the unknown. Lack of planning. Letting go of the reins. Define your goals."
        }
    },
    {
        id = 24, suit = suits[1], rank = ranks[3],
        name = { pt = "Três de Paus", en = "Three of Wands" },
        keywords = { pt = "Expansão, progresso, antecipação, comércio", en = "Expansion, progress, anticipation, trade" },
        timing = { pt = "Em breve", en = "Soon" },
        meaning = {
            pt = "Expansão. Progresso. Seus planos estão navegando. Aguarde o retorno das sementes plantadas.",
            en = "Expansion. Progress. Your plans are sailing. Await the return of the seeds you planted."
        },
        reversed_meaning = {
            pt = "Obstáculos inesperados. Atraso. Frustração com resultados. Reavalie a estratégia.",
            en = "Unexpected obstacles. Delay. Frustration with results. Reassess your strategy."
        }
    },
    {
        id = 25, suit = suits[1], rank = ranks[4],
        name = { pt = "Quatro de Paus", en = "Four of Wands" },
        keywords = { pt = "Celebração, lar, harmonia, estabilidade", en = "Celebration, home, harmony, stability" },
        timing = { pt = "4 semanas", en = "4 weeks" },
        meaning = {
            pt = "Celebração. Harmonia em casa. Conquistas compartilhadas. Um merecido descanso após o esforço.",
            en = "Celebration. Harmony at home. Shared achievements. A well-deserved rest after effort."
        },
        reversed_meaning = {
            pt = "Falta de união. Instabilidade doméstica. Comemoração adiada. Resgate a alegria simples.",
            en = "Lack of unity. Domestic instability. Postponed celebration. Recover simple joy."
        }
    },
    {
        id = 26, suit = suits[1], rank = ranks[5],
        name = { pt = "Cinco de Paus", en = "Five of Wands" },
        keywords = { pt = "Competição, conflito, debate, crescimento", en = "Competition, conflict, debate, growth" },
        timing = { pt = "5 semanas", en = "5 weeks" },
        meaning = {
            pt = "Competição saudável. Conflito criativo. Diferentes pontos de vista enriquecem a busca.",
            en = "Healthy competition. Creative conflict. Different viewpoints enrich the search."
        },
        reversed_meaning = {
            pt = "Brigas internas. Evitar confrontos. Desgaste de energia. Busque cooperação em vez de disputa.",
            en = "Internal quarrels. Avoiding confrontation. Energy drain. Seek cooperation instead of dispute."
        }
    },
    {
        id = 27, suit = suits[1], rank = ranks[6],
        name = { pt = "Seis de Paus", en = "Six of Wands" },
        keywords = { pt = "Vitória, reconhecimento, triunfo, autoconfiança", en = "Victory, recognition, triumph, confidence" },
        timing = { pt = "6 semanas", en = "6 weeks" },
        meaning = {
            pt = "Vitória. Reconhecimento público. Autoestima elevada. Colha os louros com humildade.",
            en = "Victory. Public recognition. High self-esteem. Reap the laurels with humility."
        },
        reversed_meaning = {
            pt = "Ego inflado. Reconhecimento passageiro. Inveja. A verdadeira vitória é interna.",
            en = "Inflated ego. Short-lived recognition. Envy. True victory is internal."
        }
    },
    {
        id = 28, suit = suits[1], rank = ranks[7],
        name = { pt = "Sete de Paus", en = "Seven of Wands" },
        keywords = { pt = "Defesa, perseverança, coragem, resistência", en = "Defense, perseverance, courage, resistance" },
        timing = { pt = "7 semanas", en = "7 weeks" },
        meaning = {
            pt = "Defesa de posições. Perseverança. Mantenha-se firme apesar da oposição. Você tem vantagem.",
            en = "Defense of positions. Perseverance. Stand firm despite opposition. You have the upper hand."
        },
        reversed_meaning = {
            pt = "Exaustão. Sentir-se acuado. Desistência. Reforce seus limites com sabedoria.",
            en = "Exhaustion. Feeling cornered. Giving up. Reinforce your boundaries wisely."
        }
    },
    {
        id = 29, suit = suits[1], rank = ranks[8],
        name = { pt = "Oito de Paus", en = "Eight of Wands" },
        keywords = { pt = "Velocidade, ação, progresso, comunicação", en = "Speed, action, progress, communication" },
        timing = { pt = "Muito rápido", en = "Very fast" },
        meaning = {
            pt = "Movimento rápido. Notícias chegando. Ação acelerada. Aproveite o vento a favor.",
            en = "Swift movement. News arriving. Accelerated action. Take advantage of the tailwind."
        },
        reversed_meaning = {
            pt = "Atraso. Falta de direção. Energia dispersa. Espere o momento certo para agir.",
            en = "Delay. Lack of direction. Scattered energy. Wait for the right moment to act."
        }
    },
    {
        id = 30, suit = suits[1], rank = ranks[9],
        name = { pt = "Nove de Paus", en = "Nine of Wands" },
        keywords = { pt = "Resiliência, persistência, última defesa, cansaço", en = "Resilience, persistence, last stand, fatigue" },
        timing = { pt = "9 semanas", en = "9 weeks" },
        meaning = {
            pt = "Resiliência. Última batalha. Você está quase lá, mesmo que cansado. Mantenha a guarda.",
            en = "Resilience. Last battle. You are almost there, even if tired. Keep your guard up."
        },
        reversed_meaning = {
            pt = "Teimosia. Recusar ajuda. Esgotamento. Solte a defesa e permita-se descansar.",
            en = "Stubbornness. Refusing help. Exhaustion. Let down your defense and allow yourself to rest."
        }
    },
    {
        id = 31, suit = suits[1], rank = ranks[10],
        name = { pt = "Dez de Paus", en = "Ten of Wands" },
        keywords = { pt = "Sobrecarga, responsabilidade, fardo, esforço", en = "Overload, responsibility, burden, effort" },
        timing = { pt = "10 semanas, fim do ciclo", en = "10 weeks, end of cycle" },
        meaning = {
            pt = "Sobrecarga. Responsabilidades pesadas. O fardo é grande, mas o fim está próximo. Delegue tarefas.",
            en = "Overload. Heavy responsibilities. The burden is great, but the end is near. Delegate tasks."
        },
        reversed_meaning = {
            pt = "Incapacidade de delegar. Esgotamento. Recusar ajuda. Solte o que não lhe pertence.",
            en = "Inability to delegate. Burnout. Refusing help. Let go of what doesn't belong to you."
        }
    },
    {
        id = 32, suit = suits[1], rank = ranks[11],
        name = { pt = "Pajem de Paus", en = "Page of Wands" },
        keywords = { pt = "Entusiasmo, exploração, descoberta, nova ideia", en = "Enthusiasm, exploration, discovery, new idea" },
        timing = { pt = "Jovem, rápido", en = "Youthful, fast" },
        meaning = {
            pt = "Entusiasmo. Novas ideias. Um jovem mensageiro traz inspiração. Explore sua curiosidade sem medo.",
            en = "Enthusiasm. New ideas. A young messenger brings inspiration. Explore your curiosity without fear."
        },
        reversed_meaning = {
            pt = "Falta de planos. Impulsividade. Ideias sem execução. Defina metas antes de agir.",
            en = "Lack of plans. Impulsiveness. Ideas without execution. Set goals before acting."
        }
    },
    {
        id = 33, suit = suits[1], rank = ranks[12],
        name = { pt = "Cavaleiro de Paus", en = "Knight of Wands" },
        keywords = { pt = "Ação, paixão, impulso, aventura", en = "Action, passion, impulse, adventure" },
        timing = { pt = "Imediato, intenso", en = "Immediate, intense" },
        meaning = {
            pt = "Ação apaixonada. Coragem para arriscar. Vá em frente com ousadia, mas sem esquecer o destino.",
            en = "Passionate action. Courage to take risks. Go ahead boldly, but don't forget the destination."
        },
        reversed_meaning = {
            pt = "Impaciência. Correria sem direção. Conflito. Diminua o ritmo e escolha o caminho certo.",
            en = "Impatience. Rushing without direction. Conflict. Slow down and choose the right path."
        }
    },
    {
        id = 34, suit = suits[1], rank = ranks[13],
        name = { pt = "Rainha de Paus", en = "Queen of Wands" },
        keywords = { pt = "Carisma, liderança, calor, confiança", en = "Charisma, leadership, warmth, confidence" },
        timing = { pt = "Verão, maduro", en = "Summer, mature" },
        meaning = {
            pt = "Calor, determinação e magnetismo. Liderança inspiradora. Use seu carisma para atrair o que deseja.",
            en = "Warmth, determination and magnetism. Inspiring leadership. Use your charisma to attract what you want."
        },
        reversed_meaning = {
            pt = "Ciúme. Insegurança. Temperamento explosivo. A chama interior pode queimar quem está perto.",
            en = "Jealousy. Insecurity. Explosive temper. The inner flame can burn those nearby."
        }
    },
    {
        id = 35, suit = suits[1], rank = ranks[14],
        name = { pt = "Rei de Paus", en = "King of Wands" },
        keywords = { pt = "Visão, empreendedorismo, autoridade, honra", en = "Vision, entrepreneurship, authority, honor" },
        timing = { pt = "Longo prazo, liderança", en = "Long term, leadership" },
        meaning = {
            pt = "Visão empreendedora. Liderança forte. Assuma o comando com integridade e inspire os outros.",
            en = "Entrepreneurial vision. Strong leadership. Take command with integrity and inspire others."
        },
        reversed_meaning = {
            pt = "Autoritarismo. Promessas vazias. Falta de visão. Liderar pelo medo não constrói nada duradouro.",
            en = "Authoritarianism. Empty promises. Lack of vision. Leading by fear builds nothing lasting."
        }
    },

    -- ═══════════════════════  NAIPE DE COPAS (Cups) ═══════════════════════
    {
        id = 36, suit = suits[2], rank = ranks[1],
        name = { pt = "Ás de Copas", en = "Ace of Cups" },
        keywords = { pt = "Amor, emoção, intuição, novo sentimento", en = "Love, emotion, intuition, new feeling" },
        timing = { pt = "Lunar, emocional", en = "Lunar, emotional" },
        meaning = {
            pt = "Amor transbordante. Novo ciclo emocional. Abra-se para sentimentos profundos e conexões verdadeiras.",
            en = "Overflowing love. New emotional cycle. Open yourself to deep feelings and true connections."
        },
        reversed_meaning = {
            pt = "Amor reprimido. Bloqueio emocional. Vazio interior. Permita-se sentir para poder curar.",
            en = "Repressed love. Emotional block. Inner emptiness. Allow yourself to feel in order to heal."
        }
    },
    {
        id = 37, suit = suits[2], rank = ranks[2],
        name = { pt = "Dois de Copas", en = "Two of Cups" },
        keywords = { pt = "União, parceria, compromisso, atração", en = "Union, partnership, commitment, attraction" },
        timing = { pt = "Encontro breve", en = "Meeting soon" },
        meaning = {
            pt = "União. Parceria amorosa. Encontro de almas. Respeito mútuo e compromisso fortalecem o vínculo.",
            en = "Union. Loving partnership. Soul meeting. Mutual respect and commitment strengthen the bond."
        },
        reversed_meaning = {
            pt = "Desconexão. Brigas. Desequilíbrio afetivo. Uma conversa sincera pode restaurar a harmonia.",
            en = "Disconnection. Quarrels. Emotional imbalance. A sincere conversation can restore harmony."
        }
    },
    {
        id = 38, suit = suits[2], rank = ranks[3],
        name = { pt = "Três de Copas", en = "Three of Cups" },
        keywords = { pt = "Amizade, celebração, comunidade, alegria", en = "Friendship, celebration, community, joy" },
        timing = { pt = "Evento social", en = "Social event" },
        meaning = {
            pt = "Amizade. Celebração. Alegria compartilhada. Reúna-se com quem você ama e celebre a vida.",
            en = "Friendship. Celebration. Shared joy. Gather with those you love and celebrate life."
        },
        reversed_meaning = {
            pt = "Fofoca. Isolamento. Excesso de festas. Cuidado com amizades superficiais e mágoas escondidas.",
            en = "Gossip. Isolation. Excess partying. Beware of superficial friendships and hidden resentments."
        }
    },
    {
        id = 39, suit = suits[2], rank = ranks[4],
        name = { pt = "Quatro de Copas", en = "Four of Cups" },
        keywords = { pt = "Contemplação, apatia, tédio, introspecção", en = "Contemplation, apathy, boredom, introspection" },
        timing = { pt = "Estagnado", en = "Stagnant" },
        meaning = {
            pt = "Contemplação. Apatia. Novo convite ignorado. Olhe além do tédio para perceber as oportunidades.",
            en = "Contemplation. Apathy. New invitation ignored. Look beyond boredom to notice opportunities."
        },
        reversed_meaning = {
            pt = "Despertar. Aceitação. Novas perspectivas. Saia da zona de conforto e agarre a chance oferecida.",
            en = "Awakening. Acceptance. New perspectives. Leave your comfort zone and seize the chance offered."
        }
    },
    {
        id = 40, suit = suits[2], rank = ranks[5],
        name = { pt = "Cinco de Copas", en = "Five of Cups" },
        keywords = { pt = "Luto, perda, arrependimento, foco no negativo", en = "Grief, loss, regret, focus on negative" },
        timing = { pt = "Passado recente", en = "Recent past" },
        meaning = {
            pt = "Luto. Perda. Foco no que se foi. Ainda restam duas taças de pé – olhe para o que permanece.",
            en = "Grief. Loss. Focus on what is gone. Two cups still stand – look at what remains."
        },
        reversed_meaning = {
            pt = "Superação. Recuperação. Aprendizado com a dor. Aceite o passado e siga em frente.",
            en = "Overcoming. Recovery. Learning from pain. Accept the past and move forward."
        }
    },
    {
        id = 41, suit = suits[2], rank = ranks[6],
        name = { pt = "Seis de Copas", en = "Six of Cups" },
        keywords = { pt = "Nostalgia, memória, infância, presente", en = "Nostalgia, memory, childhood, gift" },
        timing = { pt = "Revisitar o passado", en = "Revisiting the past" },
        meaning = {
            pt = "Nostalgia. Memórias afetivas. Reencontro com o passado. Valorize suas raízes com carinho.",
            en = "Nostalgia. Fond memories. Reunion with the past. Cherish your roots with affection."
        },
        reversed_meaning = {
            pt = "Prender-se ao passado. Imaturidade. Incapacidade de seguir em frente. Viva o presente.",
            en = "Clinging to the past. Immaturity. Inability to move on. Live the present."
        }
    },
    {
        id = 42, suit = suits[2], rank = ranks[7],
        name = { pt = "Sete de Copas", en = "Seven of Cups" },
        keywords = { pt = "Ilusão, escolhas, fantasia, sonhos", en = "Illusion, choices, fantasy, dreams" },
        timing = { pt = "Confuso, indefinido", en = "Confusing, indefinite" },
        meaning = {
            pt = "Ilusões. Fantasias. Múltiplas opções. É preciso discernimento para escolher o copo verdadeiro.",
            en = "Illusions. Fantasies. Multiple options. Discernment is needed to choose the true cup."
        },
        reversed_meaning = {
            pt = "Clareza. Decisão firme. Fim das ilusões. Concentre-se no que realmente importa.",
            en = "Clarity. Firm decision. End of illusions. Focus on what really matters."
        }
    },
    {
        id = 43, suit = suits[2], rank = ranks[8],
        name = { pt = "Oito de Copas", en = "Eight of Cups" },
        keywords = { pt = "Afastamento, busca, desilusão, partida", en = "Withdrawal, search, disillusion, departure" },
        timing = { pt = "Transição emocional", en = "Emotional transition" },
        meaning = {
            pt = "Afastamento. Busca espiritual. Deixar para trás o que não preenche. Siga sua intuição.",
            en = "Withdrawal. Spiritual search. Leaving behind what doesn't fulfill. Follow your intuition."
        },
        reversed_meaning = {
            pt = "Medo de mudar. Ficar por comodismo. Insatisfação silenciosa. Coragem para partir.",
            en = "Fear of change. Staying out of convenience. Silent dissatisfaction. Courage to leave."
        }
    },
    {
        id = 44, suit = suits[2], rank = ranks[9],
        name = { pt = "Nove de Copas", en = "Nine of Cups" },
        keywords = { pt = "Desejo realizado, satisfação, contentamento, luxo", en = "Wish fulfilled, satisfaction, contentment, luxury" },
        timing = { pt = "Breve realização", en = "Soon fulfillment" },
        meaning = {
            pt = "Desejo realizado. Satisfação. O “copo dos sonhos” está cheio. Aproveite a abundância emocional.",
            en = "Wish fulfilled. Satisfaction. The “dream cup” is full. Enjoy emotional abundance."
        },
        reversed_meaning = {
            pt = "Insatisfação. Desejos não atendidos. Materialismo vazio. A felicidade verdadeira está no simples.",
            en = "Dissatisfaction. Unmet desires. Empty materialism. True happiness lies in simplicity."
        }
    },
    {
        id = 45, suit = suits[2], rank = ranks[10],
        name = { pt = "Dez de Copas", en = "Ten of Cups" },
        keywords = { pt = "Felicidade, família, harmonia, bênção", en = "Happiness, family, harmony, blessing" },
        timing = { pt = "Final feliz", en = "Happy ending" },
        meaning = {
            pt = "Felicidade plena. Amor familiar. Harmonia duradoura. O coração transborda de alegria compartilhada.",
            en = "Full happiness. Family love. Lasting harmony. The heart overflows with shared joy."
        },
        reversed_meaning = {
            pt = "Conflitos familiares. Laços quebrados. Idealização da felicidade. Trabalhe a comunicação afetiva.",
            en = "Family conflicts. Broken bonds. Idealization of happiness. Work on emotional communication."
        }
    },
    {
        id = 46, suit = suits[2], rank = ranks[11],
        name = { pt = "Pajem de Copas", en = "Page of Cups" },
        keywords = { pt = "Sensibilidade, criatividade, mensagem, intuição", en = "Sensitivity, creativity, message, intuition" },
        timing = { pt = "Surpresa emocional", en = "Emotional surprise" },
        meaning = {
            pt = "Sensibilidade criativa. Mensagem de amor. Abra-se para a intuição e surpresas do coração.",
            en = "Creative sensitivity. Message of love. Open up to intuition and heart surprises."
        },
        reversed_meaning = {
            pt = "Imaturidade emocional. Decepção amorosa. Ciúme infantil. Deixe a fantasia de lado e encare a realidade.",
            en = "Emotional immaturity. Love disappointment. Childish jealousy. Put fantasy aside and face reality."
        }
    },
    {
        id = 47, suit = suits[2], rank = ranks[12],
        name = { pt = "Cavaleiro de Copas", en = "Knight of Cups" },
        keywords = { pt = "Romantismo, charme, proposta, idealismo", en = "Romanticism, charm, proposal, idealism" },
        timing = { pt = "Convite breve", en = "Invitation soon" },
        meaning = {
            pt = "Romantismo. Proposta encantadora. Busca pelo belo e ideal. Siga seu coração com elegância.",
            en = "Romanticism. Charming proposal. Search for the beautiful and ideal. Follow your heart with elegance."
        },
        reversed_meaning = {
            pt = "Ilusão amorosa. Promessas vazias. Excesso de idealização. Mantenha os pés no chão.",
            en = "Love illusion. Empty promises. Excess of idealization. Keep your feet on the ground."
        }
    },
    {
        id = 48, suit = suits[2], rank = ranks[13],
        name = { pt = "Rainha de Copas", en = "Queen of Cups" },
        keywords = { pt = "Empatia, intuição, cuidado, compaixão", en = "Empathy, intuition, care, compassion" },
        timing = { pt = "Ciclo lunar, maduro", en = "Lunar cycle, mature" },
        meaning = {
            pt = "Intuição profunda. Empatia. Cuidadora emocional. Confie na sua capacidade de amar e curar.",
            en = "Deep intuition. Empathy. Emotional caregiver. Trust your ability to love and heal."
        },
        reversed_meaning = {
            pt = "Dependência emocional. Sensibilidade exacerbada. Manipulação afetiva. Estabeleça limites saudáveis.",
            en = "Emotional dependence. Exacerbated sensitivity. Emotional manipulation. Set healthy boundaries."
        }
    },
    {
        id = 49, suit = suits[2], rank = ranks[14],
        name = { pt = "Rei de Copas", en = "King of Cups" },
        keywords = { pt = "Domínio emocional, diplomacia, calma, sabedoria", en = "Emotional mastery, diplomacy, calm, wisdom" },
        timing = { pt = "Estabilidade emocional", en = "Emotional stability" },
        meaning = {
            pt = "Domínio emocional. Compaixão madura. Liderança com coração. Acalme as águas turbulentas com sabedoria.",
            en = "Emotional mastery. Mature compassion. Leadership with heart. Calm turbulent waters with wisdom."
        },
        reversed_meaning = {
            pt = "Frieza. Repressão emocional. Manipulação. O coração reprimido se torna um tirano silencioso.",
            en = "Coldness. Emotional repression. Manipulation. The repressed heart becomes a silent tyrant."
        }
    },

    -- ═══════════════════════  NAIPE DE ESPADAS (Swords) ═══════════════════════
    {
        id = 50, suit = suits[3], rank = ranks[1],
        name = { pt = "Ás de Espadas", en = "Ace of Swords" },
        keywords = { pt = "Clareza, verdade, justiça, mente afiada", en = "Clarity, truth, justice, sharp mind" },
        timing = { pt = "Decisão rápida", en = "Quick decision" },
        meaning = {
            pt = "Clareza mental. Verdade revelada. Ideia afiada. Use o poder da palavra com justiça.",
            en = "Mental clarity. Truth revealed. Sharp idea. Use the power of the word with justice."
        },
        reversed_meaning = {
            pt = "Confusão. Mentiras. Abuso verbal. A verdade distorcida fere. Busque a comunicação limpa.",
            en = "Confusion. Lies. Verbal abuse. Distorted truth hurts. Seek clean communication."
        }
    },
    {
        id = 51, suit = suits[3], rank = ranks[2],
        name = { pt = "Dois de Espadas", en = "Two of Swords" },
        keywords = { pt = "Impasse, escolha difícil, negação, equilíbrio", en = "Impasse, difficult choice, denial, balance" },
        timing = { pt = "Paralisado", en = "Stalled" },
        meaning = {
            pt = "Decisão difícil. Impasse. Equilíbrio precário. Remova a venda e olhe de frente para a situação.",
            en = "Difficult decision. Impasse. Precarious balance. Remove the blindfold and face the situation."
        },
        reversed_meaning = {
            pt = "Decisão adiada. Fuga da verdade. Conflito interno. Liberte-se da paralisia e escolha.",
            en = "Postponed decision. Escape from truth. Internal conflict. Free yourself from paralysis and choose."
        }
    },
    {
        id = 52, suit = suits[3], rank = ranks[3],
        name = { pt = "Três de Espadas", en = "Three of Swords" },
        keywords = { pt = "Dor, traição, tristeza, coração partido", en = "Pain, betrayal, sadness, heartbreak" },
        timing = { pt = "Dor recente", en = "Recent pain" },
        meaning = {
            pt = "Dor emocional. Traição. Coração partido. O sofrimento é real, mas é o primeiro passo para a cura.",
            en = "Emotional pain. Betrayal. Broken heart. Suffering is real, but it's the first step toward healing."
        },
        reversed_meaning = {
            pt = "Recuperação lenta. Guardar mágoas. Dificuldade em perdoar. Liberte-se do veneno do ressentimento.",
            en = "Slow recovery. Holding grudges. Difficulty forgiving. Free yourself from the poison of resentment."
        }
    },
    {
        id = 53, suit = suits[3], rank = ranks[4],
        name = { pt = "Quatro de Espadas", en = "Four of Swords" },
        keywords = { pt = "Descanso, recuperação, contemplação, pausa", en = "Rest, recovery, contemplation, pause" },
        timing = { pt = "Pausa necessária", en = "Necessary pause" },
        meaning = {
            pt = "Descanso mental. Retiro. Recuperação. Afaste-se do barulho e recarregue sua mente.",
            en = "Mental rest. Retreat. Recovery. Step away from the noise and recharge your mind."
        },
        reversed_meaning = {
            pt = "Insônia. Exaustão mental. Impossibilidade de relaxar. O excesso de pensamentos adoece.",
            en = "Insomnia. Mental exhaustion. Inability to relax. Excessive thinking makes you sick."
        }
    },
    {
        id = 54, suit = suits[3], rank = ranks[5],
        name = { pt = "Cinco de Espadas", en = "Five of Swords" },
        keywords = { pt = "Conflito, derrota, hostilidade, vitória vazia", en = "Conflict, defeat, hostility, hollow victory" },
        timing = { pt = "Conflito atual", en = "Current conflict" },
        meaning = {
            pt = "Conflito. Vitória vazia. Humilhação. Às vezes ganhar a batalha significa perder a guerra.",
            en = "Conflict. Empty victory. Humiliation. Sometimes winning the battle means losing the war."
        },
        reversed_meaning = {
            pt = "Reconciliação. Remorso. Deixar o orgulho de lado. Busque a paz em vez da razão.",
            en = "Reconciliation. Remorse. Putting pride aside. Seek peace instead of being right."
        }
    },
    {
        id = 55, suit = suits[3], rank = ranks[6],
        name = { pt = "Seis de Espadas", en = "Six of Swords" },
        keywords = { pt = "Transição, cura, viagem, seguir em frente", en = "Transition, healing, journey, moving on" },
        timing = { pt = "Transição gradual", en = "Gradual transition" },
        meaning = {
            pt = "Transição suave. Viagem de cura. Deixar águas turbulentas para trás. Rumo à calmaria.",
            en = "Smooth transition. Healing journey. Leaving turbulent waters behind. Toward calm waters."
        },
        reversed_meaning = {
            pt = "Resistência à mudança. Bagagem emocional. Ficar preso no problema. Solte o que não pode carregar.",
            en = "Resistance to change. Emotional baggage. Staying stuck in the problem. Release what you cannot carry."
        }
    },
    {
        id = 56, suit = suits[3], rank = ranks[7],
        name = { pt = "Sete de Espadas", en = "Seven of Swords" },
        keywords = { pt = "Estratégia, engano, fuga, esperteza", en = "Strategy, deception, escape, cunning" },
        timing = { pt = "Rápido, furtivo", en = "Fast, stealthy" },
        meaning = {
            pt = "Estratégia. Fuga sutil. Nem tudo precisa ser enfrentado de frente. Aja com inteligência.",
            en = "Strategy. Subtle escape. Not everything needs to be faced head-on. Act with intelligence."
        },
        reversed_meaning = {
            pt = "Engano. Roubo. Falta de ética. A mentira tem pernas curtas. Aja com honestidade.",
            en = "Deception. Theft. Lack of ethics. Lies have short legs. Act with honesty."
        }
    },
    {
        id = 57, suit = suits[3], rank = ranks[8],
        name = { pt = "Oito de Espadas", en = "Eight of Swords" },
        keywords = { pt = "Aprisionamento, autossabotagem, limitação, medo", en = "Imprisonment, self-sabotage, limitation, fear" },
        timing = { pt = "Prisão mental, temporário", en = "Mental prison, temporary" },
        meaning = {
            pt = "Sentir-se preso. Autossabotagem. Limitações imaginárias. A prisão é mental – a chave está em você.",
            en = "Feeling trapped. Self-sabotage. Imaginary limitations. The prison is mental – the key is within you."
        },
        reversed_meaning = {
            pt = "Libertação. Novo olhar. Superação de crenças limitantes. Rompa as amarras e veja a luz.",
            en = "Liberation. New perspective. Overcoming limiting beliefs. Break the bonds and see the light."
        }
    },
    {
        id = 58, suit = suits[3], rank = ranks[9],
        name = { pt = "Nove de Espadas", en = "Nine of Swords" },
        keywords = { pt = "Ansiedade, pesadelo, preocupação, angústia", en = "Anxiety, nightmare, worry, anguish" },
        timing = { pt = "Noturno, insônia", en = "Nocturnal, insomnia" },
        meaning = {
            pt = "Ansiedade. Pesadelos. Preocupações noturnas. A mente é seu próprio algoz. Busque acalmar os pensamentos.",
            en = "Anxiety. Nightmares. Nocturnal worries. The mind is its own tormentor. Seek to calm your thoughts."
        },
        reversed_meaning = {
            pt = "Recuperação da angústia. Aprendizado com a dor. O pior já passou. Respire fundo.",
            en = "Recovery from anguish. Learning from pain. The worst is over. Take a deep breath."
        }
    },
    {
        id = 59, suit = suits[3], rank = ranks[10],
        name = { pt = "Dez de Espadas", en = "Ten of Swords" },
        keywords = { pt = "Fim doloroso, traição, crise, renascimento", en = "Painful ending, betrayal, crisis, rebirth" },
        timing = { pt = "Fundo do poço, novo amanhecer", en = "Rock bottom, new dawn" },
        meaning = {
            pt = "Fim doloroso. Traição final. Ponto mais baixo. Deste abismo só se pode subir – a alvorada chega.",
            en = "Painful ending. Final betrayal. Rock bottom. From this abyss one can only rise – dawn arrives."
        },
        reversed_meaning = {
            pt = "Recuperação. Resistência. Evitar o colapso final. O sofrimento pode ser transformado em força.",
            en = "Recovery. Resistance. Avoiding the final collapse. Suffering can be transformed into strength."
        }
    },
    {
        id = 60, suit = suits[3], rank = ranks[11],
        name = { pt = "Pajem de Espadas", en = "Page of Swords" },
        keywords = { pt = "Curiosidade, comunicação, ideias, vigilância", en = "Curiosity, communication, ideas, vigilance" },
        timing = { pt = "Notícias breves", en = "News shortly" },
        meaning = {
            pt = "Curiosidade intelectual. Ideias novas. Comunicação ágil. Fale sua verdade, mas com tato.",
            en = "Intellectual curiosity. New ideas. Agile communication. Speak your truth, but with tact."
        },
        reversed_meaning = {
            pt = "Fofoca. Pensamento superficial. Críticas sem fundamento. Use sua mente para construir, não destruir.",
            en = "Gossip. Superficial thinking. Baseless criticism. Use your mind to build, not destroy."
        }
    },
    {
        id = 61, suit = suits[3], rank = ranks[12],
        name = { pt = "Cavaleiro de Espadas", en = "Knight of Swords" },
        keywords = { pt = "Ação rápida, impulso, determinação, conflito", en = "Swift action, impulse, determination, conflict" },
        timing = { pt = "Agora, urgente", en = "Now, urgent" },
        meaning = {
            pt = "Ação impetuosa. Determinação intelectual. Avance com ímpeto, mas não atropele os outros.",
            en = "Impetuous action. Intellectual determination. Advance with momentum, but don't trample others."
        },
        reversed_meaning = {
            pt = "Impulsividade cega. Confronto desnecessário. Agressividade. Pense antes de brandir a espada.",
            en = "Blind impulsiveness. Unnecessary confrontation. Aggressiveness. Think before brandishing the sword."
        }
    },
    {
        id = 62, suit = suits[3], rank = ranks[13],
        name = { pt = "Rainha de Espadas", en = "Queen of Swords" },
        keywords = { pt = "Racionalidade, independência, discernimento, verdade", en = "Rationality, independence, discernment, truth" },
        timing = { pt = "Decisão madura", en = "Mature decision" },
        meaning = {
            pt = "Racionalidade clara. Independência. Justiça ponderada. Tome decisões com a mente, mas sem perder a empatia.",
            en = "Clear rationality. Independence. Weighted justice. Make decisions with the mind, but without losing empathy."
        },
        reversed_meaning = {
            pt = "Frieza emocional. Amargura. Julgamento severo. A razão sem coração se torna crueldade.",
            en = "Emotional coldness. Bitterness. Harsh judgment. Reason without heart becomes cruelty."
        }
    },
    {
        id = 63, suit = suits[3], rank = ranks[14],
        name = { pt = "Rei de Espadas", en = "King of Swords" },
        keywords = { pt = "Autoridade intelectual, ética, clareza, justiça", en = "Intellectual authority, ethics, clarity, justice" },
        timing = { pt = "Autoridade legal, longo prazo", en = "Legal authority, long term" },
        meaning = {
            pt = "Autoridade intelectual. Ética. Liderança justa e lúcida. A verdade é a sua espada mais afiada.",
            en = "Intellectual authority. Ethics. Just and lucid leadership. Truth is your sharpest sword."
        },
        reversed_meaning = {
            pt = "Tirania mental. Manipulação da verdade. Abuso de poder. O intelecto sem moral oprime.",
            en = "Mental tyranny. Manipulation of truth. Abuse of power. Intellect without morals oppresses."
        }
    },

    -- ═══════════════════════  NAIPE DE OUROS (Pentacles) ═══════════════════════
    {
        id = 64, suit = suits[4], rank = ranks[1],
        name = { pt = "Ás de Ouros", en = "Ace of Pentacles" },
        keywords = { pt = "Oportunidade, prosperidade, novo recurso, segurança", en = "Opportunity, prosperity, new resource, security" },
        timing = { pt = "Início material", en = "Material beginning" },
        meaning = {
            pt = "Nova oportunidade material. Prosperidade ao alcance. Mãos à obra para colher frutos sólidos.",
            en = "New material opportunity. Prosperity at hand. Get to work to reap solid fruits."
        },
        reversed_meaning = {
            pt = "Oportunidade perdida. Ganância. Atraso financeiro. A base precisa ser firmada antes de crescer.",
            en = "Missed opportunity. Greed. Financial delay. The foundation needs to be set before growing."
        }
    },
    {
        id = 65, suit = suits[4], rank = ranks[2],
        name = { pt = "Dois de Ouros", en = "Two of Pentacles" },
        keywords = { pt = "Equilíbrio, adaptação, malabarismo, prioridades", en = "Balance, adaptation, juggling, priorities" },
        timing = { pt = "Flutuante", en = "Fluctuating" },
        meaning = {
            pt = "Equilíbrio financeiro. Malabarismo. Adapte-se às mudanças sem perder o controle das contas.",
            en = "Financial balance. Juggling. Adapt to changes without losing control of your accounts."
        },
        reversed_meaning = {
            pt = "Desorganização. Sobrecarga de dívidas. Incapacidade de priorizar. Reorganize suas finanças.",
            en = "Disorganization. Debt overload. Inability to prioritize. Reorganize your finances."
        }
    },
    {
        id = 66, suit = suits[4], rank = ranks[3],
        name = { pt = "Três de Ouros", en = "Three of Pentacles" },
        keywords = { pt = "Trabalho em equipe, colaboração, maestria, habilidade", en = "Teamwork, collaboration, mastery, skill" },
        timing = { pt = "Projeto em andamento", en = "Project in progress" },
        meaning = {
            pt = "Trabalho em equipe. Maestria. Colaboração produtiva. Juntos, o resultado é maior que a soma.",
            en = "Teamwork. Mastery. Productive collaboration. Together, the result is greater than the sum."
        },
        reversed_meaning = {
            pt = "Falta de colaboração. Desleixo. Trabalho mal feito. Resgate o respeito pela excelência.",
            en = "Lack of collaboration. Carelessness. Poor workmanship. Restore respect for excellence."
        }
    },
    {
        id = 67, suit = suits[4], rank = ranks[4],
        name = { pt = "Quatro de Ouros", en = "Four of Pentacles" },
        keywords = { pt = "Segurança, apego, economia, controle", en = "Security, attachment, saving, control" },
        timing = { pt = "Estável, estagnado", en = "Stable, stagnant" },
        meaning = {
            pt = "Segurança material. Apego aos bens. Economia sadia, mas sem se fechar para o novo.",
            en = "Material security. Attachment to possessions. Healthy saving, but without closing off to the new."
        },
        reversed_meaning = {
            pt = "Avareza. Medo de perder. Bloqueio da abundância. Solte um pouco o controle para receber.",
            en = "Miserliness. Fear of loss. Blocking abundance. Let go a little control to receive."
        }
    },
    {
        id = 68, suit = suits[4], rank = ranks[5],
        name = { pt = "Cinco de Ouros", en = "Five of Pentacles" },
        keywords = { pt = "Dificuldade, escassez, exclusão, auxílio", en = "Hardship, scarcity, exclusion, aid" },
        timing = { pt = "Período difícil", en = "Difficult period" },
        meaning = {
            pt = "Dificuldade material. Sensação de exclusão. A ajuda está mais perto do que imagina. Peça auxílio.",
            en = "Material hardship. Feeling of exclusion. Help is closer than you think. Ask for assistance."
        },
        reversed_meaning = {
            pt = "Recuperação financeira. Fim da escassez. Reinclusão. A luz brilha no fim do túnel.",
            en = "Financial recovery. End of scarcity. Re-inclusion. Light shines at the end of the tunnel."
        }
    },
    {
        id = 69, suit = suits[4], rank = ranks[6],
        name = { pt = "Seis de Ouros", en = "Six of Pentacles" },
        keywords = { pt = "Generosidade, partilha, caridade, equilíbrio", en = "Generosity, sharing, charity, balance" },
        timing = { pt = "Dar e receber", en = "Give and receive" },
        meaning = {
            pt = "Generosidade. Partilha. Dar e receber em equilíbrio. A prosperidade circula quando a mão se abre.",
            en = "Generosity. Sharing. Giving and receiving in balance. Prosperity circulates when the hand opens."
        },
        reversed_meaning = {
            pt = "Caridade interesseira. Dívidas. Desequilíbrio na doação. Cuidado com quem só pede e nunca retribui.",
            en = "Self-interested charity. Debts. Imbalance in giving. Beware of those who only ask and never give back."
        }
    },
    {
        id = 70, suit = suits[4], rank = ranks[7],
        name = { pt = "Sete de Ouros", en = "Seven of Pentacles" },
        keywords = { pt = "Paciência, colheita, avaliação, investimento", en = "Patience, harvest, evaluation, investment" },
        timing = { pt = "Longo prazo", en = "Long term" },
        meaning = {
            pt = "Paciência. Colheita em andamento. Avalie se seus esforços estão gerando os frutos esperados.",
            en = "Patience. Harvest in progress. Evaluate if your efforts are yielding the expected fruits."
        },
        reversed_meaning = {
            pt = "Impaciência. Trabalho infrutífero. Frustração com resultados. Recalcule a rota e continue.",
            en = "Impatience. Fruitless work. Frustration with results. Recalculate the route and continue."
        }
    },
    {
        id = 71, suit = suits[4], rank = ranks[8],
        name = { pt = "Oito de Ouros", en = "Eight of Pentacles" },
        keywords = { pt = "Dedicação, aprendizado, aperfeiçoamento, trabalho", en = "Dedication, learning, improvement, work" },
        timing = { pt = "Diário, constante", en = "Daily, constant" },
        meaning = {
            pt = "Aprendizado dedicado. Artesanato. Aperfeiçoamento constante. O domínio exige prática diária.",
            en = "Dedicated learning. Craftsmanship. Constant improvement. Mastery requires daily practice."
        },
        reversed_meaning = {
            pt = "Perfeccionismo. Trabalho monótono. Falta de motivação. Reacenda o prazer no fazer.",
            en = "Perfectionism. Monotonous work. Lack of motivation. Rekindle the pleasure in doing."
        }
    },
    {
        id = 72, suit = suits[4], rank = ranks[9],
        name = { pt = "Nove de Ouros", en = "Nine of Pentacles" },
        keywords = { pt = "Autossuficiência, luxo, conquista, independência", en = "Self-sufficiency, luxury, achievement, independence" },
        timing = { pt = "Colheita pessoal", en = "Personal harvest" },
        meaning = {
            pt = "Autossuficiência. Luxo pessoal. Conquista material com independência. Desfrute do que construiu.",
            en = "Self-sufficiency. Personal luxury. Material achievement with independence. Enjoy what you have built."
        },
        reversed_meaning = {
            pt = "Dependência financeira. Ostentação vazia. Insegurança material. O valor real está em quem você é.",
            en = "Financial dependence. Empty ostentation. Material insecurity. Real value lies in who you are."
        }
    },
    {
        id = 73, suit = suits[4], rank = ranks[10],
        name = { pt = "Dez de Ouros", en = "Ten of Pentacles" },
        keywords = { pt = "Riqueza, legado, família, estabilidade", en = "Wealth, legacy, family, stability" },
        timing = { pt = "Permanente, longo prazo", en = "Permanent, long term" },
        meaning = {
            pt = "Riqueza duradoura. Legado familiar. Segurança material e afetiva. As raízes fortes nutrem o futuro.",
            en = "Lasting wealth. Family legacy. Material and emotional security. Strong roots nourish the future."
        },
        reversed_meaning = {
            pt = "Perda de herança. Conflitos familiares por dinheiro. Instabilidade financeira. Reconstrua os alicerces.",
            en = "Loss of inheritance. Family conflicts over money. Financial instability. Rebuild the foundations."
        }
    },
    {
        id = 74, suit = suits[4], rank = ranks[11],
        name = { pt = "Pajem de Ouros", en = "Page of Pentacles" },
        keywords = { pt = "Estudo, ambição, foco, novo projeto", en = "Study, ambition, focus, new project" },
        timing = { pt = "Início lento", en = "Slow start" },
        meaning = {
            pt = "Estudo aplicado. Nova habilidade. Ambição construtiva. Comece pequeno, sonhe grande.",
            en = "Applied study. New skill. Constructive ambition. Start small, dream big."
        },
        reversed_meaning = {
            pt = "Falta de foco. Progresso lento. Desistência precoce. Persista nos estudos e no trabalho.",
            en = "Lack of focus. Slow progress. Premature abandonment. Persist in studies and work."
        }
    },
    {
        id = 75, suit = suits[4], rank = ranks[12],
        name = { pt = "Cavaleiro de Ouros", en = "Knight of Pentacles" },
        keywords = { pt = "Trabalho árduo, rotina, paciência, confiabilidade", en = "Hard work, routine, patience, reliability" },
        timing = { pt = "Passo a passo", en = "Step by step" },
        meaning = {
            pt = "Trabalho árduo. Rotina confiável. Paciência para construir. Passos firmes levam longe.",
            en = "Hard work. Reliable routine. Patience to build. Steady steps take you far."
        },
        reversed_meaning = {
            pt = "Estagnação. Tédio. Falta de ambição. Mexa-se antes que a inércia se torne permanente.",
            en = "Stagnation. Boredom. Lack of ambition. Move before inertia becomes permanent."
        }
    },
    {
        id = 76, suit = suits[4], rank = ranks[13],
        name = { pt = "Rainha de Ouros", en = "Queen of Pentacles" },
        keywords = { pt = "Prosperidade, cuidado prático, lar, segurança", en = "Prosperity, practical care, home, security" },
        timing = { pt = "Ciclo doméstico", en = "Domestic cycle" },
        meaning = {
            pt = "Prosperidade caseira. Cuidado prático. Mãe generosa. Sua segurança material sustenta quem você ama.",
            en = "Homely prosperity. Practical care. Generous mother. Your material security sustains those you love."
        },
        reversed_meaning = {
            pt = "Descuido com o lar. Materialismo egoísta. Desequilíbrio trabalho-casa. Cuide primeiro do seu ninho.",
            en = "Neglect of home. Selfish materialism. Work-home imbalance. Take care of your nest first."
        }
    },
    {
        id = 77, suit = suits[4], rank = ranks[14],
        name = { pt = "Rei de Ouros", en = "King of Pentacles" },
        keywords = { pt = "Sucesso, abundância, estabilidade, negócios", en = "Success, abundance, stability, business" },
        timing = { pt = "Maturidade financeira", en = "Financial maturity" },
        meaning = {
            pt = "Sucesso financeiro. Liderança próspera. Abundância com estabilidade. Seu tino para negócios é um dom.",
            en = "Financial success. Prosperous leadership. Abundance with stability. Your business acumen is a gift."
        },
        reversed_meaning = {
            pt = "Avareza. Materialismo extremo. Corrupção. A riqueza sem propósito é vazia e corrompe.",
            en = "Miserliness. Extreme materialism. Corruption. Wealth without purpose is empty and corrupts."
        }
    },
}

-- Montagem final do baralho completo
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
        keywords = { pt = "Notícias, mensagem, visitante, rapidez", en = "News, message, visitor, swiftness" },
        meaning = {
            pt = "Notícias chegando. Um visitante ou mensagem importante. Movimento rápido e boas novas no horizonte.",
            en = "News arriving. A visitor or important message. Swift movement and good tidings on the horizon."
        }
    },
    {
        id = 2, number = 2,
        name = { pt = "O Trevo", en = "The Clover" },
        symbol = "♣",
        keywords = { pt = "Sorte, oportunidade, leveza, momento", en = "Luck, opportunity, lightness, moment" },
        meaning = {
            pt = "Sorte passageira. Oportunidade efêmera. Alegria simples. Aproveite o momento presente com leveza.",
            en = "Passing luck. Fleeting opportunity. Simple joy. Enjoy the present moment with lightness."
        }
    },
    {
        id = 3, number = 3,
        name = { pt = "O Navio", en = "The Ship" },
        symbol = "⛵",
        keywords = { pt = "Viagem, mudança, aventura, movimento", en = "Travel, change, adventure, movement" },
        meaning = {
            pt = "Viagem. Mudança de cenário. Novos horizontes. Aventure-se, o mundo espera por você.",
            en = "Travel. Change of scenery. New horizons. Venture forth, the world awaits you."
        }
    },
    {
        id = 4, number = 4,
        name = { pt = "A Casa", en = "The House" },
        symbol = "⌂",
        keywords = { pt = "Lar, família, segurança, raízes", en = "Home, family, security, roots" },
        meaning = {
            pt = "Lar. Segurança familiar. Raízes firmes. Cuide do seu espaço sagrado com amor e dedicação.",
            en = "Home. Family security. Firm roots. Care for your sacred space with love and dedication."
        }
    },
    {
        id = 5, number = 5,
        name = { pt = "A Árvore", en = "The Tree" },
        symbol = "♧",
        keywords = { pt = "Saúde, crescimento, natureza, vitalidade", en = "Health, growth, nature, vitality" },
        meaning = {
            pt = "Saúde. Crescimento pessoal. Conexão com a natureza. Suas raízes são profundas, seus frutos virão.",
            en = "Health. Personal growth. Connection with nature. Your roots are deep, your fruits will come."
        }
    },
    {
        id = 6, number = 6,
        name = { pt = "As Nuvens", en = "The Clouds" },
        symbol = "☁",
        keywords = { pt = "Confusão, incerteza, dúvida, névoa", en = "Confusion, uncertainty, doubt, fog" },
        meaning = {
            pt = "Confusão. Incerteza temporária. Dúvidas pairando. A clareza virá após a tempestade passar.",
            en = "Confusion. Temporary uncertainty. Lingering doubts. Clarity will come after the storm passes."
        }
    },
    {
        id = 7, number = 7,
        name = { pt = "A Cobra", en = "The Snake" },
        symbol = "≈",
        keywords = { pt = "Sedução, traição, manipulação, astúcia", en = "Seduction, betrayal, manipulation, cunning" },
        meaning = {
            pt = "Sedução. Traição ou manipulação. Cuidado com falsas promessas. A sabedoria está em ver além das aparências.",
            en = "Seduction. Betrayal or manipulation. Beware of false promises. Wisdom lies in seeing beyond appearances."
        }
    },
    {
        id = 8, number = 8,
        name = { pt = "O Caixão", en = "The Coffin" },
        symbol = "⚰",
        keywords = { pt = "Fim, transformação, perda, renascimento", en = "Ending, transformation, loss, rebirth" },
        meaning = {
            pt = "Fim de um ciclo. Transformação profunda. Deixe o passado descansar. O novo nasce do que se foi.",
            en = "End of a cycle. Deep transformation. Let the past rest. The new is born from what has gone."
        }
    },
    {
        id = 9, number = 9,
        name = { pt = "O Buquê", en = "The Bouquet" },
        symbol = "⚘",
        keywords = { pt = "Presente, elogio, beleza, gratidão", en = "Gift, compliment, beauty, gratitude" },
        meaning = {
            pt = "Presente. Elogio. Reconhecimento. A beleza da vida se revela nas pequenas gentilezas.",
            en = "Gift. Compliment. Recognition. The beauty of life reveals itself in small kindnesses."
        }
    },
    {
        id = 10, number = 10,
        name = { pt = "A Foice", en = "The Scythe" },
        symbol = "⚔",
        keywords = { pt = "Corte, decisão, ruptura, aviso", en = "Cut, decision, rupture, warning" },
        meaning = {
            pt = "Corte necessário. Decisão drástica. Ruptura iminente. Às vezes é preciso cortar para curar.",
            en = "Necessary cut. Drastic decision. Imminent rupture. Sometimes you must cut to heal."
        }
    },
    {
        id = 11, number = 11,
        name = { pt = "O Chicote", en = "The Whip" },
        symbol = "≈≈",
        keywords = { pt = "Conflito, debate, paixão, repetição", en = "Conflict, debate, passion, repetition" },
        meaning = {
            pt = "Conflito. Discussões acaloradas. Paixão intensa. Canalize a energia para ações produtivas.",
            en = "Conflict. Heated discussions. Intense passion. Channel energy into productive actions."
        }
    },
    {
        id = 12, number = 12,
        name = { pt = "Os Pássaros", en = "The Birds" },
        symbol = "♫",
        keywords = { pt = "Conversa, fofoca, comunicação, nervosismo", en = "Talk, gossip, communication, nervousness" },
        meaning = {
            pt = "Conversas importantes. Fofocas ou notícias. Comunicação em foco. Escolha bem suas palavras.",
            en = "Important conversations. Gossip or news. Communication in focus. Choose your words wisely."
        }
    },
    {
        id = 13, number = 13,
        name = { pt = "A Criança", en = "The Child" },
        symbol = "☺",
        keywords = { pt = "Inocência, recomeço, pureza, brincadeira", en = "Innocence, new start, purity, playfulness" },
        meaning = {
            pt = "Inocência. Novo começo. Pureza de intenção. Abrace sua criança interior com ternura.",
            en = "Innocence. New beginning. Purity of intention. Embrace your inner child with tenderness."
        }
    },
    {
        id = 14, number = 14,
        name = { pt = "A Raposa", en = "The Fox" },
        symbol = "≈≈",
        keywords = { pt = "Astúcia, esperteza, engano, adaptação", en = "Cunning, cleverness, deceit, adaptation" },
        meaning = {
            pt = "Astúcia. Esperteza. Cuidado com enganos. Use sua inteligência para o bem, não para manipular.",
            en = "Cunning. Cleverness. Beware of deception. Use your intelligence for good, not manipulation."
        }
    },
    {
        id = 15, number = 15,
        name = { pt = "O Urso", en = "The Bear" },
        symbol = "♚",
        keywords = { pt = "Força, proteção, poder, autoridade", en = "Strength, protection, power, authority" },
        meaning = {
            pt = "Força protetora. Poder financeiro. Autoridade natural. Liderança com generosidade traz prosperidade.",
            en = "Protective strength. Financial power. Natural authority. Leadership with generosity brings prosperity."
        }
    },
    {
        id = 16, number = 16,
        name = { pt = "A Estrela", en = "The Star" },
        symbol = "★",
        keywords = { pt = "Esperança, clareza, propósito, luz", en = "Hope, clarity, purpose, light" },
        meaning = {
            pt = "Esperança. Clareza de propósito. Siga sua luz interior. O universo conspira a seu favor.",
            en = "Hope. Clarity of purpose. Follow your inner light. The universe conspires in your favor."
        }
    },
    {
        id = 17, number = 17,
        name = { pt = "A Cegonha", en = "The Stork" },
        symbol = "♆",
        keywords = { pt = "Mudança positiva, renovação, transição, benção", en = "Positive change, renewal, transition, blessing" },
        meaning = {
            pt = "Mudança positiva. Renovação. Transição abençoada. Novas energias chegam para transformar sua vida.",
            en = "Positive change. Renewal. Blessed transition. New energies arrive to transform your life."
        }
    },
    {
        id = 18, number = 18,
        name = { pt = "O Cachorro", en = "The Dog" },
        symbol = "♉",
        keywords = { pt = "Amizade, lealdade, companheirismo, confiança", en = "Friendship, loyalty, companionship, trust" },
        meaning = {
            pt = "Amizade leal. Fidelidade. Companheirismo sincero. Valorize quem caminha ao seu lado.",
            en = "Loyal friendship. Fidelity. Sincere companionship. Value those who walk beside you."
        }
    },
    {
        id = 19, number = 19,
        name = { pt = "A Torre", en = "The Tower" },
        symbol = "♜",
        keywords = { pt = "Autoridade, estrutura, isolamento, instituição", en = "Authority, structure, isolation, institution" },
        meaning = {
            pt = "Autoridade institucional. Proteção. Estrutura sólida. Construa bases firmes para o futuro.",
            en = "Institutional authority. Protection. Solid structure. Build firm foundations for the future."
        }
    },
    {
        id = 20, number = 20,
        name = { pt = "O Jardim", en = "The Garden" },
        symbol = "❦",
        keywords = { pt = "Vida social, comunidade, encontro, público", en = "Social life, community, meeting, public" },
        meaning = {
            pt = "Vida social. Comunidade. Encontros públicos. Abra-se para novas conexões e ambientes.",
            en = "Social life. Community. Public encounters. Open yourself to new connections and environments."
        }
    },
    {
        id = 21, number = 21,
        name = { pt = "A Montanha", en = "The Mountain" },
        symbol = "▲",
        keywords = { pt = "Obstáculo, desafio, bloqueio, persistência", en = "Obstacle, challenge, blockage, persistence" },
        meaning = {
            pt = "Obstáculo. Desafio a superar. Bloqueio temporário. A vista do topo justifica a escalada.",
            en = "Obstacle. Challenge to overcome. Temporary blockage. The view from the top justifies the climb."
        }
    },
    {
        id = 22, number = 22,
        name = { pt = "O Caminho", en = "The Crossroads" },
        symbol = "⛗",
        keywords = { pt = "Escolha, decisão, direção, alternativa", en = "Choice, decision, direction, alternative" },
        meaning = {
            pt = "Escolha importante. Decisão crucial. Múltiplos caminhos. Siga sua intuição na encruzilhada.",
            en = "Important choice. Crucial decision. Multiple paths. Follow your intuition at the crossroads."
        }
    },
    {
        id = 23, number = 23,
        name = { pt = "Os Ratos", en = "The Mice" },
        symbol = "🐭",
        keywords = { pt = "Perda, desgaste, preocupação, corrosão", en = "Loss, wear, worry, corrosion" },
        meaning = {
            pt = "Perda gradual. Desgaste. Preocupações corroendo. Atenção aos detalhes que passam despercebidos.",
            en = "Gradual loss. Wear and tear. Corroding worries. Attention to details that go unnoticed."
        }
    },
    {
        id = 24, number = 24,
        name = { pt = "O Coração", en = "The Heart" },
        symbol = "♥",
        keywords = { pt = "Amor, paixão, afeto, romance", en = "Love, passion, affection, romance" },
        meaning = {
            pt = "Amor verdadeiro. Paixão. Afeto profundo. Abra seu coração sem medo de ser feliz.",
            en = "True love. Passion. Deep affection. Open your heart without fear of being happy."
        }
    },
    {
        id = 25, number = 25,
        name = { pt = "O Anel", en = "The Ring" },
        symbol = "◎",
        keywords = { pt = "Compromisso, aliança, ciclo, união", en = "Commitment, alliance, cycle, union" },
        meaning = {
            pt = "Compromisso. Aliança. Ciclo completado. Honre seus pactos e promessas com integridade.",
            en = "Commitment. Alliance. Completed cycle. Honor your pacts and promises with integrity."
        }
    },
    {
        id = 26, number = 26,
        name = { pt = "O Livro", en = "The Book" },
        symbol = "▣",
        keywords = { pt = "Segredo, conhecimento, estudo, mistério", en = "Secret, knowledge, study, mystery" },
        meaning = {
            pt = "Segredo. Conhecimento oculto. Mistério a ser revelado. A resposta está nas entrelinhas.",
            en = "Secret. Hidden knowledge. Mystery to be revealed. The answer lies between the lines."
        }
    },
    {
        id = 27, number = 27,
        name = { pt = "A Carta", en = "The Letter" },
        symbol = "✉",
        keywords = { pt = "Mensagem, documento, comunicação, notícia", en = "Message, document, communication, news" },
        meaning = {
            pt = "Mensagem escrita. Documento importante. Comunicação formal. Notícias que chegam pelo papel.",
            en = "Written message. Important document. Formal communication. News arriving on paper."
        }
    },
    {
        id = 28, number = 28,
        name = { pt = "O Homem", en = "The Gentleman" },
        symbol = "♂",
        keywords = { pt = "Homem, parceiro, ação, yang", en = "Man, partner, action, yang" },
        meaning = {
            pt = "Figura masculina influente. Parceiro ou consulente. Força yang. Ação e iniciativa.",
            en = "Influential male figure. Partner or seeker. Yang force. Action and initiative."
        }
    },
    {
        id = 29, number = 29,
        name = { pt = "A Mulher", en = "The Lady" },
        symbol = "♀",
        keywords = { pt = "Mulher, parceira, intuição, yin", en = "Woman, partner, intuition, yin" },
        meaning = {
            pt = "Figura feminina influente. Parceira ou consulente. Força yin. Intuição e acolhimento.",
            en = "Influential female figure. Partner or seeker. Yin force. Intuition and nurturing."
        }
    },
    {
        id = 30, number = 30,
        name = { pt = "Os Lírios", en = "The Lilies" },
        symbol = "⚜",
        keywords = { pt = "Paz, harmonia, sabedoria, virtude", en = "Peace, harmony, wisdom, virtue" },
        meaning = {
            pt = "Paz. Harmonia. Sabedoria madura. A virtude da paciência floresce em seu jardim.",
            en = "Peace. Harmony. Mature wisdom. The virtue of patience blooms in your garden."
        }
    },
    {
        id = 31, number = 31,
        name = { pt = "O Sol", en = "The Sun" },
        symbol = "☼",
        keywords = { pt = "Sucesso, vitória, energia, felicidade", en = "Success, victory, energy, happiness" },
        meaning = {
            pt = "Sucesso. Vitória. Energia vital plena. Tudo está iluminado, aproveite este momento.",
            en = "Success. Victory. Full vital energy. Everything is illuminated, enjoy this moment."
        }
    },
    {
        id = 32, number = 32,
        name = { pt = "A Lua", en = "The Moon" },
        symbol = "☽",
        keywords = { pt = "Reconhecimento, fama, criatividade, intuição", en = "Recognition, fame, creativity, intuition" },
        meaning = {
            pt = "Intuição. Reconhecimento. Fama e criatividade. Seus talentos são reconhecidos sob a luz lunar.",
            en = "Intuition. Recognition. Fame and creativity. Your talents are recognized under moonlight."
        }
    },
    {
        id = 33, number = 33,
        name = { pt = "A Chave", en = "The Key" },
        symbol = "⚷",
        keywords = { pt = "Solução, abertura, oportunidade, resposta", en = "Solution, opening, opportunity, answer" },
        meaning = {
            pt = "Solução. Abertura de portas. Oportunidade decisiva. A resposta que você busca está ao seu alcance.",
            en = "Solution. Opening doors. Decisive opportunity. The answer you seek is within reach."
        }
    },
    {
        id = 34, number = 34,
        name = { pt = "Os Peixes", en = "The Fish" },
        symbol = "♓",
        keywords = { pt = "Abundância, finanças, fluxo, prosperidade", en = "Abundance, finances, flow, prosperity" },
        meaning = {
            pt = "Abundância financeira. Prosperidade. Fluxo de recursos. A riqueza flui como água limpa.",
            en = "Financial abundance. Prosperity. Flow of resources. Wealth flows like clean water."
        }
    },
    {
        id = 35, number = 35,
        name = { pt = "A Âncora", en = "The Anchor" },
        symbol = "⚓",
        keywords = { pt = "Estabilidade, segurança, trabalho, firmeza", en = "Stability, security, work, steadfastness" },
        meaning = {
            pt = "Estabilidade. Segurança duradoura. Trabalho firme. Construa bases sólidas para o amanhã.",
            en = "Stability. Lasting security. Steady work. Build solid foundations for tomorrow."
        }
    },
    {
        id = 36, number = 36,
        name = { pt = "A Cruz", en = "The Cross" },
        symbol = "✚",
        keywords = { pt = "Destino, provação, fardo, transcendência", en = "Destiny, trial, burden, transcendence" },
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
    self.hidden_card = G_reader_settings:readSetting("tarot_hidden_card")
    if self.hidden_card == nil then
        self.hidden_card = true
    end
    
    self:ensureSavesDir()
    
    -- Carrega strings de localização do arquivo .po se disponível
    l10n_strings = loadL10n(self.language or "pt")
end

function TarotPlugin:getTranslation(key)
    local lang = self.language or "pt"
    -- Prioriza strings da pasta l10n (.po files)
    if l10n_strings and l10n_strings[key] then
        return l10n_strings[key]
    end
    -- Fallback para tabela interna de traduções
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
    G_reader_settings:delSetting("tarot_daily_date")
    G_reader_settings:delSetting("tarot_daily_card_id")
    G_reader_settings:delSetting("tarot_daily_card_is_reversed")
    G_reader_settings:delSetting("tarot_daily_revealed_date")
    G_reader_settings:delSetting("lenormand_daily_date")
    G_reader_settings:delSetting("lenormand_daily_card_id")
    G_reader_settings:delSetting("lenormand_daily_card_is_reversed")
    G_reader_settings:delSetting("lenormand_daily_revealed_date")
    G_reader_settings:delSetting("tarot_daily_card_is_lenormand")
    
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
    
    -- Recarrega strings de localização após restauração
    l10n_strings = loadL10n(self.language)
end

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           SEÇÃO 6: IMAGENS DAS CARTAS (suporte a PNG/JPG)                    ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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

function TarotPlugin:getCardImageWidget(card, w_override, h_override)
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
        }
    else
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

function TarotPlugin:getDimmedCardWidget(card, w, h)
    local img = self:getCardImageWidget(card, w, h)
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

    local card_path = self.plugin:getCardImagePath(card)
    local has_image = card_path and lfs.attributes(card_path) and lfs.attributes(card_path).mode == "file"
    local hide_name = (self.plugin.use_lenormand) and (lang == "en") and has_image

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

    local card_image
    if total_cards > 1 then
        local spacing = 24
        local has_left = self.current_index > 1
        local has_right = self.current_index < total_cards

        local main_w, main_h = self.plugin:getDefaultCardSize(card)
        local center_img = self.plugin:getCardImageWidget(card, main_w, main_h)

        local mini_w = math.floor(main_w * 2/3)
        local mini_h = math.floor(main_h * 2/3)

        local remaining = iw - main_w
        local half_remaining = math.floor(remaining / 2)

        local left_img, right_img
        if has_left then
            local left_card = self.cards[self.current_index - 1].card
            if self.plugin.use_lenormand then
                left_img = self.plugin:getCardImageWidget(left_card, mini_w, mini_h)
            else
                left_img = self.plugin:getDimmedCardWidget(left_card, mini_w, mini_h)
            end
        end
        if has_right then
            local right_card = self.cards[self.current_index + 1].card
            if self.plugin.use_lenormand then
                right_img = self.plugin:getCardImageWidget(right_card, mini_w, mini_h)
            else
                right_img = self.plugin:getDimmedCardWidget(right_card, mini_w, mini_h)
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
        card_image = self.plugin:getCardImageWidget(card)
    end

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

    local divider = TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "center",
    }

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

    local content = VerticalGroup:new{
        align = "center",
        title_w,
        VerticalSpan:new{ width = Size.span.vertical_default },
        card_image,
        VerticalSpan:new{ width = Size.span.vertical_default },
    }

    if name_w then
        table.insert(content, name_w)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    end

    table.insert(content, divider)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, meaning_w)

    -- NOVO BOTÃO "VER NO LIVRO" (subtle, transparent, small)
    local btn_view_in_book = Button:new{
    text = self.plugin:getTranslation("view_in_book"),
    bordersize = 0,
    background = nil,
    font_face = Font:getFace("x_smallinfofont"),
    width = math.floor(iw * 0.5),
    radius = 0,
    callback = function()
        self.plugin:showCardInBook(card)
    end,
}
-- Força a cor cinza diretamente no widget de texto
if btn_view_in_book.textwidget then
    btn_view_in_book.textwidget.fgcolor = Blitbuffer.gray(0.5)
end
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_small })
    table.insert(content, btn_view_in_book)

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(content, divider)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    if nav_row then
        table.insert(content, nav_row)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    end

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

    -- Título principal (centralizado)
    local title = TextWidget:new{
        text      = self.plugin:getTranslation("settings"),
        face      = Font:getFace("tfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    local rows = VerticalGroup:new{ align = "center" }

    -- ============================================================
    -- SEÇÃO: Tipo de baralho
    -- ============================================================
    local deck_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("deck_type") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }
    table.insert(rows, deck_section)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

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
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })

    -- Divisor visual (centralizado)
    local divider = TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "center",
    }
    table.insert(rows, divider)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })

    -- ============================================================
    -- SEÇÃO: Opções do Tarot (se não for Lenormand)
    -- ============================================================
    if not self.plugin.use_lenormand then
        -- Subseção: Cartas invertidas
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
        table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

        -- Subseção: Apenas Arcanos Maiores
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
        table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(rows, divider)
        table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })
    end

    -- ============================================================
    -- SEÇÃO: Carta oculta
    -- ============================================================
    local hidden_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("hidden_card") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }
    table.insert(rows, hidden_section)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

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
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(rows, divider)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })

    -- ============================================================
    -- SEÇÃO: Idioma
    -- ============================================================
    local lang_label = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("language") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }
    table.insert(rows, lang_label)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

    local current_lang = self.plugin.language
    local pt_mark = (current_lang == "pt") and "☑" or "☐"
    local en_mark = (current_lang == "en") and "☑" or "☐"

    local lang_btns = HorizontalGroup:new{
        align = "center",
        Button:new{
            text   = pt_mark .. " PT (BR)",
            width  = math.floor(iw * 0.47),
            radius = Size.radius.button,
            callback = function()
                self.plugin.language = "pt"
                G_reader_settings:saveSetting("tarot_language", "pt")
                -- Recarrega strings de localização ao mudar idioma
                l10n_strings = loadL10n("pt")
                UIManager:close(self)
                self.plugin:refreshMenu()
                UIManager:show(SettingsDialog:new{ plugin = self.plugin })
                UIManager:setDirty(nil, "full")
            end,
        },
        HorizontalSpan:new{ width = math.floor(iw * 0.06) },
        Button:new{
            text   = en_mark .. " EN",
            width  = math.floor(iw * 0.47),
            radius = Size.radius.button,
            callback = function()
                self.plugin.language = "en"
                G_reader_settings:saveSetting("tarot_language", "en")
                -- Recarrega strings de localização ao mudar idioma
                l10n_strings = loadL10n("en")
                UIManager:close(self)
                self.plugin:refreshMenu()
                UIManager:show(SettingsDialog:new{ plugin = self.plugin })
                UIManager:setDirty(nil, "full")
            end,
        },
    }
    table.insert(rows, lang_btns)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(rows, divider)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })

    -- ============================================================
    -- SEÇÃO: Redefinir (Restaurar)
    -- ============================================================
    local reset_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("reset_section") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }
    table.insert(rows, reset_section)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

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
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(rows, divider)
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_large })

    -- ============================================================
    -- Botões Sobre e Fechar
    -- ============================================================
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
    table.insert(rows, VerticalSpan:new{ width = Size.span.vertical_default })

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

    -- Montagem final
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

    -- 1. Nome da carta (título)
    local name_text = card.name[lang] or card.name.pt
    local name_w = TextWidget:new{
        text      = name_text,
        face      = Font:getFace("cfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }

    -- 2. Imagem à esquerda, informações à direita
    local default_w, default_h = self.plugin:getDefaultCardSize(card)
    local img_w = math.floor(default_w * 2/3)
    local img_h = math.floor(default_h * 2/3)
    local img_widget = self.plugin:getCardImageWidget(card, img_w, img_h)

    -- Largura disponível para a coluna da direita
    local right_col_w = iw - img_w - Size.span.horizontal_default

    -- Coluna da direita (VerticalGroup)
    local right_col = VerticalGroup:new{ align = "left" }

    -- Função auxiliar para adicionar um rótulo (cinza, small) + valor (normal)
    local function addInfoField(label, value)
        -- Rótulo
        local label_w = TextWidget:new{
            text      = label .. ":",
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = right_col_w,
            alignment = "left",
        }
        table.insert(right_col, label_w)
        -- Valor
        local value_w = TextBoxWidget:new{
            text      = value,
            face      = Font:getFace("cfont"),
            width     = right_col_w,
            alignment = "left",
        }
        table.insert(right_col, value_w)
        table.insert(right_col, VerticalSpan:new{ width = Size.span.vertical_small })
    end

    -- Keywords
    if card.keywords then
        local kw = card.keywords[lang] or card.keywords.pt
        addInfoField(self.plugin:getTranslation("keywords_label"), kw)
    end
    -- Planet / Sign
    if card.planet then
        local planet = card.planet[lang] or card.planet.pt
        addInfoField(self.plugin:getTranslation("planet_sign_label"), planet)
    end
    -- Timing
    if card.timing then
        local timing = card.timing[lang] or card.timing.pt
        addInfoField(self.plugin:getTranslation("timing_label"), timing)
    end

    -- Pequeno divisor se houver informações
    if card.keywords or card.planet or card.timing then
        local info_divider = TextWidget:new{
            text      = "─ ─ ─ ─ ─ ─ ─ ─",
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = right_col_w,
            alignment = "left",
        }
        table.insert(right_col, info_divider)
        table.insert(right_col, VerticalSpan:new{ width = Size.span.vertical_small })
    end

    -- Layout lado a lado: imagem (esquerda) + coluna de informações (direita)
    local image_info_row = HorizontalGroup:new{
        align = "top",
        img_widget,
        HorizontalSpan:new{ width = Size.span.horizontal_default },
        right_col,
    }

    -- Significado normal (Upright) – ALINHADO À ESQUERDA COMO O REVERSO
    local upright_label = (lang == "pt") and "Normal:" or "Upright:"
    local upright_label_w = TextWidget:new{
        text      = upright_label,
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "left",
    }
    local meaning_text = card.meaning[lang] or card.meaning.pt
    local meaning_w = TextBoxWidget:new{
        text      = meaning_text,
        face      = Font:getFace("cfont"),
        width     = iw,
        alignment = "left",
    }
    local upright_section = VerticalGroup:new{
        align = "left",
        upright_label_w,
        VerticalSpan:new{ width = Size.span.vertical_small },
        meaning_w,
    }

    -- Significado invertido (apenas se não for Lenormand e existir)
    local reversed_section
    if not self.plugin.use_lenormand and card.reversed_meaning then
        local reversed_label = (lang == "pt") and "Reverso:" or "Reversed:"
        local reversed_label_w = TextWidget:new{
            text      = reversed_label,
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = iw,
            alignment = "left",
        }
        local reversed_meaning_text = card.reversed_meaning[lang] or card.reversed_meaning.pt
        local reversed_meaning_w = TextBoxWidget:new{
            text      = reversed_meaning_text,
            face      = Font:getFace("cfont"),
            width     = iw,
            alignment = "left",
        }
        reversed_section = VerticalGroup:new{
            align = "left",
            reversed_label_w,
            VerticalSpan:new{ width = Size.span.vertical_small },
            reversed_meaning_w,
        }
    end

    -- Divisor padrão
    local divider = TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "center",
    }

    -- Navegação entre cartas
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

    -- Botão Voltar
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

    -- Montagem final do conteúdo
    local content = VerticalGroup:new{
        align = "center",
        name_w,
        VerticalSpan:new{ width = Size.span.vertical_default },
        image_info_row,
        VerticalSpan:new{ width = Size.span.vertical_large },
        upright_section,   -- ← agora alinhado à esquerda dentro do grupo
    }

    if reversed_section then
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, divider)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(content, reversed_section)
    end

    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_large })
    table.insert(content, divider)
    table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })

    if nav_row then
        table.insert(content, nav_row)
        table.insert(content, VerticalSpan:new{ width = Size.span.vertical_default })
    end

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

    -- Título principal
    local title = TextWidget:new{
        text      = self.plugin:getTranslation("card_book"),
        face      = Font:getFace("tfont"),
        bold      = true,
        max_width = iw,
        alignment = "center",
    }

    -- Seção Tarot
    local tarot_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("tarot_deck") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }

    -- Botão View All Cards (largura total)
    local btn_all = Button:new{
        text     = self.plugin:getTranslation("all_cards"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            self:showCardList(FULL_DECK)
        end,
    }

    -- Botões Arcanos Maiores | Arcanos Menores (lado a lado)
    local btn_major = Button:new{
        text     = self.plugin:getTranslation("major_arcana"),
        width    = math.floor((iw - Size.span.horizontal_default) / 2),
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            self:showCardList(MAJOR_ARCANA)
        end,
    }

    local btn_minor = Button:new{
        text     = self.plugin:getTranslation("minor_arcana"),
        width    = math.floor((iw - Size.span.horizontal_default) / 2),
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            self:showMinorArcanaMenu()
        end,
    }

    local major_minor_row = HorizontalGroup:new{
        align = "center",
        btn_major,
        HorizontalSpan:new{ width = Size.span.horizontal_default },
        btn_minor,
    }

    -- Divisor padrão (igual ao CardDialog)
    local divider = TextWidget:new{
        text      = "─ ─ ─ ─ ─ ─ ─ ─",
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "center",
    }

    -- Seção Lenormand
    local lenormand_section = TextWidget:new{
        text      = "— " .. self.plugin:getTranslation("lenormand_deck") .. " —",
        face      = Font:getFace("smalltfont"),
        bold      = true,
        max_width = iw,
        alignment = "left",
    }

    local btn_lenormand = Button:new{
        text     = self.plugin:getTranslation("lenormand_deck"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            self:showCardList(LENORMAND_DECK)
        end,
    }

    -- Botão Close
    local btn_close = Button:new{
        text     = self.plugin:getTranslation("close"),
        width    = iw,
        radius   = Size.radius.button,
        callback = function()
            UIManager:close(self)
            UIManager:setDirty(nil, "full")
        end,
    }

    -- Montagem do conteúdo vertical
    local content = VerticalGroup:new{
        align = "center",
        title,
        VerticalSpan:new{ width = Size.span.vertical_large },
        tarot_section,
        VerticalSpan:new{ width = Size.span.vertical_small },
        btn_all,
        VerticalSpan:new{ width = Size.span.vertical_large },
        major_minor_row,
        VerticalSpan:new{ width = Size.span.vertical_default },
        divider,
        VerticalSpan:new{ width = Size.span.vertical_default },
        lenormand_section,
        VerticalSpan:new{ width = Size.span.vertical_small },
        btn_lenormand,
        VerticalSpan:new{ width = Size.span.vertical_default },
        divider,
        VerticalSpan:new{ width = Size.span.vertical_default },
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
        { name = self.plugin:getTranslation("suit_wands"), symbol = "♣", start = 22, end_ = 35 },
        { name = self.plugin:getTranslation("suit_cups"), symbol = "♥", start = 36, end_ = 49 },
        { name = self.plugin:getTranslation("suit_swords"), symbol = "♠", start = 50, end_ = 63 },
        { name = self.plugin:getTranslation("suit_pentacles"), symbol = "♦", start = 64, end_ = 77 },
    }

    -- Largura de cada botão de naipe (2 por fileira)
    local btn_width = math.floor((iw - Size.span.horizontal_default) / 2)

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
        local buttons_vgroup = VerticalGroup:new{ align = "center" }

        -- Primeira fileira: Wands | Cups
        local row1 = HorizontalGroup:new{ align = "center" }
        local btn_wands = Button:new{
            text     = suit_keys[1].symbol .. " " .. suit_keys[1].name,
            width    = btn_width,
            radius   = Size.radius.button,
            callback = function()
                local cards = {}
                for _, card in ipairs(MINOR_ARCANA) do
                    if card.id >= suit_keys[1].start and card.id <= suit_keys[1].end_ then
                        table.insert(cards, card)
                    end
                end
                UIManager:close(self)
                self:showCardList(cards)
            end,
        }
        local btn_cups = Button:new{
            text     = suit_keys[2].symbol .. " " .. suit_keys[2].name,
            width    = btn_width,
            radius   = Size.radius.button,
            callback = function()
                local cards = {}
                for _, card in ipairs(MINOR_ARCANA) do
                    if card.id >= suit_keys[2].start and card.id <= suit_keys[2].end_ then
                        table.insert(cards, card)
                    end
                end
                UIManager:close(self)
                self:showCardList(cards)
            end,
        }
        table.insert(row1, btn_wands)
        table.insert(row1, HorizontalSpan:new{ width = Size.span.horizontal_default })
        table.insert(row1, btn_cups)
        table.insert(buttons_vgroup, row1)
        table.insert(buttons_vgroup, VerticalSpan:new{ width = Size.span.vertical_large })

        -- Segunda fileira: Swords | Pentacles
        local row2 = HorizontalGroup:new{ align = "center" }
        local btn_swords = Button:new{
            text     = suit_keys[3].symbol .. " " .. suit_keys[3].name,
            width    = btn_width,
            radius   = Size.radius.button,
            callback = function()
                local cards = {}
                for _, card in ipairs(MINOR_ARCANA) do
                    if card.id >= suit_keys[3].start and card.id <= suit_keys[3].end_ then
                        table.insert(cards, card)
                    end
                end
                UIManager:close(self)
                self:showCardList(cards)
            end,
        }
        local btn_pents = Button:new{
            text     = suit_keys[4].symbol .. " " .. suit_keys[4].name,
            width    = btn_width,
            radius   = Size.radius.button,
            callback = function()
                local cards = {}
                for _, card in ipairs(MINOR_ARCANA) do
                    if card.id >= suit_keys[4].start and card.id <= suit_keys[4].end_ then
                        table.insert(cards, card)
                    end
                end
                UIManager:close(self)
                self:showCardList(cards)
            end,
        }
        table.insert(row2, btn_swords)
        table.insert(row2, HorizontalSpan:new{ width = Size.span.horizontal_default })
        table.insert(row2, btn_pents)
        table.insert(buttons_vgroup, row2)
        table.insert(buttons_vgroup, VerticalSpan:new{ width = Size.span.vertical_large })

        -- Botão "All Cards - Minor Arcana" (largura total)
        local btn_all_minor = Button:new{
            text     = self.plugin:getTranslation("all_cards") .. " - " .. self.plugin:getTranslation("minor_arcana"),
            width    = iw,
            radius   = Size.radius.button,
            callback = function()
                UIManager:close(self)
                self:showCardList(MINOR_ARCANA)
            end,
        }
        table.insert(buttons_vgroup, btn_all_minor)

        -- Divisor padrão
        local divider = TextWidget:new{
            text      = "─ ─ ─ ─ ─ ─ ─ ─",
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = iw,
            alignment = "center",
        }
        table.insert(buttons_vgroup, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(buttons_vgroup, divider)
        table.insert(buttons_vgroup, VerticalSpan:new{ width = Size.span.vertical_large })

        -- Botão Voltar
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
        table.insert(buttons_vgroup, btn_back)

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
            buttons_vgroup,
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

function TarotPlugin:showCardInBook(card)
    local deck = self:getActiveDeck()
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
        parent_callback = function()
            UIManager:setDirty(nil, "full")
        end,
    })
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
        local prefix = self.use_lenormand and "lenormand_daily_" or "tarot_daily_"
        local date_key = prefix .. "date"
        local card_id_key = prefix .. "card_id"
        local is_reversed_key = prefix .. "is_reversed"
        local revealed_key = prefix .. "revealed_date"

        local today = self:getCurrentDateStr()
        local stored_date = G_reader_settings:readSetting(date_key) or ""
        local card
        
        if stored_date == today then
            local card_id = G_reader_settings:readSetting(card_id_key)
            local deck = self:getActiveDeck()
            card = nil
            for _, c in ipairs(deck) do
                if c.id == card_id then
                    card = c
                    break
                end
            end
            if not card then
                card = deck[math.random(1, #deck)]
                G_reader_settings:saveSetting(card_id_key, card.id)
            end
        else
            local deck = self:getActiveDeck()
            card = deck[math.random(1, #deck)]
            G_reader_settings:saveSetting(date_key, today)
            G_reader_settings:saveSetting(card_id_key, card.id)
        end

        local is_reversed = false
        if not self.use_lenormand and self.allow_reversed then
            if stored_date == today then
                is_reversed = G_reader_settings:readSetting(is_reversed_key) or false
            else
                is_reversed = math.random(2) == 1
                G_reader_settings:saveSetting(is_reversed_key, is_reversed)
            end
        end

        if stored_date ~= today then
            G_reader_settings:saveSetting(revealed_key, "")
        end

        UIManager:close(loading)
        
        local cards = {{ card = card, is_reversed = is_reversed }}
        local on_new_func = function() self:showDailyCard() end
        
        local revealed_date = G_reader_settings:readSetting(revealed_key) or ""
        
        if self.hidden_card and revealed_date ~= today then
            local hidden_dlg = HiddenCardDialog:new{
                plugin = self,
                cards = cards,
                on_new = on_new_func,
                is_daily = true,
                on_reveal = function()
                    G_reader_settings:saveSetting(revealed_key, today)
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

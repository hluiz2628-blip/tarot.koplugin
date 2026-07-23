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
-- ║                 SEÇÃO 1: INTERNACIONALIZAÇÃO (gettext)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
-- O inglês é o idioma-fonte. Todas as traduções ficam fora deste arquivo,
-- em l10n/<idioma>/koreader.po (fonte) e koreader.mo (catálogo carregado).
local T = require("tarot_gettext")

local UI_TEXT = {
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
    saved_card_line = "Card %d — %s (%s)",
    plugin_description = "Draw Tarot and Lenormand cards for reflection, save readings, and browse the complete card book.",
}
-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 2: CARTAS - ARCANOS MAIORES (22)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local MAJOR_ARCANA = {
    {
        id = 0, roman = "0",
        name = "The Fool",
        keywords = "New beginning, spontaneity, faith, risk",
        planet = "Uranus",
        timing = "Immediate, unpredictable",
        meaning = "New beginnings. Spontaneity. Take a leap of faith. Venture without fear, the universe supports you.",
        reversed_meaning = "Recklessness. Lack of direction. Think before acting. Blind risk may bring consequences."
    },
    {
        id = 1, roman = "I",
        name = "The Magician",
        keywords = "Power, skill, manifestation, focus",
        planet = "Mercury",
        timing = "Fast, now is the time",
        meaning = "Personal power. Skill. You have everything you need. Manifest your desires with confidence.",
        reversed_meaning = "Manipulation. Wasted talent. Deceit. Beware of illusions of power."
    },
    {
        id = 2, roman = "II",
        name = "The High Priestess",
        keywords = "Intuition, mystery, subconscious, wisdom",
        planet = "Moon",
        timing = "Lunar cycles, 28 days",
        meaning = "Intuition. Mystery. Trust your inner voice. Hidden knowledge reveals itself in silence.",
        reversed_meaning = "Secrets revealed. Intuitive disconnection. Silence broken. Listen to your inner voice again."
    },
    {
        id = 3, roman = "III",
        name = "The Empress",
        keywords = "Abundance, fertility, nature, nurturing",
        planet = "Venus",
        timing = "9 months, spring",
        meaning = "Abundance. Fertility. Nurture yourself. Nature flourishes around you.",
        reversed_meaning = "Neglect. Creative block. Dependence. Return to tending your inner garden."
    },
    {
        id = 4, roman = "IV",
        name = "The Emperor",
        keywords = "Authority, structure, leadership, stability",
        planet = "Aries",
        timing = "1 year, soon",
        meaning = "Authority. Structure. Take control. Firm leadership brings stability.",
        reversed_meaning = "Tyranny. Rigidity. Lack of discipline. Excess control suffocates."
    },
    {
        id = 5, roman = "V",
        name = "The Hierophant",
        keywords = "Tradition, wisdom, guidance, teaching",
        planet = "Taurus",
        timing = "5 weeks, slow but steady",
        meaning = "Tradition. Wisdom. Seek guidance. Masters appear when the student is ready.",
        reversed_meaning = "Rebellion. Dogma. Necessary questioning. Breaking with traditions can be liberating."
    },
    {
        id = 6, roman = "VI",
        name = "The Lovers",
        keywords = "Love, choice, harmony, partnership",
        planet = "Gemini",
        timing = "Imminent decision",
        meaning = "Love. Choice. Harmony in relationships. The heart knows the way.",
        reversed_meaning = "Conflict. Imbalance. Difficult decision. Avoid impulsive choices in love."
    },
    {
        id = 7, roman = "VII",
        name = "The Chariot",
        keywords = "Victory, determination, control, progress",
        planet = "Cancer",
        timing = "7 weeks",
        meaning = "Victory. Determination. Move forward with confidence. Triumph awaits the perseverant.",
        reversed_meaning = "Lack of direction. Defeat. Loss of control. Reevaluate your route before proceeding."
    },
    {
        id = 8, roman = "VIII",
        name = "Strength",
        keywords = "Courage, inner strength, compassion, mastery",
        planet = "Leo",
        timing = "8 weeks",
        meaning = "Courage. Inner strength. Master your impulses with kindness, not violence.",
        reversed_meaning = "Weakness. Insecurity. Lack of self-control. True strength comes from vulnerability."
    },
    {
        id = 9, roman = "IX",
        name = "The Hermit",
        keywords = "Introspection, solitude, wisdom, inner search",
        planet = "Virgo",
        timing = "9 months, slow",
        meaning = "Introspection. Inner wisdom. Seek silence. The light you seek is within you.",
        reversed_meaning = "Isolation. Loneliness. Refusing to see the truth. Prolonged retreat becomes escape."
    },
    {
        id = 10, roman = "X",
        name = "Wheel of Fortune",
        keywords = "Change, destiny, cycles, luck",
        planet = "Jupiter",
        timing = "In motion, cyclical",
        meaning = "Change. Destiny. Luck is turning in your favor. Everything passes, cycles renew.",
        reversed_meaning = "Bad luck. Resistance to change. Negative cycle. Accept that nothing is permanent."
    },
    {
        id = 11, roman = "XI",
        name = "Justice",
        keywords = "Balance, truth, law, cause and effect",
        planet = "Libra",
        timing = "Under review, fair",
        meaning = "Balance. Truth. Justice will prevail. Reap what you have sown with serenity.",
        reversed_meaning = "Injustice. Dishonesty. Consequences coming. The scales weigh against you now."
    },
    {
        id = 12, roman = "XII",
        name = "The Hanged Man",
        keywords = "Sacrifice, suspension, new perspective, surrender",
        planet = "Neptune",
        timing = "Indeterminate, pause",
        meaning = "Sacrifice. New perspective. Let go, trust. Sometimes stopping is advancing.",
        reversed_meaning = "Stagnation. Procrastination. Resist change. The pause has become paralysis."
    },
    {
        id = 13, roman = "XIII",
        name = "Death",
        keywords = "Transformation, ending, rebirth, transition",
        planet = "Scorpio",
        timing = "Autumn, shortly",
        meaning = "Transformation. End of a cycle. Rebirth near. The old dies so the new can be born.",
        reversed_meaning = "Resistance to change. Stagnation. Fear of endings. Let go of what no longer serves."
    },
    {
        id = 14, roman = "XIV",
        name = "Temperance",
        keywords = "Patience, balance, moderation, harmony",
        planet = "Sagittarius",
        timing = "Patience, gradual",
        meaning = "Patience. Moderation. Find balance. Water finds its level.",
        reversed_meaning = "Excess. Impatience. Disharmony. Return to center, breathe deeply."
    },
    {
        id = 15, roman = "XV",
        name = "The Devil",
        keywords = "Temptation, attachment, shadow, materialism",
        planet = "Capricorn",
        timing = "15 days",
        meaning = "Temptation. Negative patterns. Free yourself from chains. You have the power to break free.",
        reversed_meaning = "Liberation. Breaking addictions. Recovery. Light enters where darkness once was."
    },
    {
        id = 16, roman = "XVI",
        name = "The Tower",
        keywords = "Revelation, upheaval, chaos, reconstruction",
        planet = "Mars",
        timing = "Sudden, unexpected",
        meaning = "Sudden revelation. Rupture. Necessary reconstruction. What is false crumbles.",
        reversed_meaning = "Avoiding disaster. Fear of change. Denial. The fall is inevitable, accept it."
    },
    {
        id = 17, roman = "XVII",
        name = "The Star",
        keywords = "Hope, faith, inspiration, renewal",
        planet = "Aquarius",
        timing = "17 days",
        meaning = "Hope. Faith. Follow your intuition. Light guides you in darkness. Trust the universe.",
        reversed_meaning = "Hopelessness. Lack of faith. Spiritual disconnection. The light is there, you just don't see it."
    },
    {
        id = 18, roman = "XVIII",
        name = "The Moon",
        keywords = "Illusion, intuition, fear, subconscious",
        planet = "Pisces",
        timing = "28 days, nocturnal",
        meaning = "Illusion. Intuition. Not everything is as it seems. Walk carefully in the twilight.",
        reversed_meaning = "Confusion cleared. Fear overcome. Truth revealed. The fog is lifting."
    },
    {
        id = 19, roman = "XIX",
        name = "The Sun",
        keywords = "Joy, success, vitality, clarity",
        planet = "Sun",
        timing = "19 days, diurnal",
        meaning = "Joy. Success. Vitality. Everything is illuminated. Happiness overflows.",
        reversed_meaning = "Temporary sadness. Delay. Lack of enthusiasm. The sun always shines again."
    },
    {
        id = 20, roman = "XX",
        name = "Judgement",
        keywords = "Renewal, awakening, forgiveness, calling",
        planet = "Pluto",
        timing = "Renewal, awakening",
        meaning = "Renewal. Inner calling. Time to awaken. The past has been forgiven.",
        reversed_meaning = "Self-criticism. Regret. Denial of the calling. Free yourself from guilt."
    },
    {
        id = 21, roman = "XXI",
        name = "The World",
        keywords = "Completion, fulfillment, integration, success",
        planet = "Saturn",
        timing = "21 days/months, full cycle",
        meaning = "Completion. Fulfillment. Cycle successfully concluded. The universe celebrates with you.",
        reversed_meaning = "Incompleteness. Delay. Lack of closure. There is still one step to take."
    },
}

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                 SEÇÃO 3: CARTAS - ARCANOS MENORES (56)                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local suits = {
    { name = "Wands", symbol = "♣" },
    { name = "Cups", symbol = "♥" },
    { name = "Swords", symbol = "♠" },
    { name = "Pentacles", symbol = "♦" },
}

local ranks = {
    { name = "Ace" },
    { name = "Two" },
    { name = "Three" },
    { name = "Four" },
    { name = "Five" },
    { name = "Six" },
    { name = "Seven" },
    { name = "Eight" },
    { name = "Nine" },
    { name = "Ten" },
    { name = "Page" },
    { name = "Knight" },
    { name = "Queen" },
    { name = "King" },
}

local MINOR_ARCANA = {
    -- ═══════════════════════  NAIPE DE PAUS (Wands) ═══════════════════════
    {
        id = 22, suit = suits[1], rank = ranks[1],
        name = "Ace of Wands",
        keywords = "Inspiration, creativity, new beginning, energy",
        timing = "Fast (days)",
        meaning = "Creative inspiration. A new beginning full of energy. Seize the initial impulse to start projects.",
        reversed_meaning = "False start. Procrastination. Lack of motivation. Rekindle your passion before moving on."
    },
    {
        id = 23, suit = suits[1], rank = ranks[2],
        name = "Two of Wands",
        keywords = "Planning, vision, decision, expansion",
        timing = "Weeks",
        meaning = "Planning. Looking ahead. You have the world in your hands, but you must choose the path.",
        reversed_meaning = "Fear of the unknown. Lack of planning. Letting go of the reins. Define your goals."
    },
    {
        id = 24, suit = suits[1], rank = ranks[3],
        name = "Three of Wands",
        keywords = "Expansion, progress, anticipation, trade",
        timing = "Soon",
        meaning = "Expansion. Progress. Your plans are sailing. Await the return of the seeds you planted.",
        reversed_meaning = "Unexpected obstacles. Delay. Frustration with results. Reassess your strategy."
    },
    {
        id = 25, suit = suits[1], rank = ranks[4],
        name = "Four of Wands",
        keywords = "Celebration, home, harmony, stability",
        timing = "4 weeks",
        meaning = "Celebration. Harmony at home. Shared achievements. A well-deserved rest after effort.",
        reversed_meaning = "Lack of unity. Domestic instability. Postponed celebration. Recover simple joy."
    },
    {
        id = 26, suit = suits[1], rank = ranks[5],
        name = "Five of Wands",
        keywords = "Competition, conflict, debate, growth",
        timing = "5 weeks",
        meaning = "Healthy competition. Creative conflict. Different viewpoints enrich the search.",
        reversed_meaning = "Internal quarrels. Avoiding confrontation. Energy drain. Seek cooperation instead of dispute."
    },
    {
        id = 27, suit = suits[1], rank = ranks[6],
        name = "Six of Wands",
        keywords = "Victory, recognition, triumph, confidence",
        timing = "6 weeks",
        meaning = "Victory. Public recognition. High self-esteem. Reap the laurels with humility.",
        reversed_meaning = "Inflated ego. Short-lived recognition. Envy. True victory is internal."
    },
    {
        id = 28, suit = suits[1], rank = ranks[7],
        name = "Seven of Wands",
        keywords = "Defense, perseverance, courage, resistance",
        timing = "7 weeks",
        meaning = "Defense of positions. Perseverance. Stand firm despite opposition. You have the upper hand.",
        reversed_meaning = "Exhaustion. Feeling cornered. Giving up. Reinforce your boundaries wisely."
    },
    {
        id = 29, suit = suits[1], rank = ranks[8],
        name = "Eight of Wands",
        keywords = "Speed, action, progress, communication",
        timing = "Very fast",
        meaning = "Swift movement. News arriving. Accelerated action. Take advantage of the tailwind.",
        reversed_meaning = "Delay. Lack of direction. Scattered energy. Wait for the right moment to act."
    },
    {
        id = 30, suit = suits[1], rank = ranks[9],
        name = "Nine of Wands",
        keywords = "Resilience, persistence, last stand, fatigue",
        timing = "9 weeks",
        meaning = "Resilience. Last battle. You are almost there, even if tired. Keep your guard up.",
        reversed_meaning = "Stubbornness. Refusing help. Exhaustion. Let down your defense and allow yourself to rest."
    },
    {
        id = 31, suit = suits[1], rank = ranks[10],
        name = "Ten of Wands",
        keywords = "Overload, responsibility, burden, effort",
        timing = "10 weeks, end of cycle",
        meaning = "Overload. Heavy responsibilities. The burden is great, but the end is near. Delegate tasks.",
        reversed_meaning = "Inability to delegate. Burnout. Refusing help. Let go of what doesn't belong to you."
    },
    {
        id = 32, suit = suits[1], rank = ranks[11],
        name = "Page of Wands",
        keywords = "Enthusiasm, exploration, discovery, new idea",
        timing = "Youthful, fast",
        meaning = "Enthusiasm. New ideas. A young messenger brings inspiration. Explore your curiosity without fear.",
        reversed_meaning = "Lack of plans. Impulsiveness. Ideas without execution. Set goals before acting."
    },
    {
        id = 33, suit = suits[1], rank = ranks[12],
        name = "Knight of Wands",
        keywords = "Action, passion, impulse, adventure",
        timing = "Immediate, intense",
        meaning = "Passionate action. Courage to take risks. Go ahead boldly, but don't forget the destination.",
        reversed_meaning = "Impatience. Rushing without direction. Conflict. Slow down and choose the right path."
    },
    {
        id = 34, suit = suits[1], rank = ranks[13],
        name = "Queen of Wands",
        keywords = "Charisma, leadership, warmth, confidence",
        timing = "Summer, mature",
        meaning = "Warmth, determination and magnetism. Inspiring leadership. Use your charisma to attract what you want.",
        reversed_meaning = "Jealousy. Insecurity. Explosive temper. The inner flame can burn those nearby."
    },
    {
        id = 35, suit = suits[1], rank = ranks[14],
        name = "King of Wands",
        keywords = "Vision, entrepreneurship, authority, honor",
        timing = "Long term, leadership",
        meaning = "Entrepreneurial vision. Strong leadership. Take command with integrity and inspire others.",
        reversed_meaning = "Authoritarianism. Empty promises. Lack of vision. Leading by fear builds nothing lasting."
    },

    -- ═══════════════════════  NAIPE DE COPAS (Cups) ═══════════════════════
    {
        id = 36, suit = suits[2], rank = ranks[1],
        name = "Ace of Cups",
        keywords = "Love, emotion, intuition, new feeling",
        timing = "Lunar, emotional",
        meaning = "Overflowing love. New emotional cycle. Open yourself to deep feelings and true connections.",
        reversed_meaning = "Repressed love. Emotional block. Inner emptiness. Allow yourself to feel in order to heal."
    },
    {
        id = 37, suit = suits[2], rank = ranks[2],
        name = "Two of Cups",
        keywords = "Union, partnership, commitment, attraction",
        timing = "Meeting soon",
        meaning = "Union. Loving partnership. Soul meeting. Mutual respect and commitment strengthen the bond.",
        reversed_meaning = "Disconnection. Quarrels. Emotional imbalance. A sincere conversation can restore harmony."
    },
    {
        id = 38, suit = suits[2], rank = ranks[3],
        name = "Three of Cups",
        keywords = "Friendship, celebration, community, joy",
        timing = "Social event",
        meaning = "Friendship. Celebration. Shared joy. Gather with those you love and celebrate life.",
        reversed_meaning = "Gossip. Isolation. Excess partying. Beware of superficial friendships and hidden resentments."
    },
    {
        id = 39, suit = suits[2], rank = ranks[4],
        name = "Four of Cups",
        keywords = "Contemplation, apathy, boredom, introspection",
        timing = "Stagnant",
        meaning = "Contemplation. Apathy. New invitation ignored. Look beyond boredom to notice opportunities.",
        reversed_meaning = "Awakening. Acceptance. New perspectives. Leave your comfort zone and seize the chance offered."
    },
    {
        id = 40, suit = suits[2], rank = ranks[5],
        name = "Five of Cups",
        keywords = "Grief, loss, regret, focus on negative",
        timing = "Recent past",
        meaning = "Grief. Loss. Focus on what is gone. Two cups still stand – look at what remains.",
        reversed_meaning = "Overcoming. Recovery. Learning from pain. Accept the past and move forward."
    },
    {
        id = 41, suit = suits[2], rank = ranks[6],
        name = "Six of Cups",
        keywords = "Nostalgia, memory, childhood, gift",
        timing = "Revisiting the past",
        meaning = "Nostalgia. Fond memories. Reunion with the past. Cherish your roots with affection.",
        reversed_meaning = "Clinging to the past. Immaturity. Inability to move on. Live the present."
    },
    {
        id = 42, suit = suits[2], rank = ranks[7],
        name = "Seven of Cups",
        keywords = "Illusion, choices, fantasy, dreams",
        timing = "Confusing, indefinite",
        meaning = "Illusions. Fantasies. Multiple options. Discernment is needed to choose the true cup.",
        reversed_meaning = "Clarity. Firm decision. End of illusions. Focus on what really matters."
    },
    {
        id = 43, suit = suits[2], rank = ranks[8],
        name = "Eight of Cups",
        keywords = "Withdrawal, search, disillusion, departure",
        timing = "Emotional transition",
        meaning = "Withdrawal. Spiritual search. Leaving behind what doesn't fulfill. Follow your intuition.",
        reversed_meaning = "Fear of change. Staying out of convenience. Silent dissatisfaction. Courage to leave."
    },
    {
        id = 44, suit = suits[2], rank = ranks[9],
        name = "Nine of Cups",
        keywords = "Wish fulfilled, satisfaction, contentment, luxury",
        timing = "Soon fulfillment",
        meaning = "Wish fulfilled. Satisfaction. The “dream cup” is full. Enjoy emotional abundance.",
        reversed_meaning = "Dissatisfaction. Unmet desires. Empty materialism. True happiness lies in simplicity."
    },
    {
        id = 45, suit = suits[2], rank = ranks[10],
        name = "Ten of Cups",
        keywords = "Happiness, family, harmony, blessing",
        timing = "Happy ending",
        meaning = "Full happiness. Family love. Lasting harmony. The heart overflows with shared joy.",
        reversed_meaning = "Family conflicts. Broken bonds. Idealization of happiness. Work on emotional communication."
    },
    {
        id = 46, suit = suits[2], rank = ranks[11],
        name = "Page of Cups",
        keywords = "Sensitivity, creativity, message, intuition",
        timing = "Emotional surprise",
        meaning = "Creative sensitivity. Message of love. Open up to intuition and heart surprises.",
        reversed_meaning = "Emotional immaturity. Love disappointment. Childish jealousy. Put fantasy aside and face reality."
    },
    {
        id = 47, suit = suits[2], rank = ranks[12],
        name = "Knight of Cups",
        keywords = "Romanticism, charm, proposal, idealism",
        timing = "Invitation soon",
        meaning = "Romanticism. Charming proposal. Search for the beautiful and ideal. Follow your heart with elegance.",
        reversed_meaning = "Love illusion. Empty promises. Excess of idealization. Keep your feet on the ground."
    },
    {
        id = 48, suit = suits[2], rank = ranks[13],
        name = "Queen of Cups",
        keywords = "Empathy, intuition, care, compassion",
        timing = "Lunar cycle, mature",
        meaning = "Deep intuition. Empathy. Emotional caregiver. Trust your ability to love and heal.",
        reversed_meaning = "Emotional dependence. Exacerbated sensitivity. Emotional manipulation. Set healthy boundaries."
    },
    {
        id = 49, suit = suits[2], rank = ranks[14],
        name = "King of Cups",
        keywords = "Emotional mastery, diplomacy, calm, wisdom",
        timing = "Emotional stability",
        meaning = "Emotional mastery. Mature compassion. Leadership with heart. Calm turbulent waters with wisdom.",
        reversed_meaning = "Coldness. Emotional repression. Manipulation. The repressed heart becomes a silent tyrant."
    },

    -- ═══════════════════════  NAIPE DE ESPADAS (Swords) ═══════════════════════
    {
        id = 50, suit = suits[3], rank = ranks[1],
        name = "Ace of Swords",
        keywords = "Clarity, truth, justice, sharp mind",
        timing = "Quick decision",
        meaning = "Mental clarity. Truth revealed. Sharp idea. Use the power of the word with justice.",
        reversed_meaning = "Confusion. Lies. Verbal abuse. Distorted truth hurts. Seek clean communication."
    },
    {
        id = 51, suit = suits[3], rank = ranks[2],
        name = "Two of Swords",
        keywords = "Impasse, difficult choice, denial, balance",
        timing = "Stalled",
        meaning = "Difficult decision. Impasse. Precarious balance. Remove the blindfold and face the situation.",
        reversed_meaning = "Postponed decision. Escape from truth. Internal conflict. Free yourself from paralysis and choose."
    },
    {
        id = 52, suit = suits[3], rank = ranks[3],
        name = "Three of Swords",
        keywords = "Pain, betrayal, sadness, heartbreak",
        timing = "Recent pain",
        meaning = "Emotional pain. Betrayal. Broken heart. Suffering is real, but it's the first step toward healing.",
        reversed_meaning = "Slow recovery. Holding grudges. Difficulty forgiving. Free yourself from the poison of resentment."
    },
    {
        id = 53, suit = suits[3], rank = ranks[4],
        name = "Four of Swords",
        keywords = "Rest, recovery, contemplation, pause",
        timing = "Necessary pause",
        meaning = "Mental rest. Retreat. Recovery. Step away from the noise and recharge your mind.",
        reversed_meaning = "Insomnia. Mental exhaustion. Inability to relax. Excessive thinking makes you sick."
    },
    {
        id = 54, suit = suits[3], rank = ranks[5],
        name = "Five of Swords",
        keywords = "Conflict, defeat, hostility, hollow victory",
        timing = "Current conflict",
        meaning = "Conflict. Empty victory. Humiliation. Sometimes winning the battle means losing the war.",
        reversed_meaning = "Reconciliation. Remorse. Putting pride aside. Seek peace instead of being right."
    },
    {
        id = 55, suit = suits[3], rank = ranks[6],
        name = "Six of Swords",
        keywords = "Transition, healing, journey, moving on",
        timing = "Gradual transition",
        meaning = "Smooth transition. Healing journey. Leaving turbulent waters behind. Toward calm waters.",
        reversed_meaning = "Resistance to change. Emotional baggage. Staying stuck in the problem. Release what you cannot carry."
    },
    {
        id = 56, suit = suits[3], rank = ranks[7],
        name = "Seven of Swords",
        keywords = "Strategy, deception, escape, cunning",
        timing = "Fast, stealthy",
        meaning = "Strategy. Subtle escape. Not everything needs to be faced head-on. Act with intelligence.",
        reversed_meaning = "Deception. Theft. Lack of ethics. Lies have short legs. Act with honesty."
    },
    {
        id = 57, suit = suits[3], rank = ranks[8],
        name = "Eight of Swords",
        keywords = "Imprisonment, self-sabotage, limitation, fear",
        timing = "Mental prison, temporary",
        meaning = "Feeling trapped. Self-sabotage. Imaginary limitations. The prison is mental – the key is within you.",
        reversed_meaning = "Liberation. New perspective. Overcoming limiting beliefs. Break the bonds and see the light."
    },
    {
        id = 58, suit = suits[3], rank = ranks[9],
        name = "Nine of Swords",
        keywords = "Anxiety, nightmare, worry, anguish",
        timing = "Nocturnal, insomnia",
        meaning = "Anxiety. Nightmares. Nocturnal worries. The mind is its own tormentor. Seek to calm your thoughts.",
        reversed_meaning = "Recovery from anguish. Learning from pain. The worst is over. Take a deep breath."
    },
    {
        id = 59, suit = suits[3], rank = ranks[10],
        name = "Ten of Swords",
        keywords = "Painful ending, betrayal, crisis, rebirth",
        timing = "Rock bottom, new dawn",
        meaning = "Painful ending. Final betrayal. Rock bottom. From this abyss one can only rise – dawn arrives.",
        reversed_meaning = "Recovery. Resistance. Avoiding the final collapse. Suffering can be transformed into strength."
    },
    {
        id = 60, suit = suits[3], rank = ranks[11],
        name = "Page of Swords",
        keywords = "Curiosity, communication, ideas, vigilance",
        timing = "News shortly",
        meaning = "Intellectual curiosity. New ideas. Agile communication. Speak your truth, but with tact.",
        reversed_meaning = "Gossip. Superficial thinking. Baseless criticism. Use your mind to build, not destroy."
    },
    {
        id = 61, suit = suits[3], rank = ranks[12],
        name = "Knight of Swords",
        keywords = "Swift action, impulse, determination, conflict",
        timing = "Now, urgent",
        meaning = "Impetuous action. Intellectual determination. Advance with momentum, but don't trample others.",
        reversed_meaning = "Blind impulsiveness. Unnecessary confrontation. Aggressiveness. Think before brandishing the sword."
    },
    {
        id = 62, suit = suits[3], rank = ranks[13],
        name = "Queen of Swords",
        keywords = "Rationality, independence, discernment, truth",
        timing = "Mature decision",
        meaning = "Clear rationality. Independence. Weighted justice. Make decisions with the mind, but without losing empathy.",
        reversed_meaning = "Emotional coldness. Bitterness. Harsh judgment. Reason without heart becomes cruelty."
    },
    {
        id = 63, suit = suits[3], rank = ranks[14],
        name = "King of Swords",
        keywords = "Intellectual authority, ethics, clarity, justice",
        timing = "Legal authority, long term",
        meaning = "Intellectual authority. Ethics. Just and lucid leadership. Truth is your sharpest sword.",
        reversed_meaning = "Mental tyranny. Manipulation of truth. Abuse of power. Intellect without morals oppresses."
    },

    -- ═══════════════════════  NAIPE DE OUROS (Pentacles) ═══════════════════════
    {
        id = 64, suit = suits[4], rank = ranks[1],
        name = "Ace of Pentacles",
        keywords = "Opportunity, prosperity, new resource, security",
        timing = "Material beginning",
        meaning = "New material opportunity. Prosperity at hand. Get to work to reap solid fruits.",
        reversed_meaning = "Missed opportunity. Greed. Financial delay. The foundation needs to be set before growing."
    },
    {
        id = 65, suit = suits[4], rank = ranks[2],
        name = "Two of Pentacles",
        keywords = "Balance, adaptation, juggling, priorities",
        timing = "Fluctuating",
        meaning = "Financial balance. Juggling. Adapt to changes without losing control of your accounts.",
        reversed_meaning = "Disorganization. Debt overload. Inability to prioritize. Reorganize your finances."
    },
    {
        id = 66, suit = suits[4], rank = ranks[3],
        name = "Three of Pentacles",
        keywords = "Teamwork, collaboration, mastery, skill",
        timing = "Project in progress",
        meaning = "Teamwork. Mastery. Productive collaboration. Together, the result is greater than the sum.",
        reversed_meaning = "Lack of collaboration. Carelessness. Poor workmanship. Restore respect for excellence."
    },
    {
        id = 67, suit = suits[4], rank = ranks[4],
        name = "Four of Pentacles",
        keywords = "Security, attachment, saving, control",
        timing = "Stable, stagnant",
        meaning = "Material security. Attachment to possessions. Healthy saving, but without closing off to the new.",
        reversed_meaning = "Miserliness. Fear of loss. Blocking abundance. Let go a little control to receive."
    },
    {
        id = 68, suit = suits[4], rank = ranks[5],
        name = "Five of Pentacles",
        keywords = "Hardship, scarcity, exclusion, aid",
        timing = "Difficult period",
        meaning = "Material hardship. Feeling of exclusion. Help is closer than you think. Ask for assistance.",
        reversed_meaning = "Financial recovery. End of scarcity. Re-inclusion. Light shines at the end of the tunnel."
    },
    {
        id = 69, suit = suits[4], rank = ranks[6],
        name = "Six of Pentacles",
        keywords = "Generosity, sharing, charity, balance",
        timing = "Give and receive",
        meaning = "Generosity. Sharing. Giving and receiving in balance. Prosperity circulates when the hand opens.",
        reversed_meaning = "Self-interested charity. Debts. Imbalance in giving. Beware of those who only ask and never give back."
    },
    {
        id = 70, suit = suits[4], rank = ranks[7],
        name = "Seven of Pentacles",
        keywords = "Patience, harvest, evaluation, investment",
        timing = "Long term",
        meaning = "Patience. Harvest in progress. Evaluate if your efforts are yielding the expected fruits.",
        reversed_meaning = "Impatience. Fruitless work. Frustration with results. Recalculate the route and continue."
    },
    {
        id = 71, suit = suits[4], rank = ranks[8],
        name = "Eight of Pentacles",
        keywords = "Dedication, learning, improvement, work",
        timing = "Daily, constant",
        meaning = "Dedicated learning. Craftsmanship. Constant improvement. Mastery requires daily practice.",
        reversed_meaning = "Perfectionism. Monotonous work. Lack of motivation. Rekindle the pleasure in doing."
    },
    {
        id = 72, suit = suits[4], rank = ranks[9],
        name = "Nine of Pentacles",
        keywords = "Self-sufficiency, luxury, achievement, independence",
        timing = "Personal harvest",
        meaning = "Self-sufficiency. Personal luxury. Material achievement with independence. Enjoy what you have built.",
        reversed_meaning = "Financial dependence. Empty ostentation. Material insecurity. Real value lies in who you are."
    },
    {
        id = 73, suit = suits[4], rank = ranks[10],
        name = "Ten of Pentacles",
        keywords = "Wealth, legacy, family, stability",
        timing = "Permanent, long term",
        meaning = "Lasting wealth. Family legacy. Material and emotional security. Strong roots nourish the future.",
        reversed_meaning = "Loss of inheritance. Family conflicts over money. Financial instability. Rebuild the foundations."
    },
    {
        id = 74, suit = suits[4], rank = ranks[11],
        name = "Page of Pentacles",
        keywords = "Study, ambition, focus, new project",
        timing = "Slow start",
        meaning = "Applied study. New skill. Constructive ambition. Start small, dream big.",
        reversed_meaning = "Lack of focus. Slow progress. Premature abandonment. Persist in studies and work."
    },
    {
        id = 75, suit = suits[4], rank = ranks[12],
        name = "Knight of Pentacles",
        keywords = "Hard work, routine, patience, reliability",
        timing = "Step by step",
        meaning = "Hard work. Reliable routine. Patience to build. Steady steps take you far.",
        reversed_meaning = "Stagnation. Boredom. Lack of ambition. Move before inertia becomes permanent."
    },
    {
        id = 76, suit = suits[4], rank = ranks[13],
        name = "Queen of Pentacles",
        keywords = "Prosperity, practical care, home, security",
        timing = "Domestic cycle",
        meaning = "Homely prosperity. Practical care. Generous mother. Your material security sustains those you love.",
        reversed_meaning = "Neglect of home. Selfish materialism. Work-home imbalance. Take care of your nest first."
    },
    {
        id = 77, suit = suits[4], rank = ranks[14],
        name = "King of Pentacles",
        keywords = "Success, abundance, stability, business",
        timing = "Financial maturity",
        meaning = "Financial success. Prosperous leadership. Abundance with stability. Your business acumen is a gift.",
        reversed_meaning = "Miserliness. Extreme materialism. Corruption. Wealth without purpose is empty and corrupts."
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
        name = "The Rider",
        symbol = "♞",
        keywords = "News, message, visitor, swiftness",
        meaning = "News arriving. A visitor or important message. Swift movement and good tidings on the horizon."
    },
    {
        id = 2, number = 2,
        name = "The Clover",
        symbol = "♣",
        keywords = "Luck, opportunity, lightness, moment",
        meaning = "Passing luck. Fleeting opportunity. Simple joy. Enjoy the present moment with lightness."
    },
    {
        id = 3, number = 3,
        name = "The Ship",
        symbol = "⛵",
        keywords = "Travel, change, adventure, movement",
        meaning = "Travel. Change of scenery. New horizons. Venture forth, the world awaits you."
    },
    {
        id = 4, number = 4,
        name = "The House",
        symbol = "⌂",
        keywords = "Home, family, security, roots",
        meaning = "Home. Family security. Firm roots. Care for your sacred space with love and dedication."
    },
    {
        id = 5, number = 5,
        name = "The Tree",
        symbol = "♧",
        keywords = "Health, growth, nature, vitality",
        meaning = "Health. Personal growth. Connection with nature. Your roots are deep, your fruits will come."
    },
    {
        id = 6, number = 6,
        name = "The Clouds",
        symbol = "☁",
        keywords = "Confusion, uncertainty, doubt, fog",
        meaning = "Confusion. Temporary uncertainty. Lingering doubts. Clarity will come after the storm passes."
    },
    {
        id = 7, number = 7,
        name = "The Snake",
        symbol = "≈",
        keywords = "Seduction, betrayal, manipulation, cunning",
        meaning = "Seduction. Betrayal or manipulation. Beware of false promises. Wisdom lies in seeing beyond appearances."
    },
    {
        id = 8, number = 8,
        name = "The Coffin",
        symbol = "⚰",
        keywords = "Ending, transformation, loss, rebirth",
        meaning = "End of a cycle. Deep transformation. Let the past rest. The new is born from what has gone."
    },
    {
        id = 9, number = 9,
        name = "The Bouquet",
        symbol = "⚘",
        keywords = "Gift, compliment, beauty, gratitude",
        meaning = "Gift. Compliment. Recognition. The beauty of life reveals itself in small kindnesses."
    },
    {
        id = 10, number = 10,
        name = "The Scythe",
        symbol = "⚔",
        keywords = "Cut, decision, rupture, warning",
        meaning = "Necessary cut. Drastic decision. Imminent rupture. Sometimes you must cut to heal."
    },
    {
        id = 11, number = 11,
        name = "The Whip",
        symbol = "≈≈",
        keywords = "Conflict, debate, passion, repetition",
        meaning = "Conflict. Heated discussions. Intense passion. Channel energy into productive actions."
    },
    {
        id = 12, number = 12,
        name = "The Birds",
        symbol = "♫",
        keywords = "Talk, gossip, communication, nervousness",
        meaning = "Important conversations. Gossip or news. Communication in focus. Choose your words wisely."
    },
    {
        id = 13, number = 13,
        name = "The Child",
        symbol = "☺",
        keywords = "Innocence, new start, purity, playfulness",
        meaning = "Innocence. New beginning. Purity of intention. Embrace your inner child with tenderness."
    },
    {
        id = 14, number = 14,
        name = "The Fox",
        symbol = "≈≈",
        keywords = "Cunning, cleverness, deceit, adaptation",
        meaning = "Cunning. Cleverness. Beware of deception. Use your intelligence for good, not manipulation."
    },
    {
        id = 15, number = 15,
        name = "The Bear",
        symbol = "♚",
        keywords = "Strength, protection, power, authority",
        meaning = "Protective strength. Financial power. Natural authority. Leadership with generosity brings prosperity."
    },
    {
        id = 16, number = 16,
        name = "The Star",
        symbol = "★",
        keywords = "Hope, clarity, purpose, light",
        meaning = "Hope. Clarity of purpose. Follow your inner light. The universe conspires in your favor."
    },
    {
        id = 17, number = 17,
        name = "The Stork",
        symbol = "♆",
        keywords = "Positive change, renewal, transition, blessing",
        meaning = "Positive change. Renewal. Blessed transition. New energies arrive to transform your life."
    },
    {
        id = 18, number = 18,
        name = "The Dog",
        symbol = "♉",
        keywords = "Friendship, loyalty, companionship, trust",
        meaning = "Loyal friendship. Fidelity. Sincere companionship. Value those who walk beside you."
    },
    {
        id = 19, number = 19,
        name = "The Tower",
        symbol = "♜",
        keywords = "Authority, structure, isolation, institution",
        meaning = "Institutional authority. Protection. Solid structure. Build firm foundations for the future."
    },
    {
        id = 20, number = 20,
        name = "The Garden",
        symbol = "❦",
        keywords = "Social life, community, meeting, public",
        meaning = "Social life. Community. Public encounters. Open yourself to new connections and environments."
    },
    {
        id = 21, number = 21,
        name = "The Mountain",
        symbol = "▲",
        keywords = "Obstacle, challenge, blockage, persistence",
        meaning = "Obstacle. Challenge to overcome. Temporary blockage. The view from the top justifies the climb."
    },
    {
        id = 22, number = 22,
        name = "The Crossroads",
        symbol = "⛗",
        keywords = "Choice, decision, direction, alternative",
        meaning = "Important choice. Crucial decision. Multiple paths. Follow your intuition at the crossroads."
    },
    {
        id = 23, number = 23,
        name = "The Mice",
        symbol = "🐭",
        keywords = "Loss, wear, worry, corrosion",
        meaning = "Gradual loss. Wear and tear. Corroding worries. Attention to details that go unnoticed."
    },
    {
        id = 24, number = 24,
        name = "The Heart",
        symbol = "♥",
        keywords = "Love, passion, affection, romance",
        meaning = "True love. Passion. Deep affection. Open your heart without fear of being happy."
    },
    {
        id = 25, number = 25,
        name = "The Ring",
        symbol = "◎",
        keywords = "Commitment, alliance, cycle, union",
        meaning = "Commitment. Alliance. Completed cycle. Honor your pacts and promises with integrity."
    },
    {
        id = 26, number = 26,
        name = "The Book",
        symbol = "▣",
        keywords = "Secret, knowledge, study, mystery",
        meaning = "Secret. Hidden knowledge. Mystery to be revealed. The answer lies between the lines."
    },
    {
        id = 27, number = 27,
        name = "The Letter",
        symbol = "✉",
        keywords = "Message, document, communication, news",
        meaning = "Written message. Important document. Formal communication. News arriving on paper."
    },
    {
        id = 28, number = 28,
        name = "The Gentleman",
        symbol = "♂",
        keywords = "Man, partner, action, yang",
        meaning = "Influential male figure. Partner or seeker. Yang force. Action and initiative."
    },
    {
        id = 29, number = 29,
        name = "The Lady",
        symbol = "♀",
        keywords = "Woman, partner, intuition, yin",
        meaning = "Influential female figure. Partner or seeker. Yin force. Intuition and nurturing."
    },
    {
        id = 30, number = 30,
        name = "The Lilies",
        symbol = "⚜",
        keywords = "Peace, harmony, wisdom, virtue",
        meaning = "Peace. Harmony. Mature wisdom. The virtue of patience blooms in your garden."
    },
    {
        id = 31, number = 31,
        name = "The Sun",
        symbol = "☼",
        keywords = "Success, victory, energy, happiness",
        meaning = "Success. Victory. Full vital energy. Everything is illuminated, enjoy this moment."
    },
    {
        id = 32, number = 32,
        name = "The Moon",
        symbol = "☽",
        keywords = "Recognition, fame, creativity, intuition",
        meaning = "Intuition. Recognition. Fame and creativity. Your talents are recognized under moonlight."
    },
    {
        id = 33, number = 33,
        name = "The Key",
        symbol = "⚷",
        keywords = "Solution, opening, opportunity, answer",
        meaning = "Solution. Opening doors. Decisive opportunity. The answer you seek is within reach."
    },
    {
        id = 34, number = 34,
        name = "The Fish",
        symbol = "♓",
        keywords = "Abundance, finances, flow, prosperity",
        meaning = "Financial abundance. Prosperity. Flow of resources. Wealth flows like clean water."
    },
    {
        id = 35, number = 35,
        name = "The Anchor",
        symbol = "⚓",
        keywords = "Stability, security, work, steadfastness",
        meaning = "Stability. Lasting security. Steady work. Build solid foundations for tomorrow."
    },
    {
        id = 36, number = 36,
        name = "The Cross",
        symbol = "✚",
        keywords = "Destiny, trial, burden, transcendence",
        meaning = "Destiny. Necessary trial. Sacred burden. Suffering brings wisdom and transcendence."
    },
}

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                  SEÇÃO 5: PLUGIN PRINCIPAL (TarotPlugin)                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
local TarotPlugin = InputContainer:extend{
    name        = "tarot",
    fullname    = T(UI_TEXT.title),
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
end

function TarotPlugin:getTranslation(key)
    local msgid = UI_TEXT[key]
    if not msgid then
        logger.warn("tarot.koplugin: chave de tradução desconhecida:", tostring(key))
        return tostring(key)
    end
    return T(msgid)
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
    self.allow_reversed = true
    self.major_only = false
    self.use_lenormand = false
    self.hidden_card = true
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
        local name_text = T(card.name)
        
        local meaning
        if self.use_lenormand then
            meaning = T(card.meaning)
        else
            meaning = is_reversed and T(card.reversed_meaning) or (T(card.meaning))
        end
        
        table.insert(lines, string.format(self:getTranslation("saved_card_line"), i, name_text, position_text))
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
    local total_cards = #self.cards

    local card_path = self.plugin:getCardImagePath(card)
    local has_image = card_path and lfs.attributes(card_path) and lfs.attributes(card_path).mode == "file"
    local hide_name = self.plugin.use_lenormand and T.current_lang == "C" and has_image

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
        local name_text = T(card.name)
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
        meaning_text = T(card.meaning)
    else
        meaning_text = is_reversed and T(card.reversed_meaning) or (T(card.meaning))
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

    local card = self.card_list[self.current_index]

    -- 1. Nome da carta (título)
    local name_text = T(card.name)
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
        local kw = T(card.keywords)
        addInfoField(self.plugin:getTranslation("keywords_label"), kw)
    end
    -- Planet / Sign
    if card.planet then
        local planet = T(card.planet)
        addInfoField(self.plugin:getTranslation("planet_sign_label"), planet)
    end
    -- Timing
    if card.timing then
        local timing = T(card.timing)
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
    local upright_label = self.plugin:getTranslation("upright") .. ":"
    local upright_label_w = TextWidget:new{
        text      = upright_label,
        face      = Font:getFace("x_smallinfofont"),
        fgcolor   = Blitbuffer.gray(0.5),
        max_width = iw,
        alignment = "left",
    }
    local meaning_text = T(card.meaning)
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
        local reversed_label = self.plugin:getTranslation("reversed") .. ":"
        local reversed_label_w = TextWidget:new{
            text      = reversed_label,
            face      = Font:getFace("x_smallinfofont"),
            fgcolor   = Blitbuffer.gray(0.5),
            max_width = iw,
            alignment = "left",
        }
        local reversed_meaning_text = T(card.reversed_meaning)
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

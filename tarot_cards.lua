-- Dados do baralho separados do main.lua.
-- Estes textos continuam em inglês porque são os msgids usados pelo l10n.

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


return {
    suits = suits,
    ranks = ranks,
    MAJOR_ARCANA = MAJOR_ARCANA,
    MINOR_ARCANA = MINOR_ARCANA,
    FULL_DECK = FULL_DECK,
    LENORMAND_DECK = LENORMAND_DECK,
}

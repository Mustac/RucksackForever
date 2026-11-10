-- Rucksack / Darkmoon Faire: the data: the ticket turn-ins, where their items come from, the prizes, the
-- Faire's dates and Sayge's answers. Turn-ins, prizes and drop spots are from Wowhead's WoW Forever
-- database (10 Nov 2026). The addon also reads the real quest windows at the Faire and keeps what it
-- sees, so anything Forever changes later gets corrected on its own.
local RS = Rucksack
if not RS then return end
RS.Faire = RS.Faire or {}
local ns = RS.Faire -- (the Faire keeps its own little namespace inside Rucksack)
local D = {}
ns.D = D

D.FACTION = 909           -- Darkmoon Faire reputation
D.TICKET_CURRENCY = 515   -- Forever pays tickets as a currency...
D.TICKET_ITEM = 19182     -- ...and some quests still list the old ticket item

-- The four turn-in NPCs (by NPC id) and who sells the prizes
D.NPCS = {
  [14829] = "Yebb Neblegear",
  [14832] = "Kerri Hicks",
  [14841] = "Rinling",
  [14833] = "Chronos",
}
D.PRIZE_NPC = 14828 -- Gelvas Grimegate

-- tier: 1..5.  more = the repeatable "More ..." version of the same turn-in
D.TURNINS = {
  { npc = "Yebb Neblegear", what = "animal parts", list = {
    { q = 7899, title = "Small Furry Paws",      item = 5134,  n = 5,  t = 1,  lv = 1,  tier = 1 },
    { q = 7900, title = "Torn Bear Pelts",       item = 11407, n = 5,  t = 4,  lv = 10, tier = 2 },
    { q = 7901, title = "Soft Bushy Tails",      item = 4582,  n = 5,  t = 8,  lv = 20, tier = 3 },
    { q = 7902, title = "Vibrant Plumes",        item = 5117,  n = 5,  t = 12, lv = 30, tier = 4 },
    { q = 7903, title = "Evil Bat Eyes",         item = 11404, n = 10, t = 20, lv = 40, tier = 5, more = 7943 },
    { q = 8222, title = "Glowing Scorpid Blood", item = 19933, n = 10, t = 20, lv = 40, tier = 5, more = 8223 },
  } },
  { npc = "Kerri Hicks", what = "blacksmithing", list = {
    { q = 7889, title = "Coarse Weightstone",    item = 3240,  n = 10, t = 1,  lv = 1,  tier = 1 },
    { q = 7890, title = "Heavy Grinding Stone",  item = 3486,  n = 7,  t = 4,  lv = 10, tier = 2 },
    { q = 7891, title = "Green Iron Bracers",    item = 3835,  n = 3,  t = 8,  lv = 20, tier = 3 },
    { q = 7892, title = "Big Black Mace",        item = 7945,  n = 1,  t = 12, lv = 30, tier = 4 },
    { q = 7893, title = "Rituals of Strength",   item = 12644, n = 8,  t = 20, lv = 40, tier = 5, more = 7939 },
  } },
  { npc = "Rinling", what = "engineering", list = {
    { q = 7894, title = "Copper Modulator",      item = 4363,  n = 5,  t = 1,  lv = 1,  tier = 1 },
    { q = 7895, title = "Whirring Bronze Gizmo", item = 4375,  n = 7,  t = 4,  lv = 10, tier = 2 },
    { q = 7896, title = "Green Fireworks",       item = 9313,  n = 36, t = 8,  lv = 20, tier = 3 },
    { q = 7897, title = "Mechanical Repair Kits", item = 11590, n = 6, t = 12, lv = 30, tier = 4 },
    { q = 7898, title = "Thorium Widget",        item = 15994, n = 6,  t = 20, lv = 40, tier = 5, more = 7942 },
  } },
  { npc = "Chronos", what = "leatherworking", list = {
    { q = 7881, title = "Carnival Boots",        item = 2309,  n = 3,  t = 1,  lv = 1,  tier = 1 },
    { q = 7882, title = "Carnival Jerkins",      item = 2314,  n = 3,  t = 4,  lv = 10, tier = 2 },
    { q = 7883, title = "The World's Largest Gnome!", item = 5739, n = 3, t = 8, lv = 20, tier = 3 },
    { q = 7884, title = "Crocolisk Boy and the Bearded Murloc", item = 8185, n = 1, t = 12, lv = 30, tier = 4 },
    { q = 7885, title = "Armor Kits",            item = 15564, n = 8,  t = 20, lv = 40, tier = 5, more = 7941 },
  } },
}

-- Each tier's quest goes away once your Faire reputation passes this (standing, points into it).
-- Tier 5 keeps giving tickets after that through its "More ..." quest.
-- standing: 4 = Neutral, 5 = Friendly
D.TIER_CAP = {
  [1] = { 4, 500 }, [2] = { 4, 1100 }, [3] = { 4, 1700 }, [4] = { 4, 2500 }, [5] = nil,
}

-- Item names, so lines read well before the game has the item cached
D.ITEM_NAMES = {
  [5134] = "Small Furry Paw", [11407] = "Torn Bear Pelt", [4582] = "Soft Bushy Tail", [5117] = "Vibrant Plume",
  [11404] = "Evil Bat Eye", [19933] = "Glowing Scorpid Blood",
  [3240] = "Coarse Weightstone", [3486] = "Heavy Grinding Stone", [3835] = "Green Iron Bracers",
  [7945] = "Big Black Mace", [12644] = "Dense Grinding Stone",
  [4363] = "Copper Modulator", [4375] = "Whirring Bronze Gizmo", [9313] = "Green Firework",
  [11590] = "Mechanical Repair Kit", [15994] = "Thorium Widget",
  [2309] = "Embossed Leather Boots", [2314] = "Toughened Leather Armor", [5739] = "Barbaric Harness",
  [8185] = "Turtle Scale Leggings", [15564] = "Rugged Armor Kit",
}

-- Crafted items: which profession makes them. The materials get filled in from your own
-- profession window (open it once on the character that knows the recipe).
D.CRAFTED = {
  [3240] = "Blacksmithing", [3486] = "Blacksmithing", [3835] = "Blacksmithing", [7945] = "Blacksmithing",
  [12644] = "Blacksmithing",
  [4363] = "Engineering", [4375] = "Engineering", [9313] = "Engineering", [11590] = "Engineering",
  [15994] = "Engineering",
  [2309] = "Leatherworking", [2314] = "Leatherworking", [5739] = "Leatherworking", [8185] = "Leatherworking",
  [15564] = "Leatherworking",
}

-- Dropped items: good places to farm them. map = the game's map id, x/y = where most of them are.
-- pct = how often one drops (Wowhead's numbers).
D.SPOTS = {
  [5134] = { -- Small Furry Paw: cats of the Barrens and Darkshore
    { mob = "Moonstalker Runt",    lv = { 10, 17 }, map = 1439, zone = "Darkshore",   x = 40.2, y = 47.1, pct = 22 },
    { mob = "Savannah Huntress",   lv = { 11, 12 }, map = 1413, zone = "The Barrens", x = 51.9, y = 27.5, pct = 22 },
    { mob = "Moonstalker",         lv = { 14, 15 }, map = 1439, zone = "Darkshore",   x = 50.4, y = 29.5, pct = 33 },
    { mob = "Savannah Prowler",    lv = { 14, 15 }, map = 1413, zone = "The Barrens", x = 41.2, y = 24.3, pct = 21 },
    { mob = "Savannah Patriarch",  lv = { 15, 16 }, map = 1413, zone = "The Barrens", x = 45.2, y = 14.9, pct = 32 },
  },
  [11407] = { -- Torn Bear Pelt
    { mob = "Gray Bear",            lv = { 21, 22 }, map = 1424, zone = "Hillsbrad Foothills", x = 59.9, y = 30.4, pct = 8 },
    { mob = "Ashenvale Bear",       lv = { 21, 22 }, map = 1440, zone = "Ashenvale",           x = 40.9, y = 66.6, pct = 8 },
    { mob = "Elder Gray Bear",      lv = { 25, 26 }, map = 1424, zone = "Hillsbrad Foothills", x = 37.4, y = 47.5, pct = 16 },
    { mob = "Maddened Rotclaw",     lv = { 25, 26 }, map = 1437, zone = "Wetlands",            x = 61.0, y = 36.5, pct = 20 },
    { mob = "Elder Ashenvale Bear", lv = { 25, 26 }, map = 1440, zone = "Ashenvale",           x = 65.7, y = 60.2, pct = 17 },
    { mob = "Giant Ashenvale Bear", lv = { 29, 30 }, map = 1440, zone = "Ashenvale",           x = 85.4, y = 46.5, pct = 25 },
  },
  [4582] = { -- Soft Bushy Tail: wolves and coyotes
    { mob = "Plains Coyote",       lv = { 36, 37 }, map = 2548, zone = "Riverglades", x = 53.0, y = 83.9, pct = 20 },
    { mob = "Magram Bonepaw",      lv = { 37, 38 }, map = 1443, zone = "Desolace",    x = 70.9, y = 74.2, pct = 24 },
    { mob = "Feral Crag Coyote",   lv = { 37, 38 }, map = 1418, zone = "Badlands",    x = 56.8, y = 67.8, pct = 22 },
    { mob = "Mage Hunter",         lv = { 38, 39 }, map = 1443, zone = "Desolace",    x = 55.1, y = 77.1, pct = 21 },
    { mob = "Elder Crag Coyote",   lv = { 39, 40 }, map = 1418, zone = "Badlands",    x = 24.0, y = 54.0, pct = 24 },
  },
  [5117] = { -- Vibrant Plume: birds and harpies
    { mob = "Northspring Harpy",      lv = { 48, 49 }, map = 1444, zone = "Feralas",             x = 39.4, y = 13.3, pct = 29 },
    { mob = "Carrion Vulture",        lv = { 50, 52 }, map = 1422, zone = "Western Plaguelands", x = 31.9, y = 61.4, pct = 30 },
    { mob = "Carrion Vulture",        lv = { 50, 52 }, map = 1420, zone = "Tirisfal Glades",     x = 81.5, y = 68.9, pct = 30 },
    { mob = "Ironbeak Screecher",     lv = { 52, 53 }, map = 1448, zone = "Felwood",             x = 62.3, y = 19.4, pct = 23 },
    { mob = "Sky Shadow",             lv = { 55, 56 }, map = 1430, zone = "Deadwind Pass",       x = 38.7, y = 41.6, pct = 30 },
    { mob = "Winterspring Screecher", lv = { 57, 60 }, map = 1452, zone = "Winterspring",        x = 58.5, y = 21.7, pct = 24 },
  },
  [11404] = { -- Evil Bat Eye: the bats of the Plaguelands
    { mob = "Plaguebat",           lv = { 53, 55 }, map = 1423, zone = "Eastern Plaguelands", x = 31.6, y = 71.3, pct = 18 },
    { mob = "Plaguebat",           lv = { 53, 55 }, map = 1422, zone = "Western Plaguelands", x = 73.8, y = 58.6, pct = 18 },
    { mob = "Noxious Plaguebat",   lv = { 54, 56 }, map = 1423, zone = "Eastern Plaguelands", x = 71.7, y = 72.8, pct = 18 },
    { mob = "Monstrous Plaguebat", lv = { 56, 58 }, map = 1423, zone = "Eastern Plaguelands", x = 48.7, y = 25.0, pct = 20 },
  },
  [19933] = { -- Glowing Scorpid Blood
    { mob = "Venomtip Scorpid",    lv = { 52, 53 }, map = 1428, zone = "Burning Steppes", x = 86.1, y = 58.9, pct = 8 },
    { mob = "Deathlash Scorpid",   lv = { 54, 55 }, map = 1428, zone = "Burning Steppes", x = 63.8, y = 58.9, pct = 15 },
    { mob = "Stonelash Scorpid",   lv = { 54, 55 }, map = 1451, zone = "Silithus",        x = 60.2, y = 24.9, pct = 14 },
    { mob = "Stonelash Pincer",    lv = { 56, 56 }, map = 1451, zone = "Silithus",        x = 38.5, y = 55.0, pct = 22 },
    { mob = "Firetail Scorpid",    lv = { 56, 57 }, map = 1428, zone = "Burning Steppes", x = 26.8, y = 58.3, pct = 24 },
    { mob = "Stonelash Flayer",    lv = { 57, 58 }, map = 1451, zone = "Silithus",        x = 43.1, y = 72.4, pct = 23 },
  },
}

-- What Gelvas Grimegate gives for tickets (each is a quest at him)
D.PRIZES = {
  { cost = 5,    name = "Darkmoon Flower",       item = 19295, lv = 6,  note = "off-hand flower, just for fun" },
  { cost = 5,    name = "Minor Darkmoon Prize",  item = 19298, lv = 15, note = "random box" },
  { cost = 10,   name = "Last Month's Mutton",   item = 19292, lv = 25, note = "fun mace" },
  { cost = 12,   name = "Lesser Darkmoon Prize", item = 19297, lv = 30, note = "random box: gear around 35-45, bag or gems" },
  { cost = 40,   name = "Greater Darkmoon Prize", item = 19296, lv = 45, note = "random box: gear around 50-55, recipes or gems" },
  { cost = 40,   name = "Schematic: Steam Tonk Controller", lv = 45, note = "engineering recipe, new in Forever" },
  { cost = 50,   name = "Darkmoon Storage Box",  item = 19291, lv = 6,  note = "14-slot bag (unique)" },
  { cost = 50,   name = "Last Year's Mutton",    item = 19293, lv = 45, note = "fun mace" },
  { cost = 1200, name = "Orb of the Darkmoon",   item = 19426, lv = 55, note = "caster necklace (epic)" },
  { cost = 1200, name = "Amulet of the Darkmoon", item = 19491, lv = 55, note = "agility/strength necklace (epic)" },
}

-- Where and when. Starts Monday 04:00 realm time and runs one week.
D.FAIRE_SPOT = {
  Elwynn = { map = 1429, zone = "Elwynn Forest", x = 41.5, y = 69.5, near = "south of Goldshire" },
  Mulgore = { map = 1412, zone = "Mulgore", x = 36.5, y = 37.5, near = "southwest of Thunder Bluff" },
}
D.SCHEDULE = {
  { 2026, 11, 9, "Elwynn" }, { 2026, 12, 7, "Mulgore" }, { 2027, 1, 4, "Elwynn" },
  { 2027, 2, 8, "Mulgore" }, { 2027, 3, 8, "Elwynn" }, { 2027, 4, 5, "Mulgore" },
}

-- Sayge: answer to question 1, then question 2 -> the buff (lasts 2 hours)
D.SAYGE = {
  { "1", "1", "+10% damage" }, { "1", "2", "+25 magic resistance" }, { "1", "3", "+10% armor" },
  { "2", "1", "+10% spirit" }, { "2", "2", "+10% intellect" }, { "2", "3", "+25 magic resistance" },
  { "3", "1", "+10% stamina" }, { "3", "2", "+10% strength" }, { "3", "3", "+10% agility" },
  { "4", "1", "+10% intellect" }, { "4", "2", "+10% spirit" }, { "4", "3", "+10% armor" },
}

-- Darkmoon decks: eight cards each (Ace to Eight). Right-click a card with all eight to make the deck.
D.DECKS = { "Beasts", "Elementals", "Portals", "Warlords" }
D.DECK_TRINKET = { Beasts = "Darkmoon Card: Blue Dragon", Elementals = "Darkmoon Card: Maelstrom",
  Portals = "Darkmoon Card: Twisting Nether", Warlords = "Darkmoon Card: Heroism" }
D.CARDS = { "Ace", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight" }

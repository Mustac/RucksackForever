-- Rucksack / the Guide (10 Nov): what every part does, shown on the Guide page of the
-- window. Each page's "?" button opens the Guide at its own section. Plain text, easy to edit.
local _, ns = ...

local Y = "|cffffd100" -- an option's name
local G = "|cff999999" -- a side note
local R = "|r"

ns.GUIDE = {
  { key = "home", title = "|cffc8a165Ruck|r|cffffd100sack|r", text = table.concat({
    "Rucksack takes care of the two chores every adventurer repeats all day: eating and drinking, and full bags.",
    "",
    Y .. "Rations" .. R .. " picks the right food and water for you and eats and drinks with one click. No more searching your bags after every fight or eating the wrong stack.",
    Y .. "Clean-up" .. R .. " keeps a few bag slots free for you, always. When space runs low, the cheapest junk goes first (or gets sold at the next vendor), and quest items stay.",
    "",
    Y .. "Home" .. R .. " (the page that opens with /ruck) shows everything at a glance:",
    "·  " .. Y .. "Bag space" .. R .. ": free slots. The bar turns yellow, then red, as your bags fill up.",
    "·  " .. Y .. "Rations card" .. R .. ": your next food and water, how many you have, and the rules you picked.",
    "·  " .. Y .. "Clean-up card" .. R .. ": how many stacks are waiting to be deleted, what a vendor would pay you right now, the gold you've made from selling, and how many items were deleted. " .. Y .. "Delete next" .. R .. " deletes the next waiting item now.",
    "·  " .. Y .. "Right now" .. R .. ": what Rucksack is doing on its own, like keeping items your quests need.",
    "Click a card to open that tool. The sidebar on the left switches pages; shown or hidden next to each tool tells you whether its button is on screen.",
  }, "\n") },

  { key = "eat", title = "|cff66dd66Rations|r  ·  eat and drink with one click", text = table.concat({
    Y .. "The eat button" .. R .. ": a button on your screen with your food on the left and your water on the right, with how many you have. Click it to eat and drink at once. Shift-drag to move it. It turns grey in combat, because the game doesn't let you eat or drink in a fight.",
    Y .. "Macros" .. R .. ": Rucksack makes " .. Y .. "EatDrink" .. R .. ", " .. Y .. "Eat" .. R .. " and " .. Y .. "Drink" .. R .. " for all your characters (Esc > Macros > General). Drag them onto your bars; they always use your best food and water.",
    Y .. "Macros" .. R .. ": three macros shared by all your characters (/macro, General tab), kept up to date with the food and water of whoever you're playing: " .. Y .. "EatDrink" .. R .. " (like the button), " .. Y .. "Eat" .. R .. " (food only) and " .. Y .. "Drink" .. R .. " (water only). On the Rations page, drag one straight onto your bars, or click " .. Y .. "Create macros" .. R .. " to make any that are missing.",
    Y .. "Eat button" .. R .. " (click it to go through the choices): " .. Y .. "Food and water" .. R .. " (one click eats and drinks), " .. Y .. "Food only" .. R .. ", " .. Y .. "Water only" .. R .. ", or " .. Y .. "Separate" .. R .. " (two buttons side by side: click the food to eat, the water to drink).",
    "",
    Y .. "Use first" .. R .. " (which food and water it picks):",
    "·  " .. Y .. "Strongest first" .. R .. ": the one that restores the most.",
    "·  " .. Y .. "Conjured first" .. R .. ": mage food and water first.",
    "·  " .. Y .. "Save conjured" .. R .. ": everything else first; conjured food and water are kept for later.",
    "·  " .. Y .. "Random" .. R .. ": a different one each time.",
    Y .. "Food level" .. R .. ":",
    "·  " .. Y .. "Any level" .. R .. ": all food and water you're able to eat.",
    "·  " .. Y .. "Only my level" .. R .. ": only the two newest levels you can eat. Older food is used only when nothing else is left.",
    "·  " .. Y .. "Use up old food" .. R .. ": the lowest level first, so old food doesn't pile up. " .. G .. "(Not with Random.)" .. R,
    Y .. "Delete below level" .. R .. ": " .. Y .. "Off" .. R .. ", " .. Y .. "Auto" .. R .. " (food and water too weak for your level), or a level from 5 to 55. Food and water below it are deleted by Clean-up when your bags are nearly full. " .. G .. "(Clean-up must be on.)" .. R,
    Y .. "Delete all water as soon as I get it" .. R .. ": for characters with no mana. Set for each character, and on by default for warriors and rogues. Clean-up deletes the water on your next key press.",
    "",
    Y .. "The list" .. R .. ": all food and water in your bags. Click one to set " .. Y .. "Use this first" .. R .. " (always picked before the rest, never deleted) or " .. Y .. "Never use this" .. R .. ".",
    Y .. "Eat buff food when the buff is missing" .. R .. ": food that gives a buff (Well Fed) is normally kept. Ticked, the eat button uses it first whenever you're not Well Fed, then goes back to plain food.",
    Y .. "Alert me while I eat for the buff" .. R .. ": while you eat buff food, the middle of the screen says \"don't move\" with a 10-second countdown, then \"Well Fed! You can move now.\" " .. Y .. "Move the alert" .. R .. " lets you drag it anywhere.",
    G .. "Never eaten: buff food (unless the box above is ticked), food above your level, and anything on your Clean-up list." .. R,
  }, "\n") },

  { key = "del", title = "|cffff5555Clean-up|r  ·  delete what you don't need", text = table.concat({
    "Clean-up is like a little bag helper. You pick how many free slots you always want to keep, say 4. As soon as you drop below that, it throws out your " .. Y .. "cheapest junk first" .. R .. ", the stuff worth the least, until you're back to 4 free slots. No more \"Inventory is full\" in the middle of a dungeon.",
    "Grey trash goes by itself. Anything else only goes if you told it to: click " .. Y .. "Always" .. R .. " when you delete something once, and Clean-up remembers it. Passing a vendor? It " .. Y .. "sells" .. R .. " the junk for gold instead. And it never touches what your quests still need: if a quest wants 8 wolf pelts, it keeps 8.",
    "",
    Y .. "Always / Yes / No" .. R .. ": when you destroy an item, the game's box gets an " .. Y .. "Always" .. R .. " button. Always deletes it now and puts it on your list: from then on it's deleted whenever you pick it up and your bags are nearly full. Yes deletes it just this once. If the item is used for something (a quest, a Darkmoon turn-in, an unread scroll, your next food or water, or it's rare or better) the box tells you what for and asks once more: " .. Y .. "Delete anyway" .. R .. " or No.",
    Y .. "Why a key press" .. R .. ": the game only lets an addon delete an item during a click or a key press. So Clean-up deletes one waiting item each time you press a key or click the trash button. Never in combat.",
    "",
    Y .. "Delete on any key press" .. R .. ": on, any key you press out of combat deletes the next waiting item. Off, only the trash button or the RuckDelete macro does.",
    Y .. "Chat message when deleting" .. R .. ": prints a line in chat for each item deleted.",
    Y .. "Always show the trash button" .. R .. ": the trash button normally shows only when something is waiting. Click it to delete the next item; Shift-drag to move it.",
    Y .. "Keep empty slots" .. R .. ": how many free bag slots Clean-up keeps for you. Drop below it and the cheapest stack goes first.",
    Y .. "Goes by itself" .. R .. ": grey items; white weapons and armour your class can't wear, or that are worse than what you wear in that slot (less armour; weapons: less damage per second); and soulbound gear of any quality your class can't use. Better gear, gear for an empty slot, and " .. Y .. "profession tools" .. R .. " (Skinning Knife, Mining Pick, fishing poles, enchanting rods...) always stay. Everything else goes only once you delete it yourself with Always. All of it is sold at a vendor, or deleted when your bags are nearly full, cheapest first.",
    Y .. "Don't delete anything worth more than" .. R .. ": a stack worth more than this (1g to start) isn't deleted. Clean-up stops and tells you; click the trash button to choose " .. Y .. "Delete it" .. R .. ", " .. Y .. "Keep it" .. R .. " or " .. Y .. "Not now" .. R .. ". It goes on by itself once you free up a bag slot. Selling isn't limited.",
    Y .. "RuckDelete macro" .. R .. ": put it on your bars. It does the same as clicking the trash button: throws the first item away now, full bags or not, and shows that item's icon and tooltip.",
    Y .. "Drop an item here" .. R .. ": drag an item onto the box to put it on your list without deleting it.",
    "",
    Y .. "Each item" .. R .. " (click it in the list): " .. Y .. "When my bags are nearly full" .. R .. " or " .. Y .. "As soon as I get it" .. R .. ", and " .. Y .. "Stop deleting it" .. R .. ". An item caught by a rule (junk, or a Rations rule) has a " .. Y .. "Keep" .. R .. " button in the list.",
    Y .. "Quest items" .. R .. ": Clean-up keeps exactly the amount your current quests still need and deletes only the extra. Items that start a quest are kept.",
    Y .. "The list" .. R .. ": search by name, then pick " .. Y .. "Everything" .. R .. ", " .. Y .. "My list" .. R .. " (the white and better items you chose; " .. Y .. "Remove" .. R .. " takes one off), " .. Y .. "In my bags" .. R .. " or " .. Y .. "Deleted" .. R .. " (the last 100 items deleted: how many, when and why), and filter by quality.",
  }, "\n") },

  { key = "sell", title = "|cffffd100Selling|r  ·  gold instead of deleting", text = table.concat({
    "When you open a vendor, Rucksack sells for you, a few items at a time. A line in chat says what it sold and for how much.",
    Y .. "At a vendor: sell my Clean-up items for gold" .. R .. " " .. G .. "(on by default)" .. R .. ": everything Clean-up would delete is sold instead, if you reach a vendor before your bags fill up. Deleting pays nothing; selling pays gold, and you can buy it back from the vendor if you made a mistake.",
    Y .. "Sell grey items" .. R .. ": every grey item with a price is sold.",
    Y .. "Sell soulbound gear I can't use" .. R .. ": soulbound weapons your class can never use (by WoW Forever's weapon trainers), and shields and relics that aren't for your class. Tick " .. Y .. "Cloth, Leather, Mail or Plate" .. R .. " to also sell soulbound armor of types this character never wears. Only ever sold, never deleted. Up to blue; epics, cloaks and unbound gear are kept.",
    G .. "Never sold: amounts your quests need, items set to Keep, items with no vendor price, and blue or better unless you put them on your list yourself." .. R,
    Y .. "Hold Shift" .. R .. " while opening the vendor to sell nothing that time. " .. G .. "(The vendor can buy back only your last 12 items.)" .. R,
    "Home shows what a vendor would pay right now and the gold you've made so far.",
  }, "\n") },

  { key = "pocket", title = "|cffffd100The Pocket|r  ·  a small window that stays on screen", text = table.concat({
    "What it shows: " .. Y .. "Bags" .. R .. " (free slots), " .. Y .. "Vendor" .. R .. " (what a vendor would pay right now; hover it for the list), " .. Y .. "Food" .. R .. ", " .. Y .. "Water" .. R .. ", " .. Y .. "Next to delete" .. R .. " (what Clean-up throws out next, and how many are waiting), your Darkmoon " .. Y .. "Prize" .. R .. " (or tickets) and your " .. Y .. "Scrolls" .. R .. ".",
    Y .. "Four styles" .. R .. " (Settings): " .. Y .. "Rows" .. R .. " (one short line each), " .. Y .. "Tiles" .. R .. " (big numbers in a grid, bag space on top, the prize as a strip), " .. Y .. "Strip" .. R .. " (just icons and numbers in one bar) and " .. Y .. "Ledger" .. R .. " (text only).",
    "A red edge: something is waiting to be deleted. Green: your prize or tickets are ready, or scrolls you can read.",
    "Click an entry to open its page. Shift-click " .. Y .. "Next to delete" .. R .. " to delete it now. " .. Y .. "Right-click" .. R .. " anywhere on it: Settings. Drag it to move it.",
    "Show or hide it: the box on Home or Settings, or right-click the minimap button.",
    "On Settings: " .. Y .. "Lock it in place" .. R .. ", " .. Y .. "Hide it in combat" .. R .. ", " .. Y .. "Size" .. R .. ", " .. Y .. "Style" .. R .. ", and which " .. Y .. "Lines" .. R .. " to show.",
  }, "\n") },

  { key = "faire", title = "|cffb48cffDarkmoon Faire|r  ·  tickets, turn-ins and prizes", text = table.concat({
    "Once a month the Darkmoon Faire comes to Elwynn Forest or Mulgore. Four of its people trade " .. Y .. "prize tickets" .. R .. " for things you bring them: animal parts, and blacksmithing, engineering and leatherworking items. Gelvas Grimegate swaps the tickets for prizes, like a 14-slot bag for 50.",
    "",
    Y .. "Turn-ins" .. R .. ": every ticket quest, how many items it wants, how many you have (the bank too, once you've opened it) and the tickets it gives. " .. Y .. "Ready" .. R .. " means you can hand it in now. " .. Y .. "Closed" .. R .. " means your Faire reputation is past that quest's limit: bring higher ones.",
    Y .. "Where to get it" .. R .. ": click a turn-in. Animal parts list good places to farm, closest to your level first. Click one to " .. Y .. "pin it on your map" .. R .. " (shift-click pins them all). Crafted items show their profession, and their materials once you open that profession's window.",
    Y .. "Prizes" .. R .. ": click a prize to " .. Y .. "track" .. R .. " it. The Pocket's Tickets line and Home show it as 37 / 50. Want it on screen too? Turn on " .. Y .. "Button on screen" .. R .. " (Faire & Sayge tab): a little card that fills up and glows gold when you have enough.",
    Y .. "Decks" .. R .. ": which Darkmoon cards you have, Ace to Eight, for all four decks.",
    Y .. "Faire & Sayge" .. R .. ": when and where the Faire is, Sayge's answers (1 then 1 = +10% damage) and the settings.",
    "",
    Y .. "Quick turn-ins" .. R .. ": talk to Yebb, Kerri, Rinling or Chronos and the quests you have items for are handed in for you. Hold Shift to do it yourself. Prizes are never bought for you.",
    Y .. "Keep Darkmoon turn-in items" .. R .. ": Clean-up never deletes or sells them, even the grey ones like Small Furry Paws.",
    Y .. "Tooltips" .. R .. ": turn-in items say who wants them and how many tickets they give.",
  }, "\n") },

  { key = "scrolls", title = "|cff69ccf0Scrolls|r  ·  mages: decipher with one click", text = table.concat({
    "Monsters everywhere drop strange scrolls: " .. Y .. "Scroll:" .. R .. " and then words in capitals, like Scroll: UPDOG. A mage reads them with " .. Y .. "Comprehend Scroll" .. R .. " (from the mage trainer at level 6) and gets a useful scroll out: weapon imbues, familiars, Cryoblast and more. Each one read raises your " .. Y .. "Comprehension" .. R .. " skill.",
    "",
    Y .. "The scroll button" .. R .. ": shows how many scrolls you carry. One click reads the next one (5 seconds, stand still). Shift-drag to move it. The " .. Y .. "Decipher" .. R .. " macro does the same from your bars.",
    Y .. "Which one" .. R .. ": the hardest scroll your skill allows. Each needs some skill (1, 15, 50 or 175, shown on the scroll). Reading one above your skill turns you into a sheep for 8 seconds, so those are skipped until you're good enough.",
    Y .. "In a fight" .. R .. ": the button greys out. Read them somewhere safe.",
    Y .. "Clean-up keeps them" .. R .. ": scrolls sell for coppers, so Clean-up would throw them out first. They're kept (you can untick it). Other classes keep them too, to send to your mage.",
  }, "\n") },

  { key = "general", title = "|cffffd100Settings and commands|r", text = table.concat({
    Y .. "Minimap button" .. R .. ": left-click opens Rucksack, right-click shows or hides the Pocket, drag moves it around the minimap.",
    Y .. "Open Rucksack" .. R .. ": a key that opens and closes the window.",
    Y .. "Modules" .. R .. ": Rucksack comes with all its parts (Rations, Clean-up, Darkmoon Faire, Scrolls) but only loads the ones you turn on. Click a card to turn it on or off, then press Apply (Cancel puts them back). New ones load right away; ones you turned off need a reload, and then they aren't loaded at all. Each character has its own choice, and Scrolls turns itself on for mages only.",
    "",
    Y .. "/ruck" .. R .. " or " .. Y .. "/rucksack" .. R .. ": open the window. Everything else is in here.",
    "",
    G .. "Keys can also be set in the game's Key Bindings, under Rucksack." .. R,
  }, "\n") },
}

-- Rucksack Forever / the Guide (10 Nov): what every part does, shown on the Guide page of the
-- window. Each page's "?" button opens the Guide at its own section. Plain text, easy to edit.
local _, ns = ...

local Y = "|cffffd100" -- an option's name
local G = "|cff999999" -- a side note
local R = "|r"

ns.GUIDE = {
  { key = "home", title = "|cffc8a165Ruck|r|cffffd100sack|r Forever", text = table.concat({
    "Rucksack Forever takes care of the two chores every adventurer repeats all day: eating and drinking, and full bags.",
    "",
    Y .. "Rations" .. R .. " picks the right food and water for you and eats and drinks with one click. No more searching your bags after every fight or eating the wrong stack.",
    Y .. "Clean-up" .. R .. " keeps a few bag slots free for you, always. When space runs low, the cheapest junk goes first (or gets sold at the next vendor), and quest items stay.",
    "",
    Y .. "Home" .. R .. " (the page that opens with /ruck) shows everything at a glance:",
    "·  " .. Y .. "Bag space" .. R .. ": free slots. The bar turns yellow, then red, as your bags fill up.",
    "·  " .. Y .. "Rations card" .. R .. ": your next food and water, how many you have, and the rules you picked.",
    "·  " .. Y .. "Clean-up card" .. R .. ": how many stacks are waiting to be deleted, what a vendor would pay you right now, the gold you've made from selling, and how many items were deleted. " .. Y .. "Delete next" .. R .. " deletes the next waiting item now.",
    "·  " .. Y .. "Right now" .. R .. ": what Rucksack is doing on its own, like keeping items your quests need.",
    "Click a card to open that tool. The sidebar on the left switches pages; the on/off next to Rations and Clean-up shows whether they're turned on.",
  }, "\n") },

  { key = "eat", title = "|cff66dd66Rations|r  ·  eat and drink with one click", text = table.concat({
    Y .. "The eat button" .. R .. ": a button on your screen with your food on the left and your water on the right, with how many you have. Click it (or press its key) to eat and drink at once. Shift-drag to move it. It turns grey in combat, because the game doesn't let you eat or drink in a fight.",
    Y .. "Keys" .. R .. ": " .. Y .. "Eat and drink" .. R .. ", " .. Y .. "Food only" .. R .. " and " .. Y .. "Water only" .. R .. " (on the Rations page, or the game's Key Bindings under Rucksack). They work in both modes.",
    Y .. "Macros" .. R .. ": three macros shared by all your characters (/macro, General tab), kept up to date with the food and water of whoever you're playing: " .. Y .. "EatDrink" .. R .. " (like the button), " .. Y .. "Eat" .. R .. " (food only) and " .. Y .. "Drink" .. R .. " (water only). Put them on any action bar.",
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
    Y .. "Always / Yes / No" .. R .. ": when you destroy an item, the game's box gets an " .. Y .. "Always" .. R .. " button. Always deletes it now and puts it on your list: from then on it's deleted whenever you pick it up and your bags are nearly full. Yes deletes it just this once.",
    Y .. "Why a key press" .. R .. ": the game only lets an addon delete an item during a click or a key press. So Clean-up deletes one waiting item each time you press a key or click the trash button. Never in combat.",
    "",
    Y .. "Delete on any key press" .. R .. ": on, any key you press out of combat deletes the next waiting item. Off, only the trash button or its key does.",
    Y .. "Chat message when deleting" .. R .. ": prints a line in chat for each item deleted.",
    Y .. "Always show the trash button" .. R .. ": the trash button normally shows only when something is waiting. Click it to delete the next item; Shift-drag to move it.",
    Y .. "Bags nearly full" .. R .. ": the number of free slots below which Clean-up starts deleting. The cheapest stack goes first.",
    Y .. "Also delete everything up to" .. R .. ": a quality (grey, white or green). Every item of that quality or lower goes too, except items you set to Keep. It starts at " .. Y .. "Trash" .. R .. ": grey items go by themselves, so " .. Y .. "My list" .. R .. " is only the white and better items you chose.",
    Y .. "Delete next item" .. R .. ": a key that deletes the next waiting item right away, full bags or not.",
    Y .. "Drop an item here" .. R .. ": drag an item onto the box to put it on your list without deleting it.",
    "",
    Y .. "Each item" .. R .. " (click it in the list): " .. Y .. "When my bags are nearly full" .. R .. " or " .. Y .. "As soon as I get it" .. R .. ", and " .. Y .. "Stop deleting it" .. R .. ". An item caught by a rule (its quality, or a Rations rule) has a " .. Y .. "Keep" .. R .. " button in the list.",
    Y .. "Quest items" .. R .. ": Clean-up keeps exactly the amount your current quests still need and deletes only the extra. Items that start a quest are kept.",
    Y .. "The list" .. R .. ": search by name, then pick " .. Y .. "Everything" .. R .. ", " .. Y .. "My list" .. R .. " (the white and better items you chose; " .. Y .. "Remove" .. R .. " takes one off), " .. Y .. "In my bags" .. R .. " or " .. Y .. "Deleted" .. R .. " (the last 100 items deleted: how many, when and why), and filter by quality.",
  }, "\n") },

  { key = "sell", title = "|cffffd100Selling|r  ·  gold instead of deleting", text = table.concat({
    "When you open a vendor, Rucksack sells for you, a few items at a time. A line in chat says what it sold and for how much.",
    Y .. "At a vendor: sell my Clean-up items for gold" .. R .. " " .. G .. "(on by default)" .. R .. ": everything Clean-up would delete is sold instead, if you reach a vendor before your bags fill up. Deleting pays nothing; selling pays gold, and you can buy it back from the vendor if you made a mistake.",
    Y .. "Sell grey items" .. R .. ": every grey item with a price is sold.",
    G .. "Never sold: amounts your quests need, items set to Keep, items with no vendor price, and blue or better unless you put them on your list yourself." .. R,
    Y .. "Hold Shift" .. R .. " while opening the vendor to sell nothing that time. " .. G .. "(The vendor can buy back only your last 12 items.)" .. R,
    "Home shows what a vendor would pay right now and the gold you've made so far.",
  }, "\n") },

  { key = "pocket", title = "|cffffd100The Pocket|r  ·  a small window that stays on screen", text = table.concat({
    "Five lines: " .. Y .. "Bags" .. R .. " (free slots), " .. Y .. "Vendor" .. R .. " (what a vendor would pay right now; hover it for the list), " .. Y .. "Food" .. R .. ", " .. Y .. "Water" .. R .. " and " .. Y .. "Delete" .. R .. " (stacks waiting and the next item).",
    "Click a line to open its page. Shift-click " .. Y .. "Delete" .. R .. " to delete the next item now. " .. Y .. "Right-click" .. R .. " anywhere on it: Settings. Drag it to move it.",
    Y .. "Clean-up on / off" .. R .. " (top of the Pocket): turns Clean-up on or off with one click. Off: nothing is deleted or sold until you turn it back on; your list stays.",
    "Show or hide it: " .. Y .. "/ruck pocket" .. R .. ", the box on Home or Settings, or right-click the minimap button.",
    "On Settings: " .. Y .. "Lock it in place" .. R .. ", " .. Y .. "Hide it in combat" .. R .. ", " .. Y .. "Size" .. R .. ", and which " .. Y .. "Lines" .. R .. " to show.",
  }, "\n") },

  { key = "general", title = "|cffffd100Settings and commands|r", text = table.concat({
    Y .. "Minimap button" .. R .. ": left-click opens Rucksack, right-click shows or hides the Pocket, drag moves it around the minimap.",
    Y .. "Open Rucksack" .. R .. ": a key that opens and closes the window.",
    Y .. "Tools" .. R .. ": turn Rations or Clean-up off completely.",
    "",
    Y .. "/ruck" .. R .. " or " .. Y .. "/rucksack" .. R .. ": open the window",
    Y .. "/rations" .. R .. " " .. G .. "(or /eatdrink)" .. R .. ": the Rations page",
    Y .. "/cleanup" .. R .. " " .. G .. "(or /adel)" .. R .. ": the Clean-up page",
    Y .. "/ruck pocket" .. R .. ": show or hide the Pocket",
    Y .. "/ruck settings" .. R .. ": the Settings page",
    Y .. "/ruck minimap" .. R .. ": show or hide the minimap button",
    "",
    G .. "Keys can also be set in the game's Key Bindings, under Rucksack." .. R,
  }, "\n") },
}

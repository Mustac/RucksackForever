# Rucksack 1.7.5

### New
- **Buff food on or off in one click:** a small tick on the eat button, and on the Pocket's food. The Pocket shows "no buff" (red) or "Well Fed" (green) while buff food is on.
- **Remind me when I'm not Well Fed** (Rations page, per character): Alert (big text, untick under it to stop it), Text (a line under the eat button), Icon (your buff food next to the eat button: click it to eat) or Off. Never in a fight, while you eat, or without buff food in your bags.

### Changed
- **Eat button choice:** Food and water, Food only, Water only and Separate are four buttons side by side; the one in use is lit.
- The sidebar no longer says "shown" or "hidden": every tool in it is on. Each tool's page still has its "Show button" box.
- Clearer words: Home says "2 can go · first: ..." and the Clean-up page explains the rules (white gear you can't wear or that's worse than yours; profession tools stay).

# Rucksack 1.7.4

### New
- **Pocket styles:** pick Rows, Tiles, Strip or Ledger in Settings. Strip can go across or down, with how many in each row or column, and a word under each number. Right-click the Pocket for its settings (no more buttons on it).
- **Delete limit:** Clean-up never deletes anything worth more than your limit (1g to start). It stops, tells you, and lets you choose: Delete it, Keep it or Not now. It goes on by itself once you free a bag slot.
- **Warning before deleting something useful:** when you delete an item by hand that a quest needs, a Darkmoon turn-in, an unread scroll, your next food or water, a profession tool, or anything rare or better, it tells you what it's for and asks once more.
- **Create macros** on the Rations page: makes any missing EatDrink, Eat or Drink macro, and you can drag them straight onto your bars from there.
- Right-click the eat button or the scroll button: opens its page.

### Changed
- **What Clean-up throws out by itself:** grey items; white weapons and armour your class can't wear or that are worse than what you wear; and soulbound gear of any quality your class can't use. The "delete everything up to" quality choice is gone.
- **Profession tools** (Skinning Knife, Mining Pick, fishing poles, enchanting rods...) are never deleted or sold.
- **The trash button** shows your free slots against your setting, the first item to go and what it's worth. It's red only when it really deletes on your next key press. Hover it for everything that can go. Clicking it, or the RuckDelete macro, throws the first one away now; the macro shows that item too.
- Grey items can't be added to the list by hand: they're on it already.
- **Settings > Modules** are cards now. Module choices are per character, and Scrolls turns itself on for mages and off for everyone else.
- Modules that aren't loaded no longer show in the sidebar or in the Pocket's line choices.
- Only `/ruck` and `/rucksack` now; everything else is in the window.
- The Clean-up on/off switch on the Pocket is gone: turn Clean-up off in Settings > Modules.

### Fixed
- The Pocket's prize line updates as soon as you pick a prize (it needed a reload).

# Rucksack 1.7.3

### Changed
- **Settings > Modules:** ticking and unticking no longer happens one by one. Pick what you want, then press **Apply** (bottom right) and everything changes at once: new modules load right away, and if you turned any off you get one reload prompt. **Cancel** puts your ticks back.
- Each tool page's top box is now **Show button**: it only shows or hides that tool's button on screen. Turning a tool really on or off is done in Settings > Modules.
- The sidebar now says shown or hidden next to each tool.

# Rucksack 1.7.2

### Fixed
- **Scrolls:** the scroll button said your skill was too low when the Skills list had "Secondary Skills" folded shut. It now finds your Comprehension skill either way, and if it really can't, it doesn't hold any scroll back (it reads the easiest first).

# Rucksack 1.7.1

### Changed
- The on-screen Darkmoon ticket button / prize card is off by default: the Pocket's Tickets line and Home already show your tracked prize (37 / 50). Turn it back on with "Button on screen" on the Faire & Sayge tab, or /faire button.

### Fixed
- Settings: the Pocket's Lines checkboxes now sit four to a row instead of running off the page.

# Rucksack 1.7

### New
- **Modules:** Rucksack now comes in parts: Rations, Clean-up, Darkmoon Faire and Scrolls. Pick which ones load in **Settings > Modules**. Ticking one loads it right away; unticking one needs a reload, and then it isn't loaded at all (no memory, no work). "Just for this character" lets a character have its own choice. Your settings carry over.
- **Darkmoon Faire module:** every ticket turn-in with how many items you have and the tickets it gives; where to farm each animal part, closest to your level first, and one click pins it on your map; crafted items show their profession and materials. Prizes as tiles: click one to track it, and an on-screen card shows the prize filling up (37 / 50) and glows when you have enough. Darkmoon deck checklist, Faire dates and Sayge's answers, item tooltips and quick turn-ins at the Faire NPCs. /faire
- **Scrolls module (mages):** one click deciphers your next scroll with Comprehend Scroll, only ones your Comprehension skill allows (no sheep). A scroll button with a counter, a Decipher macro, and a page with your skill and every scroll in your bags. /scrolls
- **Clean-up keeps** Darkmoon turn-in items and undeciphered scrolls (both can be switched off).
- **Pocket:** new Tickets and Scrolls lines.

### Changed
- The addon is called just **Rucksack** in the game.

# Rucksack Forever 1.6

### New
- **Pocket:** a spyglass at the top of the Pocket lets you tick which lines it shows: Bags, Vendor, Food, Water, Cheapest item.
- **RuckDelete macro:** made for all your characters (General tab of /macro). Put it on your bars and one click deletes the next waiting item.

### Changed
- "Bags nearly full when under" is now **Keep empty slots**.
- The eating alert follows buff food: with "Eat buff food when the buff is missing" off, the alert and "Move the alert" are greyed out.
- Closing Rucksack while moving the alert locks it where it is.
- The "Set key" buttons for eat and drink, food only, water only and delete next item are gone: drag the EatDrink, Eat, Drink or RuckDelete macro onto your bars instead. Keys you already set keep working (Esc > Key Bindings > Rucksack).
- Pocket lines are renamed to match: Bags, Vendor, Food, Water, Cheapest item.

# Rucksack Forever 1.5

### New
- **Sell soulbound gear I can't use** (Clean-up page, on by default): at a vendor, soulbound weapons your class can never use in WoW Forever are sold, plus shields and relics that aren't for your class. Weapons you can learn but haven't trained yet are kept.
- **Also sell soulbound armor:** tick Cloth, Leather, Mail or Plate for armor types this character never wears (set per character).
- This gear is only ever sold, never deleted, even with full bags. Up to blue; epics, cloaks and unbound gear are kept.
- The Pocket's vendor list says why each item sells ("can't use: One-Handed Axes").

# Rucksack Forever 1.4

### New
- **Eat buff food when the buff is missing:** tick it on the Rations page and the eat button uses your buff food first while you're not Well Fed, then goes back to plain food.
- **Eating alert:** while you eat buff food, the middle of the screen says "don't move" with a 10-second countdown, then "Well Fed! You can move now." You can turn it off or drag it anywhere ("Move the alert").

### Changed
- **Eat button:** one button now cycles through Food and water, Food only, Water only and Separate (two buttons side by side). The separate Together/Separate row is gone.
- **Clean-up** is explained in plain words in the Guide and the "Bags nearly full" tip.

### Fixed
- The eat button's tooltip now says what a click does for the choice you picked.

# Rucksack Forever 1.3.1

- **Guide:** the first page now explains what Rucksack Forever is for: Rations picks your food and water and eats with one click; Clean-up keeps your bags free of junk without touching what your quests need.

# Rucksack Forever 1.3

First release on CurseForge.

- **Rations:** one-click eating and drinking; Together or Separate buttons; Use first, Food level and Delete below level; delete all water as soon as you get it (warriors and rogues); EatDrink, Eat and Drink macros shared by all characters.
- **Clean-up:** Always / Yes / No delete box; grey trash goes by itself; keeps exactly what your quests need; sells at vendors; search; history of the last 100 deletes.
- **Home**, the **Pocket** info window with a Clean-up on/off switch, an in-game **Guide**, and hover help on every option.

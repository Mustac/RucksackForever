# Rucksack 1.9.14

### Fixed
- **Loot stays stacked** while Haul runs. No more single pieces all over your bag. The ones from before are stacked back by themselves, a second or so each.
- **Track bars** no longer get stuck acting like you hold an item after you sold or destroyed it.
- If the game blocks Rucksack from opening clams and pouches by itself, it now remembers that and shows the **Open** button, instead of trying again every login.

# Rucksack 1.9.13

### New, and already on
- **Haul** shows what your loot is worth and your gold per hour. Open it with the Haul button under Rucksack's icon in your bag. In Haul:
  - **Sort loot:** loot a vendor pays more for goes on Sell.
  - **Check bag:** marks what's better sold to a vendor.
  - **Reset:** starts the count from zero.
  - Auction prices come from one of these addons: **Auctionator, auxForever, AHledger, GoldScout, CraftProfit or Hammerprice**. Without one of them, Haul and the gold coin don't work.
- **Gold coin** on items a vendor pays more for than the auction house (after its cut). At a vendor, one button sells them all.
- **Track bars:** keep items on screen with how many you carry, click to use them, drag one off to take it off. Up to 5, from the tool row.
- **Armour sets** from the game's equipment manager: their own group, a red border, never sold, deleted or disenchanted.
- **Quest marks:** ! starts a quest, a gold border means a quest item, !? means a quest of yours needs it.
- **Tool row** under Rucksack's icon: Haul, Track, Restock, Hidden. **Look** goes Rows, Packed, One bag.
- The Once box has sell and delete ticks, like Always.

### Better
- Items no longer jump around while auction house addons scan.
- Drag an item and the others make room; it lands right where you drop it.
- Food, water and potions are together in Consumables.
- Restock and Hidden are simpler.
- Profession tools you don't need can be sold.
- Your other characters' bags and gold are remembered properly.
- Learning a recipe isn't blocked any more.

# Rucksack 1.9.12

### Changed
- **One bag moves no reagents by itself:** reagents stay where you put them (Groups still moves them into the reagent bag).
- **The reagent bag's slots are green** in One bag, so you can see which slots are the reagent bag.

# Rucksack 1.9.11

### New
- **Take a bag out even when it's full:** click (or drag) a bag in the bags row. Rucksack moves its items into your other bags first (and into the bank while it's open), then puts the bag in a free slot. Not enough room? It tells you how many slots are missing and offers to delete junk.

# Rucksack 1.9.10

### Changed
- **One bag never sorts by itself:** your items stay in the slots you put them in, also after switching to Groups and back. Click **Tidy** to sort them once. The Free / Tidy switch and the "Sort" setting are gone. Groups is still sorted for you, as before.

# Rucksack 1.9.9

### New
- **Swap a bag that still has items:** drop the new bag on the old one in the bags row. Rucksack moves the old bag's items into your other bags first (and into the bank while it's open), then puts the new bag in. Not enough room? It tells you how many slots are missing and offers to delete junk or use an empty bag slot.
- **Why an item isn't sold:** its tooltip says so when a quest you have still needs it.

### Fixed
- **Items in the reagent bag weren't sold or deleted:** selling, deleting and the vendor's "not sold" lines never looked in the reagent bag. They do now.
- An error in Free mode about GetItemInfo (an empty slot).

# Rucksack 1.9.8

### Changed
- **"A new version is out" only for chosen releases:** Rucksack no longer tells other players about every new version, only about releases picked for it. None is picked right now. Your "Tell me when a new version is out" setting stays.

# Rucksack 1.9.7

### Changed
- **Each special bag is its own group** in the bag, with how full it is: "Soul bag 12/16". What's inside shows there, not in Everything else.
- **One tile or slot by slot, for each kind of bag:** click its colour at the bottom of the Bags page. "One tile per item" (the default) shows all your shards as one tile with the total; untick it to see each slot and the empty ones.

# Rucksack 1.9.6

### Fixed
- **Soul bag in the reagent bag slot:** on Forever a warlock can put the soul bag there, and Rucksack took it for a reagent bag. "Delete extra soul shards" stayed greyed out, shards weren't sorted into it, and Rucksack tried to put reagents in it ("only soul shards can go in that"). A soul bag is now recognised in any slot, and no reagents are moved into it.

# Rucksack 1.9.5

### Fixed
- **Soul bags (and other special bags) not recognised:** some bags were treated as ordinary bags, so "Delete extra soul shards" stayed greyed out and shards weren't sorted into the soul bag. Rucksack now also recognises a special bag by the bag itself.

# Rucksack 1.9.4

### Fixed
- **"Only soul shards can go in that" at login:** sorting into special bags tried to put a spare bag (a soul pouch, a quiver) into the matching special bag. Bags are never moved into special bags now, and if the game ever refuses a move, Rucksack stops trying that item.

# Rucksack 1.9.3

### New
- **Delete extra soul shards:** once your soul bag is full, a Soul Shard that lands in another bag is deleted (on your next key press). Shards a quest needs stay. A switch on the Bags page, on to start; greyed out while you don't wear a soul bag.

### Changed
- **Hidden and Restock sit right against the bag** when nothing is in the way. They only move further out when the sell / delete / bank windows are at the top right, or too close below them.

# Rucksack 1.9.2

### New
- **Pin the bag window:** a pushpin, first on the left of the bags row. Pinned, the window can't be dragged by accident; click it again to move it.
- **Your characters:** the characters button lists you and your other characters. Point at one and pick **Inventory** or **Bank**.
- **Clearer quest marks:** a big yellow **!** on quest items (the game's small yellow square is gone), and **!?** on ordinary items one of your quests needs.

### Changed
- The delete question ("Delete Linen Cloth x14?") is a smaller box, as wide as its text, with Delete and Cancel side by side.

# Rucksack 1.9.1

### New
- **Special bags:** herb, soul, mining, enchanting, leatherworking, engineering, gem and inscription bags, quivers and ammo pouches.
  - Their slots are tinted with a thin border in that bag's colour, and their empty slots are their own group, named after the bag ("Empty · Herb bag").
  - **Items sort into them by themselves:** anything that fits a special bag with room moves there (half-full stacks first). Special bags come before the reagent bag. "Sort into special bags" on the Bags page (on to start) replaces the arrows-only switch.
  - **Pick the colours:** "Special bag colours" at the bottom of the Bags page, a square per kind with a small palette and Default. "Colour their slots" turns the tint off.

# Rucksack 1.9.0

**Rucksack is now a bag addon.** Selling, deleting and sending to the bank are part of Rucksack's own bag.

### New
- **Bags and Clean-up are one module:** the **Bags** card in Settings > Modules is the bag with everything built in. If you had Clean-up or Bags on, your bag is on now. Rations, Darkmoon Faire and Scrolls stay as extras.
- **A one-time message** says so when you log in. If another bag addon is running (Bagnon, Baganator...), a button turns it off and reloads.
- **Quiver window:** while you wear a quiver or ammo pouch, a fourth window beside the bag (under Send to bank) shows it slot by slot, with how many arrows you have. Drop ammo on it to put it in.
- **Arrows and bullets move into your quiver** by themselves when there's room (half-full stacks first). Never in a fight. Both quiver switches are on the Bags page, on to start.

### Changed
- **"Delete items worth up to"** replaces "Do not sell above". The slider is now your delete limit (10 silver to 5 gold, or no limit, the same setting as on the Clean-up page): a stack worth more is never thrown away by itself, only sold at the next vendor. Selling has no limit any more.
- **The bag draws above other windows,** like quest trackers and health bars from other addons.

# Rucksack 1.8.8

### Changed
- **Destroying an item** (with Bags on) is one simple question now: "Delete Linen Cloth x14?", with what it's needed for underneath (a quest, a Darkmoon turn-in...) when it is. **Delete** or **Cancel**, no second question. Your lists stay as they are.

# Rucksack 1.8.7

### New
- **Destroying an item** (with Bags on): drag it out of your bag and Rucksack asks "Are you sure you want to delete it?" with **Delete** or **Cancel**. Delete removes it right away. If it's needed for something (a quest, a Darkmoon turn-in, a rare or better item...), a second question says what and asks again. Your lists and the windows beside the bag stay as they are.
- **A yellow ! on items a quest needs**, in the top right corner of the item in your bag.
- **"A new version is out"** at login, when someone in your guild or group has a newer Rucksack. A tick box in Settings turns it off.
- **At a vendor, Rucksack tells you why** something wasn't sold: "not sold: Crisp Spider Meat x4: a quest needs it". If the vendor doesn't take something, it tries once more and tells you what the game said.
- **Take an item out of a window by dropping it on an empty slot** in your bag. While you hold an item from one of the windows, the Empty group shows a green slot first for it.

### Changed
- **Open clams and pouches by itself is now on** unless you turn it off. Clams and pouches it will open are never sold or deleted.
- With the padlock open, you can drop an item from the windows into any group.
- The bag's hover text and the value at the bottom now match what really gets sold.

### Fixed
- The colour inside the "Do not sell above" slider now ends exactly at the handle.

# Rucksack 1.8.6

### New
- **Three windows next to your bag:** **Always sell / delete**, **Sell / delete once** and **Send to bank**. Each shows the items that belong to it, and each has a **?** that says what it does. Drop an item on a window to put it there.
  - **Always sell / delete:** every one of that item, also the ones you get later. A vendor buys it, or the cheapest goes when your bags fill up. Grey items and gear you can't use land here by themselves.
  - **Sell / delete once:** only the stack you dropped there.
  - **Send to bank:** the stacks you put here go into your bank by themselves when you open it. Rucksack never sells or throws them away.
  - **Alt + left-click** an item in your bag sends that stack to the bank (at the bank it goes straight in). **Alt + right-click** an item in any of the three windows takes it out again.
  - A new button in the bags row moves the windows to the next corner of the bag: top right, bottom right, bottom left, top left. The same choice is on the Bags page.
- **Do not sell above:** a slider under "Always sell / delete", from 0 to 2 gold in 10 silver steps. Nothing worth more than that (the price of one, not the stack) is sold.
- **Darkmoon Faire plan:** a new **Plan** tab. Pick the prize you're saving for, tick the turn-ins you want to do and how many times. It shows the tickets you'll have, the items and raw materials you still need, and how many hand-ins your reputation still allows. The on-screen prize card shows it all as a small table. Click an item to see where it comes from and pin it on your map.
- **Open clams and pouches by itself:** a switch on the Settings page. Clams, pouches and other things that open with one click (no cast) are opened for you, one at a time. It waits while you fight, cast, loot or stand at a vendor, bank, mailbox or trade. Locked boxes are left alone.
- **Conjured food and water** (and mana gems) are deleted without asking when you destroy them: you can make them again for free.

### Changed
- **The delete box** now says **Always delete / Delete 16 / Cancel**. The number is how many are in the stack you're holding. Nothing is deleted on the spot any more: it waits like the rest, sold at a vendor or thrown away when your bags are nearly full (the cheapest first). Shift-click Delete to delete it right away.
- **Junk and Sell are no longer groups in the bag:** the new windows replace them. Items you set to "only sell" before still are only sold, and show in "Always sell / delete".
- Marking something while a vendor is open sells it right away.

### Fixed
- A stack you marked yourself wasn't sold when the item was set to Keep.
- A new empty group's "drop it here" text stayed behind its items.

# Rucksack 1.8.5

### Fixed
- **Sell in the delete box:** pressing Sell on a rare (blue) or other useful item asked "Do you really want to delete it?". Sell keeps the item, so it now goes straight to your Sell list. The extra question only comes before Yes or Always, which really delete.

# Rucksack 1.8.4

### New
- **One bag, Free:** a new button next to Tidy in the One bag look. With Free on, nothing is sorted: every item stays in the slot you put it in, and you can drag things onto any slot. Tidy then sorts your bags once (the game's own sort) and puts half-full stacks together.
- **A new website:** https://rucksackforever.duckdns.org. Send a bug or an idea with a screenshot, no account needed. You get a private link where you see the answer and when it's fixed, and the **Fixed and added** page shows what came from players' reports. The Website and Report a bug buttons in the game now point there.

### Changed
- **Report a bug:** the ready-made report no longer has your class and level in it (no names, nothing about your character). Each box has a **Select** button, so copying is one click and Ctrl+C.
- Settings > Modules: shorter text on the Bags card.

# Rucksack 1.8.3

### New
- **Website and Report a bug:** two buttons at the top of the Rucksack window. Each gives you a link to copy (the game doesn't let addons open a browser). Report a bug also gives a ready-made report to paste: your Rucksack and game version, the modules that are on, and the last thing the game blocked.
- **Rucksack has a website:** what it does, what's new, a report form anyone can use without an account, and a page with everyone's feedback. https://mustac.github.io/RucksackForever/

# Rucksack 1.8.2

### New
- **Bags and Clean-up are two modules.** Each has its own card in Settings > Modules and works alone: Bags without Clean-up is one bag window with your groups; Clean-up without Bags sells junk with the game's own bags or another bag addon. With both on, your bag gets Junk and Sell groups and shows what your junk sells for. Bags has its own page in the list on the left.
- **Restock:** the cart next to Hidden opens a small bag for the things you always want on you (water, food, arrows, reagents). Pull an item in and type how many to carry. A vendor that sells it tops you up, by itself or when you click **Buy now**.
  - **Keep at least N gold:** restocking never takes you below that.
  - **Money short:** *Some of each* buys a bit of every item in turn; *Top of list first* fills the first item, then the next. The arrows set the order.
  - What's on the list sits in its own **Restock** group in the bag (untick it on the Bags page to leave those items where they were). Clean-up never sells or throws them away.
- **Sell group:** drop an item on Sell and it is sold at every vendor, never thrown away.
- **Your bank in Rucksack:** at a banker your bank opens in Rucksack's own window, with the bank's bag slots in a row at the top. Click the next locked slot to buy it (the game asks once), drop a bag on a slot to put it there. The bag icon in the corner shows or hides that row.
- **Reagents go to the reagent bag:** a reagent lying in an ordinary bag moves into your reagent bag when there's room (a switch on the Bags page).
- Bag sounds when the bag opens and closes (a switch on the Bags page).

### Changed
- **Junk is under everything** by default. New groups go above it. You can still drag it.
- Settings > Modules: every module is a card with a tick; a card you changed has a gold edge until you press Apply.
- Clean-up's value limit is a slider (10s to 5g).

### Fixed
- **"Tried to call a protected function"** when using an item or buying a bank slot with Bags on. Rucksack no longer replaces the game's bag functions; it opens your bag after them.
- The bank showed slots that weren't there (the keyring was counted as part of the bank) and the wrong number of free slots.

# Rucksack 1.8.1

### Fixed
- **A cooking recipe was taken for food.** Its tooltip shows the dish it teaches ("Restores ... health ... while eating"), so the eat button and the EatDrink macro could pick the recipe (and use it, learning it), Clean-up could throw an old one away as "food below your level", and Bags put it under Food and water. Now only real food and water count; recipes stay recipes.

# Rucksack 1.8.0

### New
- **Bags module:** one bag window instead of the game's bags (B, the bag buttons, vendors, mail, the auction house, trades). Turn it on in Settings > Modules: on the **Clean-up** card, pick **Clean-up + Bags**.
- **Groups:** Weapons, Armour, Food and water, Potions, Trade goods, Quest, Everything else and Junk, each on its own row (or **Packed** side by side). Drag a group by its name: it lifts, the others slide out of the way, and it settles where you let go.
- **Put an item in a group:** pick it up, and every group gets a green **+** at its end (Junk a red one). Drop it there and all its stacks go in that group from now on.
- **Your own groups:** the green + in the bags row makes one (or drop an item on it). Right-click a group's name to rename it, change its colour or delete it.
- **One bag:** no groups, everything sorted by kind, quality or name, with Junk as a fixed group at the bottom.
- **The bags row:** hover Rucksack in the bag's corner and click the arrow. It slides open with your four bags and the reagent bag (free slots, swap a bag by dropping one on it), Hidden, New group, Delete group and a **padlock** that locks the layout.
- **Hidden:** the eye opens a small bag next to yours. Pull items into it (tools, your Hearthstone...) and the bag stops showing them. It suggests the profession tools you carry.
- **Your bank and your other characters:** open in their own window, faded, as they were when last seen. At a banker your bank opens by itself, live. Item tooltips say where else you have an item: "Also: Bank 12 · Zyxon 5".
- New items, every empty slot, BoE and "open" tags, Tidy, merged or separate stacks, search.

### Changed
- Settings > Modules: the **Clean-up** card is a choice of three: Off, Clean-up only, or Clean-up + Bags. With Bags on, the Clean-up page has **Clean-up | Bags** tabs.

# Rucksack 1.7.7

### Changed
- The one-slot eat button (Food only, Water only) is a little wider, and the Buff strip sits neatly on top of it.

### Fixed
- The tick under the "No Well Fed" alert now turns buff food off (Settings and the Buff strip follow), and the alert comes back when you tick Buff again. Before, it switched the reminder off for good. Characters that lost the alert this way get it back.
- "Remind me" on the Rations page can be changed while buff food is off.

# Rucksack 1.7.6

### Changed
- **Buff on the eat button:** a small "Buff" strip on top of the eat button, with a tick to switch buff food on or off. Green when it's on, red when it's off. (Replaces the tick in the corner.)
- **Remind me when I'm not Well Fed:** now Off or Alert. The side icon and the text under the button are gone.
- The Clean-up page no longer shows the RuckDelete macro hint.

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

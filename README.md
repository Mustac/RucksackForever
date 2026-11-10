# Rucksack Forever

**Tired of full bags and digging for food?** Rucksack Forever takes care of the two chores every adventurer repeats all day. Made for World of Warcraft Forever (interface 16001).

**Rations** picks the right food and water for you and eats and drinks with one click. No more searching your bags after every fight or eating the wrong stack.

**Clean-up** keeps a few bag slots free for you, always. When space runs low, the cheapest junk goes first (or gets sold at the next vendor), and quest items stay.

Everything is in one window (`/ruck`), with a small on-screen Pocket that shows bag space, your next meal and what a vendor would pay.

## Rations: eat and drink with one click

- One button (or key) eats your food and drinks your water. It greys out in combat, when you can't eat or drink.
- **Eat button:** Food and water (one click does both), Food only, Water only, or Separate (a food button and a water button side by side).
- **Use first:** Strongest first, Conjured first, Save conjured, or Random.
- **Food level:** Any level, Only my level, or Use up old food.
- **Delete below level:** Off, Auto, or a level (5 to 55): old food you've outgrown goes when your bags fill up.
- Warriors and rogues: delete all water as soon as you get it (set per character).
- **Buff food:** tick "Eat buff food when the buff is missing" and it's eaten first whenever you're not Well Fed. A big "don't move" alert counts down while you eat, and tells you when you're Well Fed and can move (you can drag it anywhere).
- Set any food to "Use this first" or "Never use this".
- Three macros shared by all your characters, kept up to date: **EatDrink**, **Eat** and **Drink**.

## Clean-up: delete or sell what you don't need

**Clean-up is like a little bag helper.** You pick how many free slots you always want to keep, say 4. As soon as you drop below that, it throws out your **cheapest junk first**, the stuff worth the least, until you're back to 4 free slots. No more "Inventory is full" in the middle of a dungeon.

Grey trash goes by itself. Anything else only goes if you told it to: click **Always** when you delete something once, and Clean-up remembers it. Passing a vendor? It **sells** the junk for gold instead. And it never touches what your quests still need: if a quest wants 8 wolf pelts, it keeps 8.

- The game's delete box gets an **Always** button: the item goes on your list and is deleted from then on.
- Grey trash goes by itself. Choose a quality to also delete white or green items.
- Deletes only when your bags are nearly full (you set how full), the cheapest stack first.
- Keeps exactly what your current quests still need, never more. Quest starters are kept.
- **At a vendor:** sells your Clean-up items and grey items for gold instead of deleting them (hold Shift to skip).
- **Gear you can't use:** soulbound weapons your class can never use (and shields and relics that aren't for your class) are sold at a vendor, never deleted. Tick Cloth, Leather, Mail or Plate to also sell armor types this character never wears.
- Search your list, see what's in your bags, and a history of the last 100 items deleted.

## Home, Pocket and Guide

- **Home:** bag space, your next food and water, what's waiting to go, and what a vendor would pay right now.
- **Pocket:** a small window that stays on screen with the same numbers, plus a Clean-up on/off switch.
- **Guide:** every feature explained in the game. Hover any option for a short tip.

## Commands

- `/ruck` or `/rucksack`: open the window
- `/rations`: the Rations page
- `/cleanup`: the Clean-up page
- `/ruck pocket`: show or hide the Pocket
- `/ruck settings`: settings
- `/ruck minimap`: show or hide the minimap button

## Install

Get it from [CurseForge](https://www.curseforge.com/wow/addons/rucksack-forever) (pick your WoW Forever install in the CurseForge app), or download the zip from [Releases](https://github.com/Mustac/RucksackForever/releases) and unpack it into `World of Warcraft\_forever_\Interface\AddOns`. The addon folder is called `Rucksack`.

Works alongside bag addons like Bagnon and Baganator.

## Support

Enjoying Rucksack Forever? You can [buy me a coffee](https://buymeacoffee.com/zyxon) ☕

## Releasing

Releases are automatic. To release a new version:

1. Raise `## Version` in `Rucksack.toc` (for example to `1.3.1`).
2. Add the changes at the top of `CHANGELOG.md`.
3. Push to `main`.

The GitHub Action sees the new version, tags it (`v1.3.1`), builds the zip and uploads it to CurseForge and GitHub Releases. Pushes that keep the same version release nothing.

The CurseForge API token is stored as the repository secret `CF_API_KEY`.

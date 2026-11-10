# Rucksack Forever

**Tired of full bags and digging for food?** Rucksack Forever takes care of the two chores every adventurer repeats all day. Made for World of Warcraft Forever (interface 16001).

**Rations** picks the right food and water for you and eats and drinks with one click. No more searching your bags after every fight or eating the wrong stack.

**Clean-up** keeps your bags from filling up with junk. Grey trash and anything you mark goes on its own when space runs low, or gets sold the next time you visit a vendor. It never touches what your quests still need.

Everything is in one window (`/ruck`), with a small on-screen Pocket that shows bag space, your next meal and what a vendor would pay.

## Rations: eat and drink with one click

- One button (or key) eats your food and drinks your water. It greys out in combat, when you can't eat or drink.
- **Together or Separate:** one button for both, or a food button and a water button side by side.
- **Use first:** Strongest first, Conjured first, Save conjured, or Random.
- **Food level:** Any level, Only my level, or Use up old food.
- **Delete below level:** Off, Auto, or a level (5 to 55): old food you've outgrown goes when your bags fill up.
- Warriors and rogues: delete all water as soon as you get it (set per character).
- Food with a buff (Well Fed) is never used. Set any food to "Use this first" or "Never use this".
- Three macros shared by all your characters, kept up to date: **EatDrink**, **Eat** and **Drink**.

## Clean-up: delete or sell what you don't need

- The game's delete box gets an **Always** button: the item goes on your list and is deleted from then on.
- Grey trash goes by itself. Choose a quality to also delete white or green items.
- Deletes only when your bags are nearly full (you set how full), the cheapest stack first.
- Keeps exactly what your current quests still need, never more. Quest starters are kept.
- **At a vendor:** sells your Clean-up items and grey items for gold instead of deleting them (hold Shift to skip).
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

## Releasing

Releases are automatic. To release a new version:

1. Raise `## Version` in `Rucksack.toc` (for example to `1.3.1`).
2. Add the changes at the top of `CHANGELOG.md`.
3. Push to `main`.

The GitHub Action sees the new version, tags it (`v1.3.1`), builds the zip and uploads it to CurseForge and GitHub Releases. Pushes that keep the same version release nothing.

The CurseForge API token is stored as the repository secret `CF_API_KEY`.

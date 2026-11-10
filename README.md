# Rucksack Forever

A World of Warcraft Forever addon (interface 16001) with two bag tools in one window (`/ruck`):

- **Rations:** eat and drink with one click (or two separate buttons), in the order and from the food levels you choose.
- **Clean-up:** delete or sell the items you don't need when your bags fill up, keeping what your quests still need.

The addon folder is called `Rucksack`. Download it from CurseForge (project 1796228).

## Releasing

Releases are automatic: push a tag such as `v1.3.1` and the GitHub Action builds the zip and uploads it to CurseForge.
Before tagging, raise `## Version` in `Rucksack.toc` and add the changes at the top of `CHANGELOG.md`.

The CurseForge API token is stored as the repository secret `CF_API_KEY`.

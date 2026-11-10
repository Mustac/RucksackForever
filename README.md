# Rucksack Forever

A World of Warcraft Forever addon (interface 16001) with two bag tools in one window (`/ruck`):

- **Rations:** eat and drink with one click (or two separate buttons), in the order and from the food levels you choose.
- **Clean-up:** delete or sell the items you don't need when your bags fill up, keeping what your quests still need.

The addon folder is called `Rucksack`. Download it from CurseForge (project 1796228).

## Releasing

Releases are automatic. To release a new version:

1. Raise `## Version` in `Rucksack.toc` (for example to `1.3.1`).
2. Add the changes at the top of `CHANGELOG.md`.
3. Push to `main`.

The GitHub Action sees the new version, tags it (`v1.3.1`), builds the zip and uploads it to CurseForge and GitHub Releases. Pushes that keep the same version release nothing.

The CurseForge API token is stored as the repository secret `CF_API_KEY`.

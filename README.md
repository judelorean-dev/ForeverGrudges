# Forever Grudges (Rencor Eterno)

A lightweight, dwarven-inspired personal note and memory-aid addon for **World of Warcraft** (`Interface: 16001`, client `1.60.1.70862`), with built-in **English (EN)** and **Spanish (ES)** localization.

---

## Purpose & Fair Play Statement

**Forever Grudges** was created with the sole intention of helping players **maintain a healthy, organized, and positive gaming environment**. In large multiplayer communities, it is natural to want a personal reminder of past group experiences—whether to avoid grouping again with someone whose playstyle clashed with yours, or to remember context from a previous dungeon or raid.

> **Important Ethical Notice:**
> This addon is strictly a **personal organization tool** and **must never be used to defame, harass, bully, spam, or organize witch-hunts against other players**. All data is stored strictly locally on your machine, and all predefined tags and descriptions are written in a respectful, non-abusive tone focused on in-game behaviors rather than personal attacks. Please respect your fellow players and abide by your server's Terms of Use and Code of Conduct at all times.

---

## Features

- **Predefined, Respectful Behavior Tags** (with in-game descriptions):
  1. **Ninja Looter** (`NINJA`) — Claimed someone else's loot by rolling Need improperly or broke agreed loot rules.
  2. **Firewalker / Comefuegos** (`FIREWALK`) — Ignores ground mechanics, stands in harmful areas, or accidentally pulls extra patrols.
  3. **Ragequitter** (`DESERTER`) — Abandoned the dungeon or raid after the first wipe, leaving the group stranded.
  4. **AFK Statue / Estatua (AFK)** (`AFK`) — On passive follow or prolonged unexplained AFK while the rest of the group does the work.
  5. **Chat Rager / Rager de Chat** (`RAGER`) — Uses group chat to stir up drama, blame others, and disrupt team coordination.
  6. **Ganker / Stalker** (`GANKER`) — Camps graveyards or relentlessly hunts down low-level or outnumbered players.
- **Quick Registration**:
  - Right-click any player's portrait and select **"Add to Forever Grudges"** (taint-free implementation using `Menu.ModifyMenu`).
  - Right-click the draggable **Minimap Button** or type `/grudge` (or `/fg`) while targeting a player to open the quick registration modal.
- **Non-Intrusive Local Detection & Alerts**:
  - Displays a visual `[GRUDGE: <TAG>]` banner above the `TargetFrame` when targeting a listed player.
  - Appends the tag, description, note, and date to the player's `GameTooltip`.
  - Alerts you locally when a listed player joins your party/raid, opens a trade window, whispers you, or is targeted/hovered (with a 60-second per-player anti-spam cooldown).
- **Bilingual Support (EN / ES)**:
  - Automatically detects your client locale (`enUS`/`enGB` or `esES`/`esMX`) and allows instant in-game language switching via `/grudge lang <en|es>` or the **`EN` / `ES`** button in the main window.

---

## Slash Commands

| Command | Description |
| :--- | :--- |
| `/grudge` or `/fg` | Opens the quick registration modal (if targeting a player) or toggles the main Forever Grudges window. |
| `/grudge list` | Opens or closes the main Forever Grudges window. |
| `/grudge new` | Opens the quick registration modal even without a target. |
| `/grudge add <Name> <1-6> <Note>` | Records a player entry directly from the chat console. |
| `/grudge del <Name>` | Removes a player entry from Forever Grudges. |
| `/grudge lang <en\|es>` | Switches the addon's active language between English and Spanish. |

---

## Installation

1. Copy the addon folder into your `World of Warcraft/_forever_/Interface/AddOns/` directory.
2. Ensure the folder name matches the `.toc` filename (`ForeverGrudges`).
3. Restart the game or type `/reload` in chat.

---

## License, Attribution & Disclaimer ("AS IS")

This project is open source and released under the **MIT Attribution License**.

- **Modification & Redistribution**: You are free to use, modify, and redistribute this addon, provided that you retain clear attribution to the original author: **`judelorean@proton.me`**.
- **Provided "AS IS"**: This software is provided **"AS IS"**, without warranty of any kind, express or implied. The author (**`judelorean@proton.me`**) assumes **no responsibility or liability** for how users choose to use or misuse this addon, nor for any damages, data loss, or account actions resulting from its use.

See the [LICENSE](LICENSE) file for the full legal text.

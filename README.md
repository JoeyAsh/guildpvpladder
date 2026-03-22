# GuildPvPLadder

A World of Warcraft **Retail** addon that gives your guild a unified, in-game PvP leaderboard. See every member's arena and rated battleground ratings, PvP achievements, and officer-assigned PvP titles — all in one sortable window.

> **Supported version:** WoW Retail 12.0.X and above
> **Not supported:** Classic, Era, Season of Discovery, Wrath, Cataclysm

---

## Features

- **Guild-wide ladder** — sortable table showing 2v2, 3v3, RBG, and Solo Shuffle ratings for all guild members
- **PvP achievements** — tracks Gladiator, Duelist, Rival, Challenger, Hero of the Alliance/Horde per member
- **Live sync** — members broadcast their own data on login; everyone's addon cache updates automatically
- **Offline support** — last known data for offline members is preserved between sessions
- **Custom PvP ranks** — officers can assign titles (e.g. *Warlord*, *Veteran*) displayed next to a member's name
- **Minimap button** — draggable button to quickly open/close the ladder
- **Search & sort** — filter by name, click any column header to sort ascending or descending
- **Per-character position saving** — window remembers where you left it

---

## Installation

### Option A — Manual
1. Download or build the addon (see [Building](#building) below)
2. Copy the `GuildPvPLadder` folder into:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
3. Launch WoW (or `/reload` if already in-game)
4. Enable the addon in the **AddOns** list on the character select screen

### Option B — Build script (recommended for development)
See [Building](#building) — the build script copies files to `dist\GuildPvPLadder\` and automatically symlinks it into your AddOns folder.

---

## Usage

### Opening the Ladder

- Click the **minimap button**
- Or type `/gpvp` in chat

The ladder window shows all guild members who have the addon installed, sorted by 3v3 rating by default.

### Window Controls

| Action | How |
|---|---|
| Sort by column | Click any column header (click again to reverse) |
| Filter by name | Type in the **Search** box at the bottom |
| Move window | Click and drag the title bar |
| Close | Click **X** or press **Escape** |
| Refresh data | Click **Refresh** or type `/gpvp refresh` |
| View your own stats | Click **My Stats** |

### Columns

| Column | Description |
|---|---|
| `#` | Ladder position |
| `Name` | Character name (colored by class) |
| `G.Rank` | In-game guild rank |
| `2v2` | 2v2 Arena rating |
| `3v3` | 3v3 Arena rating |
| `RBG` | Rated Battleground rating |
| `Solo` | Solo Shuffle rating |
| `PvP Rank` | Custom officer-assigned PvP title |

Ratings show `--` when no data has been received yet for that bracket.

---

## Slash Commands

| Command | Description |
|---|---|
| `/gpvp` | Toggle the ladder window |
| `/gpvp refresh` | Request fresh data from all online guild members |
| `/gpvp show <name>` | Print a player's ratings to chat |
| `/gpvp rank <name> <title>` | Assign a custom PvP rank *(officers only)* |
| `/gpvp help` | List all commands |

**Examples:**
```
/gpvp show Thrallmight
/gpvp rank Sylvanabane Warlord
/gpvp rank Anduin          ← clears the custom rank
```

---

## How Data Sync Works

WoW's API only exposes **your own** character's ratings and achievements — it is not possible to query another player's stats directly. GuildPvPLadder works around this by having each member broadcast their own data:

1. When you log in, your addon reads your ratings and achievements and sends them to the guild channel via an addon message
2. Every other guild member running the addon receives and caches your data
3. Data persists in `SavedVariables` so offline members still appear in the ladder with their last known stats

**The more guild members who have the addon installed, the more complete the ladder will be.**

---

## Building

Requirements: PowerShell (included with Windows)

```powershell
.\build_dist.ps1
```

This copies all addon files into `dist\GuildPvPLadder\` and creates a symlink from your WoW AddOns folder pointing to it. After the first run, simply rebuild after any code change and use `/reload` in-game.

> **Note:** Symlink creation requires Administrator privileges or Developer Mode enabled.
> Settings → System → For Developers → Developer Mode: On

---

## Project Structure

```
GuildPvPLadder/
├── GuildPvPLadder.toc        # Addon metadata and load order
├── GuildPvPLadder.lua        # Entry point, events, slash commands
├── Core/
│   ├── GuildManager.lua      # Guild roster management
│   ├── RatingTracker.lua     # Bracket rating fetching
│   ├── AchievementTracker.lua# PvP achievement tracking
│   └── DataCollector.lua     # Addon message broadcast/receive
├── UI/
│   ├── MainFrame.lua         # Ladder window logic
│   ├── MainFrame.xml         # Frame layout
│   ├── LadderRow.lua         # Per-row rendering
│   ├── Tooltips.lua          # Hover tooltip content
│   └── Minimap.lua           # Minimap button
└── Locale/
    └── enUS.lua              # English strings
```

---

## Known Limitations

- **Data requires the addon** — guild members without GuildPvPLadder installed will not appear in the ladder
- **Ratings are self-reported** — a member's data only updates when they log in with the addon active
- **Achievement IDs change each season** — update the ID table in `Core/AchievementTracker.lua` at the start of a new PvP season
- **TOC interface number** — update `## Interface` in `GuildPvPLadder.toc` after each major WoW patch

---

## License

This project is released for personal and guild use. Feel free to modify it for your own guild's needs.

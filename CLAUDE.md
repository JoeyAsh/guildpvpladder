# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**GuildPvPLadder** is a World of Warcraft Retail addon (12.0.X+) written in Lua 5.1 (WoW sandbox). It displays a guild-wide PvP leaderboard with ratings and achievements. Retail only — no Classic support.

## No Build System

WoW addons are loaded directly by the game engine. There is no build step, package manager, or test framework. To test, copy the addon folder into `World of Warcraft/_retail_/Interface/AddOns/GuildPvPLadder/` and reload the UI in-game (`/reload`).

## File Load Order

Files are loaded in the order listed in `GuildPvPLadder.toc`. The current load order is:
1. `Locale/enUS.lua`
2. `Core/GuildManager.lua`
3. `Core/RatingTracker.lua`
4. `Core/AchievementTracker.lua`
5. `Core/DataCollector.lua`
6. `UI/Tooltips.lua`
7. `UI/LadderRow.lua`
8. `UI/MainFrame.xml`
9. `UI/MainFrame.lua`
10. `UI/Minimap.lua`
11. `GuildPvPLadder.lua` (main init — loaded last)

When adding new files, register them in the TOC.

## Architecture

### Module Responsibilities

- **`GuildPvPLadder.lua`** — Addon entry point. Handles `ADDON_LOADED`, registers all events, defines slash commands (`/gpvp`, `/guildpvp`), and bootstraps all other modules.
- **`Core/GuildManager.lua`** — Guild roster via `GetGuildRosterInfo()`. Refreshes on `GUILD_ROSTER_UPDATE`.
- **`Core/RatingTracker.lua`** — Fetches own bracket ratings via `GetPersonalRatedInfo(bracketIndex)` (indices: 1=2v2, 2=3v3, 5=RBG, 7=Solo Shuffle).
- **`Core/AchievementTracker.lua`** — Fetches own PvP achievements via `GetAchievementInfo(id)`. Achievement IDs live in a configurable table (update between seasons without code changes).
- **`Core/DataCollector.lua`** — Orchestrates data gathering; calls GuildManager, RatingTracker, AchievementTracker on login/refresh.
- **`UI/MainFrame.lua` + `MainFrame.xml`** — Main sortable ladder window. Columns: Rank, Name, Guild Rank, 2v2, 3v3, RBG, Solo Shuffle, Achievements. Default sort: 3v3 descending.
- **`UI/LadderRow.lua`** — Renders individual player rows with class-colored names.
- **`UI/Tooltips.lua`** — Hover tooltips with full player PvP detail.
- **`UI/Minimap.lua`** — Minimap button (LibDBIcon-compatible).
- **`Locale/enUS.lua`** — All user-facing strings; structure ready for additional locales.

### Data Flow

1. `ADDON_LOADED` → initialize `GuildPvPLadderDB` (or migrate if version mismatch), register events
2. `PLAYER_LOGIN` → collect own ratings/achievements → broadcast via addon messages on `GUILD` channel
3. `CHAT_MSG_ADDON` with prefix `GPVPL` → receive other members' data → cache in `GuildPvPLadderDB`
4. Main window reads from `GuildPvPLadderDB.members` to render the ladder

### Data Persistence

- **`GuildPvPLadderDB`** (SavedVariables) — Shared guild data. Members keyed by `"CharacterName-RealmName"`. Stores ratings, achievements, custom PvP ranks, last-updated timestamp.
- **`GuildPvPLadderCharDB`** (SavedVariablesPerCharacter) — Per-character settings (window position, etc.).
- On load, check `GuildPvPLadderDB.version` and migrate if outdated.

### Addon Message Protocol

- **Prefix:** `GPVPL` (must be registered via `C_ChatInfo.RegisterAddonMessagePrefix`)
- **Channel:** `GUILD`
- **Message types:** `RATING_UPDATE`, `ACH_UPDATE`, `RANK_SET`, `REQUEST_DATA`
- Throttle broadcasts — send once on login and on explicit `/gpvp refresh`. Do not spam.

## Key Constraints

- **Rating data is self-reported.** `GetPersonalRatedInfo` only works for the logged-in character. Other members' data comes from their own broadcasts.
- **Achievement data is local.** `GetAchievementInfo` is only reliable for the current player.
- **Keys must include realm name** (`Name-Realm`) to avoid collisions in cross-realm guilds.
- **TOC Interface number** (`120000` = Retail 12.0.X) must be updated each major WoW patch.
- Verify `GetPersonalRatedInfo` bracket indices against current API docs before use — they can shift between expansions.

## Slash Commands

| Command | Action |
|---|---|
| `/gpvp` or `/guildpvp` | Toggle main ladder window |
| `/gpvp refresh` | Force re-request data from guild |
| `/gpvp show <name>` | Show specific player's stats |
| `/gpvp rank <name> <title>` | Assign custom PvP rank (officer only, guild rank ≤ 2) |
| `/gpvp config` | Open settings panel |
| `/gpvp help` | Print command help |

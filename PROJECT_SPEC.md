# GuildPvPLadder — WoW Addon Project Specification

> **Target Game Version:** World of Warcraft Retail (12.0.X and above)  
> **Addon Type:** Guild Utility / PvP Tracker  
> **Scope:** Retail only — no Classic, Era, or Season of Discovery support

---

## 1. Project Overview

**GuildPvPLadder** is a World of Warcraft retail addon that provides guilds with a unified, in-game leaderboard for Player vs. Player (PvP) performance. It allows guild members and officers to view at a glance who holds the highest ratings, has achieved notable PvP accomplishments, and what rank each member holds across all relevant PvP brackets.

The addon fetches and caches PvP data for guild members, presents it in a clean sortable ladder UI, and persists data between sessions using `SavedVariables`.

---

## 2. Goals & Non-Goals

### Goals
- Display a per-guild PvP ladder ranked by configurable criteria (rating, achievements, etc.)
- Show each member's highest rating per PvP bracket (2v2, 3v3, RBG, Solo Shuffle)
- Show PvP-related achievements per member (e.g., Gladiator, Duelist, Rival, Challenger, Hero of the Alliance/Horde)
- Allow officers/GMs to assign and display custom PvP ranks within the addon
- Persist collected data across sessions via `SavedVariables`
- Provide a slash command interface for quick access
- Support localization infrastructure (EN as primary, structure ready for more)

### Non-Goals
- No support for Classic, Wrath, Cata, or any non-retail version
- No external server or backend — purely in-game data via the WoW API
- No real-time cross-realm data scraping
- No Auction House, PvE, or raid tracking

---

## 3. Technical Foundation

| Property | Value |
|---|---|
| Game Version | WoW Retail 12.0.X |
| API Type | Lua 5.1 (WoW sandbox) |
| TOC Interface | `120000` (update per patch) |
| Saved Variables | `GuildPvPLadderDB` |
| Slash Commands | `/gpvp`, `/guildpvp` |
| Frame System | Standard WoW XML + Lua frames (no third-party UI libs required) |
| Optional Dependency | LibStub, AceDB-3.0 (optional, for DB management) |

---

## 4. File & Folder Structure

```
GuildPvPLadder/
├── GuildPvPLadder.toc          # Addon metadata and file load order
├── GuildPvPLadder.lua          # Core addon init, event registration, slash commands
├── Core/
│   ├── DataCollector.lua       # Gathers PvP data via WoW API calls
│   ├── GuildManager.lua        # Handles guild roster, ranks, member lookups
│   ├── AchievementTracker.lua  # Queries and caches PvP achievement data
│   └── RatingTracker.lua       # Fetches and stores bracket ratings
├── UI/
│   ├── MainFrame.lua           # Main ladder window logic
│   ├── MainFrame.xml           # Frame layout definition
│   ├── LadderRow.lua           # Individual player row rendering
│   ├── Tooltips.lua            # Tooltip content for player details
│   └── Minimap.lua             # Minimap button (LibDBIcon compatible)
├── Locale/
│   └── enUS.lua                # English strings
└── Libs/
    └── (optional: LibStub, AceDB, LibDBIcon)
```

---

## 5. TOC File

```toc
## Interface: 120000
## Title: GuildPvPLadder
## Notes: Guild-wide PvP leaderboard with ratings and achievements.
## Author: YourName
## Version: 1.0.0
## SavedVariables: GuildPvPLadderDB
## SavedVariablesPerCharacter: GuildPvPLadderCharDB

Locale/enUS.lua
Core/GuildManager.lua
Core/RatingTracker.lua
Core/AchievementTracker.lua
Core/DataCollector.lua
UI/Tooltips.lua
UI/LadderRow.lua
UI/MainFrame.xml
UI/MainFrame.lua
UI/Minimap.lua
GuildPvPLadder.lua
```

---

## 6. Core Features

### 6.1 Guild Roster Integration

- Use `GetGuildRosterInfo(index)` to iterate over all guild members
- Store name, class, level, guild rank index, and guild rank name
- Refresh roster on `GUILD_ROSTER_UPDATE` event
- Support for offline members (data persisted in `SavedVariables`)

### 6.2 PvP Rating Tracking

Use the following WoW API calls to retrieve bracket ratings:

| Bracket | API Function |
|---|---|
| 2v2 Arena | `GetPersonalRatedInfo(1)` |
| 3v3 Arena | `GetPersonalRatedInfo(2)` |
| RBG | `GetPersonalRatedInfo(5)` |
| Solo Shuffle | `GetPersonalRatedInfo(7)` |

> **Note:** Ratings can only be fetched for the **currently logged-in character**. For other guild members, data must be submitted voluntarily when they log in with the addon installed, and stored in `SavedVariables` (shared across characters on the same account or broadcast via addon messages).

**Data sync strategy:**
- Each player's client broadcasts their own rating data via `SendAddonMessage` on the `GUILD` channel on login/update
- Other guild members with the addon receive this data and cache it locally

### 6.3 PvP Achievement Tracking

Track the following PvP achievements per player using `GetAchievementInfo(achievementID)`:

| Achievement | ID | Category |
|---|---|---|
| Gladiator | 2090 | Arena Season |
| Duelist | 2092 | Arena Season |
| Rival | 2093 | Arena Season |
| Challenger | 2091 | Arena Season |
| Hero of the Alliance | 659 | RBG |
| Hero of the Horde | 660 | RBG |
| High Warlord / Grand Marshal | 2136 / 2137 | Legacy |
| Solo Shuffle: Elite | (current season ID) | Solo Shuffle |

> Achievement IDs may change between seasons. The addon should support a configurable ID table in a separate `Config.lua` file for easy updates.

### 6.4 PvP Ladder Display

The main window is a sortable table with the following columns:

| # | Column | Description |
|---|---|---|
| 1 | Rank | Position in the ladder (auto-calculated) |
| 2 | Name | Character name (colored by class) |
| 3 | Guild Rank | In-game guild rank |
| 4 | 2v2 Rating | Highest rating in 2v2 bracket |
| 5 | 3v3 Rating | Highest rating in 3v3 bracket |
| 6 | RBG Rating | Highest RBG rating |
| 7 | Solo Shuffle | Highest Solo Shuffle rating |
| 8 | Achievements | Icons for notable PvP achievements earned |

- Clicking a column header sorts the ladder by that column (ascending/descending toggle)
- Default sort: highest 3v3 rating descending
- Rows are colored alternately for readability
- Hovering a row shows a tooltip with full detail

### 6.5 Custom PvP Ranks

Officers and GMs can assign custom in-addon PvP titles to members:

- Examples: `Warlord`, `Champion`, `Veteran`, `Recruit`
- Stored in `GuildPvPLadderDB` keyed by character name
- Displayed as a badge/tag next to the member's name in the ladder
- Only players with guild rank `≤ 2` (configurable) can assign custom ranks

---

## 7. Data Model

### SavedVariables Schema (`GuildPvPLadderDB`)

```lua
GuildPvPLadderDB = {
  version = "1.0.0",
  members = {
    ["CharacterName-RealmName"] = {
      name        = "CharacterName",
      realm       = "RealmName",
      class       = "WARRIOR",          -- WoW class token
      guildRank   = 2,                  -- Index from GetGuildRosterInfo
      guildRankName = "Officer",
      ratings = {
        ["2v2"]         = 1850,
        ["3v3"]         = 2100,
        ["rbg"]         = 1950,
        ["soloshuffle"] = 1750,
      },
      achievements = {
        gladiator     = true,
        duelist       = false,
        rival         = true,
        challenger    = true,
        heroAlliance  = false,
        heroHorde     = false,
      },
      customPvPRank = "Warlord",        -- nil if not set
      lastUpdated   = 1700000000,       -- Unix timestamp
    },
  },
  config = {
    defaultSort   = "3v3",
    officerRankThreshold = 2,
    showOfflineMembers   = true,
    minimapButton = { hide = false, angle = 45 },
  },
}
```

---

## 8. Addon Message Protocol

Used for guild-wide data synchronization via `C_ChatInfo.SendAddonMessage`.

**Prefix:** `GPVPL`  
**Channel:** `GUILD`

### Message Types

| Type | Payload | Description |
|---|---|---|
| `RATING_UPDATE` | `name|2v2|3v3|rbg|solo` | Broadcast own ratings on login |
| `ACH_UPDATE` | `name|ach1,ach2,...` | Broadcast achieved PvP achs |
| `RANK_SET` | `name|customRank` | Officer sets a custom rank |
| `REQUEST_DATA` | `name` | Request data from a specific player |

**Example payload:**
```
GPVPL:RATING_UPDATE:Thrallmight-Silvermoon|1800|2050|1900|1650
```

---

## 9. UI Layout Specification

```
┌─────────────────────────────────────────────────────────┐
│  ⚔  Guild PvP Ladder          [Search: _______] [X]     │
├──────┬──────────────┬────────┬──────┬──────┬─────┬──────┤
│  #   │ Name         │ G.Rank │  2v2 │  3v3 │ RBG │ Solo │
├──────┼──────────────┼────────┼──────┼──────┼─────┼──────┤
│  1   │ Thrallmight  │ GM     │ 1800 │ 2100 │1950 │ 1750 │
│  2   │ Sylvanabane  │ Officer│ 1750 │ 2050 │1880 │ 1690 │
│  3   │ Anduin       │ Member │ 1200 │ 1950 │1700 │ 1600 │
│  ... │ ...          │ ...    │  ... │  ... │ ... │  ... │
├──────┴──────────────┴────────┴──────┴──────┴─────┴──────┤
│  [Refresh]  [My Stats]  [Options]    Last update: 2m ago │
└─────────────────────────────────────────────────────────┘
```

- Window is movable and resizable
- Position saved in `SavedVariables`
- Minimap button toggles the window

---

## 10. Slash Commands

| Command | Description |
|---|---|
| `/gpvp` or `/guildpvp` | Toggle the main ladder window |
| `/gpvp refresh` | Force re-request data from guild |
| `/gpvp show <name>` | Show a specific player's PvP stats |
| `/gpvp rank <name> <title>` | Assign a custom PvP rank (officer only) |
| `/gpvp config` | Open the settings panel |
| `/gpvp help` | Print all commands to chat |

---

## 11. Events to Handle

| WoW Event | Handler |
|---|---|
| `ADDON_LOADED` | Initialize DB, register events |
| `PLAYER_LOGIN` | Collect own data, broadcast to guild |
| `GUILD_ROSTER_UPDATE` | Refresh roster cache |
| `CHAT_MSG_ADDON` | Process incoming GPVPL messages |
| `ACHIEVEMENT_EARNED` | Update own achievement data and broadcast |
| `PLAYER_PVP_RANK_CHANGED` | Re-fetch ratings, broadcast update |
| `UPDATE_BATTLEFIELD_SCORE` | Triggered after rated match; update ratings |

---

## 12. WoW API Reference

Key API functions used in this addon:

```lua
-- Guild
GetNumGuildMembers()
GetGuildRosterInfo(index)          -- name, rank, rankIndex, level, class, ...

-- PvP Ratings
GetPersonalRatedInfo(bracketIndex) -- rating, seasonBest, weeklyBest, ...

-- Achievements
GetAchievementInfo(achievementID)  -- id, name, points, completed, ...
GetAchievementNumCriteria(id)
GetAchievementCriteriaInfo(id, n)

-- Addon Messaging
C_ChatInfo.SendAddonMessage(prefix, message, channel)
C_ChatInfo.RegisterAddonMessagePrefix(prefix)

-- Misc
UnitClass("player")
UnitName("player")
GetRealmName()
time()                             -- current Unix timestamp
```

---

## 13. Development Phases

### Phase 1 — Foundation (MVP)
- [ ] TOC file, `SavedVariables`, init logic
- [ ] Guild roster collection
- [ ] Own-character rating & achievement collection
- [ ] Basic ladder window (static, non-sortable)
- [ ] Slash command `/gpvp`

### Phase 2 — Sync & Data
- [ ] Addon message broadcasting on login
- [ ] Receiving and caching other members' data
- [ ] Offline member support (show last known data)
- [ ] Achievement badge icons in ladder rows

### Phase 3 — UI Polish
- [ ] Sortable columns
- [ ] Search/filter by name
- [ ] Tooltips with full player PvP history
- [ ] Minimap button
- [ ] Settings panel

### Phase 4 — Advanced Features
- [ ] Custom PvP rank assignment (officer feature)
- [ ] Season history tracking (store previous season bests)
- [ ] Export data to chat (share ladder as formatted text)
- [ ] Localization support for additional languages

---

## 14. Constraints & Known Limitations

- **Rating data is self-reported:** The WoW API does not allow querying another player's rating directly. All data relies on guild members having the addon installed and broadcasting their stats.
- **Achievement data is local:** `GetAchievementInfo` only works reliably for the current player. Other players' achievements must be broadcast via addon messages.
- **Realm name handling:** Character keys must include realm name (`Name-Realm`) to avoid collisions in cross-realm guilds.
- **Rate limiting:** Avoid spamming `SendAddonMessage`; throttle broadcasts to once per login and on explicit refresh.
- **Interface number:** `120000` corresponds to WoW Retail 12.0.X. Update `## Interface` in the TOC per major patch.

---

## 15. Versioning & Compatibility

| Field | Value |
|---|---|
| Current TOC Interface | `120000` |
| Minimum Supported Build | Retail 12.0.0 |
| SavedVariables Version | `1.0.0` |
| DB Migration | Check `GuildPvPLadderDB.version` on load; migrate if outdated |

---

*This document is intended to be read by an AI coding assistant or developer to implement the GuildPvPLadder addon from scratch. All API references are based on the live WoW Retail 12.0.X API. Double-check `GetPersonalRatedInfo` bracket indices against the current API documentation before implementation, as these may shift between expansions.*
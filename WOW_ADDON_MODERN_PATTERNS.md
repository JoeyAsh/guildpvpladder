# Modern WoW Retail Addon Development Patterns
*Derived from Plater v636-Retail (Patch 12.0.x) — cross-referenced with official API changelogs*

---

## TOC File

```ini
## Interface: 120001, 120005     ← multiple interface versions OK
## Title: MyAddon
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB
## OptionalDeps: SomeOtherAddon
## X-Curse-Project-ID: 123456   ← distribution platform metadata
## X-Wago-ID: abc123

#@no-lib-strip@                  ← packager strips libs before upload
libs\libs.xml
#@end-no-lib-strip@

Locale\enUS.lua
...files in load order...
MyAddon.lua                      ← main init loaded last
```

---

## Addon Table Initialization

Every module file must guard against `nil` before indexing the global table,
because modules load before the main file:

```lua
-- Top of EVERY module file (the table is nil until the first file creates it)
MyAddon = MyAddon or {}
MyAddon.SomeModule = MyAddon.SomeModule or {}
```

Modern alternative — use the implicit addon namespace from `...`:

```lua
-- WoW passes two values to every file in the addon:
local addonName, addonNamespace = ...
-- addonNamespace is a shared empty table per-addon, no guard needed
addonNamespace.SomeModule = {}
```

---

## Event Registration

Raw WoW API is preferred over AceEvent-3.0 in modern addons:

```lua
-- Event handler frame
local eventFrame = CreateFrame("Frame")

-- Map events to handler functions (cleaner than a giant if/elseif chain)
local handlers = {
    ADDON_LOADED = function(addonName)
        if addonName ~= "MyAddon" then return end
        -- init here
    end,
    PLAYER_LOGIN = function()
        -- world is ready, safe to call most APIs
    end,
    GUILD_ROSTER_UPDATE = function()
        -- roster changed
    end,
}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if fn then fn(...) end
end)

for event in pairs(handlers) do
    eventFrame:RegisterEvent(event)
end
```

---

## Slash Commands

Pattern is **unchanged** in 12.0 — still the standard:

```lua
SLASH_MYADDON1 = "/myaddon"
SLASH_MYADDON2 = "/ma"

SlashCmdList["MYADDON"] = function(msg, editBox)
    -- editBox is the ChatEdit frame (rarely needed)
    msg = msg:match("^%s*(.-)%s*$")  -- trim
    -- parse msg here
end
```

---

## SavedVariables

Access SavedVariables in `ADDON_LOADED` (they are populated before that event fires):

```lua
handlers.ADDON_LOADED = function(addonName)
    if addonName ~= "MyAddon" then return end

    -- First run: MyAddonDB is nil. Always guard with defaults:
    MyAddonDB = MyAddonDB or {}
    MyAddonDB.version = MyAddonDB.version or "1.0"
    MyAddonDB.members = MyAddonDB.members or {}
end
```

**New opt-in TOC directive** (Patch 11.1.5+) — loads SavedVariables *before* Lua files:
```ini
## LoadSavedVariablesFirst: 1
```
Useful if modules need DB data at file-load time rather than `ADDON_LOADED`.

---

## APIs That Changed or Were Removed

### GetPersonalRatedInfo → GetInspectArenaData (removed ~11.0)

```lua
-- OLD (removed — not present in live source as of 11.0+):
local rating = GetPersonalRatedInfo(bracketIndex)

-- NEW: works for the current player even without an active inspect
local rating = GetInspectArenaData(bracketIndex)
-- Returns: rating, seasonPlayed, seasonWon, weeklyPlayed, weeklyWon
```

**Bracket indices (current):**

| Bracket      | Index |
|--------------|-------|
| 2v2          | 1     |
| 3v3          | 2     |
| RBG          | 4     |
| Solo Shuffle | 7     |
| BG Blitz     | 9     |

> Note: index 5 (old RBG) is wrong. RBG is now **4**.

For data available only *during an active match*: `C_PvP.GetPVPActiveMatchPersonalRatedInfo()`

---

### GuildInfo() → C_GuildInfo.GuildRoster() (moved in 8.2.0)

```lua
-- OLD (compat wrapper may still exist but avoid it):
GuildInfo()

-- NEW:
C_GuildInfo.GuildRoster()
```

`GetGuildRosterInfo(index)` itself is unchanged and still works.

---

### EasyMenu removed in 11.0.0 — use MenuUtil

```lua
-- OLD (removed in 11.0.0):
EasyMenu(menuList, dropdownFrame, "cursor", 0, 0, "MENU")

-- NEW: right-click context menu
MenuUtil.CreateContextMenu(anchorFrame, function(owner, rootDescription)
    rootDescription:CreateTitle("My Addon")
    rootDescription:CreateButton("Do Something", function()
        -- action
    end)
    rootDescription:CreateButton("Hide This Button", function()
        myButton:Hide()
    end)
    -- Checkbox example:
    rootDescription:CreateCheckbox(
        "Enable Feature",
        function() return db.featureEnabled end,
        function() db.featureEnabled = not db.featureEnabled end
    )
end)

-- NEW: inline dropdown (persistent, not right-click triggered)
local dd = CreateFrame("DropdownButton", nil, parent)
dd:SetupMenu(function(dropdown, rootDescription)
    rootDescription:CreateButton("Option A", callbackA)
    rootDescription:CreateButton("Option B", callbackB)
end)
```

`UIDropDownMenu` is formally **deprecated** (kept for backward compat only — do not use for new code).

---

### GetAddOnMetadata → C_AddOns.GetAddOnMetadata (10.1+)

```lua
-- Defensive fallback pattern:
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local version = GetAddOnMetadata("MyAddon", "Version")
```

Similarly for other AddOn* globals:
```lua
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
```

---

### GetSpellInfo → C_Spell.GetSpellInfo (10.1+)

```lua
-- OLD:
local name, _, icon = GetSpellInfo(spellID)

-- NEW (returns a table):
local info = C_Spell.GetSpellInfo(spellID)
if info then
    local name = info.name
    local icon = info.iconID
    local castTime = info.castTime
end
```

---

## Frame Creation Patterns

### BackdropTemplate (required since 9.0)

Backdrop must go through `BackdropTemplate` — the old XML `<Backdrop>` attribute no longer renders in current retail.

```lua
-- In Lua:
local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})

-- Defensive (works on any version):
local frame = CreateFrame("Frame", nil, parent,
    BackdropTemplateMixin and "BackdropTemplate")
if frame.SetBackdrop then
    frame:SetBackdrop({ ... })
end
```

---

## Addon Communication (C_ChatInfo)

Still the standard, but with tighter throttling since **10.2.7**:

```lua
-- Register prefix (do this once, in ADDON_LOADED):
C_ChatInfo.RegisterAddonMessagePrefix("MYADDON")

-- Send — now returns an Enum.SendAddonMessageResult code (not boolean):
local result = C_ChatInfo.SendAddonMessage("MYADDON", msg, "GUILD")
-- result == 0 → success
-- result == 11 → AddOnMessageLockdown (blocked in instances/rated PvP)
-- result == 12 → TargetOffline

-- Throttle budget: 10 messages burst, regenerates 1/sec per prefix.
-- Keep sends minimal — once on login + explicit refresh is fine.

-- Receive:
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
handlers.CHAT_MSG_ADDON = function(prefix, message, channel, sender)
    if prefix ~= "MYADDON" then return end
    -- handle
end
```

**Addon messages are blocked** during active Mythic+, rated PvP, and boss encounters.
Handle `result == 11` gracefully (queue and retry after leaving the instance).

---

## Timer API (no library needed)

```lua
-- Fire once after delay:
C_Timer.After(2.5, function()
    -- runs 2.5 seconds later
end)

-- Repeating timer (object with :Cancel()):
local ticker = C_Timer.NewTicker(1.0, function()
    -- runs every second
end, 5)  -- optional 3rd arg: max repetitions

ticker:Cancel()  -- stop early
```

---

## Version Detection

```lua
-- Check WoW project (Retail vs Classic variants):
local isRetail  = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

-- Check for Midnight-specific behavior:
local isMidnight = select(4, GetBuildInfo()) >= 120000
```

---

## Addon Messaging in Lockdown (12.0)

Starting in **12.0 (Midnight)**, certain data is unavailable programmatically during combat
and in rated instances ("Secret Values" system, CLEU removed):

- Combat log events (`COMBAT_LOG_EVENT_UNFILTERED`) no longer fire
- Aura/cooldown/health data in instances is display-only — cannot be read by addons
- `C_ChatInfo.SendAddonMessage` returns `AddOnMessageLockdown` (11) during rated matches

For a PvP ladder addon this matters on login: if a player logs in mid-match the broadcast
will fail. Retry on `PLAYER_ENTERING_WORLD` when not in a restricted instance.

---

## General Modern Practices

| Old Pattern | Modern Pattern |
|---|---|
| `GetPersonalRatedInfo(idx)` | `GetInspectArenaData(idx)` |
| `GuildInfo()` | `C_GuildInfo.GuildRoster()` |
| `EasyMenu(...)` | `MenuUtil.CreateContextMenu(...)` |
| `GetSpellInfo(id)` | `C_Spell.GetSpellInfo(id)` (returns table) |
| `GetAddOnMetadata(...)` | `C_AddOns.GetAddOnMetadata(...)` |
| `<Backdrop>` in XML | `"BackdropTemplate"` + `:SetBackdrop()` in Lua |
| `UIDropDownMenu*` | `DropdownButton` frame + `:SetupMenu()` |
| `C_Timer` library | Built-in `C_Timer.After` / `C_Timer.NewTicker` |
| Checking `SendAddonMessage` boolean | Check `Enum.SendAddonMessageResult` code |
| `AceEvent` for event routing | Raw `CreateFrame` + event table dispatch |
| RBG bracket index 5 | RBG bracket index **4** |

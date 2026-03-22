-- GuildPvPLadder.lua
-- Main addon entry point. Creates the addon table, event frame, and slash commands.

GuildPvPLadder = GuildPvPLadder or {}

-------------------------------------------------------------------------------
-- DB initialisation / migration
-------------------------------------------------------------------------------

local function InitDB()
  -- Ensure GuildPvPLadderDB exists with all required keys
  if type(GuildPvPLadderDB) ~= "table" then
    GuildPvPLadderDB = {}
  end
  local db = GuildPvPLadderDB
  db.version  = db.version  or "1.0.0"
  db.members  = db.members  or {}
  db.config   = db.config   or {}

  local c = db.config
  if c.defaultSort         == nil then c.defaultSort         = "3v3"  end
  if c.sortAscending       == nil then c.sortAscending       = false  end
  if c.officerRankThreshold == nil then c.officerRankThreshold = 2    end
  if c.showOfflineMembers  == nil then c.showOfflineMembers  = true   end
  if c.minimapButton       == nil then c.minimapButton       = { hide = false, angle = 45 } end

  if type(GuildPvPLadderCharDB) ~= "table" then
    GuildPvPLadderCharDB = {}
  end
  -- windowPos intentionally kept nil when not yet saved
  if GuildPvPLadderCharDB.windowPos == nil then
    GuildPvPLadderCharDB.windowPos = nil
  end

  return db
end

-------------------------------------------------------------------------------
-- Event handlers
-------------------------------------------------------------------------------

function GuildPvPLadder:ADDON_LOADED(addonName)
  if addonName ~= "GuildPvPLadder" then return end

  local db = InitDB()

  -- Initialise all modules (implemented by other agents)
  GuildPvPLadder.GuildManager:Initialize(db)
  GuildPvPLadder.RatingTracker:Initialize(db)
  GuildPvPLadder.AchievementTracker:Initialize(db)
  GuildPvPLadder.DataCollector:Initialize(db)
  GuildPvPLadder.UI:Initialize(db)
  GuildPvPLadder.Minimap:Initialize(db)

  DEFAULT_CHAT_FRAME:AddMessage(GPVPL_L["LOADED"])
end

function GuildPvPLadder:PLAYER_LOGIN()
  GuildPvPLadder.GuildManager:RefreshRoster()
  -- Request self-inspect to load bracket ratings; broadcast fires from INSPECT_READY.
  -- Also attempt an immediate collect so DB has something even if inspect is slow.
  GuildPvPLadder.DataCollector:CollectAndBroadcast()
  GuildPvPLadder.RatingTracker:RequestInspect()
end

function GuildPvPLadder:INSPECT_READY(guid)
  -- Let both handlers check whether this inspect belongs to them.
  GuildPvPLadder.RatingTracker:OnInspectReady(guid)
  GuildPvPLadder.DataCollector:OnMemberInspectReady(guid)
end

local _initialInspectQueued = false
function GuildPvPLadder:GUILD_ROSTER_UPDATE()
  GuildPvPLadder.GuildManager:RefreshRoster()
  -- On the first roster update after login, kick off the guild inspect sweep.
  -- A small delay lets the self-inspect (RequestInspect) finish first.
  if not _initialInspectQueued then
    _initialInspectQueued = true
    C_Timer.After(8, function()
      GuildPvPLadder.DataCollector:QueueGuildInspects()
    end)
  end
  if GuildPvPLadder.UI and GuildPvPLadder.UI.frame and GuildPvPLadder.UI.frame:IsShown() then
    GuildPvPLadder.UI:Refresh()
  end
end

function GuildPvPLadder:CHAT_MSG_ADDON(prefix, message, channel, sender)
  GuildPvPLadder.DataCollector:HandleAddonMessage(prefix, message, channel, sender)
end

function GuildPvPLadder:ACHIEVEMENT_EARNED()
  GuildPvPLadder.DataCollector:CollectAndBroadcast()
end

function GuildPvPLadder:UPDATE_BATTLEFIELD_SCORE()
  GuildPvPLadder.DataCollector:CollectAndBroadcast()
end

-------------------------------------------------------------------------------
-- Event frame
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
eventFrame:RegisterEvent("INSPECT_READY")

eventFrame:SetScript("OnEvent", function(self, event, ...)
  GuildPvPLadder[event](GuildPvPLadder, ...)
end)

-------------------------------------------------------------------------------
-- Slash command helpers
-------------------------------------------------------------------------------

-- Case-insensitive member lookup by name.
local function FindMember(name)
  local lower = name:lower()
  for memberName, data in pairs(GuildPvPLadderDB.members) do
    if memberName:lower() == lower then
      return memberName, data
    end
  end
  return nil, nil
end

-- Returns true when the current player has officer-level guild privileges.
local function IsOfficer()
  -- CanEditOfficerNote() is available in all retail versions and is a reliable
  -- indicator that the player holds an officer (or higher) guild rank.
  return CanEditOfficerNote and CanEditOfficerNote()
end

-- Print all help strings to the default chat frame.
local function PrintHelp()
  DEFAULT_CHAT_FRAME:AddMessage(GPVPL_L["CMD_HELP"])
  DEFAULT_CHAT_FRAME:AddMessage(GPVPL_L["CMD_TOGGLE"])
  DEFAULT_CHAT_FRAME:AddMessage(GPVPL_L["CMD_REFRESH"])
  DEFAULT_CHAT_FRAME:AddMessage(GPVPL_L["CMD_SHOW"])
  DEFAULT_CHAT_FRAME:AddMessage(GPVPL_L["CMD_RANK"])
  DEFAULT_CHAT_FRAME:AddMessage(GPVPL_L["CMD_CONFIG"])
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

SLASH_GPVP1 = "/gpvp"
SLASH_GPVP2 = "/guildpvp"

SlashCmdList["GPVP"] = function(msg)
  msg = msg and msg:match("^%s*(.-)%s*$") or ""  -- trim whitespace

  -- Split into up to 3 tokens: cmd, arg1, arg2
  local cmd, arg1, arg2 = msg:match("^(%S+)%s*(%S*)%s*(.*)$")
  if cmd then
    cmd = cmd:lower()
  end

  -- "/gpvp" or "/gpvp show" with no further args → toggle
  if msg == "" or (cmd == "show" and arg1 == "") then
    GuildPvPLadder.UI:Toggle()

  elseif cmd == "refresh" then
    GuildPvPLadder.DataCollector:RequestGuildData()
    DEFAULT_CHAT_FRAME:AddMessage(GPVPL_L["REFRESHING"])

  elseif cmd == "show" then
    -- "show <name>"
    local targetName = arg1
    local foundName, data = FindMember(targetName)
    if not foundName then
      DEFAULT_CHAT_FRAME:AddMessage(string.format(GPVPL_L["PLAYER_NOT_FOUND"], targetName))
    else
      local r = data.ratings or {}
      DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "[GuildPvPLadder] %s — 2v2: %s  3v3: %s  RBG: %s  Solo: %s",
        foundName,
        tostring(r["2v2"]  or GPVPL_L["NO_RATING"]),
        tostring(r["3v3"]  or GPVPL_L["NO_RATING"]),
        tostring(r["rbg"]  or GPVPL_L["NO_RATING"]),
        tostring(r["soloshuffle"] or GPVPL_L["NO_RATING"])
      ))
    end

  elseif cmd == "rank" then
    -- "rank <name> <title>"
    local targetName = arg1
    local title      = arg2 and arg2:match("^%s*(.-)%s*$") or ""

    if not IsOfficer() then
      DEFAULT_CHAT_FRAME:AddMessage(GPVPL_L["NOT_OFFICER"])
      return
    end

    if targetName == "" then
      PrintHelp()
      return
    end

    local foundName, data = FindMember(targetName)
    if not foundName then
      DEFAULT_CHAT_FRAME:AddMessage(string.format(GPVPL_L["PLAYER_NOT_FOUND"], targetName))
    else
      data.customPvPRank = (title ~= "") and title or nil
      DEFAULT_CHAT_FRAME:AddMessage(string.format(GPVPL_L["RANK_SET"], title, foundName))
      -- Broadcast the update so other guild members receive it.
      GuildPvPLadder.DataCollector:CollectAndBroadcast()
    end

  elseif cmd == "config" then
    -- Phase 3 feature — settings panel not yet implemented.
    DEFAULT_CHAT_FRAME:AddMessage("[GuildPvPLadder] Settings panel coming soon.")

  elseif cmd == "help" then
    PrintHelp()

  else
    -- Unknown command — show help.
    PrintHelp()
  end
end

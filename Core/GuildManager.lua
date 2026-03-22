-- GuildPvPLadder: Core/GuildManager.lua
-- Manages guild roster scanning and member DB entries.

GuildPvPLadder = GuildPvPLadder or {}
GuildPvPLadder.GuildManager = GuildPvPLadder.GuildManager or {}
local GuildManager = GuildPvPLadder.GuildManager

local L = GPVPL_L

-- -------------------------------------------------------------------------
-- Internal helpers
-- -------------------------------------------------------------------------

--- Return the current player's realm name with spaces stripped.
local function GetCleanRealm()
    local realm = GetRealmName() or ""
    return realm:gsub("%s+", "")
end

--- Parse a fullName string returned by GetGuildRosterInfo.
--- On connected realms fullName is "Name-Realm"; on the same realm it may
--- be just "Name".  We always return (name, realm) as separate strings.
local function ParseFullName(fullName)
    local name, realm = fullName:match("^(.+)-(.+)$")
    if name and realm then
        return name, realm
    end
    -- Same-realm character — append current realm
    return fullName, GetCleanRealm()
end

--- Public wrapper around the local ParseFullName helper.
--- Used by other modules (e.g. DataCollector) that have a fullName string.
function GuildManager:SplitFullName(fullName)
    return ParseFullName(fullName)
end

--- Build the canonical member key used as the DB table key.
--- The key is always lowercase "name-realm" to avoid case-sensitivity issues.
function GuildManager:GetMemberKey(name, realm)
    return (name .. "-" .. realm):lower()
end

--- Return the canonical key for the currently logged-in player.
function GuildManager:GetMyKey()
    local name  = UnitName("player") or ""
    local realm = GetCleanRealm()
    return self:GetMemberKey(name, realm)
end

-- -------------------------------------------------------------------------
-- Initialisation
-- -------------------------------------------------------------------------

--- Called by the main addon after the DB has been loaded.
--- @param db table  Reference to GuildPvPLadderDB
function GuildManager:Initialize(db)
    self.db = db
    self.db.members = self.db.members or {}
    self:RefreshRoster()
end

-- -------------------------------------------------------------------------
-- Roster refresh
-- -------------------------------------------------------------------------

--- Default member record template.
local function NewMemberRecord(name, realm, classFileName, rankIndex, rankName)
    return {
        name          = name,
        realm         = realm,
        class         = classFileName or "UNKNOWN",
        guildRank     = rankIndex     or 0,
        guildRankName = rankName      or "",
        ratings       = { ["2v2"] = 0, ["3v3"] = 0, ["rbg"] = 0, ["soloshuffle"] = 0, ["blitz"] = 0 },
        achievements  = {
            gladiator    = false,
            duelist      = false,
            rival        = false,
            challenger   = false,
            heroAlliance = false,
            heroHorde    = false,
        },
        customPvPRank = nil,
        lastUpdated   = 0,
    }
end

--- Iterate the guild roster and upsert every member into db.members.
--- Call GuildInfo() first to ensure the roster is fully populated.
function GuildManager:RefreshRoster()
    if not IsInGuild() then return end

    C_GuildInfo.GuildRoster() -- request a server-side refresh of the roster cache

    local db      = self.db
    local members = db.members
    local total   = GetNumGuildMembers()

    for i = 1, total do
        -- GetGuildRosterInfo returns:
        -- fullName, rankName, rankIndex, level, classDisplayName, zone,
        -- note, officerNote, isOnline, status, classFileName,
        -- achievementPoints, achievementRank, isMobile, canSoR,
        -- repStanding, GUID
        local fullName, rankName, rankIndex, _level, _classDisplay,
              _zone, _note, _officerNote, _isOnline, _status, classFileName =
              GetGuildRosterInfo(i)

        if fullName then
            local name, realm = ParseFullName(fullName)
            local key         = self:GetMemberKey(name, realm)

            if members[key] then
                -- Update mutable roster fields only; preserve ratings/achiev.
                members[key].name          = name
                members[key].realm         = realm
                members[key].class         = classFileName or members[key].class
                members[key].guildRank     = rankIndex     or members[key].guildRank
                members[key].guildRankName = rankName      or members[key].guildRankName
            else
                -- First time we see this member — create a full record.
                members[key] = NewMemberRecord(name, realm, classFileName, rankIndex, rankName)
            end
        end
    end
end

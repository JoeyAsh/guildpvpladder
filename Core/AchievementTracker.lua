-- GuildPvPLadder: Core/AchievementTracker.lua
-- Reads the current player's PvP achievements and persists them.

GuildPvPLadder = GuildPvPLadder or {}
GuildPvPLadder.AchievementTracker = GuildPvPLadder.AchievementTracker or {}
local AchievementTracker = GuildPvPLadder.AchievementTracker

local L = GPVPL_L

-- -------------------------------------------------------------------------
-- Achievement ID table
-- GetAchievementInfo returns (positional):
--   1:id  2:name  3:points  4:completed  5:month  6:day  7:year
--   8:description  9:flags  10:icon  11:rewardText  12:isGuild
--   13:wasEarnedByMe  14:earnedBy
-- We use index 13 (wasEarnedByMe) to determine whether the *current*
-- player has earned the achievement.
-- -------------------------------------------------------------------------
local ACHIEVEMENT_IDS = {
    gladiator    = 2090,
    duelist      = 2092,
    rival        = 2093,
    challenger   = 2091,
    heroAlliance = 659,
    heroHorde    = 660,
}

-- -------------------------------------------------------------------------
-- Initialisation
-- -------------------------------------------------------------------------

--- Called by the main addon after the DB has been loaded.
--- Stores a db reference and makes the achievement ID table accessible on
--- the module so other systems can inspect it if needed.
--- @param db table  Reference to GuildPvPLadderDB
function AchievementTracker:Initialize(db)
    self.db             = db
    self.db.members     = self.db.members or {}
    self.achievementIds = ACHIEVEMENT_IDS
end

-- -------------------------------------------------------------------------
-- Achievement retrieval
-- -------------------------------------------------------------------------

--- Query the game client for every tracked achievement and return the
--- results as a plain boolean table.
---
--- @return table  { gladiator=bool, duelist=bool, rival=bool,
---                  challenger=bool, heroAlliance=bool, heroHorde=bool }
function AchievementTracker:GetMyAchievements()
    local result = {}
    for achievKey, achId in pairs(ACHIEVEMENT_IDS) do
        -- wasEarnedByMe is the 13th return value of GetAchievementInfo.
        local wasEarnedByMe = select(13, GetAchievementInfo(achId))
        result[achievKey] = wasEarnedByMe and true or false
    end
    return result
end

-- -------------------------------------------------------------------------
-- DB persistence
-- -------------------------------------------------------------------------

--- Fetch the current player's achievements and write them into db.members,
--- creating a minimal stub record if GuildManager has not added one yet.
function AchievementTracker:UpdateMyAchievements()
    local key     = GuildPvPLadder.GuildManager:GetMyKey()
    local members = self.db.members

    -- Ensure a record exists for the current player.
    if not members[key] then
        local name, realm = UnitName("player"), (GetRealmName() or ""):gsub("%s+", "")
        members[key] = {
            name          = name or "",
            realm         = realm,
            class         = select(2, UnitClass("player")) or "UNKNOWN",
            guildRank     = 0,
            guildRankName = "",
            ratings       = { ["2v2"] = 0, ["3v3"] = 0, ["rbg"] = 0, ["soloshuffle"] = 0 },
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

    local achievements = self:GetMyAchievements()
    local record       = members[key]

    record.achievements.gladiator    = achievements.gladiator
    record.achievements.duelist      = achievements.duelist
    record.achievements.rival        = achievements.rival
    record.achievements.challenger   = achievements.challenger
    record.achievements.heroAlliance = achievements.heroAlliance
    record.achievements.heroHorde    = achievements.heroHorde
    record.lastUpdated               = time()
end

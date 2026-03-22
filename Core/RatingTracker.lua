-- GuildPvPLadder: Core/RatingTracker.lua
-- Reads the current player's rated PvP bracket ratings and persists them.

GuildPvPLadder = GuildPvPLadder or {}
GuildPvPLadder.RatingTracker = GuildPvPLadder.RatingTracker or {}
local RatingTracker = GuildPvPLadder.RatingTracker

local L = GPVPL_L

-- -------------------------------------------------------------------------
-- Bracket index mapping
-- GetInspectArenaData bracket indices (retail 11.0+):
--   1 = 2v2
--   2 = 3v3
--   4 = RBG
--   7 = Solo Shuffle
-- GetPersonalRatedInfo was removed; GetInspectArenaData works for self too.
-- -------------------------------------------------------------------------
local BRACKET_INDEX = {
    ["2v2"]         = 1,
    ["3v3"]         = 2,
    ["rbg"]         = 4,
    ["soloshuffle"] = 7,
}

-- -------------------------------------------------------------------------
-- Initialisation
-- -------------------------------------------------------------------------

--- Called by the main addon after the DB has been loaded.
--- @param db table  Reference to GuildPvPLadderDB
function RatingTracker:Initialize(db)
    self.db = db
    self.db.members = self.db.members or {}
    self._pendingBroadcast = false
end

-- -------------------------------------------------------------------------
-- Rating retrieval
-- -------------------------------------------------------------------------

--- Query the game client for the current player's ratings in all four
--- tracked brackets and return them as a plain table.
---
--- GetPersonalRatedInfo returns:
---   rating, seasonBest, weeklyBest, seasonPlayed, seasonWon,
---   weeklyPlayed, weeklyWon, lastSeasonBest, hasWon, tier
---
--- @return table  { ["2v2"]=n, ["3v3"]=n, ["rbg"]=n, ["soloshuffle"]=n }
function RatingTracker:GetMyRatings()
    local ratings = {}
    for bracketName, bracketIdx in pairs(BRACKET_INDEX) do
        -- GetInspectArenaData replaced GetPersonalRatedInfo (removed in 11.0).
        -- Returns: rating, seasonPlayed, seasonWon, weeklyPlayed, weeklyWon
        local rating = GetInspectArenaData(bracketIdx)
        ratings[bracketName] = rating or 0
    end
    return ratings
end

-- -------------------------------------------------------------------------
-- Inspect-based self-rating fetch
-- -------------------------------------------------------------------------

--- Request the game to load our own inspect data so GetInspectArenaData works.
--- Call this on login; ratings are written when INSPECT_READY fires.
function RatingTracker:RequestInspect()
    self._pendingBroadcast = true
    NotifyInspect("player")
end

--- Called from the INSPECT_READY event handler in the main addon.
--- Reads bracket ratings and triggers a broadcast if the inspect was ours.
function RatingTracker:OnInspectReady(guid)
    if not self._pendingBroadcast then return end
    local playerGUID = UnitGUID("player")
    if guid and guid ~= "" and guid ~= playerGUID then return end
    self._pendingBroadcast = false
    self:UpdateMyRatings()
    if GuildPvPLadder.DataCollector then
        GuildPvPLadder.DataCollector:CollectAndBroadcast()
    end
end

-- -------------------------------------------------------------------------
-- DB persistence
-- -------------------------------------------------------------------------

--- Fetch the current player's ratings and write them into db.members,
--- creating a minimal stub record if the GuildManager has not added one yet.
function RatingTracker:UpdateMyRatings()
    local key = GuildPvPLadder.GuildManager:GetMyKey()
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

    local ratings = self:GetMyRatings()
    local record  = members[key]

    record.ratings["2v2"]         = ratings["2v2"]
    record.ratings["3v3"]         = ratings["3v3"]
    record.ratings["rbg"]         = ratings["rbg"]
    record.ratings["soloshuffle"] = ratings["soloshuffle"]
    record.lastUpdated            = time()
end

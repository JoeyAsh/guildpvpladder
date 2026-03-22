-- GuildPvPLadder: Core/DataCollector.lua
-- Collects the current player's data and broadcasts/receives addon messages
-- to synchronise ratings, achievements, and custom ranks across the guild.

GuildPvPLadder = GuildPvPLadder or {}
GuildPvPLadder.DataCollector = GuildPvPLadder.DataCollector or {}
local DataCollector = GuildPvPLadder.DataCollector

local L              = GPVPL_L
local ADDON_PREFIX   = "GPVPL"
local BROADCAST_COOLDOWN = 30  -- seconds between outgoing broadcasts

-- Bracket indices shared with RatingTracker (kept local to avoid cross-module dep)
local BRACKET_INDEX = {
    ["2v2"]         = 1,
    ["3v3"]         = 2,
    ["rbg"]         = 4,
    ["soloshuffle"] = 7,
    ["blitz"]       = 8,
}

-- Guild member inspect queue state
local inspectQueue       = {}   -- ordered list of GUIDs to inspect
local inspectGUIDToKey   = {}   -- GUID → db member key
local currentInspectGUID = nil  -- GUID we're currently waiting on

-- -------------------------------------------------------------------------
-- Initialisation
-- -------------------------------------------------------------------------

--- Called by the main addon after the DB has been loaded.
--- Registers the addon message prefix so we can receive GPVPL messages.
--- @param db table  Reference to GuildPvPLadderDB
function DataCollector:Initialize(db)
    self.db                = db
    self.db.members        = self.db.members or {}
    self.lastBroadcastTime = 0

    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
end

-- -------------------------------------------------------------------------
-- Outgoing messages
-- -------------------------------------------------------------------------

--- Collect own ratings and achievements, persist them to the DB, then
--- broadcast both update messages to the guild channel.
--- Silently skips if the cooldown has not expired.
function DataCollector:CollectAndBroadcast()
    local now = time()
    if (now - self.lastBroadcastTime) < BROADCAST_COOLDOWN then
        return
    end
    self.lastBroadcastTime = now

    -- Persist latest data first.
    local RT = GuildPvPLadder.RatingTracker
    local AT = GuildPvPLadder.AchievementTracker
    local GM = GuildPvPLadder.GuildManager

    RT:UpdateMyRatings()
    AT:UpdateMyAchievements()

    local key    = GM:GetMyKey()
    local record = self.db.members[key]
    if not record then return end

    -- Build and send RATING_UPDATE message.
    -- Format: RATING_UPDATE:Name-Realm|2v2|3v3|rbg|solo|blitz
    local ratingMsg = string.format(
        "RATING_UPDATE:%s-%s|%d|%d|%d|%d|%d",
        record.name,
        record.realm,
        record.ratings["2v2"]         or 0,
        record.ratings["3v3"]         or 0,
        record.ratings["rbg"]         or 0,
        record.ratings["soloshuffle"] or 0,
        record.ratings["blitz"]       or 0
    )
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, ratingMsg, "GUILD")

    -- Build and send ACH_UPDATE message.
    -- Format: ACH_UPDATE:Name-Realm|glad,duel,rival,chall,heroA,heroH  (1/0)
    local function b(v) return v and 1 or 0 end
    local ach = record.achievements
    local achMsg = string.format(
        "ACH_UPDATE:%s-%s|%d,%d,%d,%d,%d,%d",
        record.name,
        record.realm,
        b(ach.gladiator),
        b(ach.duelist),
        b(ach.rival),
        b(ach.challenger),
        b(ach.heroAlliance),
        b(ach.heroHorde)
    )
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, achMsg, "GUILD")
end

--- Broadcast a REQUEST_DATA message asking all guild members who have the
--- addon to respond with their own data.  Also kicks off a fresh inspect
--- sweep so ratings appear even for members without the addon.
function DataCollector:RequestGuildData()
    local name, realm = UnitName("player"), (GetRealmName() or ""):gsub("%s+", "")
    local msg = string.format("REQUEST_DATA:%s-%s", name, realm)
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, msg, "GUILD")
    self:QueueGuildInspects()
end

-- -------------------------------------------------------------------------
-- Incoming messages
-- -------------------------------------------------------------------------

--- Parse an incoming addon message and update db.members accordingly.
--- This should be wired up to the CHAT_MSG_ADDON event in the main addon.
---
--- @param prefix  string  The addon message prefix (should be "GPVPL")
--- @param message string  The raw message payload
--- @param channel string  The channel ("GUILD", "WHISPER", etc.)
--- @param sender  string  The sender ("Name-Realm" or just "Name" on same realm)
function DataCollector:HandleAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end

    local msgType, payload = message:match("^([^:]+):(.+)$")
    if not msgType or not payload then return end

    local members = self.db.members

    -- ------------------------------------------------------------------
    -- RATING_UPDATE:Name-Realm|2v2|3v3|rbg|solo
    -- ------------------------------------------------------------------
    if msgType == "RATING_UPDATE" then
        -- Try new 5-value format first (with blitz), fall back to old 4-value format
        local nameRealm, r2v2, r3v3, rRBG, rSolo, rBlitz =
            payload:match("^([^|]+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$")
        if not nameRealm then
            nameRealm, r2v2, r3v3, rRBG, rSolo =
                payload:match("^([^|]+)|(%d+)|(%d+)|(%d+)|(%d+)$")
            rBlitz = "0"
        end
        if not nameRealm then return end

        local key = nameRealm:lower()
        members[key] = members[key] or self:_StubRecord(nameRealm)

        members[key].ratings["2v2"]         = tonumber(r2v2)   or 0
        members[key].ratings["3v3"]         = tonumber(r3v3)   or 0
        members[key].ratings["rbg"]         = tonumber(rRBG)   or 0
        members[key].ratings["soloshuffle"] = tonumber(rSolo)  or 0
        members[key].ratings["blitz"]       = tonumber(rBlitz) or 0
        members[key].lastUpdated            = time()

    -- ------------------------------------------------------------------
    -- ACH_UPDATE:Name-Realm|glad,duel,rival,chall,heroA,heroH
    -- ------------------------------------------------------------------
    elseif msgType == "ACH_UPDATE" then
        local nameRealm, achStr =
            payload:match("^([^|]+)|(.+)$")
        if not nameRealm or not achStr then return end

        local vals = {}
        for v in achStr:gmatch("[^,]+") do
            vals[#vals + 1] = tonumber(v)
        end
        if #vals < 6 then return end

        local key = nameRealm:lower()
        members[key] = members[key] or self:_StubRecord(nameRealm)

        local ach = members[key].achievements
        ach.gladiator    = vals[1] == 1
        ach.duelist      = vals[2] == 1
        ach.rival        = vals[3] == 1
        ach.challenger   = vals[4] == 1
        ach.heroAlliance = vals[5] == 1
        ach.heroHorde    = vals[6] == 1
        members[key].lastUpdated = time()

    -- ------------------------------------------------------------------
    -- RANK_SET:Name-Realm|customRankTitle
    -- ------------------------------------------------------------------
    elseif msgType == "RANK_SET" then
        local nameRealm, rankTitle =
            payload:match("^([^|]+)|(.*)$")
        if not nameRealm then return end

        local key = nameRealm:lower()
        members[key] = members[key] or self:_StubRecord(nameRealm)

        -- An empty rankTitle clears the custom rank.
        members[key].customPvPRank = (rankTitle ~= "") and rankTitle or nil
        members[key].lastUpdated   = time()

    -- ------------------------------------------------------------------
    -- REQUEST_DATA:Name-Realm  — someone is asking for our data
    -- ------------------------------------------------------------------
    elseif msgType == "REQUEST_DATA" then
        -- Respond by broadcasting our own current data.
        -- We intentionally reset the cooldown guard so our response goes
        -- through even if we broadcast recently (the requester needs data).
        self.lastBroadcastTime = 0
        self:CollectAndBroadcast()
    end
end

-- -------------------------------------------------------------------------
-- Guild member inspect queue
-- Fetches bracket ratings for online guild members via the inspect API so
-- we show real ratings even for members who don't have the addon installed.
-- -------------------------------------------------------------------------

--- Build an ordered queue of online guild-member GUIDs and start inspecting.
function DataCollector:QueueGuildInspects()
    inspectQueue     = {}
    inspectGUIDToKey = {}
    currentInspectGUID = nil

    local myGUID  = UnitGUID("player")
    local GM      = GuildPvPLadder.GuildManager
    local total   = GetNumGuildMembers()

    for i = 1, total do
        -- 17th return value of GetGuildRosterInfo is the member GUID
        local fullName, _, _, _, _, _, _, _, isOnline,
              _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)

        if fullName and isOnline and guid and guid ~= "" and guid ~= myGUID then
            local name, realm = GM:SplitFullName(fullName)
            local key = GM:GetMemberKey(name, realm)
            inspectGUIDToKey[guid] = key
            inspectQueue[#inspectQueue + 1] = guid
        end
    end

    self:_NextInspect()
end

--- Return the unit ID ("party1", "raid2", …) for a GUID if the member is
--- in our current group, otherwise return the GUID itself as a fallback.
local function UnitIdForGUID(guid)
    for i = 1, 4 do
        local uid = "party" .. i
        if UnitExists(uid) and UnitGUID(uid) == guid then return uid end
    end
    for i = 1, 40 do
        local uid = "raid" .. i
        if UnitExists(uid) and UnitGUID(uid) == guid then return uid end
    end
    return guid  -- fall back: pass GUID directly (works in retail TWW)
end

--- Pop the next GUID from the queue and request an inspect.
--- Falls through automatically after 5 s if INSPECT_READY never fires.
function DataCollector:_NextInspect()
    if #inspectQueue == 0 then
        currentInspectGUID = nil
        return
    end

    local guid = table.remove(inspectQueue, 1)
    currentInspectGUID = guid
    NotifyInspect(UnitIdForGUID(guid))

    -- Safety timeout: if the server never responds, advance the queue anyway.
    C_Timer.After(5, function()
        if currentInspectGUID == guid then
            currentInspectGUID = nil
            DataCollector:_NextInspect()
        end
    end)
end

--- Find the DB member key for a GUID.  Checks the pre-built map first,
--- then falls back to scanning the full roster (covers user right-click
--- inspects where we didn't queue the request ourselves).
function DataCollector:_FindMemberKeyByGUID(guid)
    if inspectGUIDToKey[guid] then
        return inspectGUIDToKey[guid]
    end
    local GM    = GuildPvPLadder.GuildManager
    local total = GetNumGuildMembers()
    for i = 1, total do
        local fullName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, memberGUID =
            GetGuildRosterInfo(i)
        if memberGUID == guid and fullName then
            local name, realm = GM:SplitFullName(fullName)
            local key = GM:GetMemberKey(name, realm)
            inspectGUIDToKey[guid] = key  -- cache for next time
            return key
        end
    end
    return nil
end

--- Called from the INSPECT_READY handler.
--- Captures bracket ratings for ANY guild member inspect — whether we
--- queued it ourselves or the user right-clicked and inspected someone.
function DataCollector:OnMemberInspectReady(guid)
    local key = self:_FindMemberKeyByGUID(guid)
    if key and self.db.members[key] then
        local record = self.db.members[key]
        for bracketName, bracketIdx in pairs(BRACKET_INDEX) do
            local rating = GetInspectArenaData(bracketIdx)
            record.ratings[bracketName] = rating or 0
        end
        record.lastUpdated = time()

        if GuildPvPLadder.UI and GuildPvPLadder.UI.frame
                and GuildPvPLadder.UI.frame:IsShown() then
            GuildPvPLadder.UI:Refresh()
        end
    end

    -- If this was a queued inspect, clear the guard and advance the queue.
    if guid == currentInspectGUID then
        currentInspectGUID = nil
        C_Timer.After(1.5, function()
            DataCollector:_NextInspect()
        end)
    end
end

-- -------------------------------------------------------------------------
-- Private helpers
-- -------------------------------------------------------------------------

--- Create a minimal stub DB record from a "Name-Realm" string.
--- Used when an addon message arrives for a member not yet in the DB.
--- @param  nameRealm string  e.g. "Thrall-Kazzak"
--- @return table
function DataCollector:_StubRecord(nameRealm)
    local name, realm = nameRealm:match("^(.+)-(.+)$")
    if not name then
        name  = nameRealm
        realm = (GetRealmName() or ""):gsub("%s+", "")
    end
    return {
        name          = name,
        realm         = realm,
        class         = "UNKNOWN",
        guildRank     = 0,
        guildRankName = "",
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

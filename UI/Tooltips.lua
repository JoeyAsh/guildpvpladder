-- GuildPvPLadder: UI/Tooltips.lua
-- GameTooltip population for ladder rows.

GuildPvPLadder = GuildPvPLadder or {}
GuildPvPLadder.Tooltips = GuildPvPLadder.Tooltips or {}
local Tooltips = GuildPvPLadder.Tooltips

-------------------------------------------------------------------------------
-- Helper: get a class color ARGB table (r,g,b floats 0-1)
-------------------------------------------------------------------------------
local function GetClassColor(classToken)
    if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        return RAID_CLASS_COLORS[classToken]
    end
    return { r = 1, g = 1, b = 1 }
end

-------------------------------------------------------------------------------
-- Helper: format a timestamp as "X minutes ago" / "X hours ago" / "just now"
-------------------------------------------------------------------------------
local function FormatTimeAgo(timestamp)
    if not timestamp or timestamp == 0 then
        return "Never"
    end
    local elapsed = time() - timestamp
    if elapsed < 60 then
        return "Just now"
    elseif elapsed < 3600 then
        local mins = math.floor(elapsed / 60)
        return mins .. (mins == 1 and " minute ago" or " minutes ago")
    elseif elapsed < 86400 then
        local hours = math.floor(elapsed / 3600)
        return hours .. (hours == 1 and " hour ago" or " hours ago")
    else
        local days = math.floor(elapsed / 86400)
        return days .. (days == 1 and " day ago" or " days ago")
    end
end

-------------------------------------------------------------------------------
-- Helper: format a rating for tooltip display
-------------------------------------------------------------------------------
local function FormatRating(val)
    if not val or val == 0 then return "|cff888888--|r" end
    -- Color-code by rough bracket
    if val >= 2400 then
        return "|cffff8000" .. tostring(val) .. "|r"   -- Gladiator orange
    elseif val >= 2100 then
        return "|cffa335ee" .. tostring(val) .. "|r"   -- Duelist purple
    elseif val >= 1800 then
        return "|cff0070dd" .. tostring(val) .. "|r"   -- Rival blue
    elseif val >= 1550 then
        return "|cff1eff00" .. tostring(val) .. "|r"   -- Challenger green
    else
        return "|cffffffff" .. tostring(val) .. "|r"   -- White
    end
end

-------------------------------------------------------------------------------
-- ShowPlayerTooltip
-- frame      : the row frame to anchor the tooltip to
-- memberData : the DB entry for this player
-------------------------------------------------------------------------------
function Tooltips.ShowPlayerTooltip(frame, memberData)
    if not frame or not memberData then return end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    -- Title: Name-Realm colored by class
    local classColor = GetClassColor(memberData.class)
    local nameStr    = memberData.name or "Unknown"
    local realmStr   = memberData.realm or ""
    local fullName   = realmStr ~= "" and (nameStr .. "-" .. realmStr) or nameStr
    GameTooltip:AddLine(fullName, classColor.r, classColor.g, classColor.b)

    -- Class name (if we can look it up)
    if memberData.class then
        local classDisplayName = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[memberData.class]
        if classDisplayName then
            GameTooltip:AddLine(classDisplayName, classColor.r, classColor.g, classColor.b, false)
        end
    end

    -- Guild Rank
    if memberData.guildRankName then
        GameTooltip:AddDoubleLine("Guild Rank:", memberData.guildRankName, 0.7, 0.7, 0.7, 1, 1, 1)
    end

    -- Spacer
    GameTooltip:AddLine(" ")

    -- Ratings section header
    GameTooltip:AddLine("PvP Ratings", 1, 0.82, 0)

    local ratings = memberData.ratings or {}
    GameTooltip:AddDoubleLine("  2v2:",         FormatRating(ratings["2v2"]),        0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("  3v3:",         FormatRating(ratings["3v3"]),        0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("  RBG:",         FormatRating(ratings["rbg"]),        0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("  Solo Shuffle:", FormatRating(ratings["soloshuffle"]), 0.7, 0.7, 0.7, 1, 1, 1)

    -- Achievements section
    local achievements = memberData.achievements
    if achievements then
        local earned = {}
        if achievements.gladiator    then earned[#earned+1] = "|cffff8000Gladiator|r"         end
        if achievements.duelist      then earned[#earned+1] = "|cffa335eeDuelist|r"           end
        if achievements.rival        then earned[#earned+1] = "|cff0070ddRival|r"             end
        if achievements.challenger   then earned[#earned+1] = "|cff1eff00Challenger|r"        end
        if achievements.heroAlliance then earned[#earned+1] = "|cff00aaffHero (Alliance)|r"   end
        if achievements.heroHorde    then earned[#earned+1] = "|cffcc0000Hero (Horde)|r"      end

        if #earned > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Achievements", 1, 0.82, 0)
            for _, label in ipairs(earned) do
                GameTooltip:AddLine("  " .. label)
            end
        end
    end

    -- Custom PvP Rank badge
    if memberData.customPvPRank and memberData.customPvPRank ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("PvP Rank:", "|cffd4af37" .. memberData.customPvPRank .. "|r", 0.7, 0.7, 0.7, 1, 1, 1)
    end

    -- Last updated timestamp
    GameTooltip:AddLine(" ")
    local timeAgo = FormatTimeAgo(memberData.lastUpdated)
    GameTooltip:AddDoubleLine("Last updated:", timeAgo, 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)

    GameTooltip:Show()
end

-- GuildPvPLadder: UI/LadderRow.lua
-- Individual row creation and data population for the PvP ladder list.

GuildPvPLadder = GuildPvPLadder or {}
GuildPvPLadder.LadderRow = GuildPvPLadder.LadderRow or {}
local LadderRow = GuildPvPLadder.LadderRow

local ROW_HEIGHT   = 20
local ROW_WIDTH    = 570

-- Column x-offsets matching the header layout (left edge of each cell)
local COL_X = {
    rank      = 0,
    name      = 30,
    guildRank = 150,
    twov2     = 230,
    threev3   = 280,
    rbg       = 330,
    solo      = 380,
    blitz     = 430,
    pvpRank   = 480,
}

-- Column widths
local COL_W = {
    rank      = 28,
    name      = 118,
    guildRank = 78,
    twov2     = 48,
    threev3   = 48,
    rbg       = 48,
    solo      = 48,
    blitz     = 48,
    pvpRank   = 78,
}

-------------------------------------------------------------------------------
-- Helper: format a rating value for display
-------------------------------------------------------------------------------
local function FormatRating(val)
    if not val or val == 0 then
        return "|cff888888--|r"
    end
    return tostring(val)
end

-------------------------------------------------------------------------------
-- Helper: get class color hex string
-------------------------------------------------------------------------------
local function GetClassColorStr(classToken)
    if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        local c = RAID_CLASS_COLORS[classToken]
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return "|cffffffff"
end

-------------------------------------------------------------------------------
-- CreateRow: build the reusable frame for a single ladder row
-------------------------------------------------------------------------------
function LadderRow:CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

    -- Alternating background texture
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    if index % 2 == 0 then
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.25)
    else
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.10)
    end
    row.bg = bg

    -- Highlight texture on hover
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetColorTexture(1, 1, 1, 0.07)
    row:SetHighlightTexture(hl)

    -- FontStrings for each column
    local function MakeCell(xOffset, width, justifyH)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetWidth(width)
        fs:SetHeight(ROW_HEIGHT)
        fs:SetPoint("LEFT", row, "LEFT", xOffset, 0)
        fs:SetJustifyH(justifyH or "LEFT")
        fs:SetJustifyV("MIDDLE")
        return fs
    end

    row.cellRank      = MakeCell(COL_X.rank,      COL_W.rank,      "CENTER")
    row.cellName      = MakeCell(COL_X.name,      COL_W.name,      "LEFT")
    row.cellGuildRank = MakeCell(COL_X.guildRank, COL_W.guildRank, "LEFT")
    row.cell2v2       = MakeCell(COL_X.twov2,     COL_W.twov2,     "CENTER")
    row.cell3v3       = MakeCell(COL_X.threev3,   COL_W.threev3,   "CENTER")
    row.cellRBG       = MakeCell(COL_X.rbg,       COL_W.rbg,       "CENTER")
    row.cellSolo      = MakeCell(COL_X.solo,      COL_W.solo,      "CENTER")
    row.cellBlitz     = MakeCell(COL_X.blitz,     COL_W.blitz,     "CENTER")
    row.cellPvPRank   = MakeCell(COL_X.pvpRank,   COL_W.pvpRank,   "LEFT")

    -- Tooltip scripts
    row:SetScript("OnEnter", function(self)
        if self.memberData then
            GuildPvPLadder.Tooltips.ShowPlayerTooltip(self, self.memberData)
        end
    end)
    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Click script (reserved for future use, e.g. inspect)
    row:SetScript("OnClick", function(self, button)
        -- Right-click reserved for context menu expansion
    end)

    row.memberData = nil
    row.rowIndex   = index

    return row
end

-------------------------------------------------------------------------------
-- UpdateRow: populate an existing row frame with new rank + member data
-------------------------------------------------------------------------------
function LadderRow:UpdateRow(rowFrame, rankNum, memberData)
    rowFrame.memberData = memberData

    -- Update alternating background based on current visual rank
    if rankNum % 2 == 0 then
        rowFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.25)
    else
        rowFrame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.10)
    end

    -- Rank number
    rowFrame.cellRank:SetText(tostring(rankNum))

    -- Name: colored by class
    local classToken = memberData.class or ""
    local colorStr   = GetClassColorStr(classToken)
    local nameStr    = memberData.name or "Unknown"
    rowFrame.cellName:SetText(colorStr .. nameStr .. "|r")

    -- Guild rank name
    local gRankName = memberData.guildRankName or ""
    rowFrame.cellGuildRank:SetText("|cffaaaaaa" .. gRankName .. "|r")

    -- Ratings
    local ratings = memberData.ratings or {}
    rowFrame.cell2v2:SetText(FormatRating(ratings["2v2"]))
    rowFrame.cell3v3:SetText(FormatRating(ratings["3v3"]))
    rowFrame.cellRBG:SetText(FormatRating(ratings["rbg"]))
    rowFrame.cellSolo:SetText(FormatRating(ratings["soloshuffle"]))
    rowFrame.cellBlitz:SetText(FormatRating(ratings["blitz"]))

    -- Custom PvP Rank badge
    if memberData.customPvPRank and memberData.customPvPRank ~= "" then
        rowFrame.cellPvPRank:SetText("|cffd4af37" .. memberData.customPvPRank .. "|r")
    else
        rowFrame.cellPvPRank:SetText("")
    end
end

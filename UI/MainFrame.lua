-- GuildPvPLadder: UI/MainFrame.lua
-- Main window logic: sorting, filtering, row pooling, position persistence

local ADDON_NAME = "GuildPvPLadder"
GuildPvPLadder = GuildPvPLadder or {}
GuildPvPLadder.UI = GuildPvPLadder.UI or {}
local UI = GuildPvPLadder.UI

-- Column definitions: key, display label, width, sort key
local COLUMNS = {
    { key = "rank",        label = "#",        width = 30  },
    { key = "name",        label = "Name",     width = 120 },
    { key = "guildRank",   label = "G.Rank",   width = 80  },
    { key = "2v2",         label = "2v2",      width = 50  },
    { key = "3v3",         label = "3v3",      width = 50  },
    { key = "rbg",         label = "RBG",      width = 50  },
    { key = "soloshuffle", label = "Solo",     width = 50  },
    { key = "blitz",       label = "Blitz",    width = 50  },
    { key = "pvpRank",     label = "PvP Rank", width = 80  },
}

local ROW_POOL_SIZE = 20
local ROW_HEIGHT = 20

-- Internal state
local db               -- reference to GuildPvPLadderDB
local rowPool = {}     -- pool of reusable row frames
local activeRows = {}  -- currently visible rows
local filteredMembers = {} -- sorted+filtered member list
local currentFilter = ""

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------
function UI:Initialize(database)
    db = database

    local frame = GuildPvPLadderFrame
    UI.frame = frame

    -- Ensure backdrop renders in WoW Retail 9.0+ (BackdropTemplate mixin)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    -- Header row: dark background + force button text (plain <Button> in XML has no
    -- implicit NormalText FontString, so <NormalText> is silently ignored; SetText()
    -- creates it correctly at runtime).
    local headerFrame = GuildPvPLadderFrameHeaders
    if headerFrame then
        local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
        headerBg:SetAllPoints(headerFrame)
        headerBg:SetColorTexture(0, 0, 0, 0.45)

        -- Vertical divider between Name section and rating columns
        local divider = headerFrame:CreateTexture(nil, "ARTWORK")
        divider:SetSize(1, 18)
        divider:SetPoint("LEFT", headerFrame, "LEFT", 228, 0)
        divider:SetColorTexture(0.5, 0.5, 0.5, 0.6)

        -- Highlight the rating-column area with a subtle tinted strip (5 cols × 50px)
        local ratingBg = headerFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
        ratingBg:SetSize(250, 22)
        ratingBg:SetPoint("LEFT", headerFrame, "LEFT", 229, 0)
        ratingBg:SetColorTexture(0.1, 0.3, 0.4, 0.35)

        -- Force-create label FontStrings for each header button.
        -- r=1 means it's a rating column (gold tint), r=0 means info column (white).
        local headerDefs = {
            { btn = headerFrame.rankBtn,    text = "#",        r = 0 },
            { btn = headerFrame.nameBtn,    text = "Name",     r = 0 },
            { btn = headerFrame.grankBtn,   text = "G.Rank",   r = 0 },
            { btn = headerFrame.twov2Btn,   text = "2v2",      r = 1 },
            { btn = headerFrame.threev3Btn, text = "3v3",      r = 1 },
            { btn = headerFrame.rbgBtn,     text = "RBG",      r = 1 },
            { btn = headerFrame.soloBtn,    text = "Solo",     r = 1 },
            { btn = headerFrame.blitzBtn,   text = "Blitz",    r = 1 },
            { btn = headerFrame.pvpRankBtn, text = "PvP Rank", r = 0 },
        }
        for _, def in ipairs(headerDefs) do
            if def.btn then
                def.btn:SetNormalFontObject("GameFontNormalSmall")
                def.btn:SetText(def.text)
                local fs = def.btn:GetFontString()
                if fs then
                    if def.r == 1 then
                        fs:SetTextColor(1, 0.9, 0.4, 1)   -- gold for rating cols
                    else
                        fs:SetTextColor(0.9, 0.9, 0.9, 1) -- white for info cols
                    end
                end
            end
        end
    end

    -- Pre-create row pool
    local scrollChild = GuildPvPLadderScrollChild
    for i = 1, ROW_POOL_SIZE do
        local row = GuildPvPLadder.LadderRow:CreateRow(scrollChild, i)
        row:Hide()
        rowPool[i] = row
    end

    -- Load saved window position
    UI:LoadWindowPosition()

    -- Register ESC to close
    tinsert(UISpecialFrames, "GuildPvPLadderFrame")
end

-------------------------------------------------------------------------------
-- Show / Hide / Toggle
-------------------------------------------------------------------------------
function UI:Toggle()
    if GuildPvPLadderFrame:IsShown() then
        UI:Hide()
    else
        UI:Show()
    end
end

function UI:Show()
    GuildPvPLadderFrame:Show()
    UI:Refresh()
end

function UI:Hide()
    GuildPvPLadderFrame:Hide()
end

-------------------------------------------------------------------------------
-- Window position persistence
-------------------------------------------------------------------------------
function UI:SaveWindowPosition()
    if not GuildPvPLadderCharDB then return end
    local frame = GuildPvPLadderFrame
    local point, _, relPoint, x, y = frame:GetPoint()
    GuildPvPLadderCharDB.windowPos = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y,
    }
end

function UI:LoadWindowPosition()
    if not GuildPvPLadderCharDB then return end
    local pos = GuildPvPLadderCharDB.windowPos
    if pos and pos.point then
        GuildPvPLadderFrame:ClearAllPoints()
        GuildPvPLadderFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

-------------------------------------------------------------------------------
-- Sorting
-------------------------------------------------------------------------------
function UI:SortBy(columnKey)
    if not db or not db.config then return end
    if db.config.defaultSort == columnKey then
        db.config.sortAscending = not db.config.sortAscending
    else
        db.config.defaultSort = columnKey
        -- Default to descending for ratings, ascending for names/ranks
        if columnKey == "name" or columnKey == "guildRank" or columnKey == "rank" then
            db.config.sortAscending = true
        else
            db.config.sortAscending = false
        end
    end
    UI:Refresh()
end

local function GetSortValue(member, key)
    if key == "name" then
        return member.name or ""
    elseif key == "guildRank" then
        return member.guildRank or 99
    elseif key == "2v2" or key == "3v3" or key == "rbg" or key == "soloshuffle" or key == "blitz" then
        return (member.ratings and member.ratings[key]) or 0
    elseif key == "pvpRank" then
        return member.customPvPRank or ""
    end
    return 0
end

local function SortMembers(memberList, sortKey, ascending)
    table.sort(memberList, function(a, b)
        local va = GetSortValue(a, sortKey)
        local vb = GetSortValue(b, sortKey)
        if type(va) == "string" and type(vb) == "string" then
            if ascending then
                return va:lower() < vb:lower()
            else
                return va:lower() > vb:lower()
            end
        else
            if ascending then
                return va < vb
            else
                return va > vb
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Filtering
-------------------------------------------------------------------------------
function UI:FilterRows(text)
    if text == "Search..." then text = "" end
    currentFilter = text:lower()
    UI:Refresh()
end

local function MemberMatchesFilter(member, filter)
    if filter == "" then return true end
    local name = (member.name or ""):lower()
    return name:find(filter, 1, true) ~= nil
end

-------------------------------------------------------------------------------
-- Refresh — rebuild the visible rows
-------------------------------------------------------------------------------
function UI:Refresh()
    if not db or not db.members then return end
    if not GuildPvPLadderFrame:IsShown() then return end

    -- Hide all rows first
    for i = 1, #rowPool do
        rowPool[i]:Hide()
    end
    activeRows = {}

    -- Build sorted member list
    local members = {}
    for _, memberData in pairs(db.members) do
        -- Optionally filter offline members
        if db.config and not db.config.showOfflineMembers then
            -- only include if online (if there's an online flag; otherwise include all)
            if memberData.online ~= false then
                members[#members + 1] = memberData
            end
        else
            members[#members + 1] = memberData
        end
    end

    local sortKey = (db.config and db.config.defaultSort) or "3v3"
    local ascending = (db.config and db.config.sortAscending) or false
    SortMembers(members, sortKey, ascending)

    -- Apply search filter
    filteredMembers = {}
    for _, member in ipairs(members) do
        if MemberMatchesFilter(member, currentFilter) then
            filteredMembers[#filteredMembers + 1] = member
        end
    end

    -- Resize scroll child to fit all rows
    local scrollChild = GuildPvPLadderScrollChild
    local totalHeight = #filteredMembers * ROW_HEIGHT
    scrollChild:SetHeight(math.max(totalHeight, 20))

    -- Populate rows from pool (extend pool if needed)
    for i, memberData in ipairs(filteredMembers) do
        local row = rowPool[i]
        if not row then
            row = GuildPvPLadder.LadderRow:CreateRow(scrollChild, i)
            rowPool[i] = row
        end
        GuildPvPLadder.LadderRow:UpdateRow(row, i, memberData)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:Show()
        activeRows[#activeRows + 1] = row
    end

    -- Update sort indicator arrows on column headers
    UI:UpdateSortIndicators()
end

-------------------------------------------------------------------------------
-- Sort indicator arrows on headers
-------------------------------------------------------------------------------
function UI:UpdateSortIndicators()
    if not db or not db.config then return end
    local sortKey = db.config.defaultSort
    local ascending = db.config.sortAscending

    local headerFrame = GuildPvPLadderFrameHeaders
    if not headerFrame then return end

    local keyToBtn = {
        ["rank"]        = headerFrame.rankBtn,
        ["name"]        = headerFrame.nameBtn,
        ["guildRank"]   = headerFrame.grankBtn,
        ["2v2"]         = headerFrame.twov2Btn,
        ["3v3"]         = headerFrame.threev3Btn,
        ["rbg"]         = headerFrame.rbgBtn,
        ["soloshuffle"] = headerFrame.soloBtn,
        ["blitz"]       = headerFrame.blitzBtn,
        ["pvpRank"]     = headerFrame.pvpRankBtn,
    }

    local labels = {
        ["rank"]        = "#",
        ["name"]        = "Name",
        ["guildRank"]   = "G.Rank",
        ["2v2"]         = "2v2",
        ["3v3"]         = "3v3",
        ["rbg"]         = "RBG",
        ["soloshuffle"] = "Solo",
        ["blitz"]       = "Blitz",
        ["pvpRank"]     = "PvP Rank",
    }

    -- Rating columns get a brighter/distinct colour so they stand out
    local ratingKeys = { ["2v2"] = true, ["3v3"] = true, ["rbg"] = true, ["soloshuffle"] = true, ["blitz"] = true }

    for key, btn in pairs(keyToBtn) do
        if btn then
            local label = labels[key] or key
            local arrow = ""
            if key == sortKey then
                arrow = ascending and " |TInterface\\Buttons\\Arrow-Up-Up:12|t"
                                   or " |TInterface\\Buttons\\Arrow-Down-Up:12|t"
            end
            btn:SetText(label .. arrow)

            -- Colour: bright cyan for active rating sort, gold for rating columns, white for rest
            if key == sortKey and ratingKeys[key] then
                btn:GetFontString():SetTextColor(0.4, 1, 1, 1)
            elseif ratingKeys[key] then
                btn:GetFontString():SetTextColor(1, 0.9, 0.4, 1)
            elseif key == sortKey then
                btn:GetFontString():SetTextColor(1, 1, 0.4, 1)
            else
                btn:GetFontString():SetTextColor(0.8, 0.8, 0.8, 1)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- My Stats dialog
-------------------------------------------------------------------------------
function UI:ShowMyStats()
    if not db or not db.members then return end

    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    local key = playerName .. "-" .. playerRealm
    local memberData = db.members[key]

    if not memberData then
        -- Try without realm suffix for same-realm lookups
        for k, v in pairs(db.members) do
            if v.name == playerName then
                memberData = v
                break
            end
        end
    end

    -- Create or reuse the My Stats dialog
    if not UI.myStatsDialog then
        local dialog = CreateFrame("Frame", "GuildPvPLadderMyStats", UIParent, "BackdropTemplate")
        dialog:SetSize(280, 240)
        dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dialog:SetMovable(true)
        dialog:EnableMouse(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
        dialog:SetFrameStrata("TOOLTIP")
        dialog:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })

        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        title:SetPoint("TOP", dialog, "TOP", 0, -14)
        title:SetText("My PvP Stats")
        dialog.title = title

        local content = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        content:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -40)
        content:SetWidth(244)
        content:SetJustifyH("LEFT")
        dialog.content = content

        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() dialog:Hide() end)

        UI.myStatsDialog = dialog
    end

    local dialog = UI.myStatsDialog

    if not memberData then
        dialog.content:SetText("No data found for " .. playerName .. ".\n\nTry clicking Refresh first.")
    else
        local r2 = (memberData.ratings and memberData.ratings["2v2"]) or 0
        local r3 = (memberData.ratings and memberData.ratings["3v3"]) or 0
        local rbg = (memberData.ratings and memberData.ratings["rbg"]) or 0
        local solo = (memberData.ratings and memberData.ratings["soloshuffle"]) or 0

        local lines = {}
        lines[#lines+1] = "|cffffffff" .. (memberData.name or playerName) .. "|r"
        lines[#lines+1] = "Guild Rank: " .. (memberData.guildRankName or "Unknown")
        lines[#lines+1] = " "
        lines[#lines+1] = "|cffffff00Ratings:|r"
        lines[#lines+1] = "  2v2:         " .. (r2 > 0 and tostring(r2) or "--")
        lines[#lines+1] = "  3v3:         " .. (r3 > 0 and tostring(r3) or "--")
        lines[#lines+1] = "  RBG:         " .. (rbg > 0 and tostring(rbg) or "--")
        lines[#lines+1] = "  Solo Shuffle: " .. (solo > 0 and tostring(solo) or "--")

        if memberData.customPvPRank then
            lines[#lines+1] = " "
            lines[#lines+1] = "PvP Rank: |cffd4af37" .. memberData.customPvPRank .. "|r"
        end

        dialog.content:SetText(table.concat(lines, "\n"))
    end

    dialog:Show()
end

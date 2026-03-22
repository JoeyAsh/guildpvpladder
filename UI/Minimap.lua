-- GuildPvPLadder: UI/Minimap.lua
-- Circular draggable minimap button that toggles the main window.

GuildPvPLadder = GuildPvPLadder or {}
GuildPvPLadder.Minimap = GuildPvPLadder.Minimap or {}
local Minimap = GuildPvPLadder.Minimap

-- Radius of the orbit around the minimap edge (minimap radius ~70 + 10 padding)
local MINIMAP_RADIUS = 80
local BUTTON_SIZE    = 32
local ICON_TEXTURE   = "Interface\\Icons\\Achievement_PVP_A_01"

local db       -- reference to GuildPvPLadderDB
local button   -- the minimap button frame
local isDragging = false

-------------------------------------------------------------------------------
-- Helper: position the button at a given angle (degrees)
-------------------------------------------------------------------------------
local function SetButtonAngle(angle)
    local rad = math.rad(angle)
    local x   = math.cos(rad) * MINIMAP_RADIUS
    local y   = math.sin(rad) * MINIMAP_RADIUS
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap_GetReference(), "CENTER", x, y)
end

-- Returns the minimap reference frame (handles both "Minimap" and "MinimapCluster")
local function GetMinimapFrame()
    return Minimap  -- WoW global "Minimap" frame
end

-------------------------------------------------------------------------------
-- Angle persistence helpers
-------------------------------------------------------------------------------
local function SaveAngle(angle)
    if db and db.config and db.config.minimapButton then
        db.config.minimapButton.angle = angle
    end
end

local function LoadAngle()
    if db and db.config and db.config.minimapButton then
        return db.config.minimapButton.angle or 45
    end
    return 45
end

-------------------------------------------------------------------------------
-- Drag logic: calculate angle from cursor position relative to minimap center
-------------------------------------------------------------------------------
local function UpdateDragPosition()
    local mx, my = GetMinimapFrame():GetCenter()
    local cx, cy = GetCursorPosition()
    local scale  = UIParent:GetEffectiveScale()
    cx = cx / scale
    cy = cy / scale
    local angle = math.deg(math.atan2(cy - my, cx - mx))
    SetButtonAngle(angle)
    SaveAngle(angle)
end

-------------------------------------------------------------------------------
-- Right-click dropdown menu (MenuUtil API — EasyMenu removed in 11.0.0)
-------------------------------------------------------------------------------
local function CreateDropdownMenu()
    MenuUtil.CreateContextMenu(button, function(owner, rootDescription)
        rootDescription:CreateTitle("Guild PvP Ladder")
        rootDescription:CreateButton("Show Ladder", function()
            GuildPvPLadder.UI:Show()
        end)
        rootDescription:CreateButton("Hide Button", function()
            if db and db.config and db.config.minimapButton then
                db.config.minimapButton.hide = true
            end
            button:Hide()
        end)
    end)
end

-------------------------------------------------------------------------------
-- Initialize: create the minimap button
-------------------------------------------------------------------------------
function Minimap:Initialize(database)
    db = database

    -- Create the button frame
    button = CreateFrame("Button", "GuildPvPLadderMinimapButton", GetMinimapFrame())
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetMovable(true)
    button:EnableMouse(true)

    -- Circular mask / backdrop using a standard round button approach
    -- Outer border texture (circular frame)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(56, 56)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.border = border

    -- Background circle
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    bg:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.bg = bg

    -- Icon texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(BUTTON_SIZE - 4, BUTTON_SIZE - 4)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    -- Clip the icon to a circle via mask or just let it be square inside round border
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    -- Highlight
    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    hl:SetSize(BUTTON_SIZE + 8, BUTTON_SIZE + 8)
    hl:SetPoint("CENTER", button, "CENTER", 0, 0)
    hl:SetAlpha(0.5)
    button:SetHighlightTexture(hl)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Guild PvP Ladder", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click to toggle", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click for options", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag to reposition", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Left click: toggle main window
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "LeftButton" and not isDragging then
            GuildPvPLadder.UI:Toggle()
        elseif mouseButton == "RightButton" then
            CreateDropdownMenu()
        end
    end)

    -- Drag to reposition
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            isDragging = false
            self:SetScript("OnUpdate", function()
                isDragging = true
                UpdateDragPosition()
            end)
        end
    end)

    button:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self:SetScript("OnUpdate", nil)
            -- Small grace: if barely moved, treat as click (handled by OnClick firing first)
        end
    end)

    -- Position at saved angle
    local angle = LoadAngle()
    -- We defer the actual SetPoint until after all frames are laid out
    button:SetPoint("CENTER", GetMinimapFrame(), "CENTER", 0, 0)
    C_Timer.After(0, function()
        SetButtonAngle(angle)
    end)

    -- Hide if previously hidden
    if db and db.config and db.config.minimapButton and db.config.minimapButton.hide then
        button:Hide()
    end
end

-------------------------------------------------------------------------------
-- Toggle: show or hide the minimap button
-------------------------------------------------------------------------------
function Minimap:Toggle()
    if not button then return end
    if button:IsShown() then
        button:Hide()
        if db and db.config and db.config.minimapButton then
            db.config.minimapButton.hide = true
        end
    else
        button:Show()
        if db and db.config and db.config.minimapButton then
            db.config.minimapButton.hide = false
        end
        -- Re-apply position in case minimap moved
        SetButtonAngle(LoadAngle())
    end
end

-- Override the local GetMinimapFrame reference to avoid conflict with the global Minimap table
-- (WoW global "Minimap" frame vs our GuildPvPLadder.Minimap table)
-- We fix this by using the WoW API function directly:
do
    local _wowMinimap = _G["Minimap"]
    GetMinimapFrame = function()
        return _wowMinimap
    end
    SetButtonAngle = function(angle)
        local rad = math.rad(angle)
        local x   = math.cos(rad) * MINIMAP_RADIUS
        local y   = math.sin(rad) * MINIMAP_RADIUS
        if button then
            button:ClearAllPoints()
            button:SetPoint("CENTER", _wowMinimap, "CENTER", x, y)
        end
    end
end

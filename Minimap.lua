local addonName, ns = ...

-- ======================================================
--  :3 HideFrames - Minimap Button :3
--  a small orbiting icon, the way minimap buttons are
--  "supposed" to behave (angle-based, hugs the ring while
--  you drag, remembers its spot between sessions).
-- ======================================================

local button
local RADIUS = 80

local function UpdatePosition(angle)
    local rad = math.rad(angle)
    local x = math.cos(rad) * RADIUS
    local y = math.sin(rad) * RADIUS
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnUpdate(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale

    local angle = math.deg(math.atan2(py - my, px - mx))
    HideFramesDB.minimap.angle = angle
    UpdatePosition(angle)
end

local function CreateMinimapButton()
    button = CreateFrame("Button", "HideFramesMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- background ring so it reads as a "real" minimap button, not a floating icon
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetAllPoints()

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ns.Print("left-click toggles the window, that's the only trick i know :3")
        else
            ns.UI.Toggle()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.colors.blue .. "Hide" .. ns.colors.pink .. "Frames" .. ns.colors.reset, 1, 1, 1)
        GameTooltip:AddLine("Left-click: toggle window", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Right-click: hint", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Drag: move me around the ring", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    UpdatePosition(HideFramesDB.minimap.angle or 225)
end

-- created lazily after Core has set up saved variables
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not HideFramesDB.minimap.hide then
        CreateMinimapButton()
    end
end)

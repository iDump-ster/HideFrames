local addonName, ns = ...
local c = ns.colors

-- ======================================================
--  :3 HideFrames - UI :3
--  the config window: profile dropdown + CRUD buttons,
--  and the scrollable list of frames you're managing.
-- ======================================================

ns.UI = {}

local mainFrame
local profileDropdown
local rowPool = {}
local refreshQueued = false

-- ------------------------------------------------------
-- Small helper: batches RefreshList calls onto the next
-- frame instead of rebuilding the list synchronously
-- several times in a row (e.g. profile switch + checkbox
-- click happening back to back). Cheap insurance against
-- redundant layout work.
-- ------------------------------------------------------
local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        if mainFrame and mainFrame:IsShown() then
            ns.UI.RefreshList()
        end
    end)
end

-- ------------------------------------------------------
-- Static popups (confirmations)
-- ------------------------------------------------------
StaticPopupDialogs["HIDEFRAMES_DELETE_PROFILE"] = {
    text = "Delete profile %s? This can't be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, name)
        if ns.DeleteProfile(name) then
            ns.Print("deleted profile " .. c.pink .. name .. c.reset .. ". bye bye!")
            ns.UI.RefreshProfileDropdown()
            QueueRefresh()
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["HIDEFRAMES_RESET_PROFILE"] = {
    text = "Reset profile %s and show everything in it again?",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function(self, name)
        ns.ResetProfile(name)
        ns.Print("profile " .. c.pink .. name .. c.reset .. " reset, fresh start :3")
        QueueRefresh()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["HIDEFRAMES_TEXT_INPUT"] = {
    text = "%s",
    button1 = "Confirm",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        self.EditBox:SetFocus()
        self.EditBox:SetText("")
    end,
    OnHide = function(self)
        self.EditBox:SetText("")
    end,
    OnAccept = function(self)
        local text = strtrim(self.EditBox:GetText() or "")
        if self.data and self.data.callback then self.data.callback(text) end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local text = strtrim(self:GetText() or "")
        if parent.data.callback then parent.data.callback(text) end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local function PromptForText(promptText, callback)
    local popup = StaticPopup_Show("HIDEFRAMES_TEXT_INPUT", promptText)
    if popup then popup.data = { callback = callback } end
end

-- ------------------------------------------------------
-- Build the frame
-- ------------------------------------------------------
local function BuildFrame()
    mainFrame = CreateFrame("Frame", "HideFramesMainFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(400, 500)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:Hide()
    mainFrame.TitleText:SetText(c.blue .. "Hide" .. c.pink .. "Frames" .. c.reset)

    -- Profile row --------------------------------------------------
    local profileLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profileLabel:SetPoint("TOPLEFT", 14, -32)
    profileLabel:SetText("Profile:")

    profileDropdown = CreateFrame("Frame", "HideFramesProfileDropdown", mainFrame, "UIDropDownMenuTemplate")
    profileDropdown:SetPoint("LEFT", profileLabel, "RIGHT", -8, -3)
    UIDropDownMenu_SetWidth(profileDropdown, 130)

    UIDropDownMenu_Initialize(profileDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        local names = {}
        for name in pairs(HideFramesDB.profiles) do table.insert(names, name) end
        table.sort(names)
        for _, name in ipairs(names) do
            info.text = name
            info.checked = (name == HideFramesDB.currentProfile)
            info.func = function()
                if ns.SwitchProfile(name) then
                    UIDropDownMenu_SetText(profileDropdown, name)
                    QueueRefresh()
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Profile management buttons (New / Copy / Rename / Delete) ----
    local function MakeSmallButton(text, anchor, xoff)
        local btn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
        btn:SetSize(58, 20)
        btn:SetPoint("LEFT", anchor, "RIGHT", xoff, 0)
        btn:SetText(text)
        local fs = btn:GetFontString()
        if fs then fs:SetFontObject("GameFontHighlightSmall") end
        return btn
    end

    local newBtn = MakeSmallButton("New", profileDropdown, 12)
    newBtn:SetScript("OnClick", function()
        PromptForText("Name for the new profile:", function(name)
            if ns.CreateProfile(name) then
                ns.SwitchProfile(name)
                ns.UI.RefreshProfileDropdown()
                QueueRefresh()
                ns.Print("created & switched to " .. c.pink .. name .. c.reset .. " :3")
            elseif name ~= "" then
                ns.Print(c.red .. "a profile with that name already exists." .. c.reset)
            end
        end)
    end)

    local copyBtn = MakeSmallButton("Copy", newBtn, 4)
    copyBtn:SetScript("OnClick", function()
        PromptForText("Name for the copy of " .. HideFramesDB.currentProfile .. ":", function(name)
            if ns.CopyProfile(name) then
                ns.SwitchProfile(name)
                ns.UI.RefreshProfileDropdown()
                QueueRefresh()
                ns.Print("copied into " .. c.pink .. name .. c.reset)
            elseif name ~= "" then
                ns.Print(c.red .. "a profile with that name already exists." .. c.reset)
            end
        end)
    end)

    mainFrame.copyBtn = copyBtn

    -- second row, under the dropdown: Rename / Delete / Reset
    local renameBtn = MakeSmallButton("Rename", profileLabel, 0)
    renameBtn:ClearAllPoints()
    renameBtn:SetPoint("TOPLEFT", profileLabel, "BOTTOMLEFT", 0, -8)
    renameBtn:SetScript("OnClick", function()
        local old = HideFramesDB.currentProfile
        PromptForText("New name for " .. old .. ":", function(name)
            if ns.RenameProfile(old, name) then
                ns.UI.RefreshProfileDropdown()
                ns.Print("renamed to " .. c.pink .. name .. c.reset)
            elseif name ~= "" then
                ns.Print(c.red .. "that name's taken." .. c.reset)
            end
        end)
    end)

    local deleteBtn = MakeSmallButton("Delete", renameBtn, 4)
    deleteBtn:SetScript("OnClick", function()
        local name = HideFramesDB.currentProfile
        if ns.CountProfiles() <= 1 then
            ns.Print(c.red .. "can't delete your only profile." .. c.reset)
            return
        end
        StaticPopup_Show("HIDEFRAMES_DELETE_PROFILE", name, nil, name)
    end)

    local resetBtn = MakeSmallButton("Reset", deleteBtn, 4)
    resetBtn:SetScript("OnClick", function()
        local name = HideFramesDB.currentProfile
        StaticPopup_Show("HIDEFRAMES_RESET_PROFILE", name, nil, name)
    end)

    -- Scroll list ----------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -100)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(340, 1)
    scrollFrame:SetScrollChild(content)
    mainFrame.content = content

    -- Quick-add box ---------------------------------------------------
    local addLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("BOTTOMLEFT", 14, 34)
    addLabel:SetText("Add frame(s):")

    local addBox = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
    addBox:SetSize(200, 20)
    addBox:SetPoint("LEFT", addLabel, "RIGHT", 8, 0)
    addBox:SetAutoFocus(false)
    addBox:SetScript("OnEnterPressed", function(self)
        local text = strtrim(self:GetText() or "")
        if text == "" then return end

        local added, skipped = ns.AddAndHideList(text)

        if added > 0 then
            ns.Print("added & hid " .. added .. " frame(s) :3")
            self:SetText("")
            QueueRefresh()
        end
        for _, s in ipairs(skipped) do
            ns.Print(c.red .. "skipped " .. c.reset .. s.key .. " (" .. s.reason .. ")")
        end
    end)
    addBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Help text --------------------------------------------------------
    local helpText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    helpText:SetPoint("BOTTOMLEFT", 14, 16)
    helpText:SetText("/hide help for all commands  -  drag rows' checkbox to hide/show")

    mainFrame:SetScript("OnShow", function()
        ns.UI.RefreshProfileDropdown()
        ns.UI.RefreshList()
    end)
end

-- ------------------------------------------------------
-- Refreshers
-- ------------------------------------------------------
function ns.UI.RefreshProfileDropdown()
    if not profileDropdown then return end
    UIDropDownMenu_SetText(profileDropdown, HideFramesDB.currentProfile)
end

function ns.UI.RefreshList()
    if not mainFrame then return end
    local content = mainFrame.content

    for _, row in ipairs(rowPool) do
        row:Hide()
    end

    local profile = ns.GetCurrentProfile()
    if not profile then return end

    local y = -6
    for i, key in ipairs(profile.frames) do
        local row = rowPool[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(340, 28)

            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetPoint("LEFT", 4, 0)

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
            row.label:SetPoint("RIGHT", -30, 0)
            row.label:SetJustifyH("LEFT")

            row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            row.remove:SetSize(22, 22)
            row.remove:SetPoint("RIGHT", -2, 0)

            rowPool[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row:Show()

        row.label:SetText(key)
        row.check:SetChecked(profile.hidden[key])
        row.key = key

        -- (re)assign handlers each refresh so they always close over the
        -- current `key`/`profile` rather than accumulating closures
        row.check:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            profile.hidden[key] = checked
            local f = ns.ResolveFrame(key)
            if checked then ns.HideFrame(f) else ns.ShowFrame(f) end
        end)

        row.remove:SetScript("OnClick", function()
            local f = ns.ResolveFrame(key)
            ns.ShowFrame(f)
            ns.RemoveFrame(key)
            ns.UI.RefreshList()
        end)

        y = y - 30
    end

    content:SetHeight(math.max(40, math.abs(y) + 10))
end

function ns.UI.OnProfileChanged()
    ns.UI.RefreshProfileDropdown()
    QueueRefresh()
end

function ns.UI.Toggle()
    if not mainFrame then BuildFrame() end
    mainFrame:SetShown(not mainFrame:IsShown())
end

function ns.UI.Show()
    if not mainFrame then BuildFrame() end
    mainFrame:Show()
end

-- Also register a Blizzard Interface Options / Settings entry that just
-- opens the real window - this is the "expected" place players look for
-- addon config, even though our UI lives in its own frame.
local function RegisterSettingsShortcut()
    local panel = CreateFrame("Frame")
    panel.name = "HideFrames"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(c.blue .. "Hide" .. c.pink .. "Frames" .. c.reset)

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(160, 24)
    openBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    openBtn:SetText("Open HideFrames")
    openBtn:SetScript("OnClick", function() ns.UI.Show() end)

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -16)
    desc:SetJustifyH("LEFT")
    desc:SetWidth(360)
    desc:SetText("HideFrames has its own movable window - click above to open it, or use /hide anywhere.")

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", RegisterSettingsShortcut)

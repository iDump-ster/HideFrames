local addonName, ns = ...

-- ======================================================
--  :3 HideFrames - Core :3
--  saved variables, profile CRUD, and the actual
--  hide/show logic. everything else (UI, minimap,
--  slash commands) talks to this module through `ns`.
-- ======================================================

ns.colors = {
    pink  = "|cffF5A9B8",
    blue  = "|cff5BCEFA",
    white = "|cffFFFFFF",
    red   = "|cffFF5555",
    reset = "|r",
}

local c = ns.colors
ns.prefix = c.blue .. "Hide" .. c.pink .. "Frames" .. c.reset .. c.white .. ":" .. c.reset .. " "

local function msg(text)
    print(ns.prefix .. text)
end
ns.Print = msg

-- ------------------------------------------------------
-- Saved variables
-- ------------------------------------------------------
local DEFAULT_PROFILE_NAME = "Default"

local function NewProfile()
    return { frames = {}, hidden = {} }
end

local function EnsureDB()
    HideFramesDB = HideFramesDB or {
        currentProfile = DEFAULT_PROFILE_NAME,
        profiles = { [DEFAULT_PROFILE_NAME] = NewProfile() },
        minimap = { hide = false, angle = 225 },
    }
    -- backfill in case an old save is missing a field (upgrades shouldn't nuke your list uwu)
    HideFramesDB.profiles = HideFramesDB.profiles or { [DEFAULT_PROFILE_NAME] = NewProfile() }
    HideFramesDB.currentProfile = HideFramesDB.currentProfile or DEFAULT_PROFILE_NAME
    HideFramesDB.minimap = HideFramesDB.minimap or { hide = false, angle = 225 }
    if not HideFramesDB.profiles[HideFramesDB.currentProfile] then
        HideFramesDB.currentProfile = DEFAULT_PROFILE_NAME
        HideFramesDB.profiles[DEFAULT_PROFILE_NAME] = HideFramesDB.profiles[DEFAULT_PROFILE_NAME] or NewProfile()
    end
end

-- cached pointer to the active profile table so hot paths (hiding on login,
-- OnShow re-hooks, etc) don't re-index HideFramesDB.profiles[...] every call
local activeProfile

local function GetCurrentProfile()
    return activeProfile
end
ns.GetCurrentProfile = GetCurrentProfile

-- ------------------------------------------------------
-- Frame resolution
-- ------------------------------------------------------
local function GetFrameByPath(path)
    if not path or path == "" then return nil end
    local parts = { strsplit(".", path) }
    local current = _G[parts[1]]
    if not current then return nil end
    for i = 2, #parts do
        current = current[parts[i]]
        if not current then return nil end
    end
    return current
end

local function ResolveFrame(key)
    return _G[key] or GetFrameByPath(key)
end
ns.ResolveFrame = ResolveFrame

-- ------------------------------------------------------
-- Hide / show
-- ------------------------------------------------------
local function HideFrame(f)
    if not f then return end
    f.__hideFramesSuppressed = true
    f:Hide()
    if not f.__hideFramesHooked then
        f:HookScript("OnShow", function(self)
            if self.__hideFramesSuppressed then self:Hide() end
        end)
        f.__hideFramesHooked = true
    end
    if f.SetAlpha then f:SetAlpha(0) end
    if f.EnableMouse then f:EnableMouse(false) end
end
ns.HideFrame = HideFrame

local function ShowFrame(f)
    if not f then return end
    f.__hideFramesSuppressed = false
    f:Show()
    if f.SetAlpha then f:SetAlpha(1) end
    if f.EnableMouse then f:EnableMouse(true) end
end
ns.ShowFrame = ShowFrame

-- ------------------------------------------------------
-- Profile application
-- ------------------------------------------------------
local function ApplyProfile(profile)
    if not profile then return end
    for _, key in ipairs(profile.frames) do
        local f = ResolveFrame(key)
        if f then
            if profile.hidden[key] then
                HideFrame(f)
            else
                ShowFrame(f)
            end
        end
    end
end
ns.ApplyProfile = ApplyProfile

local function ShowAllInProfile(profile)
    if not profile then return end
    for _, key in ipairs(profile.frames) do
        local f = ResolveFrame(key)
        if f then ShowFrame(f) end
    end
end
ns.ShowAllInProfile = ShowAllInProfile

local function SwitchProfile(newName)
    if not HideFramesDB.profiles[newName] then return false end
    if newName == HideFramesDB.currentProfile then return false end

    ShowAllInProfile(activeProfile)
    HideFramesDB.currentProfile = newName
    activeProfile = HideFramesDB.profiles[newName]
    ApplyProfile(activeProfile)

    if ns.UI and ns.UI.OnProfileChanged then ns.UI.OnProfileChanged() end
    return true
end
ns.SwitchProfile = SwitchProfile

local function IsInList(profile, key)
    for _, v in ipairs(profile.frames) do
        if v == key then return true end
    end
    return false
end

local function AddFrame(key)
    local profile = activeProfile
    if not key or key == "" or IsInList(profile, key) then return false end
    table.insert(profile.frames, key)
    if profile.hidden[key] == nil then
        profile.hidden[key] = true
    end
    return true
end
ns.AddFrame = AddFrame

-- Splits on whitespace so "/hide Foo Bar" and typing "Foo Bar" into the
-- Add Frame box behave identically. Returns how many were added and a
-- list of {key, reason} for anything skipped.
local function AddAndHideList(text)
    local added, skipped = 0, {}
    for key in (text or ""):gmatch("%S+") do
        local f = ResolveFrame(key)
        if f then
            if AddFrame(key) then
                activeProfile.hidden[key] = true
                HideFrame(f)
                added = added + 1
            else
                table.insert(skipped, { key = key, reason = "already tracked" })
            end
        else
            table.insert(skipped, { key = key, reason = "not found" })
        end
    end
    return added, skipped
end
ns.AddAndHideList = AddAndHideList

local function RemoveFrame(key)
    local profile = activeProfile
    for i, v in ipairs(profile.frames) do
        if v == key then
            table.remove(profile.frames, i)
            profile.hidden[key] = nil
            break
        end
    end
end
ns.RemoveFrame = RemoveFrame

-- ------------------------------------------------------
-- Profile CRUD (rename / delete / copy / reset)
-- ------------------------------------------------------
local function CreateProfile(name)
    if not name or name == "" or HideFramesDB.profiles[name] then return false end
    HideFramesDB.profiles[name] = NewProfile()
    return true
end
ns.CreateProfile = CreateProfile

local function CopyProfile(newName, sourceName)
    sourceName = sourceName or HideFramesDB.currentProfile
    if not newName or newName == "" or HideFramesDB.profiles[newName] then return false end
    local src = HideFramesDB.profiles[sourceName]
    if not src then return false end

    local copy = NewProfile()
    for _, key in ipairs(src.frames) do
        table.insert(copy.frames, key)
        copy.hidden[key] = src.hidden[key]
    end
    HideFramesDB.profiles[newName] = copy
    return true
end
ns.CopyProfile = CopyProfile

local function DeleteProfile(name)
    if not HideFramesDB.profiles[name] then return false end
    if name == DEFAULT_PROFILE_NAME and CountProfiles and CountProfiles() <= 1 then return false end

    local isActive = (name == HideFramesDB.currentProfile)
    if isActive then
        ShowAllInProfile(HideFramesDB.profiles[name])
    end

    HideFramesDB.profiles[name] = nil

    if isActive then
        -- fall back to Default, creating it fresh if it somehow doesn't exist
        if not HideFramesDB.profiles[DEFAULT_PROFILE_NAME] then
            HideFramesDB.profiles[DEFAULT_PROFILE_NAME] = NewProfile()
        end
        HideFramesDB.currentProfile = DEFAULT_PROFILE_NAME
        activeProfile = HideFramesDB.profiles[DEFAULT_PROFILE_NAME]
        ApplyProfile(activeProfile)
    end
    return true
end
ns.DeleteProfile = DeleteProfile

local function RenameProfile(oldName, newName)
    if not HideFramesDB.profiles[oldName] then return false end
    if not newName or newName == "" or HideFramesDB.profiles[newName] then return false end

    HideFramesDB.profiles[newName] = HideFramesDB.profiles[oldName]
    HideFramesDB.profiles[oldName] = nil

    if HideFramesDB.currentProfile == oldName then
        HideFramesDB.currentProfile = newName
        activeProfile = HideFramesDB.profiles[newName]
    end
    return true
end
ns.RenameProfile = RenameProfile

local function ResetProfile(name)
    name = name or HideFramesDB.currentProfile
    local profile = HideFramesDB.profiles[name]
    if not profile then return false end
    ShowAllInProfile(profile)
    HideFramesDB.profiles[name] = NewProfile()
    if name == HideFramesDB.currentProfile then
        activeProfile = HideFramesDB.profiles[name]
    end
    return true
end
ns.ResetProfile = ResetProfile

function CountProfiles()
    local n = 0
    for _ in pairs(HideFramesDB.profiles) do n = n + 1 end
    return n
end
ns.CountProfiles = CountProfiles

-- ------------------------------------------------------
-- Login / init
--
-- some Blizzard frames (and other addons) show themselves back up
-- after PLAYER_ENTERING_WORLD or a bit later once everything's loaded,
-- so we re-apply a couple times on a short delay rather than polling
-- forever. two follow-up passes is enough.
-- ------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        EnsureDB()
        activeProfile = HideFramesDB.profiles[HideFramesDB.currentProfile]

        local profileCount, frameCount = 0, #activeProfile.frames
        for _ in pairs(HideFramesDB.profiles) do profileCount = profileCount + 1 end
        msg("loaded " .. c.pink .. profileCount .. c.reset .. " profile(s), "
            .. c.pink .. frameCount .. c.reset .. " frame(s) tracked in "
            .. c.pink .. HideFramesDB.currentProfile .. c.reset .. " :3")

        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    local profile = activeProfile
    if not profile then return end

    for _, key in ipairs(profile.frames) do
        if profile.hidden[key] == nil then
            profile.hidden[key] = true
        end
    end

    ApplyProfile(profile)
    C_Timer.After(1.5, function() ApplyProfile(activeProfile) end)
    C_Timer.After(4, function() ApplyProfile(activeProfile) end)
end)

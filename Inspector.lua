local addonName, ns = ...
local c = ns.colors

-- ======================================================
--  :3 HideFrames - Inspector :3
--  hover a stack of frames, run "/hide copy" to list them
--  top-to-bottom, then "/hide copy <n>" to grab one.
-- ======================================================

local inspectFrame
local lastList -- cached list from the most recent "/hide copy" (no args)

-- ------------------------------------------------------
-- For each frame, work out the best candidate name, then
-- PROVE it actually resolves back to that exact frame via
-- ns.ResolveFrame before calling it usable. GetDebugName()
-- already returns a full dotted path when it can build one
-- (e.g. "UIParent.reportBug") -- we must NOT prepend the
-- parent name again on top of that, or we get doubled paths
-- like "UIParent.UIParent.<hash>". When Blizzard can't find
-- a real field name for an anonymous frame it fabricates a
-- hash-like id instead; that id isn't a real table key, so
-- the round-trip check below correctly flags it unusable.
-- ------------------------------------------------------
local function BuildFrameList()
    local foci = GetMouseFoci and GetMouseFoci()
    if not foci or #foci == 0 then return nil end

    local list = {}
    for _, f in ipairs(foci) do
        local candidate = f:GetName()
        if not candidate and f.GetDebugName then
            local debugName = f:GetDebugName()
            if debugName and debugName ~= "" then
                candidate = debugName
            end
        end

        local resolvable = candidate ~= nil and ns.ResolveFrame(candidate) == f
        table.insert(list, { frame = f, key = candidate, resolvable = resolvable })
    end
    return list
end

local function EnsureInspectFrame()
    if inspectFrame then return inspectFrame end

    inspectFrame = CreateFrame("Frame", "HideFramesInspectFrame", UIParent, "BasicFrameTemplateWithInset")
    inspectFrame:SetSize(320, 70)
    inspectFrame:SetPoint("CENTER")
    inspectFrame:SetFrameStrata("DIALOG")
    inspectFrame:SetMovable(true)
    inspectFrame:EnableMouse(true)
    inspectFrame:RegisterForDrag("LeftButton")
    inspectFrame:SetScript("OnDragStart", inspectFrame.StartMoving)
    inspectFrame:SetScript("OnDragStop", inspectFrame.StopMovingOrSizing)
    inspectFrame.TitleText:SetText("Frame Name")

    inspectFrame.edit = CreateFrame("EditBox", nil, inspectFrame, "InputBoxTemplate")
    inspectFrame.edit:SetPoint("TOPLEFT", 16, -32)
    inspectFrame.edit:SetPoint("BOTTOMRIGHT", -16, 12)
    inspectFrame.edit:SetAutoFocus(true)
    inspectFrame.edit:SetScript("OnEscapePressed", function() inspectFrame:Hide() end)
    inspectFrame.edit:SetScript("OnEnterPressed", function() inspectFrame:Hide() end)

    return inspectFrame
end

local function ShowInspectBox(text)
    local box = EnsureInspectFrame()
    box.edit:SetText(text or "")
    box.edit:HighlightText()
    box:Show()
    box.edit:SetFocus()
end

local function PrintList(list)
    ns.Print("frames under your mouse, top to bottom:")
    for i, entry in ipairs(list) do
        local label = entry.key or "(no name at all)"
        local tag = entry.resolvable and (c.blue .. "[named]" .. c.reset) or (c.red .. "[anonymous]" .. c.reset)
        print("  " .. i .. ". " .. label .. "  " .. tag)
    end
    ns.Print("run " .. c.blue .. "/hide copy <number>" .. c.reset .. " to grab a name, or "
        .. c.blue .. "/hide temp <number>" .. c.reset .. " to hide it right now for this session.")
    ns.Print(c.red .. "[anonymous]" .. c.reset .. " ones can still be copied/temp-hidden, they just won't survive a reload since there's no stable name for /hide to find them by next time.")
end

local function GrabEntry(index, entry)
    local text = entry.key or "(no name at all)"
    ShowInspectBox(text)
    if entry.resolvable then
        ns.Print("grabbed #" .. index .. ": " .. c.pink .. text .. c.reset .. " -- copied to the box")
    else
        ns.Print("grabbed #" .. index .. ": " .. c.pink .. text .. c.reset .. " -- copied to the box, but "
            .. c.red .. "heads up" .. c.reset .. ": this one's anonymous, so /hide can't re-find it after a reload. "
            .. "use " .. c.blue .. "/hide temp " .. index .. c.reset .. " instead if you just want it gone for now.")
    end
end

-- Public entry point used by Slash.lua ("/hide copy" and "/hide copy <n>")
function ns.InspectFrameUnderMouse(pick)
    if pick then
        local index = tonumber(pick)
        if not lastList or not index or not lastList[index] then
            ns.Print(c.red .. "run /hide copy first to get a numbered list." .. c.reset)
            return
        end
        GrabEntry(index, lastList[index])
        return
    end

    local list = BuildFrameList()
    lastList = list

    if not list then
        ns.Print(c.red .. "no frame under your mouse." .. c.reset)
        return
    end

    if #list == 1 then
        GrabEntry(1, list[1])
        return
    end

    PrintList(list)
end

-- Public entry point used by Slash.lua ("/hide temp <n>") -- hides the
-- live frame reference for this session only, exactly like /framestack's
-- right-click hide. No name required, nothing written to the profile,
-- so it simply doesn't survive the next reload/login.
function ns.TempHideFromList(pick)
    local index = tonumber(pick)
    if not lastList or not index or not lastList[index] then
        ns.Print(c.red .. "run /hide copy first to get a numbered list, then /hide temp <n>." .. c.reset)
        return
    end
    local entry = lastList[index]
    ns.HideFrame(entry.frame)
    ns.Print("hidden #" .. index .. " (" .. c.pink .. (entry.key or "unnamed") .. c.reset
        .. ") for this session. it'll come back on your next /reload or login.")
end

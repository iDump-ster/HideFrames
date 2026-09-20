local addonName, ns = ...
local c = ns.colors

-- ======================================================
--  HideFrames - Slash Commands <3
--  /hide <frame> [frame2] ...   add & hide one or more frames
--  /hide list                   show what's tracked in this profile
--  /hide remove <frame>         stop tracking a frame (shows it again)
--  /hide show <frame>           un-hide without untracking
--  /hide profile <name>         switch profiles (creates if new)
--  /hide copy                   list every frame under your mouse
--  /hide copy <n>               grab entry #n's name into a box
--  /hide temp <n>               hide entry #n right now, this session only
--  /hide reset                  wipe the current profile
--  /hide minimap                toggle the minimap button
--  /hide gui | config           open the window
--  /hide help                   this list
-- ======================================================

local function PrintHelp()
    ns.Print("commands:")
    print("  " .. c.blue .. "/hide" .. c.reset .. " <frame> [frame2 ...]  - add & hide")
    print("  " .. c.blue .. "/hide list" .. c.reset .. "                  - show tracked frames")
    print("  " .. c.blue .. "/hide remove" .. c.reset .. " <frame>        - untrack (shows it again)")
    print("  " .. c.blue .. "/hide show" .. c.reset .. " <frame>          - unhide, keep tracking")
    print("  " .. c.blue .. "/hide profile" .. c.reset .. " <name>        - switch/create profile")
    print("  " .. c.blue .. "/hide copy" .. c.reset .. "                  - list every frame under your mouse")
    print("  " .. c.blue .. "/hide copy <n>" .. c.reset .. "               - grab #n's name into a box")
    print("  " .. c.blue .. "/hide temp <n>" .. c.reset .. "               - hide #n right now, this session only")
    print("  " .. c.blue .. "/hide reset" .. c.reset .. "                 - clear the current profile")
    print("  " .. c.blue .. "/hide minimap" .. c.reset .. "               - toggle the minimap button")
    print("  " .. c.blue .. "/hide gui" .. c.reset .. "                   - open the window")
end

local function DoList()
    local profile = ns.GetCurrentProfile()
    if not profile or #profile.frames == 0 then
        ns.Print("nothing tracked in " .. c.pink .. HideFramesDB.currentProfile .. c.reset .. " yet.")
        return
    end
    ns.Print("tracked in " .. c.pink .. HideFramesDB.currentProfile .. c.reset .. ":")
    for _, key in ipairs(profile.frames) do
        local state = profile.hidden[key] and (c.red .. "hidden" .. c.reset) or (c.blue .. "shown" .. c.reset)
        print("  " .. key .. "  [" .. state .. "]")
    end
end

local function DoMultiHide(msg)
    local added, skipped = ns.AddAndHideList(msg)

    if added > 0 then
        ns.Print("added & hid " .. added .. " frame(s) :3")
        if ns.UI then ns.UI.RefreshList() end
    end
    for _, s in ipairs(skipped) do
        ns.Print(c.red .. "skipped " .. c.reset .. s.key .. " (" .. s.reason .. ")")
    end
end

SLASH_HIDEFRAMES1 = "/hide"
SLASH_HIDEFRAMES2 = "/hideframes"
SlashCmdList["HIDEFRAMES"] = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "" or cmd == "gui" or cmd == "config" then
        ns.UI.Show()

    elseif cmd == "help" then
        PrintHelp()

    elseif cmd == "list" then
        DoList()

    elseif cmd == "copy" then
        ns.InspectFrameUnderMouse(rest ~= "" and rest or nil)

    elseif cmd == "temp" then
        if rest == "" then
            ns.Print("usage: /hide copy first, then /hide temp <number>")
        else
            ns.TempHideFromList(rest)
        end

    elseif cmd == "remove" then
        if rest == "" then
            ns.Print("usage: /hide remove <frame>")
        else
            local f = ns.ResolveFrame(rest)
            if f then ns.ShowFrame(f) end
            ns.RemoveFrame(rest)
            ns.Print("untracked " .. c.pink .. rest .. c.reset)
            if ns.UI then ns.UI.RefreshList() end
        end

    elseif cmd == "show" then
        if rest == "" then
            ns.Print("usage: /hide show <frame>")
        else
            local f = ns.ResolveFrame(rest)
            if f then
                ns.ShowFrame(f)
                ns.GetCurrentProfile().hidden[rest] = false
                ns.Print("showing " .. c.pink .. rest .. c.reset .. " again")
                if ns.UI then ns.UI.RefreshList() end
            else
                ns.Print(c.red .. "couldn't find " .. rest .. c.reset)
            end
        end

    elseif cmd == "profile" then
        if rest == "" then
            ns.Print("current profile: " .. c.pink .. HideFramesDB.currentProfile .. c.reset)
        elseif HideFramesDB.profiles[rest] then
            ns.SwitchProfile(rest)
            ns.Print("switched to " .. c.pink .. rest .. c.reset)
        else
            ns.CreateProfile(rest)
            ns.SwitchProfile(rest)
            ns.Print("created & switched to " .. c.pink .. rest .. c.reset .. " :3")
        end

    elseif cmd == "reset" then
        ns.ResetProfile()
        ns.Print("profile " .. c.pink .. HideFramesDB.currentProfile .. c.reset .. " reset.")
        if ns.UI then ns.UI.RefreshList() end

    elseif cmd == "minimap" then
        HideFramesDB.minimap.hide = not HideFramesDB.minimap.hide
        ns.Print(HideFramesDB.minimap.hide and "minimap button hidden (reload to fully remove it)"
                                             or "minimap button will show after a /reload")

    else
        -- not a recognized subcommand: treat the whole message as a
        -- space-separated list of frame names, same as before
        DoMultiHide(msg)
    end
end

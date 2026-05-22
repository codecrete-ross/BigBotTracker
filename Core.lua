local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.addonName = addonName or "BigBotTracker"

local frame = CreateFrame("Frame")

local function handleSlashCommand(message)
    message = BBT.Util.Trim(message or ""):lower()

    if message == "" or message == "show" or message == "open" then
        BBT.UI.Open()
        return
    end

    if message == "status" then
        local candidates = BBT.Storage.GetAllCandidates()
        BBT.Util.Print(string.format("%d tracked candidates. Sync: %s", #candidates, BBT.Sync.status or "Unknown"))
        return
    end

    if message == "sync on" then
        BBT.Storage.GetSettings().sync.enabled = true
        BBT.Sync.JoinChannel()
        BBT.Util.Print("Sync enabled.")
        return
    end

    if message == "sync off" then
        BBT.Storage.GetSettings().sync.enabled = false
        BBT.Sync.status = "Disabled"
        BBT.Util.Print("Sync disabled.")
        return
    end

    if message == "clear buffers" then
        BBT.Storage.ClearRuntimeBuffers()
        BBT.Util.Print("Runtime scan buffers cleared.")
        return
    end

    if message == "export" then
        BBT.Storage.GetSettings().lastDebugSummary = BBT.Storage.BuildDebugSummary()
        BBT.Util.Print("Debug summary saved in BigBotTrackerDB.settings.lastDebugSummary.")
        return
    end

    local channelName = message:match("^channel%s+(.+)$")
    if channelName and channelName ~= "" then
        BBT.Storage.GetSettings().sync.channelName = channelName
        if BBT.Storage.GetSettings().sync.enabled then
            BBT.Sync.JoinChannel()
        end
        BBT.Util.Print("Sync channel set to " .. channelName .. ".")
        return
    end

    local monitorName, monitorState = message:match("^monitor%s+(%S+)%s+(%S+)$")
    if (monitorName == "trade" or monitorName == "services") and (monitorState == "on" or monitorState == "off") then
        BBT.Storage.GetSettings().monitor[monitorName] = monitorState == "on"
        BBT.Util.Print(
            string.format("%s monitoring %s.", monitorName, monitorState == "on" and "enabled" or "disabled")
        )
        return
    end

    if message == "debug on" then
        BBT.Storage.GetSettings().debug = true
        BBT.Util.Print("Debug enabled.")
        return
    end

    if message == "debug off" then
        BBT.Storage.GetSettings().debug = false
        BBT.Util.Print("Debug disabled.")
        return
    end

    BBT.Util.Print(
        "Commands: /bbt, /bbt status, /bbt sync on|off, /bbt channel NAME, /bbt monitor trade|services on|off, /bbt export, /bbt clear buffers, /bbt debug on|off"
    )
end

local function initializeSlashCommands()
    SLASH_BIGBOTTRACKER1 = "/bbt"
    SLASH_BIGBOTTRACKER2 = "/bigbottracker"
    SlashCmdList.BIGBOTTRACKER = handleSlashCommand
end

function BigBotTracker_OnAddonCompartmentClick()
    if BBT.UI and BBT.UI.Toggle then
        BBT.UI.Toggle()
    end
end

local function onAddonLoaded(loadedName)
    if loadedName ~= addonName then
        return
    end

    BBT.Storage.Initialize()
    BBT.Sync.Initialize()
    BBT.UI.Create()
    initializeSlashCommands()

    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("CHAT_MSG_CHANNEL")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnUpdate", function(_, elapsed)
        if BBT.Sync and BBT.Sync.OnUpdate then
            BBT.Sync.OnUpdate()
        end
        if BBT.UI and BBT.UI.OnUpdate then
            BBT.UI.OnUpdate(elapsed)
        end
    end)
end

local function onPlayerLogin()
    if BBT.Sync and BBT.Sync.Start then
        BBT.Sync.Start()
    end
    BBT.Util.Print("Loaded. Open the report with /bbt.")
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        onAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        onPlayerLogin()
    elseif event == "CHAT_MSG_CHANNEL" then
        local text, sender, _, channelName, _, _, zoneChannelID, channelIndex, channelBaseName, _, lineID, guid = ...
        BBT.ChatScanner.HandleChannelMessage(
            text,
            sender,
            channelName,
            zoneChannelID,
            channelIndex,
            channelBaseName,
            lineID,
            guid
        )
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        BBT.Sync.HandleAddonMessage(prefix, message, channel, sender)
    end
end)

frame:RegisterEvent("ADDON_LOADED")

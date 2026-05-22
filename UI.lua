local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.UI = BBT.UI or {}

local UI = BBT.UI
local Util = BBT.Util
local Storage = BBT.Storage

local FRAME_NAME = "BigBotTrackerFrame"
local ROW_COUNT = 12

local frame
local rows = {}
local detailLines = {}
local selectedCandidate
local dirty = false
local dirtyReason = nil
local dirtyElapsed = 0
local passiveElapsed = 0
local statusElapsed = 0
local refreshCount = 0

local DIRTY_REFRESH_SECONDS = 0.5
local PASSIVE_REFRESH_SECONDS = 5
local STATUS_REFRESH_SECONDS = 1

local columns = {
    { label = "Tier", x = 8, width = 92 },
    { label = "Score", x = 102, width = 48 },
    { label = "Conf", x = 152, width = 48 },
    { label = "Character-Realm", x = 202, width = 170 },
    { label = "Last Seen", x = 374, width = 92 },
    { label = "Msgs", x = 468, width = 44 },
    { label = "Rate", x = 514, width = 50 },
    { label = "Avg Int", x = 566, width = 58 },
    { label = "Reuse", x = 626, width = 52 },
    { label = "Src", x = 680, width = 44 },
}

local function createFont(parent, layer, template, point, relativeTo, relativePoint, x, y)
    local font = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlightSmall")
    font:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    font:SetJustifyH("LEFT")
    return font
end

local function createButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 96, height or 22)
    button:SetText(text)
    return button
end

local function formatLastSeen(candidate)
    if not candidate.lastSeen or candidate.lastSeen <= 0 then
        return "-"
    end
    local age = Util.GetNow() - candidate.lastSeen
    if age < 86400 then
        return Util.FormatDuration(age) .. " ago"
    end
    return Util.FormatTimestamp(candidate.lastSeen)
end

local function getSourceMarker(candidate)
    local hasLocal = (candidate.totalMessages or 0) > 0
    local peerCount = candidate.network and candidate.network.peerCount or 0
    if hasLocal and peerCount > 0 then
        return "L+N"
    end
    if peerCount > 0 then
        return "Net"
    end
    return "Local"
end

local function topBucketsText(candidate)
    local buckets = candidate.timing and candidate.timing.dominantBuckets or {}
    local parts = {}
    for index = 1, math.min(3, #buckets) do
        parts[#parts + 1] = string.format("~%ds: %d%%", buckets[index].bucket or 0, buckets[index].percent or 0)
    end
    return #parts > 0 and table.concat(parts, ", ") or "-"
end

local function phasesText(candidate)
    local phases = candidate.timing and candidate.timing.cadencePhases or {}
    if #phases == 0 then
        return "-"
    end

    local parts = {}
    for index = 1, math.min(3, #phases) do
        local phase = phases[index]
        parts[#parts + 1] = string.format("~%ds x%d", phase.bucket or 0, phase.count or 0)
    end
    return table.concat(parts, ", ")
end

local function setDetailLine(index, label, value)
    local line = detailLines[index]
    if line then
        line:SetText(string.format("|cffbbbbbb%s:|r %s", label, tostring(value or "-")))
    end
end

local function refreshDetails(candidate)
    if not frame then
        return
    end

    selectedCandidate = candidate or selectedCandidate
    candidate = selectedCandidate

    if not candidate then
        for _, line in ipairs(detailLines) do
            line:SetText("")
        end
        setDetailLine(1, "Select", "Choose a row to view evidence")
        return
    end

    local score = candidate.score or {}
    local timing = candidate.timing or {}
    local content = candidate.content or {}
    local behavior = candidate.behavior or {}
    local network = candidate.network or {}
    local channels = {}
    for _, key in ipairs(Util.TableKeysSorted(candidate.channels)) do
        channels[#channels + 1] = key
    end

    setDetailLine(1, "Character", candidate.displayName)
    setDetailLine(
        2,
        "Tier / Score",
        string.format("%s / %d", score.tier or "Insufficient Data", score.networkAdjustedScore or 0)
    )
    setDetailLine(
        3,
        "Local vs Network",
        string.format("%d / %d", score.localScore or 0, score.networkAdjustedScore or 0)
    )
    setDetailLine(4, "Confidence", Util.FormatPercent(score.confidence or 0))
    setDetailLine(5, "Channels Seen", #channels > 0 and table.concat(channels, ", ") or "-")
    setDetailLine(6, "First Seen", Util.FormatTimestamp(candidate.firstSeen))
    setDetailLine(7, "First Suspected", Util.FormatTimestamp(candidate.firstPromoted))
    setDetailLine(8, "Last Seen", Util.FormatTimestamp(candidate.lastSeen))
    setDetailLine(
        9,
        "Messages",
        string.format("%d total, %d this session", candidate.totalMessages or 0, candidate.sessionMessages or 0)
    )
    setDetailLine(10, "Active Days", tostring(Util.CountMap(candidate.daysSeen)))
    setDetailLine(11, "Active Span", Util.FormatDuration(behavior.activeSpan or 0))
    setDetailLine(12, "Posts/Hour", Util.FormatNumber(behavior.postsPerHour or 0, 1))
    setDetailLine(13, "Average Interval", Util.FormatDuration(timing.averageInterval or 0))
    setDetailLine(14, "Interval Consistency", timing.intervalConsistency or "-")
    setDetailLine(15, "Top Buckets", topBucketsText(candidate))
    setDetailLine(16, "Rolling Entropy", Util.FormatNumber((timing.lowestRollingEntropy or 1), 2))
    setDetailLine(17, "Global Entropy", Util.FormatNumber((timing.globalEntropy or 1), 2))
    setDetailLine(18, "Cadence Phases", phasesText(candidate))
    setDetailLine(19, "Cadence Switches", tostring(timing.cadenceSwitchCount or 0))
    setDetailLine(20, "Template Reuse", Util.FormatPercent(content.templateReusePercent or 0))
    setDetailLine(21, "Unique Templates", tostring(content.uniqueTemplateCount or 0))
    setDetailLine(22, "Near Duplicates", tostring(content.nearDuplicateCount or 0))
    setDetailLine(23, "Longest Run", Util.FormatDuration(behavior.longestActiveSpan or 0))
    setDetailLine(24, "Bursts", tostring(behavior.burstCount or 0))
    setDetailLine(25, "Network Sightings", tostring(network.peerCount or 0))
    setDetailLine(26, "Last Network Update", Util.FormatTimestamp(network.lastReceived))

    local reasonText = "-"
    if score.reasons and #score.reasons > 0 then
        reasonText = table.concat(score.reasons, "  |  ")
    end
    setDetailLine(27, "Top Reasons", reasonText)
end

function UI.Refresh()
    if not frame or not frame:IsShown() then
        return
    end

    refreshCount = refreshCount + 1
    local candidates = Storage.GetAllCandidates()

    for rowIndex = 1, ROW_COUNT do
        local row = rows[rowIndex]
        local candidate = candidates[rowIndex]
        row.candidate = candidate

        if candidate then
            local score = candidate.score or {}
            local timing = candidate.timing or {}
            local content = candidate.content or {}
            local behavior = candidate.behavior or {}

            row:Show()
            row.fields[1]:SetText(score.tier or "Insufficient")
            row.fields[2]:SetText(tostring(math.floor((score.networkAdjustedScore or 0) + 0.5)))
            row.fields[3]:SetText(Util.FormatPercent(score.confidence or 0))
            row.fields[4]:SetText(candidate.displayName or "-")
            row.fields[5]:SetText(formatLastSeen(candidate))
            row.fields[6]:SetText(tostring(candidate.totalMessages or 0))
            row.fields[7]:SetText(Util.FormatNumber(behavior.postsPerHour or 0, 1))
            row.fields[8]:SetText(Util.FormatDuration(timing.averageInterval or 0))
            row.fields[9]:SetText(Util.FormatPercent(content.templateReusePercent or 0))
            row.fields[10]:SetText(getSourceMarker(candidate))
        else
            row:Hide()
        end
    end

    if selectedCandidate then
        refreshDetails(selectedCandidate)
    else
        refreshDetails(nil)
    end

    UI.UpdateStatus()
end

local function createRows(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -58)
    header:SetSize(728, 20)

    for index, column in ipairs(columns) do
        local label = createFont(header, "OVERLAY", "GameFontNormalSmall", "LEFT", header, "LEFT", column.x, 0)
        label:SetWidth(column.width)
        label:SetText(column.label)
    end

    for rowIndex = 1, ROW_COUNT do
        local row = CreateFrame("Button", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -78 - ((rowIndex - 1) * 22))
        row:SetSize(728, 20)
        row.fields = {}

        local texture = row:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints(row)
        texture:SetColorTexture(0.12, 0.12, 0.14, rowIndex % 2 == 0 and 0.35 or 0.18)

        for index, column in ipairs(columns) do
            local field = createFont(row, "OVERLAY", "GameFontHighlightSmall", "LEFT", row, "LEFT", column.x, 0)
            field:SetWidth(column.width)
            field:SetText("")
            row.fields[index] = field
        end

        row:SetScript("OnClick", function(self)
            if self.candidate then
                selectedCandidate = self.candidate
                refreshDetails(self.candidate)
            end
        end)

        rows[rowIndex] = row
    end
end

local function createDetails(parent)
    local title = createFont(parent, "OVERLAY", "GameFontNormal", "TOPLEFT", parent, "TOPLEFT", 14, -352)
    title:SetText("Candidate Detail")

    for index = 1, 27 do
        local line = createFont(
            parent,
            "OVERLAY",
            "GameFontHighlightSmall",
            "TOPLEFT",
            parent,
            "TOPLEFT",
            14,
            -374 - ((index - 1) * 15)
        )
        line:SetWidth(720)
        line:SetWordWrap(false)
        detailLines[index] = line
    end
end

local function createControls(parent)
    local refresh = createButton(parent, "Refresh", 82, 22)
    refresh:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 14)
    refresh:SetScript("OnClick", function()
        UI.Refresh()
    end)

    local sync = createButton(parent, "Toggle Sync", 104, 22)
    sync:SetPoint("LEFT", refresh, "RIGHT", 8, 0)
    sync:SetScript("OnClick", function()
        local settings = Storage.GetSettings()
        settings.sync.enabled = not settings.sync.enabled
        if settings.sync.enabled then
            BBT.Sync.JoinChannel()
            Util.Print("Sync enabled.")
        else
            BBT.Sync.status = "Disabled"
            Util.Print("Sync disabled.")
        end
        UI.Refresh()
    end)

    local clearSession = createButton(parent, "Clear Session", 112, 22)
    clearSession:SetPoint("LEFT", sync, "RIGHT", 8, 0)
    clearSession:SetScript("OnClick", function()
        Storage.ClearSessionBuffers()
        Util.Print("Session-only scan buffers cleared.")
        UI.Refresh()
    end)

    local purgeAll = createButton(parent, "Purge All", 88, 22)
    purgeAll:SetPoint("LEFT", clearSession, "RIGHT", 8, 0)
    purgeAll:SetScript("OnClick", function()
        if StaticPopupDialogs and StaticPopup_Show then
            StaticPopupDialogs.BIGBOTTRACKER_PURGE_ALL = {
                text = "Purge all Big Bot Tracker candidate data?",
                button1 = "Purge",
                button2 = "Cancel",
                OnAccept = function()
                    Storage.PurgeAll()
                    selectedCandidate = nil
                    Util.Print("All Big Bot Tracker data purged.")
                    UI.Refresh()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("BIGBOTTRACKER_PURGE_ALL")
        else
            Storage.PurgeAll()
            selectedCandidate = nil
            UI.Refresh()
        end
    end)

    local purgeSelected = createButton(parent, "Purge Selected", 122, 22)
    purgeSelected:SetPoint("LEFT", purgeAll, "RIGHT", 8, 0)
    purgeSelected:SetScript("OnClick", function()
        if selectedCandidate then
            Storage.PurgeCandidate(selectedCandidate)
            Util.Print("Purged " .. tostring(selectedCandidate.displayName) .. ".")
            selectedCandidate = nil
            UI.Refresh()
        else
            Util.Print("Select a candidate first.")
        end
    end)

    local export = createButton(parent, "Export", 72, 22)
    export:SetPoint("LEFT", purgeSelected, "RIGHT", 8, 0)
    export:SetScript("OnClick", function()
        Storage.GetSettings().lastDebugSummary = Storage.BuildDebugSummary()
        Util.Print("Debug summary saved in BigBotTrackerDB.settings.lastDebugSummary.")
    end)

    local status = createFont(parent, "OVERLAY", "GameFontDisableSmall", "LEFT", export, "RIGHT", 12, 0)
    status:SetWidth(160)
    status:SetText("")
    parent.syncStatusText = status
end

function UI.Create()
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(760, 820)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = createFont(frame, "OVERLAY", "GameFontHighlightLarge", "TOPLEFT", frame, "TOPLEFT", 14, -14)
    frame.title:SetText("Big Bot Tracker")

    frame.subtitle = createFont(frame, "OVERLAY", "GameFontDisableSmall", "TOPLEFT", frame, "TOPLEFT", 14, -36)
    frame.subtitle:SetWidth(720)
    frame.subtitle:SetText("Chat-based suspicion report. Scores are likelihood signals, not proof of botting.")

    createRows(frame)
    createDetails(frame)
    createControls(frame)

    frame:SetScript("OnShow", function()
        UI.Refresh()
    end)

    return frame
end

function UI.Open()
    UI.Create()
    frame:Show()
    UI.Refresh()
end

function UI.Toggle()
    UI.Create()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        UI.Refresh()
    end
end

function UI.UpdateStatus()
    if frame and frame.syncStatusText then
        local tracked = Storage.GetAllCandidates()
        frame.syncStatusText:SetText(
            string.format(
                "Live: scanning | Tracked: %d | Sync: %s",
                #tracked,
                tostring(BBT.Sync and BBT.Sync.status or "Unknown")
            )
        )
    end
end

function UI.MarkDirty(reason)
    dirty = true
    dirtyReason = reason or dirtyReason or "data"
end

function UI.IsDirty()
    return dirty
end

function UI.GetRefreshCount()
    return refreshCount
end

function UI.OnUpdate(elapsed)
    if not frame or not frame:IsShown() then
        return
    end

    elapsed = elapsed or 0
    dirtyElapsed = dirtyElapsed + elapsed
    passiveElapsed = passiveElapsed + elapsed
    statusElapsed = statusElapsed + elapsed

    if statusElapsed >= STATUS_REFRESH_SECONDS then
        UI.UpdateStatus()
        statusElapsed = 0
    end

    if dirty and dirtyElapsed >= DIRTY_REFRESH_SECONDS then
        dirty = false
        dirtyReason = nil
        dirtyElapsed = 0
        passiveElapsed = 0
        UI.Refresh()
        return
    end

    if not dirty and passiveElapsed >= PASSIVE_REFRESH_SECONDS then
        passiveElapsed = 0
        UI.Refresh()
    end
end

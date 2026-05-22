local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.UI = BBT.UI or {}

local UI = BBT.UI
local Util = BBT.Util
local Storage = BBT.Storage

local FRAME_NAME = "BigBotTrackerFrame"
local FRAME_WIDTH = 1180
local FRAME_HEIGHT = 820
local OUTER_MARGIN = 20
local TABLE_CONTENT_WIDTH = 1120
local TABLE_VIEW_WIDTH = 1120
local TABLE_HEIGHT = 270
local ROW_HEIGHT = 22
local HEADER_HEIGHT = 24
local TITLE_TOP = -26
local SUBTITLE_TOP = -54
local STATUS_TOP = -88
local HEADER_TOP = -124
local TABLE_TOP = -150
local DETAIL_TITLE_TOP = -430
local DETAIL_TOP = -466
local REASONS_TOP = DETAIL_TOP - 250

local frame
local tableScroll
local tableContent
local emptyState
local headerButtons = {}
local rows = {}
local detail = {}
local selectedCandidate
local selectedKey
local dirty = false
local dirtyReason = nil
local dirtyElapsed = 0
local passiveElapsed = 0
local statusElapsed = 0
local refreshCount = 0

local DIRTY_REFRESH_SECONDS = 0.5
local PASSIVE_REFRESH_SECONDS = 5
local STATUS_REFRESH_SECONDS = 1

local tierRank = {
    ["Insufficient Data"] = 0,
    Preliminary = 0,
    Low = 1,
    Medium = 2,
    High = 3,
    Critical = 4,
}

local sourceRank = {
    Local = 1,
    Net = 2,
    ["L+N"] = 3,
}

local columns = {
    {
        key = "character",
        label = "Character-Realm",
        width = 198,
        align = "LEFT",
        defaultDescending = false,
        tooltip = "Tracked character and realm. Same names on different realms are kept separate.",
    },
    {
        key = "tier",
        label = "Tier",
        width = 110,
        align = "LEFT",
        defaultDescending = true,
        tooltip = "Plain-language suspicion tier derived from score and confidence.",
    },
    {
        key = "score",
        label = "Score",
        width = 58,
        align = "RIGHT",
        defaultDescending = true,
        tooltip = "Local evidence likelihood score. Network evidence is shown separately and does not boost this score.",
    },
    {
        key = "confidence",
        label = "Conf",
        width = 58,
        align = "RIGHT",
        defaultDescending = true,
        tooltip = "How much evidence supports the current score.",
    },
    {
        key = "firstSeen",
        label = "First Seen",
        width = 128,
        align = "LEFT",
        defaultDescending = false,
        tooltip = "First time this character was observed by this addon.",
    },
    {
        key = "lastSeen",
        label = "Last Seen",
        width = 106,
        align = "LEFT",
        defaultDescending = true,
        tooltip = "Most recent monitored-channel message or network sighting.",
    },
    {
        key = "messages",
        label = "Msgs",
        width = 50,
        align = "RIGHT",
        defaultDescending = true,
        tooltip = "Total locally observed messages for this candidate.",
    },
    {
        key = "rate",
        label = "Rate",
        width = 58,
        align = "RIGHT",
        defaultDescending = true,
        tooltip = "Estimated posts per hour across the observed active span.",
    },
    {
        key = "averageInterval",
        label = "Avg Int",
        width = 70,
        align = "RIGHT",
        defaultDescending = false,
        tooltip = "Average interval between observed messages.",
    },
    {
        key = "cadence",
        label = "Cadence",
        width = 122,
        align = "LEFT",
        defaultDescending = true,
        tooltip = "User-friendly timing entropy summary. Hover rows for entropy and bucket details.",
    },
    {
        key = "reuse",
        label = "Reuse",
        width = 58,
        align = "RIGHT",
        defaultDescending = true,
        tooltip = "Percent of messages matching the most reused normalized template.",
    },
    {
        key = "source",
        label = "Src",
        width = 60,
        align = "LEFT",
        defaultDescending = true,
        tooltip = "Local, network, or combined evidence source.",
    },
}

local tierColors = {
    Critical = { 1.00, 0.22, 0.16 },
    High = { 1.00, 0.52, 0.12 },
    Medium = { 1.00, 0.84, 0.16 },
    Low = { 0.56, 0.78, 1.00 },
    Preliminary = { 0.66, 0.78, 1.00 },
    ["Insufficient Data"] = { 0.66, 0.66, 0.66 },
}

local cadenceColors = {
    ["Fixed Cadence"] = { 1.00, 0.34, 0.22 },
    ["Jittered Cadence"] = { 1.00, 0.56, 0.22 },
    ["Mixed Regular"] = { 1.00, 0.64, 0.20 },
    ["Burst-Only"] = { 1.00, 0.76, 0.28 },
    Variable = { 0.70, 0.82, 1.00 },
    Sparse = { 0.60, 0.60, 0.60 },
}

local cadenceRank = {
    Sparse = 0,
    Variable = 1,
    ["Burst-Only"] = 2,
    ["Jittered Cadence"] = 3,
    ["Mixed Regular"] = 4,
    ["Fixed Cadence"] = 5,
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

local function setTextColor(font, color)
    if font and font.SetTextColor and color then
        font:SetTextColor(color[1], color[2], color[3])
    end
end

local function setShown(widget, shown)
    if not widget then
        return
    end
    if widget.SetShown then
        widget:SetShown(shown)
    elseif shown then
        widget:Show()
    else
        widget:Hide()
    end
end

local function raiseFrame()
    if frame and frame.Raise then
        frame:Raise()
    end
end

local function registerEscapeClose()
    if type(UISpecialFrames) ~= "table" then
        return
    end

    for _, frameName in ipairs(UISpecialFrames) do
        if frameName == FRAME_NAME then
            return
        end
    end

    table.insert(UISpecialFrames, FRAME_NAME)
end

local function bindTooltip(owner, title, lines)
    owner:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)

        local tooltipLines = type(lines) == "function" and lines(self) or lines
        for _, line in ipairs(tooltipLines or {}) do
            if type(line) == "table" then
                GameTooltip:AddLine(line.text or "", line.r or 0.85, line.g or 0.85, line.b or 0.85, true)
            else
                GameTooltip:AddLine(tostring(line), 0.85, 0.85, 0.85, true)
            end
        end

        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function getSettingsUi()
    local settings = Storage.GetSettings()
    settings.ui = settings.ui or {}
    settings.ui.sortKey = settings.ui.sortKey or "score"
    if settings.ui.sortDescending == nil then
        settings.ui.sortDescending = true
    end
    return settings.ui
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

local function formatFirstSeen(candidate)
    return Util.FormatTimestamp(candidate.firstSeen)
end

local function topBucketsText(candidate)
    local buckets = candidate.timing and candidate.timing.dominantBuckets or {}
    local parts = {}
    for index = 1, math.min(3, #buckets) do
        parts[#parts + 1] = string.format("~%ds %d%%", buckets[index].bucket or 0, buckets[index].percent or 0)
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
        local duration = (phase.endTime or 0) - (phase.startTime or 0)
        parts[#parts + 1] =
            string.format("~%ds x%d (%s)", phase.bucket or 0, phase.count or 0, Util.FormatDuration(duration))
    end
    return table.concat(parts, ", ")
end

local function getIntervalCount(candidate)
    local timing = candidate and candidate.timing or {}
    return timing.intervalCount or #(timing.intervals or {})
end

function UI.GetCadenceDisplay(candidate)
    local timing = candidate and candidate.timing or {}
    local intervalCount = getIntervalCount(candidate)
    local buckets = timing.dominantBuckets or {}
    local topBucket = buckets[1]
    local topBucketPercent = topBucket and (topBucket.percent or 0) or 0
    local rollingEntropy = timing.lowestRollingEntropy
    local globalEntropy = timing.globalEntropy
    local cadenceSwitches = timing.cadenceSwitchCount or 0
    local phaseCount = #(timing.cadencePhases or {})
    local label = timing.cadenceClass or "Variable"

    if label == "Very Regular" then
        label = "Fixed Cadence"
    elseif label == "Regular" then
        label = "Jittered Cadence"
    elseif intervalCount < 3 then
        label = "Sparse"
    elseif not cadenceRank[label] then
        if cadenceSwitches > 0 and phaseCount >= 2 then
            label = "Mixed Regular"
        elseif topBucketPercent >= 75 and (rollingEntropy or 1) <= 0.25 then
            label = "Fixed Cadence"
        elseif topBucketPercent >= 55 and (rollingEntropy or 1) <= 0.45 then
            label = "Jittered Cadence"
        else
            label = "Variable"
        end
    elseif label == "" then
        label = "Variable"
    end

    local tooltip = {}
    tooltip[#tooltip + 1] = string.format("Timing samples: %d", intervalCount)
    tooltip[#tooltip + 1] = string.format("Rolling entropy: %.2f", rollingEntropy or 1)
    tooltip[#tooltip + 1] = string.format("Global entropy: %.2f", globalEntropy or 1)
    tooltip[#tooltip + 1] = string.format("Robust CV: %.2f", timing.robustCoefficientVariation or 1)
    tooltip[#tooltip + 1] = string.format("Median interval: %s", Util.FormatDuration(timing.medianInterval or 0))
    tooltip[#tooltip + 1] = "Dominant buckets: " .. topBucketsText(candidate or {})
    tooltip[#tooltip + 1] = string.format("Cadence switches: %d", cadenceSwitches)

    if label == "Sparse" then
        tooltip[#tooltip + 1] = "Not enough interval samples for a strong timing read."
    elseif label == "Mixed Regular" then
        tooltip[#tooltip + 1] = "Multiple stable posting cadences were detected."
    elseif label == "Fixed Cadence" then
        tooltip[#tooltip + 1] = "Recent intervals are highly concentrated around one cadence."
    elseif label == "Jittered Cadence" then
        tooltip[#tooltip + 1] = "Timing has jitter, but still stays inside a repeatable cadence."
    elseif label == "Burst-Only" then
        tooltip[#tooltip + 1] = "Activity is concentrated into bursts without enough regular cadence evidence."
    else
        tooltip[#tooltip + 1] = "Timing is spread out or lacks a stable cadence."
    end

    return {
        label = label,
        rank = cadenceRank[label] or 0,
        color = cadenceColors[label],
        tooltip = tooltip,
    }
end

local function scoreValue(candidate)
    local score = candidate.score or {}
    return math.floor((score.displayScore or score.networkAdjustedScore or score.localScore or 0) + 0.5)
end

local function confidenceValue(candidate)
    local score = candidate.score or {}
    return score.confidence or 0
end

local function getSortValue(candidate, key)
    local score = candidate.score or {}
    local timing = candidate.timing or {}
    local content = candidate.content or {}
    local behavior = candidate.behavior or {}

    if key == "character" then
        return string.lower(candidate.displayName or "")
    elseif key == "tier" then
        return tierRank[score.tier or "Insufficient Data"] or 0
    elseif key == "score" then
        return score.networkAdjustedScore or 0
    elseif key == "confidence" then
        return score.confidence or 0
    elseif key == "firstSeen" then
        return candidate.firstSeen or 0
    elseif key == "lastSeen" then
        return candidate.lastSeen or 0
    elseif key == "messages" then
        return candidate.totalMessages or 0
    elseif key == "rate" then
        return behavior.postsPerHour or 0
    elseif key == "averageInterval" then
        return timing.averageInterval or 0
    elseif key == "cadence" then
        return UI.GetCadenceDisplay(candidate).rank
    elseif key == "reuse" then
        return content.templateReusePercent or 0
    elseif key == "source" then
        return sourceRank[getSourceMarker(candidate)] or 0
    end
    return score.networkAdjustedScore or 0
end

local function compareFallback(left, right)
    local leftScore = left.score and left.score.networkAdjustedScore or 0
    local rightScore = right.score and right.score.networkAdjustedScore or 0
    if leftScore ~= rightScore then
        return leftScore > rightScore
    end

    local leftSeen = left.lastSeen or 0
    local rightSeen = right.lastSeen or 0
    if leftSeen ~= rightSeen then
        return leftSeen > rightSeen
    end

    return string.lower(left.displayName or "") < string.lower(right.displayName or "")
end

function UI.SortCandidates(candidates)
    local uiSettings = getSettingsUi()
    local sortKey = uiSettings.sortKey or "score"
    local sortDescending = uiSettings.sortDescending ~= false
    local decorated = {}

    for index, candidate in ipairs(candidates or {}) do
        decorated[#decorated + 1] = {
            index = index,
            candidate = candidate,
        }
    end

    table.sort(decorated, function(leftRow, rightRow)
        local left = leftRow.candidate
        local right = rightRow.candidate
        local leftValue = getSortValue(left, sortKey)
        local rightValue = getSortValue(right, sortKey)

        if leftValue ~= rightValue then
            if type(leftValue) == "string" or type(rightValue) == "string" then
                leftValue = tostring(leftValue)
                rightValue = tostring(rightValue)
                if sortDescending then
                    return leftValue > rightValue
                end
                return leftValue < rightValue
            end

            if sortDescending then
                return leftValue > rightValue
            end
            return leftValue < rightValue
        end

        if compareFallback(left, right) ~= compareFallback(right, left) then
            return compareFallback(left, right)
        end

        return leftRow.index < rightRow.index
    end)

    local sorted = {}
    for index, row in ipairs(decorated) do
        sorted[index] = row.candidate
    end
    return sorted
end

function UI.SetSort(key, descending)
    local uiSettings = getSettingsUi()
    uiSettings.sortKey = key or "score"
    uiSettings.sortDescending = descending ~= false
end

function UI.GetSortState()
    local uiSettings = getSettingsUi()
    return uiSettings.sortKey, uiSettings.sortDescending ~= false
end

function UI.GetColumnKeys()
    local keys = {}
    for index, column in ipairs(columns) do
        keys[index] = column.key
    end
    return keys
end

function UI.GetHeaderState(key)
    local button = headerButtons[key]
    if not button then
        return nil
    end

    return {
        label = button.text and button.text.text or nil,
        arrowShown = button.arrow and button.arrow:IsShown() or false,
        arrowTexCoord = button.arrow and button.arrow.texCoord or nil,
        activeShown = button.active and button.active:IsShown() or false,
    }
end

local function updateHeaderLabels()
    local sortKey, sortDescending = UI.GetSortState()
    for _, column in ipairs(columns) do
        local button = headerButtons[column.key]
        if button and button.text then
            local active = column.key == sortKey
            button.text:SetText(column.label)
            setShown(button.active, active)
            setShown(button.arrow, active)
            if active and button.arrow and button.arrow.SetTexCoord then
                if sortDescending then
                    button.arrow:SetTexCoord(0, 1, 1, 0)
                else
                    button.arrow:SetTexCoord(0, 1, 0, 1)
                end
            end
        end
    end
end

local function setRowVisual(row)
    if not row or not row.bg then
        return
    end

    if row.selected then
        row.bg:SetColorTexture(0.22, 0.42, 0.62, 0.58)
    elseif row.hovered then
        row.bg:SetColorTexture(0.26, 0.26, 0.30, 0.58)
    elseif row.index and row.index % 2 == 0 then
        row.bg:SetColorTexture(0.10, 0.10, 0.12, 0.42)
    else
        row.bg:SetColorTexture(0.07, 0.07, 0.08, 0.30)
    end
end

local function updateAllRowVisuals()
    for _, row in ipairs(rows) do
        row.selected = row.candidate and row.candidate.fullKey == selectedKey
        setRowVisual(row)
    end
end

local function showCandidateTooltip(owner)
    local candidate = owner.candidate
    if not candidate or not GameTooltip then
        return
    end

    local cadence = UI.GetCadenceDisplay(candidate)
    local score = candidate.score or {}

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(candidate.displayName or "Candidate", 1, 1, 1)
    GameTooltip:AddDoubleLine("Tier", score.tier or "Insufficient Data", 0.85, 0.85, 0.85, 1, 0.82, 0.20)
    GameTooltip:AddDoubleLine("Score", tostring(scoreValue(candidate)), 0.85, 0.85, 0.85, 1, 1, 1)
    GameTooltip:AddDoubleLine("Confidence", Util.FormatPercent(score.confidence or 0), 0.85, 0.85, 0.85, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Cadence: " .. cadence.label, 1, 0.82, 0.2)
    for _, line in ipairs(cadence.tooltip or {}) do
        GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Source: " .. getSourceMarker(candidate), 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
end

local function clearDetails()
    selectedCandidate = nil
    selectedKey = nil

    if detail.title then
        detail.title:SetText("Candidate Detail")
    end
    if detail.subtitle then
        detail.subtitle:SetText("Select a row to view structured local and network evidence.")
    end

    for _, group in pairs(detail.groups or {}) do
        for _, line in ipairs(group.lines or {}) do
            line:SetText("")
        end
    end

    if detail.reasons then
        for _, line in ipairs(detail.reasons) do
            line:SetText("")
        end
    end
end

local function setGroupLine(groupName, index, label, value)
    local group = detail.groups and detail.groups[groupName]
    local line = group and group.lines and group.lines[index]
    if line then
        line:SetText(string.format("|cffbbbbbb%s:|r %s", label, tostring(value or "-")))
    end
end

local function refreshDetails(candidate)
    if not frame then
        return
    end

    if candidate then
        selectedCandidate = candidate
        selectedKey = candidate.fullKey
    elseif selectedKey then
        for _, rowCandidate in ipairs(Storage.GetAllCandidates()) do
            if rowCandidate.fullKey == selectedKey then
                selectedCandidate = rowCandidate
                candidate = rowCandidate
                break
            end
        end
    end

    candidate = candidate or selectedCandidate
    if not candidate then
        clearDetails()
        return
    end

    local score = candidate.score or {}
    local timing = candidate.timing or {}
    local content = candidate.content or {}
    local behavior = candidate.behavior or {}
    local network = candidate.network or {}
    local familyScores = score.familyScores or {}
    local baseline = candidate.baseline or {}
    local cadence = UI.GetCadenceDisplay(candidate)
    local channels = {}
    for _, key in ipairs(Util.TableKeysSorted(candidate.channels)) do
        channels[#channels + 1] = key
    end

    detail.title:SetText(candidate.displayName or "Candidate Detail")
    detail.subtitle:SetText("Evidence is based on monitored chat behavior. It is suspicion, not proof.")

    setGroupLine("summary", 1, "Tier", score.tier or "Insufficient Data")
    setGroupLine("summary", 2, "Score", tostring(scoreValue(candidate)))
    setGroupLine("summary", 3, "Confidence", Util.FormatPercent(score.confidence or 0))
    setGroupLine("summary", 4, "Source", getSourceMarker(candidate))

    setGroupLine("activity", 1, "First Seen", Util.FormatTimestamp(candidate.firstSeen))
    setGroupLine("activity", 2, "First Suspected", Util.FormatTimestamp(candidate.firstPromoted))
    setGroupLine("activity", 3, "Last Seen", Util.FormatTimestamp(candidate.lastSeen))
    setGroupLine(
        "activity",
        4,
        "Messages",
        string.format("%d total, %d this session", candidate.totalMessages or 0, candidate.sessionMessages or 0)
    )
    setGroupLine("activity", 5, "Channels", #channels > 0 and table.concat(channels, ", ") or "-")

    setGroupLine("timing", 1, "Cadence", cadence.label)
    setGroupLine("timing", 2, "Average Interval", Util.FormatDuration(timing.averageInterval or 0))
    setGroupLine("timing", 3, "Median Interval", Util.FormatDuration(timing.medianInterval or 0))
    setGroupLine("timing", 4, "Robust CV", Util.FormatNumber(timing.robustCoefficientVariation or 1, 2))
    setGroupLine("timing", 5, "Rolling Entropy", Util.FormatNumber(timing.lowestRollingEntropy or 1, 2))
    setGroupLine("timing", 6, "Top Buckets", topBucketsText(candidate))
    setGroupLine("timing", 7, "Cadence Phases", phasesText(candidate))
    setGroupLine("timing", 8, "Switches", tostring(timing.cadenceSwitchCount or 0))
    setGroupLine("timing", 9, "Posts/Hour", Util.FormatNumber(behavior.postsPerHour or 0, 1))

    setGroupLine("content", 1, "Template Reuse", Util.FormatPercent(content.templateReusePercent or 0))
    setGroupLine("content", 2, "Shingle Reuse", Util.FormatPercent(content.shingleReusePercent or 0))
    setGroupLine("content", 3, "Unique Templates", tostring(content.uniqueTemplateCount or 0))
    setGroupLine("content", 4, "Near Duplicates", tostring(content.nearDuplicateCount or 0))
    setGroupLine("content", 5, "Ad Intent", tostring(content.adIntentTotal or 0) .. " categorized")

    setGroupLine("families", 1, "Families", tostring(score.evidenceFamilyCount or 0))
    setGroupLine("families", 2, "Timing", tostring(familyScores.timing or 0) .. " / 35")
    setGroupLine("families", 3, "Content", tostring(familyScores.content or 0) .. " / 30")
    setGroupLine("families", 4, "Activity", tostring(familyScores.activity or 0) .. " / 20")
    setGroupLine("families", 5, "Persistence", tostring(familyScores.persistence or 0) .. " / 10")
    setGroupLine("families", 6, "Baseline", tostring(familyScores.baseline or 0) .. " / 15")

    setGroupLine("baseline", 1, "Status", baseline.label or "Collecting baseline")
    setGroupLine("baseline", 2, "Samples", tostring(baseline.sampleCount or 0))
    setGroupLine("baseline", 3, "Rate Percentile", Util.FormatPercent(baseline.postsPerHourPercentile or 0))
    setGroupLine("baseline", 4, "Regularity Percentile", Util.FormatPercent(baseline.regularityPercentile or 0))

    setGroupLine("network", 1, "Peers", tostring(network.peerCount or 0))
    setGroupLine("network", 2, "Overlap", network.overlap or "None")
    setGroupLine("network", 3, "Last Update", Util.FormatTimestamp(network.lastReceived))
    setGroupLine(
        "network",
        4,
        "Local / Network",
        string.format("%d / %d", score.localScore or 0, score.networkScore or 0)
    )

    local reasons = score.reasons or {}
    for index, line in ipairs(detail.reasons or {}) do
        if reasons[index] then
            line:SetText(string.format("%d. %s", index, reasons[index]))
        else
            line:SetText(index == 1 and "No strong evidence reasons yet." or "")
        end
    end
end

local function createHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", OUTER_MARGIN, HEADER_TOP)
    header:SetSize(TABLE_VIEW_WIDTH, HEADER_HEIGHT)
    parent.header = header

    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(header)
    bg:SetColorTexture(0.07, 0.07, 0.08, 0.82)
    header.bg = bg

    local bottomLine = header:CreateTexture(nil, "ARTWORK")
    bottomLine:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    bottomLine:SetSize(TABLE_VIEW_WIDTH, 1)
    bottomLine:SetColorTexture(1, 0.82, 0, 0.28)
    header.bottomLine = bottomLine

    local x = 0
    for _, column in ipairs(columns) do
        local button = CreateFrame("Button", nil, header)
        button:SetPoint("LEFT", header, "LEFT", x, 0)
        button:SetSize(column.width, HEADER_HEIGHT)
        button.column = column

        local active = button:CreateTexture(nil, "BACKGROUND")
        active:SetAllPoints(button)
        active:SetColorTexture(0.20, 0.28, 0.36, 0.55)
        active:Hide()
        button.active = active

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetColorTexture(1, 1, 1, 0.08)
        if button.SetHighlightTexture then
            button:SetHighlightTexture(highlight)
        end
        button.highlight = highlight

        local text = createFont(button, "OVERLAY", "GameFontNormalSmall", "LEFT", button, "LEFT", 4, 0)
        text:SetWidth(column.width - 22)
        text:SetJustifyH(column.align or "LEFT")
        button.text = text

        local arrow = button:CreateTexture(nil, "OVERLAY")
        arrow:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        arrow:SetSize(12, 12)
        if arrow.SetAtlas then
            arrow:SetAtlas("auctionhouse-ui-sortarrow", true)
        elseif arrow.SetTexture then
            arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
        end
        arrow:Hide()
        button.arrow = arrow

        if x > 0 then
            local separator = header:CreateTexture(nil, "ARTWORK")
            separator:SetPoint("LEFT", header, "LEFT", x - 2, 0)
            separator:SetSize(1, HEADER_HEIGHT - 4)
            separator:SetColorTexture(1, 1, 1, 0.08)
        end

        button:SetScript("OnClick", function(self)
            local uiSettings = getSettingsUi()
            if uiSettings.sortKey == self.column.key then
                uiSettings.sortDescending = not uiSettings.sortDescending
            else
                uiSettings.sortKey = self.column.key
                uiSettings.sortDescending = self.column.defaultDescending ~= false
            end
            updateHeaderLabels()
            UI.Refresh()
        end)
        button:SetScript("OnEnter", function(self)
            if not GameTooltip then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.column.label, 1, 1, 1)
            GameTooltip:AddLine(self.column.tooltip, 0.85, 0.85, 0.85, true)
            GameTooltip:AddLine("Click to sort. Click again to reverse direction.", 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        headerButtons[column.key] = button
        x = x + column.width + 4
    end

    parent.headerButtons = headerButtons
    updateHeaderLabels()
end

local function createRow(index)
    local row = CreateFrame("Button", nil, tableContent)
    row:SetPoint("TOPLEFT", tableContent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetSize(TABLE_CONTENT_WIDTH, ROW_HEIGHT - 1)
    row.index = index
    row.fields = {}

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)

    local x = 0
    for columnIndex, column in ipairs(columns) do
        local field = createFont(row, "OVERLAY", "GameFontHighlightSmall", "LEFT", row, "LEFT", x + 4, 0)
        field:SetWidth(column.width - 8)
        field:SetJustifyH(column.align or "LEFT")
        field:SetText("")
        row.fields[columnIndex] = field
        x = x + column.width + 4
    end

    row:SetScript("OnClick", function(self)
        if self.candidate then
            selectedCandidate = self.candidate
            selectedKey = self.candidate.fullKey
            refreshDetails(self.candidate)
            updateAllRowVisuals()
        end
    end)
    row:SetScript("OnEnter", function(self)
        self.hovered = true
        setRowVisual(self)
        showCandidateTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hovered = false
        setRowVisual(self)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    rows[index] = row
    return row
end

local function setRowField(row, index, text, color)
    local field = row.fields[index]
    if not field then
        return
    end
    field:SetText(text or "-")
    setTextColor(field, color or { 1, 1, 1 })
end

local function populateRow(row, candidate)
    local score = candidate.score or {}
    local timing = candidate.timing or {}
    local content = candidate.content or {}
    local behavior = candidate.behavior or {}
    local cadence = UI.GetCadenceDisplay(candidate)
    local tier = score.tier or "Insufficient Data"

    row.candidate = candidate
    row.selected = candidate.fullKey == selectedKey
    row:Show()

    setRowField(row, 1, candidate.displayName or "-", { 1, 1, 1 })
    setRowField(row, 2, tier, tierColors[tier])
    setRowField(row, 3, tostring(scoreValue(candidate)), { 1, 1, 1 })
    setRowField(row, 4, Util.FormatPercent(confidenceValue(candidate)), { 0.88, 0.88, 0.88 })
    setRowField(row, 5, formatFirstSeen(candidate), { 0.82, 0.82, 0.82 })
    setRowField(row, 6, formatLastSeen(candidate), { 0.82, 0.82, 0.82 })
    setRowField(row, 7, tostring(candidate.totalMessages or 0), { 1, 1, 1 })
    setRowField(row, 8, Util.FormatNumber(behavior.postsPerHour or 0, 1), { 1, 1, 1 })
    setRowField(row, 9, Util.FormatDuration(timing.averageInterval or 0), { 0.92, 0.92, 0.92 })
    setRowField(row, 10, cadence.label, cadence.color)
    setRowField(row, 11, Util.FormatPercent(content.templateReusePercent or 0), { 1, 1, 1 })
    setRowField(row, 12, getSourceMarker(candidate), { 0.82, 0.92, 1.00 })

    setRowVisual(row)
end

local function createTable(parent)
    createHeader(parent)

    tableScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    tableScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", OUTER_MARGIN, TABLE_TOP)
    tableScroll:SetSize(TABLE_VIEW_WIDTH, TABLE_HEIGHT)
    tableScroll:EnableMouseWheel(true)
    tableScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local maxScroll = math.max(0, ((tableContent and tableContent.contentHeight) or TABLE_HEIGHT) - TABLE_HEIGHT)
        self:SetVerticalScroll(Util.Clamp(current - (delta * ROW_HEIGHT * 3), 0, maxScroll))
    end)

    tableContent = CreateFrame("Frame", nil, tableScroll)
    tableContent:SetSize(TABLE_CONTENT_WIDTH, TABLE_HEIGHT)
    tableContent.contentHeight = TABLE_HEIGHT
    tableScroll:SetScrollChild(tableContent)

    emptyState = createFont(parent, "OVERLAY", "GameFontDisableSmall", "CENTER", tableScroll, "CENTER", 0, 0)
    emptyState:SetWidth(TABLE_CONTENT_WIDTH)
    emptyState:SetJustifyH("CENTER")
    emptyState:SetText("No tracked candidates yet. Monitoring Trade and Services.")
    emptyState:Hide()
end

local function createSection(parent, title, x, y, width, lineCount)
    local section = {
        lines = {},
    }

    local header = createFont(parent, "OVERLAY", "GameFontNormalSmall", "TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetText(title)
    section.header = header

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 17)
    divider:SetSize(width, 1)
    divider:SetColorTexture(1, 0.82, 0, 0.28)
    section.divider = divider

    for index = 1, lineCount do
        local line = createFont(
            parent,
            "OVERLAY",
            "GameFontHighlightSmall",
            "TOPLEFT",
            parent,
            "TOPLEFT",
            x,
            y - 24 - ((index - 1) * 15)
        )
        line:SetWidth(width)
        line:SetWordWrap(false)
        section.lines[index] = line
    end

    return section
end

local function createDetails(parent)
    detail.title =
        createFont(parent, "OVERLAY", "GameFontNormal", "TOPLEFT", parent, "TOPLEFT", OUTER_MARGIN, DETAIL_TITLE_TOP)
    detail.title:SetText("Candidate Detail")

    detail.subtitle = createFont(
        parent,
        "OVERLAY",
        "GameFontDisableSmall",
        "TOPLEFT",
        parent,
        "TOPLEFT",
        OUTER_MARGIN,
        DETAIL_TITLE_TOP - 20
    )
    detail.subtitle:SetWidth(TABLE_CONTENT_WIDTH)
    detail.subtitle:SetText("Select a row to view structured local and network evidence.")

    detail.groups = {
        summary = createSection(parent, "Summary", OUTER_MARGIN, DETAIL_TOP, 250, 4),
        activity = createSection(parent, "Activity", OUTER_MARGIN, DETAIL_TOP - 102, 340, 5),
        network = createSection(parent, "Network Context", OUTER_MARGIN, DETAIL_TOP - 220, 340, 4),
        timing = createSection(parent, "Timing", 380, DETAIL_TOP, 350, 9),
        content = createSection(parent, "Content", 380, DETAIL_TOP - 176, 330, 5),
        families = createSection(parent, "Evidence Families", 760, DETAIL_TOP, 360, 6),
        baseline = createSection(parent, "Compared to Current Channel", 760, DETAIL_TOP - 146, 360, 4),
    }

    local reasonHeader =
        createFont(parent, "OVERLAY", "GameFontNormalSmall", "TOPLEFT", parent, "TOPLEFT", 760, REASONS_TOP)
    reasonHeader:SetText("Top Evidence Reasons")
    detail.reasonHeader = reasonHeader

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 760, REASONS_TOP - 17)
    divider:SetSize(360, 1)
    divider:SetColorTexture(1, 0.82, 0, 0.28)
    detail.reasonDivider = divider

    detail.reasons = {}
    for index = 1, 3 do
        local line = createFont(
            parent,
            "OVERLAY",
            "GameFontHighlightSmall",
            "TOPLEFT",
            parent,
            "TOPLEFT",
            760,
            REASONS_TOP - 26 - ((index - 1) * 32)
        )
        line:SetWidth(360)
        line:SetWordWrap(true)
        detail.reasons[index] = line
    end
end

local function createStatusStrip(parent)
    local statusFrame = CreateFrame("Frame", nil, parent)
    statusFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", OUTER_MARGIN, STATUS_TOP)
    statusFrame:SetSize(TABLE_VIEW_WIDTH, 24)
    statusFrame:EnableMouse(true)
    parent.statusFrame = statusFrame

    local bg = statusFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(statusFrame)
    bg:SetColorTexture(0.05, 0.05, 0.06, 0.58)
    statusFrame.bg = bg

    local scan = createFont(statusFrame, "OVERLAY", "GameFontNormalSmall", "LEFT", statusFrame, "LEFT", 8, 0)
    scan:SetWidth(140)
    scan:SetText("Live: scanning")
    parent.scanStatusText = scan

    local tracked = createFont(statusFrame, "OVERLAY", "GameFontHighlightSmall", "LEFT", statusFrame, "LEFT", 160, 0)
    tracked:SetWidth(130)
    tracked:SetText("Tracked: 0")
    parent.trackedStatusText = tracked

    local sync = createFont(statusFrame, "OVERLAY", "GameFontHighlightSmall", "LEFT", statusFrame, "LEFT", 308, 0)
    sync:SetWidth(420)
    sync:SetText("Sync: Unknown")
    parent.syncStatusText = sync

    local hint = createFont(statusFrame, "OVERLAY", "GameFontDisableSmall", "RIGHT", statusFrame, "RIGHT", -8, 0)
    hint:SetWidth(360)
    hint:SetJustifyH("RIGHT")
    hint:SetText("Scores are likelihood signals, not proof of botting.")
    parent.statusHintText = hint

    bindTooltip(statusFrame, "Live Scanner Status", function()
        return {
            "The report refreshes while this window is open.",
            "Sync shares compact evidence summaries only, not raw chat text.",
            "Current sync state: " .. tostring(BBT.Sync and BBT.Sync.status or "Unknown"),
        }
    end)
end

local function confirmPopup(name, text, onAccept)
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs[name] = {
            text = text,
            button1 = "Confirm",
            button2 = "Cancel",
            OnAccept = onAccept,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show(name)
    else
        onAccept()
    end
end

local function createControls(parent)
    local refresh = createButton(parent, "Refresh", 82, 22)
    refresh:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", OUTER_MARGIN, 16)
    refresh:SetScript("OnClick", function()
        UI.Refresh()
    end)
    bindTooltip(refresh, "Refresh", { "Manually rebuild the visible report." })

    local export = createButton(parent, "Export", 72, 22)
    export:SetPoint("LEFT", refresh, "RIGHT", 8, 0)
    export:SetScript("OnClick", function()
        Storage.GetSettings().lastDebugSummary = Storage.BuildDebugSummary()
        Util.Print("Debug summary saved in BigBotTrackerDB.settings.lastDebugSummary.")
    end)
    bindTooltip(export, "Export Debug Summary", { "Stores a compact debug summary in SavedVariables." })

    local sync = createButton(parent, "Toggle Sync", 104, 22)
    sync:SetPoint("LEFT", export, "RIGHT", 8, 0)
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
    bindTooltip(sync, "Toggle Sync", { "Enable or disable evidence capsule sharing with other users." })

    local purgeAll = createButton(parent, "Purge All", 88, 22)
    purgeAll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -OUTER_MARGIN, 16)
    purgeAll:SetScript("OnClick", function()
        confirmPopup("BIGBOTTRACKER_PURGE_ALL", "Purge all Big Bot Tracker candidate data?", function()
            Storage.PurgeAll()
            clearDetails()
            Util.Print("All Big Bot Tracker data purged.")
            UI.Refresh()
        end)
    end)
    bindTooltip(purgeAll, "Purge All", { "Destructive: removes all persisted candidate evidence." })

    local purgeSelected = createButton(parent, "Purge Selected", 122, 22)
    purgeSelected:SetPoint("RIGHT", purgeAll, "LEFT", -8, 0)
    purgeSelected:SetScript("OnClick", function()
        if not selectedCandidate then
            Util.Print("Select a candidate first.")
            return
        end

        local candidate = selectedCandidate
        confirmPopup(
            "BIGBOTTRACKER_PURGE_SELECTED",
            "Purge Big Bot Tracker data for " .. tostring(candidate.displayName) .. "?",
            function()
                Storage.PurgeCandidate(candidate)
                Util.Print("Purged " .. tostring(candidate.displayName) .. ".")
                clearDetails()
                UI.Refresh()
            end
        )
    end)
    bindTooltip(purgeSelected, "Purge Selected", { "Destructive: removes evidence for the selected candidate." })

    local clearSession = createButton(parent, "Clear Session", 112, 22)
    clearSession:SetPoint("RIGHT", purgeSelected, "LEFT", -8, 0)
    clearSession:SetScript("OnClick", function()
        confirmPopup("BIGBOTTRACKER_CLEAR_SESSION", "Clear session-only pretracking buffers?", function()
            Storage.ClearSessionBuffers()
            Util.Print("Session-only scan buffers cleared.")
            UI.Refresh()
        end)
    end)
    bindTooltip(clearSession, "Clear Session", { "Clears unpromoted session-only scan buffers." })
end

function UI.Refresh()
    if not frame or not frame:IsShown() then
        return
    end

    refreshCount = refreshCount + 1
    updateHeaderLabels()

    local candidates = UI.SortCandidates(Storage.GetAllCandidates())
    emptyState:SetShown(#candidates == 0)

    local contentHeight = math.max(TABLE_HEIGHT, #candidates * ROW_HEIGHT)
    tableContent.contentHeight = contentHeight
    tableContent:SetSize(TABLE_CONTENT_WIDTH, contentHeight)

    local maxScroll = math.max(0, contentHeight - TABLE_HEIGHT)
    if (tableScroll:GetVerticalScroll() or 0) > maxScroll then
        tableScroll:SetVerticalScroll(maxScroll)
    end

    local selectedStillPresent = false
    for index, candidate in ipairs(candidates) do
        if candidate.fullKey == selectedKey then
            selectedCandidate = candidate
            selectedStillPresent = true
        end

        local row = rows[index] or createRow(index)
        row.index = index
        populateRow(row, candidate)
    end

    for index = #candidates + 1, #rows do
        rows[index].candidate = nil
        rows[index]:Hide()
    end

    if selectedKey and not selectedStillPresent then
        clearDetails()
    elseif selectedCandidate then
        refreshDetails(selectedCandidate)
    else
        refreshDetails(nil)
    end

    updateAllRowVisuals()
    UI.UpdateStatus()
end

function UI.Create()
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    if frame.SetFrameStrata then
        frame:SetFrameStrata("DIALOG")
    end
    if frame.SetFrameLevel then
        frame:SetFrameLevel(100)
    end
    if frame.SetToplevel then
        frame:SetToplevel(true)
    end
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnMouseDown", function()
        raiseFrame()
    end)
    frame:SetScript("OnDragStart", function(self)
        raiseFrame()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    registerEscapeClose()

    frame.title =
        createFont(frame, "OVERLAY", "GameFontHighlightLarge", "TOPLEFT", frame, "TOPLEFT", OUTER_MARGIN, TITLE_TOP)
    frame.title:SetText("Big Bot Tracker")

    frame.subtitle =
        createFont(frame, "OVERLAY", "GameFontDisableSmall", "TOPLEFT", frame, "TOPLEFT", OUTER_MARGIN, SUBTITLE_TOP)
    frame.subtitle:SetWidth(500)
    frame.subtitle:SetText("Chat-based suspicion report for Trade and Services.")

    createStatusStrip(frame)
    createTable(frame)
    createDetails(frame)
    createControls(frame)
    clearDetails()

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
    if not frame then
        return
    end

    local tracked = Storage.GetAllCandidates()
    if frame.scanStatusText then
        frame.scanStatusText:SetText("Live: scanning")
    end
    if frame.trackedStatusText then
        frame.trackedStatusText:SetText("Tracked: " .. tostring(#tracked))
    end
    if frame.syncStatusText then
        frame.syncStatusText:SetText("Sync: " .. tostring(BBT.Sync and BBT.Sync.status or "Unknown"))
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

local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.Report = BBT.Report or {}

local Report = BBT.Report
local Util = BBT.Util

local REPORT_COMMENT_LIMIT = 127
local unpack = unpack or table.unpack

Report.REPORT_COMMENT_LIMIT = REPORT_COMMENT_LIMIT

local function truncate(value, limit)
    value = tostring(value or "")
    limit = limit or REPORT_COMMENT_LIMIT
    if #value <= limit then
        return value
    end
    return value:sub(1, math.max(0, limit - 3)) .. "..."
end

local function formatDurationCompact(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    if seconds < 60 then
        return tostring(seconds) .. "s"
    end
    if seconds < 3600 then
        local minutes = math.floor(seconds / 60)
        local remainder = seconds % 60
        if remainder == 0 then
            return tostring(minutes) .. "m"
        end
        return string.format("%dm%02ds", minutes, remainder)
    end
    if seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        if minutes == 0 then
            return tostring(hours) .. "h"
        end
        return string.format("%dh%02dm", hours, minutes)
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    if hours == 0 then
        return tostring(days) .. "d"
    end
    return string.format("%dd%02dh", days, hours)
end

local function getActiveSpan(candidate)
    local behavior = candidate and candidate.behavior or {}
    if (behavior.activeSpan or 0) > 0 then
        return behavior.activeSpan
    end
    if candidate and candidate.firstSeen and candidate.lastSeen and candidate.lastSeen > candidate.firstSeen then
        return candidate.lastSeen - candidate.firstSeen
    end
    return 0
end

local function getBestRate(candidate)
    local behavior = candidate and candidate.behavior or {}
    local timing = candidate and candidate.timing or {}
    local rate = behavior.postsPerHour or 0
    for _, summary in pairs(timing.windowSummaries or {}) do
        rate = math.max(rate, summary.postsPerHour or 0)
    end
    return rate
end

local function getDominantBucket(candidate)
    local timing = candidate and candidate.timing or {}
    return timing.dominantBuckets and timing.dominantBuckets[1] or nil
end

local function buildIntervalFragment(candidate)
    local timing = candidate and candidate.timing or {}
    local baseline = candidate and candidate.baseline or {}
    local topBucket = getDominantBucket(candidate)
    local interval = topBucket and topBucket.bucket or timing.medianInterval or timing.averageInterval or 0
    local cadenceClass = timing.cadenceClass or timing.intervalConsistency

    if topBucket and (topBucket.percent or 0) >= 60 and interval > 0 then
        return string.format("~%s interval", formatDurationCompact(interval))
    end

    local regularCadence = cadenceClass == "Fixed Cadence"
        or cadenceClass == "Dominant Active-Run Cadence"
        or cadenceClass == "Dominant Cadence"
        or cadenceClass == "Jittered Cadence"
        or cadenceClass == "Mixed Cadence"
        or cadenceClass == "Mixed Regular"
    if regularCadence then
        if interval > 0 then
            return string.format("~%s interval", formatDurationCompact(interval))
        end
        return "regular posting interval"
    end

    if (baseline.regularityPercentile or 0) >= 95 then
        return "highly regular timing"
    end

    return nil
end

local function buildVolumeFragment(candidate)
    local messages = candidate and candidate.totalMessages or 0
    if messages <= 0 then
        return nil
    end

    local span = getActiveSpan(candidate)
    if span >= 60 then
        return string.format("%d posts in %s", messages, formatDurationCompact(span))
    end
    return tostring(messages) .. " posts"
end

local function buildReuseFragment(candidate)
    local content = candidate and candidate.content or {}
    local templateReuse = content.templateReusePercent or 0
    local shingleReuse = content.shingleReusePercent or 0
    local nearDuplicates = content.nearDuplicateCount or 0

    if templateReuse >= 40 then
        return string.format("%d%% reused text", math.floor(templateReuse + 0.5))
    end
    if shingleReuse >= 55 then
        return string.format("%d%% similar wording", math.floor(shingleReuse + 0.5))
    end
    if nearDuplicates > 0 then
        return tostring(nearDuplicates) .. " near-dupes"
    end
    return nil
end

local function buildPersistenceFragment(candidate)
    local dayCount = Util.CountMap(candidate and candidate.daysSeen)
    if dayCount >= 2 then
        return string.format("observed %d days", dayCount)
    end
    return nil
end

local function buildRateFragment(candidate)
    local rate = getBestRate(candidate)
    if rate >= 15 then
        return string.format("about %.0f posts/hr", rate)
    end
    return nil
end

local function buildLocalEvidenceFragment(candidate)
    local score = candidate and candidate.score or {}
    local localEvidence = score.confidence or 0
    if localEvidence > 0 then
        return string.format("%d%% local evidence", math.floor(localEvidence + 0.5))
    end
    return nil
end

local function addPart(parts, value)
    if value and value ~= "" then
        parts[#parts + 1] = value
    end
end

local function renderReportComment(base, parts, confidencePart)
    local allParts = {}
    for _, part in ipairs(parts) do
        allParts[#allParts + 1] = part
    end
    if confidencePart then
        allParts[#allParts + 1] = confidencePart
    end

    if #allParts == 0 then
        return base .. "."
    end
    return base .. ": " .. table.concat(allParts, ", ") .. "."
end

local function composeReportComment(parts, confidencePart)
    local base = "Big Bot Tracker: Repeated advertising pattern"
    local kept = {}

    for _, part in ipairs(parts) do
        kept[#kept + 1] = part
        local candidate = renderReportComment(base, kept, confidencePart)
        if #candidate > REPORT_COMMENT_LIMIT then
            table.remove(kept)
        end
    end

    local comment = renderReportComment(base, kept, confidencePart)
    while #comment > REPORT_COMMENT_LIMIT and #kept > 0 do
        table.remove(kept)
        comment = renderReportComment(base, kept, confidencePart)
    end

    if #comment <= REPORT_COMMENT_LIMIT then
        return comment
    end
    return truncate(comment, REPORT_COMMENT_LIMIT)
end

local function addEvidenceBullet(bullets, seen, text)
    if not text or text == "" or #bullets >= 4 then
        return
    end
    if seen[text] then
        return
    end
    seen[text] = true
    bullets[#bullets + 1] = text
end

local function plural(value, singular, pluralText)
    return tostring(value) .. " " .. (value == 1 and singular or pluralText)
end

local function getReportEnums()
    local enum = _G.Enum or {}
    local reportType = enum.ReportType or {}
    local majorCategory = enum.ReportMajorCategory or {}
    local minorCategory = enum.ReportMinorCategory or {}
    return {
        inWorld = reportType.InWorld,
        cheating = majorCategory.Cheating,
        botting = minorCategory.Botting,
    }
end

local function tableContains(list, value)
    if value == nil or type(list) ~= "table" then
        return false
    end

    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return false, nil, "missing"
    end

    local ok, first, second = pcall(fn, ...)
    if not ok then
        return false, nil, tostring(first)
    end
    return true, first, second
end

local function createLocation(methodName, ...)
    if not PlayerLocation or type(PlayerLocation[methodName]) ~= "function" then
        return nil, "missing"
    end

    local args = { ... }
    local ok, location = pcall(function()
        return PlayerLocation[methodName](PlayerLocation, unpack(args))
    end)
    if not ok then
        return nil, tostring(location)
    end
    return location, nil
end

local function isLocationValid(location)
    if not location or type(location.IsValid) ~= "function" then
        return false
    end

    local ok, valid = pcall(function()
        return location:IsValid()
    end)
    return ok and valid == true
end

local function canReportLocation(location)
    if not isLocationValid(location) then
        return false, nil
    end
    if not C_ReportSystem or type(C_ReportSystem.CanReportPlayer) ~= "function" then
        return false, "missing"
    end

    local ok, canReport = pcall(C_ReportSystem.CanReportPlayer, location)
    if not ok then
        return false, tostring(canReport)
    end
    return canReport == true, nil
end

local function getTargetFullName()
    if not UnitExists or not UnitExists("target") then
        return nil
    end

    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("target")
    end
    if (not name or name == "") and UnitName then
        name, realm = UnitName("target")
    end
    if not name or name == "" then
        return nil
    end

    if not realm or realm == "" then
        realm = Util.GetPlayerRealm()
    end
    return name .. "-" .. realm
end

local function targetMatchesCandidate(candidate)
    local fullName = getTargetFullName()
    if not fullName or not candidate then
        return false, fullName
    end

    local targetIdentity = Util.NormalizeIdentity(fullName)
    return targetIdentity.fullKey == candidate.fullKey, targetIdentity.displayName
end

local function checkInWorldBottingCategory()
    local enums = getReportEnums()
    local status = {
        hasReportType = enums.inWorld ~= nil,
        hasCheating = false,
        hasBotting = false,
        error = nil,
    }

    if not status.hasReportType or not C_ReportSystem then
        return status
    end

    local okMajor, majorCategories, majorError = safeCall(C_ReportSystem.GetMajorCategoriesForReportType, enums.inWorld)
    if not okMajor then
        status.error = majorError
        return status
    end

    status.hasCheating = tableContains(majorCategories, enums.cheating)
    if not status.hasCheating then
        return status
    end

    local okMinor, minorCategories, minorError =
        safeCall(C_ReportSystem.GetMinorCategoriesForReportTypeAndMajorCategory, enums.inWorld, enums.cheating)
    if not okMinor then
        status.error = minorError
        return status
    end

    status.hasBotting = tableContains(minorCategories, enums.botting)
    return status
end

local function writeDiagnostic(candidate, diagnostic)
    if not candidate or type(diagnostic) ~= "table" then
        return
    end

    candidate.lastReportDiagnostic = {
        checkedAt = diagnostic.checkedAt,
        isCritical = diagnostic.isCritical,
        hasGuid = diagnostic.hasGuid,
        hasLineID = diagnostic.hasLineID,
        targetMatches = diagnostic.targetMatches,
        targetLocationValid = diagnostic.targetLocationValid,
        targetCanReport = diagnostic.targetCanReport,
        guidLocationValid = diagnostic.guidLocationValid,
        guidCanReport = diagnostic.guidCanReport,
        chatLineValid = diagnostic.chatLineValid,
        chatLineCanReport = diagnostic.chatLineCanReport,
        inWorldHasCheating = diagnostic.inWorldHasCheating,
        inWorldHasBotting = diagnostic.inWorldHasBotting,
        canOpen = diagnostic.canOpen,
        source = diagnostic.source,
        reason = diagnostic.reason,
    }
end

function Report.IsCriticalCandidate(candidate)
    local score = candidate and candidate.score or {}
    return score.status == "Very Strong Pattern" or score.tier == "Very Strong Pattern"
end

function Report.BuildReportComment(candidate)
    local parts = {}
    addPart(parts, buildIntervalFragment(candidate))
    addPart(parts, buildVolumeFragment(candidate))
    addPart(parts, buildReuseFragment(candidate))
    addPart(parts, buildPersistenceFragment(candidate))
    addPart(parts, buildRateFragment(candidate))
    return composeReportComment(parts, buildLocalEvidenceFragment(candidate))
end

function Report.BuildReportAssist(candidate)
    local timing = candidate and candidate.timing or {}
    local content = candidate and candidate.content or {}
    local score = candidate and candidate.score or {}
    local bullets = {}
    local seen = {}

    local topBucket = getDominantBucket(candidate)
    if topBucket and (topBucket.percent or 0) > 0 then
        addEvidenceBullet(
            bullets,
            seen,
            string.format(
                "Observed timing: %d%% of intervals were near %s.",
                math.floor((topBucket.percent or 0) + 0.5),
                formatDurationCompact(topBucket.bucket or timing.medianInterval or timing.averageInterval or 0)
            )
        )
    elseif buildIntervalFragment(candidate) then
        addEvidenceBullet(bullets, seen, "Observed timing: " .. buildIntervalFragment(candidate) .. ".")
    end

    local messages = candidate and candidate.totalMessages or 0
    local activeSpan = getActiveSpan(candidate)
    if messages > 0 then
        local observed = string.format("Observed volume: %s", plural(messages, "message", "messages"))
        if activeSpan >= 60 then
            observed = observed .. " over " .. formatDurationCompact(activeSpan)
        end
        local dayCount = Util.CountMap(candidate and candidate.daysSeen)
        if dayCount >= 2 then
            observed = observed .. " across " .. plural(dayCount, "day", "days")
        end
        addEvidenceBullet(bullets, seen, observed .. ".")
    end

    local reuseDetails = {}
    if (content.templateReusePercent or 0) >= 40 then
        reuseDetails[#reuseDetails + 1] =
            string.format("%d%% reused text", math.floor((content.templateReusePercent or 0) + 0.5))
    end
    if (content.shingleReusePercent or 0) >= 55 then
        reuseDetails[#reuseDetails + 1] =
            string.format("%d%% similar wording", math.floor((content.shingleReusePercent or 0) + 0.5))
    end
    if (content.nearDuplicateCount or 0) > 0 then
        reuseDetails[#reuseDetails + 1] = plural(content.nearDuplicateCount or 0, "near-dupe", "near-dupes")
    end
    if #reuseDetails > 0 then
        addEvidenceBullet(bullets, seen, "Repeated wording: " .. table.concat(reuseDetails, ", ") .. ".")
    end

    local rate = getBestRate(candidate)
    if rate >= 15 then
        addEvidenceBullet(bullets, seen, string.format("Posting rate: %.1f/hr in active windows.", rate))
    end

    for _, reason in ipairs(score.reasons or {}) do
        addEvidenceBullet(bullets, seen, "Observed signal: " .. tostring(reason))
    end

    if #bullets < 2 then
        addEvidenceBullet(
            bullets,
            seen,
            string.format(
                "Model context: local timing and repeated-ad evidence reached %d%% local evidence.",
                math.floor((score.confidence or 0) + 0.5)
            )
        )
    end

    return {
        comment = Report.BuildReportComment(candidate),
        commentLimit = REPORT_COMMENT_LIMIT,
        instruction = "If you report this in Blizzard's window, select Cheating > Botting.",
        bullets = bullets,
    }
end

function Report.GetDiagnostics(candidate)
    local categoryStatus = checkInWorldBottingCategory()
    local diagnostic = {
        checkedAt = Util.GetNow(),
        candidate = candidate and candidate.displayName or nil,
        isCritical = Report.IsCriticalCandidate(candidate),
        hasGuid = candidate and candidate.lastGuid ~= nil and candidate.lastGuid ~= "",
        hasLineID = candidate and candidate.lastLineID ~= nil,
        targetMatches = false,
        targetName = nil,
        targetLocationValid = false,
        targetCanReport = false,
        guidLocationValid = false,
        guidCanReport = false,
        chatLineValid = false,
        chatLineCanReport = false,
        inWorldHasCheating = categoryStatus.hasCheating,
        inWorldHasBotting = categoryStatus.hasBotting,
        canOpen = false,
        source = "none",
        reason = "No candidate selected.",
    }

    if not candidate then
        return diagnostic
    end

    local selectedLocation = nil

    diagnostic.targetMatches, diagnostic.targetName = targetMatchesCandidate(candidate)
    if diagnostic.targetMatches then
        local targetLocation = createLocation("CreateFromUnit", "target")
        diagnostic.targetLocationValid = isLocationValid(targetLocation)
        diagnostic.targetCanReport = canReportLocation(targetLocation)
        if diagnostic.targetCanReport then
            selectedLocation = targetLocation
            diagnostic.source = "target"
        end
    end

    if not selectedLocation and diagnostic.hasGuid then
        local guidLocation = createLocation("CreateFromGUID", candidate.lastGuid)
        diagnostic.guidLocationValid = isLocationValid(guidLocation)
        diagnostic.guidCanReport = canReportLocation(guidLocation)
        if diagnostic.guidCanReport then
            selectedLocation = guidLocation
            diagnostic.source = "guid"
        end
    end

    if diagnostic.hasLineID then
        local validChatLine = false
        if C_ChatInfo and type(C_ChatInfo.IsValidChatLine) == "function" then
            local ok, result = pcall(C_ChatInfo.IsValidChatLine, candidate.lastLineID)
            validChatLine = ok and result == true
        end
        diagnostic.chatLineValid = validChatLine

        if validChatLine then
            local chatLocation = createLocation("CreateFromChatLineID", candidate.lastLineID)
            diagnostic.chatLineCanReport = canReportLocation(chatLocation)
        end
    end

    diagnostic._selectedLocation = selectedLocation

    if not diagnostic.isCritical then
        diagnostic.reason = "Candidate is not Very Strong Pattern."
    elseif not diagnostic.inWorldHasBotting then
        diagnostic.reason = "In-world Botting category unavailable."
    elseif not selectedLocation then
        diagnostic.reason = "No reportable in-world player location."
    else
        diagnostic.canOpen = true
        diagnostic.reason = "Ready."
    end

    writeDiagnostic(candidate, diagnostic)
    return diagnostic
end

local function loadReportFrame()
    if ReportFrame and ReportFrame.InitiateReport then
        return true
    end

    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        local ok = pcall(C_AddOns.LoadAddOn, "Blizzard_ReportFrame")
        return ok and ReportFrame and ReportFrame.InitiateReport
    end

    if type(LoadAddOn) == "function" then
        local ok = pcall(LoadAddOn, "Blizzard_ReportFrame")
        return ok and ReportFrame and ReportFrame.InitiateReport
    end

    return false
end

function Report.OpenBottingReport(candidate)
    local diagnostic = Report.GetDiagnostics(candidate)
    if not diagnostic.canOpen then
        return false, diagnostic
    end

    if not loadReportFrame() then
        diagnostic.canOpen = false
        diagnostic.reason = "Blizzard report frame unavailable."
        writeDiagnostic(candidate, diagnostic)
        return false, diagnostic
    end

    if not ReportInfo or type(ReportInfo.CreateReportInfoFromType) ~= "function" then
        diagnostic.canOpen = false
        diagnostic.reason = "ReportInfo API unavailable."
        writeDiagnostic(candidate, diagnostic)
        return false, diagnostic
    end

    local enums = getReportEnums()
    local reportInfo = ReportInfo:CreateReportInfoFromType(enums.inWorld)
    if not reportInfo then
        diagnostic.canOpen = false
        diagnostic.reason = "Could not create in-world report info."
        writeDiagnostic(candidate, diagnostic)
        return false, diagnostic
    end

    local ok, err = pcall(function()
        ReportFrame:InitiateReport(reportInfo, candidate.displayName, diagnostic._selectedLocation)
    end)
    if not ok then
        diagnostic.canOpen = false
        diagnostic.reason = tostring(err)
        writeDiagnostic(candidate, diagnostic)
        return false, diagnostic
    end

    diagnostic.reason = "Opened Blizzard report frame."
    writeDiagnostic(candidate, diagnostic)
    if BBT.Storage and BBT.Storage.MarkReported then
        BBT.Storage.MarkReported(candidate, Util.GetNow(), true)
    end
    return true, diagnostic
end

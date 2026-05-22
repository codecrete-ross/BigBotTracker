local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.Report = BBT.Report or {}

local Report = BBT.Report
local Util = BBT.Util

local unpack = unpack or table.unpack

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

    local okMajor, majorCategories, majorError =
        safeCall(C_ReportSystem.GetMajorCategoriesForReportType, enums.inWorld)
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
    return candidate and candidate.score and candidate.score.tier == "Critical"
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
        diagnostic.reason = "Candidate is not Critical."
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
    return true, diagnostic
end

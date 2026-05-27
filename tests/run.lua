local root = arg and arg[1] or "."
local BBT = {}
local fakeNow = 1700000000

_G.BigBotTracker = BBT
_G.BigBotTrackerDB = nil
_G.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
_G.UIParent = {}
_G.UISpecialFrames = {}

local function makeWidget()
    local widget = { shown = false }

    function widget:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function widget:SetWidth(width)
        self.width = width
    end
    function widget:SetHeight(height)
        self.height = height
    end
    function widget:GetWidth()
        return self.width or 0
    end
    function widget:GetHeight()
        return self.height or 0
    end
    function widget:ClearAllPoints()
        self.points = {}
    end
    function widget:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points = self.points or {}
        self.points[#self.points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x or 0,
            y = y or 0,
        }
    end
    function widget:SetMovable() end
    function widget:SetClampedToScreen() end
    function widget:EnableMouse() end
    function widget:EnableMouseWheel() end
    function widget:RegisterForDrag() end
    function widget:SetFontObject(fontObject)
        self.fontObject = fontObject
    end
    function widget:SetJustifyH(justifyH)
        self.justifyH = justifyH
    end
    function widget:SetJustifyV(justifyV)
        self.justifyV = justifyV
    end
    function widget:SetFrameStrata(strata)
        self.frameStrata = strata
    end
    function widget:SetFrameLevel(level)
        self.frameLevel = level
    end
    function widget:SetToplevel(topLevel)
        self.topLevel = topLevel
    end
    function widget:SetAlpha(alpha)
        self.alpha = alpha
    end
    function widget:SetEnabled(enabled)
        self.enabled = enabled
    end
    function widget:IsEnabled()
        return self.enabled ~= false
    end
    function widget:Enable()
        self.enabled = true
    end
    function widget:Disable()
        self.enabled = false
    end
    function widget:Raise()
        self.raised = (self.raised or 0) + 1
    end
    function widget:SetHighlightTexture(texture)
        self.highlightTexture = texture
    end
    function widget:SetScript(script, handler)
        self.scripts = self.scripts or {}
        self.scripts[script] = handler
    end
    function widget:Hide()
        self.shown = false
    end
    function widget:Show()
        self.shown = true
        if self.scripts and self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end
    function widget:SetShown(shown)
        if shown then
            self:Show()
        else
            self:Hide()
        end
    end
    function widget:IsShown()
        return self.shown
    end
    function widget:SetScrollChild(child)
        self.scrollChild = child
    end
    function widget:SetVerticalScroll(value)
        self.verticalScroll = value
    end
    function widget:GetVerticalScroll()
        return self.verticalScroll or 0
    end
    function widget:SetAutoFocus(autoFocus)
        self.autoFocus = autoFocus
    end
    function widget:SetMaxLetters(maxLetters)
        self.maxLetters = maxLetters
    end
    function widget:SetMultiLine(multiLine)
        self.multiLine = multiLine
    end
    function widget:SetTextInsets(left, right, top, bottom)
        self.textInsets = { left = left, right = right, top = top, bottom = bottom }
    end
    function widget:SetCursorPosition(position)
        self.cursorPosition = position
    end
    function widget:SetFocus()
        self.focused = true
    end
    function widget:ClearFocus()
        self.focused = false
    end
    function widget:HighlightText()
        self.highlighted = true
    end
    function widget:GetText()
        return self.text or ""
    end
    function widget:CreateFontString()
        local font = makeWidget()
        function font:SetWidth(width)
            self.width = width
        end
        function font:SetWordWrap(wordWrap)
            self.wordWrap = wordWrap
        end
        function font:SetTextColor() end
        function font:GetText()
            return self.text or ""
        end
        function font:GetStringWidth()
            return #(self.text or "") * 8
        end
        function font:SetText(text)
            self.text = text
        end
        return font
    end
    function widget:CreateTexture()
        local texture = makeWidget()
        function texture:SetAllPoints() end
        function texture:SetColorTexture() end
        function texture:SetTexCoord(...)
            self.texCoord = table.concat({ ... }, ",")
        end
        function texture:SetAtlas(atlas)
            self.atlas = atlas
        end
        function texture:SetTexture(texturePath)
            self.texturePath = texturePath
        end
        return texture
    end
    function widget:SetText(text)
        text = tostring(text or "")
        if self.maxLetters and #text > self.maxLetters then
            text = text:sub(1, self.maxLetters)
        end
        self.text = text
    end
    widget.StartMoving = function() end
    widget.StopMovingOrSizing = function() end

    return widget
end

function _G.CreateFrame(frameType, name, parent, template)
    local widget = makeWidget()
    widget.frameType = frameType
    widget.name = name
    widget.parent = parent
    widget.template = template
    if name then
        _G[name] = widget
    end
    return widget
end

function _G.time()
    return fakeNow
end

function _G.GetNormalizedRealmName()
    return "Area52"
end

function _G.GetRealmName()
    return "Area 52"
end

function _G.UnitFullName()
    return "Tester", "Area52"
end

function _G.Ambiguate(value)
    return value
end

function _G.UnitExists()
    return false
end

local fakeInGuild = true
local fakeInGroup = false
local fakeInRaid = false
local fakeInInstanceGroup = false
_G.LE_PARTY_CATEGORY_INSTANCE = 2

function _G.IsInGuild()
    return fakeInGuild
end

function _G.IsInGroup(category)
    if category == _G.LE_PARTY_CATEGORY_INSTANCE then
        return fakeInInstanceGroup
    end
    return fakeInGroup
end

function _G.IsInRaid()
    return fakeInRaid
end

_G.Enum = {
    ReportType = {
        Chat = 0,
        InWorld = 1,
    },
    ReportMajorCategory = {
        Cheating = 2,
    },
    ReportMinorCategory = {
        Botting = 128,
    },
    RegisterAddonMessagePrefixResult = {
        Success = 0,
    },
    SendAddonMessageResult = {
        Success = 0,
    },
}

local function makeLocation(kind, value, valid, canReport)
    return {
        kind = kind,
        value = value,
        valid = valid,
        canReport = canReport,
        IsValid = function(self)
            return self.valid
        end,
        IsChatLineID = function(self)
            return self.kind == "chat"
        end,
    }
end

_G.PlayerLocation = {
    CreateFromGUID = function(_, guid)
        return makeLocation("guid", guid, guid ~= "invalid-guid", guid == "reportable-guid")
    end,
    CreateFromChatLineID = function(_, lineID)
        return makeLocation("chat", lineID, lineID ~= nil, true)
    end,
    CreateFromUnit = function(_, unit)
        return makeLocation("unit", unit, unit == "target", unit == "target")
    end,
}

_G.C_ChatInfo = {
    registeredAddonPrefixes = {},
    sentAddonMessages = {},
    IsValidChatLine = function(lineID)
        return lineID ~= nil
    end,
    IsAddonMessagePrefixRegistered = function(prefix)
        return _G.C_ChatInfo.registeredAddonPrefixes[prefix] == true
    end,
    RegisterAddonMessagePrefix = function(prefix)
        _G.C_ChatInfo.registeredAddonPrefixes[prefix] = true
        return Enum.RegisterAddonMessagePrefixResult.Success
    end,
    SendAddonMessage = function(prefix, message, chatType, target)
        _G.C_ChatInfo.sentAddonMessages[#_G.C_ChatInfo.sentAddonMessages + 1] = {
            prefix = prefix,
            message = message,
            chatType = chatType,
            target = target,
        }
        return Enum.SendAddonMessageResult.Success
    end,
}

_G.C_AddOns = {
    loaded = {},
    LoadAddOn = function(addon)
        _G.C_AddOns.loaded[addon] = true
        return true
    end,
}

_G.C_ReportSystem = {
    CanReportPlayer = function(playerLocation)
        return playerLocation and playerLocation.canReport == true
    end,
    GetMajorCategoriesForReportType = function(reportType)
        if reportType == Enum.ReportType.InWorld then
            return { Enum.ReportMajorCategory.Cheating }
        end
        return {}
    end,
    GetMinorCategoriesForReportTypeAndMajorCategory = function(reportType, majorCategory)
        if reportType == Enum.ReportType.InWorld and majorCategory == Enum.ReportMajorCategory.Cheating then
            return { Enum.ReportMinorCategory.Botting }
        end
        return {}
    end,
}

_G.ReportInfo = {
    CreateReportInfoFromType = function(_, reportType)
        return { reportType = reportType }
    end,
}

_G.ReportFrame = {
    openCount = 0,
    InitiateReport = function(self, reportInfo, playerName, playerLocation)
        self.openCount = self.openCount + 1
        self.lastReport = {
            reportInfo = reportInfo,
            playerName = playerName,
            playerLocation = playerLocation,
        }
    end,
}

local function loadModule(name)
    local chunk, err = loadfile(root .. "/" .. name)
    assert(chunk, err)
    chunk("BigBotTracker", BBT)
end

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local function assertTruthy(value, label)
    if not value then
        error(label .. ": expected truthy value", 2)
    end
end

local function assertContains(value, pattern, label)
    value = tostring(value or "")
    if not value:find(pattern, 1, true) then
        error(string.format("%s: expected %q to contain %q", label, value, pattern), 2)
    end
end

local function assertNotContains(value, pattern, label)
    value = tostring(value or "")
    if value:find(pattern, 1, true) then
        error(string.format("%s: expected %q not to contain %q", label, value, pattern), 2)
    end
end

local function readTextFile(name)
    local file = assert(io.open(root .. "/" .. name, "r"))
    local text = file:read("*a")
    file:close()
    return text
end

local function assertFileNotContains(name, pattern, label)
    assertNotContains(readTextFile(name), pattern, label or (name .. " should not contain " .. pattern))
end

loadModule("Util.lua")
loadModule("Compat.lua")
loadModule("Normalizer.lua")
loadModule("Scoring.lua")
loadModule("Storage.lua")
loadModule("ChatScanner.lua")
loadModule("Sync.lua")
loadModule("Report.lua")
loadModule("UI.lua")

for _, fileName in ipairs({ "UI.lua", "Report.lua", "README.md" }) do
    assertFileNotContains(fileName, "bot probability", fileName .. " should avoid bot-probability wording")
    assertFileNotContains(fileName, "confirmed bot", fileName .. " should avoid confirmation wording")
    assertFileNotContains(fileName, "proof", fileName .. " should avoid proof wording")
end

local originalProjectId = _G.WOW_PROJECT_ID
local originalGetBuildInfo = _G.GetBuildInfo
_G.WOW_PROJECT_MAINLINE = 1
_G.WOW_PROJECT_CLASSIC = 2
_G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
_G.WOW_PROJECT_WRATH_CLASSIC = 11
_G.WOW_PROJECT_CATACLYSM_CLASSIC = 14
_G.WOW_PROJECT_MISTS_CLASSIC = 19

local function assertFlavor(projectId, interfaceVersion, expectedFlavor, expectedLabel)
    _G.WOW_PROJECT_ID = projectId
    _G.GetBuildInfo = function()
        return "test", "1", "Jan 1 2026", interfaceVersion
    end
    assertEqual(BBT.Compat.GetFlavor(), expectedFlavor, "client flavor for " .. tostring(interfaceVersion))
    assertEqual(
        BBT.Compat.GetClientInfo().label,
        expectedLabel,
        "client flavor label for " .. tostring(interfaceVersion)
    )
end

assertFlavor(1, 120005, "retail", "Retail")
assertFlavor(2, 11508, "vanilla", "Classic Era")
assertFlavor(5, 20505, "tbc", "TBC Anniversary")
assertFlavor(11, 30405, "wrath", "Wrath Classic")
assertFlavor(11, 38001, "titan", "Titan Reforged")
assertFlavor(14, 40402, "cata", "Cataclysm Classic")
assertFlavor(19, 50503, "mists", "Mists Classic")
_G.WOW_PROJECT_ID = 1
_G.GetBuildInfo = function()
    return "test", "1", "Jan 1 2026", 120005
end
assertEqual(BBT.Compat.IsRetail(), true, "Retail flavor helper")
assertEqual(BBT.Compat.IsClassic(), false, "Retail should not be Classic")
_G.WOW_PROJECT_ID = 5
_G.GetBuildInfo = function()
    return "test", "1", "Jan 1 2026", 20505
end
assertEqual(BBT.Compat.IsRetail(), false, "Classic should not be Retail")
assertEqual(BBT.Compat.IsClassic(), true, "Classic flavor helper")
_G.WOW_PROJECT_ID = originalProjectId
_G.GetBuildInfo = originalGetBuildInfo

local originalCreateFrame = _G.CreateFrame
_G.CreateFrame = function(frameType, name, parent, template)
    if template == "MissingTemplate" or template == "AlsoMissing" then
        error("missing template")
    end
    return originalCreateFrame(frameType, name, parent, template)
end
local fallbackFrame = BBT.Compat.CreateFrame("Frame", "BigBotTrackerCompatFallback", UIParent, "MissingTemplate", {
    "AlsoMissing",
})
assertTruthy(fallbackFrame, "compat frame creation should fall back when templates are missing")
assertEqual(fallbackFrame.template, nil, "compat frame fallback should create without missing templates")
_G.CreateFrame = originalCreateFrame

BBT.Storage.Initialize()
BBT.Sync.Initialize()
BBT.UI.Create()

local function countSpecialFrame(name)
    local count = 0
    for _, frameName in ipairs(UISpecialFrames) do
        if frameName == name then
            count = count + 1
        end
    end
    return count
end

assertTruthy(_G.BigBotTrackerFrame, "named UI frame should be globally addressable")
assertEqual(_G.BigBotTrackerFrame.width, 1180, "report frame width")
assertEqual(_G.BigBotTrackerFrame.height, 900, "report frame height")
assertTruthy(_G.BigBotTrackerFrame.title.points and _G.BigBotTrackerFrame.title.points[1], "report title anchor")
assertEqual(_G.BigBotTrackerFrame.title.points[1].y, -36, "report title top padding")
assertEqual(_G.BigBotTrackerFrame.frameStrata, "DIALOG", "report frame strata")
assertEqual(_G.BigBotTrackerFrame.frameLevel, 100, "report frame level")
assertEqual(_G.BigBotTrackerFrame.topLevel, true, "report frame should be top-level")
assertEqual(countSpecialFrame("BigBotTrackerFrame"), 1, "report frame should register for Escape once")
BBT.UI.Create()
assertEqual(countSpecialFrame("BigBotTrackerFrame"), 1, "Escape registration should not duplicate")

local statusHeader = BBT.UI.GetHeaderState("status")
assertTruthy(statusHeader, "status header state")
assertEqual(statusHeader.label, "Status", "header label should not include sort marker text")
assertTruthy(statusHeader.arrowShown, "active sort header should show arrow")
assertEqual(statusHeader.arrowTexCoord, "0,1,1,0", "descending sort arrow orientation")
local watchHeader = BBT.UI.GetHeaderState("watch")
assertTruthy(watchHeader, "watch header state")
assertEqual(watchHeader.arrowShown, false, "watch action column should not show a sort arrow")
assertEqual(watchHeader.activeShown, false, "watch action column should not be an active sort header")

local function send(sender, text, seconds)
    fakeNow = fakeNow + (seconds or 0)
    BBT.ChatScanner.HandleChannelMessage(text, sender, "2. Trade - City", nil, 2, "Trade", fakeNow, "guid")
end

local function sendChannel(sender, text, seconds, channelName, channelBaseName, channelIndex)
    fakeNow = fakeNow + (seconds or 0)
    BBT.ChatScanner.HandleChannelMessage(
        text,
        sender,
        channelName,
        nil,
        channelIndex or 1,
        channelBaseName,
        fakeNow,
        "guid"
    )
end

assertEqual(BBT.UI.GetRefreshCount(), 0, "hidden UI starts with no refreshes")
BBT.UI.MarkDirty("hidden-test")
BBT.UI.OnUpdate(1)
assertEqual(BBT.UI.GetRefreshCount(), 0, "hidden UI should not refresh")

send("Casual-Area52", "hello trade", 0)
send("Casual-Area52", "anyone crafting?", 60)
send("Casual-Area52", "is anyone around?", 60)
assertEqual(BBT.Storage.GetCandidate("Casual-Area52"), nil, "casual chatter should not persist")

sendChannel("GeneralCasual-Area52", "hello general", 60, "1. General - Elwynn Forest", "General", 1)
sendChannel("GeneralCasual-Area52", "where is the repair vendor?", 60, "1. General - Elwynn Forest", "General", 1)
sendChannel("GeneralCasual-Area52", "thanks for the help", 60, "1. General - Elwynn Forest", "General", 1)
assertEqual(BBT.Storage.GetCandidate("GeneralCasual-Area52"), nil, "casual General chatter should not persist")

sendChannel("GeneralSeller-Area52", "WTS dungeon boost pst", 60, "1. General - Elwynn Forest", "General", 1)
sendChannel("GeneralSeller-Area52", "WTS dungeon boost pst", 60, "1. General - Elwynn Forest", "General", 1)
sendChannel("GeneralSeller-Area52", "WTS dungeon boost pst", 60, "1. General - Elwynn Forest", "General", 1)
local generalSeller = BBT.Storage.GetCandidate("GeneralSeller-Area52")
assertTruthy(generalSeller, "repeated General ads should promote")
assertEqual(generalSeller.channels.General, 3, "General channel should use the plain base channel name")

sendChannel("CustomSeller-Area52", "WTS raid boost pst", 60, "5. Classic World", "Classic World", 5)
sendChannel("CustomSeller-Area52", "WTS raid boost pst", 60, "5. Classic World", "Classic World", 5)
sendChannel("CustomSeller-Area52", "WTS raid boost pst", 60, "5. Classic World", "Classic World", 5)
local customSeller = BBT.Storage.GetCandidate("CustomSeller-Area52")
assertTruthy(customSeller, "repeated custom public channel ads should promote")
assertEqual(customSeller.channels["Classic World"], 3, "custom public channel should use the exact base channel name")

sendChannel("FallbackSeller-Area52", "WTS classic raid boost pst", 60, "7. LookingForGroup", nil, 7)
sendChannel("FallbackSeller-Area52", "WTS classic raid boost pst", 60, "7. LookingForGroup", nil, 7)
sendChannel("FallbackSeller-Area52", "WTS classic raid boost pst", 60, "7. LookingForGroup", nil, 7)
local fallbackSeller = BBT.Storage.GetCandidate("FallbackSeller-Area52")
assertTruthy(fallbackSeller, "missing base channel should fall back to channel name")
assertEqual(fallbackSeller.channels.LookingForGroup, 3, "fallback channel name should strip only the numeric prefix")

sendChannel("EmptyChannelSeller-Area52", "WTS invisible channel boost", 60, "", "", 9)
sendChannel("EmptyChannelSeller-Area52", "WTS invisible channel boost", 60, "", "", 9)
sendChannel("EmptyChannelSeller-Area52", "WTS invisible channel boost", 60, "", "", 9)
assertEqual(BBT.Storage.GetCandidate("EmptyChannelSeller-Area52"), nil, "empty channel names should be ignored")

BBT.Storage.GetSettings().monitor.public = false
sendChannel("PublicOffSeller-Area52", "WTS public off boost", 60, "1. General - Elwynn Forest", "General", 1)
sendChannel("PublicOffSeller-Area52", "WTS public off boost", 60, "1. General - Elwynn Forest", "General", 1)
sendChannel("PublicOffSeller-Area52", "WTS public off boost", 60, "1. General - Elwynn Forest", "General", 1)
assertEqual(BBT.Storage.GetCandidate("PublicOffSeller-Area52"), nil, "public monitor off should skip General")
BBT.Storage.GetSettings().monitor.public = true

BBT.Storage.GetSettings().monitor.trade = false
sendChannel("TradeOffSeller-Area52", "WTS trade off boost", 60, "2. Trade - City", "Trade", 2)
sendChannel("TradeOffSeller-Area52", "WTS trade off boost", 60, "2. Trade - City", "Trade", 2)
sendChannel("TradeOffSeller-Area52", "WTS trade off boost", 60, "2. Trade - City", "Trade", 2)
assertEqual(
    BBT.Storage.GetCandidate("TradeOffSeller-Area52"),
    nil,
    "trade monitor off should skip Trade even when public is on"
)
BBT.Storage.GetSettings().monitor.trade = true

send("Seller-Area52", "WTS mythic carry now", 60)
send("Seller-Area52", "WTS mythic carry now", 120)
assertEqual(BBT.Storage.GetCandidate("Seller-Area52"), nil, "two repeated ads should remain pretracked")
send("Seller-Area52", "WTS mythic carry now", 120)

local seller = BBT.Storage.GetCandidate("Seller-Area52")
assertTruthy(seller, "repeated seller should promote after enough evidence")
assertEqual(seller.realmKey, "area52", "seller realm key")
assertTruthy(BBT.UI.IsDirty(), "promotion should mark UI dirty")

local refreshCountBeforeOpen = BBT.UI.GetRefreshCount()
BBT.UI.Open()
assertTruthy(BBT.UI.GetRefreshCount() > refreshCountBeforeOpen, "opening UI should refresh")
BBT.UI.SetSort("status", false)
BBT.UI.Refresh()
statusHeader = BBT.UI.GetHeaderState("status")
assertEqual(statusHeader.label, "Status", "sorted header label should remain clean")
assertTruthy(statusHeader.arrowShown, "sorted header should show arrow after refresh")
assertEqual(statusHeader.arrowTexCoord, "0,1,0,1", "ascending sort arrow orientation")
BBT.UI.SetSort("status", true)
BBT.UI.Refresh()
local refreshCountAfterOpen = BBT.UI.GetRefreshCount()
BBT.UI.OnUpdate(0.49)
assertEqual(BBT.UI.GetRefreshCount(), refreshCountAfterOpen, "dirty UI should throttle below 0.5s")
BBT.UI.OnUpdate(0.02)
assertTruthy(BBT.UI.GetRefreshCount() > refreshCountAfterOpen, "dirty UI should refresh after throttle")

send("Seller-Area52", "WTS mythic carry now", 120)
send("Seller-Area52", "WTS mythic carry now", 120)
send("Seller-Area52", "WTS mythic carry now", 120)
send("Seller-Area52", "WTS mythic carry now", 120)
assertTruthy(BBT.UI.IsDirty(), "local observation should mark UI dirty")

seller = BBT.Storage.GetCandidate("Seller-Area52")
assertTruthy(seller.timing.dominantBuckets[1], "dominant bucket exists")
assertEqual(seller.timing.dominantBuckets[1].bucket, 120, "dominant cadence bucket")
assertEqual(BBT.UI.GetCadenceDisplay(seller).label, "Fixed Cadence", "fixed seller cadence label")
assertTruthy((seller.score.networkAdjustedScore or 0) >= 45, "fixed cadence should build pattern strength")
assertEqual(seller.featureVersion, 4, "seller feature version")
assertTruthy((seller.score.familyScores.timing or 0) > 0, "seller timing family score")
assertTruthy((seller.score.familyScores.content or 0) > 0, "seller content family score")
assertTruthy((seller.score.evidenceFamilyCount or 0) >= 2, "seller should have multiple evidence families")
assertEqual(seller.score.status, "Early Pattern", "limited-history repeated seller should stay early pattern")
assertEqual(seller.lastGuid, "guid", "seller should persist latest chat sender guid")
assertTruthy(seller.lastLineID, "seller should persist latest chat line id")
assertTruthy(seller.lastReportObservedAt, "seller should persist report observation timestamp")

local beforeReload = {
    localScore = seller.score.localScore,
    confidence = seller.score.confidence,
    status = seller.score.status,
    familyCount = seller.score.evidenceFamilyCount,
    timing = seller.score.familyScores.timing,
    content = seller.score.familyScores.content,
    activity = seller.score.familyScores.activity,
    persistence = seller.score.familyScores.persistence,
    baseline = seller.score.familyScores.baseline,
}
seller.triage = nil
BBT.runtime = nil
BBT.Storage.Initialize()
assertTruthy(BBT.runtime and BBT.runtime.pretrack, "reload should recreate runtime buffers")
seller = BBT.Storage.GetCandidate("Seller-Area52")
assertEqual(seller.score.localScore, beforeReload.localScore, "reload should not increase local score")
assertEqual(seller.score.confidence, beforeReload.confidence, "reload should not increase confidence")
assertEqual(seller.score.status, beforeReload.status, "reload should not change status")
assertEqual(seller.score.evidenceFamilyCount, beforeReload.familyCount, "reload should not change family count")
assertEqual(seller.score.familyScores.timing, beforeReload.timing, "reload should not change timing family")
assertEqual(seller.score.familyScores.content, beforeReload.content, "reload should not change content family")
assertEqual(seller.score.familyScores.activity, beforeReload.activity, "reload should not change activity family")
assertEqual(
    seller.score.familyScores.persistence,
    beforeReload.persistence,
    "reload should not change persistence family"
)
assertEqual(seller.score.familyScores.baseline, beforeReload.baseline, "reload should not change baseline family")
assertEqual(BBT.Storage.IsCandidateWatched(seller), false, "reload should default missing watched state")
assertEqual(BBT.Storage.IsCandidateReported(seller), false, "reload should default missing reported state")
assertEqual(BBT.Storage.IsCandidateIgnored(seller), false, "reload should default missing ignored state")

local originalSellerStatus = seller.score.status
BBT.UI.SelectCandidate(seller)
local detailState = BBT.UI.GetDetailState()
assertContains(detailState.assessment, "Observed:", "detail summary should lead with observations")
assertContains(detailState.assessment, "100% same text", "detail summary should cite repeated text")
assertContains(detailState.assessment, "Why this status", "detail summary should explain status")
assertNotContains(detailState.assessment, "% likely", "detail summary should not claim probability")
assertNotContains(detailState.assessment, "confirmed", "detail summary should not confirm botting")
assertNotContains(detailState.assessment, "WTS mythic", "detail summary should not include raw chat text")
assertContains(detailState.groups.summary.lines[1], "Status", "detail should label status")
assertContains(detailState.groups.summary.lines[2], "Pattern Strength", "detail should label pattern strength")
assertContains(detailState.groups.summary.lines[3], "Local Evidence", "detail should label local evidence")
assertContains(detailState.groups.summary.lines[5], "Evidence Source", "detail should label evidence source")
assertContains(detailState.groups.activity.lines[2], "First Flagged", "detail should label first flagged time")
assertContains(detailState.groups.activity.lines[4], "Local Messages", "detail should label local messages")
assertContains(detailState.groups.timing.lines[4], "Interval Variation", "detail should label interval variation")
assertContains(detailState.groups.timing.lines[5], "Timing Entropy", "detail should label timing entropy")
assertContains(detailState.groups.timing.lines[6], "Common Intervals", "detail should label common intervals")
assertContains(detailState.groups.timing.lines[7], "Stable Runs", "detail should label stable runs")
assertContains(detailState.groups.timing.lines[8], "Cadence Changes", "detail should label cadence changes")
assertContains(detailState.groups.timing.lines[9], "Rate", "detail should label timing rate")
assertContains(detailState.groups.content.lines[1], "Exact Text Reuse", "detail should label exact text reuse")
assertContains(detailState.groups.content.lines[2], "Similar Wording", "detail should label similar wording")
assertContains(detailState.groups.content.lines[5], "Ad-like Messages", "detail should label ad-like messages")
assertContains(detailState.groups.families.header, "Why This Was Flagged", "detail should rename evidence families")
assertContains(detailState.groups.families.lines[1], "Signal Types", "detail should label signal types")
assertContains(detailState.groups.baseline.header, "Local Channel Baseline", "detail should rename baseline section")
assertContains(detailState.groups.baseline.lines[2], "Baseline Samples", "detail should label baseline samples")
assertContains(detailState.groups.baseline.lines[5], "Reuse vs Baseline", "detail should show reuse baseline")
assertContains(detailState.groups.network.header, "Peer Evidence", "detail should rename network section")
assertContains(detailState.groups.network.lines[4], "Pattern Strength / Peer Signal", "detail should label peer signal")
assertEqual(detailState.reasonHeader, "Observed Signals", "detail should rename reasons header")
local reportState = BBT.UI.GetReportControlState()
assertEqual(reportState.reportShown, false, "botting report action should hide below Very Strong Pattern")

seller.score.status = "Very Strong Pattern"
seller.score.tier = "Very Strong Pattern"
seller.lastGuid = "reportable-guid"
BBT.UI.SelectCandidate(seller)
reportState = BBT.UI.GetReportControlState()
assertEqual(reportState.reportShown, true, "botting report action should show for Very Strong Pattern candidates")
assertEqual(reportState.reportEnabled, true, "botting report action should enable for Very Strong Pattern candidates")

local reportComment = BBT.Report.BuildReportComment(seller)
assertEqual(reportComment:sub(1, 16), "Big Bot Tracker:", "report comment should cite addon source")
assertTruthy(#reportComment <= BBT.Report.REPORT_COMMENT_LIMIT, "report comment should fit Blizzard limit")
assertTruthy(reportComment:find("Repeated advertising pattern", 1, true), "report comment should use evidence language")
assertTruthy(reportComment:find("interval", 1, true), "report comment should prioritize interval")
assertEqual(reportComment:find("near", 1, true), nil, "report comment should avoid near-metric wording")
assertEqual(reportComment:find("cadence", 1, true), nil, "report comment should avoid cadence jargon")
assertTruthy(reportComment:find("posts", 1, true), "report comment should include observation volume")
assertTruthy(reportComment:find("reused text", 1, true), "report comment should include content reuse")
assertTruthy(reportComment:find("%% local evidence"), "report comment should include local evidence percentage")
assertEqual(reportComment:find("score", 1, true), nil, "report comment should not include score")
assertEqual(reportComment:find("WTS", 1, true), nil, "report comment should not include raw chat text")

local reportAssist = BBT.Report.BuildReportAssist(seller)
assertEqual(reportAssist.comment, reportComment, "assist should reuse report comment")
assertTruthy(#reportAssist.bullets >= 2, "assist should include evidence bullets")
assertTruthy(reportAssist.bullets[1]:find("Observed", 1, true), "assist bullets should label observed behavior")

local reportOpenCountBeforeClick = ReportFrame.openCount
_G.BigBotTrackerFrame.reportButton.scripts.OnClick(_G.BigBotTrackerFrame.reportButton)
assertEqual(ReportFrame.openCount, reportOpenCountBeforeClick + 1, "report click should open Blizzard report frame")
assertEqual(BBT.Storage.IsCandidateReported(seller), true, "successful report open should mark candidate reported")
assertEqual(seller.triage.reportOpenCount, 1, "successful report open should increment report-open count")
local assistState = BBT.UI.GetReportAssistState()
assertEqual(assistState.shown, true, "report click should show Big Bot Tracker assist dialog")
assertEqual(assistState.comment, reportComment, "assist dialog should show selectable report comment")
assertEqual(assistState.clearReportedEnabled, true, "assist dialog should allow clearing reported status")
assertEqual(_G.BigBotTrackerReportAssistFrame.commentEdit.multiLine, true, "assist comment field should be multiline")
assertEqual(
    _G.BigBotTrackerReportAssistFrame.commentEdit.template,
    nil,
    "assist comment field should not use single-line input template"
)
assertEqual(_G.BigBotTrackerReportAssistFrame.body, nil, "assist dialog should not use a masking body overlay")
assertTruthy(assistState.status:find("Blizzard report opened", 1, true), "assist dialog should show opened status")
assertTruthy(assistState.bullets[1]:find("Observed", 1, true), "assist dialog should show evidence bullets")
_G.BigBotTrackerReportAssistFrame.selectButton.scripts.OnClick(_G.BigBotTrackerReportAssistFrame.selectButton)
assertEqual(_G.BigBotTrackerReportAssistFrame.commentEdit.focused, true, "select button should focus comment field")
assertEqual(
    _G.BigBotTrackerReportAssistFrame.commentEdit.highlighted,
    true,
    "select button should highlight comment field"
)
_G.BigBotTrackerReportAssistFrame.clearReportedButton.scripts.OnClick(
    _G.BigBotTrackerReportAssistFrame.clearReportedButton
)
assertEqual(BBT.Storage.IsCandidateReported(seller), false, "assist should clear reported status")
BBT.Storage.MarkReported(seller)
assertEqual(BBT.Storage.IsCandidateReported(seller), true, "manual mark should set reported status")
assertEqual(seller.triage.reportOpenCount, 1, "manual mark should not increment report-open count")
BBT.Storage.ClearReported(seller)
assertEqual(BBT.Storage.IsCandidateReported(seller), false, "manual clear should unset reported status")

local reportDiagnostic = seller.lastReportDiagnostic
assertEqual(reportDiagnostic.source, "guid", "guid should be used when target is unavailable")
assertEqual(
    ReportFrame.lastReport.reportInfo.reportType,
    Enum.ReportType.InWorld,
    "report flow should use InWorld type"
)
assertEqual(ReportFrame.lastReport.playerName, seller.displayName, "report frame should receive candidate name")
assertEqual(seller.lastReportDiagnostic.canOpen, true, "candidate should retain positive report diagnostic")

local reportOpenCount = ReportFrame.openCount
seller.lastGuid = "blocked-guid"
seller.lastLineID = 987654
BBT.UI.SelectCandidate(seller)
_G.BigBotTrackerFrame.reportButton.scripts.OnClick(_G.BigBotTrackerFrame.reportButton)
local blockedDiagnostic = seller.lastReportDiagnostic
assertEqual(ReportFrame.openCount, reportOpenCount, "chat line fallback should not open report frame")
assertEqual(BBT.Storage.IsCandidateReported(seller), false, "failed report open should not mark candidate reported")
assistState = BBT.UI.GetReportAssistState()
assertEqual(assistState.shown, true, "failed report open should keep assist dialog visible")
assertTruthy(
    assistState.status:find("No reportable in-world player location", 1, true),
    "assist dialog should show diagnostic failure reason"
)
assertEqual(blockedDiagnostic.guidCanReport, false, "blocked guid should be diagnosed")
assertEqual(blockedDiagnostic.chatLineCanReport, true, "chat-line reportability should be diagnostic only")
assertEqual(blockedDiagnostic.canOpen, false, "blocked guid should not be openable")

seller.lastGuid = "guid"
seller.score.status = originalSellerStatus
seller.score.tier = originalSellerStatus
BBT.UI.SelectCandidate(seller)

send("Switchy-Area52", "selling raid boost pst", 120)
send("Switchy-Area52", "selling raid boost pst", 120)
send("Switchy-Area52", "selling raid boost pst", 120)
send("Switchy-Area52", "selling raid boost pst", 120)
send("Switchy-Area52", "selling raid boost pst", 180)
send("Switchy-Area52", "selling raid boost pst", 180)
send("Switchy-Area52", "selling raid boost pst", 180)
send("Switchy-Area52", "selling raid boost pst", 180)

local switchy = BBT.Storage.GetCandidate("Switchy-Area52")
assertTruthy((switchy.timing.cadenceSwitchCount or 0) >= 1, "schedule switch should be detected")
assertEqual(BBT.UI.GetCadenceDisplay(switchy).label, "Mixed Cadence", "schedule switch cadence label")
BBT.UI.SelectCandidate(switchy)
detailState = BBT.UI.GetDetailState()
assertContains(detailState.groups.timing.lines[7], "~120s", "stable runs should show first cadence")
assertContains(detailState.groups.timing.lines[7], "~180s", "stable runs should show changed cadence")
BBT.UI.SelectCandidate(seller)

send("Shorty-Area52", "ok", 60)
send("Shorty-Area52", "ok", 60)
send("Shorty-Area52", "ok", 60)
assertEqual(BBT.Storage.GetCandidate("Shorty-Area52"), nil, "short repeated generic messages should not promote")

send("Timer-Area52", "WTS raid carry available", 120)
send("Timer-Area52", "selling crafted armor slots", 120)
send("Timer-Area52", "portal service available now", 120)
send("Timer-Area52", "cheap profession work orders", 120)
send("Timer-Area52", "mythic plus schedule open", 120)
assertTruthy(BBT.Storage.GetCandidate("Timer-Area52"), "regular interval fixture should promote")

send("Burst-Area52", "lockbox opener available", 60)
send("Burst-Area52", "lf enchanter for weapon", 60)
send("Burst-Area52", "buying old materials pst", 60)
send("Burst-Area52", "need jewelcraft recraft", 60)
send("Burst-Area52", "selling profession cooldown", 60)
send("Burst-Area52", "looking for crafter now", 60)
assertTruthy(BBT.Storage.GetCandidate("Burst-Area52"), "high-volume fixture should promote")

send("HumanBurst-Area52", "hello folks how is trade today", 15)
send("HumanBurst-Area52", "anyone awake in here tonight", 37)
send("HumanBurst-Area52", "that price seems pretty normal", 81)
send("HumanBurst-Area52", "thanks all appreciate the answer", 44)
send("HumanBurst-Area52", "nice transmog in the city", 96)
send("HumanBurst-Area52", "what is everyone doing now", 52)
assertEqual(BBT.Storage.GetCandidate("HumanBurst-Area52"), nil, "human-like high volume should not promote")

send("Shuffle-Area52", "WTS heroic raid carry tonight cheap", 60)
send("Shuffle-Area52", "WTS heroic raid carry cheap tonight", 70)
send("Shuffle-Area52", "cheap WTS heroic raid carry tonight", 80)
local shuffle = BBT.Storage.GetCandidate("Shuffle-Area52")
assertTruthy(shuffle, "rearranged duplicate ads should promote")
assertTruthy((shuffle.content.shingleReusePercent or 0) > 0, "shingle reuse should be tracked")

send("Jitter-Area52", "WTS arena carry tonight pst", 110)
send("Jitter-Area52", "WTS arena carry tonight pst", 120)
send("Jitter-Area52", "WTS arena carry tonight pst", 130)
send("Jitter-Area52", "WTS arena carry tonight pst", 115)
send("Jitter-Area52", "WTS arena carry tonight pst", 125)
send("Jitter-Area52", "WTS arena carry tonight pst", 118)
local jitter = BBT.Storage.GetCandidate("Jitter-Area52")
assertTruthy(jitter, "jittered cadence fixture should promote")
assertEqual(BBT.UI.GetCadenceDisplay(jitter).label, "Jittered Cadence", "jittered cadence label")
assertTruthy((jitter.score.networkAdjustedScore or 0) >= 45, "jittered repeated ad should build pattern strength")

local dominantIntervals = {}
local dominantTime = fakeNow + 1000
for runIndex = 1, 5 do
    for _ = 1, 12 do
        dominantTime = dominantTime + 20
        dominantIntervals[#dominantIntervals + 1] = {
            t = dominantTime,
            s = 20,
            b = 20,
        }
    end
    if runIndex < 5 then
        if runIndex == 2 or runIndex == 3 then
            dominantTime = dominantTime + 30
            dominantIntervals[#dominantIntervals + 1] = {
                t = dominantTime,
                s = 30,
                b = 30,
            }
        end
        dominantTime = dominantTime + 180
        dominantIntervals[#dominantIntervals + 1] = {
            t = dominantTime,
            s = 180,
            b = 180,
        }
    end
end

local dominantCadence = {
    displayName = "DominantCadence-Area52",
    fullKey = "dominantcadence-area52",
    realmKey = "area52",
    channels = { Trade = 1 },
    daysSeen = { ["2026-05-22"] = true },
    totalMessages = #dominantIntervals + 1,
    firstSeen = dominantIntervals[1].t - 20,
    lastSeen = dominantTime,
    timing = {
        intervals = dominantIntervals,
        intervalCount = #dominantIntervals,
    },
    content = {
        templateCounts = { fixed = #dominantIntervals + 1 },
        templateTotal = #dominantIntervals + 1,
        shingleCounts = { fixed = #dominantIntervals + 1 },
        shingleTotal = #dominantIntervals + 1,
        adIntentCounts = { boost = #dominantIntervals + 1 },
        adIntentTotal = #dominantIntervals + 1,
        nearDuplicateCount = #dominantIntervals,
    },
    behavior = {},
    network = {},
}
BBT.Scoring.Recalculate(dominantCadence, BBT.Storage.GetSettings())
assertEqual(
    BBT.UI.GetCadenceDisplay(dominantCadence).label,
    "Dominant Active-Run Cadence",
    "mostly fixed active runs with gaps should not be labeled fixed"
)
assertTruthy(
    (dominantCadence.score.familyScores.timing or 0) < 35,
    "dominant cadence with gaps should not max timing score"
)
assertContains(
    BBT.UI.BuildEvidenceSummary(dominantCadence),
    "dominant ~20s active-run cadence",
    "dominant cadence summary should explain active-run cadence"
)

send("ContentOnly-Area52", "WTS rare pet cheap pst", 900)
send("ContentOnly-Area52", "WTS rare pet cheap pst", 133)
send("ContentOnly-Area52", "WTS rare pet cheap pst", 777)
local contentOnly = BBT.Storage.GetCandidate("ContentOnly-Area52")
assertTruthy(contentOnly, "content-only repeated ad should promote")
assertTruthy((contentOnly.score.networkAdjustedScore or 0) < 70, "content-only evidence should stay below strong")
assertTruthy(
    contentOnly.score.status ~= "Strong Pattern" and contentOnly.score.status ~= "Very Strong Pattern",
    "content-only evidence should not reach strong status"
)

send("TimingOnly-Area52", "casual note alpha beta gamma", 120)
send("TimingOnly-Area52", "different words delta epsilon zeta", 120)
send("TimingOnly-Area52", "another phrase eta theta iota", 120)
send("TimingOnly-Area52", "fresh line kappa lambda mu", 120)
send("TimingOnly-Area52", "separate text nu xi omicron", 120)
local timingOnly = BBT.Storage.GetCandidate("TimingOnly-Area52")
assertTruthy(timingOnly, "timing-only regular fixture should promote")
assertTruthy((timingOnly.score.networkAdjustedScore or 0) < 70, "timing-only evidence should stay below strong")

send("Mirror-Illidan", "WTS raid boost now", 60)
send("Mirror-Illidan", "WTS raid boost now", 60)
send("Mirror-Illidan", "WTS raid boost now", 60)
send("Mirror-Area52", "WTS raid boost now", 60)
send("Mirror-Area52", "WTS raid boost now", 60)
send("Mirror-Area52", "WTS raid boost now", 60)

assertTruthy(BBT.Storage.GetCandidate("Mirror-Illidan"), "illidan mirror candidate")
assertTruthy(BBT.Storage.GetCandidate("Mirror-Area52"), "area52 mirror candidate")

local function containsCandidate(candidates, target)
    for _, candidate in ipairs(candidates or {}) do
        if candidate == target or candidate.fullKey == target.fullKey then
            return true
        end
    end
    return false
end

local channelGeneral = {
    displayName = "ChannelGeneral-Area52",
    fullKey = "channelgeneral-area52",
    channels = { General = 3 },
    totalMessages = 3,
    score = {},
    timing = {},
    content = {},
    behavior = {},
    network = {},
}
local channelTrade = {
    displayName = "ChannelTrade-Area52",
    fullKey = "channeltrade-area52",
    channels = { Trade = 2, ["Classic World"] = 1 },
    totalMessages = 3,
    score = {},
    timing = {},
    content = {},
    behavior = {},
    network = {},
}
local channelNetworkOnly = {
    displayName = "ChannelNetwork-Area52",
    fullKey = "channelnetwork-area52",
    channels = {},
    totalMessages = 0,
    score = {},
    timing = {},
    content = {},
    behavior = {},
    network = { peerCount = 1 },
}
local channelFixtures = { channelGeneral, channelTrade, channelNetworkOnly }
local channelOptions = BBT.UI.GetChannelFilterOptions(channelFixtures)
assertEqual(
    table.concat(channelOptions, ","),
    "Classic World,General,Trade",
    "channel options should be distinct and sorted"
)

BBT.UI.SetFilter("all")
BBT.UI.SetChannelFilter(nil)
assertEqual(
    containsCandidate(BBT.UI.FilterCandidates(channelFixtures), channelNetworkOnly),
    true,
    "all channels should include network-only candidates"
)
BBT.UI.SetChannelFilter("General")
local generalOnly = BBT.UI.FilterCandidates(channelFixtures)
assertEqual(
    containsCandidate(generalOnly, channelGeneral),
    true,
    "specific channel filter should include matching local candidates"
)
assertEqual(
    containsCandidate(generalOnly, channelTrade),
    false,
    "specific channel filter should exclude other local channels"
)
assertEqual(
    containsCandidate(generalOnly, channelNetworkOnly),
    false,
    "specific channel filter should exclude network-only candidates"
)

BBT.Storage.MarkReported(channelGeneral)
BBT.UI.SetFilter("active")
assertEqual(
    containsCandidate(BBT.UI.FilterCandidates(channelFixtures), channelGeneral),
    false,
    "channel filter should preserve active status filtering"
)
BBT.UI.SetFilter("reported")
assertEqual(
    containsCandidate(BBT.UI.FilterCandidates(channelFixtures), channelGeneral),
    true,
    "channel filter should preserve reported status filtering"
)
BBT.Storage.ClearReported(channelGeneral)
BBT.Storage.SetIgnored(channelGeneral, true)
BBT.UI.SetFilter("active")
assertEqual(
    containsCandidate(BBT.UI.FilterCandidates(channelFixtures), channelGeneral),
    false,
    "channel filter should preserve ignored filtering"
)
BBT.Storage.SetWatched(channelGeneral, true)
assertEqual(
    containsCandidate(BBT.UI.FilterCandidates(channelFixtures), channelGeneral),
    true,
    "watched should still override active filtering with a channel selected"
)
BBT.Storage.SetWatched(channelGeneral, false)
BBT.Storage.SetIgnored(channelGeneral, false)

BBT.UI.SetFilter("all")
BBT.UI.SetChannelFilter("Missing Channel")
BBT.UI.FilterCandidates(channelFixtures)
assertEqual(BBT.UI.GetChannelFilterState(), nil, "stale selected channel should reset to all channels")
BBT.UI.SetFilter("active")
BBT.UI.SetChannelFilter(nil)

BBT.Storage.MarkReported(seller)
BBT.UI.SetFilter("active")
assertEqual(
    containsCandidate(BBT.UI.FilterCandidates(BBT.Storage.GetAllCandidates()), seller),
    false,
    "active filter should hide reported candidates"
)
BBT.Storage.SetWatched(seller, true)
assertEqual(
    containsCandidate(BBT.UI.FilterCandidates(BBT.Storage.GetAllCandidates()), seller),
    true,
    "watched should override active filter hiding"
)
BBT.Storage.SetWatched(seller, false)
BBT.Storage.ClearReported(seller)

BBT.Storage.SetIgnored(switchy, true)
local ignoredMessageCount = switchy.totalMessages
send("Switchy-Area52", "selling raid boost pst", 120)
assertEqual(switchy.totalMessages, ignoredMessageCount + 1, "ignored candidates should keep accumulating evidence")
BBT.UI.SetFilter("active")
assertEqual(
    containsCandidate(BBT.UI.FilterCandidates(BBT.Storage.GetAllCandidates()), switchy),
    false,
    "active filter should hide ignored candidates"
)
BBT.Storage.SetWatched(switchy, true)
assertEqual(
    containsCandidate(BBT.UI.FilterCandidates(BBT.Storage.GetAllCandidates()), switchy),
    true,
    "watched should keep ignored candidates visible"
)
BBT.UI.SetFilter("watched")
BBT.UI.Refresh()
local watchedRow = BBT.UI.GetRowState(1)
assertTruthy(
    watchedRow and watchedRow.candidate and watchedRow.candidate.fullKey == switchy.fullKey,
    "watched filter should show watched candidate"
)
assertTruthy(watchedRow.watchText ~= "", "watched row should expose a watch toggle")
assertEqual(BBT.UI.ClickRowWatch(1), true, "row watch button should be clickable")
assertEqual(BBT.Storage.IsCandidateWatched(switchy), false, "row watch button should toggle watched state off")
BBT.Storage.SetIgnored(switchy, false)
BBT.UI.SetFilter("active")

assertEqual(
    BBT.UI.GetCadenceDisplay({
        timing = {
            intervalCount = 1,
        },
    }).label,
    "Sparse",
    "sparse cadence label"
)
assertEqual(
    BBT.UI.GetCadenceDisplay({
        timing = {
            intervalCount = 8,
            lowestRollingEntropy = 0.92,
            globalEntropy = 0.95,
            dominantBuckets = {
                { bucket = 95, percent = 22 },
            },
        },
    }).label,
    "Variable",
    "variable cadence label"
)

assertContains(
    BBT.UI.BuildEvidenceSummary({
        totalMessages = 0,
        score = { status = "Peer Context Only" },
        network = { peerCount = 1 },
    }),
    "peer clients shared compact evidence",
    "network-only summary should explain peer signal"
)
assertContains(
    BBT.UI.BuildEvidenceSummary({
        totalMessages = 1,
        score = { status = "Observing" },
        network = {},
    }),
    "not enough local evidence",
    "insufficient summary should explain limited evidence"
)

local timingDisplay = {
    displayName = "TimingDisplay-Area52",
    fullKey = "timingdisplay-area52",
    realmKey = "area52",
    channels = { services = 244 },
    daysSeen = { ["2026-05-22"] = true },
    totalMessages = 244,
    firstSeen = fakeNow - 3900,
    firstPromoted = fakeNow - 3840,
    lastSeen = fakeNow,
    timing = {
        averageInterval = 16,
        medianInterval = 16,
        robustCoefficientVariation = 0,
        lowestRollingEntropy = 0,
        intervalCount = 243,
        cadenceClass = "Fixed Cadence",
        cadenceSwitchCount = 0,
        dominantBuckets = {
            { bucket = 20, count = 238, percent = 98 },
            { bucket = 50, count = 2, percent = 0.8 },
            { bucket = 10, count = 1, percent = 0.4 },
        },
        cadencePhases = {
            { bucket = 20, count = 91, duration = 1434, startTime = fakeNow - 3800, endTime = fakeNow - 2366 },
            { bucket = 20, count = 22, duration = 347, startTime = fakeNow - 2200, endTime = fakeNow - 1853 },
            { bucket = 20, count = 49, duration = 800, startTime = fakeNow - 1600, endTime = fakeNow - 800 },
        },
        windowSummaries = {
            w600 = { postsPerHour = 234 },
        },
    },
    content = {
        templateReusePercent = 100,
        shingleReusePercent = 100,
        uniqueTemplateCount = 1,
        nearDuplicateCount = 243,
        adIntentTotal = 244,
    },
    behavior = {
        postsPerHour = 225.3,
    },
    baseline = {
        label = "Above 95th percentile",
        sampleCount = 623,
        postsPerHourPercentile = 94,
        regularityPercentile = 100,
        templateReusePercentile = 100,
    },
    network = {
        peerCount = 0,
        overlap = "None",
    },
    score = {
        status = "Very Strong Pattern",
        tier = "Very Strong Pattern",
        localScore = 100,
        displayScore = 100,
        confidence = 89,
        networkScore = 0,
        evidenceFamilyCount = 5,
        familyScores = {
            timing = 35,
            content = 30,
            activity = 20,
            persistence = 4,
            baseline = 13,
        },
        reasons = {
            "Intervals are almost entirely concentrated around one fixed posting cadence.",
            "100% of local messages reuse the same text pattern.",
        },
    },
}
BBT.UI.SelectCandidate(timingDisplay)
detailState = BBT.UI.GetDetailState()
assertContains(
    detailState.assessment,
    "this repeated chat pattern is worth reviewing",
    "very strong detail summary should explain review"
)
assertContains(detailState.assessment, "fixed ~20s cadence", "critical detail summary should cite cadence metric")
assertContains(detailState.assessment, "peak 234/hr", "critical detail summary should cite peak rate")
assertNotContains(detailState.assessment, "% likely", "critical detail summary should not claim probability")
assertContains(
    detailState.groups.timing.lines[6],
    "<1%",
    "common intervals should show tiny retained buckets as less than one percent"
)
assertNotContains(detailState.groups.timing.lines[6], "0%", "common intervals should not show misleading zero percent")
assertNotContains(detailState.groups.timing.lines[6], "~10s", "common intervals should hide one-off low-signal buckets")
assertContains(
    detailState.groups.timing.lines[7],
    "across 3 runs",
    "stable runs should group repeated same-cadence phases"
)
assertNotContains(detailState.groups.timing.lines[7], "x91", "stable runs should not show raw duplicate phase counts")
assertContains(
    detailState.groups.timing.lines[9],
    "avg 225.3/hr; peak 234.0/hr",
    "rate line should show average and peak rates"
)
BBT.UI.SelectCandidate(seller)

BBT.UI.SetSort("character", false)
local characterSorted = BBT.UI.SortCandidates({
    {
        displayName = "Zed-Area52",
        score = {},
        timing = {},
        content = {},
        behavior = {},
        network = {},
    },
    {
        displayName = "Alpha-Area52",
        score = {},
        timing = {},
        content = {},
        behavior = {},
        network = {},
    },
})
assertEqual(characterSorted[1].displayName, "Alpha-Area52", "character sort is ascending by default")

BBT.UI.SetSort("status", true)
local statusSorted = BBT.UI.SortCandidates({
    {
        displayName = "Observing-Area52",
        score = { status = "Observing" },
        timing = {},
        content = {},
        behavior = {},
        network = {},
    },
    {
        displayName = "Strong-Area52",
        score = {
            status = "Strong Pattern",
            networkAdjustedScore = 50,
        },
        timing = {},
        content = {},
        behavior = {},
        network = {},
    },
})
assertEqual(statusSorted[1].displayName, "Strong-Area52", "status sort orders stronger patterns first")

BBT.UI.SetSort("cadence", true)
local cadenceSorted = BBT.UI.SortCandidates({
    {
        displayName = "Sparse-Area52",
        timing = {
            intervalCount = 1,
        },
        score = {},
        content = {},
        behavior = {},
        network = {},
    },
    {
        displayName = "Regular-Area52",
        timing = {
            intervalCount = 5,
            lowestRollingEntropy = 0.1,
            globalEntropy = 0.1,
            dominantBuckets = {
                { bucket = 120, percent = 100 },
            },
        },
        score = {},
        content = {},
        behavior = {},
        network = {},
    },
})
assertEqual(cadenceSorted[1].displayName, "Regular-Area52", "cadence sort uses deterministic severity order")

BBT.UI.SetSort("watch", true)
local sortKeyAfterWatch = BBT.UI.GetSortState()
assertEqual(sortKeyAfterWatch, "status", "watch action column should not become the active sort")

for _, key in ipairs(BBT.UI.GetColumnKeys()) do
    BBT.UI.SetSort(key, true)
    local sorted = BBT.UI.SortCandidates({
        {
            displayName = "SortB-Area52",
            firstSeen = fakeNow - 20,
            lastSeen = fakeNow - 10,
            totalMessages = 4,
            score = {
                status = "Early Pattern",
                displayScore = 20,
                networkAdjustedScore = 20,
                confidence = 40,
            },
            timing = {
                intervalCount = 4,
                averageInterval = 100,
                lowestRollingEntropy = 0.2,
                globalEntropy = 0.2,
                dominantBuckets = {
                    { bucket = 100, percent = 80 },
                },
            },
            content = {
                templateReusePercent = 75,
            },
            behavior = {
                postsPerHour = 12,
            },
            network = {},
        },
        {
            displayName = "SortA-Area52",
            firstSeen = fakeNow - 30,
            lastSeen = fakeNow - 5,
            totalMessages = 2,
            score = {
                status = "Observing",
                displayScore = 5,
                networkAdjustedScore = 5,
                confidence = 10,
            },
            timing = {},
            content = {},
            behavior = {},
            network = {},
        },
    })
    assertTruthy(sorted[1], "sort should return a first row for " .. key)
end

local networkCandidate = BBT.Storage.MergeNetworkEvidence({
    peerId = "peer-one",
    fullName = "Network-Area52",
    firstSeen = fakeNow - 600,
    lastSeen = fakeNow,
    firstWindow = math.floor((fakeNow - 600) / 1800),
    lastWindow = math.floor(fakeNow / 1800),
    featureVersion = 4,
    messageCount = 12,
    rollingEntropy = 0.2,
    globalEntropy = 0.3,
    templateReusePercent = 80,
    postsPerHour = 12,
    cadenceSwitchCount = 1,
    confidence = 80,
})
assertTruthy(networkCandidate, "network evidence should merge")
assertTruthy(BBT.UI.IsDirty(), "network evidence should mark UI dirty")
assertEqual(networkCandidate.score.localScore, 0, "network-only local score should remain zero")
assertEqual(networkCandidate.score.confidence, 0, "network-only local confidence should remain zero")
assertTruthy((networkCandidate.score.networkScore or 0) > 0, "network-only candidate should keep network context")
assertEqual(networkCandidate.score.status, "Peer Context Only", "network-only candidate should be peer context only")
assertEqual(networkCandidate.network.overlap, "Network only", "network-only overlap context")

seller = BBT.Storage.GetCandidate("Seller-Area52")
local sellerLocalScore = seller.score.localScore
local sellerLocalConfidence = seller.score.confidence
BBT.Storage.MergeNetworkEvidence({
    peerId = "peer-two",
    fullName = "Seller-Area52",
    firstSeen = fakeNow - 600,
    lastSeen = fakeNow,
    firstWindow = math.floor((fakeNow - 600) / 1800),
    lastWindow = math.floor(fakeNow / 1800),
    featureVersion = 4,
    messageCount = 20,
    rollingEntropy = 0.1,
    globalEntropy = 0.2,
    templateReusePercent = 100,
    postsPerHour = 20,
    cadenceSwitchCount = 0,
    confidence = 90,
})
seller = BBT.Storage.GetCandidate("Seller-Area52")
assertEqual(seller.score.localScore, sellerLocalScore, "peer evidence should not increase local score")
assertEqual(seller.score.confidence, sellerLocalConfidence, "peer evidence should not increase local confidence")
assertTruthy((seller.score.networkScore or 0) > 0, "local candidate should still expose network context")
assertTruthy(seller.network.overlap ~= "None", "local candidate should expose network overlap context")

local payload = BBT.Sync.SerializeCandidate(seller)
assertTruthy(payload and #payload <= 240, "sync capsule should stay compact")
local capsule = BBT.Sync.ParseCapsule(payload, "Peer-Area52")
assertTruthy(capsule, "sync capsule should parse")
assertEqual(capsule.featureVersion, 4, "sync capsule feature version")
assertTruthy(capsule.firstWindow > 0 and capsule.lastWindow >= capsule.firstWindow, "sync capsule coarse windows")
assertTruthy(capsule.shingleHashes, "sync capsule shingle hash table")
local rejectedCapsule = BBT.Sync.ParseCapsule("C|2|" .. string.rep("x", 260), "Peer-Area52")
assertEqual(rejectedCapsule, nil, "oversized sync packet should reject")
rejectedCapsule = BBT.Sync.ParseCapsule("C|1|Bad-Area52", "Peer-Area52")
assertEqual(rejectedCapsule, nil, "wrong sync protocol should reject")
local joinedCustomChannel = false
_G.JoinTemporaryChannel = function()
    joinedCustomChannel = true
end
_G.GetChannelName = function()
    return 0
end

local function expectSyncTransport(
    label,
    includeGuild,
    includeGroup,
    inGuild,
    inGroup,
    inRaid,
    inInstanceGroup,
    expected
)
    BBT.Sync.SetEnabled(false)
    BBT.Storage.GetSettings().sync.includeGuild = includeGuild
    BBT.Storage.GetSettings().sync.includeGroup = includeGroup
    _G.C_ChatInfo.sentAddonMessages = {}
    fakeInGuild = inGuild
    fakeInGroup = inGroup
    fakeInRaid = inRaid
    fakeInInstanceGroup = inInstanceGroup
    BBT.Sync.lastSendAt = 0
    seller.lastSyncQueuedAt = nil
    BBT.Sync.SetEnabled(true)
    BBT.Sync.QueueCandidate(seller)
    BBT.Sync.SendNext()

    if expected then
        assertEqual(#_G.C_ChatInfo.sentAddonMessages, 1, label .. " should send one hidden addon message")
        assertEqual(_G.C_ChatInfo.sentAddonMessages[1].prefix, "BigBotTrack", label .. " sync prefix")
        assertEqual(_G.C_ChatInfo.sentAddonMessages[1].chatType, expected, label .. " sync transport")
        assertEqual(_G.C_ChatInfo.sentAddonMessages[1].target, nil, label .. " sync should not target a custom channel")
    else
        assertEqual(#_G.C_ChatInfo.sentAddonMessages, 0, label .. " should not send without a transport")
        assertEqual(BBT.Sync.status, "Waiting for guild/group", label .. " sync waiting status")
    end
end

expectSyncTransport("guild", true, false, true, false, false, false, "GUILD")
expectSyncTransport("party", false, true, false, true, false, false, "PARTY")
expectSyncTransport("raid", false, true, false, false, true, false, "RAID")
expectSyncTransport("instance", false, true, false, false, false, true, "INSTANCE_CHAT")
expectSyncTransport("no transport", true, true, false, false, false, false, nil)
assertEqual(joinedCustomChannel, false, "sync should not join custom chat channels")

local function networkPayloadFor(fullName)
    local firstSeen = fakeNow - 60
    local lastSeen = fakeNow
    return table.concat({
        "C",
        "2",
        "4",
        fullName,
        tostring(firstSeen),
        tostring(lastSeen),
        tostring(math.floor(firstSeen / 1800)),
        tostring(math.floor(lastSeen / 1800)),
        "3",
        "60",
        "10",
        "80",
        "80",
        "67",
        "67",
        "0",
        "12",
        "50",
        "",
        "",
    }, "|")
end

BBT.Sync.SetEnabled(true)
local ignoredChannelCount = #BBT.Storage.GetAllCandidates()
BBT.Sync.HandleAddonMessage("BigBotTrack", networkPayloadFor("ChannelOnly-Area52"), "CHANNEL", "Peer-Area52")
assertEqual(#BBT.Storage.GetAllCandidates(), ignoredChannelCount, "CHANNEL addon packets should be ignored")
BBT.Sync.HandleAddonMessage("BigBotTrack", networkPayloadFor("WhisperOnly-Area52"), "WHISPER", "Peer-Area52")
assertEqual(#BBT.Storage.GetAllCandidates(), ignoredChannelCount, "WHISPER addon packets should be ignored")
BBT.Sync.HandleAddonMessage("BigBotTrack", networkPayloadFor("GuildOnly-Area52"), "GUILD", "Peer-Area52")
assertTruthy(BBT.Storage.GetCandidate("GuildOnly-Area52"), "GUILD addon packets should still merge")
BBT.Sync.SetEnabled(false)
BBT.Storage.GetSettings().sync.includeGuild = true
BBT.Storage.GetSettings().sync.includeGroup = true

for _ = 1, 3 do
    fakeNow = fakeNow + 60
    BBT.ChatScanner.HandleChannelMessage(
        "WTS classic raid boost now",
        "ClassicSeller-Area52",
        "2. Trade - City",
        nil,
        2,
        "Trade",
        nil,
        nil
    )
end
assertTruthy(
    BBT.Storage.GetCandidate("ClassicSeller-Area52"),
    "Classic-style channel events should handle missing line and guid"
)
local futureCandidate, futureReason = BBT.Storage.MergeNetworkEvidence({
    peerId = "peer-future",
    fullName = "Future-Area52",
    firstSeen = fakeNow,
    lastSeen = fakeNow + 7200,
    featureVersion = 4,
})
assertEqual(futureCandidate, nil, "future network evidence should reject")
assertEqual(futureReason, "future", "future network rejection reason")
local staleCandidate, staleReason = BBT.Storage.MergeNetworkEvidence({
    peerId = "peer-stale",
    fullName = "Stale-Area52",
    firstSeen = fakeNow - (40 * 86400),
    lastSeen = fakeNow - (40 * 86400),
    featureVersion = 4,
})
assertEqual(staleCandidate, nil, "stale network evidence should reject")
assertEqual(staleReason, "stale", "stale network rejection reason")

local originalBaseline = BBT.Storage.GetBaselineComparison
BBT.Storage.GetBaselineComparison = function()
    return {
        sampleCount = 20,
        postsPerHourPercentile = 100,
        regularityPercentile = 100,
        templateReusePercentile = 100,
        label = "Above 95th percentile",
    }
end
local baselineOnly = {
    displayName = "BaselineOnly-Area52",
    fullKey = "baselineonly-area52",
    realmKey = "area52",
    channels = { trade = 1 },
    daysSeen = {},
    totalMessages = 1,
    firstSeen = fakeNow,
    lastSeen = fakeNow,
    timing = { intervals = {}, intervalCount = 0 },
    content = { templateCounts = {}, shingleCounts = {}, adIntentCounts = {} },
    behavior = {},
    network = {},
}
BBT.Scoring.Recalculate(baselineOnly, BBT.Storage.GetSettings())
BBT.Storage.GetBaselineComparison = originalBaseline
assertTruthy(
    (baselineOnly.score.networkAdjustedScore or 0) < 70,
    "baseline-only pattern strength should stay below strong"
)
assertEqual(baselineOnly.score.status, "Observing", "baseline-only evidence should not leave observing")

local function makeConfidenceCandidate(dayCount)
    local baseTime = fakeNow + 10000
    local intervals = {}
    for index = 1, 12 do
        intervals[index] = {
            t = baseTime + (index * 120),
            s = 120,
            b = 120,
        }
    end

    local daysSeen = {}
    for index = 1, dayCount do
        daysSeen["day-" .. tostring(index)] = true
    end

    return {
        displayName = "ConfidenceFixture-Area52",
        fullKey = "confidencefixture-area52",
        realmKey = "area52",
        channels = { trade = 1 },
        daysSeen = daysSeen,
        totalMessages = 18,
        firstSeen = baseTime,
        lastSeen = baseTime + 1440,
        timing = {
            intervals = intervals,
            intervalCount = 12,
        },
        content = {
            templateCounts = { fixed = 18 },
            templateTotal = 18,
            shingleCounts = { fixed = 18 },
            shingleTotal = 18,
            adIntentCounts = { boost = 18 },
            adIntentTotal = 18,
            nearDuplicateCount = 18,
        },
        behavior = {
            burstCount = 2,
            longestActiveSpan = 1800,
        },
        network = {},
    }
end

local oneDayConfidence = makeConfidenceCandidate(1)
BBT.Scoring.Recalculate(oneDayConfidence, BBT.Storage.GetSettings())
assertTruthy(oneDayConfidence.score.confidence < 90, "one-day confidence should stay below 90")

local threeDayConfidence = makeConfidenceCandidate(3)
BBT.Scoring.Recalculate(threeDayConfidence, BBT.Storage.GetSettings())
assertEqual(threeDayConfidence.score.confidence, 100, "three-day maxed evidence can reach 100 confidence")

local passiveRefreshCount = BBT.UI.GetRefreshCount()
BBT.UI.OnUpdate(0.51)
BBT.UI.OnUpdate(5)
assertTruthy(BBT.UI.GetRefreshCount() > passiveRefreshCount, "visible UI should refresh passively")

BBT.runtime.pretrack.fixture = true
BBT.runtime.recentNormalized.fixture = true
BBT.runtime.seenLines[12345] = true
BBT.runtime.baselineSampled.fixture = true
BBT.Storage.ClearRuntimeBuffers()
assertEqual(next(BBT.runtime.pretrack), nil, "clear buffers should empty pretrack")
assertEqual(next(BBT.runtime.recentNormalized), nil, "clear buffers should empty recent normalized cache")
assertEqual(next(BBT.runtime.seenLines), nil, "clear buffers should empty line dedupe cache")
assertEqual(next(BBT.runtime.baselineSampled), nil, "clear buffers should empty baseline cooldown cache")

local currentEpoch = BBT.Storage.GetCurrentDataEpoch()

BigBotTrackerDB = {
    schemaVersion = 3,
    featureVersion = 3,
    settings = {
        debug = true,
        sync = {
            enabled = true,
            firstRunNoticeShown = true,
            includeGuild = false,
            includeGroup = true,
        },
        monitor = {
            public = false,
            trade = true,
            services = false,
        },
        ui = {
            sortKey = "character",
            sortDescending = false,
            filterKey = "all",
            channelFilter = "Trade",
        },
        lastDebugSummary = "old summary",
    },
    candidates = {
        area52 = {
            old = {
                displayName = "Old-Area52",
            },
        },
    },
    templates = {
        oldhash = { count = 99 },
    },
    baselines = {
        realms = {
            area52 = {
                channels = {
                    Trade = { sampleCount = 99 },
                },
            },
        },
    },
    peers = {
        old = true,
    },
    sessions = {
        old = {
            startedAt = fakeNow,
        },
    },
}
BBT.DB = BigBotTrackerDB
BBT.runtime = {
    pretrack = { old = true },
    recentNormalized = { old = true },
    seenLines = { old = true },
    baselineSampled = { old = true },
}
BBT.Storage.Initialize()
assertEqual(BigBotTrackerDB.schemaVersion, 4, "epoch cutover should install current schema")
assertEqual(BigBotTrackerDB.featureVersion, 4, "epoch cutover should install current feature version")
assertEqual(BigBotTrackerDB.dataEpoch, currentEpoch, "epoch cutover should stamp current data epoch")
assertEqual(next(BigBotTrackerDB.candidates), nil, "epoch cutover should clear old candidates")
assertEqual(next(BigBotTrackerDB.templates), nil, "epoch cutover should clear old templates")
assertEqual(next(BigBotTrackerDB.baselines.realms), nil, "epoch cutover should clear old baselines")
assertEqual(next(BigBotTrackerDB.peers), nil, "epoch cutover should clear old peers")
assertEqual(BigBotTrackerDB.sessions, nil, "epoch cutover should not keep saved sessions")
assertEqual(BigBotTrackerDB.settings.debug, true, "epoch cutover should preserve debug preference")
assertEqual(BigBotTrackerDB.settings.sync.enabled, true, "epoch cutover should preserve sync preference")
assertEqual(
    BigBotTrackerDB.settings.sync.includeGuild,
    false,
    "epoch cutover should preserve sync transport preference"
)
assertEqual(BigBotTrackerDB.settings.monitor.public, false, "epoch cutover should preserve monitor preference")
assertEqual(BigBotTrackerDB.settings.ui.sortKey, "character", "epoch cutover should preserve UI sort preference")
assertEqual(BigBotTrackerDB.settings.lastDebugSummary, nil, "epoch cutover should clear debug summaries")
assertEqual(
    BigBotTrackerDB.resetHistory[1].reason,
    "player-facing-detection-cutover",
    "epoch cutover should record reset reason"
)
assertTruthy(BBT.runtime and BBT.runtime.pretrack, "epoch cutover should recreate runtime buffers")
assertEqual(next(BBT.runtime.pretrack), nil, "epoch cutover should clear runtime pretrack")

BigBotTrackerDB.candidates.area52 = {
    fresh = {
        name = "Fresh",
        realm = "Area52",
        nameKey = "fresh",
        realmKey = "area52",
        fullKey = "fresh-area52",
        displayName = "Fresh-Area52",
        firstSeen = fakeNow,
        lastSeen = fakeNow,
        totalMessages = 1,
        timing = { intervals = {}, intervalCount = 0 },
        content = { templateCounts = {}, shingleCounts = {}, adIntentCounts = {} },
        behavior = {},
        network = {},
        channels = { Trade = 1 },
        daysSeen = {},
        observationWindows = {},
        score = { status = "Observing" },
    },
}
local resetHistoryCount = #BigBotTrackerDB.resetHistory
BBT.Storage.Initialize()
assertTruthy(BBT.Storage.GetCandidate("Fresh-Area52"), "current epoch should keep current evidence")
assertEqual(#BigBotTrackerDB.resetHistory, resetHistoryCount, "current epoch should not reset again")

BigBotTrackerDB = nil
BBT.DB = nil
BBT.runtime = nil
BBT.Storage.Initialize()
assertEqual(BigBotTrackerDB.dataEpoch, currentEpoch, "new install should stamp current data epoch")
assertEqual(#BigBotTrackerDB.resetHistory, 0, "new install should not record a reset")
assertEqual(next(BigBotTrackerDB.candidates), nil, "new install should start with no candidates")

print("Lua fixture tests passed.")

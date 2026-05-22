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

loadModule("Util.lua")
loadModule("Normalizer.lua")
loadModule("Scoring.lua")
loadModule("Storage.lua")
loadModule("ChatScanner.lua")
loadModule("Sync.lua")
loadModule("Report.lua")
loadModule("UI.lua")

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

local scoreHeader = BBT.UI.GetHeaderState("score")
assertTruthy(scoreHeader, "score header state")
assertEqual(scoreHeader.label, "Score", "header label should not include sort marker text")
assertTruthy(scoreHeader.arrowShown, "active sort header should show arrow")
assertEqual(scoreHeader.arrowTexCoord, "0,1,1,0", "descending sort arrow orientation")

local function send(sender, text, seconds)
    fakeNow = fakeNow + (seconds or 0)
    BBT.ChatScanner.HandleChannelMessage(text, sender, "2. Trade - City", nil, 2, "Trade", fakeNow, "guid")
end

assertEqual(BBT.UI.GetRefreshCount(), 0, "hidden UI starts with no refreshes")
BBT.UI.MarkDirty("hidden-test")
BBT.UI.OnUpdate(1)
assertEqual(BBT.UI.GetRefreshCount(), 0, "hidden UI should not refresh")

send("Casual-Area52", "hello trade", 0)
send("Casual-Area52", "anyone crafting?", 60)
send("Casual-Area52", "is anyone around?", 60)
assertEqual(BBT.Storage.GetCandidate("Casual-Area52"), nil, "casual chatter should not persist")

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
BBT.UI.SetSort("score", false)
BBT.UI.Refresh()
scoreHeader = BBT.UI.GetHeaderState("score")
assertEqual(scoreHeader.label, "Score", "sorted header label should remain clean")
assertTruthy(scoreHeader.arrowShown, "sorted header should show arrow after refresh")
assertEqual(scoreHeader.arrowTexCoord, "0,1,0,1", "ascending sort arrow orientation")
BBT.UI.SetSort("score", true)
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
assertTruthy((seller.score.networkAdjustedScore or 0) >= 45, "fixed cadence should score at least medium")
assertEqual(seller.featureVersion, 3, "seller feature version")
assertTruthy((seller.score.familyScores.timing or 0) > 0, "seller timing family score")
assertTruthy((seller.score.familyScores.content or 0) > 0, "seller content family score")
assertTruthy((seller.score.evidenceFamilyCount or 0) >= 2, "seller should have multiple evidence families")
assertEqual(seller.score.tier, "High", "fixed repeated seller should reach high tier")
assertEqual(seller.lastGuid, "guid", "seller should persist latest chat sender guid")
assertTruthy(seller.lastLineID, "seller should persist latest chat line id")
assertTruthy(seller.lastReportObservedAt, "seller should persist report observation timestamp")

local beforeReload = {
    localScore = seller.score.localScore,
    confidence = seller.score.confidence,
    tier = seller.score.tier,
    familyCount = seller.score.evidenceFamilyCount,
    timing = seller.score.familyScores.timing,
    content = seller.score.familyScores.content,
    activity = seller.score.familyScores.activity,
    persistence = seller.score.familyScores.persistence,
    baseline = seller.score.familyScores.baseline,
}
BBT.runtime = nil
BBT.Storage.Initialize()
assertTruthy(BBT.runtime and BBT.runtime.pretrack, "reload should recreate runtime buffers")
seller = BBT.Storage.GetCandidate("Seller-Area52")
assertEqual(seller.score.localScore, beforeReload.localScore, "reload should not increase local score")
assertEqual(seller.score.confidence, beforeReload.confidence, "reload should not increase confidence")
assertEqual(seller.score.tier, beforeReload.tier, "reload should not change tier")
assertEqual(seller.score.evidenceFamilyCount, beforeReload.familyCount, "reload should not change family count")
assertEqual(seller.score.familyScores.timing, beforeReload.timing, "reload should not change timing family")
assertEqual(seller.score.familyScores.content, beforeReload.content, "reload should not change content family")
assertEqual(seller.score.familyScores.activity, beforeReload.activity, "reload should not change activity family")
assertEqual(seller.score.familyScores.persistence, beforeReload.persistence, "reload should not change persistence family")
assertEqual(seller.score.familyScores.baseline, beforeReload.baseline, "reload should not change baseline family")

local originalSellerTier = seller.score.tier
BBT.UI.SelectCandidate(seller)
local reportState = BBT.UI.GetReportControlState()
assertEqual(reportState.reportShown, false, "botting report action should hide below Critical")

seller.score.tier = "Critical"
seller.lastGuid = "reportable-guid"
BBT.UI.SelectCandidate(seller)
reportState = BBT.UI.GetReportControlState()
assertEqual(reportState.reportShown, true, "botting report action should show for Critical candidates")
assertEqual(reportState.reportEnabled, true, "botting report action should enable for Critical candidates")

local reportComment = BBT.Report.BuildReportComment(seller)
assertEqual(reportComment:sub(1, 16), "Big Bot Tracker:", "report comment should cite addon source")
assertTruthy(#reportComment <= BBT.Report.REPORT_COMMENT_LIMIT, "report comment should fit Blizzard limit")
assertTruthy(reportComment:find("Suspected automated", 1, true), "report comment should use report language")
assertTruthy(reportComment:find("interval", 1, true), "report comment should prioritize interval")
assertEqual(reportComment:find("near", 1, true), nil, "report comment should avoid near-metric wording")
assertEqual(reportComment:find("cadence", 1, true), nil, "report comment should avoid cadence jargon")
assertTruthy(reportComment:find("posts", 1, true), "report comment should include observation volume")
assertTruthy(reportComment:find("reused text", 1, true), "report comment should include content reuse")
assertTruthy(reportComment:find("%% confidence"), "report comment should include percentage confidence")
assertEqual(reportComment:find("score", 1, true), nil, "report comment should not include score")
assertEqual(reportComment:find("WTS", 1, true), nil, "report comment should not include raw chat text")

local reportAssist = BBT.Report.BuildReportAssist(seller)
assertEqual(reportAssist.comment, reportComment, "assist should reuse report comment")
assertTruthy(#reportAssist.bullets >= 2, "assist should include evidence bullets")
assertTruthy(reportAssist.bullets[1]:find("Suspicious", 1, true), "assist bullets should label suspicious behavior")

local reportOpenCountBeforeClick = ReportFrame.openCount
_G.BigBotTrackerFrame.reportButton.scripts.OnClick(_G.BigBotTrackerFrame.reportButton)
assertEqual(ReportFrame.openCount, reportOpenCountBeforeClick + 1, "report click should open Blizzard report frame")
local assistState = BBT.UI.GetReportAssistState()
assertEqual(assistState.shown, true, "report click should show Big Bot Tracker assist dialog")
assertEqual(assistState.comment, reportComment, "assist dialog should show selectable report comment")
assertEqual(_G.BigBotTrackerReportAssistFrame.commentEdit.multiLine, true, "assist comment field should be multiline")
assertEqual(_G.BigBotTrackerReportAssistFrame.commentEdit.template, nil, "assist comment field should not use single-line input template")
assertEqual(_G.BigBotTrackerReportAssistFrame.body, nil, "assist dialog should not use a masking body overlay")
assertTruthy(assistState.status:find("Blizzard report opened", 1, true), "assist dialog should show opened status")
assertTruthy(assistState.bullets[1]:find("Suspicious", 1, true), "assist dialog should show evidence bullets")
_G.BigBotTrackerReportAssistFrame.selectButton.scripts.OnClick(_G.BigBotTrackerReportAssistFrame.selectButton)
assertEqual(_G.BigBotTrackerReportAssistFrame.commentEdit.focused, true, "select button should focus comment field")
assertEqual(_G.BigBotTrackerReportAssistFrame.commentEdit.highlighted, true, "select button should highlight comment field")

local reportDiagnostic = seller.lastReportDiagnostic
assertEqual(reportDiagnostic.source, "guid", "guid should be used when target is unavailable")
assertEqual(ReportFrame.lastReport.reportInfo.reportType, Enum.ReportType.InWorld, "report flow should use InWorld type")
assertEqual(ReportFrame.lastReport.playerName, seller.displayName, "report frame should receive candidate name")
assertEqual(seller.lastReportDiagnostic.canOpen, true, "candidate should retain positive report diagnostic")

local reportOpenCount = ReportFrame.openCount
seller.lastGuid = "blocked-guid"
seller.lastLineID = 987654
BBT.UI.SelectCandidate(seller)
_G.BigBotTrackerFrame.reportButton.scripts.OnClick(_G.BigBotTrackerFrame.reportButton)
local blockedDiagnostic = seller.lastReportDiagnostic
assertEqual(ReportFrame.openCount, reportOpenCount, "chat line fallback should not open report frame")
assistState = BBT.UI.GetReportAssistState()
assertEqual(assistState.shown, true, "failed report open should keep assist dialog visible")
assertTruthy(assistState.status:find("No reportable in-world player location", 1, true), "assist dialog should show diagnostic failure reason")
assertEqual(blockedDiagnostic.guidCanReport, false, "blocked guid should be diagnosed")
assertEqual(blockedDiagnostic.chatLineCanReport, true, "chat-line reportability should be diagnostic only")
assertEqual(blockedDiagnostic.canOpen, false, "blocked guid should not be openable")

seller.lastGuid = "guid"
seller.score.tier = originalSellerTier
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
assertEqual(BBT.UI.GetCadenceDisplay(switchy).label, "Mixed Regular", "schedule switch cadence label")

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
assertTruthy((jitter.score.networkAdjustedScore or 0) >= 45, "jittered repeated ad should reach at least medium")

send("ContentOnly-Area52", "WTS rare pet cheap pst", 900)
send("ContentOnly-Area52", "WTS rare pet cheap pst", 133)
send("ContentOnly-Area52", "WTS rare pet cheap pst", 777)
local contentOnly = BBT.Storage.GetCandidate("ContentOnly-Area52")
assertTruthy(contentOnly, "content-only repeated ad should promote")
assertTruthy((contentOnly.score.networkAdjustedScore or 0) < 70, "content-only evidence should stay below high")
assertTruthy(
    contentOnly.score.tier ~= "High" and contentOnly.score.tier ~= "Critical",
    "content-only evidence should not high-tier"
)

send("TimingOnly-Area52", "casual note alpha beta gamma", 120)
send("TimingOnly-Area52", "different words delta epsilon zeta", 120)
send("TimingOnly-Area52", "another phrase eta theta iota", 120)
send("TimingOnly-Area52", "fresh line kappa lambda mu", 120)
send("TimingOnly-Area52", "separate text nu xi omicron", 120)
local timingOnly = BBT.Storage.GetCandidate("TimingOnly-Area52")
assertTruthy(timingOnly, "timing-only regular fixture should promote")
assertTruthy((timingOnly.score.networkAdjustedScore or 0) < 70, "timing-only evidence should stay below high")

send("Mirror-Illidan", "WTS raid boost now", 60)
send("Mirror-Illidan", "WTS raid boost now", 60)
send("Mirror-Illidan", "WTS raid boost now", 60)
send("Mirror-Area52", "WTS raid boost now", 60)
send("Mirror-Area52", "WTS raid boost now", 60)
send("Mirror-Area52", "WTS raid boost now", 60)

assertTruthy(BBT.Storage.GetCandidate("Mirror-Illidan"), "illidan mirror candidate")
assertTruthy(BBT.Storage.GetCandidate("Mirror-Area52"), "area52 mirror candidate")

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

BBT.UI.SetSort("score", true)
local scoreSorted = BBT.UI.SortCandidates({
    {
        displayName = "NoScore-Area52",
        score = {},
        timing = {},
        content = {},
        behavior = {},
        network = {},
    },
    {
        displayName = "Scored-Area52",
        score = {
            networkAdjustedScore = 50,
        },
        timing = {},
        content = {},
        behavior = {},
        network = {},
    },
})
assertEqual(scoreSorted[1].displayName, "Scored-Area52", "numeric sort handles missing values")

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

for _, key in ipairs(BBT.UI.GetColumnKeys()) do
    BBT.UI.SetSort(key, true)
    local sorted = BBT.UI.SortCandidates({
        {
            displayName = "SortB-Area52",
            firstSeen = fakeNow - 20,
            lastSeen = fakeNow - 10,
            totalMessages = 4,
            score = {
                tier = "Low",
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
                tier = "Insufficient Data",
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
    featureVersion = 3,
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
assertEqual(networkCandidate.score.tier, "Preliminary", "network-only candidate should be preliminary")
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
    featureVersion = 3,
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
assertEqual(capsule.featureVersion, 3, "sync capsule feature version")
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
_G.C_ChatInfo.sentAddonMessages = {}
fakeInGuild = true
fakeInGroup = false
fakeInRaid = false
fakeInInstanceGroup = false
BBT.Sync.SetEnabled(true)
BBT.Sync.QueueCandidate(seller)
BBT.Sync.SendNext()
assertEqual(#_G.C_ChatInfo.sentAddonMessages, 1, "sync should send one hidden addon message")
assertEqual(_G.C_ChatInfo.sentAddonMessages[1].prefix, "BigBotTrack", "sync prefix")
assertEqual(_G.C_ChatInfo.sentAddonMessages[1].chatType, "GUILD", "sync should use hidden guild transport")
assertEqual(_G.C_ChatInfo.sentAddonMessages[1].target, nil, "sync should not target a custom channel")
assertEqual(joinedCustomChannel, false, "sync should not join custom chat channels")
BBT.Sync.SetEnabled(false)
local futureCandidate, futureReason = BBT.Storage.MergeNetworkEvidence({
    peerId = "peer-future",
    fullName = "Future-Area52",
    firstSeen = fakeNow,
    lastSeen = fakeNow + 7200,
    featureVersion = 3,
})
assertEqual(futureCandidate, nil, "future network evidence should reject")
assertEqual(futureReason, "future", "future network rejection reason")
local staleCandidate, staleReason = BBT.Storage.MergeNetworkEvidence({
    peerId = "peer-stale",
    fullName = "Stale-Area52",
    firstSeen = fakeNow - (40 * 86400),
    lastSeen = fakeNow - (40 * 86400),
    featureVersion = 3,
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
assertTruthy((baselineOnly.score.networkAdjustedScore or 0) < 70, "baseline-only score should stay below high")
assertEqual(baselineOnly.score.tier, "Insufficient Data", "baseline-only evidence should not tier up")

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

BigBotTrackerDB = {
    schemaVersion = 2,
    candidates = {
        area52 = {
            old = {
                displayName = "Old-Area52",
            },
        },
    },
    sessions = {
        old = {
            startedAt = fakeNow,
        },
    },
}
BBT.DB = BigBotTrackerDB
BBT.runtime = nil
BBT.Storage.Initialize()
assertEqual(BigBotTrackerDB.schemaVersion, 3, "schema clean cutover should install current schema")
assertEqual(next(BigBotTrackerDB.candidates), nil, "schema clean cutover should clear old candidates")
assertEqual(BigBotTrackerDB.sessions, nil, "schema clean cutover should not keep saved sessions")
assertTruthy(BBT.runtime and BBT.runtime.pretrack, "schema clean cutover should recreate runtime buffers")

print("Lua fixture tests passed.")

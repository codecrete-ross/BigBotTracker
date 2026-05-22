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
    function widget:SetPoint() end
    function widget:SetMovable() end
    function widget:SetClampedToScreen() end
    function widget:EnableMouse() end
    function widget:EnableMouseWheel() end
    function widget:RegisterForDrag() end
    function widget:SetFrameStrata(strata)
        self.frameStrata = strata
    end
    function widget:SetFrameLevel(level)
        self.frameLevel = level
    end
    function widget:SetToplevel(topLevel)
        self.topLevel = topLevel
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
    function widget:CreateFontString()
        local font = makeWidget()
        function font:SetJustifyH() end
        function font:SetWidth() end
        function font:SetWordWrap() end
        function font:SetTextColor() end
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
loadModule("UI.lua")

BBT.Storage.Initialize()
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
assertEqual(seller.featureVersion, 2, "seller feature version")
assertTruthy((seller.score.familyScores.timing or 0) > 0, "seller timing family score")
assertTruthy((seller.score.familyScores.content or 0) > 0, "seller content family score")
assertTruthy((seller.score.evidenceFamilyCount or 0) >= 2, "seller should have multiple evidence families")
assertEqual(seller.score.tier, "High", "fixed repeated seller should reach high tier")

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
    featureVersion = 2,
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
    featureVersion = 2,
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
assertEqual(capsule.featureVersion, 2, "sync capsule feature version")
assertTruthy(capsule.firstWindow > 0 and capsule.lastWindow >= capsule.firstWindow, "sync capsule coarse windows")
assertTruthy(capsule.shingleHashes, "sync capsule shingle hash table")
local rejectedCapsule = BBT.Sync.ParseCapsule("C|2|" .. string.rep("x", 260), "Peer-Area52")
assertEqual(rejectedCapsule, nil, "oversized sync packet should reject")
rejectedCapsule = BBT.Sync.ParseCapsule("C|1|Bad-Area52", "Peer-Area52")
assertEqual(rejectedCapsule, nil, "wrong sync protocol should reject")
local futureCandidate, futureReason = BBT.Storage.MergeNetworkEvidence({
    peerId = "peer-future",
    fullName = "Future-Area52",
    firstSeen = fakeNow,
    lastSeen = fakeNow + 7200,
    featureVersion = 2,
})
assertEqual(futureCandidate, nil, "future network evidence should reject")
assertEqual(futureReason, "future", "future network rejection reason")
local staleCandidate, staleReason = BBT.Storage.MergeNetworkEvidence({
    peerId = "peer-stale",
    fullName = "Stale-Area52",
    firstSeen = fakeNow - (40 * 86400),
    lastSeen = fakeNow - (40 * 86400),
    featureVersion = 2,
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
    sessionsSeen = {},
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

local passiveRefreshCount = BBT.UI.GetRefreshCount()
BBT.UI.OnUpdate(0.51)
BBT.UI.OnUpdate(5)
assertTruthy(BBT.UI.GetRefreshCount() > passiveRefreshCount, "visible UI should refresh passively")

print("Lua fixture tests passed.")

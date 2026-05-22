local root = arg and arg[1] or "."
local BBT = {}
local fakeNow = 1700000000

_G.BigBotTracker = BBT
_G.BigBotTrackerDB = nil
_G.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
_G.UIParent = {}

local function makeWidget()
    local widget = { shown = false }

    function widget:SetSize() end
    function widget:SetPoint() end
    function widget:SetMovable() end
    function widget:SetClampedToScreen() end
    function widget:EnableMouse() end
    function widget:RegisterForDrag() end
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
    function widget:IsShown()
        return self.shown
    end
    function widget:CreateFontString()
        local font = makeWidget()
        function font:SetJustifyH() end
        function font:SetWidth() end
        function font:SetWordWrap() end
        function font:SetText(text)
            self.text = text
        end
        return font
    end
    function widget:CreateTexture()
        local texture = makeWidget()
        function texture:SetAllPoints() end
        function texture:SetColorTexture() end
        return texture
    end
    function widget:SetText(text)
        self.text = text
    end
    widget.StartMoving = function() end
    widget.StopMovingOrSizing = function() end

    return widget
end

function _G.CreateFrame()
    return makeWidget()
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
loadModule("UI.lua")
loadModule("ChatScanner.lua")

BBT.Storage.Initialize()
BBT.UI.Create()

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
assertEqual(BBT.Storage.GetCandidate("Casual-Area52"), nil, "casual chatter should not persist")

send("Seller-Area52", "WTS mythic carry now", 60)
send("Seller-Area52", "WTS mythic carry now", 120)

local seller = BBT.Storage.GetCandidate("Seller-Area52")
assertTruthy(seller, "near-duplicate seller should promote")
assertEqual(seller.realmKey, "area52", "seller realm key")
assertTruthy(BBT.UI.IsDirty(), "promotion should mark UI dirty")

local refreshCountBeforeOpen = BBT.UI.GetRefreshCount()
BBT.UI.Open()
assertTruthy(BBT.UI.GetRefreshCount() > refreshCountBeforeOpen, "opening UI should refresh")
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
assertTruthy((seller.score.networkAdjustedScore or 0) >= 45, "fixed cadence should score at least medium")

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

send("Mirror-Illidan", "WTS raid boost", 60)
send("Mirror-Illidan", "WTS raid boost", 60)
send("Mirror-Area52", "WTS raid boost", 60)
send("Mirror-Area52", "WTS raid boost", 60)

assertTruthy(BBT.Storage.GetCandidate("Mirror-Illidan"), "illidan mirror candidate")
assertTruthy(BBT.Storage.GetCandidate("Mirror-Area52"), "area52 mirror candidate")

local networkCandidate = BBT.Storage.MergeNetworkEvidence({
    peerId = "peer-one",
    fullName = "Network-Area52",
    firstSeen = fakeNow - 600,
    lastSeen = fakeNow,
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

local passiveRefreshCount = BBT.UI.GetRefreshCount()
BBT.UI.OnUpdate(0.51)
BBT.UI.OnUpdate(5)
assertTruthy(BBT.UI.GetRefreshCount() > passiveRefreshCount, "visible UI should refresh passively")

print("Lua fixture tests passed.")

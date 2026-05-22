local root = arg and arg[1] or "."
local BBT = {}
local fakeNow = 1700000000

_G.BigBotTracker = BBT
_G.BigBotTrackerDB = nil
_G.DEFAULT_CHAT_FRAME = { AddMessage = function() end }

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

BBT.Storage.Initialize()

local function send(sender, text, seconds)
    fakeNow = fakeNow + (seconds or 0)
    BBT.ChatScanner.HandleChannelMessage(text, sender, "2. Trade - City", nil, 2, "Trade", fakeNow, "guid")
end

send("Casual-Area52", "hello trade", 0)
send("Casual-Area52", "anyone crafting?", 60)
assertEqual(BBT.Storage.GetCandidate("Casual-Area52"), nil, "casual chatter should not persist")

send("Seller-Area52", "WTS mythic carry now", 60)
send("Seller-Area52", "WTS mythic carry now", 120)

local seller = BBT.Storage.GetCandidate("Seller-Area52")
assertTruthy(seller, "near-duplicate seller should promote")
assertEqual(seller.realmKey, "area52", "seller realm key")

send("Seller-Area52", "WTS mythic carry now", 120)
send("Seller-Area52", "WTS mythic carry now", 120)
send("Seller-Area52", "WTS mythic carry now", 120)
send("Seller-Area52", "WTS mythic carry now", 120)

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

print("Lua fixture tests passed.")

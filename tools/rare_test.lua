-- Runs the REAL SpawnDB.lua / QuestWatcher.lua / Advisor.lua under stubbed 3.3.5
-- WoW APIs and asserts the rare-quest completion fix (CBH v1.5.3).
-- Executed by rare_test.js via fengari.

local ADDON = ADDON_DIR  -- injected by the JS side

-- ------------------------------------------------------------------ WoW stubs
local noop = function() end
local function stubFrame()
   local f = {}
   setmetatable(f, { __index = function() return function() return nil end end })
   f.t = 0
   return f
end
function CreateFrame() return stubFrame() end
WorldMapFrame = stubFrame()
UIParent = stubFrame()
GameTooltip = stubFrame()

_G.time = os.time
_G.date = os.date
function GetTime() return 1000 end
function GetRealZoneText() return CURRENT_ZONE or "Stormwind City" end
function GetSubZoneText() return "" end
function GetNumPartyMembers() return 0 end
function SendChatMessage() end
function SetMapToCurrentZone() end
function GetPlayerMapPosition() return 0, 0 end
function GetCurrentMapContinent() return 4 end
function GetCurrentMapZone() return 1 end
function SetMapZoom() end
function GetNumQuestWatches() return 0 end
function GetQuestIndexForWatch() return nil end
function QuestPOIGetIconInfo() return nil end
function InCombatLockdown() return false end
function UnitCastingInfo() return nil end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) if VERBOSE then print("   [chat] " .. tostring(m)) end end }

-- ------------------------------------------------------------- fake quest log
-- Each entry: { title=, objectives={...} }
QUESTLOG = {}
function GetNumQuestLogEntries() return #QUESTLOG end
function GetQuestLogTitle(i)
   local q = QUESTLOG[i]
   if not q then return nil end
   -- 3.3.5 returns questID as the 9th value (used by the POI system)
   return q.title, 80, nil, nil, false, false, false, false, 5000 + i
end
function GetNumQuestLeaderBoards(i)
   local q = QUESTLOG[i]
   return q and #q.objectives or 0
end
function GetQuestLogLeaderBoard(j, i)
   local q = QUESTLOG[i]
   return q and q.objectives[j], "monster", false
end

-- ------------------------------------------------------------------ namespace
CallboardHunter = {
   QuestWatcher = {}, SpawnDB = {}, Arrow = {}, Detector = {}, Announce = {},
   hotZones = {}, visited = {},
}
local CBH = CallboardHunter
CBH.db = { options = {}, learned = {}, learnedKills = {}, cardZones = {},
           callboards = {}, portOverrides = {}, checkpointBlock = {}, log = {} }
function CBH.print(m) if VERBOSE then print("   [cbh] " .. tostring(m)) end end
function CBH.safeCall(fn, ...) if fn then fn(...) end end
function CBH.IsBlockedCheckpoint() return false end
function CBH.GetQuestPOI() return nil end
function CBH.PlayerZonePos() return nil end
function CBH.Arrow.Refresh() end
function CBH.Arrow.GetTargetXY() return nil end

local function load(f)
   local chunk, err = loadfile(ADDON .. "/" .. f)
   if not chunk then error("load " .. f .. ": " .. tostring(err)) end
   chunk()
end
load("SpawnDB.lua")
load("QuestWatcher.lua")
load("Advisor.lua")

local QW, Advisor = CBH.QuestWatcher, CBH.Advisor

-- --------------------------------------------------------------- assertions
local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label,
      tostring(got), ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end

print("== rare quest completion ==")
QUESTLOG = {
   { title = "Rare Hunt in Icecrown",  objectives = { "Rare creatures slain: 3/3" } },
   { title = "Rare Hunt in Nagrand",   objectives = { "Rare creatures slain: 1/3" } },
}
QW.Update(true)
check("finished Icecrown flagged done", CBH.hotZones["Icecrown"].done, true)
check("unfinished Nagrand not done",    CBH.hotZones["Nagrand"].done, false)
check("IsZoneHot(Icecrown) [finished]", QW.IsZoneHot("Icecrown"), false)
check("IsZoneHot(Nagrand) [active]",    QW.IsZoneHot("Nagrand"), true)

print("\n== two rare quests in one zone: the UNFINISHED one wins ==")
QUESTLOG = {
   { title = "Rare Hunt in Zul'Drak", objectives = { "Rare creatures slain: 5/5" } },
   { title = "More Rares in Zul'Drak", objectives = { "Rare creatures slain: 0/5" } },
}
QW.Update(true)
check("Zul'Drak stays active", QW.IsZoneHot("Zul'Drak"), true)
-- ...and in the other listing order (completed quest parsed last)
QUESTLOG = {
   { title = "More Rares in Zul'Drak", objectives = { "Rare creatures slain: 0/5" } },
   { title = "Rare Hunt in Zul'Drak", objectives = { "Rare creatures slain: 5/5" } },
}
QW.Update(true)
check("Zul'Drak active (reverse order)", QW.IsZoneHot("Zul'Drak"), true)

print("\n== THE BUG: a finished rare quest must not hijack the Port button ==")
-- Finished rare quest at questIndex 1 (sorts first), unfinished kill objective
-- at questIndex 2. Standing somewhere unrelated.
CURRENT_ZONE = "Western Plaguelands"
QUESTLOG = {
   { title = "Rare Hunt in Icecrown", objectives = { "Rare creatures slain: 3/3" } },
   { title = "Thinning the Herd in Winterspring", objectives = { "Flame Revenant slain: 0/10" } },
}
QW.Update(true)
local dest, _, _, _, via = Advisor.ResolveDestination()
check("routes to the unfinished objective", dest, "Dragonblight")
check("  ...forcing its checkpoint", via, "Fordragon Hold")

-- Prove this is what regressed: clear the done flag (old behaviour) and the
-- finished Icecrown quest wins the sort again.
CBH.hotZones["Icecrown"].done = false
local oldDest = Advisor.ResolveDestination()
check("pre-fix behaviour reproduced", oldDest, "Icecrown")

print("\n== kill-objective parsing still works ==")
QUESTLOG = {
   { title = "Steel Yourself: Banthar", objectives = { "Banthar slain: 2/6" } },
}
QW.Update(true)
check("kill objective parsed", CBH.killObjectives["Banthar"].have, 2)
check("  need parsed", CBH.killObjectives["Banthar"].need, 6)
check("no phantom hot zone", next(CBH.hotZones) == nil, true)

print("")
if fails > 0 then
   print(fails .. " FAILURE(S) of " .. n)
   os.exit(1)
else
   print("ALL " .. n .. " PASS")
end

-- Executes the REAL Dungeon.lua against stubbed board frames, popups and money.
local ADDON = ADDON_DIR
-- WoW 3.3.5 is Lua 5.1 (global unpack); fengari is 5.3 (table.unpack).
unpack = unpack or table.unpack

-- ---- fake widget tree -------------------------------------------------------
local function mk(kind, name)
   local f = { _kind = kind, _children = {}, _regions = {}, _shown = true, _clicks = 0 }
   function f:GetObjectType() return self._kind end
   function f:IsShown() return self._shown end
   function f:GetChildren() return unpack(self._children) end
   function f:GetRegions() return unpack(self._regions) end
   function f:GetText() return self._text end
   function f:Click() self._clicks = self._clicks + 1 end
   if name then _G[name] = f end
   return f
end
local function fs(text) local r = mk("FontString"); r._text = text; return r end
function CreateFrame() return mk("Frame") end
function GetTime() return NOW or 0 end
MONEY = 5000000
function GetMoney() return MONEY end
function IsInInstance() return INSIDE, INSTANCE_KIND or "party" end
function GetRealZoneText() return ZONE or "Utgarde Keep" end
function GetNumPartyMembers() return PARTY or 0 end
function GetNumRaidMembers() return 0 end
PUSHED, SELECTED = 0, nil
function SelectQuestLogEntry(i) SELECTED = i end
function QuestLogPushQuest() PUSHED = PUSHED + 1 end
function GetMapContinents() return "Northrend" end
function GetMapZones() return "Howling Fjord", "Icecrown" end

CallboardHunter = { SpawnDB = {} }
local CBH = CallboardHunter
PRINTED = {}
function CBH.print(m) PRINTED[#PRINTED + 1] = tostring(m) end
function CBH.Log() end
function CBH.safeCall(fn, ...) if fn then fn(...) end end
CBH.db = { options = { dungeonAuto = true, dungeonRerollMax = 10,
                       dungeonGoldReserve = 0, dungeonShare = true,
                       dungeonHintsShown = 0 } }
local function load(f) local c, e = loadfile(ADDON .. "/" .. f); if not c then error(e) end; c() end
load("SpawnDB.lua"); load("Dungeon.lua")
local D = CBH.Dungeon

-- ---- board builder ----------------------------------------------------------
local board, rerollBtn
local function BuildBoard(cardTexts, rerollLabel)
   board = mk("Frame", "ObjectivesMainFrame")
   for i = 1, 3 do
      local card = mk("Frame", "ObjectiveFrame" .. i)
      card._regions = { fs(cardTexts[i] or "") }
      local sel = mk("Button"); sel._text = "Select"
      card._children = { sel }
      card.sel = sel
      board._children[#board._children + 1] = card
   end
   rerollBtn = mk("Button")
   rerollBtn._text = rerollLabel or "Reroll Selection 10g 40s"
   board._children[#board._children + 1] = rerollBtn
end
local function Popup(text)
   for i = 1, 4 do
      _G["StaticPopup" .. i] = nil
      _G["StaticPopup" .. i .. "Text"] = nil
      _G["StaticPopup" .. i .. "Button1"] = nil
   end
   if not text then return end
   mk("Frame", "StaticPopup1")
   _G["StaticPopup1Text"] = fs(text)
   mk("Button", "StaticPopup1Button1")
end

local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label, tostring(got),
      ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end

INSIDE, ZONE = true, "Utgarde Keep"

print("== only runs inside a dungeon ==")
INSIDE = false
BuildBoard({ "Kill 10 Azure Manashaper in Crystalsong Forest." })
D.run = nil; NOW = 1; D.Poll(NOW)
check("outdoors -> no run started", D.run, nil)
INSIDE = true

print("")
print("== matching ==")
BuildBoard({ "Slay Ingvar the Plunderer in Utgarde Keep.", "Collect 40 Icethorn.", "Kill 10 Murloc." })
check("card naming the dungeon", (D.MatchCard(D.ReadCards(), "Utgarde Keep")), 1)
BuildBoard({ "Collect 40 Icethorn.", "Slay Ingvar the Plunderer.", "Kill 10 Murloc." })
check("card naming a boss of it", (D.MatchCard(D.ReadCards(), "Utgarde Keep")), 2)
BuildBoard({ "Slay King Ymiron." })
check("boss of a different dungeon is not a match", D.MatchCard(D.ReadCards(), "Utgarde Keep"), nil)

print("")
print("== accepts a matching card without rerolling ==")
BuildBoard({ "Slay Ingvar the Plunderer in Utgarde Keep." })
D.run = nil; NOW = 10; D.Poll(NOW)
check("clicked Select", board._children[1].sel._clicks, 1)
check("no rerolls needed", rerollBtn._clicks, 0)

print("")
print("== SAFETY: refuses to confirm a popup that is not the reroll dialog ==")
BuildBoard({ "Collect 40 Icethorn." })
D.run = nil; NOW = 20; D.Poll(NOW)
check("reroll clicked", rerollBtn._clicks, 1)
Popup("Are you sure you want to DELETE this item?")
NOW = 21; D.Poll(NOW)
check("did NOT click the wrong dialog", _G["StaticPopup1Button1"]._clicks, 0)
check("  ...and stopped the run", D.run, nil)

print("")
print("== confirms the real reroll dialog and counts the spend ==")
BuildBoard({ "Collect 40 Icethorn." })
MONEY = 5000000
D.run = nil; NOW = 30; D.Poll(NOW)
Popup("Reroll selection for 10g 40s?")
MONEY = 5000000 - 104000
NOW = 31; D.Poll(NOW)
check("clicked Confirm", _G["StaticPopup1Button1"]._clicks, 1)
check("counted one reroll", D.run.rerolls, 1)
check("learned the real cost", D.lastCost, 104000)
check("tracked the spend", D.run.spent, 104000)

print("")
print("== reroll cap stops the loop ==")
CBH.db.options.dungeonRerollMax = 2
BuildBoard({ "Collect 40 Icethorn." })
D.run = nil; NOW = 40; D.Poll(NOW)
D.run.rerolls = 2
D.run.phase = "match"; D.run.at = 0
NOW = 41; D.Poll(NOW)
check("stopped at the cap", D.run, nil)
CBH.db.options.dungeonRerollMax = 10

print("")
print("== gold reserve stops the loop before spending below it ==")
CBH.db.options.dungeonGoldReserve = 1000000
MONEY = 1050000
BuildBoard({ "Collect 40 Icethorn." })
D.run = nil; NOW = 50; D.Poll(NOW)
check("refused to reroll", rerollBtn._clicks, 0)
check("  ...and stopped", D.run, nil)
CBH.db.options.dungeonGoldReserve = 0
MONEY = 5000000

print("")
print("== board despawning stops the run ==")
BuildBoard({ "Collect 40 Icethorn." })
D.run = nil; NOW = 60; D.Poll(NOW)
check("run active", D.run ~= nil, true)
board._shown = false
NOW = 61; D.Poll(NOW)
check("stopped when board vanished", D.run, nil)

print("")
print("== missing Reroll button stops rather than guessing ==")
BuildBoard({ "Collect 40 Icethorn." }, "Something Else")
D.run = nil; NOW = 70; D.Poll(NOW)
check("stopped, clicked nothing", D.run, nil)

print("")
print("== sharing: once, and only in a group ==")
PARTY, PUSHED = 0, 0
D.run = { instance = "Utgarde Keep", rerolls = 0, spent = 0, shared = false }
D.OnQuestAccepted(7)
check("solo -> not shared", PUSHED, 0)
PARTY, PUSHED = 4, 0
D.run = { instance = "Utgarde Keep", rerolls = 0, spent = 0, shared = false }
D.OnQuestAccepted(7)
check("in a group -> shared", PUSHED, 1)
check("  ...selected the right quest", SELECTED, 7)
D.OnQuestAccepted(7)
check("second call does not re-share", PUSHED, 1)
CBH.db.options.dungeonShare = false
PARTY, PUSHED = 4, 0
D.run = { instance = "Utgarde Keep", rerolls = 0, spent = 0, shared = false }
D.OnQuestAccepted(7)
check("sharing off is respected", PUSHED, 0)
CBH.db.options.dungeonShare = true

print("")
print("== disabled by default means nothing happens ==")
CBH.db.options.dungeonAuto = false
BuildBoard({ "Collect 40 Icethorn." })
D.run = nil; NOW = 80; D.Poll(NOW)
check("opt-out honoured", D.run, nil)
check("  ...no clicks", rerollBtn._clicks, 0)

print("")
print("== instance-entry reminder (was specced but missing in 1.8.0) ==")
CBH.db.options.dungeonAuto = true
PRINTED = {}; D.announced = nil
INSIDE, ZONE = true, "Halls of Lightning"
D.OnZoneChanged()
check("announces on entering", #PRINTED, 1)
check("  ...names the dungeon", string.find(PRINTED[1], "Halls of Lightning") ~= nil, true)
PRINTED = {}
D.OnZoneChanged()
check("does not repeat for the same instance", #PRINTED, 0)
ZONE = "Halls of Stone"
D.OnZoneChanged()
check("announces again in a different dungeon", #PRINTED, 1)
PRINTED = {}; INSIDE = false
D.OnZoneChanged()
check("silent outdoors", #PRINTED, 0)

print("")
print("== when OFF it says how to turn it on, then stops nagging ==")
CBH.db.options.dungeonAuto = false
CBH.db.options.dungeonHintsShown = 0
local seen = 0
for i = 1, 5 do
   INSIDE = true; ZONE = "Dungeon " .. i; PRINTED = {}
   D.OnZoneChanged()
   if #PRINTED > 0 then
      seen = seen + 1
      if seen == 1 then
         check("first hint explains the command",
            string.find(PRINTED[1], "/cbh dungeon on") ~= nil, true)
      end
   end
end
check("hints are capped, not endless", seen, 3)
CBH.db.options.dungeonAuto = true

print("")
print("== raids automate too (boss-only card, raid instance) ==")
INSIDE, INSTANCE_KIND, ZONE = true, "raid", "Icecrown Citadel"
CBH.db.options.dungeonAuto = true
BuildBoard({ "Collect 40 Icethorn.", "Wanted: Festergut", "Kill 10 Murloc." })
D.run = nil; NOW = 200; D.Poll(NOW)
check("matched the raid boss card", board._children[2].sel._clicks, 1)
check("  ...without rerolling", rerollBtn._clicks, 0)
-- a boss from a DIFFERENT raid must not match
BuildBoard({ "Wanted: Yogg-Saron" })
check("other raid's boss is not a match", D.MatchCard(D.ReadCards(), "Icecrown Citadel"), nil)
-- raid instances are recognised for the entry announcement too
PRINTED = {}; D.announced = nil
D.OnZoneChanged()
check("announces in a raid", #PRINTED, 1)
INSTANCE_KIND = "party"

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

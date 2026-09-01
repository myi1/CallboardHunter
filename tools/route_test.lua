-- Stubbed-WoW harness for CallboardHunter/Route.lua.
-- Walks the route state machine and exercises the auto accept / turn-in engine
-- through the real event wiring (RT.Init registers the handlers; we find the
-- frame that asked for QUEST_DETAIL and fire events at it).

-- Run from this folder:  node run_lua.js route_test.lua
local ROUTE = os.getenv("CBH_ROUTE") or "../Route.lua"

-- ----------------------------------------------------------------- world state
local W = {
  zone = "Elwynn Forest",
  level = 1,
  runAsh = 0,
  quests = {},        -- title -> true (currently in the log)
  dialogTitle = nil,  -- what the open quest window is showing
  dialogNpc = nil,    -- UnitName("npc") while a quest window is open
  targetName = nil,   -- UnitName("target")
  choices = 0,        -- reward choices on the complete screen
  completable = true,
  gossipAvail = {},   -- flat vararg, as the client returns it
  gossipActive = {},
  now = 1000,
}
-- Calls the addon made on our behalf.
local did = { accept = {}, complete = {}, reward = {}, gossipA = {}, gossipQ = {} }

-- ------------------------------------------------------------------ WoW stubs
local out = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) out[#out + 1] = m end }

function GetTime() W.now = W.now + 1; return W.now end
time = os.time
date = os.date

function GetRealZoneText() return W.zone end
function UnitLevel() return W.level end
function UnitName(u)
  if u == "npc" then return W.dialogNpc end
  if u == "target" then return W.targetName end
  return "Some NPC"
end
function GetTitleText() return W.dialogTitle end
function SetMapToCurrentZone() end
function GetPlayerMapPosition() return 0.5, 0.5 end
function InCombatLockdown() return false end
function GetSpellName() return nil end
BOOKTYPE_SPELL = "spell"
ERR_QUEST_COMPLETE_S = "%s completed."
function SetRaidTarget() end
function GetRaidTargetIndex() return nil end
function UnitExists(u) return W.targetName ~= nil end

function AcceptQuest() did.accept[#did.accept + 1] = W.dialogTitle end
function CompleteQuest() did.complete[#did.complete + 1] = W.dialogTitle end
function GetQuestReward(i) did.reward[#did.reward + 1] = W.dialogTitle .. "#" .. tostring(i) end
function GetNumQuestChoices() return W.choices end
function IsQuestCompletable() return W.completable end

local function varargs(t) return (unpack or table.unpack)(t) end
function GetGossipAvailableQuests() return varargs(W.gossipAvail) end
function GetGossipActiveQuests() return varargs(W.gossipActive) end
function SelectGossipAvailableQuest(i) did.gossipA[#did.gossipA + 1] = i end
function SelectGossipActiveQuest(i) did.gossipQ[#did.gossipQ + 1] = i end
function GetNumActiveQuests() return 0 end
function GetNumAvailableQuests() return 0 end

-- Quest log: one header plus every quest currently held.
local function QuestList()
  local list = { { title = "Northrend", header = true } }
  for t in pairs(W.quests) do list[#list + 1] = { title = t } end
  return list
end
function GetNumQuestLogEntries() return #QuestList(), #QuestList() - 1 end
function GetQuestLogTitle(i)
  local e = QuestList()[i]
  if not e then return nil end
  return e.title, 70, nil, nil, e.header or false, false, false, false
end
function ExpandQuestHeader() end
function CollapseQuestHeader() end

-- Frames: unknown methods are no-ops; the few with real behaviour are set.
local frames = {}
local function MockFrame(name)
  -- _attrs must exist up front: the __index below fabricates a FUNCTION for any
  -- missing key, so a lazy `self._attrs or {}` would get a function, not a table.
  local f = { _name = name, _shown = false, _scripts = {}, _events = {}, _attrs = {} }
  function f:Show() self._shown = true
    if self._scripts.OnShow then self._scripts.OnShow(self) end end
  function f:Hide() self._shown = false end
  function f:IsShown() return self._shown end
  function f:SetScript(k, fn) self._scripts[k] = fn end
  function f:HookScript(k, fn) self._scripts[k] = fn end
  function f:GetScript(k) return self._scripts[k] end
  function f:SetText(t) self._text = t end
  function f:GetText() return self._text end
  function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
  function f:GetChildren() return end
  function f:CreateFontString() return MockFrame(name .. ".fs") end
  function f:RegisterEvent(e) self._events[e] = true end
  function f:SetAttribute(k, v)
    self._attrs = self._attrs or {}; self._attrs[k] = v
  end
  setmetatable(f, { __index = function(t, k)
    local noop = function() return nil end
    rawset(t, k, noop)
    return noop
  end })
  frames[#frames + 1] = f
  return f
end
UIParent = MockFrame("UIParent")
WorldMapFrame = MockFrame("WorldMapFrame")
WorldMapButton = MockFrame("WorldMapButton")
function CreateFrame(_, name, _, _) return MockFrame(name or "anon") end

EbonholdPlayerRunData = setmetatable({}, { __index = function(_, k)
  if k == "soulPoints" then return W.runAsh end
end })

-- The server paints the tier with a colour code; the digit is what matters.
-- Declared up here (not just before the read-tier tests further down) because
-- Route.Advance now drives a real click through this frame for the mode
-- steps in the main lap walk below -- the lap can no longer complete a mode
-- step by acking blind, so the walk needs a run frame that already reports
-- the target tier, same as a player who is already sitting at it in-game.
local function FakeRunFrame(label)
  local fs = { GetText = function() return label end,
               GetObjectType = function() return "FontString" end }
  local btn = { GetObjectType = function() return "Button" end,
                GetRegions = function() return fs end,
                GetChildren = function() return end,
                IsShown = function() return true end }
  return { GetObjectType = function() return "Frame" end,
           GetRegions = function() return end,
           GetChildren = function() return btn end,
           IsShown = function() return true end }
end

-- --------------------------------------------------------- load the module
-- Route.lua expects the CallboardHunter namespace and its shared helpers, so
-- stand up just enough of Core.lua rather than dofile'ing the whole addon.
CallboardHunter = {
  Route = {},
  Arrow = {},
  Advisor = {},
  db = { options = {}, route = {} },
}
local CBH = CallboardHunter
function CBH.print(m) out[#out + 1] = "CBH: " .. tostring(m) end
-- Surface errors instead of swallowing them: the real safeCall prints and moves
-- on, which is right in-game and useless in a test.
function CBH.safeCall(fn, ...)
  if not fn then return end
  local ok, err = pcall(fn, ...)
  if not ok then error("safeCall: " .. tostring(err), 0) end
end

dofile(ROUTE)
local RT = CallboardHunter.Route

-- ----------------------------------------------------------------- assertions
local fails, checks = 0, 0
local function stepKey(i) return i and RT.Steps()[i].key or "<complete>" end
local function expect(want, label)
  checks = checks + 1
  local got = stepKey(RT.Current())
  if got ~= want then
    fails = fails + 1
    print(string.format("  FAIL %-38s expected %-8s got %s", label, want, got))
  else
    print(string.format("  ok   %-38s -> %s", label, got))
  end
end
local function check(cond, label, detail)
  checks = checks + 1
  if cond then print("  ok   " .. label)
  else fails = fails + 1; print("  FAIL " .. label .. "   " .. tostring(detail)) end
end

print("PrestigeRoute route walk")
RT.Init() -- builds both panels AND registers the auto accept / turn-in events

-- A fresh level 1 -- any ash level, no prestige preamble. Step 1 is the
-- hardcore swap, not an ash gate.
RT.Reset(true, true)
expect("hcStart", "fresh level 1 -> step 1 is the hardcore swap")
checks = checks + 1
if #RT.Steps() == 13 then print("  ok   route is 13 steps, level 1 to 80")
else fails = fails + 1; print("  FAIL step count -> " .. #RT.Steps()) end

-- The run frame already reports the target tier -- the ordinary case of a
-- player who switched (or was already sitting at) Hardcore 5 before clicking.
_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 5|r")
RT.Advance(); expect("dala1", "one click confirms the tier and advances")

W.zone = "Dalaran"
expect("q1", "arrived in Dalaran -> quest 1")

local function turnIn(t) CallboardHunter.db.route.turnedIn[RT.NormTitle(t)] = true end

turnIn("Preparations for War")
expect("q2", "quest 1 handed in -> quest 2")

turnIn("Learning to Leave and Return: The Magical Way")
expect("q3a", "quest 2 handed in -> pick up quest 3")

-- THE APOSTROPHE CASE: the server spells the title with a CURLY apostrophe
-- while the route table spells it straight.
W.quests["The Champion\226\128\153s Call!"] = true
expect("zd", "curly-apostrophe quest detected in log")

W.zone = "Zul'Drak"; W.level = 64
expect("q3b", "arrived in Zul'Drak -> hand in quest 3")

W.quests["The Champion\226\128\153s Call!"] = nil
turnIn("The Champion\226\128\153s Call!")
expect("dala2", "quest 3 handed in -> port back to Dalaran")

-- THE REGRESSION: leaving Zul'Drak must not un-complete the Zul'Drak port.
W.zone = "Dalaran"
expect("hcEnd", "back in Dalaran -> drop a tier (not zd)")

-- hcEnd's default target is Hardcore 3 -- the run frame now reports that.
_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 3|r")
RT.Advance(); expect("bt", "tier drop confirmed -> port to Borean Tundra")
W.zone = "Borean Tundra"
expect("grindBt", "arrived in Borean Tundra -> grind to 72")

-- 64 -> 80. Bands come from keepsy's own run logs: 66-72 Borean, 73-80 Icecrown.
W.level = 71
expect("grindBt", "still under 72 -> keep grinding")
W.level = 72
expect("ice", "hit 72 -> port to Icecrown")

W.zone = "Icecrown"
expect("grindIce", "arrived in Icecrown -> grind to 80")
W.level = 79
expect("grindIce", "79 is not 80")
W.level = 80
expect("<complete>", "ding 80 -> route complete")

-- The bands are retunable per character.
W.level = 70; W.zone = "Borean Tundra"
CallboardHunter.db.route.acked.ice = nil
CallboardHunter.db.route.acked.grindBt = nil
CallboardHunter.db.route.acked.grindIce = nil
expect("grindBt", "back on the Borean band at 70")
RT.Command("grind 68")
expect("ice", "grind 68 moves the hand-off earlier")
RT.Command("grind 72")

W.level = 80; W.zone = "Icecrown"
expect("<complete>", "route complete again at 80")

-- Back cannot undo a levelling step -- you cannot un-ding. It has to SAY that
-- rather than look like a dead button; /cbh route reset is the way back.
out = {}
RT.Back()
checks = checks + 1
if string.find(table.concat(out, "|"), "still reads as done", 1, true) then
  print("  ok   Back on a levelling step explains itself")
else
  fails = fails + 1
  print("  FAIL Back message -> " .. table.concat(out, "|"))
end

W.level, W.zone = 1, "Durotar"

-- A hand-run reset replays the leg from the top.
RT.Reset(true)
expect("hcStart", "manual reset -> back to step 1")

-- Hardcore tiers are configurable: you cannot switch to a tier you have not
-- unlocked, and the route's own "HC5" is the author's ladder, not yours.
RT.Command("hc 2")
checks = checks + 1
if RT.Steps()[1].text == "Switch to Hardcore 2" then
  print("  ok   /cbh route hc 2 retargets the tier")
else fails = fails + 1; print("  FAIL tier -> " .. tostring(RT.Steps()[1].text)) end

RT.Command("hc off")
expect("dala1", "hc off drops the mode steps entirely")
checks = checks + 1
if #RT.Steps() == 11 then print("  ok   route is 11 steps with hardcore off")
else fails = fails + 1; print("  FAIL step count -> " .. #RT.Steps()) end
RT.Command("hc 5")


-- ------------------------------------------------------ one button, one label
print("")
print("compact panel")
RT.SetMode(true)
RT.Reset(true, true)
W.zone = "Elwynn Forest"
RT.Refresh()
local mini = RT.miniPanel
check(string.find(mini.go._text or "", "Hardcore", 1, true) ~= nil,
  "button labels the hardcore step", mini.go._text)
check(rawget(mini, "exec") == nil, "the separate exec button is gone")
check((mini.guide._text or "") ~= "", "a guide line is present", mini.guide._text)
-- rawget: the mock fabricates a no-op for any missing key, so a plain nil
-- check would always pass and prove nothing.
check(rawget(mini, "ports") == nil and rawget(mini, "back") == nil
  and rawget(mini, "done") == nil and rawget(mini, "skip") == nil
  and rawget(mini, "full") == nil,
  "no port bar / back / done / skip / full buttons remain")

-- hcStart is back to targeting 5 (RT.Command("hc 5") above); match the frame.
_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 5|r")
RT.Advance(); W.zone = "Dalaran"; RT.Refresh()
check(string.find(mini.go._text or "", "Port to", 1, true) == nil,
  "already in Dalaran, so the port step is behind us", mini.go._text)

-- ------------------------------------------------------- targeting the NPC
print("")
print("target + marker")
-- Teach it who hands quest 1 in, the way a real lap would.
CallboardHunter.db.route.learned[RT.NormTitle("Preparations for War")] = {
  turn = { zone = "Dalaran", x = 0.68, y = 0.49, npc = "High Captain Justin Bartlett" },
}
RT.Refresh()
check(string.find(mini.go._text or "", "Target High Captain", 1, true) ~= nil,
  "button offers to target the learned NPC", mini.go._text)
local mt = mini.go._attrs and mini.go._attrs.macrotext or ""
check(string.find(mt, "/targetexact High Captain Justin Bartlett", 1, true) ~= nil,
  "and its macro targets them by exact name", mt)
check(string.find(mt, "OnTargeted", 1, true) ~= nil,
  "then hands back to Lua to place the marker", mt)
check((mini.go._attrs or {}).type == "macro", "the button is a secure macro button")

-- Solo, raid icons are a no-op; say so rather than claim a marker appeared.
W.targetName = "High Captain Justin Bartlett"
out = {}
RT.OnTargeted()
check(string.find(table.concat(out, "|"), "need a party", 1, true) ~= nil,
  "no-op marker is reported honestly", table.concat(out, "|"))

W.targetName = nil
out = {}
RT.OnTargeted()
check(string.find(table.concat(out, "|"), "Couldn't find", 1, true) ~= nil,
  "and an out-of-range NPC says so")

-- ----------------------------------------------------- auto accept / turn-in
print("")
print("auto accept / turn-in")

-- Find the frame the addon registered its quest events on.
local ev
for _, f in ipairs(frames) do
  if f._events["QUEST_DETAIL"] then ev = f break end
end
check(ev ~= nil, "found the registered quest event frame")
local function fire(e) ev._scripts.OnEvent(ev, e) end

W.dialogTitle = "Preparations for War"
fire("QUEST_DETAIL")
check(did.accept[#did.accept] == "Preparations for War",
  "a route quest auto-accepts", did.accept[#did.accept])

W.dialogTitle = "Kill 10 Boars"
fire("QUEST_DETAIL")
check(did.accept[#did.accept] == "Preparations for War",
  "a NON-route quest is left alone", did.accept[#did.accept])

W.dialogTitle = "The Champion's Call!"
fire("QUEST_PROGRESS")
check(did.complete[#did.complete] == "The Champion's Call!",
  "a route quest auto-completes at the progress screen")

W.completable = false
W.dialogTitle = "Preparations for War"
local before = #did.complete
fire("QUEST_PROGRESS")
check(#did.complete == before, "an incomplete quest is not forced")
W.completable = true

-- Reward screen: no choice -> take it; a real choice -> leave it to the player.
W.choices = 0
W.dialogTitle = "Preparations for War"
fire("QUEST_COMPLETE")
check(did.reward[#did.reward] == "Preparations for War#1",
  "a no-choice reward is taken automatically", did.reward[#did.reward])

W.choices = 3
local rewardsBefore = #did.reward
fire("QUEST_COMPLETE")
check(#did.reward == rewardsBefore,
  "a multi-choice reward is NOT auto-taken")
check(string.find(table.concat(out, "|"), "Pick a reward yourself", 1, true) ~= nil,
  "and it says so")
W.choices = 0

-- Gossip: the title is found by counting strings, so the vararg stride does
-- not matter. Route quest is second here.
W.gossipAvail = { "Some Other Quest", 70, false, false, false,
                  "Learning to Leave and Return: The Magical Way", 71, false, false, false }
fire("GOSSIP_SHOW")
check(did.gossipA[#did.gossipA] == 2,
  "gossip picks the route quest by index", did.gossipA[#did.gossipA])

-- Turn-ins outrank pick-ups when an NPC offers both.
W.gossipActive = { "Preparations for War", 70, false, true }
local aBefore = #did.gossipA
fire("GOSSIP_SHOW")
check(did.gossipQ[#did.gossipQ] == 1 and #did.gossipA == aBefore,
  "an active turn-in wins over an available pick-up")
W.gossipAvail, W.gossipActive = {}, {}

-- The off switch.
RT.Command("auto")
check(RT.AutoOn() == false, "/cbh route auto turns it off")
W.dialogTitle = "Preparations for War"
local acceptsBefore = #did.accept
fire("QUEST_DETAIL")
check(#did.accept == acceptsBefore, "and nothing auto-accepts while off")
RT.Command("auto")
check(RT.AutoOn() == true, "toggling again turns it back on")

-- ------------------------------------------- hand-in detection (the live bug)
print("")
print("hand-in detection")
RT.Reset(true, true)
CallboardHunter.db.route.acked.hcStart = true
W.zone = "Dalaran"
expect("q1", "sitting on quest 1")

-- Signal 1: the server's own confirmation line. Note the lowercase "the" --
-- the client spells the title differently from the route table.
fire2 = nil
ev._scripts.OnEvent(ev, "CHAT_MSG_SYSTEM", "Preparations for War completed.")
expect("q2", "chat 'completed.' line advances the step")

-- ...even with the server's own capitalisation of the next one.
ev._scripts.OnEvent(ev, "CHAT_MSG_SYSTEM",
  "Learning to Leave and Return: the Magical Way completed.")
expect("q3a", "lowercase 'the' in the server title still matches")

-- An unrelated quest completing must not move the route.
ev._scripts.OnEvent(ev, "CHAT_MSG_SYSTEM", "Kill 10 Boars completed.")
expect("q3a", "an unrelated quest completing is ignored")

-- Signal 2: a quest that was in the log AND complete, then vanishes.
W.quests["The Champion's Call!"] = true
ev._scripts.OnEvent(ev, "QUEST_LOG_UPDATE")
expect("zd", "quest 3 in the log advances past the pick-up step")

-- ------------------------------------------------------ hardcore tier (read)
print("")
print("hardcore tier (read)")

_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 5|r")
check(RT.HcCurrent() == 5, "reads the live tier through its colour code", RT.HcCurrent())

_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("Hardcore 2")
check(RT.HcCurrent() == 2, "reads an uncoloured tier too", RT.HcCurrent())

_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("Softcore")
check(RT.HcCurrent() == nil, "no tier in the text -> nil", RT.HcCurrent())

_G.ProjectEbonholdPlayerRunFrame = nil
check(RT.HcCurrent() == nil, "no run frame at all -> nil", RT.HcCurrent())

-- ---------------------------------------------------------- hardcore tier (switch)
print("")
print("hardcore tier (switch)")

-- Detection: a mode step is done when the tier actually matches.
_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 3|r")
CallboardHunter.db.route.acked = {}
CallboardHunter.db.route.hcEnd = 3
check(RT.HcTier("end") == 3, "the config we just set is what HcTier reads back", RT.HcTier("end"))
check(RT.HcCurrent() == 3, "mode step is done when the tier already matches", RT.HcCurrent())

-- Switching: clicking is attempted, and success is judged by re-reading.
local clicks = 0
local btn = RT.HcButton()
btn.Click = function() clicks = clicks + 1 end
local ok, why = RT.HcSwitch(3)
check(clicks == 0, "already on target -> no click needed", clicks)
check(ok == true, "  ...and it reports success", ok)

_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 5|r")
local b2 = RT.HcButton()
clicks = 0
b2.Click = function() clicks = clicks + 1 end
ok, why = RT.HcSwitch(3)
check(clicks == 1, "a real change clicks the server's control", clicks)
check(ok == false, "  ...but refuses to claim success when the tier did not move", ok)
check(string.find(tostring(why), "still on") ~= nil, "  ...and says why", why)

_G.ProjectEbonholdPlayerRunFrame = nil
ok, why = RT.HcSwitch(3)
check(ok == false, "no control -> not a success", ok)
check(string.find(tostring(why), "Mark done") ~= nil,
  "  ...and points at manual acknowledgement", why)

-- ------------------------------------------------- compact panel (switch)
-- The compact panel is the DEFAULT view, so its one button (Route.Advance)
-- has to run the same switch-and-verify as the full panel's Act button, not
-- the old rubber-stamp. RT.Command("hc 5") earlier in this file left hcStart
-- targeting Hardcore 5. World state (frame, zone) is set BEFORE each Reset,
-- not after: Reset's own Refresh() calls Route.Current(), which LATCHES any
-- step that already reads done into d.acked -- setting the frame afterward
-- would be too late to stop a stale match from being latched permanently.
-- Zone is pulled off Dalaran too, so completing hcStart lands cleanly on
-- dala1 instead of also auto-completing the port step behind its back.
print("")
print("compact panel (switch)")

W.zone = "Elwynn Forest"
_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 9|r") -- mismatched: hcStart wants 5
RT.Reset(true, true)
local mb = RT.HcButton()
clicks = 0
mb.Click = function() clicks = clicks + 1 end -- a no-op click: the server ignored it
expect("hcStart", "fresh lap, mismatched tier -> still step 1")
RT.Advance()
check(clicks == 1, "the compact button drives a real click, not just an ack", clicks)
expect("hcStart", "  ...and a click that didn't take does not advance the step")

_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 9|r") -- mismatched again
local mb2, fs2 = RT.HcButton(), nil
fs2 = mb2.GetRegions()
clicks = 0
mb2.Click = function()
  clicks = clicks + 1
  fs2.GetText = function() return "|cffFF4444Hardcore 5|r" end -- this time the server switched you
end
RT.Advance()
check(clicks == 1, "  ...but a click that DOES take is still just one click", clicks)
expect("dala1", "  ...and this time the compact panel advances")

-- The escape hatch: Mark done still forces a mode step through even when the
-- tier genuinely does not match -- a player who can see they are done, but
-- whose server UI didn't cooperate, must not get stuck on the compact panel.
W.zone = "Elwynn Forest"
_G.ProjectEbonholdPlayerRunFrame = FakeRunFrame("|cffFF4444Hardcore 9|r") -- still not 5
RT.Reset(true, true)
expect("hcStart", "fresh lap again, tier still mismatched")
CallboardHunter.db.route.acked.hcStart = true
expect("dala1", "Mark done forces the step through despite the mismatch")

-- Other surfaces should not throw.
RT.Why()
RT.Report(); RT.Api(); RT.Macros(); RT.ListCheckpoints(); RT.Refresh()
print(string.format("\n%d checks, %d failed", checks, fails))
if fails > 0 then os.exit(1) end

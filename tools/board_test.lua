-- Executes the REAL Board.lua against stubbed board frames, popups and money.
-- The engine is caller-agnostic, so every case here drives it through a match
-- callback of its own - nothing in this file knows what a dungeon is.
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
-- Deliberately no CBH.db: the engine takes its cap and reserve as numbers from
-- the caller, so it must run with no saved variables in existence at all.
local function load(f) local c, e = loadfile(ADDON .. "/" .. f); if not c then error(e) end; c() end
load("SpawnDB.lua"); load("Board.lua")

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

local B = CBH.Board
INSIDE = true

print("== the engine honours a supplied match callback ==")
BuildBoard({ "Alpha", "Beta", "Gamma" })
local seen = nil
B.run = nil; NOW = 1
B.Start({ label = "test", match = function(cards)
   seen = #cards
   for i, c in ipairs(cards) do
      if string.find(c.text, "Beta", 1, true) then return i, "found beta" end
   end
end })
B.Poll(NOW)
check("callback saw all three cards", seen, 3)
check("accepted the matching card", board._children[2].sel._clicks, 1)
check("no reroll needed", rerollBtn._clicks, 0)

print("")
print("== no match -> rerolls, then stops at the cap ==")
BuildBoard({ "Alpha", "Beta", "Gamma" })
B.run = nil; NOW = 10
B.Start({ label = "test", rerollMax = 1, match = function() return nil end })
B.Poll(NOW)
check("clicked reroll", rerollBtn._clicks, 1)
Popup("Reroll selection for 10g 40s?")
NOW = 11; B.Poll(NOW)
check("confirmed", _G["StaticPopup1Button1"]._clicks, 1)
BuildBoard({ "Delta", "Epsilon", "Zeta" })
NOW = 12; B.Poll(NOW)
NOW = 13; B.Poll(NOW)
check("stopped at the cap", B.run, nil)

print("")
print("== SAFETY: still refuses a non-reroll dialog ==")
BuildBoard({ "Alpha" })
B.run = nil; NOW = 20
B.Start({ label = "test", match = function() return nil end })
B.Poll(NOW)
Popup("Are you sure you want to DELETE this item?")
NOW = 21; B.Poll(NOW)
check("did not click it", _G["StaticPopup1Button1"]._clicks, 0)
check("stopped the run", B.run, nil)

print("")
print("== onAccept fires with the winning card ==")
BuildBoard({ "Alpha", "Beta" })
local gotWhy = nil
B.run = nil; NOW = 30
B.Start({ label = "test",
   match = function(cards) return 1, "first card" end,
   onAccept = function(card, why) gotWhy = why end })
B.Poll(NOW)
check("onAccept received the reason", gotWhy, "first card")
-- Same board as the first case, different callback, different card: the engine
-- takes whichever card the caller names, not one of its own choosing.
check("a swapped callback moves the pick to card 1", board._children[1].sel._clicks, 1)

print("")
print("== one run at a time, and never one without a question to ask ==")
-- Both ownership guards in Dungeon.lua lean on this: a second caller must not
-- be able to take over a board mid-run.
BuildBoard({ "Alpha" })
B.run = nil; NOW = 40
B.Start({ label = "first", match = function() return nil end })
check("a second Start is refused while a run is live",
   B.Start({ label = "second", match = function() return 1 end }), false)
B.run = nil
check("a Start with no match callback is refused", B.Start({ label = "third" }), false)

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

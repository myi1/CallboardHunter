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
-- The whole stub surface the engine touches: a clock and a purse. There is no
-- IsInInstance, no GetRealZoneText, no quest-sharing here on purpose - stubs the
-- engine never calls would quietly contradict the header above, and a file that
-- LOOKS like it knows about dungeons invites the next edit to make it so.
function GetTime() return NOW or 0 end
MONEY = 5000000
function GetMoney() return MONEY end

CallboardHunter = { SpawnDB = {} }
local CBH = CallboardHunter
PRINTED = {}
function CBH.print(m) PRINTED[#PRINTED + 1] = tostring(m) end
function CBH.Log() end
function CBH.safeCall(fn, ...) if fn then fn(...) end end
-- Deliberately no CBH.db: the engine takes its cap and reserve as numbers from
-- the caller, so it must run with no saved variables in existence at all.
local function load(f) local c, e = loadfile(ADDON .. "/" .. f); if not c then error(e) end; c() end
-- Board.lua only: SpawnDB is the dungeon/favourites vocabulary, and the engine
-- has no business needing it loaded to run.
load("Board.lua")

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
print("== a hidden slot leaves a HOLE, and the contract is walk 1..SLOTS ==")
-- ReadCards writes out[i] only for a SHOWN card, so slot 2 can exist while slot
-- 1 does not. Every caller used to walk the result with ipairs, which stops dead
-- at the hole - and "no match" is the branch that spends 10g on a reroll.
BuildBoard({ "Alpha", "Beta", "Gamma" })
_G["ObjectiveFrame1"]._shown = false
local sparse = B.ReadCards()
check("the engine publishes how many slots to walk", B.SLOTS, 3)
check("the hidden slot has no entry", sparse[1], nil)
check("  ...but the slots behind it still do", sparse[2] ~= nil and sparse[3] ~= nil, true)
local viaIpairs = 0
for _ in ipairs(sparse) do viaIpairs = viaIpairs + 1 end
local viaSlots = 0
for i = 1, B.SLOTS do if sparse[i] then viaSlots = viaSlots + 1 end end
check("ipairs finds none of the two live cards", viaIpairs, 0)
check("the slot walk finds both", viaSlots, 2)
B.run = nil; NOW = 300
B.Start({ label = "test", match = function(cs)
   for i = 1, B.SLOTS do
      local c = cs[i]
      if c and string.find(c.text, "Beta", 1, true) then return i, "beta on slot 2" end
   end
end })
B.Poll(NOW)
check("accepted slot 2 with slot 1 hidden", board._children[2].sel._clicks, 1)
check("  ...paying for no reroll", rerollBtn._clicks, 0)
B.run = nil

print("")
print("== the engine never reads CBH's own card note back as card text ==")
-- 1.9.7 shipped this class of bug once already: CBH catalogued its own
-- annotations and read them back as evidence. Here it is worse than a dirty
-- catalogue - the note NAMES A ZONE, so a matcher keying on card text can match
-- CBH's own words. The note also joined the settle rail's signature, so
-- redrawing it looked like the board had changed.
BuildBoard({ "Slay Loken in Halls of Lightning." })
local noted = _G["ObjectiveFrame1"]
local note = fs("|cff322516Dungeon/raid: Naxxramas|r")
noted._regions[#noted._regions + 1] = note
noted.cbhNote = note
local read = B.ReadCards()
check("the server's own card text survives",
   string.find(read[1].text, "Slay Loken", 1, true) ~= nil, true)
check("our annotation does not", string.find(read[1].text, "Naxxramas", 1, true), nil)

print("")
print("== a won run ends itself when no caller claims it ==")
-- Board.Accept clicks Select and sets phase; nothing here cleared Board.run.
-- The dungeon caller survives only because QUEST_ACCEPTED nils it. A caller
-- without that hook kept polling a won run: Select clicked again every tick,
-- then a paid reroll once the taken card left the board.
BuildBoard({ "Alpha" })
B.run = nil; NOW = 400
B.Start({ label = "test", match = function() return 1, "always" end })   -- no onAccept
B.Poll(NOW)
check("accepted once", board._children[1].sel._clicks, 1)
NOW = 400.5; B.Poll(NOW)
check("the next tick does not click Select again", board._children[1].sel._clicks, 1)
check("  ...and the run is still claimable inside the grace window", B.run ~= nil, true)
NOW = 403; B.Poll(NOW)
check("the grace window expires and the run ends", B.run, nil)
check("  ...having never touched Reroll", rerollBtn._clicks, 0)

print("")
print("== a match naming a card that is not on the board stops, it does not pay ==")
-- Unreachable through either shipped matcher, but this is the gold-spending
-- branch: an out-of-board index used to fall through to "no match" and reroll.
BuildBoard({ "Alpha" })
_G["ObjectiveFrame2"]._shown = false
_G["ObjectiveFrame3"]._shown = false
B.run = nil; NOW = 500; PRINTED = {}
B.Start({ label = "test", match = function() return 2, "a slot that is not there" end })
B.Poll(NOW)
check("stopped the run", B.run, nil)
check("  ...clicked no Reroll", rerollBtn._clicks, 0)
check("  ...and named the real fault",
   string.find(table.concat(PRINTED, " "), "not on the board", 1, true) ~= nil, true)

print("")
print("== rerolling that changes nothing gives up (the settle rail) ==")
-- MAX_UNCHANGED had no coverage in any suite. It is the only thing between a
-- server that silently refuses to reroll and a loop that pays for the same
-- three cards until it hits the cap - and it is shared by both callers now.
BuildBoard({ "Alpha", "Beta", "Gamma" })
Popup(nil)   -- this server rerolls with no confirmation dialog
B.run = nil; NOW = 600; PRINTED = {}
B.Start({ label = "test", match = function() return nil end })
B.Poll(600)   -- clicks Reroll, hands off to the confirm step
B.Poll(601)   -- no popup: counts the reroll, starts watching for a change
check("one reroll paid for", rerollBtn._clicks, 1)
B.Poll(602); check("unchanged once, still going", B.run ~= nil, true)
B.Poll(603); check("unchanged twice, still going", B.run ~= nil, true)
B.Poll(604)
check("unchanged three times, gives up", B.run, nil)
check("  ...without paying for a second reroll", rerollBtn._clicks, 1)
check("  ...and says the cards stopped changing",
   string.find(table.concat(PRINTED, " "), "stopped changing", 1, true) ~= nil, true)

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

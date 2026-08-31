-- Executes the REAL Dungeon.lua and Favourites.lua over the REAL Board.lua, at
-- the same time, against one stubbed board.
--
-- Why a suite of its own: board_test.lua proves the engine in isolation and must
-- stay ignorant of both callers, while dungeon_test.lua and fav_test.lua each
-- see only their own side. The extraction made Board.run a SHARED resource, and
-- the defects that fall out of that are exactly the ones neither single-caller
-- suite can see - one feature stranding the board and locking the other out of
-- it until a /reload. dungeon_test.lua is additionally frozen at 37 assertions
-- as the extraction's regression gate, so dungeon-side coverage lands here.
local ADDON = ADDON_DIR
-- WoW 3.3.5 is Lua 5.1 (global unpack); fengari is 5.3 (table.unpack).
unpack = unpack or table.unpack

-- ---- fake widget tree (see dungeon_test.lua) --------------------------------
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
function IsInInstance() return INSIDE, "party" end
function GetRealZoneText() return ZONE or "Utgarde Keep" end
function GetNumPartyMembers() return PARTY or 0 end
function GetNumRaidMembers() return 0 end
PUSHED, SELECTED = 0, nil
function SelectQuestLogEntry(i) SELECTED = i end
function QuestLogPushQuest() PUSHED = PUSHED + 1 end

CallboardHunter = { SpawnDB = {} }
local CBH = CallboardHunter
PRINTED = {}
function CBH.print(m) PRINTED[#PRINTED + 1] = tostring(m) end
function CBH.Log() end
function CBH.safeCall(fn, ...) if fn then fn(...) end end
CBH.db = { options = { dungeonAuto = true, dungeonRerollMax = 10,
                       dungeonGoldReserve = 0, dungeonShare = true,
                       dungeonHintsShown = 0 },
           favourites = {}, cardCatalogue = {} }
local function load(f) local c, e = loadfile(ADDON .. "/" .. f); if not c then error(e) end; c() end
-- UI.lua because Fav.Hunt prints its bound through UI.Stamp before spending.
load("UI.lua"); load("SpawnDB.lua"); load("Board.lua"); load("Dungeon.lua")
load("Favourites.lua")
local D, Fav, B = CBH.Dungeon, CBH.Favourites, CBH.Board

-- ---- board builder (see dungeon_test.lua) -----------------------------------
local board, rerollBtn
local function BuildBoard(cardTexts)
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
   rerollBtn._text = "Reroll Selection 10g 40s"
   board._children[#board._children + 1] = rerollBtn
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

print("== /cbh dungeon off mid-run does not strand the shared board ==")
-- D.Command flipped the flag and walked away. D.Poll then returns on that flag
-- BEFORE it reaches either the despawn stop or its own label guard, so the run
-- was never polled again and nothing expired it. Pre-extraction that only
-- stranded D.run, which nothing else read; Board.run is shared now.
BuildBoard({ "Collect 40 Icethorn." })
B.run = nil; NOW = 10
D.Poll(NOW)
check("a dungeon run is live", B.run ~= nil, true)
D.Command("off")
check("turning automation off stopped it", B.run, nil)
-- The cross-feature half, and the reason this matters at all: an orphaned run
-- made every later /cbh hunt answer "already working the board" until /reload.
CBH.db.favourites = { ["Loken"] = true }
PRINTED = {}
check("  ...so a favourites hunt can still start", Fav.Hunt(), true)
B.run = nil
-- The switch stops OUR run, not whoever else is holding the board.
CBH.db.options.dungeonAuto = true
BuildBoard({ "Bulk Order: Eternal Earth" })
B.run = nil
Fav.Hunt()
D.Command("off")
check("a favourites run is not the dungeon switch's to kill", B.run ~= nil, true)
check("  ...and it is still the favourites run", B.run.label, "favourites")
B.run = nil
CBH.db.options.dungeonAuto = true
CBH.db.favourites = {}

print("")
print("== a hidden card slot must not hide the dungeon's own card ==")
-- Board.ReadCards is sparse by contract; the old ipairs walk stopped at the
-- first hole, so a board whose slot 1 was hidden looked like "no card for this
-- instance" and cost 10g to reroll away.
BuildBoard({ "Collect 40 Icethorn.", "Slay Ingvar the Plunderer in Utgarde Keep.",
             "Kill 10 Murloc." })
_G["ObjectiveFrame1"]._shown = false
check("the names-the-dungeon pass looks past the hole",
   (D.MatchCard(B.ReadCards(), "Utgarde Keep")), 2)
B.run = nil; NOW = 20
D.Poll(NOW)
check("accepted the dungeon's card on slot 2", board._children[2].sel._clicks, 1)
check("  ...instead of paying to reroll a board that already had it",
   rerollBtn._clicks, 0)
B.run = nil
-- The boss-name pass is a second loop over the same list, so it needs the same
-- fix and its own check.
BuildBoard({ "Collect 40 Icethorn.", "Slay Ingvar the Plunderer." })
_G["ObjectiveFrame1"]._shown = false
check("the names-a-boss pass looks past the hole too",
   (D.MatchCard(B.ReadCards(), "Utgarde Keep")), 2)

print("")
print("== the accept grace leaves the dungeon's QUEST_ACCEPTED hand-off intact ==")
PARTY, PUSHED = 4, 0
BuildBoard({ "Slay Ingvar the Plunderer in Utgarde Keep." })
B.run = nil; NOW = 30
D.Poll(NOW)
check("accepted", board._children[1].sel._clicks, 1)
check("the run outlives the click, waiting for the event", B.run ~= nil, true)
D.OnQuestAccepted(7)
check("the event still shares the quest", PUSHED, 1)
check("  ...and still ends the run", B.run, nil)

-- QUEST_ACCEPTED is the server's to send. When it does not arrive, the engine's
-- own grace window ends the run instead of leaving Board.run set forever - which
-- would now lock favourites out of the board as well.
BuildBoard({ "Slay Ingvar the Plunderer in Utgarde Keep." })
B.run = nil; NOW = 40
D.Poll(NOW)
check("accepted, event pending", B.run ~= nil, true)
NOW = 40.5; D.Poll(NOW)
check("a tick inside the window does not click Select twice",
   board._children[1].sel._clicks, 1)
NOW = 43; D.Poll(NOW)
check("the grace window releases the shared board", B.run, nil)
CBH.db.favourites = { ["Loken"] = true }
check("  ...so favourites is not locked out by a lost event", Fav.Hunt(), true)
B.run = nil
CBH.db.favourites = {}

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

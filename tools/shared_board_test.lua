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
--
-- A HARNESS ASSUMPTION WORTH KNOWING BEFORE YOU ADD PER-BOARD STATE TO
-- Dungeon.lua: dungeon_test.lua builds a NEW board frame between scenarios and
-- never simulates the old one despawning, so D.Poll there never sees a tick
-- with the board hidden. Any state that only clears on despawn therefore stays
-- armed across its scenarios and fails it - the once-per-board guard below cost
-- 33/37 as a plain boolean before it was keyed on the board frame instead. The
-- freeze is on that file's ASSERTIONS, so the fix is to make the guard survive
-- a board swap, not to reach over and edit the gate.
--
-- This suite is the place to exercise the despawn path directly, because it can
-- hide and re-show ONE frame - which is what the game actually does, where
-- ObjectivesMainFrame is long-lived and summons only show and hide it.
--
-- The instance-coverage gate below (D.declinedInstance) adds per-entry state to
-- the same function and does NOT share the landmine above: it clears when
-- D.OnZoneChanged sees the player leave the instance, not when the board
-- despawns, and dungeon_test.lua exercises that leave-transition directly
-- (INSIDE = false, both explicit and via manual D.announced resets) rather than
-- assuming it. Board identity was the wrong key for it anyway - the gate is a
-- fact about the INSTANCE ("has a quest ever been seen here"), not about which
-- physical board frame is in front of the player.
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
print("== one auto-started run per board, however the last one ended ==")
-- The grace rail above is what makes this reachable, and the two callers differ
-- here: Favourites nils the run inside its own onAccept, but Dungeon leaves the
-- run standing so QUEST_ACCEPTED can read the quest log index off it. When that
-- event is genuinely lost, the rail releases the run 2s after the click - which
-- is correct, the shared board must not stay locked - and D.Poll then saw
-- `Board.run == nil` with the board still up and started a SECOND run against
-- the board it had just taken a card from.
--
-- That restart is the PAID branch: the card it took is gone, so nothing matches,
-- so it rerolls - up to the cap, at 10g 40s a go - off one dropped event. Before
-- the grace rail existed the same lost event merely re-clicked Select every 0.5s
-- and cost nothing, so this is a regression the rail introduced, not an old bug.
PARTY = 0
BuildBoard({ "Slay Ingvar the Plunderer in Utgarde Keep." })
B.run = nil; NOW = 50
D.Poll(NOW)
check("took the dungeon's card", board._children[1].sel._clicks, 1)
NOW = 53; D.Poll(NOW)                 -- the event never comes; the rail lets go
check("the lost event still releases the shared board", B.run, nil)
-- The board keeps its other cards, but not the one we just took. That is what
-- makes the restart cost gold rather than merely click Select twice.
_G["ObjectiveFrame1"]._regions[1]._text = "Collect 40 Icethorn."
NOW = 54; D.Poll(NOW)
check("no second run against the board we already worked", B.run, nil)
check("  ...so a dropped event buys no rerolls", rerollBtn._clicks, 0)
check("  ...and Select is not clicked a second time",
   board._children[1].sel._clicks, 1)

-- Same guard, no dropped event needed: any stop leaves Board.run nil with the
-- board still up. A restart begins at rerolls = 0, so the per-summon cap the
-- player set becomes a per-run figure that the board's 30s life resets over and
-- over. Here the run stops on the cards-stopped-changing rail after one reroll;
-- unguarded, D.Poll starts again and pays for another, indefinitely.
BuildBoard({ "Collect 40 Icethorn.", "Kill 10 Murloc.", "Bulk Order: Eternal Earth" })
B.run = nil; NOW = 60
D.Poll(NOW)                                       -- no match -> click Reroll
check("no card for this instance, so it rerolled", rerollBtn._clicks, 1)
NOW = 60.6; D.Poll(NOW)                           -- confirm (no popup on this server)
for i = 1, 3 do NOW = 61.2 + (i - 1) * 0.6; D.Poll(NOW) end   -- 3 unchanged -> stop
check("the run gave up on the unchanging board", B.run, nil)
for i = 1, 6 do NOW = 63 + i; D.Poll(NOW) end
check("a stopped run does not restart on the same board", B.run, nil)
check("  ...so the reroll cap is not reset back to zero", rerollBtn._clicks, 1)

-- The guard must not curdle into "dungeon automation runs once per session".
-- In game the board is ONE long-lived frame that summons show and despawns
-- hide, so a resummon has the same identity as the board we just worked and the
-- despawn tick is the only thing that can re-arm it. Reusing the frame here is
-- the point of this check, not an economy.
board._shown = false
NOW = 70; D.Poll(NOW)                    -- the 30s window expires
_G["ObjectiveFrame1"]._regions[1]._text = "Slay Ingvar the Plunderer in Utgarde Keep."
board._shown = true                      -- ...and the player summons another
B.run = nil; NOW = 71
D.Poll(NOW)
check("a resummon onto the same frame re-arms the automation",
   board._children[1].sel._clicks, 1)
B.run = nil

-- And a board that is a different frame is a different board whatever we saw,
-- which is what keeps the guard from leaking across dungeon_test.lua's scenarios.
BuildBoard({ "Slay Ingvar the Plunderer in Utgarde Keep." })
B.run = nil; NOW = 80
D.Poll(NOW)
check("so does a board that is a different frame entirely",
   board._children[1].sel._clicks, 1)
B.run = nil

print("")
print("== instance coverage gate: no known quest -> no paid reroll hunt ==")
-- The reported live bug: Icecrown Citadel has boss data in SpawnDB (Board.lua
-- needs it to MATCH a card that names Festergut, say), but this server has
-- never issued an ICC callboard quest at all, so D.Poll used to reroll to its
-- cap (~104g) chasing a card that could never appear. None of these cards name
-- ICC or one of its bosses, so there is no free match to fall back on either -
-- this is the actual shape of the reported loss, not a contrived board.
INSIDE, ZONE = true, "Icecrown Citadel"
D.announced, D.declinedInstance = nil, nil
BuildBoard({ "Collect 40 Icethorn.", "Kill 10 Murloc.", "Bulk Order: Eternal Earth" })
B.run = nil; NOW = 100; PRINTED = {}
D.Poll(NOW)
check("no run started for an uncovered instance", B.run, nil)
-- The click counter, not B.run, is the load-bearing assertion here: a version
-- that started the run and then let the reserve/cap logic stop it on the very
-- first tick would also read B.run == nil, while having already paid for one
-- reroll on the way there.
check("  ...critically, no Reroll click - not just no run", rerollBtn._clicks, 0)
check("told the player once, rather than failing silently", #PRINTED, 1)
check("  ...and named the instance", string.find(PRINTED[1], "Icecrown Citadel") ~= nil, true)
NOW = 100.5; D.Poll(NOW)
check("does not repeat the decline every tick", #PRINTED, 1)

print("")
print("== instance coverage gate: a known quest still automates ==")
-- Utgarde Keep is covered by the bundled "Ingvar the Plunderer" quest (SpawnDB
-- QUESTS), so the gate must not disable the feature for the common case - this
-- board has no free match either, so a reroll click here proves the loop still
-- runs, not just that Board.run got created.
INSIDE, ZONE = true, "Utgarde Keep"
D.announced, D.declinedInstance = nil, nil
BuildBoard({ "Collect 40 Icethorn." })
B.run = nil; NOW = 110; PRINTED = {}
D.Poll(NOW)
check("still starts a run - the bundled Ingvar quest covers it", B.run ~= nil, true)
check("  ...and rerolls looking for it, same as before the fix", rerollBtn._clicks, 1)
B.run = nil

print("")
print("== instance coverage gate: the catalogue teaches it ==")
check("Halls of Stone starts uncovered (no bundled quest names it)",
   CBH.SpawnDB.InstanceHasKnownQuest("Halls of Stone"), false)
CBH.db.cardCatalogue["Slay Krystallus in Halls of Stone."] = { n = 1 }
CBH.SpawnDB.InvalidateCoverage()
check("a catalogued card now covers the instance",
   CBH.SpawnDB.InstanceHasKnownQuest("Halls of Stone"), true)
INSIDE, ZONE = true, "Halls of Stone"
D.announced, D.declinedInstance = nil, nil
BuildBoard({ "Collect 40 Icethorn." })
B.run = nil; NOW = 120
D.Poll(NOW)
check("the gate now lets automation run for a taught instance", B.run ~= nil, true)
B.run = nil
-- A pre-1.9.8 self-annotation (Advisor.lua's own "Dungeon/raid: X" card note,
-- colour-coded) must not count as evidence a real card exists - it is CBH
-- talking to itself, not something the server ever wrote. Fav.List skips the
-- same |c-tainted keys for the same reason.
CBH.db.cardCatalogue[CBH.UI.Colour("inkSoft", "Dungeon/raid: Trial of the Champion")] = { n = 1 }
CBH.SpawnDB.InvalidateCoverage()
check("a |c-tainted catalogue key grants no coverage",
   CBH.SpawnDB.InstanceHasKnownQuest("Trial of the Champion"), false)
CBH.db.cardCatalogue = {}
CBH.SpawnDB.InvalidateCoverage()

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

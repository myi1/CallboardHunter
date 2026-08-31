-- Executes the REAL Favourites.lua (over the REAL SpawnDB.TargetOf and the REAL
-- Board.lua reroll engine) against stubbed card frames. UI.lua is loaded because
-- Fav.Command's /cbh fav list prints CBH.UI.Stamp per row - without it that path
-- would die on a nil index instead of on the assertion actually under test. The
-- star widget (Fav.StarText, a later task) will need it too.
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
-- Fav.Hunt drives Board.lua's real reroll loop (see below), which reads the
-- clock and the player's purse to gate rerolls - stub both so a hunt test can
-- actually reach a reroll click instead of being refused for poverty.
function GetTime() return NOW or 0 end
MONEY = 5000000
function GetMoney() return MONEY end

CallboardHunter = { SpawnDB = {} }
local CBH = CallboardHunter
PRINTED = {}
function CBH.print(m) PRINTED[#PRINTED + 1] = tostring(m) end
function CBH.Log() end
CBH.db = { favourites = {}, cardCatalogue = {} }
local function load(f) local c, e = loadfile(ADDON .. "/" .. f); if not c then error(e) end; c() end
load("UI.lua"); load("SpawnDB.lua"); load("Board.lua"); load("Favourites.lua")
local Fav = CBH.Favourites

-- ---- board builder (see dungeon_test.lua) -----------------------------------
-- Each card now carries a Select button and the board a Reroll button, because
-- Fav.Hunt (Task 4) drives the real Board.lua loop, which clicks both.
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

-- Fav.MatchCards takes the card list rather than reading it itself, so tests
-- build it the same way Board.ReadCards would, without needing Board.lua.
function ReadCardsStub()
   local out = {}
   for i = 1, 3 do
      local card = _G["ObjectiveFrame" .. i]
      if card and card:IsShown() then
         local texts = {}
         for r = 1, select("#", card:GetRegions()) do
            local reg = select(r, card:GetRegions())
            if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
               local t = reg:GetText()
               if t and t ~= "" then texts[#texts + 1] = t end
            end
         end
         out[i] = { frame = card, text = table.concat(texts, " | ") }
      end
   end
   return out
end

local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label, tostring(got),
      ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end

CBH.db.favourites = {}
CBH.db.cardCatalogue = {}

print("== toggling ==")
check("not favourite initially", Fav.IsFavourite("Loken"), false)
check("toggle on returns true", Fav.Toggle("Loken"), true)
check("  ...and it sticks", Fav.IsFavourite("Loken"), true)
check("toggle off returns false", Fav.Toggle("Loken"), false)
check("  ...and it clears", Fav.IsFavourite("Loken"), false)
check("nil is safe", Fav.Toggle(nil), false)

print("")
print("== matching keys on the target, not the title ==")
CBH.db.favourites = { ["Loken"] = true }
BuildBoard({ "Bulk Order: Eternal Earth", "Dungeon Crawl: Loken", "No Mercy: Azure Scalebane" })
local idx, why = Fav.MatchCards(CBH.Board and CBH.Board.ReadCards() or ReadCardsStub())
check("found the favourite", idx, 2)
check("  ...and says why", string.find(why or "", "Loken", 1, true) ~= nil, true)

BuildBoard({ "Wanted: Loken" })
check("same target, different prefix", (Fav.MatchCards(ReadCardsStub())), 1)

BuildBoard({ "Bulk Order: Eternal Earth" })
check("no favourite present", Fav.MatchCards(ReadCardsStub()), nil)

print("")
print("== an empty favourites list refuses to match anything ==")
-- The hunt command (a later task) treats "no match" as license to keep
-- rerolling. An empty list must never look like a hit, or hunting with
-- nothing favourited would burn gold forever with no way to stop. Restore the
-- prior set afterward - this suite has a history of one test's leftover state
-- silently changing a later one's result.
local savedFavourites = CBH.db.favourites
CBH.db.favourites = {}
BuildBoard({ "Wanted: Loken" })
check("empty favourites, no match", Fav.MatchCards(ReadCardsStub()), nil)
CBH.db.favourites = savedFavourites

print("")
print("== progress counters do not break matching ==")
CBH.db.favourites = { ["Azure Scalebane"] = true }
BuildBoard({ "No Mercy: Azure Scalebane", "Azure Scalebane slain: 3/10" })
check("matches despite the counter", (Fav.MatchCards(ReadCardsStub())), 1)

print("")
print("== the pickable list is bundled union catalogue ==")
CBH.db.favourites = {}
CBH.db.cardCatalogue = { ["Sweep and Clear: Brand New Mob"] = { n = 1, lo = 80, hi = 80 } }
local list = Fav.List()
local names = {}
for _, e in ipairs(list) do names[e.target] = e end
check("includes a bundled target", names["Loken"] ~= nil, true)
check("includes a learned target", names["Brand New Mob"] ~= nil, true)
check("marks favourites", names["Loken"].favourite, false)
CBH.db.favourites = { ["Loken"] = true }
local list2 = Fav.List()
local n2 = {}
for _, e in ipairs(list2) do n2[e.target] = e end
check("  ...once favourited", n2["Loken"].favourite, true)
check("no duplicates", (function()
   local seen, dupes = {}, 0
   for _, e in ipairs(Fav.List()) do
      if seen[e.target] then dupes = dupes + 1 end
      seen[e.target] = true
   end
   return dupes
end)(), 0)
check("count reflects the set", Fav.Count(), 1)

print("")
print("== List merges lo/hi when a target appears in both sources ==")
-- "Loken" is already bundled at lo=80,hi=80 (see SpawnDB.QUESTS). A catalogue
-- sighting outside that band must widen the row, not duplicate it - Fav.List
-- is the only place both sources meet, so this merge path would otherwise
-- ship untested.
CBH.db.cardCatalogue = { ["Wanted: Loken"] = { n = 1, lo = 75, hi = 85 } }
local list3 = Fav.List()
local seenLoken, mergedLoken = 0, nil
for _, e in ipairs(list3) do
   if e.target == "Loken" then
      seenLoken = seenLoken + 1
      mergedLoken = e
   end
end
check("merged target appears exactly once", seenLoken, 1)
check("lo widened down to the catalogue's band", mergedLoken and mergedLoken.lo, 75)
check("hi widened up to the catalogue's band", mergedLoken and mergedLoken.hi, 85)

print("")
print("== hunt refuses to start with an empty list ==")
CBH.db.favourites = {}
PRINTED = {}
BuildBoard({ "Alpha", "Beta", "Gamma" })
CBH.Board.run = nil; NOW = 100
check("did not start", Fav.Hunt(), false)
check("  ...and said why", string.find(table.concat(PRINTED, " "), "favourite") ~= nil, true)
check("  ...clicked nothing", rerollBtn._clicks, 0)

print("")
print("== hunt takes a favourite that is already on the board ==")
CBH.db.favourites = { ["Loken"] = true }
BuildBoard({ "Bulk Order: Eternal Earth", "Wanted: Loken", "No Mercy: Azure Scalebane" })
CBH.Board.run = nil; NOW = 110
check("started", Fav.Hunt(), true)
Fav.Poll(NOW)
check("took the favourite", board._children[2].sel._clicks, 1)
check("without rerolling", rerollBtn._clicks, 0)

print("")
print("== hunt rerolls when no favourite is present ==")
BuildBoard({ "Bulk Order: Eternal Earth" })
CBH.Board.run = nil; NOW = 120
Fav.Hunt()
Fav.Poll(NOW)
check("clicked reroll", rerollBtn._clicks, 1)

print("")
print("== hunt refuses to start while any run is already live ==")
-- Not the empty-list branch and not the no-board branch: the board is open
-- and favourites still holds Loken from two tests ago. This is specifically
-- the "someone already owns the board" refusal, and it must fire even for a
-- FOREIGN run's label - Fav.Hunt is not supposed to special-case whose run it
-- is, only whether one exists.
BuildBoard({ "Wanted: Loken" })
CBH.Board.run = { label = "dungeon", subject = "dungeon", match = function() end,
   rerolls = 0, spent = 0, rerollMax = 10, goldReserve = 0, unchanged = 0, at = 0,
   phase = "match", lastSig = nil }
PRINTED = {}
check("refused while a run is live", Fav.Hunt(), false)
check("  ...for the right reason", string.find(string.lower(table.concat(PRINTED, " ")),
   "already", 1, true) ~= nil, true)
check("  ...touched nothing on the board", rerollBtn._clicks, 0)
CBH.Board.run = nil

print("")
print("== Fav.Poll never drives a run it does not own (the double-click guard) ==")
-- This is the guard the whole label/ownership scheme exists for: if Fav.Poll
-- ever drove a run labelled "dungeon", the Dungeon poller and this one would
-- both advance the SAME run in one ticker pass and click Select or Reroll
-- twice - real gold, spent twice per tick. The foreign run's match always
-- misses, so if the guard were ever dropped this poll would click Reroll;
-- assert on that counter, not just "no error was raised".
BuildBoard({ "Wanted: Loken" })
CBH.Board.run = { label = "dungeon", subject = "dungeon", match = function() return nil end,
   rerolls = 0, spent = 0, rerollMax = 10, goldReserve = 0, unchanged = 0, at = 0,
   phase = "match", lastSig = nil }
NOW = 140
Fav.Poll(NOW)
check("left the foreign run's reroll button untouched", rerollBtn._clicks, 0)
check("left the foreign run's Select buttons untouched", board._children[1].sel._clicks, 0)
check("did not advance the foreign run's state", CBH.Board.run.rerolls, 0)
CBH.Board.run = nil

print("")
print("== reroll cap stops the hunt through Fav.Poll, not just the engine ==")
-- board_test.lua and dungeon_test.lua already prove Board.lua's own cap
-- works; this proves Favourites is actually WIRED to it - a future edit to
-- Fav.Hunt's Board.Start call (say, dropping the implicit rerollMax default)
-- could break that wiring without failing anything else in this file.
BuildBoard({ "Bulk Order: Eternal Earth" })   -- no favourite present -> would reroll forever
CBH.Board.run = nil; NOW = 150
Fav.Hunt()
CBH.Board.run.rerolls = 10   -- Board's default cap; pretend we already got there
CBH.Board.run.phase = "match"; CBH.Board.run.at = 0
NOW = 151
Fav.Poll(NOW)
check("stopped at the cap", CBH.Board.run, nil)

print("")
print("== hunt needs an open board ==")
board._shown = false
CBH.Board.run = nil; PRINTED = {}
check("refuses with no board", Fav.Hunt(), false)
board._shown = true

print("")
print("== a won hunt is over: no second accept, and no reroll after the win ==")
-- Nothing cleared Board.run at the accept, and Favourites has no QUEST_ACCEPTED
-- hook (Dungeon's nils the run as a side effect). So Fav.Poll kept driving a won
-- run at the ticker's 0.5s cadence: Select clicked again every tick, and a paid
-- reroll the moment the taken card left the board. At a permanent callboard
-- there is no despawn to brake that.
CBH.db.favourites = { ["Loken"] = true }
BuildBoard({ "Bulk Order: Eternal Earth", "Wanted: Loken", "No Mercy: Azure Scalebane" })
CBH.Board.run = nil; NOW = 160
Fav.Hunt()
Fav.Poll(NOW)
check("took the favourite", board._children[2].sel._clicks, 1)
check("the run ended at the accept", CBH.Board.run, nil)
NOW = 160.5; Fav.Poll(NOW)
NOW = 161;   Fav.Poll(NOW)
NOW = 161.5; Fav.Poll(NOW)
check("later ticks do not click Select again", board._children[2].sel._clicks, 1)
check("  ...and never reroll a hunt that already won", rerollBtn._clicks, 0)

-- The other half: the server takes the accepted card off the board and leaves
-- the board open. A run still live here finds no favourite and pays to reroll.
BuildBoard({ "Bulk Order: Eternal Earth", "Wanted: Loken", "No Mercy: Azure Scalebane" })
CBH.Board.run = nil; NOW = 170
Fav.Hunt(); Fav.Poll(NOW)
check("accepted", board._children[2].sel._clicks, 1)
BuildBoard({ "Bulk Order: Eternal Earth", "Collect 40 Icethorn.", "No Mercy: Azure Scalebane" })
NOW = 171; Fav.Poll(NOW)
NOW = 172; Fav.Poll(NOW)
check("the vanished card does not restart the spending", rerollBtn._clicks, 0)
check("  ...and the run is still gone", CBH.Board.run, nil)

print("")
print("== a hidden card slot must not hide the favourite behind it ==")
-- Board.ReadCards is sparse: a hidden slot leaves a hole, and the old ipairs
-- walk stopped there. With card 1 hidden, Loken on card 2 was invisible and the
-- hunt paid 10g to reroll a board that already held what it wanted.
CBH.db.favourites = { ["Loken"] = true }
BuildBoard({ "Bulk Order: Eternal Earth", "Wanted: Loken", "No Mercy: Azure Scalebane" })
_G["ObjectiveFrame1"]._shown = false   -- the server drew two cards, not three
check("MatchCards looks past the hole", (Fav.MatchCards(CBH.Board.ReadCards())), 2)
CBH.Board.run = nil; NOW = 180
check("hunt started", Fav.Hunt(), true)
Fav.Poll(NOW)
check("took the favourite on slot 2", board._children[2].sel._clicks, 1)
check("  ...instead of paying to reroll a board that already had it",
   rerollBtn._clicks, 0)
CBH.Board.run = nil

print("")
print("== CBH's own card note is not evidence (1.9.7's bug, now in the engine) ==")
-- Advisor draws "Dungeon/raid: Naxxramas" onto the card, and UI.Colour wraps it
-- in |cff..|r - whose own pipes split it into a clean-looking title line for
-- MatchCards, which then reads OUR text as a card and takes the wrong quest.
CBH.db.favourites = { ["Naxxramas"] = true }
BuildBoard({ "Slay Loken in Halls of Lightning." })
local annotated = _G["ObjectiveFrame1"]
local note = fs(CBH.UI.Colour("inkSoft", "Dungeon/raid: Naxxramas"))
annotated._regions[#annotated._regions + 1] = note
annotated.cbhNote = note
check("the note is not in what the engine reads",
   string.find(CBH.Board.ReadCards()[1].text, "Naxxramas", 1, true), nil)
check("  ...so our own annotation is never a favourite match",
   Fav.MatchCards(CBH.Board.ReadCards()), nil)
CBH.db.favourites = {}

print("")
print("== pre-1.9.8 self-annotations are not pickable favourites ==")
-- CBH.RecordCard gained a |c guard, but nothing purged what 1.9.7 had already
-- written: one real database held 97 such entries out of 346. Left in, they are
-- rows that look real and can never match a card - favourite one and the next
-- hunt rerolls to the cap with no possible win.
CBH.db.favourites = {}
CBH.db.cardCatalogue = {
   ["Sweep and Clear: Brand New Mob"] = { n = 1, lo = 80, hi = 80 },
   ["|cff322516Dungeon/raid: Naxxramas|r"] = { n = 4, lo = 80, hi = 80 },
   ["|cff4a3105> READY|r |cff160f083 known spots in Icecrown|r"] = { n = 2 },
}
local poisoned, clean = 0, false
for _, e in ipairs(Fav.List()) do
   if string.find(e.target, "|", 1, true) then poisoned = poisoned + 1 end
   if e.target == "Brand New Mob" then clean = true end
end
check("no colour-escaped row survives the merge", poisoned, 0)
check("a genuine learned target still does", clean, true)
CBH.db.cardCatalogue = {}

print("")
print("== a hunt inherits the dungeon brakes, and says the bound out loud ==")
-- Board.Start defaults to reserve 0 / cap 10 and Fav.Hunt passed neither, so a
-- player who had set /cbh dungeon reserve 500 got exactly no reserve the moment
-- they typed /cbh hunt. And the first thing they heard from a gold-spending
-- loop was "reroll 1 - spent 10g 40s".
CBH.db.favourites = { ["Loken"] = true }
CBH.db.options = { dungeonRerollMax = 4, dungeonGoldReserve = 5000000 }
BuildBoard({ "Bulk Order: Eternal Earth" })
CBH.Board.run = nil; NOW = 190; PRINTED = {}
check("started", Fav.Hunt(), true)
check("inherited the dungeon reroll cap", CBH.Board.run.rerollMax, 4)
check("inherited the dungeon gold reserve", CBH.Board.run.goldReserve, 5000000)
local said = table.concat(PRINTED, " ")
check("said the cap before spending anything",
   string.find(said, "up to 4 reroll", 1, true) ~= nil, true)
check("  ...and the reserve", string.find(said, "500g", 1, true) ~= nil, true)
check("  ...with nothing clicked yet", rerollBtn._clicks, 0)
NOW = 191; Fav.Poll(NOW)
check("the inherited reserve actually stops the spend", rerollBtn._clicks, 0)
check("  ...and stops the run", CBH.Board.run, nil)
-- A favourites-side number, once set, wins over the inherited one.
CBH.db.options.favRerollMax = 2
CBH.db.options.favGoldReserve = 100000
CBH.Board.run = nil
Fav.Hunt()
check("fav cap overrides the dungeon cap", CBH.Board.run.rerollMax, 2)
check("fav reserve overrides the dungeon reserve", CBH.Board.run.goldReserve, 100000)
CBH.Board.run = nil
CBH.db.options = nil

print("")
print("== /cbh hunt stop calls a hunt off without closing the board ==")
CBH.db.favourites = { ["Loken"] = true }
BuildBoard({ "Bulk Order: Eternal Earth" })
CBH.Board.run = nil; NOW = 200; PRINTED = {}
Fav.Hunt()
check("running", CBH.Board.run ~= nil, true)
check("stop reports it stopped one", Fav.Hunt("stop"), true)
check("  ...and the run is gone", CBH.Board.run, nil)
check("  ...so a fresh hunt can start again", Fav.Hunt(), true)
CBH.Board.run = nil
check("stop with nothing running says so", Fav.Hunt("stop"), false)
-- Not a licence to kill someone else's run.
CBH.Board.run = { label = "dungeon", subject = "dungeon", match = function() end,
   rerolls = 0, spent = 0, rerollMax = 10, goldReserve = 0, unchanged = 0, at = 0,
   phase = "match", lastSig = nil }
check("refuses to stop a dungeon run", Fav.Hunt("stop"), false)
check("  ...and leaves it alone", CBH.Board.run ~= nil, true)
CBH.Board.run = nil

print("")
print("== /cbh fav reports the limits a hunt would work within ==")
-- The list branch prints per-favourite rows through DEFAULT_CHAT_FRAME rather
-- than CBH.print, so it needs the real chat frame to exist - and it now also
-- reads the inherited reserve, which is a nil index away from throwing.
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) PRINTED[#PRINTED + 1] = tostring(m) end }
CBH.db.favourites = { ["Loken"] = true }
CBH.db.options = { dungeonGoldReserve = 2500000 }
PRINTED = {}
Fav.Command("")
local listed = table.concat(PRINTED, " ")
check("lists the favourite", string.find(listed, "Loken", 1, true) ~= nil, true)
check("names the reserve it inherited, before any of it is spent",
   string.find(listed, "250g", 1, true) ~= nil, true)
CBH.db.options = nil
CBH.db.favourites = {}

print("")
print("== an unrecognised /cbh fav argument explains itself ==")
PRINTED = {}
Fav.Command("wibble")
local out = table.concat(PRINTED, " ")
check("said it did not understand", string.find(out, "wibble", 1, true) ~= nil, true)
check("  ...and printed the usage line", string.find(out, "/cbh fav", 1, true) ~= nil, true)

print("")
print("== the star reads as a shape, not a colour ==")
CBH.db.favourites = {}
local off = Fav.StarText("Loken")
Fav.Toggle("Loken")
local on = Fav.StarText("Loken")
check("off and on differ", off ~= on, true)
local function strip(s)
   s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
   return (string.gsub(s, "|r", ""))
end
check("still differ with colour stripped", strip(off) ~= strip(on), true)
check("off is the hollow glyph", strip(off), "[ ]")
check("on is the filled glyph", strip(on), "[*]")
Fav.Toggle("Loken")
check("toggling off reverts the glyph", strip(Fav.StarText("Loken")), "[ ]")
check("unknown target still renders", strip(Fav.StarText("Nobody")), "[ ]")

-- One function, two grounds (Config.lua had a near-miss copy of the glyphs
-- called FavGlyph, so a shape change would have landed in one place only).
-- The glyph is identical either way; only the ink tier moves.
CBH.db.favourites = { ["Loken"] = true }
local HEX = CBH.UI.HEX
check("the same shape on both grounds",
   strip(Fav.StarText("Loken", true)), strip(Fav.StarText("Loken")))
check("on a card: verdigris INK, not a dark-panel tier",
   string.find(Fav.StarText("Loken", true), HEX.verdigrisInk, 1, true) ~= nil, true)
check("on a card: NOT brass - UI.Stamp(\"ready\") already spends brass there",
   string.find(Fav.StarText("Loken", true), HEX.brassInk, 1, true) ~= nil, false)
check("on a panel: the dark-surface verdigris",
   string.find(Fav.StarText("Loken"), HEX.verdigris, 1, true) ~= nil, true)
check("off on a card stays ink", string.find(Fav.StarText("Nobody", true),
   HEX.inkSoft, 1, true) ~= nil, true)
check("off on a panel stays muted", string.find(Fav.StarText("Nobody"),
   HEX.muted, 1, true) ~= nil, true)
CBH.db.favourites = {}

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

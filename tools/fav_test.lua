-- Executes the REAL Favourites.lua (over the REAL SpawnDB.TargetOf) against
-- stubbed card frames. UI.lua is loaded too, even though this task's own
-- functions never call it: Fav.StarText and Fav.Command (Tasks 4 and 5) call
-- CBH.UI.Colour / CBH.UI.Stamp, and a suite without UI.lua would die on a nil
-- index in those later tasks rather than on the assertion actually under test.
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

CallboardHunter = { SpawnDB = {} }
local CBH = CallboardHunter
CBH.db = { favourites = {}, cardCatalogue = {} }
local function load(f) local c, e = loadfile(ADDON .. "/" .. f); if not c then error(e) end; c() end
load("UI.lua"); load("SpawnDB.lua"); load("Favourites.lua")
local Fav = CBH.Favourites

-- ---- board builder (see dungeon_test.lua) -----------------------------------
local board
local function BuildBoard(cardTexts)
   board = mk("Frame", "ObjectivesMainFrame")
   for i = 1, 3 do
      local card = mk("Frame", "ObjectiveFrame" .. i)
      card._regions = { fs(cardTexts[i] or "") }
      board._children[#board._children + 1] = card
   end
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
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

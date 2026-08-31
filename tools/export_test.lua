-- Executes the REAL SpawnDB.lua + Export.lua: corroboration counts, the legacy
-- 2-element point migration, and the shape of the export table.
local ADDON = ADDON_DIR

local function stubFrame()
   local f = {}; setmetatable(f, { __index = function() return function() end end }); return f
end
function CreateFrame() return stubFrame() end
function GetAddOnMetadata() return "1.6.0" end
function GetRealmName() return "Ebonhold" end
function UnitName() return "Keepsy" end
function UnitLevel() return LEVEL or 70 end
_G.date = function() return "2026-08-29 12:00:00" end
function GetTime() return 0 end
function GetRealZoneText() return "Icecrown" end

CallboardHunter = { SpawnDB = {}, QuestWatcher = {}, Arrow = {} }
local CBH = CallboardHunter
PRINTED = {}
function CBH.print(m) PRINTED[#PRINTED + 1] = tostring(m) end
function CBH.Log() end
CBH.db = { learned = {}, learnedKills = {}, options = {} }

local function load(f)
   local c, e = loadfile(ADDON .. "/" .. f)
   if not c then error("load " .. f .. ": " .. tostring(e)) end
   c()
end
load("SpawnDB.lua")
load("Export.lua")
local SpawnDB = CBH.SpawnDB

local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label,
      tostring(got), ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end

print("== corroboration counts ==")
-- Three sightings of the same spot (within the 50yd dedupe radius) = one point
-- with n=3, not three points.
SpawnDB.Learn("Icecrown", "Putridus the Ancient", 32487, 0.570, 0.440)
SpawnDB.Learn("Icecrown", "Putridus the Ancient", 32487, 0.5705, 0.4405)
SpawnDB.Learn("Icecrown", "Putridus the Ancient", 32487, 0.5702, 0.4402)
local e = CBH.db.learned["Icecrown"][32487]
check("one point kept", #e.points, 1)
check("counted 3 sightings", e.points[1][3], 3)
-- A genuinely different spot is a separate point.
SpawnDB.Learn("Icecrown", "Putridus the Ancient", 32487, 0.700, 0.600)
check("distant sighting is a new point", #e.points, 2)
check("new point starts at 1", e.points[2][3], 1)

print("\n== legacy 2-element points still work (no migration needed) ==")
CBH.db.learned["Zul'Drak"] = { [33776] = { name = "Gondria", points = { {0.60, 0.60} } } }
SpawnDB.Learn("Zul'Drak", "Gondria", 33776, 0.6001, 0.6001)
local g = CBH.db.learned["Zul'Drak"][33776]
check("legacy point not duplicated", #g.points, 1)
check("legacy point counted as 1 then bumped", g.points[1][3], 2)

print("\n== callboard camps count too ==")
SpawnDB.LearnKill("Icecrown", "Flame Revenant", 0.30, 0.30)
SpawnDB.LearnKill("Icecrown", "Flame Revenant", 0.3001, 0.3001)
check("camp corroborated", CBH.db.learnedKills["Icecrown"]["Flame Revenant"][1][3], 2)

print("\n== export table shape ==")
CBH.Export()
local X = CallboardHunterExport
check("format stamped", X.format, 1)
check("addon version", X.addon, "1.6.0")
check("realm", X.realm, "Ebonhold")
check("character (for credit/dedup)", X.character, "Keepsy")
check("rares present", X.rares["Icecrown"]["Putridus the Ancient"] ~= nil, true)
check("npcID kept for merging", X.rares["Icecrown"]["Putridus the Ancient"].npcID, 32487)
check("counts survive export", X.rares["Icecrown"]["Putridus the Ancient"].points[1][3], 3)
check("coords rounded", X.rares["Icecrown"]["Putridus the Ancient"].points[1][1], 0.57)
check("camps present", X.camps["Icecrown"]["Flame Revenant"] ~= nil, true)
-- camps use the same {points={...}} shape as rares, for one consistent format
check("camp count survives", X.camps["Icecrown"]["Flame Revenant"].points[1][3], 2)
check("camps carry no npcID", X.camps["Icecrown"]["Flame Revenant"].npcID, nil)
-- The export must never carry personal setup (home, callboards, logs, options).
check("no home leaked", X.home, nil)
check("no log leaked", X.log, nil)
check("no options leaked", X.options, nil)

print("\n== clear ==")
CBH.Export("clear")
check("export cleared", CallboardHunterExport, nil)

print("\n== empty database declines gracefully ==")
CBH.db.learned, CBH.db.learnedKills = {}, {}
CBH.Export()
check("nothing written when nothing learned", CallboardHunterExport, nil)

print("")
print("== card catalogue: records EVERY card, not just parseable ones ==")
CBH.db.cardCatalogue = {}
LEVEL = 70
CBH.RecordCard("Kill 10 Azure Manashaper in Crystalsong Forest.")
CBH.RecordCard("Collect 40 Icethorn.")           -- never recorded before
CBH.RecordCard("Slay Ingvar the Plunderer in Utgarde Keep.")
local cnt = 0
for _ in pairs(CBH.db.cardCatalogue) do cnt = cnt + 1 end
check("all three kinds recorded", cnt, 3)
check("collection card is in there", CBH.db.cardCatalogue["Collect 40 Icethorn."] ~= nil, true)
check("  ...with the level", CBH.db.cardCatalogue["Collect 40 Icethorn."].lo, 70)

print("")
print("== live progress counters do not fragment an entry ==")
CBH.db.cardCatalogue = {}
CBH.RecordCard("Beast Kill in Howling Fjord: 0/75")
CBH.RecordCard("Beast Kill in Howling Fjord: 12/75")
CBH.RecordCard("Beast Kill in Howling Fjord: 75/75")
cnt = 0
for _ in pairs(CBH.db.cardCatalogue) do cnt = cnt + 1 end
check("one entry, not three", cnt, 1)
local key = "Beast Kill in Howling Fjord: #/#"
check("counter normalised out of the key", CBH.db.cardCatalogue[key] ~= nil, true)
check("seen count accumulated", CBH.db.cardCatalogue[key].n, 3)

print("")
print("== level band widens across sightings ==")
CBH.db.cardCatalogue = {}
LEVEL = 68; CBH.RecordCard("Collect 40 Icethorn.")
LEVEL = 74; CBH.RecordCard("Collect 40 Icethorn.")
LEVEL = 71; CBH.RecordCard("Collect 40 Icethorn.")
local e = CBH.db.cardCatalogue["Collect 40 Icethorn."]
check("low end", e.lo, 68)
check("high end", e.hi, 74)

print("")
print("== catalogue rides along with the export ==")
CBH.db.learned, CBH.db.learnedKills = {}, {}
CBH.Export()
check("exports on catalogue alone", CallboardHunterExport ~= nil, true)
check("  ...carrying the cards", CallboardHunterExport.cards["Collect 40 Icethorn."].n, 3)
CBH.db.cardCatalogue = {}
CallboardHunterExport = nil
CBH.Export()
check("truly empty still declines", CallboardHunterExport, nil)

print("")
print("== catalogue buckets by objective type ==")
CBH.db.cardCatalogue = {}
CBH.RecordCard("Kill 10 Azure Manashaper in Crystalsong Forest.")
CBH.RecordCard("Slay Ingvar the Plunderer in Utgarde Keep.")
CBH.RecordCard("Wanted: Festergut")
CBH.RecordCard("Collect 40 Icethorn.")
local C = CBH.db.cardCatalogue
check("open world tagged", C["Kill 10 Azure Manashaper in Crystalsong Forest."].kind, "open world")
check("dungeon tagged", C["Slay Ingvar the Plunderer in Utgarde Keep."].kind, "dungeon")
check("raid tagged", C["Wanted: Festergut"].kind, "raid")
check("collection tagged", C["Collect 40 Icethorn."].kind, "collection")
-- entries recorded before types existed get classified on read, no migration
C["Legacy card in Icecrown"] = { n = 1 }
PRINTED = {}
CBH.Catalogue()
check("legacy entry classified on read", C["Legacy card in Icecrown"].kind ~= nil, true)
check("summary names the buckets", string.find(PRINTED[1] or "", "raid 1") ~= nil, true)

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

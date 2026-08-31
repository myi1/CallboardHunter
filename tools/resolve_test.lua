-- Routing-table checks against the REAL SpawnDB.lua (was luaparse-based; now
-- runs the actual Lua so a refactor of the tables cannot silently bypass it).
local ADDON = ADDON_DIR
function GetMapContinents() return "Eastern Kingdoms", "Kalimdor", "Outland", "Northrend" end
function GetMapZones(c)
   if c == 4 then return "Borean Tundra", "Dragonblight", "Grizzly Hills", "Howling Fjord",
      "Icecrown", "Sholazar Basin", "The Storm Peaks", "Zul'Drak", "Wintergrasp", "Dalaran",
      "Crystalsong Forest" end
   if c == 2 then return "Winterspring", "Nagrand", "Tanaris", "Silithus", "Teldrassil",
      "Mulgore", "Azuremyst Isle", "Ammen Vale", "Valley of Trials" end
   if c == 3 then return "Zangarmarsh", "Netherstorm", "Shadowmoon Valley", "Terokkar Forest",
      "Hellfire Peninsula", "Blade's Edge Mountains", "Nagrand", "Isle of Quel'Danas" end
   return "Alterac Mountains", "Western Plaguelands", "Elwynn Forest", "Coldridge Valley",
      "Northshire Valley", "Deathknell", "Eastern Plaguelands", "Dun Morogh", "Tirisfal Glades"
end
CallboardHunter = { SpawnDB = {} }
local CBH = CallboardHunter
CBH.db = { learned = {}, cardZones = {} }
local c, e = loadfile(ADDON .. "/SpawnDB.lua")
if not c then error("load SpawnDB: " .. tostring(e)) end
c()
local S = CBH.SpawnDB

local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label,
      tostring(got), ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end
local function zone(t) local z = S.ZoneForTargetText(t) return z end

print("== dungeon / boss routing (derived DUNGEON_ZONE) ==")
check("Ingvar -> Howling Fjord", zone("Ingvar the Plunderer slain: 0/1"), "Howling Fjord")
check("Utgarde Pinnacle -> Howling Fjord", zone("Assault on Utgarde Pinnacle"), "Howling Fjord")
check("Anub'arak -> Dragonblight", zone("Anub'arak slain: 0/1"), "Dragonblight")
check("Moragg -> Dalaran", zone("Moragg slain: 0/1"), "Dalaran")
check("Krick -> Icecrown", zone("Ick and Krick slain: 0/1"), "Icecrown")
check("Mal'Ganis -> Tanaris", zone("Mal'Ganis slain: 0/1"), "Tanaris")
check("alias: The Old Kingdom -> Dragonblight", zone("The Old Kingdom"), "Dragonblight")
check("alias: The Eye -> Netherstorm", zone("Sunseeker in The Eye"), "Netherstorm")
check("hub: Ulduar -> The Storm Peaks", zone("Flame Leviathan in Ulduar"), "The Storm Peaks")
check("known rare -> its zone", zone("Vigdis the War Maiden slain: 0/3"), "Howling Fjord")
check("curated target -> Nagrand", zone("Banthar slain: 0/1"), "Nagrand")
-- Classic Stratholme is known now (EPL); longest-match keeps it distinct from
-- the Culling of Stratholme, which is verified in the Classic section below.
check("bare Stratholme -> Eastern Plaguelands", zone("Baron Rivendare in Stratholme"), "Eastern Plaguelands")
check("unknown -> nil", zone("Nobody slain: 0/1"), nil)

print("")
print("== the Alterac phantom must be unreachable ==")
local hits = 0
for _, t in ipairs({ "Ingvar the Plunderer slain: 0/1", "Anub'arak slain: 0/1",
                     "Kreug Oathbreaker slain: 0/1", "Nobody slain: 0/1" }) do
   if zone(t) == "Alterac Mountains" then hits = hits + 1 end
end
check("no objective routes to Alterac Mountains", hits, 0)

print("")
print("== dungeon matching (new: which dungeon am I standing in?) ==")
check("instance named in card", S.TextMatchesDungeon("Slay Ingvar the Plunderer in Utgarde Keep.", "Utgarde Keep"), true)
check("boss of that dungeon", S.TextMatchesDungeon("Slay Ingvar the Plunderer.", "Utgarde Keep"), true)
check("boss of a DIFFERENT dungeon in same zone",
   S.TextMatchesDungeon("Slay King Ymiron.", "Utgarde Keep"), false)
check("unrelated card", S.TextMatchesDungeon("Kill 10 Azure Manashaper in Crystalsong Forest.", "Utgarde Keep"), false)
check("alias matches", S.TextMatchesDungeon("Slay Herald Volazj in The Old Kingdom.", "Ahn'kahet"), true)
check("unknown dungeon -> false", S.TextMatchesDungeon("anything", "Not A Dungeon"), false)
check("nil-safe", S.TextMatchesDungeon(nil, "Utgarde Keep"), false)

print("")
print("== raids are first-class now (bosses, not just hub names) ==")
check("Festergut -> Icecrown", zone("Wanted: Festergut"), "Icecrown")
check("Kel'Thuzad -> Dragonblight", zone("Slay Kel'Thuzad in Naxxramas."), "Dragonblight")
check("Yogg-Saron -> The Storm Peaks", zone("Defeat Yogg-Saron in Ulduar."), "The Storm Peaks")
check("Archavon -> Wintergrasp", zone("Wanted: Archavon the Stone Watcher"), "Wintergrasp")
check("Malygos -> Borean Tundra", zone("Slay Malygos."), "Borean Tundra")

print("")
print("== instance + kind, longest name wins ==")
local i, k = S.InstanceInText("Wanted: Loken")
check("Loken is Halls of Lightning", i, "Halls of Lightning")
check("  ...a dungeon", k, "dungeon")
i, k = S.InstanceInText("Slay Festergut in Icecrown Citadel.")
check("ICC beats a stray 'Icecrown'", i, "Icecrown Citadel")
check("  ...a raid", k, "raid")
check("no instance -> nil", (S.InstanceInText("Collect 40 Icethorn.")), nil)

print("")
print("== card type classification ==")
check("dungeon card", S.ClassifyCard("Slay Ingvar the Plunderer in Utgarde Keep."), "dungeon")
check("raid card", S.ClassifyCard("Wanted: Sindragosa"), "raid")
check("collection card", S.ClassifyCard("Collect 40 Icethorn."), "collection")
check("open-world card", S.ClassifyCard("Kill 10 Azure Manashaper in Crystalsong Forest."), "open world")
check("open-world slain card", S.ClassifyCard("Banthar slain: 0/1"), "open world")
check("unrecognised -> other", S.ClassifyCard("Something entirely new"), "other")
check("empty -> other", S.ClassifyCard(""), "other")

print("")
print("== Outland instances (reported 2026-08-30) ==")
check("Kelidan the Breaker -> Hellfire Peninsula",
   zone("Purge the Darkness: Kelidan the Breaker"), "Hellfire Peninsula")
check("  ...Blizzard's spelling too",
   zone("Slay Keli'dan the Breaker in The Blood Furnace."), "Hellfire Peninsula")
check("Blood Furnace by name", zone("Assault on The Blood Furnace"), "Hellfire Peninsula")
check("Murmur -> Terokkar Forest", zone("Wanted: Murmur"), "Terokkar Forest")
check("Warp Splinter -> Netherstorm", zone("Slay Warp Splinter."), "Netherstorm")
check("Quagmirran -> Zangarmarsh", zone("Wanted: Quagmirran"), "Zangarmarsh")
check("Illidan -> Shadowmoon Valley", zone("Defeat Illidan Stormrage."), "Shadowmoon Valley")
check("Gruul -> Blade's Edge", zone("Slay Gruul the Dragonkiller."), "Blade's Edge Mountains")
local i, k = S.InstanceInText("Purge the Darkness: Kelidan the Breaker")
check("  identified as Blood Furnace", i, "The Blood Furnace")
check("  ...a dungeon", k, "dungeon")

print("")
print("== Classic instances ==")
check("Edwin VanCleef -> Westfall", zone("Wanted: Edwin VanCleef"), "Westfall")
check("Mekgineer Thermaplugg -> Dun Morogh", zone("Slay Mekgineer Thermaplugg."), "Dun Morogh")
check("Ragnaros -> Searing Gorge", zone("Defeat Ragnaros in Molten Core."), "Searing Gorge")
check("Stratholme (Classic) -> EPL", zone("Assault on Stratholme"), "Eastern Plaguelands")
check("  ...but Culling of Stratholme still Tanaris",
   zone("The Culling of Stratholme"), "Tanaris")

print("")
print("== target extraction (prefixes are decorative) ==")
check("strips a flavour prefix", S.TargetOf("Dungeon Crawl: Loken"), "Loken")
check("same target, other prefix", S.TargetOf("Wanted: Loken"), "Loken")
check("multi-word target", S.TargetOf("Bulk Order: Eternal Earth"), "Eternal Earth")
check("colon inside the target survives", S.TargetOf("Wanted: SI:7 Insignia"), "SI:7 Insignia")
check("no colon -> whole title", S.TargetOf("Beasts of the Plains"), "Beasts of the Plains")
check("description line -> nil", S.TargetOf("Collect 20 Eternal Air."), nil)
check("empty -> nil", S.TargetOf(""), nil)
check("nil -> nil", S.TargetOf(nil), nil)
check("bare colon -> nil", S.TargetOf(":"), nil)
check("colon with nothing after it -> nil", S.TargetOf("Wanted:"), nil)
check("colon with only trailing space -> nil", S.TargetOf("Wanted: "), nil)
check("trims whitespace around a whole title", S.TargetOf("  Loken  "), "Loken")
check("trims whitespace around an extracted target", S.TargetOf("Wanted:   Loken   "), "Loken")

print("")
print("== bundled quest database ==")
local byTarget = {}
for _, q in ipairs(S.QUESTS) do byTarget[q.target] = q end
check("has exactly the 63 seed rows", #S.QUESTS, 63)
check("Loken is present", byTarget["Loken"] ~= nil, true)
check("  ...with a level band", byTarget["Loken"].hi ~= nil, true)
check("Azure Scalebane is level 80", byTarget["Azure Scalebane"].hi, 80)
check("every row has a target", (function()
   for _, q in ipairs(S.QUESTS) do
      if type(q.target) ~= "string" or q.target == "" then return false end
   end
   return true
end)(), true)

print("")
print("== bundled card-zone defaults (fresh install has no card history) ==")
-- Reported 2026-08: a new install's cardZones is empty, so a Wintergrasp
-- objective (Earthbound Revenant) fell through to the POI sweep and ported
-- the player to Winterspring instead. S.CARD_ZONES ships the maintainer's own
-- vetted history so a fresh install starts with the same answer.
check("the bundle has exactly 77 entries", (function()
   local n2 = 0
   for _ in pairs(S.CARD_ZONES) do n2 = n2 + 1 end
   return n2
end)(), 77)
CBH.db.cardZones = {}
check("bundled mob resolves with no card history (the reported case)",
   S.CardZoneFor("Earthbound Revenant"), "Wintergrasp")
CBH.db.cardZones["Earthbound Revenant"] = "Icecrown"
check("the player's own card wins over the bundle",
   S.CardZoneFor("Earthbound Revenant"), "Icecrown")
CBH.db.cardZones = {}
check("a mob in neither table resolves to nil (no accidental catch-all)",
   S.CardZoneFor("Nobody Ever Vetted This Mob"), nil)
print("")
print("== none of the vetting pass's dropped keys reappear ==")
check("'Beast Kill in <Zone>' objective phrasings are not bundled keys",
   S.CARD_ZONES["Beast Kill in Wintergrasp"], nil)
check("the generic 'Beasts' token is not a bundled key", S.CARD_ZONES["Beasts"], nil)
check("the generic 'Rare' token is not a bundled key", S.CARD_ZONES["Rare"], nil)
check("Archavon (SpawnDB says Wintergrasp, the dropped row claimed Dragonblight)",
   S.CARD_ZONES["Archavon the Stone Watcher"], nil)
print("")
print("== every bundled zone is checked against KnownMapZone before it is served ==")
local validCount, badKeys = 0, {}
for mob, z in pairs(S.CARD_ZONES) do
   if S.KnownMapZone(z) then validCount = validCount + 1
   else table.insert(badKeys, mob) end
end
table.sort(badKeys)
check("74 of 77 bundled zones are real, routable outdoor zones", validCount, 74)
-- These 3 were harvested verbatim from real "Kill N X in <name>" card text that
-- named the instance rather than its outdoor zone (see SpawnDB.DUNGEONS: The
-- Oculus/Coilfang Reservoir/Tempest Keep are dungeons/raids, not map zones).
-- Kept in the table per the vetting pass rather than silently dropped, but
-- CardZoneFor's KnownMapZone check means they can never be handed back as a
-- routing answer - a data error fails loudly here instead of shipping silently.
check("the only invalid rows are the 3 known instance-named exceptions",
   table.concat(badKeys, ", "),
   "Centrifuge Construct, Coilfang Myrmidon, Sunseeker Channeler")
check("an invalid bundled zone is never surfaced by CardZoneFor",
   S.CardZoneFor("Centrifuge Construct"), nil)

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

-- CallboardHunter SpawnDB: static rare spawn points, learned layer, zone sizes.
local CBH = CallboardHunter
local SpawnDB = CBH.SpawnDB

-- Points are normalized 0-1 map coordinates (wowhead coord / 100), representative
-- patrol locations. Precision goal: get the player into detection range; the
-- learned layer refines over time. NPC IDs verified against RSO-SpawnData.lua
-- (note: RSO lists Doomsayer Jurim as 18689, duplicating Crippler; 18686 is correct).
-- [zoneKey (GetRealZoneText)] = { [npcID] = { name = "...", points = { {x,y}, ... } } }
local STATIC = {
   ["Sholazar Basin"] = {
      [32517] = { name = "Loque'nahak", points = { {0.31,0.58}, {0.49,0.79}, {0.68,0.78}, {0.24,0.71}, {0.35,0.37}, {0.59,0.52} } },
      [32481] = { name = "Aotona", points = { {0.37,0.45}, {0.47,0.55}, {0.56,0.42} } },
      [32485] = { name = "King Krush", points = { {0.26,0.54}, {0.40,0.67}, {0.52,0.72} } },
   },
   ["Icecrown"] = {
      [32495] = { name = "Hildana Deathstealer", points = { {0.55,0.68}, {0.61,0.62}, {0.49,0.73} } },
      [32487] = { name = "Putridus the Ancient", points = { {0.57,0.44}, {0.64,0.52}, {0.70,0.60} } },
      [32501] = { name = "High Thane Jorfus", points = { {0.45,0.70}, {0.52,0.78}, {0.60,0.74} } },
   },
   ["Borean Tundra"] = {
      [32358] = { name = "Fumblub Gearwind", points = { {0.55,0.32}, {0.62,0.40}, {0.51,0.45} } },
      [32361] = { name = "Icehorn", points = { {0.68,0.22}, {0.73,0.30}, {0.64,0.35} } },
      [32357] = { name = "Old Crystalbark", points = { {0.26,0.35}, {0.32,0.42}, {0.22,0.47} } },
   },
   ["Dragonblight"] = {
      [32409] = { name = "Crazed Indu'le Survivor", points = { {0.30,0.60}, {0.38,0.68}, {0.25,0.70} } },
      [32417] = { name = "Scarlet Highlord Daion", points = { {0.75,0.52}, {0.82,0.58}, {0.78,0.64} } },
      [32400] = { name = "Tukemuth", points = { {0.48,0.48}, {0.55,0.55}, {0.42,0.55} } },
   },
   ["Grizzly Hills"] = {
      [32422] = { name = "Grocklar", points = { {0.35,0.45}, {0.42,0.52}, {0.30,0.55} } },
      [32429] = { name = "Seething Hate", points = { {0.60,0.35}, {0.67,0.42}, {0.55,0.45} } },
      [32438] = { name = "Syreian the Bonecarver", points = { {0.45,0.65}, {0.52,0.72}, {0.40,0.75} } },
   },
   ["Howling Fjord"] = {
      [32398] = { name = "King Ping", points = { {0.28,0.42}, {0.34,0.50}, {0.24,0.52} } },
      [32377] = { name = "Perobas the Bloodthirster", points = { {0.55,0.25}, {0.62,0.32}, {0.50,0.35} } },
      [32386] = { name = "Vigdis the War Maiden", points = { {0.65,0.55}, {0.72,0.62}, {0.60,0.65} } },
   },
   ["The Storm Peaks"] = {
      [32500] = { name = "Dirkee", points = { {0.40,0.65}, {0.47,0.72}, {0.35,0.75} } },
      [32491] = { name = "Time-Lost Proto Drake", points = { {0.35,0.72}, {0.43,0.80}, {0.29,0.65}, {0.50,0.85} } },
      [32630] = { name = "Vyragosa", points = { {0.35,0.72}, {0.43,0.80}, {0.29,0.65}, {0.50,0.85} } },
   },
   ["Zul'Drak"] = {
      [33776] = { name = "Gondria", points = { {0.60,0.60}, {0.67,0.68}, {0.55,0.70}, {0.72,0.55} } },
      [32471] = { name = "Griegen", points = { {0.20,0.65}, {0.27,0.72}, {0.15,0.72} } },
      [32475] = { name = "Terror Spinner", points = { {0.45,0.55}, {0.52,0.62}, {0.40,0.65} } },
      [32447] = { name = "Zul'drak Sentinel", points = { {0.35,0.75}, {0.42,0.82}, {0.30,0.82} } },
   },
   ["Hellfire Peninsula"] = {
      [18679] = { name = "Vorakem Doomspeaker", points = { {0.30,0.45}, {0.40,0.55}, {0.50,0.40} } },
      [18678] = { name = "Fulgorge", points = { {0.40,0.50}, {0.55,0.40}, {0.33,0.62} } },
      [18677] = { name = "Mekthorg the Wild", points = { {0.55,0.45}, {0.62,0.55}, {0.47,0.60} } },
   },
   ["Zangarmarsh"] = {
      [18680] = { name = "Marticar", points = { {0.25,0.45}, {0.35,0.55}, {0.45,0.45} } },
      [18682] = { name = "Bog Lurker", points = { {0.30,0.60}, {0.45,0.65}, {0.60,0.55} } },
      [18681] = { name = "Coilfang Emissary", points = { {0.25,0.35}, {0.35,0.30}, {0.45,0.35} } },
   },
   ["Terokkar Forest"] = {
      [18689] = { name = "Crippler", points = { {0.35,0.20}, {0.45,0.25}, {0.55,0.20} } },
      [18686] = { name = "Doomsayer Jurim", points = { {0.40,0.40}, {0.50,0.50}, {0.60,0.45} } },
      [18685] = { name = "Okrek", points = { {0.30,0.55}, {0.40,0.65}, {0.50,0.60} } },
   },
   ["Nagrand"] = {
      [18683] = { name = "Voidhunter Yar", points = { {0.35,0.40}, {0.45,0.35}, {0.55,0.40} } },
      [17144] = { name = "Goretooth", points = { {0.40,0.60}, {0.50,0.65}, {0.60,0.60} } },
      [18684] = { name = "Bro'Gaz the Clanless", points = { {0.35,0.50}, {0.45,0.55}, {0.55,0.50} } },
   },
   ["Blade's Edge Mountains"] = {
      [18690] = { name = "Morcrush", points = { {0.50,0.60}, {0.60,0.55}, {0.40,0.65} } },
      [18693] = { name = "Speaker Mar'grom", points = { {0.30,0.60}, {0.40,0.70}, {0.50,0.65} } },
      [18692] = { name = "Hemathion", points = { {0.45,0.40}, {0.55,0.35}, {0.65,0.45} } },
   },
   ["Netherstorm"] = {
      [20932] = { name = "Nuramoc", points = { {0.45,0.35}, {0.55,0.45}, {0.65,0.35}, {0.35,0.55} } },
      [18697] = { name = "Chief Engineer Lorthander", points = { {0.30,0.50}, {0.40,0.55}, {0.50,0.50} } },
      [18698] = { name = "Ever-Core the Punisher", points = { {0.55,0.60}, {0.65,0.65}, {0.45,0.70} } },
   },
   ["Shadowmoon Valley"] = {
      [18694] = { name = "Collidus the Warp-Watcher", points = { {0.45,0.45}, {0.55,0.50}, {0.65,0.45}, {0.35,0.55} } },
      [18696] = { name = "Kraator", points = { {0.50,0.30}, {0.60,0.35}, {0.70,0.30} } },
      [18695] = { name = "Ambassador Jerrikar", points = { {0.40,0.60}, {0.50,0.65}, {0.60,0.60} } },
   },
}

-- Astrolabe-era zone dimensions in yards: [zoneKey] = {width, height}
local ZONE_SIZE = {
   ["Sholazar Basin"] = {4356.25, 2904.17}, ["Icecrown"] = {6270.83, 4181.25},
   ["Borean Tundra"] = {5764.58, 3843.75}, ["Dragonblight"] = {5608.33, 3739.58},
   ["Grizzly Hills"] = {5250.00, 3500.00}, ["Howling Fjord"] = {6045.83, 4031.25},
   ["The Storm Peaks"] = {7112.50, 4741.67}, ["Zul'Drak"] = {4993.75, 3329.17},
   ["Hellfire Peninsula"] = {5164.58, 3443.75}, ["Zangarmarsh"] = {5027.08, 3352.08},
   ["Terokkar Forest"] = {5400.00, 3600.00}, ["Nagrand"] = {5525.00, 3683.33},
   ["Blade's Edge Mountains"] = {5425.00, 3616.67}, ["Netherstorm"] = {5575.00, 3716.67},
   ["Shadowmoon Valley"] = {5500.00, 3666.67},
}

SpawnDB.ZONES = {}
for zone in pairs(STATIC) do SpawnDB.ZONES[zone] = true end
for zone in pairs(ZONE_SIZE) do SpawnDB.ZONES[zone] = true end

-- Named kill targets whose quest text does NOT name an outdoor zone, mapped to
-- the outdoor zone the port should route to. A callboard kill like "Ingvar the
-- Plunderer slain: 0/1" (the Utgarde Keep end boss, in Howling Fjord) or
-- "Banthar slain: 0/1" (Nagrand) names neither its zone nor a rare we already
-- have points for, so ZoneFromQuestText/cardZones/learnedKills all miss and it
-- used to fall through to a stale POI sweep that confidently mis-picked the
-- wrong zone ("Alterac Mountains" for Ingvar; the current zone for Banthar).
-- Mapping the dungeon/boss/target name to its zone routes to that zone's
-- nearest unlocked checkpoint instead. Keys are matched as lowercase substrings
-- of the quest title/objective text.
--
-- DUNGEON_ZONE flags its zone as "isDungeon": there is no OUTDOOR quest POI for
-- an instance boss to chase, so the port routes by zone (nearest checkpoint)
-- rather than trying to read a POI that lives inside the instance. Dungeons
-- whose name already contains their zone (e.g. "Icecrown Citadel" contains
-- "Icecrown") need no entry - the zone scan catches those first. A few boss
-- names are shared with a raid (e.g.Anub'arak: Azjol-Nerub AND Trial of the
-- Crusader; Prince Taldaram: Ahn'kahet AND Icecrown Citadel) - these map to
-- their 5-man dungeon, the far likelier callboard source; if you ever get the
-- raid version, "/cbh portvia <zone>" overrides it for that objective.
-- Dungeons, their containing zone, and their bosses. Source of truth for two
-- different questions, which is why it is shaped this way:
--   * routing  - "this objective names Ingvar, where do I port?"  -> zone
--   * matching - "is this card for the dungeon I am standing in?" -> bosses
-- A flat name->zone map cannot answer the second: Utgarde Keep and Utgarde
-- Pinnacle both map to Howling Fjord, so the zone does not identify the dungeon.
-- DUNGEON_ZONE below is derived from this, so routing behaviour is unchanged.
local DUNGEONS = {
   ["Utgarde Keep"] = { zone = "Howling Fjord", bosses = {
      "Prince Keleseth", "Skarvald", "Dalronn", "Ingvar the Plunderer" } },
   ["Utgarde Pinnacle"] = { zone = "Howling Fjord", bosses = {
      "Svala Sorrowgrave", "Gortok Palehoof", "Skadi the Ruthless", "King Ymiron" } },
   ["The Nexus"] = { zone = "Borean Tundra", bosses = {
      "Grand Magus Telestra", "Anomalus", "Ormorok", "Keristrasza" } },
   ["The Oculus"] = { zone = "Borean Tundra", bosses = {
      "Drakos", "Varos Cloudstrider", "Mage-Lord Urom", "Ley-Guardian Eregos" } },
   ["Azjol-Nerub"] = { zone = "Dragonblight", bosses = {
      "Krik'thir", "Hadronox", "Anub'arak" } },
   ["Ahn'kahet"] = { zone = "Dragonblight", aliases = { "The Old Kingdom" }, bosses = {
      "Elder Nadox", "Prince Taldaram", "Jedoga Shadowseeker", "Herald Volazj" } },
   ["Drak'Tharon Keep"] = { zone = "Grizzly Hills", bosses = {
      "Trollgore", "Novos the Summoner", "King Dred", "The Prophet Tharon'ja" } },
   ["Gundrak"] = { zone = "Zul'Drak", bosses = {
      "Slad'ran", "Drakkari Colossus", "Moorabi", "Gal'darah", "Eck the Ferocious" } },
   ["Halls of Stone"] = { zone = "The Storm Peaks", bosses = {
      "Krystallus", "Maiden of Grief", "Sjonnir the Ironshaper" } },
   ["Halls of Lightning"] = { zone = "The Storm Peaks", bosses = {
      "General Bjarngrim", "Volkhan", "Ionar", "Loken" } },
   ["The Violet Hold"] = { zone = "Dalaran", bosses = {
      "Cyanigosa", "Erekem", "Xevozz", "Zuramat", "Ichoron", "Moragg", "Lavanthor" } },
   ["Trial of the Champion"] = { zone = "Icecrown", bosses = {
      "Eadric the Pure", "Argent Confessor Paletress", "The Black Knight" } },
   ["The Forge of Souls"] = { zone = "Icecrown", bosses = {
      "Bronjahm", "Devourer of Souls" } },
   ["Pit of Saron"] = { zone = "Icecrown", bosses = {
      "Forgemaster Garfrost", "Krick", "Scourgelord Tyrannus" } },
   ["Halls of Reflection"] = { zone = "Icecrown", bosses = { "Falric", "Marwyn" } },
   ["The Culling of Stratholme"] = { zone = "Tanaris", aliases = { "Culling of Stratholme" },
      bosses = { "Salramm the Fleshcrafter", "Chrono-Lord Epoch", "Mal'Ganis",
                 "Meathook", "Infinite Corruptor" } },
   -- Raid/instance hubs that appear in real callboard cards but are not map
   -- zones, so the world map can never be pointed at them directly.
   ["Coilfang Reservoir"] = { zone = "Zangarmarsh", aliases = { "Serpentshrine Cavern" }, bosses = {} },
   ["Tempest Keep"] = { zone = "Netherstorm", aliases = { "The Eye" }, bosses = {} },
   ["Ulduar"] = { zone = "The Storm Peaks", bosses = {} },
   ["Naxxramas"] = { zone = "Dragonblight", bosses = {} },
   ["Vault of Archavon"] = { zone = "Wintergrasp", bosses = {} },
   ["Black Temple"] = { zone = "Shadowmoon Valley", bosses = {} },
}

-- Derived: every dungeon name, alias and boss name -> its zone. Keys are matched
-- as lowercase substrings of quest title/objective text. A few boss names are
-- shared with a raid (Anub'arak: Azjol-Nerub AND Trial of the Crusader; Prince
-- Taldaram: Ahn'kahet AND Icecrown Citadel) - these resolve to their 5-man
-- dungeon, the likelier callboard source; "/cbh portvia <zone>" overrides it.
-- Dungeons whose name already contains their zone (e.g. "Icecrown Citadel"
-- contains "Icecrown") need no entry - the zone scan catches those first.
local DUNGEON_ZONE = {}
for dungeon, info in pairs(DUNGEONS) do
   DUNGEON_ZONE[string.lower(dungeon)] = info.zone
   for _, a in ipairs(info.aliases or {}) do DUNGEON_ZONE[string.lower(a)] = info.zone end
   for _, b in ipairs(info.bosses or {}) do DUNGEON_ZONE[string.lower(b)] = info.zone end
end

SpawnDB.DUNGEONS = DUNGEONS

-- Does this text name the dungeon itself, or one of its bosses? Used to decide
-- whether a callboard card belongs to the instance the player is standing in.
function SpawnDB.TextMatchesDungeon(text, dungeon)
   if not text or not dungeon then return false end
   local info = DUNGEONS[dungeon]
   local lt, ld = string.lower(text), string.lower(dungeon)
   if string.find(lt, ld, 1, true) then return true end
   if not info then return false end
   for _, a in ipairs(info.aliases or {}) do
      if string.find(lt, string.lower(a), 1, true) then return true end
   end
   for _, b in ipairs(info.bosses or {}) do
      if string.find(lt, string.lower(b), 1, true) then return true end
   end
   return false
end

-- Outdoor callboard targets whose quest text names neither an outdoor zone nor a
-- rare we already have points for. Extend as new ones are reported.
local TARGET_ZONE = {
   ["banthar"] = "Nagrand", -- "Steel Yourself: Banthar" (reported 2026-08-28)
   -- "Bring Me the Head of Ragemane" (reported 2026-08-29). The quest-log zone
   -- header resolves this on its own now, but keep the entry as a backstop in
   -- case a server groups its quests under a custom (non-zone) header.
   ["ragemane"] = "Zul'Drak",
}

-- Objectives that must route to a SPECIFIC checkpoint, not merely the nearest one
-- in the zone. [substring] = { zone = <map the checkpoint is on>, via = <checkpoint
-- name> }. The zone is whichever world map that checkpoint appears on. Example:
-- the "Flame Revenant" callboard quest ("Thinning the Herd in Winterspring")
-- ports to the Fordragon Hold checkpoint, which lives on the DRAGONBLIGHT map
-- (not on Winterspring, and not to whatever Dragonblight checkpoint is nearest).
-- Reported by keepsy 2026-08-28. `via` is matched against checkpoint names the
-- same way /cbh portvia is, so a partial name is fine.
local TARGET_CHECKPOINT = {
   ["flame revenant"] = { zone = "Dragonblight", via = "Fordragon Hold" },
}

-- Every rare we have static points for, keyed by lowercase name, so an objective
-- that only says "<Rare> slain: n/m" resolves to its zone without a card.
local MOB_ZONE = {}
for zone, mobs in pairs(STATIC) do
   for _, mob in pairs(mobs) do
      if mob.name then MOB_ZONE[string.lower(mob.name)] = zone end
   end
end

SpawnDB.DUNGEON_ZONE = DUNGEON_ZONE

-- Resolve a quest's title/objective text to a routing zone by the dungeon/boss,
-- callboard target, or known rare it names. Returns (zone, isDungeon) or nil.
-- The outdoor-zone scan in ZoneFromQuestText runs first and wins; this is the
-- fallback for text that names only an instance/target, not a zone.
function SpawnDB.ZoneForTargetText(text)
   if not text then return end
   local lt = string.lower(text)
   -- Curated objective -> specific-checkpoint overrides win (returns a 3rd value,
   -- the checkpoint name to force on that zone's map).
   for key, m in pairs(TARGET_CHECKPOINT) do
      if string.find(lt, key, 1, true) then return m.zone, false, m.via end
   end
   for key, zone in pairs(DUNGEON_ZONE) do
      if string.find(lt, key, 1, true) then return zone, true end
   end
   for key, zone in pairs(TARGET_ZONE) do
      if string.find(lt, key, 1, true) then return zone, false end
   end
   for key, zone in pairs(MOB_ZONE) do
      if string.find(lt, key, 1, true) then return zone, false end
   end
   -- Rares learned by the detector over time (name-keyed or npcID-keyed).
   local learned = CBH.db and CBH.db.learned
   if learned then
      for zone, mobs in pairs(learned) do
         for mobKey, mob in pairs(mobs) do
            local nm = (type(mobKey) == "string" and mobKey) or (mob and mob.name)
            if nm and string.find(lt, string.lower(nm), 1, true) then return zone, false end
         end
      end
   end
end

-- Every real world-map zone name, cached. SpawnDB.ZONES only covers the zones we
-- ship rare data for (15 of them), but objectives happen anywhere - "Beast Kill
-- in Wintergrasp: 0/10" could not be matched at all because Wintergrasp has no
-- spawn table. Recognising a zone by name and having spawn data for it are two
-- different questions, and conflating them is what made those objectives
-- unroutable.
local mapZones, mapZonesByLen
local function BuildMapZones()
   if mapZones then return end
   mapZones, mapZonesByLen = {}, {}
   if not (GetMapContinents and GetMapZones) then return end
   for c = 1, select("#", GetMapContinents()) do
      for _, zn in ipairs({ GetMapZones(c) }) do
         if zn and zn ~= "" and not mapZones[string.lower(zn)] then
            mapZones[string.lower(zn)] = zn
            mapZonesByLen[#mapZonesByLen + 1] = zn
         end
      end
   end
   -- Longest first: so "Stormwind City" wins over "Stormwind" and a partial name
   -- can never shadow the fuller one. Also makes the result deterministic, which
   -- a pairs() scan over a hash was not.
   table.sort(mapZonesByLen, function(a, b) return string.len(a) > string.len(b) end)
end

-- Exact name -> properly cased zone, or nil. Used to sanity-check quest-log
-- headers, which can also be categories ("Dungeons") rather than places.
function SpawnDB.KnownMapZone(name)
   if not name or name == "" then return nil end
   BuildMapZones()
   return mapZones[string.lower(name)]
end

-- The longest real zone name mentioned anywhere in the text, or nil.
function SpawnDB.FindMapZoneIn(text)
   if not text or text == "" then return nil end
   BuildMapZones()
   local lt = string.lower(text)
   for _, zn in ipairs(mapZonesByLen) do
      if string.find(lt, string.lower(zn), 1, true) then return zn end
   end
   return nil
end

function SpawnDB.GetZoneSize(zoneKey)
   local s = ZONE_SIZE[zoneKey]
   if s then return s[1], s[2] end
end

function SpawnDB.IsKnownRare(npcID, name)
   for _, mobs in pairs(STATIC) do
      if npcID and mobs[npcID] then return true end
      if name then
         for _, mob in pairs(mobs) do
            if mob.name == name then return true end
         end
      end
   end
   local learned = CBH.db and CBH.db.learned
   if learned then
      for _, mobs in pairs(learned) do
         if (npcID and mobs[npcID]) or (name and mobs[name]) then return true end
      end
   end
   return false
end

function SpawnDB.Learn(zoneKey, name, npcID, x, y)
   if not (zoneKey and x and y) or not CBH.db then return end
   local learned = CBH.db.learned
   learned[zoneKey] = learned[zoneKey] or {}
   local mobKey = npcID or name
   if not mobKey then return end
   local entry = learned[zoneKey][mobKey]
   if not entry then
      entry = { name = name, points = {} }
      learned[zoneKey][mobKey] = entry
   end
   local w, h = SpawnDB.GetZoneSize(zoneKey)
   for _, p in ipairs(entry.points) do
      local dx, dy = (p[1] - x), (p[2] - y)
      if w and h then dx, dy = dx * w, dy * h else dx, dy = dx * 1000, dy * 700 end
      if (dx * dx + dy * dy) < 2500 then      -- within 50yd of a known point
         -- Corroboration: a repeat sighting bumps the point's count instead of
         -- being discarded. That count is what makes shared data mergeable -
         -- a spot seen 6 times outranks one person's single glimpse of a
         -- patrolling rare. Points are {x, y, n}; legacy 2-element points read
         -- as n = 1, so old databases need no migration.
         p[3] = (p[3] or 1) + 1
         return
      end
   end
   table.insert(entry.points, { x, y, 1 })
end

-- Record where a counted callboard kill happened (dedup 40yd, keep last 30).
function SpawnDB.LearnKill(zoneKey, name, x, y)
   if not (zoneKey and name and x and y) or not CBH.db then return end
   local lk = CBH.db.learnedKills
   lk[zoneKey] = lk[zoneKey] or {}
   local list = lk[zoneKey][name]
   if not list then list = {}; lk[zoneKey][name] = list end
   local w, h = SpawnDB.GetZoneSize(zoneKey)
   for _, p in ipairs(list) do
      local dx, dy = (p[1] - x), (p[2] - y)
      if w and h then dx, dy = dx * w, dy * h else dx, dy = dx * 1000, dy * 700 end
      if (dx * dx + dy * dy) < 1600 then      -- within 40yd of a known point
         p[3] = (p[3] or 1) + 1               -- corroboration count (see Learn)
         return
      end
   end
   table.insert(list, { x, y, 1 })
   if #list > 30 then table.remove(list, 1) end
end

-- Learned hotspots in this zone for objectives that are still incomplete.
function SpawnDB.GetFarmPoints(zoneKey)
   local out = {}
   local mobs = CBH.db and CBH.db.learnedKills and CBH.db.learnedKills[zoneKey]
   if not mobs then return out end
   local kos = CBH.killObjectives or {}
   for name, list in pairs(mobs) do
      local ko = kos[name]
      if ko and (not ko.need or (ko.have or 0) < ko.need) then
         for i, p in ipairs(list) do
            table.insert(out, { x = p[1], y = p[2], name = name, farm = true,
               key = "farm:" .. zoneKey .. ":" .. name .. ":" .. i })
         end
      end
   end
   return out
end

function SpawnDB.GetPoints(zoneKey)
   local out = {}
   local function addFrom(src)
      local mobs = src and src[zoneKey]
      if not mobs then return end
      for mobKey, mob in pairs(mobs) do
         for i, p in ipairs(mob.points) do
            table.insert(out, {
               x = p[1], y = p[2], name = mob.name,
               npcID = type(mobKey) == "number" and mobKey or nil,
               key = zoneKey .. ":" .. tostring(mobKey) .. ":" .. i,
            })
         end
      end
   end
   addFrom(STATIC)
   addFrom(CBH.db and CBH.db.learned)
   return out
end

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
      if (dx * dx + dy * dy) < 2500 then return end -- within 50yd of a known point
   end
   table.insert(entry.points, { x, y })
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

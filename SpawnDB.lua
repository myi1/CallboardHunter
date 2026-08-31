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
   -- kind: "dungeon" (5-man) or "raid". Both are automated identically; the kind
   -- is what lets the card catalogue bucket objectives the way the server does
   -- (Maerys's "The Whole Board" asks for one of each TYPE: open world, dungeon,
   -- raid, ...), and it keeps 5-man and raid bosses of the same name apart.
   ["Utgarde Keep"] = { zone = "Howling Fjord", kind = "dungeon", bosses = {
      "Prince Keleseth", "Skarvald", "Dalronn", "Ingvar the Plunderer" } },
   ["Utgarde Pinnacle"] = { zone = "Howling Fjord", kind = "dungeon", bosses = {
      "Svala Sorrowgrave", "Gortok Palehoof", "Skadi the Ruthless", "King Ymiron" } },
   ["The Nexus"] = { zone = "Borean Tundra", kind = "dungeon", bosses = {
      "Grand Magus Telestra", "Anomalus", "Ormorok", "Keristrasza" } },
   ["The Oculus"] = { zone = "Borean Tundra", kind = "dungeon", bosses = {
      "Drakos", "Varos Cloudstrider", "Mage-Lord Urom", "Ley-Guardian Eregos" } },
   ["Azjol-Nerub"] = { zone = "Dragonblight", kind = "dungeon", bosses = {
      "Krik'thir", "Hadronox", "Anub'arak" } },
   ["Ahn'kahet"] = { zone = "Dragonblight", kind = "dungeon", aliases = { "The Old Kingdom" },
      bosses = { "Elder Nadox", "Prince Taldaram", "Jedoga Shadowseeker", "Herald Volazj" } },
   ["Drak'Tharon Keep"] = { zone = "Grizzly Hills", kind = "dungeon", bosses = {
      "Trollgore", "Novos the Summoner", "King Dred", "The Prophet Tharon'ja" } },
   ["Gundrak"] = { zone = "Zul'Drak", kind = "dungeon", bosses = {
      "Slad'ran", "Drakkari Colossus", "Moorabi", "Gal'darah", "Eck the Ferocious" } },
   ["Halls of Stone"] = { zone = "The Storm Peaks", kind = "dungeon", bosses = {
      "Krystallus", "Maiden of Grief", "Sjonnir the Ironshaper" } },
   ["Halls of Lightning"] = { zone = "The Storm Peaks", kind = "dungeon", bosses = {
      "General Bjarngrim", "Volkhan", "Ionar", "Loken" } },
   ["The Violet Hold"] = { zone = "Dalaran", kind = "dungeon", bosses = {
      "Cyanigosa", "Erekem", "Xevozz", "Zuramat", "Ichoron", "Moragg", "Lavanthor" } },
   ["Trial of the Champion"] = { zone = "Icecrown", kind = "dungeon", bosses = {
      "Eadric the Pure", "Argent Confessor Paletress", "The Black Knight" } },
   ["The Forge of Souls"] = { zone = "Icecrown", kind = "dungeon", bosses = {
      "Bronjahm", "Devourer of Souls" } },
   ["Pit of Saron"] = { zone = "Icecrown", kind = "dungeon", bosses = {
      "Forgemaster Garfrost", "Krick", "Scourgelord Tyrannus" } },
   ["Halls of Reflection"] = { zone = "Icecrown", kind = "dungeon", bosses = {
      "Falric", "Marwyn" } },
   ["The Culling of Stratholme"] = { zone = "Tanaris", kind = "dungeon",
      aliases = { "Culling of Stratholme" },
      bosses = { "Salramm the Fleshcrafter", "Chrono-Lord Epoch", "Mal'Ganis",
                 "Meathook", "Infinite Corruptor" } },

   -- Raids. Bosses matter here for the same reason they do in 5-mans: a card may
   -- name only the boss ("Wanted: Festergut") and never the raid. These carried
   -- EMPTY boss lists until now, which is why raid automation could not match.
   ["Naxxramas"] = { zone = "Dragonblight", kind = "raid", bosses = {
      "Anub'Rekhan", "Grand Widow Faerlina", "Maexxna", "Noth the Plaguebringer",
      "Heigan the Unclean", "Loatheb", "Instructor Razuvious", "Gothik the Harvester",
      "Patchwerk", "Grobbulus", "Gluth", "Thaddius", "Sapphiron", "Kel'Thuzad" } },
   ["Ulduar"] = { zone = "The Storm Peaks", kind = "raid", bosses = {
      "Flame Leviathan", "Ignis the Furnace Master", "Razorscale", "XT-002 Deconstructor",
      "Kologarn", "Auriaya", "Hodir", "Thorim", "Freya", "Mimiron", "General Vezax",
      "Yogg-Saron", "Algalon the Observer" } },
   ["Icecrown Citadel"] = { zone = "Icecrown", kind = "raid", bosses = {
      "Lord Marrowgar", "Lady Deathwhisper", "Deathbringer Saurfang", "Festergut",
      "Rotface", "Professor Putricide", "Blood-Queen Lana'thel", "Valithria Dreamwalker",
      "Sindragosa", "The Lich King" } },
   ["Trial of the Crusader"] = { zone = "Icecrown", kind = "raid", bosses = {
      "Lord Jaraxxus", "Icehowl", "Gormok the Impaler" } },
   ["Vault of Archavon"] = { zone = "Wintergrasp", kind = "raid", bosses = {
      "Archavon the Stone Watcher", "Emalon the Storm Watcher",
      "Koralon the Flame Watcher", "Toravon the Ice Watcher" } },
   ["The Obsidian Sanctum"] = { zone = "Dragonblight", kind = "raid", bosses = {
      "Sartharion", "Tenebron", "Shadron", "Vesperon" } },
   ["The Eye of Eternity"] = { zone = "Borean Tundra", kind = "raid", bosses = { "Malygos" } },
   ["The Ruby Sanctum"] = { zone = "Dragonblight", kind = "raid", bosses = { "Halion" } },
   ["Onyxia's Lair"] = { zone = "Dustwallow Marsh", kind = "raid", bosses = { "Onyxia" } },
   -- ------------------------------------------------------------- Outland
   -- Reported gap: "Purge the Darkness: Kelidan the Breaker" resolved to nothing
   -- because this table only ever covered Northrend. Kelidan is the Blood
   -- Furnace end boss, inside Hellfire Citadel, in Hellfire Peninsula.
   -- Both spellings of the apostrophe names are listed - the server does not
   -- always use Blizzard's punctuation.
   ["Hellfire Ramparts"] = { zone = "Hellfire Peninsula", kind = "dungeon", bosses = {
      "Watchkeeper Gargolmar", "Omor the Unscarred", "Vazruden", "Nazan" } },
   ["The Blood Furnace"] = { zone = "Hellfire Peninsula", kind = "dungeon",
      aliases = { "Blood Furnace" }, bosses = {
      "The Maker", "Broggok", "Keli'dan the Breaker", "Kelidan the Breaker" } },
   ["The Shattered Halls"] = { zone = "Hellfire Peninsula", kind = "dungeon",
      aliases = { "Shattered Halls" }, bosses = {
      "Grand Warlock Nethekurse", "Blood Guard Porung", "Warbringer O'mrogg",
      "Warchief Kargath Bladefist", "Kargath Bladefist" } },
   ["Magtheridon's Lair"] = { zone = "Hellfire Peninsula", kind = "raid", bosses = {
      "Magtheridon" } },

   ["The Slave Pens"] = { zone = "Zangarmarsh", kind = "dungeon",
      aliases = { "Slave Pens" }, bosses = {
      "Mennu the Betrayer", "Rokmar the Crackler", "Quagmirran" } },
   ["The Underbog"] = { zone = "Zangarmarsh", kind = "dungeon",
      aliases = { "Underbog" }, bosses = {
      "Hungarfen", "Ghaz'an", "Swamplord Musel'ek", "The Black Stalker" } },
   ["The Steamvault"] = { zone = "Zangarmarsh", kind = "dungeon",
      aliases = { "Steamvault" }, bosses = {
      "Hydromancer Thespia", "Mekgineer Steamrigger", "Warlord Kalithresh" } },

   ["Mana-Tombs"] = { zone = "Terokkar Forest", kind = "dungeon", bosses = {
      "Pandemonius", "Tavarok", "Nexus-Prince Shaffar" } },
   ["Auchenai Crypts"] = { zone = "Terokkar Forest", kind = "dungeon", bosses = {
      "Shirrak the Dead Watcher", "Exarch Maladaar" } },
   ["Sethekk Halls"] = { zone = "Terokkar Forest", kind = "dungeon", bosses = {
      "Darkweaver Syth", "Talon King Ikiss" } },
   ["Shadow Labyrinth"] = { zone = "Terokkar Forest", kind = "dungeon", bosses = {
      "Ambassador Hellmaw", "Blackheart the Inciter", "Grandmaster Vorpil", "Murmur" } },

   ["The Mechanar"] = { zone = "Netherstorm", kind = "dungeon",
      aliases = { "Mechanar" }, bosses = {
      "Gatewatcher Gyro-Kill", "Gatewatcher Iron-Hand", "Mechano-Lord Capacitus",
      "Nethermancer Sepethrea", "Pathaleon the Calculator" } },
   ["The Botanica"] = { zone = "Netherstorm", kind = "dungeon",
      aliases = { "Botanica" }, bosses = {
      "Commander Sarannis", "High Botanist Freywinn", "Thorngrin the Tender",
      "Laj", "Warp Splinter" } },
   ["The Arcatraz"] = { zone = "Netherstorm", kind = "dungeon",
      aliases = { "Arcatraz" }, bosses = {
      "Zereketh the Unbound", "Dalliah the Doomsayer", "Wrath-Scryer Soccothrates",
      "Harbinger Skyriss" } },

   ["Gruul's Lair"] = { zone = "Blade's Edge Mountains", kind = "raid", bosses = {
      "High King Maulgar", "Gruul the Dragonkiller" } },
   ["Magisters' Terrace"] = { zone = "Isle of Quel'Danas", kind = "dungeon", bosses = {
      "Selin Fireheart", "Vexallus", "Priestess Delrissa" } },
   ["Sunwell Plateau"] = { zone = "Isle of Quel'Danas", kind = "raid", bosses = {
      "Kalecgos", "Brutallus", "Felmyst", "M'uru", "Kil'jaeden" } },
   ["Karazhan"] = { zone = "Deadwind Pass", kind = "raid", bosses = {
      "Attumen the Huntsman", "Moroes", "Maiden of Virtue", "The Curator",
      "Shade of Aran", "Terestian Illhoof", "Netherspite", "Prince Malchezaar" } },

   -- Outland raid hubs seen in real callboard cards. Bosses added so a card that
   -- names only the boss resolves, same as everywhere else.
   ["Coilfang Reservoir"] = { zone = "Zangarmarsh", kind = "raid",
      aliases = { "Serpentshrine Cavern" }, bosses = {
      "Hydross the Unstable", "The Lurker Below", "Leotheras the Blind",
      "Fathom-Lord Karathress", "Morogrim Tidewalker", "Lady Vashj" } },
   ["Tempest Keep"] = { zone = "Netherstorm", kind = "raid", aliases = { "The Eye" },
      bosses = { "Al'ar", "Void Reaver", "High Astromancer Solarian",
                 "Kael'thas Sunstrider" } },
   ["Black Temple"] = { zone = "Shadowmoon Valley", kind = "raid", bosses = {
      "High Warlord Naj'entus", "Supremus", "Shade of Akama", "Teron Gorefiend",
      "Gurtogg Bloodboil", "Reliquary of Souls", "Mother Shahraz",
      "Illidan Stormrage" } },

   -- ------------------------------------------------------------- Classic
   -- The callboard operates at every level (cardZones already holds Elwynn,
   -- Teldrassil, Durotar objectives), so the old-world instances belong here too.
   ["Ragefire Chasm"] = { zone = "Orgrimmar", kind = "dungeon", bosses = { "Taragaman the Hungerer" } },
   ["The Deadmines"] = { zone = "Westfall", kind = "dungeon", aliases = { "Deadmines" },
      bosses = { "Mr. Smite", "Edwin VanCleef" } },
   ["Wailing Caverns"] = { zone = "The Barrens", kind = "dungeon", bosses = { "Mutanus the Devourer" } },
   ["Shadowfang Keep"] = { zone = "Silverpine Forest", kind = "dungeon", bosses = {
      "Baron Silverlaine", "Arugal" } },
   ["Blackfathom Deeps"] = { zone = "Ashenvale", kind = "dungeon", bosses = { "Aku'mai" } },
   ["The Stockade"] = { zone = "Stormwind City", kind = "dungeon", bosses = { "Bazil Thredd" } },
   ["Gnomeregan"] = { zone = "Dun Morogh", kind = "dungeon", bosses = { "Mekgineer Thermaplugg" } },
   ["Razorfen Kraul"] = { zone = "The Barrens", kind = "dungeon", bosses = { "Charlga Razorflank" } },
   ["Razorfen Downs"] = { zone = "The Barrens", kind = "dungeon", bosses = { "Amnennar the Coldbringer" } },
   ["Scarlet Monastery"] = { zone = "Tirisfal Glades", kind = "dungeon", bosses = {
      "Herod", "Arcanist Doan", "Scarlet Commander Mograine", "High Inquisitor Whitemane" } },
   ["Uldaman"] = { zone = "Badlands", kind = "dungeon", bosses = { "Archaedas", "Ironaya" } },
   ["Zul'Farrak"] = { zone = "Tanaris", kind = "dungeon", bosses = { "Chief Ukorz Sandscalp" } },
   ["Maraudon"] = { zone = "Desolace", kind = "dungeon", bosses = { "Princess Theradras" } },
   ["Temple of Atal'Hakkar"] = { zone = "Swamp of Sorrows", kind = "dungeon",
      aliases = { "Sunken Temple" }, bosses = { "Shade of Eranikus", "Jammal'an the Prophet" } },
   ["Blackrock Depths"] = { zone = "Searing Gorge", kind = "dungeon", bosses = {
      "Emperor Dagran Thaurissan", "Ambassador Flamelash" } },
   ["Dire Maul"] = { zone = "Feralas", kind = "dungeon", bosses = { "Immol'thar", "Prince Tortheldrin" } },
   ["Stratholme"] = { zone = "Eastern Plaguelands", kind = "dungeon", bosses = {
      "Baron Rivendare", "Balnazzar" } },
   ["Scholomance"] = { zone = "Western Plaguelands", kind = "dungeon", bosses = {
      "Darkmaster Gandling", "Ras Frostwhisper" } },
   ["Blackrock Spire"] = { zone = "Searing Gorge", kind = "dungeon", bosses = {
      "General Drakkisath", "Overlord Wyrmthalak" } },
   ["Blackwing Lair"] = { zone = "Searing Gorge", kind = "raid", bosses = {
      "Razorgore the Untamed", "Vaelastrasz the Corrupt", "Nefarian" } },
   ["Molten Core"] = { zone = "Searing Gorge", kind = "raid", bosses = {
      "Lucifron", "Magmadar", "Golemagg the Incinerator", "Ragnaros" } },
   ["Zul'Gurub"] = { zone = "Stranglethorn Vale", kind = "raid", bosses = { "Hakkar" } },
   ["Ahn'Qiraj"] = { zone = "Silithus", kind = "raid", aliases = { "Temple of Ahn'Qiraj" },
      bosses = { "The Prophet Skeram", "C'Thun", "Ossirian the Unscarred" } },
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

-- Which instance (if any) does this text name, and is it a dungeon or a raid?
-- Returns instanceName, kind. The LONGEST matching name wins, so "Icecrown
-- Citadel" is not mistaken for a stray "Icecrown", and a boss shared between a
-- 5-man and a raid resolves to whichever name matched more specifically.
function SpawnDB.InstanceInText(text)
   if not text then return nil end
   local lt = string.lower(text)
   local best, bestKind, bestLen
   for name, info in pairs(DUNGEONS) do
      local cands = { name }
      for _, a in ipairs(info.aliases or {}) do cands[#cands + 1] = a end
      for _, b in ipairs(info.bosses or {}) do cands[#cands + 1] = b end
      for _, c in ipairs(cands) do
         if string.find(lt, string.lower(c), 1, true) then
            if not bestLen or string.len(c) > bestLen then
               best, bestKind, bestLen = name, info.kind or "dungeon", string.len(c)
            end
         end
      end
   end
   return best, bestKind
end

-- The callboard's objective taxonomy, as far as it can be observed. Maerys's
-- "The Whole Board" asks for one objective "of each type - open world, dungeon,
-- ...", so the server groups them, but the full vocabulary is not visible to an
-- addon. These are therefore derived from card SHAPE, and anything unrecognised
-- is kept as "other" rather than discarded:
--   raid / dungeon  - names an instance we know, or one of its bosses
--   collection      - "Collect 40 Icethorn."
--   open world      - "Kill 10 X in <zone>." or "<X> slain"
function SpawnDB.ClassifyCard(text)
   if not text or text == "" then return "other" end
   local _, kind = SpawnDB.InstanceInText(text)
   if kind then return kind end
   local lt = string.lower(text)
   if string.find(lt, "^collect%s+%d") then return "collection" end
   if SpawnDB.FindMapZoneIn and SpawnDB.FindMapZoneIn(text) then return "open world" end
   if string.find(lt, "slain") or string.find(lt, "^kill%s+%d") then return "open world" end
   return "other"
end

-- A callboard title reads "<flavour prefix>: <target>". The prefix is
-- decorative and the target is the job: "Dungeon Crawl: Loken" and
-- "Wanted: Loken" are the same contract, which is why favourites key on the
-- target rather than the whole title. Splits on the FIRST colon only, so a
-- target containing one ("SI:7 Insignia") survives intact.
function SpawnDB.TargetOf(title)
   if type(title) ~= "string" or title == "" then return nil end
   -- Description lines ("Collect 20 Eternal Air.") are not titles.
   if string.sub(title, -1) == "." then return nil end
   local hasColon = string.find(title, ":", 1, true) ~= nil
   local _, _, target = string.find(title, "^[^:]-:%s*(.+)$")
   -- A colon with nothing (or only whitespace) after it, e.g. "Wanted:", is a
   -- truncated title, not the "no colon at all" case - it must still come out
   -- nil, not fall back to the raw "Wanted:" prefix.
   if hasColon and not target then return nil end
   local out = target or title
   out = string.gsub(out, "^%s+", "")
   out = string.gsub(out, "%s+$", "")
   if out == "" then return nil end
   return out
end

-- Bundled quest targets, harvested from real cards (see the spec's Evidence
-- section). lo/hi are the level band the target was observed at. This is the
-- starting list; at runtime it merges with whatever the catalogue has learned,
-- and pooled exports grow it each release.
SpawnDB.QUESTS = {
   { target = "Adamantite Bar", lo = 67, hi = 69 },
   { target = "Adder's Tongue", lo = 77, hi = 80 },
   { target = "Ancient Lichen", lo = 68, hi = 73 },
   { target = "Anub'arak", lo = 74, hi = 80 },
   { target = "Ashtongue Handler", lo = 67, hi = 70 },
   { target = "Azure Manashaper", lo = 79, hi = 80 },
   { target = "Azure Scalebane", lo = 80, hi = 80 },
   { target = "Banthar", lo = 64, hi = 67 },
   { target = "Black Lotus", lo = 64, hi = 64 },
   { target = "Blood Scythe", lo = 64, hi = 64 },
   { target = "Carrion Eater", lo = 73, hi = 75 },
   { target = "Charlga Razorflank", lo = 35, hi = 35 },
   { target = "Cobalt Bar", lo = 77, hi = 77 },
   { target = "Core Leather", lo = 64, hi = 64 },
   { target = "Deadnettle", lo = 75, hi = 75 },
   { target = "Earthbound Revenant", lo = 80, hi = 80 },
   { target = "Eternal Earth", lo = 77, hi = 80 },
   { target = "Eternal Life", lo = 77, hi = 80 },
   { target = "Eternal Shadow", lo = 77, hi = 80 },
   { target = "Eternal Water", lo = 76, hi = 80 },
   { target = "Felsteel Bar", lo = 64, hi = 64 },
   { target = "Felweed", lo = 64, hi = 64 },
   { target = "Frost Lotus", lo = 80, hi = 80 },
   { target = "Gal'darah", lo = 80, hi = 80 },
   { target = "Gigantaur", lo = 75, hi = 75 },
   { target = "Goldclover", lo = 77, hi = 77 },
   { target = "Harbinger Skyriss", lo = 70, hi = 74 },
   { target = "High Shaman Bloodpaw", lo = 73, hi = 73 },
   { target = "Ingvar the Plunderer", lo = 72, hi = 80 },
   { target = "Kelidan the Breaker", lo = 64, hi = 70 },
   { target = "Kelthuzad", lo = 80, hi = 80 },
   { target = "Khorium Bar", lo = 70, hi = 74 },
   { target = "King Bangalash", lo = 35, hi = 35 },
   { target = "King Ymiron", lo = 80, hi = 80 },
   { target = "Lichbloom", lo = 80, hi = 80 },
   { target = "Loken", lo = 80, hi = 80 },
   { target = "Magister Keldonus", lo = 74, hi = 74 },
   { target = "Mossy Rampager", lo = 72, hi = 76 },
   { target = "Netherbloom", lo = 70, hi = 74 },
   { target = "Netherweave Cloth", lo = 64, hi = 65 },
   { target = "Nexus-Prince Shaffar", lo = 70, hi = 75 },
   { target = "Old Kingdom", lo = 77, hi = 80 },
   { target = "Omor the Unscarred", lo = 64, hi = 71 },
   { target = "Primal Air", lo = 67, hi = 67 },
   { target = "Primal Earth", lo = 67, hi = 67 },
   { target = "Primal Shadow", lo = 65, hi = 70 },
   { target = "Primal Water", lo = 65, hi = 65 },
   { target = "Ravaged Ghoul", lo = 79, hi = 80 },
   { target = "Shadowcloth", lo = 71, hi = 71 },
   { target = "Shadoweave Cloth", lo = 71, hi = 71 },
   { target = "Shadowmoon Slayer", lo = 70, hi = 70 },
   { target = "Skeletal Archmage", lo = 80, hi = 80 },
   { target = "Spellcloth", lo = 70, hi = 70 },
   { target = "Spellfire Cloth", lo = 72, hi = 72 },
   { target = "Talandra's Rose", lo = 73, hi = 77 },
   { target = "Talon King Ikiss", lo = 70, hi = 75 },
   { target = "Terocone", lo = 64, hi = 64 },
   { target = "The Oculus", lo = 77, hi = 80 },
   { target = "The Prophet Tharon'ja", lo = 76, hi = 80 },
   { target = "Tiger Lily", lo = 72, hi = 77 },
   { target = "Titanium Bar", lo = 80, hi = 80 },
   { target = "Whispering Wind", lo = 80, hi = 80 },
   { target = "Yogg-Saron", lo = 80, hi = 80 },
}

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

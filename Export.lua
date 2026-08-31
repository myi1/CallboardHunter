-- CallboardHunter Export: package learned spawn data for sharing.
--
-- Writes a clean, self-describing table to its own SavedVariable
-- (CallboardHunterExport) so a contributor can upload one file and have the
-- maintainer merge it into SpawnDB's bundled points.
--
-- Note on files: WoW writes ALL of an addon's SavedVariables into a single
-- file (SavedVariables/CallboardHunter.lua), so this table lands alongside the
-- normal DB rather than in a file of its own. That's accepted - the export
-- table is self-contained and easy to lift out; see
-- docs/superpowers/specs/2026-08-29-comm-channel-probe-design.md for the
-- sharing options that were weighed.
local CBH = CallboardHunter

local EXPORT_FORMAT = 1

-- Points are {x, y, n} where n is how many times that spot was corroborated
-- (see SpawnDB.Learn). Round coordinates for a readable, diff-able file; 4
-- decimals is ~0.5yd on the largest Northrend map, far finer than we need.
local function Round(v)
   return math.floor((v or 0) * 10000 + 0.5) / 10000
end

local function CopyPoints(list)
   local out = {}
   for _, p in ipairs(list or {}) do
      if p[1] and p[2] then
         out[#out + 1] = { Round(p[1]), Round(p[2]), p[3] or 1 }
      end
   end
   return out
end

-- learned:      [zone][npcID|name] = { name = , points = {{x,y,n},...} }
-- learnedKills: [zone][objName]    = {{x,y,n},...}
local function Collect(src, isRare)
   local out, zones, points = {}, 0, 0
   for zone, mobs in pairs(src or {}) do
      local z = {}
      local any = false
      for mobKey, entry in pairs(mobs or {}) do
         local list = isRare and entry.points or entry
         local pts = CopyPoints(list)
         if #pts > 0 then
            local name = (isRare and entry.name) or mobKey
            local rec = { points = pts }
            -- Keep the npcID when we have one: it survives renames and is the
            -- reliable key for merging into SpawnDB.STATIC.
            if isRare and type(mobKey) == "number" then rec.npcID = mobKey end
            z[tostring(name)] = rec
            points = points + #pts
            any = true
         end
      end
      if any then out[zone] = z; zones = zones + 1 end
   end
   return out, zones, points
end

-- ------------------------------------------------------------- card catalogue
--
-- Record every distinct callboard card ever seen, verbatim. cardZones only ever
-- stored cards matching "Kill N <mob> in <zone>", so collection and slay cards
-- were never recorded at all - the observed objective list was an undercount of
-- its own source. This keeps the raw text plus the level you were when it
-- appeared, which is what makes a level-banded 1-80 quest list possible once
-- several players pool their exports.
--
-- Keyed by the card text itself, so it dedupes naturally and re-seeing a card
-- just bumps its count.
local CATALOGUE_CAP = 2000

function CBH.RecordCard(text)
   if not (CBH.db and text) or text == "" then return end
   -- Cards carry live progress ("0/10"), which would make every tick a new
   -- entry. Normalise counters out so one card is one entry.
   -- Never catalogue our own annotations (they carry colour escapes).
   if string.find(text, "|c", 1, true) then return end
   local key = string.gsub(text, "%d+%s*/%s*%d+", "#/#")
   key = string.gsub(key, "^%s+", "")
   key = string.gsub(key, "%s+$", "")
   if key == "" then return end
   CBH.db.cardCatalogue = CBH.db.cardCatalogue or {}
   local cat = CBH.db.cardCatalogue
   local e = cat[key]
   if e then
      e.n = (e.n or 1) + 1
      -- Widen the level band this card has been seen at.
      local lvl = UnitLevel and UnitLevel("player")
      if lvl and lvl > 0 then
         if not e.lo or lvl < e.lo then e.lo = lvl end
         if not e.hi or lvl > e.hi then e.hi = lvl end
      end
      return
   end
   -- Cap so a long-running database cannot grow without bound.
   local count = 0
   for _ in pairs(cat) do count = count + 1 end
   if count >= CATALOGUE_CAP then return end
   local lvl = UnitLevel and UnitLevel("player")
   cat[key] = { n = 1, lo = lvl, hi = lvl,
                -- Bucket by the callboard's own notion of objective type, so the
                -- pooled data can answer "one of each type" the way Maerys does.
                kind = CBH.SpawnDB and CBH.SpawnDB.ClassifyCard
                   and CBH.SpawnDB.ClassifyCard(key) or nil,
                where = (GetRealZoneText and GetRealZoneText()) or nil,
                at = date("%Y-%m-%d") }
   -- A brand-new key can widen instance coverage (e.g. the first-ever ICC
   -- card this player has seen), so the dungeon gate's memo must not go stale
   -- and leave automation refusing an instance it has just learned about. A
   -- repeat sighting only bumps .n above and does not reach this line, so the
   -- memo is not rebuilt on every card re-seen - only on real growth.
   if CBH.SpawnDB and CBH.SpawnDB.InvalidateCoverage then CBH.SpawnDB.InvalidateCoverage() end
end

-- /cbh catalogue [dump]
local KIND_ORDER = { "open world", "dungeon", "raid", "collection", "other" }

function CBH.Catalogue(arg)
   local cat = (CBH.db and CBH.db.cardCatalogue) or {}
   local byKind, keys = {}, {}
   for k, e in pairs(cat) do
      keys[#keys + 1] = k
      -- Classify on read too, so entries recorded before types existed bucket
      -- correctly without needing a migration.
      local kind = e.kind
      if not kind and CBH.SpawnDB and CBH.SpawnDB.ClassifyCard then
         kind = CBH.SpawnDB.ClassifyCard(k)
         e.kind = kind
      end
      kind = kind or "other"
      byKind[kind] = byKind[kind] or {}
      table.insert(byKind[kind], k)
   end
   if #keys == 0 then
      CBH.print("No cards catalogued yet - open an Objectives Board and they"
         .. " record themselves.")
      return
   end
   local dump = string.lower(arg or "") == "dump"
   local counts = {}
   for _, kind in ipairs(KIND_ORDER) do
      local list = byKind[kind]
      if list then
         table.sort(list)
         counts[#counts + 1] = kind .. " " .. #list
         if dump then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. string.upper(kind)
               .. "|r (" .. #list .. ")")
            for _, k in ipairs(list) do
               local e = cat[k]
               DEFAULT_CHAT_FRAME:AddMessage("  [" .. tostring(e.lo or "?")
                  .. (e.hi and e.hi ~= e.lo and ("-" .. e.hi) or "") .. "] " .. k
                  .. " (x" .. tostring(e.n or 1) .. ")")
            end
         end
      end
   end
   CBH.print(#keys .. " distinct card" .. (#keys == 1 and "" or "s")
      .. " catalogued - " .. table.concat(counts, ", ") .. ".")
   if not dump then CBH.print("/cbh catalogue dump to list them by type.") end
end

function CBH.Export(arg)
   arg = string.lower(arg or "")
   if arg == "clear" then
      CallboardHunterExport = nil
      CBH.print("Export cleared. It disappears from the saved file on your next"
         .. " /reload or logout.")
      return
   end
   if not CBH.db then return end

   local rares, rZones, rPts = Collect(CBH.db.learned, true)
   local camps, cZones, cPts = Collect(CBH.db.learnedKills, false)

   local nCards = 0
   for _ in pairs(CBH.db.cardCatalogue or {}) do nCards = nCards + 1 end
   -- A catalogue alone is worth exporting: it is the raw material for the quest
   -- list, and a player who has only opened boards still has something to give.
   if rPts == 0 and cPts == 0 and nCards == 0 then
      CBH.print("Nothing learned yet - open a callboard or find some rares first,"
         .. " then /cbh export.")
      return
   end

   CallboardHunterExport = {
      format = EXPORT_FORMAT,
      addon = (GetAddOnMetadata and GetAddOnMetadata("CallboardHunter", "Version")) or "?",
      realm = (GetRealmName and GetRealmName()) or "?",
      -- Character name is included so contributions can be credited and so
      -- points from different players can be told apart when merging (two
      -- independent reports of a spot are worth far more than one player
      -- seeing it twice).
      character = (UnitName and UnitName("player")) or "?",
      exported = date("%Y-%m-%d %H:%M:%S"),
      rares = rares,
      camps = camps,
      -- Every distinct card seen, verbatim, with the level band it appeared at.
      -- This is the raw material for a level-banded callboard quest list.
      cards = CBH.db.cardCatalogue or {},
   }

   CBH.print("Export prepared: " .. rPts .. " rare point"
      .. (rPts == 1 and "" or "s") .. " across " .. rZones .. " zone"
      .. (rZones == 1 and "" or "s") .. ", and " .. cPts .. " callboard camp point"
      .. (cPts == 1 and "" or "s") .. " across " .. cZones .. " zone"
      .. (cZones == 1 and "" or "s") .. ".")
   if nCards > 0 then
      CBH.print("  ...plus " .. nCards .. " catalogued callboard card"
         .. (nCards == 1 and "" or "s") .. ".")
   end
   CBH.print("Now type /reload (or log out) - that is what writes the file.")
   CBH.print("Then upload: World of Warcraft\\WTF\\Account\\<YOUR ACCOUNT>"
      .. "\\SavedVariables\\CallboardHunter.lua")
   CBH.print("It includes your character name and realm for credit."
      .. " /cbh export clear removes the export again.")
   CBH.Log("export", "prepared rares=" .. rPts .. "/" .. rZones
      .. " camps=" .. cPts .. "/" .. cZones)
end

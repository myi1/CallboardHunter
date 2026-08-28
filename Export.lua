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

   if rPts == 0 and cPts == 0 then
      CBH.print("Nothing learned yet - go find some rares first, then /cbh export.")
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
   }

   CBH.print("Export prepared: " .. rPts .. " rare point"
      .. (rPts == 1 and "" or "s") .. " across " .. rZones .. " zone"
      .. (rZones == 1 and "" or "s") .. ", and " .. cPts .. " callboard camp point"
      .. (cPts == 1 and "" or "s") .. " across " .. cZones .. " zone"
      .. (cZones == 1 and "" or "s") .. ".")
   CBH.print("Now type /reload (or log out) - that is what writes the file.")
   CBH.print("Then upload: World of Warcraft\\WTF\\Account\\<YOUR ACCOUNT>"
      .. "\\SavedVariables\\CallboardHunter.lua")
   CBH.print("It includes your character name and realm for credit."
      .. " /cbh export clear removes the export again.")
   CBH.Log("export", "prepared rares=" .. rPts .. "/" .. rZones
      .. " camps=" .. cPts .. "/" .. cZones)
end

-- CallboardHunter Detector: finds rares via mouseover/target/combat log.
local CBH = CallboardHunter
local Detector = CBH.Detector

local recentAnnounce = {} -- [name] = GetTime()

-- 3.3.5 GUID: "0x" + 16 hex chars; creature npcID is hex chars 7-12.
local function NpcIDFromGUID(guid)
   if not guid or string.len(guid) ~= 18 then return nil end
   local unitType = string.sub(guid, 5, 5)
   if unitType ~= "3" and unitType ~= "B" then return nil end -- creature/vehicle
   return tonumber(string.sub(guid, 7, 12), 16)
end

local function AnnounceOnce(name, npcID, learnHere)
   local now = GetTime()
   if recentAnnounce[name] and now - recentAnnounce[name] < 60 then return end
   recentAnnounce[name] = now
   if learnHere then
      local zone = GetRealZoneText()
      if not WorldMapFrame:IsShown() then SetMapToCurrentZone() end
      local x, y = GetPlayerMapPosition("player")
      if x and y and (x ~= 0 or y ~= 0) then
         CBH.SpawnDB.Learn(zone, name, npcID, x, y)
      end
   end
   if CBH.Announce.Show then CBH.Announce.Show(name, npcID) end
end

local function CheckUnit(unit)
   if not UnitExists(unit) or UnitIsDead(unit) or UnitIsPlayer(unit) then return end
   local class = UnitClassification(unit)
   if class ~= "rare" and class ~= "rareelite" then return end
   local name = UnitName(unit)
   local npcID = NpcIDFromGUID(UnitGUID(unit))
   AnnounceOnce(name, npcID, true)
end

function Detector.OnMouseover() CheckUnit("mouseover") end
function Detector.OnTargetChanged() CheckUnit("target") end

function Detector.OnCombatLog(timestamp, event, srcGUID, srcName, srcFlags,
                              dstGUID, dstName, dstFlags, ...)
   if event == "UNIT_DIED" then
      local npcID = NpcIDFromGUID(dstGUID)
      if dstName and CBH.SpawnDB.IsKnownRare(npcID, dstName) then
         local zone = GetRealZoneText()
         local hot, have, need = CBH.QuestWatcher.IsZoneHot(zone)
         if hot then
            local progress
            if have and need then
               progress = (have + 1) .. "/" .. need
               CBH.print(dstName .. " slain! Callboard progress: " ..
                  progress .. " (log updates on next quest tick)")
            else
               CBH.print(dstName .. " slain!")
            end
            if CBH.db.options.partyAnnounce and GetNumPartyMembers() > 0 then
               local msg = dstName .. " down"
               if progress then msg = msg .. " - callboard " .. progress end
               SendChatMessage(msg .. " (" .. zone .. ")", "PARTY")
            end
            CBH.Arrow.MarkVisitedNear(dstName)
         end
      end
      return
   end
   -- Any combat activity from a known rare nearby -> announce (no learn: its
   -- exact position is unknown; the player may still be far from it).
   local npcID = NpcIDFromGUID(srcGUID)
   if srcName and npcID and CBH.SpawnDB.IsKnownRare(npcID, srcName) then
      AnnounceOnce(srcName, npcID, false)
   end
end

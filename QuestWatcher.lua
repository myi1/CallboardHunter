-- CallboardHunter QuestWatcher: parses the quest log for zone-scoped rare quests.
local CBH = CallboardHunter
local QW = CBH.QuestWatcher

-- Default markers; CBH.db.questPatterns (array of lowercase substrings) overrides.
local DEFAULT_MARKERS = { "rare" }

local function GetMarkers()
   return (CBH.db and CBH.db.questPatterns) or DEFAULT_MARKERS
end

local function TextMentionsRares(text)
   if not text then return false end
   text = string.lower(text)
   for _, m in ipairs(GetMarkers()) do
      if string.find(text, m, 1, true) then return true end
   end
   return false
end

local function FindZoneIn(text)
   if not text then return nil end
   text = string.lower(text)
   for zone in pairs(CBH.SpawnDB.ZONES) do
      if string.find(text, string.lower(zone), 1, true) then return zone end
   end
   return nil
end

local throttle = 0
function QW.Update(force)
   local now = GetTime()
   if not force and (now - throttle < 0.5) then
      QW.pending = true
      return
   end
   throttle = now
   QW.pending = nil

   local hot, kills = {}, {}
   for i = 1, GetNumQuestLogEntries() do
      local title, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
      if not isHeader and title then
         local numObj = GetNumQuestLeaderBoards(i)
         for j = 1, numObj do
            local text = GetQuestLogLeaderBoard(j, i)
            if TextMentionsRares(text) or TextMentionsRares(title) then
               local zone = FindZoneIn(text) or FindZoneIn(title)
               local _, _, have, need = string.find(text or "", "(%d+)%s*/%s*(%d+)")
               if zone then
                  have, need = tonumber(have), tonumber(need)
                  -- A FINISHED rare quest must stop driving the addon. Kill
                  -- objectives were always filtered by have<need, but hot zones
                  -- never were: a completed "rare" quest kept the arrow pointing
                  -- at its spawns, kept the Port button in objective mode, and
                  -- could out-rank an unfinished objective (watched/lower index
                  -- wins), sending you to a zone you were done with. Keep the
                  -- entry so /cbh obj and /cbh scan stay truthful; flag it done
                  -- and let consumers skip it.
                  local done = (need and have and have >= need) or false
                  -- Two rare quests in one zone: keep the UNFINISHED one, else a
                  -- completed quest parsed later masks work you still have left.
                  local prev = hot[zone]
                  if not (prev and done and not prev.done) then
                     hot[zone] = { have = have, need = need, done = done,
                        questIndex = i, questID = questID }
                  end
               end
            end
            -- Kill objectives ("Azure Scalebane slain: 3/10", "Beasts slain: 22/75"):
            -- track progress and learn WHERE counted kills happen.
            local _, _, mobName, kHave, kNeed =
               string.find(text or "", "^(.-)%s+[Ss]lain:%s*(%d+)%s*/%s*(%d+)")
            if not mobName then
               -- The callboard also phrases objectives as "<what> in <Zone>: n/m"
               -- (e.g. "Beast Kill in Howling Fjord: 0/75"), which the "slain:"
               -- pattern misses completely. The objective then registered
               -- NOWHERE, so the addon saw no active objective at all and the
               -- Port button fell back to "Port: Home". Accept the generic
               -- "<label>: n/m" form, but only when the label names a zone we
               -- can actually travel to - an objective CBH can't locate is not
               -- something it should claim it can route to. ZoneFromQuestText
               -- then resolves it like any other kill objective.
               local _, _, label, gHave, gNeed =
                  string.find(text or "", "^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
               if label and label ~= "" and FindZoneIn(label) then
                  mobName, kHave, kNeed = label, gHave, gNeed
               end
            end
            if mobName and mobName ~= "" and not string.find(string.lower(mobName), "rare") then
               kHave, kNeed = tonumber(kHave), tonumber(kNeed)
               kills[mobName] = { have = kHave, need = kNeed,
                  questIndex = i, questID = questID }
               local prev = QW.lastCounts[mobName]
               if prev and kHave > prev then
                  CBH.print("Callboard: " .. mobName .. " " .. kHave .. "/" .. kNeed)
                  QW.LearnKillHere(mobName)
                  if kHave >= kNeed and CBH.db and CBH.db.options.partyAnnounce
                     and GetNumPartyMembers() > 0 then
                     SendChatMessage("Callboard complete: " .. mobName .. " " ..
                        kHave .. "/" .. kNeed, "PARTY")
                  end
               end
               QW.lastCounts[mobName] = kHave
            end
         end
      end
   end
   CBH.hotZones = hot
   CBH.killObjectives = kills
   if CBH.Arrow.Refresh then CBH.Arrow.Refresh() end
end

QW.lastCounts = {}

function QW.LearnKillHere(name)
   -- Map-state-safe: reads against the player's own zone even when the world map
   -- is open on somewhere else (see CBH.PlayerZonePos). nil = instance/no coords.
   local x, y = CBH.PlayerZonePos()
   if not x then return end
   CBH.SpawnDB.LearnKill(GetRealZoneText(), name, x, y)
end

-- Flush a throttled (deferred) update shortly after the burst ends.
local ticker = CreateFrame("Frame")
ticker.t = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
   self.t = self.t + elapsed
   if self.t < 0.6 then return end
   self.t = 0
   if QW.pending then QW.Update(true) end
end)

function QW.IsZoneHot(zoneKey)
   if CBH.forcedZone and string.lower(CBH.forcedZone) == string.lower(zoneKey or "") then
      return true, nil, nil
   end
   local z = CBH.hotZones[zoneKey]
   -- A completed rare quest is not "hot" - this is what stops the arrow, the
   -- rare-spawn routing points and the "slain!" progress spam once you're done.
   if z and not z.done then return true, z.have, z.need end
   return false
end

function QW.Scan()
   -- Force a fresh parse first, surfacing any hidden error.
   local ok, err = pcall(QW.Update, true)
   if not ok then
      CBH.print("|cffff3333ERROR in Update():|r " .. tostring(err))
   end

   local zonesKnown = 0
   if CBH.SpawnDB and CBH.SpawnDB.ZONES then
      for _ in pairs(CBH.SpawnDB.ZONES) do zonesKnown = zonesKnown + 1 end
   end
   CBH.print("Quest log dump (for pattern tuning). Zones known: " .. zonesKnown)

   for i = 1, GetNumQuestLogEntries() do
      local title, _, _, _, isHeader = GetQuestLogTitle(i)
      if not isHeader and title then
         DEFAULT_CHAT_FRAME:AddMessage("  [" .. i .. "] " .. title)
         for j = 1, GetNumQuestLeaderBoards(i) do
            local text, otype, done = GetQuestLogLeaderBoard(j, i)
            local mOk, marker = pcall(function()
               return TextMentionsRares(text) or TextMentionsRares(title)
            end)
            local zOk, zone = pcall(function()
               return FindZoneIn(text) or FindZoneIn(title)
            end)
            local verdict
            if not (mOk and zOk) then
               verdict = "|cffff3333match ERROR: " .. tostring(mOk and zone or marker) .. "|r"
            elseif marker and zone then
               verdict = "|cff30ff00MATCH -> " .. zone .. "|r"
            elseif marker then
               verdict = "|cffffff00marker hit, no zone found|r"
            else
               verdict = "no marker"
            end
            DEFAULT_CHAT_FRAME:AddMessage("      - " .. tostring(text) ..
               " (type=" .. tostring(otype) .. ", done=" .. tostring(done) .. ") [" .. verdict .. "]")
         end
      end
   end
   local n = 0
   for _ in pairs(CBH.hotZones) do n = n + 1 end
   CBH.print("Hot zones matched: " .. n .. ". If your callboard quest is missing, report its exact text.")
end

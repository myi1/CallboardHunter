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
function QW.Update()
   local now = GetTime()
   if now - throttle < 0.5 then return end
   throttle = now

   local hot = {}
   for i = 1, GetNumQuestLogEntries() do
      local title, _, _, _, isHeader = GetQuestLogTitle(i)
      if not isHeader and title then
         local numObj = GetNumQuestLeaderBoards(i)
         for j = 1, numObj do
            local text = GetQuestLogLeaderBoard(j, i)
            if TextMentionsRares(text) or TextMentionsRares(title) then
               local zone = FindZoneIn(text) or FindZoneIn(title)
               local _, _, have, need = string.find(text or "", "(%d+)%s*/%s*(%d+)")
               if zone then
                  hot[zone] = { have = tonumber(have), need = tonumber(need), questIndex = i }
               end
            end
         end
      end
   end
   CBH.hotZones = hot
   if CBH.Arrow.Refresh then CBH.Arrow.Refresh() end
end

function QW.IsZoneHot(zoneKey)
   if CBH.forcedZone and string.lower(CBH.forcedZone) == string.lower(zoneKey or "") then
      return true, nil, nil
   end
   local z = CBH.hotZones[zoneKey]
   if z then return true, z.have, z.need end
   return false
end

function QW.Scan()
   CBH.print("Quest log dump (for pattern tuning):")
   for i = 1, GetNumQuestLogEntries() do
      local title, _, _, _, isHeader = GetQuestLogTitle(i)
      if not isHeader and title then
         DEFAULT_CHAT_FRAME:AddMessage("  [" .. i .. "] " .. title)
         for j = 1, GetNumQuestLeaderBoards(i) do
            local text, otype, done = GetQuestLogLeaderBoard(j, i)
            DEFAULT_CHAT_FRAME:AddMessage("      - " .. tostring(text) ..
               " (type=" .. tostring(otype) .. ", done=" .. tostring(done) .. ")")
         end
      end
   end
   local n = 0
   for _ in pairs(CBH.hotZones) do n = n + 1 end
   CBH.print("Hot zones matched: " .. n .. ". If your callboard quest is missing, report its exact text.")
end

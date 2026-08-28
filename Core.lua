-- CallboardHunter Core: namespace, saved vars, events, slash commands.
CallboardHunter = {
   QuestWatcher = {}, SpawnDB = {}, Arrow = {}, Detector = {}, Announce = {},
   hotZones = {},    -- [zoneKey] = {have=n, need=m, questIndex=i}
   visited = {},     -- [pointKey] = true (runtime only)
   forcedZone = nil, -- set by /cbh track
}
local CBH = CallboardHunter

local DB_VERSION = 1
local DEFAULTS = {
   version = DB_VERSION,
   options = { arrow = true, sound = true, partyAnnounce = false, arrowPos = nil },
   learned = {},      -- rare sightings: [zone][npcID/name] = {points}
   learnedKills = {}, -- callboard kill objectives: [zone][objectiveName] = {points}
   cardZones = {},    -- [objectiveName] = zone, harvested from callboard cards
   callboards = {},   -- learned callboard locations: { {zone=, x=, y=}, ... }
   portOverrides = {},-- [objectiveZone] = checkpointZone to route via instead
   checkpointBlock = {}, -- [lowercase name] = true: never route/port to this
   questPatterns = nil,
}

local function CopyDefaults(src, dst)
   for k, v in pairs(src) do
      if type(v) == "table" then
         if type(dst[k]) ~= "table" then dst[k] = {} end
         CopyDefaults(v, dst[k])
      elseif dst[k] == nil then
         dst[k] = v
      end
   end
end

function CBH.print(msg)
   DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CallboardHunter|r: " .. tostring(msg))
end

-- Set/clear the home callboard (the checkpoint nearest where you stand).
function CBH.SetHomeHere()
   SetMapToCurrentZone()
   local x, y = GetPlayerMapPosition("player")
   if not x or (x == 0 and y == 0) then
      CBH.print("Can't read your position here - stand at your preferred callboard"
         .. " / flight point (outdoors) and try again.")
      return false
   end
   CBH.db.home = { zone = GetRealZoneText(), x = x, y = y }
   CBH.print("Home set: " .. GetRealZoneText() .. ". The Callboard port button"
      .. " (and /cbh home) now bring you to the checkpoint nearest here.")
   return true
end

function CBH.ClearHome()
   CBH.db.home = nil
   CBH.print("Home cleared - Callboard port uses the nearest learned board again.")
end

-- A checkpoint the player has blocked (e.g. one that drops you INSIDE an
-- instance, like Azjol-Nerub, vs an entrance you can mount at, like Ulduar).
-- Substring match so "azjol" blocks "Azjol-Nerub". FindCheckpoints skips these.
function CBH.IsBlockedCheckpoint(name)
   if not name then return false end
   local blocked = CBH.db and CBH.db.checkpointBlock
   if not blocked then return false end
   local low = string.lower(name)
   for key in pairs(blocked) do
      if key ~= "" and string.find(low, key, 1, true) then return true end
   end
   return false
end

-- The player's position IN THEIR OWN ZONE, for learning spawn/kill coordinates.
--
-- GetPlayerMapPosition reports against whatever map is DISPLAYED, not the zone
-- you're standing in. The old idiom here was "if the map isn't shown, point it
-- at the current zone" - which silently did nothing whenever the map WAS open on
-- another zone (CBH itself leaves it that way after a port). The read then came
-- back 0,0 and every rare sighting during that window was dropped on the floor.
-- That is a large part of why the learned rare database ends up incomplete.
--
-- So: point the map at the player's zone, read, then put the player's view back
-- exactly where it was. Returns nil when there's genuinely no position (inside
-- an instance, or a map with no player coords).
function CBH.PlayerZonePos()
   -- Never fight the Advisor for the map while a port is mid-flight; it drives
   -- the map through a retry state machine and a stray SetMapZoom breaks it.
   -- Skipping one sighting is much cheaper than a mis-routed teleport.
   local adv = CBH.Advisor
   if adv and (adv.portBusy or adv.portAt) then return nil end
   local wasShown = WorldMapFrame and WorldMapFrame:IsShown()
   local c, z = GetCurrentMapContinent(), GetCurrentMapZone()
   SetMapToCurrentZone()
   local x, y = GetPlayerMapPosition("player")
   -- Restore the user's view only if we actually moved it while they were looking.
   if wasShown and c and z
      and (GetCurrentMapContinent() ~= c or GetCurrentMapZone() ~= z) then
      SetMapZoom(c, z)
   end
   if not x or (x == 0 and y == 0) then return nil end
   return x, y
end

-- Quest POI position on the currently displayed map, handling both known
-- QuestPOIGetIconInfo signatures.
function CBH.GetQuestPOI(questID)
   if not (questID and QuestPOIGetIconInfo) then return end
   local a, b, c = QuestPOIGetIconInfo(questID)
   if type(a) == "number" and type(b) == "number"
      and a > 0 and a <= 1 and b > 0 and b <= 1 then
      return a, b            -- (posX, posY, ...)
   elseif type(b) == "number" and type(c) == "number"
      and b > 0 and b <= 1 and c > 0 and c <= 1 then
      return b, c            -- (completed, posX, posY)
   end
end

-- Run a module function, printing each unique error once (WoW hides Lua errors
-- by default, which makes silent failures invisible without this).
local seenErrors = {}
function CBH.safeCall(fn, ...)
   if not fn then return end
   local ok, err = pcall(fn, ...)
   if not ok and not seenErrors[tostring(err)] then
      seenErrors[tostring(err)] = true
      CBH.print("|cffff3333ERROR:|r " .. tostring(err))
   end
end

local function OnEvent(self, event, ...)
   if event == "ADDON_LOADED" then
      local name = ...
      if name == "CallboardHunter" then
         if type(CallboardHunterDB) ~= "table" then CallboardHunterDB = {} end
         if CallboardHunterDB.version ~= DB_VERSION then
            local learned = CallboardHunterDB.learned
            CallboardHunterDB = { learned = learned }
         end
         CopyDefaults(DEFAULTS, CallboardHunterDB)
         CBH.db = CallboardHunterDB
         -- Seed dungeon checkpoints that drop you INSIDE (useless for outdoor
         -- travel) as blocked, ONCE each. Auto-routing skips them unless the
         -- active quest is for that dungeon; manual map-clicks are unaffected.
         -- Per-flag guards so a later /cbh unblock sticks across reloads.
         CBH.db.checkpointBlock = CBH.db.checkpointBlock or {}
         if not CBH.db.seededBlocks then
            CBH.db.checkpointBlock["azjol-nerub"] = true
            CBH.db.seededBlocks = true
         end
         if not CBH.db.seededBlocks2 then
            CBH.db.checkpointBlock["ahn'kahet"] = true
            CBH.db.seededBlocks2 = true
         end
      end
   elseif event == "PLAYER_LOGIN" then
      CBH.safeCall(CBH.Announce.Init)
      CBH.safeCall(CBH.Arrow.Init)
      CBH.safeCall(CBH.QuestWatcher.Update, true)
   elseif event == "QUEST_LOG_UPDATE" then
      CBH.safeCall(CBH.QuestWatcher.Update)
   elseif event == "ZONE_CHANGED_NEW_AREA" then
      CBH.visited = {}
      CBH.safeCall(CBH.Arrow.Refresh)
   elseif event == "UPDATE_MOUSEOVER_UNIT" then
      CBH.safeCall(CBH.Detector.OnMouseover)
   elseif event == "PLAYER_TARGET_CHANGED" then
      CBH.safeCall(CBH.Detector.OnTargetChanged)
   elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
      CBH.safeCall(CBH.Detector.OnCombatLog, ...)
   elseif event == "PLAYER_REGEN_ENABLED" then
      CBH.safeCall(CBH.Announce.OnRegenEnabled)
   end
end

CBH.frame = CreateFrame("Frame")
CBH.frame:SetScript("OnEvent", OnEvent)
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "QUEST_LOG_UPDATE",
      "ZONE_CHANGED_NEW_AREA", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED",
      "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_REGEN_ENABLED" }) do
   CBH.frame:RegisterEvent(e)
end

SLASH_CALLBOARDHUNTER1 = "/cbh"
SlashCmdList["CALLBOARDHUNTER"] = function(line)
   local _, _, cmd, arg = string.find(line or "", "^%s*(%S*)%s*(.-)%s*$")
   cmd = string.lower(cmd or "")
   if cmd == "scan" then
      if CBH.QuestWatcher.Scan then CBH.QuestWatcher.Scan() end
   elseif cmd == "track" and arg ~= "" then
      CBH.forcedZone = arg
      CBH.print("Tracking forced zone: " .. arg)
      if CBH.Arrow.Refresh then CBH.Arrow.Refresh() end
   elseif cmd == "untrack" then
      CBH.forcedZone = nil
      CBH.visited = {}
      CBH.print("Forced tracking cleared.")
      if CBH.Arrow.Refresh then CBH.Arrow.Refresh() end
   elseif cmd == "debug" then
      CBH.forcedZone = GetRealZoneText()
      CBH.print("Debug: treating current zone as hot (" .. CBH.forcedZone .. ")")
      if CBH.Arrow.Refresh then CBH.Arrow.Refresh() end
   elseif cmd == "arrow" then
      CBH.db.options.arrow = not CBH.db.options.arrow
      CBH.print("Arrow " .. (CBH.db.options.arrow and "ON" or "OFF"))
      if CBH.Arrow.Refresh then CBH.Arrow.Refresh() end
   elseif cmd == "sound" then
      CBH.db.options.sound = not CBH.db.options.sound
      CBH.print("Sound " .. (CBH.db.options.sound and "ON" or "OFF"))
   elseif cmd == "party" then
      CBH.db.options.partyAnnounce = not CBH.db.options.partyAnnounce
      CBH.print("Party announce " .. (CBH.db.options.partyAnnounce and "ON" or "OFF"))
   elseif cmd == "next" then
      if CBH.Arrow.Next then CBH.Arrow.Next() end
   elseif cmd == "port" then
      if CBH.Advisor and CBH.Advisor.Port then CBH.safeCall(CBH.Advisor.Port, arg) end
   elseif cmd == "portscan" then
      if CBH.Advisor and CBH.Advisor.PortScan then CBH.safeCall(CBH.Advisor.PortScan) end
   elseif cmd == "obj" then
      if CBH.Advisor and CBH.Advisor.DumpObjectives then CBH.safeCall(CBH.Advisor.DumpObjectives) end
   elseif cmd == "portvia" then
      if CBH.Advisor and CBH.Advisor.PortVia then CBH.safeCall(CBH.Advisor.PortVia, arg) end
   elseif cmd == "block" then
      CBH.db.checkpointBlock = CBH.db.checkpointBlock or {}
      if arg == "" then
         CBH.print("Usage: /cbh block <checkpoint name>  (e.g. /cbh block Azjol-Nerub)."
            .. " Blocks a checkpoint from being routed/ported to - use it for ones"
            .. " that drop you INSIDE an instance.")
      else
         CBH.db.checkpointBlock[string.lower(arg)] = true
         CBH.print("Blocked checkpoint '" .. arg .. "'. It won't be chosen for ports."
            .. " (/cbh unblock " .. arg .. " to undo, /cbh blocked to list.)")
      end
   elseif cmd == "unblock" then
      CBH.db.checkpointBlock = CBH.db.checkpointBlock or {}
      if CBH.db.checkpointBlock[string.lower(arg)] then
         CBH.db.checkpointBlock[string.lower(arg)] = nil
         CBH.print("Unblocked '" .. arg .. "'.")
      else
         CBH.print("'" .. tostring(arg) .. "' wasn't blocked. /cbh blocked to list.")
      end
   elseif cmd == "sethome" then
      CBH.SetHomeHere()
   elseif cmd == "config" or cmd == "options" then
      if CBH.OpenConfig then CBH.OpenConfig() else CBH.print("Config panel unavailable.") end
   elseif cmd == "home" then
      if arg == "off" then
         CBH.db.home = nil
         CBH.print("Home cleared - Callboard port uses the nearest learned board again.")
      elseif CBH.db.home then
         if CBH.Advisor and CBH.Advisor.PortToCallboard then
            CBH.safeCall(CBH.Advisor.PortToCallboard)
         end
      else
         CBH.print("No home set. Stand at your preferred callboard and run /cbh sethome.")
      end
   elseif cmd == "blocked" then
      local list = {}
      for k in pairs(CBH.db.checkpointBlock or {}) do list[#list + 1] = k end
      if #list == 0 then
         CBH.print("No checkpoints blocked. /cbh block <name> to block one.")
      else
         table.sort(list)
         CBH.print("Blocked checkpoints: " .. table.concat(list, ", "))
      end
   elseif cmd == "frames" then
      -- Discovery tool for the server's custom UI.
      --   /cbh frames <text>  -> only frames whose text contains <text>, with parent chain
      --   /cbh frames map     -> tree of visible frames under WorldMapFrame (checkpoint POIs)
      local function ParentChain(f)
         local names, p, depth = {}, f, 0
         while p and depth < 6 do
            table.insert(names, tostring(p.GetName and p:GetName() or "?"))
            p = p.GetParent and p:GetParent() or nil
            depth = depth + 1
         end
         return table.concat(names, " < ")
      end
      if string.lower(arg or "") == "map" then
         CBH.print("WorldMapFrame child tree (open the map first):")
         local out = { n = 0 }
         local function walk(f, depth)
            if depth > 5 or out.n > 120 then return end
            for i = 1, select("#", f:GetChildren()) do
               local c = select(i, f:GetChildren())
               if c and c.IsShown and c:IsShown() then
                  out.n = out.n + 1
                  DEFAULT_CHAT_FRAME:AddMessage(string.rep("--", depth) ..
                     tostring(c:GetName()) .. " (" .. c:GetObjectType() .. ")")
                  walk(c, depth + 1)
               end
            end
         end
         walk(WorldMapFrame, 0)
         CBH.print("Dumped " .. out.n .. " map frames.")
      else
         local filter = (arg and arg ~= "") and string.lower(arg) or nil
         CBH.print("Visible frames with text" ..
            (filter and (" matching '" .. filter .. "'") or "") .. ":")
         local f, shown = EnumerateFrames(), 0
         local cap = filter and 200 or 80
         while f and shown < cap do
            if f.IsVisible and f:IsVisible() and f.GetRegions then
               local texts = {}
               for i = 1, select("#", f:GetRegions()) do
                  local r = select(i, f:GetRegions())
                  if r and r.GetObjectType and r:GetObjectType() == "FontString" then
                     local t = r:GetText()
                     if t and t ~= "" then table.insert(texts, t) end
                  end
               end
               local joined = table.concat(texts, " | ")
               if #texts > 0 and (not filter or string.find(string.lower(joined), filter, 1, true)) then
                  shown = shown + 1
                  DEFAULT_CHAT_FRAME:AddMessage("  [" .. ParentChain(f) .. "] " ..
                     string.sub(joined, 1, 150))
               end
            end
            f = EnumerateFrames(f)
         end
         CBH.print("Dumped " .. shown .. " frames.")
      end
   elseif cmd == "log" then
      if arg == "clear" then
         CBH.db.log = {}
         CBH.print("Usage log cleared.")
      else
         local n = tonumber(arg) or 15
         local l = CBH.db.log or {}
         CBH.print("Usage log (" .. #l .. " entries; full log saves to disk on /reload):")
         for i = math.max(1, #l - n + 1), #l do
            local e = l[i]
            DEFAULT_CHAT_FRAME:AddMessage("  " .. (e.when or "?") .. " ["
               .. (e.zone or "?") .. "] " .. tostring(e.msg))
         end
      end
   elseif cmd == "reset" then
      CallboardHunterDB = nil
      CBH.print("Options reset. /reload to apply.")
   else
      CBH.print("/cbh scan | port [zone] | portvia <zone> | next | obj | track <zone> | untrack | debug | arrow | sound | party | reset")
   end
end

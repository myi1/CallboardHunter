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
   elseif cmd == "reset" then
      CallboardHunterDB = nil
      CBH.print("Options reset. /reload to apply.")
   else
      CBH.print("/cbh scan | track <zone> | untrack | debug | next | port | arrow | sound | party | reset")
   end
end

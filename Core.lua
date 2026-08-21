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
   learned = {},
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
      if CBH.Announce.Init then CBH.Announce.Init() end
      if CBH.Arrow.Init then CBH.Arrow.Init() end
      if CBH.QuestWatcher.Update then CBH.QuestWatcher.Update() end
   elseif event == "QUEST_LOG_UPDATE" then
      if CBH.QuestWatcher.Update then CBH.QuestWatcher.Update() end
   elseif event == "ZONE_CHANGED_NEW_AREA" then
      CBH.visited = {}
      if CBH.Arrow.Refresh then CBH.Arrow.Refresh() end
   elseif event == "UPDATE_MOUSEOVER_UNIT" then
      if CBH.Detector.OnMouseover then CBH.Detector.OnMouseover() end
   elseif event == "PLAYER_TARGET_CHANGED" then
      if CBH.Detector.OnTargetChanged then CBH.Detector.OnTargetChanged() end
   elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
      if CBH.Detector.OnCombatLog then CBH.Detector.OnCombatLog(...) end
   elseif event == "PLAYER_REGEN_ENABLED" then
      if CBH.Announce.OnRegenEnabled then CBH.Announce.OnRegenEnabled() end
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
   elseif cmd == "reset" then
      CallboardHunterDB = nil
      CBH.print("Options reset. /reload to apply.")
   else
      CBH.print("/cbh scan | track <zone> | untrack | debug | arrow | sound | party | reset")
   end
end

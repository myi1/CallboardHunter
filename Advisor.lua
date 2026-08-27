-- CallboardHunter Advisor: annotates the Objectives Board cards and finds
-- checkpoint teleports on the world map. Frame names discovered via /cbh frames:
-- cards = ObjectivesMainFrame > ObjectiveFrame1..3 (anonymous Select buttons);
-- checkpoints = anonymous Buttons on WorldMapButton (Blizzard POIs are named).
local CBH = CallboardHunter
local Advisor = CBH.Advisor or {}
CBH.Advisor = Advisor

-- ---------------------------------------------------------------- card advisor

-- Usage log: every port decision writes to SavedVariables so bugs can be
-- analyzed offline from a whole session at once (/cbh log to view in-game).
function CBH.Log(cat, msg)
   if not CBH.db then return end
   CBH.db.log = CBH.db.log or {}
   local l = CBH.db.log
   l[#l + 1] = { t = time(), when = date("%H:%M:%S"),
                 zone = GetRealZoneText(), cat = cat, msg = msg }
   while #l > 500 do table.remove(l, 1) end
end

local function CardTexts(card)
   local texts = {}
   for i = 1, select("#", card:GetRegions()) do
      local r = select(i, card:GetRegions())
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then
         local t = r:GetText()
         if t and t ~= "" then table.insert(texts, t) end
      end
   end
   return texts
end

local function CountPoints(zone, name)
   local mobs = CBH.db and CBH.db.learnedKills and CBH.db.learnedKills[zone]
   local list = mobs and mobs[name]
   return list and #list or 0
end

local function BuildNote(desc)
   -- "Kill 10 Azure Manashaper in Crystalsong Forest." (period sometimes absent)
   local _, _, n, mob, zone = string.find(desc, "^Kill (%d+) (.-) in (.-)%.?$")
   if mob then
      if CBH.db then CBH.db.cardZones[mob] = zone end
      local pts = CountPoints(zone, mob)
      local here = (GetRealZoneText() == zone) and " (current zone)" or ""
      if pts > 0 then
         return "|cff30ff00Known camp: " .. pts .. " spot" .. (pts > 1 and "s" or "") ..
            " in " .. zone .. here .. "|r"
      end
      return "|cffffff00No camp data yet - " .. zone .. here .. "|r"
   end
   -- "Slay Kelthuzad in Naxxramas."
   local _, _, boss, place = string.find(desc, "^Slay (.-) in (.-)%.?$")
   if boss then
      return "|cffaaaaaaDungeon/raid: " .. place .. "|r"
   end
   -- "Collect 40 Icethorn."
   local _, _, cn, item = string.find(desc, "^Collect (%d+) (.-)%.?$")
   if item then
      return "|cffaaaaaaCollection: " .. item .. "|r"
   end
   -- Rare trophy cards mention "Rare"
   if string.find(string.lower(desc), "rare") then
      return "|cff30ff00Rare hunt - arrow will guide|r"
   end
   return nil
end

local function RefreshCards()
   for i = 1, 3 do
      local card = _G["ObjectiveFrame" .. i]
      if card and card:IsShown() then
         local note
         for _, t in ipairs(CardTexts(card)) do
            note = BuildNote(t)
            if note then break end
         end
         if not card.cbhNote then
            card.cbhNote = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            card.cbhNote:SetPoint("BOTTOM", card, "BOTTOM", 0, 92) -- clear of the Select button
            card.cbhNote:SetWidth(card:GetWidth() - 50)
         end
         card.cbhNote:SetText(note or "")
      end
   end
end

-- ------------------------------------------------------------- port button

local portBtn
local function EnsurePortButton()
   if portBtn or not (CBH.db and CBH.db.options) then return end
   portBtn = CreateFrame("Button", "CallboardHunterPortButton", UIParent, "UIPanelButtonTemplate")
   portBtn:SetWidth(120); portBtn:SetHeight(22)
   portBtn:SetText("Port: checkpoint")
   portBtn:SetMovable(true)
   portBtn:RegisterForDrag("RightButton") -- right-drag moves, left-click ports
   portBtn:SetScript("OnDragStart", function(self) self:StartMoving() end)
   portBtn:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local _, _, _, x, y = self:GetPoint()
      CBH.db.options.portBtnPos = { x = x, y = y }
   end)
   local pos = CBH.db.options.portBtnPos
   if pos then portBtn:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
   else portBtn:SetPoint("CENTER", UIParent, "CENTER", 0, 130) end
   portBtn:SetScript("OnClick", function(self)
      if self.mode == "board" then
         CBH.safeCall(Advisor.PortToCallboard)
      else
         CBH.safeCall(Advisor.Port)
      end
   end)
   portBtn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      if self.mode == "board" then
         GameTooltip:AddLine("Travel to the callboard")
         GameTooltip:AddLine("Left-click: port to the checkpoint nearest a callboard you have used.", 1, 1, 1, true)
      else
         GameTooltip:AddLine("Travel to your objective")
         GameTooltip:AddLine("Left-click: port to the checkpoint nearest your callboard objective.", 1, 1, 1, true)
      end
      GameTooltip:AddLine("Right-click drag: move this button.", 0.7, 0.7, 0.7, true)
      GameTooltip:Show()
   end)
   portBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
   portBtn:Hide()
end

-- Remember where callboards are: called while an Objectives Board is open.
local function LearnCallboard()
   if not (CBH.db and CBH.db.callboards) then return end
   if not WorldMapFrame:IsShown() then SetMapToCurrentZone() end
   local x, y = GetPlayerMapPosition("player")
   if not x or (x == 0 and y == 0) then return end
   local zone = GetRealZoneText()
   for _, b in ipairs(CBH.db.callboards) do
      if b.zone == zone then
         local dx, dy = b.x - x, b.y - y
         if (dx * dx + dy * dy) < 0.0009 then return end -- same board
      end
   end
   table.insert(CBH.db.callboards, { zone = zone, x = x, y = y })
   CBH.print("Callboard location learned: " .. zone .. ". The port button can bring you back here.")
end

local function AnyObjectiveActive()
   if CBH.hotZones and next(CBH.hotZones) then return true end
   for _, ko in pairs(CBH.killObjectives or {}) do
      if not ko.need or (ko.have or 0) < ko.need then return true end
   end
   return false
end

-- Poll for the server frame (created by the ProjectEbonhold addon at its own
-- pace) and keep card notes fresh while the board is open (reroll swaps text
-- without hiding the frame).
local ticker = CreateFrame("Frame")
ticker.t = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
   self.t = self.t + elapsed
   if self.t < 0.5 then return end
   self.t = 0
   local board = _G["ObjectivesMainFrame"]
   if board and board:IsShown() then
      CBH.safeCall(RefreshCards)
      CBH.safeCall(LearnCallboard)
   end
   if Advisor.portAt and GetTime() >= Advisor.portAt then
      Advisor.portAt = nil
      CBH.safeCall(Advisor.DoPort)
   end
   CBH.safeCall(EnsurePortButton)
   if portBtn then
      local label, mode
      if AnyObjectiveActive() then
         mode = "objective"
         local destZone
         if Advisor.ResolveDestination then destZone = Advisor.ResolveDestination() end
         if destZone then Advisor.lastDestZone = destZone end
         label = destZone and ("Port: " .. destZone) or "Port: objective"
      elseif CBH.db and CBH.db.callboards and #CBH.db.callboards > 0 then
         mode = "board"
         label = "Port: Callboard"
      end
      if label then
         portBtn.mode = mode
         if portBtn:GetText() ~= label then
            portBtn:SetText(label)
            local fs = portBtn:GetFontString()
            portBtn:SetWidth(math.max(110, ((fs and fs:GetStringWidth()) or 0) + 26))
         end
         if InCombatLockdown() then portBtn:Disable() else portBtn:Enable() end
         portBtn:Show()
      else
         portBtn:Hide()
      end
   end
end)

-- ------------------------------------------------------------- checkpoint port

-- Invoke a button's OnEnter to populate its tooltip. 3.3.5-era scripts often
-- read the legacy global `this` instead of self, so set it for the call.
local function ReadTooltip(c)
   local onEnter = c:GetScript("OnEnter")
   if not onEnter then return nil, nil, false end
   local prevThis = this
   this = c
   local ok = pcall(onEnter, c)
   this = prevThis
   -- Map elements in 3.3.5 use WorldMapTooltip, everything else GameTooltip.
   local l1 = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText() or ""
   local l2 = GameTooltipTextLeft2 and GameTooltipTextLeft2:GetText() or ""
   if l1 == "" and l2 == "" and WorldMapTooltipTextLeft1 then
      l1 = WorldMapTooltipTextLeft1:GetText() or ""
      l2 = (WorldMapTooltipTextLeft2 and WorldMapTooltipTextLeft2:GetText()) or ""
   end
   -- Ebonhold's checkpoints use their own tooltip frame (found via /cbh frames):
   -- ProjectEbonholdCheckpointTooltip holds "<Name>" / "Click to travel...".
   if l1 == "" and l2 == "" then
      local cpt = _G["ProjectEbonholdCheckpointTooltip"]
      if cpt then
         local texts = {}
         for i = 1, select("#", cpt:GetRegions()) do
            local r = select(i, cpt:GetRegions())
            if r and r.GetObjectType and r:GetObjectType() == "FontString" then
               local t = r:GetText()
               if t and t ~= "" then table.insert(texts, t) end
            end
         end
         l1 = texts[1] or ""
         l2 = texts[2] or ""
         cpt:Hide()
      end
   end
   GameTooltip:Hide()
   if WorldMapTooltip then WorldMapTooltip:Hide() end
   return l1, l2, ok
end

local function FindCheckpoints(diagnose)
   local out = {}
   local stats = { unnamed = 0 }
   if not (WorldMapFrame and WorldMapButton) then return out, stats end
   local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
   local left, top = WorldMapButton:GetLeft(), WorldMapButton:GetTop()
   if not (w and h and left and top) or w == 0 or h == 0 then return out, stats end

   local function inspect(c, parentName)
      stats.unnamed = stats.unnamed + 1
      -- Ebonhold checkpoint buttons carry clean fields (found via /cbh portscan):
      -- checkpointId, nodeName, isUnlocked, isFactionAllowed.
      local cpId = rawget(c, "checkpointId")
      local nodeName = rawget(c, "nodeName")
      local unlocked = rawget(c, "isUnlocked")
      local faction = rawget(c, "isFactionAllowed")
      local isCP = (cpId ~= nil) or (nodeName ~= nil and unlocked ~= nil)
      if not isCP then
         -- Fallback for builds without those fields: tooltip scrape.
         local l1, l2 = ReadTooltip(c)
         local combined = string.lower((l1 or "") .. " " .. (l2 or ""))
         if string.find(combined, "not yet unlocked", 1, true) then
            isCP, unlocked, nodeName = true, false, (l1 ~= "" and l1) or "Checkpoint"
         elseif string.find(combined, "click to travel", 1, true) then
            isCP, unlocked, nodeName = true, true, (l1 ~= "" and l1) or "Checkpoint"
         end
      end
      if diagnose then
         CBH.print("  btn#" .. stats.unnamed .. " [" .. parentName .. "] cp=" ..
            tostring(cpId) .. " name=" .. tostring(nodeName) .. " unlocked=" ..
            tostring(unlocked) .. " faction=" .. tostring(faction) ..
            (isCP and (unlocked ~= false and (faction ~= false and " -> USE" or " -> WRONG FACTION")
            or " -> LOCKED") or ""))
      end
      if isCP then
         if unlocked == false then
            stats.locked = (stats.locked or 0) + 1
         elseif faction ~= false then
            local cx, cy = c:GetCenter()
            if cx and cy then
               table.insert(out, { btn = c, name = nodeName or "Checkpoint",
                  x = (cx - left) / w, y = (top - cy) / h })
            end
         end
      end
   end

   -- The server may parent its checkpoint buttons anywhere under the map;
   -- walk the whole WorldMapFrame tree for unnamed, visible Buttons.
   local function walk(f, depth)
      if depth > 6 then return end
      for i = 1, select("#", f:GetChildren()) do
         local c = select(i, f:GetChildren())
         if c and c.IsShown and c:IsShown() then
            if not c:GetName() and c:GetObjectType() == "Button" then
               inspect(c, tostring(f:GetName() or "?"))
            end
            walk(c, depth + 1)
         end
      end
   end
   walk(WorldMapFrame, 0)
   return out, stats
end

-- Diagnostic: /cbh portscan with the map open.
function Advisor.PortScan()
   if not WorldMapFrame:IsShown() then
      CBH.print("Open the world map first, then run /cbh portscan.")
      return
   end
   CBH.print("Scanning unnamed map buttons:")
   local cps, stats = FindCheckpoints(true)
   CBH.print("Candidates: " .. stats.unnamed .. ", validated checkpoints: " .. #cps)
end

-- All interesting points (rare spawns + learned camps of active objectives)
-- for a given zone, in that zone's normalized coordinates.
local function PointsForZone(zone)
   local pts = {}
   local hot = CBH.QuestWatcher.IsZoneHot and CBH.QuestWatcher.IsZoneHot(zone)
   if hot then
      for _, p in ipairs(CBH.SpawnDB.GetPoints(zone)) do table.insert(pts, p) end
   end
   local mobs = CBH.db and CBH.db.learnedKills and CBH.db.learnedKills[zone]
   if mobs then
      for name, list in pairs(mobs) do
         local ko = (CBH.killObjectives or {})[name]
         if ko and (not ko.need or (ko.have or 0) < ko.need) then
            for _, p in ipairs(list) do table.insert(pts, { x = p[1], y = p[2] }) end
         end
      end
   end
   return pts
end

-- Decide which zone to travel to: explicit arg > current arrow waypoint >
-- active rare zone > zone of a learned camp > zone harvested from a card.
-- Find a zone name mentioned in the quest's title or objective text.
local function ZoneFromQuestText(ko)
   if not ko.questIndex then return end
   local texts = { (GetQuestLogTitle(ko.questIndex)) }
   for j = 1, GetNumQuestLeaderBoards(ko.questIndex) do
      table.insert(texts, (GetQuestLogLeaderBoard(j, ko.questIndex)))
   end
   for _, t in ipairs(texts) do
      if t then
         local lt = string.lower(t)
         for zone in pairs(CBH.SpawnDB.ZONES) do
            if string.find(lt, string.lower(zone), 1, true) then return zone end
         end
      end
   end
end

-- Last resort: sweep every zone map looking for the quest's POI marker.
-- Changes the displayed map, so only used on an actual Port click (which is
-- about to set the map anyway).
local function FindQuestZoneByPOI(questID)
   if not (questID and QuestPOIGetIconInfo) then return end
   for c = 1, select("#", GetMapContinents()) do
      local zones = { GetMapZones(c) }
      for z, zn in ipairs(zones) do
         SetMapZoom(c, z)
         if QuestMapUpdateAllQuests then pcall(QuestMapUpdateAllQuests) end
         local x, y = CBH.GetQuestPOI(questID)
         if x then return zn, x, y end
      end
   end
end

-- Some zones are reached better via an adjacent zone's checkpoint (e.g.
-- Dalaran floats over Crystalsong Forest). Built-in defaults; user overrides win.
local DEFAULT_PORT_VIA = {
   ["Crystalsong Forest"] = "Dalaran",
}
local function PortViaFor(zone)
   if not zone then return nil end
   local u = CBH.db and CBH.db.portOverrides and CBH.db.portOverrides[zone]
   if u == "" then return nil end          -- explicitly cleared
   return u or DEFAULT_PORT_VIA[zone]
end
Advisor.PortViaFor = PortViaFor

local function IsWatched(questIndex)
   if not questIndex or not GetNumQuestWatches then return false end
   for w = 1, GetNumQuestWatches() do
      if GetQuestIndexForWatch(w) == questIndex then return true end
   end
   return false
end
Advisor.IsWatched = IsWatched

-- Resolve one kill objective to (zone, points). On an actual port (allowSweep)
-- the quest's live POI is authoritative - the server can move an objective's
-- area between quests, so it overrides stale learned camps and saved cardZones,
-- and self-heals cardZones for future labels.
local function ResolveKill(name, ko, allowSweep)
   if allowSweep and ko.questID then
      local zn, qx, qy = FindQuestZoneByPOI(ko.questID)
      if zn then
         if CBH.db and CBH.db.cardZones then CBH.db.cardZones[name] = zn end
         return zn, { { x = qx, y = qy } }
      end
   end
   if CBH.db and CBH.db.learnedKills then
      for zone, mobs in pairs(CBH.db.learnedKills) do
         if mobs[name] and #mobs[name] > 0 then return zone, PointsForZone(zone) end
      end
   end
   local zone = (CBH.db and CBH.db.cardZones and CBH.db.cardZones[name])
      or ZoneFromQuestText(ko)
   if zone then return zone, PointsForZone(zone) end
end

-- Pure resolver: returns destZone, points, questID, preferPOI. Callers store
-- what they need; the label ticker must not mutate in-flight port state.
local function ResolveDestination(zoneArg, allowSweep)
   if zoneArg and zoneArg ~= "" then return zoneArg, PointsForZone(zoneArg) end
   if CBH.Arrow.GetTargetXY then
      local tx, ty, isFarm, tname = CBH.Arrow.GetTargetXY()
      if tx then
         local qid, prefer
         if isFarm and tname then
            local ko = (CBH.killObjectives or {})[tname]
            if ko then qid, prefer = ko.questID, true end
         end
         return GetRealZoneText(), { { x = tx, y = ty } }, qid, prefer
      end
   end
   for zone, info in pairs(CBH.hotZones or {}) do
      return zone, PointsForZone(zone), info.questID, false
   end
   -- Active kill objectives, the tracked (watched) quest first - so with
   -- several active, we route to the one the player is actually following.
   local active = {}
   for name, ko in pairs(CBH.killObjectives or {}) do
      if not ko.need or (ko.have or 0) < ko.need then
         table.insert(active, { name = name, ko = ko,
            w = IsWatched(ko.questIndex) and 1 or 0 })
      end
   end
   table.sort(active, function(a, b) return a.w > b.w end)
   for _, e in ipairs(active) do
      local zone, pts = ResolveKill(e.name, e.ko, allowSweep)
      if zone then return zone, pts, e.ko.questID, true end
   end
   return nil, nil
end
Advisor.ResolveDestination = ResolveDestination

-- /cbh portvia [zone|none] - route the current objective's zone via another
-- zone's checkpoint. No arg lists overrides; "none" clears the current one.
function Advisor.PortVia(arg)
   arg = arg and (arg:gsub("^%s+", ""):gsub("%s+$", "")) or ""
   if arg == "" then
      CBH.print("Port-via overrides:")
      local any = false
      for z, v in pairs((CBH.db and CBH.db.portOverrides) or {}) do
         if v ~= "" then any = true; CBH.print("  " .. z .. " -> " .. v) end
      end
      for z, v in pairs(DEFAULT_PORT_VIA) do
         local u = CBH.db and CBH.db.portOverrides and CBH.db.portOverrides[z]
         if u == nil then any = true; CBH.print("  " .. z .. " -> " .. v .. " (default)") end
      end
      if not any then CBH.print("  (none)") end
      CBH.print("Usage: /cbh portvia <checkpoint zone>  (applies to your current objective zone: " ..
         tostring(Advisor.lastDestZone) .. "). /cbh portvia none to clear.")
      return
   end
   local objZone = Advisor.lastDestZone
   if not objZone then
      CBH.print("No current objective zone known - open the board or accept a callboard quest first.")
      return
   end
   CBH.db.portOverrides = CBH.db.portOverrides or {}
   if string.lower(arg) == "none" or string.lower(arg) == "off" then
      CBH.db.portOverrides[objZone] = ""  -- suppress default too
      CBH.print("Cleared port-via for " .. objZone .. ".")
   else
      CBH.db.portOverrides[objZone] = arg
      CBH.print(objZone .. " will now port via " .. arg .. "'s checkpoint.")
   end
end

-- Diagnostic: /cbh obj - ground truth on every active objective and how it resolves.
function Advisor.DumpObjectives()
   CBH.print("Active objectives:")
   for zone, info in pairs(CBH.hotZones or {}) do
      CBH.print("  RARE zone=" .. zone .. " qid=" .. tostring(info.questID))
   end
   local any = false
   for name, ko in pairs(CBH.killObjectives or {}) do
      any = true
      local done = ko.need and (ko.have or 0) >= ko.need
      local cz = CBH.db and CBH.db.cardZones and CBH.db.cardZones[name]
      local camp
      for z, mobs in pairs((CBH.db and CBH.db.learnedKills) or {}) do
         if mobs[name] and #mobs[name] > 0 then camp = z break end
      end
      CBH.print("  KILL '" .. name .. "' " .. tostring(ko.have) .. "/" ..
         tostring(ko.need) .. (done and " |cffff5050[done]|r" or "") ..
         " watched=" .. tostring(IsWatched(ko.questIndex)))
      CBH.print("     cardZone=" .. tostring(cz) .. " textZone=" ..
         tostring(ZoneFromQuestText(ko)) .. " camp=" .. tostring(camp))
   end
   if not any then CBH.print("  (no kill objectives)") end
   CBH.print("Open the map & /cbh port to route by live POI (overrides the above).")
end

-- Point the world map at a zone by name (case-insensitive).
local function SetMapByZoneName(zoneName)
   local want = string.lower(zoneName)
   for c = 1, select("#", GetMapContinents()) do
      local zones = { GetMapZones(c) }
      for z, zn in ipairs(zones) do
         if string.lower(zn) == want then
            SetMapZoom(c, z)
            return true
         end
      end
   end
   return false
end

-- Read quest POI buttons (the numbered map blobs) directly off the map, for
-- clients where QuestPOIGetIconInfo yields nothing.
local function HarvestQuestPOIButtons()
   local out = {}
   local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
   local left, top = WorldMapButton:GetLeft(), WorldMapButton:GetTop()
   if not (w and h and left and top) or w == 0 then return out end
   local function walk(f, depth)
      if depth > 6 then return end
      for i = 1, select("#", f:GetChildren()) do
         local c = select(i, f:GetChildren())
         if c and c.IsShown and c:IsShown() then
            if c:GetObjectType() == "Button" then
               for r = 1, select("#", c:GetRegions()) do
                  local reg = select(r, c:GetRegions())
                  if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                     local t = reg:GetText()
                     if t and string.find(t, "^%d+$") then
                        local cx, cy = c:GetCenter()
                        if cx then
                           table.insert(out, { x = (cx - left) / w, y = (top - cy) / h })
                        end
                     end
                  end
               end
            end
            walk(c, depth + 1)
         end
      end
   end
   walk(WorldMapFrame, 0)
   return out
end

local function DoPort()
   local cps, stats = FindCheckpoints(false)
   local pts = Advisor.portPoints
   Advisor.portPoints = nil
   local routedBy = (pts and #pts > 0) and "camp/waypoint" or "your position"
   -- The quest's own POI marks the CURRENT assignment area. For kill
   -- objectives it overrides learned camps (the server can assign a different
   -- part of the zone each time); otherwise it fills in when no points exist.
   if Advisor.portQuestID then
      if QuestMapUpdateAllQuests then pcall(QuestMapUpdateAllQuests) end
      if QuestPOIUpdateIcons then pcall(QuestPOIUpdateIcons) end
      local px, py = CBH.GetQuestPOI(Advisor.portQuestID)
      local src = "quest area"
      if not px and Advisor.portPreferPOI then
         -- API gave nothing: read the numbered POI button off the map itself.
         local btns = HarvestQuestPOIButtons()
         if #btns > 0 then
            px, py = btns[1].x, btns[1].y
            src = "quest area (map marker)"
         end
      end
      if px and (Advisor.portPreferPOI or not pts or #pts == 0) then
         pts = { { x = px, y = py } }
         routedBy = src
      end
   end
   Advisor.portQuestID = nil
   Advisor.portPreferPOI = false
   CBH.Log("port", "scan: map=" .. tostring(GetMapInfo()) .. " cps=" .. #cps
      .. " locked=" .. (stats.locked or 0) .. " unnamed=" .. (stats.unnamed or 0)
      .. " basis=" .. routedBy .. " pts=" .. ((pts and #pts) or 0)
      .. (pts and pts[1] and string.format(" pt1=%.2f/%.2f", pts[1].x, pts[1].y) or ""))
   if #cps == 0 then
      if (stats.locked or 0) > 0 then
         CBH.Log("port", "FAIL: 0 unlocked checkpoints (" .. stats.locked .. " locked)")
         CBH.print("No unlocked checkpoints on this map (" .. stats.locked ..
            " locked). Visit a meeting stone there to unlock one first.")
      else
         CBH.Log("port", "FAIL: 0 checkpoints, " .. (stats.unnamed or 0) .. " unnamed buttons")
         CBH.print("No checkpoints found (unnamed map buttons: " .. stats.unnamed ..
            "). Run /cbh portscan with the map open and report the output.")
      end
      return
   end
   local best, bestD, viaHit
   -- Port-via override: force the checkpoint whose name matches, if present.
   if Advisor.portViaName then
      local want = string.lower(Advisor.portViaName)
      for _, cp in ipairs(cps) do
         if cp.name and string.find(string.lower(cp.name), want, 1, true) then
            best, viaHit = cp, true
            break
         end
      end
   end
   if not best then
      for _, cp in ipairs(cps) do
         local d
         if pts and #pts > 0 then
            -- Closest checkpoint to ANY objective point in the destination zone.
            for _, p in ipairs(pts) do
               local dx, dy = cp.x - p.x, cp.y - p.y
               local dd = dx * dx + dy * dy
               if not d or dd < d then d = dd end
            end
         else
            local rx, ry = GetPlayerMapPosition("player")
            if not rx or (rx == 0 and ry == 0) then rx, ry = 0.5, 0.5 end
            local dx, dy = cp.x - rx, cp.y - ry
            d = dx * dx + dy * dy
         end
         if not bestD or d < bestD then best, bestD = cp, d end
      end
   end
   local note = (viaHit and Advisor.portViaNote) or ("routed by " .. routedBy)
   Advisor.portViaNote = nil
   Advisor.portViaName = nil
   CBH.print("Traveling to checkpoint: " .. tostring(best.name) .. " (" .. note .. ")")
   local names = {}
   for i = 1, math.min(#cps, 6) do names[i] = tostring(cps[i].name) end
   CBH.Log("port", "CLICK '" .. tostring(best.name) .. "' (" .. note
      .. (bestD and string.format(", d2=%.4f", bestD) or "")
      .. ") candidates: " .. table.concat(names, ", "))
   -- Arrival verification: did the click actually move us within 6s?
   local w = Advisor.portWatch or CreateFrame("Frame")
   Advisor.portWatch = w
   w.t0 = GetTime()
   w.from = tostring(GetRealZoneText()) .. "/" .. tostring(GetSubZoneText())
   w.cp = tostring(best.name)
   -- Already-there guard: if the destination is our current zone and the chosen
   -- checkpoint sits essentially where we stand, the click is a no-op (this was
   -- the largest share of NO-MOVE logs). Report instead of firing a dead click.
   local curZone = GetRealZoneText()
   if curZone and Advisor.lastDestZone and curZone == Advisor.lastDestZone then
      local rx, ry = GetPlayerMapPosition("player")
      if rx and ry and (rx ~= 0 or ry ~= 0) then
         local dx, dy = best.x - rx, best.y - ry
         if (dx * dx + dy * dy) < 0.0016 then -- ~0.04 map units
            CBH.print("Already at the nearest checkpoint in " .. curZone
               .. " (" .. tostring(best.name) .. ") - fly or walk from here.")
            CBH.Log("port", "SKIP: already at '" .. tostring(best.name)
               .. "' in " .. curZone)
            return
         end
      end
   end
   w:SetScript("OnUpdate", function(self)
      local now = tostring(GetRealZoneText()) .. "/" .. tostring(GetSubZoneText())
      if now ~= self.from then
         CBH.Log("port", "OK: " .. self.from .. " -> " .. now
            .. " via '" .. self.cp .. "'")
         self:SetScript("OnUpdate", nil)
      elseif GetTime() - self.t0 > 6 then
         CBH.Log("port", "NO-MOVE: still at " .. now .. " 6s after clicking '"
            .. self.cp .. "'")
         self:SetScript("OnUpdate", nil)
      end
   end)
   best.btn:Click()
end
Advisor.DoPort = DoPort

function Advisor.Port(zoneArg)
   if InCombatLockdown() then
      CBH.print("Cannot travel while in combat.")
      return
   end
   local destZone, pts, qid, prefer = ResolveDestination(zoneArg, true)
   Advisor.lastDestZone = destZone
   Advisor.portPoints = pts
   Advisor.portQuestID = qid
   Advisor.portPreferPOI = prefer or false
   CBH.Log("port", "REQUEST arg='" .. tostring(zoneArg) .. "' -> dest="
      .. tostring(destZone) .. " pts=" .. ((pts and #pts) or 0)
      .. " qid=" .. tostring(qid) .. " prefPOI=" .. tostring(prefer or false))
   -- Port-via: a zone's map can carry a checkpoint named for another zone
   -- (Crystalsong's map has a Dalaran checkpoint). Prefer that named checkpoint
   -- on THIS map rather than switching maps.
   local via = PortViaFor(destZone)
   Advisor.portViaName = (via and via ~= destZone) and via or nil
   Advisor.portViaNote = Advisor.portViaName and (destZone .. " via " .. Advisor.portViaName) or nil
   if not WorldMapFrame:IsShown() then
      -- (ToggleWorldMap does not exist on this client.)
      ShowUIPanel(WorldMapFrame)
   end
   if destZone then
      if not SetMapByZoneName(destZone) then
         CBH.Log("port", "MAP-MISS: no map for '" .. tostring(destZone)
            .. "', falling back to current zone map")
         CBH.print("No map found for zone '" .. tostring(destZone) .. "' - using current map.")
         SetMapToCurrentZone()
      end
   else
      SetMapToCurrentZone()
   end
   -- Checkpoint buttons repopulate when the displayed map changes; scan shortly.
   Advisor.portAt = GetTime() + 0.4
end

-- Travel back to a callboard you have used (prefers one in the current zone).
function Advisor.PortToCallboard()
   if InCombatLockdown() then
      CBH.print("Cannot travel while in combat.")
      return
   end
   local list = (CBH.db and CBH.db.callboards) or {}
   if #list == 0 then
      CBH.print("No callboard location learned yet - open an Objectives Board once.")
      return
   end
   local zone = GetRealZoneText()
   local pick
   for _, b in ipairs(list) do
      if b.zone == zone then pick = b break end
   end
   pick = pick or list[1]
   CBH.Log("port", "CALLBOARD request -> " .. tostring(pick.zone)
      .. string.format(" %.2f/%.2f", pick.x or 0, pick.y or 0))
   Advisor.portPoints = { { x = pick.x, y = pick.y } }
   Advisor.portQuestID = nil
   Advisor.portPreferPOI = false
   if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
   if not SetMapByZoneName(pick.zone) then SetMapToCurrentZone() end
   Advisor.portAt = GetTime() + 0.4
end

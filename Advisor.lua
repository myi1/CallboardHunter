-- CallboardHunter Advisor: annotates the Objectives Board cards and finds
-- checkpoint teleports on the world map. Frame names discovered via /cbh frames:
-- cards = ObjectivesMainFrame > ObjectiveFrame1..3 (anonymous Select buttons);
-- checkpoints = anonymous Buttons on WorldMapButton (Blizzard POIs are named).
local CBH = CallboardHunter
local Advisor = CBH.Advisor or {}
CBH.Advisor = Advisor

-- ---------------------------------------------------------------- card advisor

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
   -- "Kill 10 Azure Manashaper in Crystalsong Forest."
   local _, _, n, mob, zone = string.find(desc, "^Kill (%d+) (.-) in (.+)%.$")
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
   local _, _, boss, place = string.find(desc, "^Slay (.-) in (.+)%.$")
   if boss then
      return "|cffaaaaaaDungeon/raid: " .. place .. "|r"
   end
   -- "Collect 40 Icethorn."
   local _, _, cn, item = string.find(desc, "^Collect (%d+) (.+)%.$")
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
      local l1, l2 = ReadTooltip(c)
      local combined = string.lower((l1 or "") .. " " .. (l2 or ""))
      -- Locked checkpoints also render, with "Not yet unlocked, visit the
      -- meeting stone..." - only "Click to travel" buttons actually teleport.
      local locked = string.find(combined, "not yet unlocked", 1, true)
         or string.find(combined, "unlock this checkpoint", 1, true)
      local label
      if not locked and string.find(combined, "click to travel", 1, true) then
         label = (l1 and l1 ~= "") and l1 or "Checkpoint"
      end
      if locked then stats.locked = (stats.locked or 0) + 1 end
      -- Custom buttons usually carry their data as Lua fields; if the tooltip
      -- route failed, look for checkpoint-ish strings on the button itself.
      local nameField
      if not label and not locked then
         local fieldHit
         for k, v in pairs(c) do
            if type(v) == "string" then
               local lv = string.lower(v)
               if string.find(lv, "not yet unlocked", 1, true) then
                  fieldHit = nil
                  break
               elseif string.find(lv, "click to travel", 1, true) then
                  fieldHit = v
               elseif k == "name" or k == "Name" or k == "label" then
                  nameField = v
               end
            end
         end
         if fieldHit then label = nameField or fieldHit end
      end
      if diagnose then
         CBH.print("  btn#" .. stats.unnamed .. " [" .. parentName .. ", " ..
            math.floor(c:GetWidth() or 0) .. "x" .. math.floor(c:GetHeight() or 0) ..
            "] tooltip: '" .. tostring(l1) .. "' / '" .. tostring(l2) .. "'" ..
            (label and " -> CHECKPOINT" or ""))
         local fields = {}
         for k, v in pairs(c) do
            local tv = type(v)
            if tv == "string" or tv == "number" or tv == "boolean" then
               table.insert(fields, tostring(k) .. "=" .. tostring(v))
            else
               table.insert(fields, tostring(k) .. ":" .. tv)
            end
         end
         if #fields > 0 then
            CBH.print("    fields: " .. string.sub(table.concat(fields, ", "), 1, 220))
         end
         local nt = c.GetNormalTexture and c:GetNormalTexture()
         local tex = nt and nt:GetTexture()
         if tex then CBH.print("    texture: " .. tostring(tex)) end
      end
      if label then
         local cx, cy = c:GetCenter()
         if cx and cy then
            table.insert(out, { btn = c, name = label,
               x = (cx - left) / w, y = (top - cy) / h })
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
local function ResolveDestination(zoneArg)
   Advisor.portQuestID = nil
   Advisor.portPreferPOI = false
   if zoneArg and zoneArg ~= "" then return zoneArg, PointsForZone(zoneArg) end
   if CBH.Arrow.GetTargetXY then
      local tx, ty, isFarm, tname = CBH.Arrow.GetTargetXY()
      if tx then
         if isFarm and tname then
            local ko = (CBH.killObjectives or {})[tname]
            if ko then
               Advisor.portQuestID = ko.questID
               Advisor.portPreferPOI = true
            end
         end
         return GetRealZoneText(), { { x = tx, y = ty } }
      end
   end
   for zone, info in pairs(CBH.hotZones or {}) do
      Advisor.portQuestID = info.questID
      return zone, PointsForZone(zone)
   end
   for name, ko in pairs(CBH.killObjectives or {}) do
      if not ko.need or (ko.have or 0) < ko.need then
         for zone, mobs in pairs((CBH.db and CBH.db.learnedKills) or {}) do
            if mobs[name] and #mobs[name] > 0 then
               Advisor.portQuestID = ko.questID
               Advisor.portPreferPOI = true
               return zone, PointsForZone(zone)
            end
         end
         local zone = CBH.db and CBH.db.cardZones and CBH.db.cardZones[name]
         if zone then
            Advisor.portQuestID = ko.questID
            Advisor.portPreferPOI = true
            return zone, PointsForZone(zone)
         end
      end
   end
   return nil, nil
end
Advisor.ResolveDestination = ResolveDestination

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

local function DoPort()
   local cps, stats = FindCheckpoints(false)
   local pts = Advisor.portPoints
   Advisor.portPoints = nil
   -- The quest's own POI marks the CURRENT assignment area. For kill
   -- objectives it overrides learned camps (the server can assign a different
   -- part of the zone each time); otherwise it fills in when no points exist.
   if Advisor.portQuestID then
      local px, py = CBH.GetQuestPOI(Advisor.portQuestID)
      if px and (Advisor.portPreferPOI or not pts or #pts == 0) then
         pts = { { x = px, y = py } }
      end
   end
   Advisor.portQuestID = nil
   Advisor.portPreferPOI = false
   if #cps == 0 then
      if (stats.locked or 0) > 0 then
         CBH.print("No unlocked checkpoints on this map (" .. stats.locked ..
            " locked). Visit a meeting stone there to unlock one first.")
      else
         CBH.print("No checkpoints found (unnamed map buttons: " .. stats.unnamed ..
            "). Run /cbh portscan with the map open and report the output.")
      end
      return
   end
   local best, bestD
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
   CBH.print("Traveling to nearest checkpoint: " .. tostring(best.name))
   best.btn:Click()
end
Advisor.DoPort = DoPort

function Advisor.Port(zoneArg)
   if InCombatLockdown() then
      CBH.print("Cannot travel while in combat.")
      return
   end
   local destZone, pts = ResolveDestination(zoneArg)
   Advisor.portPoints = pts
   if not WorldMapFrame:IsShown() then
      -- (ToggleWorldMap does not exist on this client.)
      ShowUIPanel(WorldMapFrame)
   end
   if destZone then
      if not SetMapByZoneName(destZone) then
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
   Advisor.portPoints = { { x = pick.x, y = pick.y } }
   if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
   if not SetMapByZoneName(pick.zone) then SetMapToCurrentZone() end
   Advisor.portAt = GetTime() + 0.4
end

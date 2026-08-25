-- CallboardHunter Arrow: HUD arrow pointing at the nearest unvisited spawn point.
local CBH = CallboardHunter
local Arrow = CBH.Arrow

local frame, tex, label, distText
local target -- current point {x,y,name,key}

-- Rotate a square texture about its centre. Angle in radians.
local function RotateTex(t, angle)
   local c, s = 0.5 * math.cos(angle), 0.5 * math.sin(angle)
   t:SetTexCoord(0.5 - c + s, 0.5 - s - c,  -- UL
                 0.5 - c - s, 0.5 - s + c,  -- LL
                 0.5 + c + s, 0.5 + s - c,  -- UR
                 0.5 + c - s, 0.5 + s + c)  -- LR
end

local function PlayerPos()
   if not WorldMapFrame:IsShown() then SetMapToCurrentZone() end
   local x, y = GetPlayerMapPosition("player")
   if x == 0 and y == 0 then return nil end
   return x, y
end

local function PickTarget(zone, px, py)
   local hot = CBH.QuestWatcher.IsZoneHot and CBH.QuestWatcher.IsZoneHot(zone)
   local points = hot and CBH.SpawnDB.GetPoints(zone) or {}
   for _, p in ipairs(CBH.SpawnDB.GetFarmPoints(zone)) do
      table.insert(points, p)
   end
   -- The quest's own POI marks the CURRENT assignment area (Ebonhold can
   -- assign different areas per quest instance) - always a candidate.
   for name, ko in pairs(CBH.killObjectives or {}) do
      if (not ko.need or (ko.have or 0) < ko.need) and ko.questID then
         local qx, qy = CBH.GetQuestPOI(ko.questID)
         if qx then
            table.insert(points, { x = qx, y = qy, name = name, farm = true,
               key = "poi:" .. name })
         end
      end
   end
   local w, h = CBH.SpawnDB.GetZoneSize(zone)
   local best, bestD
   for _, p in ipairs(points) do
      if not CBH.visited[p.key] then
         local dx, dy = p.x - px, p.y - py
         if w and h then dx, dy = dx * w, dy * h else dx, dy = dx * 1000, dy * 700 end
         local d = dx * dx + dy * dy
         if not bestD or d < bestD then best, bestD = p, d end
      end
   end
   return best
end

local function OnUpdate(self, elapsed)
   self.t = (self.t or 0) + elapsed
   if self.t < 0.1 then return end
   self.t = 0

   -- Custom waypoint mode (driven by PallyPilot raid routes and friends):
   -- while set, the arrow just points at the given normalized map coords.
   -- The caller owns arrival detection and chain advancement.
   if Arrow.custom then
      local c = Arrow.custom
      local px, py = PlayerPos()
      if not px then frame:Hide() return end
      frame:Show()
      label:SetText(c.name or "Waypoint")
      local dx, dy = c.x - px, c.y - py
      local bearing = math.atan2(-dx, -dy)
      local facing = GetPlayerFacing() or 0
      RotateTex(tex, bearing - facing)
      distText:SetText(string.format("%.1f", math.sqrt(dx * dx + dy * dy) * 100))
      return
   end

   local zone = GetRealZoneText()
   local hot = CBH.QuestWatcher.IsZoneHot and CBH.QuestWatcher.IsZoneHot(zone)
   local active = hot or Arrow.farmActive
   if not (active and CBH.db and CBH.db.options.arrow) then frame:Hide() return end

   local px, py = PlayerPos()
   if not px then frame:Hide() return end

   if not target or CBH.visited[target.key] then
      target = PickTarget(zone, px, py)
      if not target then
         frame:Hide()
         return
      end
      label:SetText(target.farm and ("Farm: " .. target.name) or target.name)
   end

   local w, h = CBH.SpawnDB.GetZoneSize(zone)
   local dx, dy = target.x - px, target.y - py
   local yards
   if w and h then
      local yx, yy = dx * w, dy * h
      yards = math.sqrt(yx * yx + yy * yy)
   end

   -- Visited when within ~30yd (or 0.02 normalized without dimensions).
   -- Farm hotspots stay live (you keep killing there); only rare spawn
   -- points advance automatically. /cbh next skips either kind.
   if not target.farm and
      ((yards and yards < 30) or (not yards and math.abs(dx) < 0.02 and math.abs(dy) < 0.02)) then
      CBH.visited[target.key] = true
      target = nil
      return
   end

   -- Bearing: 0 = north, pi/2 = west (matches GetPlayerFacing convention).
   -- Calibration: if the arrow points away from targets in-game, negate `angle`.
   local bearing = math.atan2(-dx, -dy)
   local facing = GetPlayerFacing() or 0
   local angle = bearing - facing
   RotateTex(tex, angle)
   distText:SetText(yards and (math.floor(yards) .. " yd") or "")
end

function Arrow.Init()
   frame = CreateFrame("Frame", "CallboardHunterArrow", UIParent)
   frame:SetWidth(64); frame:SetHeight(80)
   frame:SetMovable(true); frame:EnableMouse(true)
   frame:RegisterForDrag("LeftButton")
   frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
   frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local _, _, _, x, y = self:GetPoint()
      CBH.db.options.arrowPos = { x = x, y = y }
   end)
   local pos = CBH.db.options.arrowPos
   if pos then frame:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
   else frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180) end

   tex = frame:CreateTexture(nil, "ARTWORK")
   tex:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
   tex:SetPoint("TOP"); tex:SetWidth(48); tex:SetHeight(48)

   label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
   label:SetPoint("TOP", tex, "BOTTOM", 0, -2)

   distText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
   distText:SetPoint("TOP", label, "BOTTOM", 0, -1)

   frame:SetScript("OnUpdate", OnUpdate)
   frame:Hide()
   Arrow.Refresh()
end

function Arrow.Refresh()
   if not frame then return end
   target = nil
   local zone = GetRealZoneText()
   local hot = CBH.QuestWatcher.IsZoneHot and CBH.QuestWatcher.IsZoneHot(zone)
   local farm = CBH.SpawnDB.GetFarmPoints and CBH.SpawnDB.GetFarmPoints(zone) or {}
   Arrow.farmActive = #farm > 0
   if (hot or Arrow.farmActive) and CBH.db.options.arrow then
      local points = hot and CBH.SpawnDB.GetPoints(zone) or {}
      if #points == 0 and not Arrow.farmActive then
         if not Arrow.warnedZone or Arrow.warnedZone ~= zone then
            Arrow.warnedZone = zone
            CBH.print("No known spawns for " .. zone .. " yet - detection still active; found rares are learned.")
         end
         frame:Hide()
         return
      end
      frame:Show()
   else
      frame:Hide()
   end
end

-- /cbh next: skip the current waypoint (e.g. the spawn spot is camped).
function Arrow.Next()
   if not target then
      CBH.print("No active waypoint to skip.")
      return
   end
   CBH.print("Skipping waypoint at " .. target.name .. ", advancing to the next.")
   CBH.visited[target.key] = true
   target = nil
end

-- Current waypoint (normalized coords, farm flag, objective name), for the
-- checkpoint port.
function Arrow.GetTargetXY()
   if target then return target.x, target.y, target.farm, target.name end
end

-- Public custom-target API (used by PallyPilot raid waypoints).
function Arrow.SetCustom(x, y, name)
   Arrow.custom = { x = x, y = y, name = name }
   if frame then frame:Show() end
end

function Arrow.ClearCustom()
   Arrow.custom = nil
   if frame then frame:Hide() end
end

function Arrow.MarkVisitedNear(name)
   local zone = GetRealZoneText()
   for _, p in ipairs(CBH.SpawnDB.GetPoints(zone)) do
      if p.name == name then CBH.visited[p.key] = true end
   end
   if target and target.name == name then target = nil end
end

-- CallboardHunter config panel — /cbh config. Matches the Ebonhold addon design
-- system: flat dark panel, teal accent, sections, colorblind-safe (words, not
-- color). Controls the same settings as the slash commands.
local CBH = CallboardHunter
-- Every function below reads bare UI.xxx, but nothing in this file ever bound
-- UI to anything - there is no build step to concatenate addon files, so each
-- .lua is its own Lua chunk and UI.lua's `local UI` never left UI.lua. That
-- left the whole panel one `/cbh config` away from "attempt to index a nil
-- value (global 'UI')". Same story for Fav below: every call in this file
-- needs the real CBH.Favourites, not an unbound global.
local UI = CBH.UI
local Fav = CBH.Favourites

local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local TEAL = "|cff33ff99"
local ACCENT = { 0.20, 1.00, 0.60 }
local T_PRIMARY = { 0.86, 0.88, 0.87 }
local T_MUTED = { 0.50, 0.58, 0.55 }

local panel, rows, favRows = nil, {}, {}

-- Fav.StarText colours its brackets for the CARD ground (brassInk / inkSoft -
-- near-black browns tuned to read on bright parchment). Printing that string
-- unmodified on THIS panel, which is the addon's own dark surface, reproduces
-- 1.10.0 in reverse: near-black text on a near-black background. Same bracket
-- glyph - shape still carries the on/off meaning without colour - just
-- recoloured for wood instead of ink.
local function FavGlyph(on)
  return UI.Colour(on and "verdigris" or "muted", on and "[*]" or "[ ]")
end

-- "[74-80]", or "[64]" for a target only ever seen at one level, or "" for a
-- catalogue entry the game never tagged with a level. Mirrors the bracket
-- format /cbh catalogue dump already uses (Export.lua).
local function BandText(lo, hi)
  if not lo then return "" end
  if hi and hi ~= lo then return "[" .. lo .. "-" .. hi .. "]" end
  return "[" .. lo .. "]"
end

local function RefreshConfig()
  if not (panel and CBH.db) then return end
  panel.arrow:SetChecked(CBH.db.options and CBH.db.options.arrow)
  panel.sound:SetChecked(CBH.db.options and CBH.db.options.sound)
  panel.party:SetChecked(CBH.db.options and CBH.db.options.partyAnnounce)

  local home = CBH.db.home
  panel.homeLabel:SetText(home and UI.Colour("brass", home.zone)
    or UI.Colour("muted", "not set - stand at your callboard, then Set"))

  -- Blocked-checkpoint rows.
  local names = {}
  for k in pairs(CBH.db.checkpointBlock or {}) do names[#names + 1] = k end
  table.sort(names)
  local y = 0
  for i, nm in ipairs(names) do
    local row = rows[i]
    if not row then
      row = CreateFrame("Frame", nil, panel.blockContent)
      row:SetWidth(224); row:SetHeight(19)
      row.text = UI.Text(row, "body", UI.TEXT_SECONDARY)
      row.text:SetPoint("LEFT", row, "LEFT", 2, 0)
      row.text:SetWidth(196); row.text:SetJustifyH("LEFT")
      row.del = CreateFrame("Button", nil, row, "UIPanelCloseButton")
      row.del:SetWidth(20); row.del:SetHeight(20)
      row.del:SetPoint("RIGHT", row, "RIGHT", 2, 0)
      rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel.blockContent, "TOPLEFT", 0, -y)
    row.text:SetText(nm)
    local key = nm
    row.del:SetScript("OnClick", function()
      CBH.db.checkpointBlock[key] = nil
      RefreshConfig()
    end)
    row:Show()
    y = y + 19
  end
  for i = #names + 1, #rows do rows[i]:Hide() end
  panel.blockContent:SetHeight(math.max(y, 10))
  if #names == 0 then panel.blockEmpty:Show() else panel.blockEmpty:Hide() end

  -- Favourite rows: the PICKABLE list (bundled 63 targets plus whatever the
  -- catalogue has learned), not just what is already starred. This is where
  -- you add a favourite you have not met on a card yet - the card star can
  -- only toggle a target you are currently looking at.
  local favList = Fav.List()
  local fy = 0
  for i, entry in ipairs(favList) do
    local row = favRows[i]
    if not row then
      row = CreateFrame("Button", nil, panel.favContent)
      row:SetWidth(226); row:SetHeight(19)
      row.text = UI.Text(row, "body", UI.TEXT_SECONDARY)
      row.text:SetPoint("LEFT", row, "LEFT", 2, 0)
      row.text:SetWidth(165); row.text:SetJustifyH("LEFT")
      row.band = UI.Text(row, "meta", UI.TEXT_MUTED, UI.FONT_META)
      row.band:SetPoint("RIGHT", row, "RIGHT", -2, 0)
      row.band:SetWidth(55); row.band:SetJustifyH("RIGHT")
      favRows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel.favContent, "TOPLEFT", 0, -fy)
    local target = entry.target
    row.text:SetText(FavGlyph(entry.favourite) .. " " .. target)
    row.band:SetText(BandText(entry.lo, entry.hi))
    row:SetScript("OnClick", function()
      Fav.Toggle(target)
      RefreshConfig()
    end)
    row:Show()
    fy = fy + 19
  end
  for i = #favList + 1, #favRows do favRows[i]:Hide() end
  panel.favContent:SetHeight(math.max(fy, 10))
  if #favList == 0 then panel.favEmpty:Show() else panel.favEmpty:Hide() end
end
CBH.RefreshConfig = RefreshConfig

local function MakeCheck(name, label, y, onclick)
  local cb = CreateFrame("CheckButton", "CBHCfg" .. name, panel, "UICheckButtonTemplate")
  cb:SetWidth(22); cb:SetHeight(22)
  cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
  local t = _G["CBHCfg" .. name .. "Text"]
  UI.Font(t, "body", UI.TEXT_PRIMARY)
  t:SetText(label)
  cb:SetScript("OnClick", function(self) onclick(self:GetChecked() and true or false) end)
  return cb
end

-- Section labels are set in the condensed face at stamp size: they are
-- structure, not content, so they sit a full tier below anything readable.
local function Section(text, y)
  local f = UI.Text(panel, "stamp", UI.TEXT_MUTED, UI.FONT_META)
  f:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
  f:SetText(text)
end

function CBH.OpenConfig()
  if panel then
    if panel:IsShown() then panel:Hide() else RefreshConfig(); panel:Show() end
    return
  end
  panel = CreateFrame("Frame", "CallboardHunterConfig", UIParent)
  panel:SetWidth(280); panel:SetHeight(536)
  panel:SetPoint("CENTER", UIParent, "CENTER", -160, 0)
  panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function(s) s:StartMoving() end)
  panel:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
  UI.Skin(panel, UI.SURFACE_0, UI.BORDER_STRONG)
  panel:SetFrameStrata("DIALOG")

  local hdr = panel:CreateTexture(nil, "ARTWORK")
  hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
  hdr:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1); hdr:SetHeight(34)
  hdr:SetTexture(UI.SURFACE_1[1], UI.SURFACE_1[2], UI.SURFACE_1[3], 1)
  local hline = panel:CreateTexture(nil, "OVERLAY")
  hline:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, 0)
  hline:SetPoint("TOPRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
  hline:SetHeight(1); hline:SetTexture(UI.BORDER[1], UI.BORDER[2], UI.BORDER[3], 0.10)

  local title = UI.Text(panel, "title", UI.TEXT_PRIMARY)
  title:SetPoint("LEFT", panel, "TOPLEFT", 16, -18)
  title:SetText("Callboard")
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)

  Section("DISPLAY", -44)
  panel.arrow = MakeCheck("Arrow", "Objective arrow", -62,
    function(v) CBH.db.options.arrow = v end)
  panel.sound = MakeCheck("Sound", "Sound on new objective", -84,
    function(v) CBH.db.options.sound = v end)
  panel.party = MakeCheck("Party", "Announce to party", -106,
    function(v) CBH.db.options.partyAnnounce = v end)

  Section("HOME CALLBOARD", -134)
  panel.homeLabel = UI.Text(panel, "body", UI.TEXT_PRIMARY)
  panel.homeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -152)
  panel.homeLabel:SetWidth(240); panel.homeLabel:SetJustifyH("LEFT")

  local setHome = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  setHome:SetWidth(150); setHome:SetHeight(21)
  setHome:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -170)
  setHome:SetText("Set home (stand here)")
  setHome:SetScript("OnClick", function() if CBH.SetHomeHere() then RefreshConfig() end end)
  local clearHome = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  clearHome:SetWidth(66); clearHome:SetHeight(21)
  clearHome:SetPoint("LEFT", setHome, "RIGHT", 6, 0)
  clearHome:SetText("Clear")
  clearHome:SetScript("OnClick", function() if CBH.ClearHome then CBH.ClearHome() end RefreshConfig() end)

  Section("BLOCKED CHECKPOINTS", -204)
  local sub = UI.Text(panel, "meta", UI.TEXT_MUTED, UI.FONT_META)
  sub:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -218)
  sub:SetWidth(248); sub:SetJustifyH("LEFT")
  sub:SetText("Never auto-ported to (they drop you inside). Manual clicks still work.")

  local scroll = CreateFrame("ScrollFrame", "CallboardHunterBlockScroll", panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -248)
  scroll:SetWidth(226); scroll:SetHeight(76)
  panel.blockContent = CreateFrame("Frame", nil, scroll)
  panel.blockContent:SetWidth(226); panel.blockContent:SetHeight(10)
  scroll:SetScrollChild(panel.blockContent)
  panel.blockEmpty = UI.Text(panel, "meta", UI.TEXT_FAINT, UI.FONT_META)
  panel.blockEmpty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -2)
  panel.blockEmpty:SetText("(none)")

  Section("FAVOURITES", -342)
  local favScroll = CreateFrame("ScrollFrame", "CallboardHunterFavScroll", panel, "UIPanelScrollFrameTemplate")
  favScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -360)
  favScroll:SetWidth(226); favScroll:SetHeight(100)
  panel.favContent = CreateFrame("Frame", nil, favScroll)
  panel.favContent:SetWidth(226); panel.favContent:SetHeight(10)
  favScroll:SetScrollChild(panel.favContent)
  panel.favEmpty = UI.Text(panel, "meta", UI.TEXT_FAINT, UI.FONT_META)
  panel.favEmpty:SetPoint("TOPLEFT", favScroll, "TOPLEFT", 2, -2)
  panel.favEmpty:SetText("(none)")

  local hint = UI.Text(panel, "meta", UI.TEXT_MUTED, UI.FONT_META)
  hint:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 20, 46)
  hint:SetText("Add a checkpoint name to block:")

  panel.edit = CreateFrame("EditBox", "CallboardHunterBlockEdit", panel, "InputBoxTemplate")
  panel.edit:SetWidth(180); panel.edit:SetHeight(20)
  panel.edit:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 26, 20)
  panel.edit:SetAutoFocus(false)
  panel.edit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)

  local add = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  add:SetWidth(44); add:SetHeight(21)
  add:SetPoint("LEFT", panel.edit, "RIGHT", 8, 0)
  add:SetText("Add")
  add:SetScript("OnClick", function()
    local txt = panel.edit:GetText()
    if txt and txt ~= "" then
      CBH.db.checkpointBlock = CBH.db.checkpointBlock or {}
      CBH.db.checkpointBlock[string.lower(txt)] = true
      panel.edit:SetText("")
      RefreshConfig()
    end
  end)

  RefreshConfig()
  panel:Show()
end

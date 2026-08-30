-- CallboardHunter Announce: toast, sound, party message, secure click-to-target.
local CBH = CallboardHunter
local Announce = CBH.Announce

local toast, toastText, targetBtn
local pendingMacro -- macrotext queued during combat

function Announce.Init()
   toast = CreateFrame("Frame", "CallboardHunterToast", UIParent)
   toast:SetWidth(320); toast:SetHeight(64)
   toast:SetPoint("TOP", UIParent, "TOP", 0, -140)
   toast:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
   })
   toast:SetBackdropColor(0, 0, 0, 0.75)

   toastText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
   toastText:SetPoint("TOP", toast, "TOP", 0, -10)

   -- Stays a secure button (it runs /targetexact), skinned to match.
   targetBtn = CreateFrame("Button", "CallboardHunterTargetButton", toast,
      "SecureActionButtonTemplate")
   CBH.UI.SkinButton(targetBtn, { height = 22, minWidth = 96 })
   targetBtn:SetPoint("BOTTOM", toast, "BOTTOM", 0, 8)
   targetBtn:SetLabel("Target")
   targetBtn:SetAttribute("type", "macro")

   -- Click anywhere on the toast (outside the button) to dismiss it.
   toast:EnableMouse(true)
   toast:SetScript("OnMouseDown", function(self)
      if not InCombatLockdown() then
         self.expired = nil
         self:Hide()
      end
   end)

   toast:Hide()
end

local function SetMacro(name)
   local macro = "/targetexact " .. name
   if InCombatLockdown() then
      pendingMacro = macro
      targetBtn:SetLabel("in combat")
   else
      targetBtn:SetAttribute("macrotext", macro)
      targetBtn:SetLabel("Target")
   end
end

function Announce.OnRegenEnabled()
   if pendingMacro and targetBtn then
      targetBtn:SetAttribute("macrotext", pendingMacro)
      targetBtn:SetLabel("Target")
      pendingMacro = nil
   end
   -- The toast cannot be hidden during combat (secure child); if it expired
   -- mid-fight, hide it now that combat is over.
   if toast and toast.expired then
      toast.expired = nil
      toast:Hide()
   end
end

function Announce.Show(name, npcID)
   if not toast then return end
   toastText:SetText(name)
   SetMacro(name)
   toast:Show()

   RaidNotice_AddMessage(RaidWarningFrame, name .. " spotted!", ChatTypeInfo["RAID_WARNING"])
   if CBH.db.options.sound then PlaySound("RaidWarning") end
   if CBH.db.options.partyAnnounce and GetNumPartyMembers() > 0 then
      SendChatMessage("Rare spotted: " .. name .. " (" .. GetRealZoneText() .. ")", "PARTY")
   end

   toast.elapsed = 0
   toast.expired = nil
   toast:SetScript("OnUpdate", function(self, e)
      self.elapsed = self.elapsed + e
      if self.elapsed > 8 then
         self:SetScript("OnUpdate", nil)
         if not InCombatLockdown() then
            self:Hide()
         else
            -- Cannot hide a secure button's parent in combat; dim it and let
            -- OnRegenEnabled hide it when the fight ends.
            self.expired = true
            self:SetAlpha(0.4)
         end
      end
   end)
   toast:SetAlpha(1)
end

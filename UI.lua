-- CallboardHunter UI: the shared visual language.
--
-- CBH grew five surfaces in four unrelated styles - a teal-on-charcoal config
-- panel, a gold/parchment route panel, a black tooltip toast, a stock Blizzard
-- button, and stock fonts everywhere. This file is the single source they all
-- draw from, so the addon reads as one product.
--
-- THE WORLD. A callboard is a physical notice board in a hold: contracts pinned
-- under brass tacks, wax-sealed bounties, a stamped travel order, a ledger of
-- tallies. The palette comes from that board - oiled wood, parchment, brass,
-- wax red, verdigris - not from a generic dark-UI theme.
--
-- THE SIGNATURE. Status is a STAMP: a glyph plus a word, never a colour alone.
-- keepsy is colourblind, so colour can only ever reinforce a signal that is
-- already carried by shape and text. That constraint produced the motif.
--
-- ACCENT DISCIPLINE. Brass marks the one actionable thing in a view - the
-- destination. Wax and verdigris are reserved for status. Everything else is
-- structure in wood and parchment. If brass is on two things at once, one of
-- them is wrong.
local CBH = CallboardHunter
local UI = CBH.UI or {}
CBH.UI = UI

-- ---------------------------------------------------------------- surfaces
-- Elevation is a few percent of lightness per step, one hue throughout. You
-- should feel the stacking rather than see it; a visible jump fragments the
-- interface into unrelated boxes.
UI.SURFACE_0 = { 0.078, 0.067, 0.055 }  -- canvas / page
UI.SURFACE_1 = { 0.106, 0.090, 0.075 }  -- in-flow card
UI.SURFACE_2 = { 0.133, 0.114, 0.094 }  -- raised: inputs, the travel order
UI.SURFACE_3 = { 0.161, 0.137, 0.114 }  -- popover / hover

-- Four text tiers. Two is too flat to carry hierarchy.
UI.TEXT_PRIMARY   = { 0.910, 0.863, 0.784 }  -- parchment
UI.TEXT_SECONDARY = { 0.690, 0.604, 0.490 }
UI.TEXT_MUTED     = { 0.490, 0.427, 0.353 }
UI.TEXT_FAINT     = { 0.353, 0.310, 0.259 }

-- ON PARCHMENT. CBH draws on two grounds: its OWN dark panels, and the server's
-- callboard cards, which are light parchment art we do not control. The tiers
-- above are for dark ground only - using them on a card puts pale text on pale
-- paper, which is exactly what shipped in 1.10.0 and was unreadable. Text on a
-- card is INK, and the status colours darken to match.
-- Near-black brown. The card art is bright (~#d8b98a) and these render small,
-- so mid-tones wash out against it - the first pass at 0.165/0.353 was still
-- too light in practice. Ink on paper wants real contrast, not a tint.
UI.INK       = { 0.086, 0.059, 0.031 }  -- primary text on parchment
UI.INK_SOFT  = { 0.196, 0.145, 0.086 }  -- secondary text on parchment

UI.BRASS     = { 0.784, 0.592, 0.247 }  -- the single accent: action, destination
UI.WAX       = { 0.651, 0.227, 0.180 }  -- blocked / failed
UI.VERDIGRIS = { 0.353, 0.561, 0.420 }  -- active / done

-- Borders define an edge without demanding attention. Low alpha over the
-- surface, never a solid hex - a solid border reads as a hard line.
UI.BORDER        = { 0.910, 0.863, 0.784, 0.10 }
UI.BORDER_STRONG = { 0.910, 0.863, 0.784, 0.18 }

-- Chat-line colour codes, so printed output matches the frames.
UI.HEX = {
   -- on the addon's own dark surfaces
   primary = "e8dcc8", secondary = "b09a7d", muted = "7d6d5a",
   brass = "c8973f", wax = "a63a2e", verdigris = "5a8f6b",
   -- on the server's light parchment cards
   ink = "160f08", inkSoft = "322516",
   brassInk = "4a3105", waxInk = "5c150d", verdigrisInk = "14301e",
}
function UI.Colour(key, text)
   return "|cff" .. (UI.HEX[key] or UI.HEX.primary) .. tostring(text) .. "|r"
end

-- ------------------------------------------------------------------ type
-- WoW fonts carry no weight axis, so hierarchy comes from size + colour +
-- outline. FRIZQT for names (it belongs to this world); ARIALN condensed for
-- counts and metadata, where density matters and the narrow face reads as a
-- ledger hand.
UI.FONT_NAME = "Fonts\\FRIZQT__.TTF"
UI.FONT_META = "Fonts\\ARIALN.TTF"

-- ~1.2 steps, rounded to whole pixels. Distinct at a glance, not 15/16/17 mush.
UI.SIZE = { stamp = 10, meta = 11, body = 12, label = 13, head = 14, title = 16, hero = 18 }

local SPACING = 4                        -- base unit; use multiples only
UI.PAD  = { tight = 8, snug = 12, room = 16 }
UI.GAP  = { hair = SPACING, item = SPACING * 2, group = SPACING * 4 }

-- Apply a tier to a FontString. `tier` picks size; `face` picks the typeface.
function UI.Font(fs, tier, colour, face, outline)
   if not fs then return fs end
   fs:SetFont(face or UI.FONT_NAME, UI.SIZE[tier] or UI.SIZE.body, outline or nil)
   if colour then fs:SetTextColor(colour[1], colour[2], colour[3], colour[4] or 1) end
   return fs
end

function UI.Text(parent, tier, colour, face)
   local fs = parent:CreateFontString(nil, "OVERLAY")
   return UI.Font(fs, tier, colour, face)
end

-- --------------------------------------------------------------- surfaces
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

-- A panel at a given elevation. Depth strategy is SURFACE SHIFT plus a hairline
-- border - no shadows anywhere in the addon, so the strategy stays consistent.
function UI.Skin(frame, surface, borderColour)
   frame:SetBackdrop({ bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 } })
   local s = surface or UI.SURFACE_1
   frame:SetBackdropColor(s[1], s[2], s[3], s[4] or 0.96)
   local b = borderColour or UI.BORDER
   frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 0.10)
   return frame
end

function UI.Divider(parent, inset)
   local t = parent:CreateTexture(nil, "OVERLAY")
   t:SetTexture(UI.BORDER[1], UI.BORDER[2], UI.BORDER[3], 0.08)
   t:SetHeight(1)
   t:SetPoint("LEFT", parent, "LEFT", inset or UI.PAD.snug, 0)
   t:SetPoint("RIGHT", parent, "RIGHT", -(inset or UI.PAD.snug), 0)
   return t
end

-- ----------------------------------------------------------------- stamps
-- Status as a glyph AND a word. The colour is redundant reinforcement, never
-- the signal - see the header note on why.
UI.STAMPS = {
   active  = { glyph = ">",  word = "ACTIVE",  colour = UI.VERDIGRIS },
   done    = { glyph = "+",  word = "DONE",    colour = UI.TEXT_MUTED },
   blocked = { glyph = "x",  word = "BLOCKED", colour = UI.WAX },
   locked  = { glyph = "x",  word = "LOCKED",  colour = UI.WAX },
   ready   = { glyph = ">",  word = "READY",   colour = UI.BRASS },
   idle    = { glyph = "-",  word = "IDLE",    colour = UI.TEXT_MUTED },
}

-- Stamp as a chat-safe string, e.g. "> ACTIVE". Pass onParchment=true for text
-- drawn on a callboard card, which is light: the same stamp, darkened so it is
-- legible on paper. The glyph and word never change - only the ground does.
function UI.Stamp(kind, onParchment)
   local s = UI.STAMPS[kind] or UI.STAMPS.idle
   local hex
   if onParchment then
      hex = UI.HEX.inkSoft
      if s.colour == UI.VERDIGRIS then hex = UI.HEX.verdigrisInk
      elseif s.colour == UI.WAX then hex = UI.HEX.waxInk
      elseif s.colour == UI.BRASS then hex = UI.HEX.brassInk end
   else
      hex = UI.HEX.muted
      if s.colour == UI.VERDIGRIS then hex = UI.HEX.verdigris
      elseif s.colour == UI.WAX then hex = UI.HEX.wax
      elseif s.colour == UI.BRASS then hex = UI.HEX.brass end
   end
   return "|cff" .. hex .. s.glyph .. " " .. s.word .. "|r"
end

-- ---------------------------------------------------------------- buttons
-- A stamped travel order, not a stock stone button. The label IS the content -
-- it names where you are going, so the destination is the focal element of the
-- whole addon rather than a generic verb.
function UI.SkinButton(btn, opts)
   opts = opts or {}
   UI.Skin(btn, UI.SURFACE_2, opts.accent and UI.BRASS or UI.BORDER_STRONG)
   btn:SetHeight(opts.height or 24)

   local glyph = UI.Text(btn, "meta", UI.BRASS, UI.FONT_META)
   glyph:SetPoint("LEFT", btn, "LEFT", UI.PAD.snug, 0)
   glyph:SetText(opts.glyph or ">")
   btn.cbhGlyph = glyph

   local label = UI.Text(btn, "label", UI.TEXT_PRIMARY)
   label:SetPoint("LEFT", glyph, "RIGHT", UI.GAP.item, 0)
   btn.cbhLabel = label

   -- Hover lifts one surface step; press nudges down 1px for tactile feedback.
   btn:SetScript("OnEnter", function(self)
      local s = UI.SURFACE_3
      self:SetBackdropColor(s[1], s[2], s[3], 0.98)
      if self.cbhOnEnter then self.cbhOnEnter(self) end
   end)
   btn:SetScript("OnLeave", function(self)
      local s = UI.SURFACE_2
      self:SetBackdropColor(s[1], s[2], s[3], 0.96)
      if self.cbhOnLeave then self.cbhOnLeave(self) end
   end)
   btn:SetScript("OnMouseDown", function(self)
      self.cbhLabel:SetPoint("LEFT", self.cbhGlyph, "RIGHT", UI.GAP.item, -1)
   end)
   btn:SetScript("OnMouseUp", function(self)
      self.cbhLabel:SetPoint("LEFT", self.cbhGlyph, "RIGHT", UI.GAP.item, 0)
   end)

   -- Sized to its content: a button that names a destination must fit it.
   function btn:SetLabel(text)
      self.cbhLabel:SetText(text or "")
      local w = (self.cbhLabel:GetStringWidth() or 0)
         + (self.cbhGlyph:GetStringWidth() or 0)
         + UI.PAD.snug * 2 + UI.GAP.item
      self:SetWidth(math.max(opts.minWidth or 120, math.floor(w + 0.5)))
   end
   function btn:GetLabel() return self.cbhLabel:GetText() end

   function btn:SetEnabledLook(on)
      local c = on and UI.TEXT_PRIMARY or UI.TEXT_FAINT
      self.cbhLabel:SetTextColor(c[1], c[2], c[3])
      local g = on and UI.BRASS or UI.TEXT_FAINT
      self.cbhGlyph:SetTextColor(g[1], g[2], g[3])
   end
   return btn
end

-- The accessibility invariant: status must never be carried by colour alone.
local ADDON = ADDON_DIR
CallboardHunter = {}
local CBH = CallboardHunter
local c, e = loadfile(ADDON .. "/UI.lua"); if not c then error(e) end; c()
local UI = CBH.UI

local fails, n = 0, 0
local function check(label, got, want)
   n = n + 1
   local ok = (got == want)
   print(string.format("%s  %s -> %s%s", ok and "PASS" or "FAIL", label, tostring(got),
      ok and "" or ("   EXPECTED " .. tostring(want))))
   if not ok then fails = fails + 1 end
end

print("== every stamp carries a glyph AND a word ==")
local kinds = { "active", "done", "blocked", "locked", "ready", "idle" }
for _, k in ipairs(kinds) do
   local s = UI.STAMPS[k]
   check(k .. " has a glyph", s.glyph ~= nil and s.glyph ~= "", true)
   check("  " .. k .. " has a word", s.word ~= nil and string.len(s.word) > 2, true)
end

print("")
print("== stamps survive colour being stripped ==")
-- If the colour codes are removed, the meaning must still be readable. This is
-- the whole point: keepsy cannot rely on hue.
for _, k in ipairs(kinds) do
   local plain = string.gsub(UI.Stamp(k), "|c%x%x%x%x%x%x%x%x", "")
   plain = string.gsub(plain, "|r", "")
   check(k .. " readable without colour", string.find(plain, UI.STAMPS[k].word, 1, true) ~= nil, true)
end

print("")
print("== one accent, and it is brass ==")
check("active uses verdigris", UI.STAMPS.active.colour, UI.VERDIGRIS)
check("blocked uses wax", UI.STAMPS.blocked.colour, UI.WAX)
check("ready uses brass", UI.STAMPS.ready.colour, UI.BRASS)
check("done is demoted to muted", UI.STAMPS.done.colour, UI.TEXT_MUTED)

print("")
print("== type scale is genuinely distinct, not mush ==")
local order = { "stamp", "meta", "body", "label", "head", "title", "hero" }
local prev, strictly = nil, true
for _, tier in ipairs(order) do
   local v = UI.SIZE[tier]
   if prev and v <= prev then strictly = false end
   prev = v
end
check("sizes strictly ascend", strictly, true)
check("smallest is legible (>=10)", UI.SIZE.stamp >= 10, true)
check("hero clears body by 6px+", UI.SIZE.hero - UI.SIZE.body >= 6, true)

print("")
print("== four text tiers exist ==")
check("primary ~= secondary", UI.TEXT_PRIMARY[1] ~= UI.TEXT_SECONDARY[1], true)
check("secondary ~= muted", UI.TEXT_SECONDARY[1] ~= UI.TEXT_MUTED[1], true)
check("muted ~= faint", UI.TEXT_MUTED[1] ~= UI.TEXT_FAINT[1], true)

print("")
print("== surfaces step quietly, one hue ==")
local function warm(s) return s[1] > s[3] end
check("surface 0 is warm", warm(UI.SURFACE_0), true)
check("surface 3 is warm", warm(UI.SURFACE_3), true)
check("elevation ascends", UI.SURFACE_0[1] < UI.SURFACE_1[1]
   and UI.SURFACE_1[1] < UI.SURFACE_2[1] and UI.SURFACE_2[1] < UI.SURFACE_3[1], true)
check("no step exceeds 4%", (UI.SURFACE_3[1] - UI.SURFACE_2[1]) < 0.04, true)

print("")
print("== colour helper ==")
check("wraps with the right code", UI.Colour("brass", "Fordragon Hold"),
   "|cffc8973fFordragon Hold|r")
check("unknown key falls back to primary", UI.Colour("nope", "x"), "|cffe8dcc8x|r")

print("")
print("== two grounds: text must be dark on paper, light on wood ==")
-- 1.10.0 shipped parchment-coloured text onto the server's light card art and
-- it was unreadable. Luminance is the guard.
local function lum(c) return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3] end
check("dark-ground text is light", lum(UI.TEXT_PRIMARY) > 0.7, true)
check("  secondary still light", lum(UI.TEXT_SECONDARY) > 0.5, true)
check("parchment-ground text is dark", lum(UI.INK) < 0.10, true)
check("  ink_soft still dark", lum(UI.INK_SOFT) < 0.20, true)
check("ink is far from parchment", lum(UI.TEXT_PRIMARY) - lum(UI.INK) > 0.75, true)

print("")
print("== stamps darken on parchment, and keep their word ==")
local function hexOf(str) return string.match(str, "|cff(%x%x%x%x%x%x)") end
local function hexLum(h)
   local r = tonumber(string.sub(h,1,2),16)/255
   local g = tonumber(string.sub(h,3,4),16)/255
   local b = tonumber(string.sub(h,5,6),16)/255
   return 0.299*r + 0.587*g + 0.114*b
end
for _, k in ipairs({ "active", "blocked", "ready", "idle", "done" }) do
   local onWood  = hexLum(hexOf(UI.Stamp(k, false)))
   local onPaper = hexLum(hexOf(UI.Stamp(k, true)))
   check(k .. " darker on paper than on wood", onPaper < onWood, true)
   check("  " .. k .. " dark enough to read on paper", onPaper < 0.28, true)
   check("  " .. k .. " keeps its word",
      string.find(UI.Stamp(k, true), UI.STAMPS[k].word, 1, true) ~= nil, true)
end

print("")
print("== every chat colour is usable on the ground it names ==")
for _, key in ipairs({ "primary", "secondary", "brass" }) do
   check(key .. " reads on wood", hexLum(UI.HEX[key]) > 0.35, true)
end
for _, key in ipairs({ "ink", "inkSoft", "brassInk", "waxInk", "verdigrisInk" }) do
   check(key .. " reads on paper", hexLum(UI.HEX[key]) < 0.28, true)
end

print("")
print("== measured against the real card art (~#d8b98a) ==")
-- WCAG relative-luminance contrast ratio, so the bar is a number rather than
-- a judgement call. The parchment sample is taken from the callboard card.
local function srgb(v) v = v / 255
   if v <= 0.03928 then return v / 12.92 end
   return ((v + 0.055) / 1.055) ^ 2.4 end
local function relLum(h)
   local r = srgb(tonumber(string.sub(h,1,2),16))
   local g = srgb(tonumber(string.sub(h,3,4),16))
   local b = srgb(tonumber(string.sub(h,5,6),16))
   return 0.2126*r + 0.7152*g + 0.0722*b
end
local function ratio(fg, bg)
   local a, b = relLum(fg), relLum(bg)
   if a < b then a, b = b, a end
   return (a + 0.05) / (b + 0.05)
end
local PARCHMENT = "d8b98a"
for _, key in ipairs({ "ink", "inkSoft", "brassInk", "waxInk", "verdigrisInk" }) do
   local r = ratio(UI.HEX[key], PARCHMENT)
   check(string.format("%s vs parchment >= 4.5:1 (%.1f)", key, r), r >= 4.5, true)
end
check(string.format("ink clears 7:1 (%.1f)", ratio(UI.HEX.ink, PARCHMENT)),
   ratio(UI.HEX.ink, PARCHMENT) >= 7, true)

print("")
if fails > 0 then print(fails .. " FAILURE(S) of " .. n); os.exit(1)
else print("ALL " .. n .. " PASS") end

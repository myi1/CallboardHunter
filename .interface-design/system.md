# CallboardHunter — interface system

## Direction
A bounty board rendered in its own materials. A callboard is a physical notice
board in a hold: contracts pinned under brass tacks, wax-sealed bounties, a
stamped travel order, a ledger of tallies. Oiled wood and parchment, brass for
the one actionable thing, wax red and verdigris reserved for status.

Before this, CBH had four unrelated visual languages — teal-on-charcoal config
panel, gold/parchment route panel, black tooltip toast, stock Blizzard button.
All five surfaces now draw from `UI.lua`.

## Hard constraint
**keepsy is colourblind.** Status is a STAMP — a glyph plus a word — never a
colour alone. Colour is redundant reinforcement of a signal already carried by
shape and text. `ui_test.lua` pins this: every stamp must survive its colour
codes being stripped and stay readable.

## Signature
The stamp (`> ACTIVE`, `+ DONE`, `x BLOCKED`, `> READY`, `- IDLE`) and the
travel order — the Port button names its destination ("Fordragon Hold"), not a
verb ("Port: objective"). The destination is what CBH exists to answer, so it is
the focal element of the whole addon.

## Tokens — all in `UI.lua`
- Surfaces: `SURFACE_0` canvas `.078/.067/.055` → `SURFACE_3` popover `.161/.137/.114`.
  One hue, warm; each step under 4% lightness. Feel the stacking, don't see it.
- Text, four tiers: `TEXT_PRIMARY` parchment → `SECONDARY` → `MUTED` → `FAINT`.
- Accent: `BRASS` `.784/.592/.247` — action and destination only. If brass is on
  two things at once, one is wrong. `WAX` = blocked/failed, `VERDIGRIS` = active.
- Borders: `BORDER` alpha .10, `BORDER_STRONG` alpha .18. Low-alpha over the
  surface, never solid — a solid border reads as a hard line.

## Two grounds — the mistake 1.10.0 made
CBH draws on **its own dark surfaces** (panel, toast, button, arrow) and on the
**server's light parchment cards**, which it does not control. The text tiers
above are for dark ground only. Text on a card is `INK` / `INK_SOFT`, and stamps
take `UI.Stamp(kind, true)` so their colours darken to match.

1.10.0 put parchment-coloured text on the parchment card art and it was
unreadable. `ui_test.lua` now guards it by luminance AND by measured WCAG
contrast against the real card sample (`#d8b98a`): every parchment colour must
clear **4.5:1**, and body ink must clear **7:1**. Ink currently reads 10.2:1.

Mid-tones wash out on that texture at small sizes — the first fix at `#2a1f14`
still looked grey in game. Card notes also sit at `label` size (13) rather than
`meta`, because they compete with a busy parchment texture, and only 16px
narrower than the card (at −50 the stamp glyph clipped and the line wrapped).

## Depth strategy
**Surface shift + hairline border. No shadows anywhere.** WoW backdrops make
shadows expensive and inconsistent; one strategy, held everywhere.

## Type
No weight axis in WoW fonts, so hierarchy = size + colour + outline.
- `FONT_NAME` FRIZQT for names (belongs to this world)
- `FONT_META` ARIALN condensed for counts and metadata — reads as a ledger hand
- Scale ~1.2, whole pixels: stamp 10 · meta 11 · body 12 · label 13 · head 14 ·
  title 16 · hero 18. Section labels sit at `stamp` in the condensed face: they
  are structure, not content.

## Spacing
Base unit 4. `PAD` tight 8 / snug 12 / room 16. `GAP` hair 4 / item 8 / group 16.
Multiples only.

## Component patterns
- `UI.SkinButton(btn, {accent, height, minWidth})` — stamped travel order.
  Glyph left in brass, label in primary. Hover lifts one surface step; press
  nudges the label 1px down. `:SetLabel()` sizes to content (a button naming a
  destination must fit it). `:SetEnabledLook(bool)` for combat lockdown.
  Port button: 26px h · 132 min w · accent border.
- `UI.Skin(frame, surface, border)` — any panel.
- `UI.Text(parent, tier, colour, face)` / `UI.Font(fs, ...)` — never
  `CreateFontString` with a stock font object.
- `UI.Stamp(kind)` — chat-safe glyph+word. `UI.Colour(key, text)` for chat lines,
  so printed output matches the frames.

## Still stock
`Route.lua` keeps its own gold palette (`BRIGHT`/`DIM`) — closest to this
direction already, converge it next. Its panel backdrops at Route.lua:800 and
:1144 should move to `UI.Skin`.

# CallboardHunter — callboard favourites and quest database

**Date:** 2026-08-31
**Status:** approved, ready to plan
**Origin:** StemmyBoo in #addons — *"is there a way to make this auto-reroll for
specific missions you want, or should i still be using a mix of this and the
other cb add-on?"*

## Prior art — read before building

**RavioliCallboard v1.0.43** (Zendan21, actively maintained) already ships:
saved callboard quest routes, auto-reroll until the required quest appears,
auto-select and track, dungeon/raid priority on entering an instance, a learned
quest list to build routes from, loop routes, group tools and quest sharing.

**AutoCallboard** (Disarrayed) did the same and is abandoned — repo pulled,
download 404s. Its behaviour, per its own thread: *"rolling the quests in the
background. It stops at the next targeted quest you have selected in the addon.
It starts as soon as you finish the callboard quest you're on."*

This overlap was raised with the maintainer and building anyway was an explicit
decision. It is recorded here so the choice stays visible, not to reopen it. Note
CBH's dungeon automation (1.8.0) already overlaps Ravioli's dungeon/raid
priority.

## Evidence

Measured from the live catalogue (346 entries, 97 of them CBH's own notes):

- **63 distinct quest targets** observed, against a pool of roughly 117 (quest
  IDs seen in the port log span `600651..600767`).
- Card titles follow `<flavour prefix>: <target>`. Prefixes seen include
  Material Requisition, Bulk Order, Supply Run, Stockpile, Procurement Order,
  Sweep and Clear, No Mercy, End the Threat, Wanted, Dungeon Crawl.
- **The prefix is decorative; the target is the job.** Proven by two targets
  appearing under different prefixes: `Loken` under both *Dungeon Crawl* and
  *Wanted*; `Ashtongue Handler` under *Cleaning House* and *Sweep and Clear*.
  Most targets show once only because the sample is ~250 cards.
- Level bands: 122 entries at 80, 150 at 70–79, 68 at 60–69.
- Classification is weak — 82 `other` plus 67 unclassified, most of which are
  obviously gather (`Bulk Order: Core Leather`) or kill
  (`A Dangerous Quarry: Magister Keldonus`) work. `SpawnDB.ClassifyCard` must
  learn the template forms as part of this work.

Reroll economics (10g 40s, three cards per draw, pool ~117):

| Favourites | Chance per draw | Expected cost per hit |
|---|---|---|
| 1 | ~2.6% | ~400g |
| 5 | ~12% | ~85g |
| 10 | ~24% | ~44g |

The list size dominates the cost. This belongs in the UI as guidance.

## Architecture

`Dungeon.lua` already owns the loop: reroll → verified confirm → wait for cards
to change → match → accept → share, bounded by reroll cap, gold reserve and
board expiry. **Only the match predicate differs for favourites.**

- **`Board.lua`** — the loop extracted into a reusable engine taking a
  `match(cards)` callback and returning the chosen card. Owns the safety rails.
- **`Dungeon.lua`** — calls it with "is this card for the instance I am in".
- **`Favourites.lua`** — calls it with "is this card's target on my list".

One engine, two callers. The rails are inherited rather than reimplemented,
which is the whole reason for the extraction.

## Quest database

`SpawnDB.QUESTS` — bundled list built from the 63 observed targets, each entry
`{ target, kind, lo, hi }`. **Nothing invented**: every row traces to a card
actually seen. At runtime the pickable list is *bundled ∪ catalogue*, so it grows
with play; pooled `/cbh export` data and `tools/wdbquests.js` extracts grow the
bundled half each release.

## Matching

Split the card title at the first colon, discard the prefix, key on the target.
Favouriting `Loken` therefore catches `Dungeon Crawl: Loken` and `Wanted: Loken`.
Titles with no colon match whole. The objective name is also matched, so a quest
already in the log counts as present.

Progress counters are normalised out, as the catalogue already does.

## Hunt behaviour

`/cbh hunt`, or a Hunt button while a board is open. Rerolls until any favourite
appears, takes it, stops. **Explicit start only** — there is no board timer at a
permanent callboard, so nothing may spend gold without being asked in that
moment.

Inherits the existing brakes (reroll cap, gold reserve, cards-not-changing,
verified confirm — never clicking a dialog that is not the reroll one) and adds
one: **refuses to start with an empty favourites list**, which would otherwise be
an unbounded loop with no win condition.

Reports running spend during, and on stop reports total cost and the reason.

## UI

- **A star on each card** while the board is open. Click to favourite that
  target, click again to remove. This is the cheapest way to build a list — you
  favourite things as you meet them.
- **A `/cbh config` section** listing the database grouped by type and level
  band with checkboxes, for picking quests not yet seen. Stars and checkboxes
  are the same underlying set.
- Follows `.interface-design/system.md`: stars are a glyph plus state, never
  colour alone; card-drawn elements use the ink tiers, not the dark-surface ones.

Storage: `db.favourites = { ["Loken"] = true, ... }`, account-wide.

## Testing

fengari suites, extending the existing pattern:

- the engine honours a swapped match callback (dungeon vs favourites)
- target extraction across prefixes, using the real `Loken` and
  `Ashtongue Handler` cases
- a favourite still matches when its progress counter changes
- hunt refuses to start with an empty list
- cap and reserve stop a hunt, and the verified-confirm guard still refuses a
  non-reroll dialog
- the existing 37 dungeon assertions keep passing after the extraction — that is
  the regression risk this design accepts

## Out of scope

- Ordered or looping routes (Ravioli's model). This is an unordered whitelist.
- Group tools, sharing beyond what CBH already does, resync.
- Automatic hunting on quest turn-in.

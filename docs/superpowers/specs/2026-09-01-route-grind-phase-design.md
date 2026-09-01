# Route: a callboard grind phase, a real hardcore switch, and auto-start

**Date:** 2026-09-01
**Status:** approved in conversation, pending written review
**Origin:** keepsy — *"i prefer to do through the zul drak amphitheatre turn in, then i
like to do cb quests… id rather a button to summon CB quest, portal to dalaran,
change to HC 3… and it would be good if that button actually did the mode switch
instead of it asking me to confirm i did it"*

## What the route does today

`Route.lua` walks a fixed prestige lap: switch hardcore tier, port to Dalaran,
three quests, port to Zul'Drak, hand in at The Argent Stand, port back, drop a
tier. It stops there. The two hardcore steps are `kind = "mode"` and carry

```lua
detail = "Mode popup from a starter zone, inn, or capital. No API for this -- tick it when done."
```

with `Route.lua:449` returning `false` because *"mode steps are acknowledged, not
detected"*. Both statements turn out to be wrong — see Evidence.

## Evidence, from the live client

Gathered with `/cbh frames names` and a new `/cbh frames tree`, read back out of
saved variables. All of it is observation, not recall.

`ProjectEbonholdPlayerRunFrame` is shown and contains:

```
text: |cffffffff29,008|r        -- a counter
text: |cff00ff00+827%|r         -- a bonus, almost certainly XP
- ? (Button)
   text: |cffFF4444Hardcore 5|r -- the CURRENT tier, and it is a Button
- ? (Button) x6                 -- siblings, no text of their own
```

`EbonholdQuestTracker` contains:

```
A Life, Lived Through - Runs taken to level 80: 12/14   (also 1/5, 2/3, 1/7, 1/12)
The Amphitheater of Anguish: Yggdras!  - Yggdras Defeated
Make Zangarmarsh Safe Again - Bloodscale Slavedriver slain: 3/10
```

Three things follow:

- **The current hardcore tier is readable.** It is text on a button, so the route
  can show `Hardcore 5 -> 3` instead of asking the player what they are on.
- **The tier control is a Button.** CBH already drives exactly this shape of
  custom UI in `Board.lua` — walk the children, identify the control, click it.
  "No API for this" described the absence of a documented server function, not
  the absence of a drivable frame.
- **Prestige state is visible.** `Runs taken to level 80: N/M` is a counter the
  addon can watch.

The `29,008` figure is *not yet confirmed to be ash*. `Route.lua:70` refers to an
ash gate around `10,771,440`, which is three orders of magnitude larger, so the
two are probably different quantities. This spec therefore reads and **displays**
that number without acting on it.

## The change

### 1. A grind phase

The route gains a second phase that begins when the Zul'Drak turn-in completes
and ends at level 80.

It must **not** assume the chain ends at 64. The player's ash XP nodes move that
landing level, so the phase begins at whatever level the character actually is.

Shape:

- **Entry step, once:** switch to the grind hardcore tier.
- **Repeating pair, until 80:** summon a callboard quest, then port to Dalaran.

The tier switch is deliberately *not* part of the repeating cycle — it happens
once at the start of the grind and is then left alone.

Each step is an ordinary `Route.STEPS` entry with its own button, matching how
every existing step already works. No combined multi-action button.

### 2. The hardcore step acts instead of asking

`kind = "mode"` stops being an acknowledge-only step.

- **Read:** find the tier button under `ProjectEbonholdPlayerRunFrame`, parse
  `Hardcore (%d)` out of its text, and show the real transition.
- **Act:** click the server's own control to perform the switch.
- **Verify:** re-read the tier afterwards and only mark the step done when it
  actually changed. A step that claims success without confirming it is how the
  current "tick it when done" behaviour hides failure.

If clicking the tier button opens a popup rather than switching directly, the
step completes the popup too — under the same discipline `Board.lua` uses for the
reroll confirmation: **never click a dialog whose own content has not identified
it**. Anything unrecognised stops the step and tells the player, rather than
clicking blind.

Manual acknowledgement stays available as a fallback for the case where the
control cannot be found, so a UI change on the server's side degrades to today's
behaviour instead of breaking the route.

### 3. Tier is configuration; ash is a seam, not a feature

`/cbh route hc <n>` already sets the levelling tier. The grind phase gets its own
setting, defaulting to the levelling tier so it is one less thing to configure on
a first run.

The ash-looking counter is **read and displayed** beside the tier, and nothing
depends on it. That proves the reading before anything is built on it, and turns
*"under X ash pick tier N"* into a small later change rather than a guess now.
Choosing a tier automatically from ash is **out of scope**.

### 4. Auto-start

The trigger is deliberately unresolved, because the observation that settles it
has not been taken yet: nobody has dumped the run frame immediately after a
prestige reset.

The plan is to watch the run frame and the tracker's `Runs taken to level 80`
counter for what actually changes on reset, then trigger on that.

**Fallback, if nothing reliable is observable:** on login, if the route is not
started and the character is below the Zul'Drak turn-in's level, offer to start
it — a prompt, not an automatic start. Prompting on a false positive costs one
dismissal; auto-starting on one would hijack a character mid-play.

Implementation therefore takes the observation first and picks the trigger from
what it sees. If the observation is inconclusive, the fallback ships.

## Testing

fengari suites, following the existing pattern. `tools/route_test.lua` and
`tools/cp_test.lua` already drive `Route.lua` head-first against a stubbed API.

- the grind phase begins at the character's actual level, not a constant
- the phase ends at 80
- the tier switch is an entry step and does not repeat with the cycle
- the tier is parsed correctly out of `|cffFF4444Hardcore 5|r`
- the step refuses to mark itself done when the tier did not change
- an unrecognised dialog stops the step instead of being clicked
- a missing tier control degrades to manual acknowledgement rather than erroring
- the existing lap is unchanged when the grind phase is switched off

The frozen `tools/dungeon_test.lua` gate (37 assertions) must stay untouched.

## Out of scope

- Choosing the hardcore tier from ash automatically.
- Any change to the existing levelling lap's order or its quests.
- Automating the callboard quest *choice* — `/cbh hunt` already does that, and
  the grind phase summons the board rather than deciding what to take.

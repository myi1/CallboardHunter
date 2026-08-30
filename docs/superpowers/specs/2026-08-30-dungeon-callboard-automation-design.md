# CallboardHunter — dungeon callboard automation

**Date:** 2026-08-30
**Status:** approved, implementing

## Goal

A donation-shop spell, **Summon Callboard**, places a quest callboard anywhere
(including inside instances). When you enter a dungeon that has a callboard quest
for it, take the tedium out of getting that quest: reroll the board until the
dungeon's quest appears, accept it, and share it with the group.

## Hard constraints discovered before designing

1. **An addon cannot cast the spell.** `CastSpellByName` is protected on 3.3.5
   and requires a hardware event, so "auto-summon on entering the dungeon" is
   impossible. The player casts; CBH takes over from the board appearing. This
   also avoids secure frames and taint entirely.
2. **The board lasts 30 seconds**, and the spell has a **45 second cooldown**
   (from the spell tooltip). The reroll loop is therefore bounded by the board
   despawning no matter how much gold the player has. Gold limits are secondary.
3. Each reroll costs **10g 40s** and opens a confirmation popup.

The board and its buttons are non-secure custom frames, so clicking them from Lua
works — CBH already does exactly this for checkpoint buttons
(`best.btn:Click()`).

## Flow

1. **Entering an instance** — `IsInInstance()` plus `GetRealZoneText()` names the
   dungeon. Print a one-line reminder, once per instance visit.
2. **Player casts Summon Callboard.** CBH already polls for
   `ObjectivesMainFrame`; when it appears while in an instance and automation is
   enabled, the run starts.
3. **Match** — read the three cards with the existing `CardTexts`. A card matches
   when either:
   - its `"Slay <Boss> in <Place>."` place equals the current instance, or
   - it names a known boss of the current dungeon.
4. **Reroll** — no match: click Reroll, confirm, wait for the card text to
   actually change, re-evaluate.
5. **Accept** — click the matching card's Select button.
6. **Share** — on `QUEST_ACCEPTED`, `SelectQuestLogEntry` + `QuestLogPushQuest`,
   only when in a party/raid, once per quest per run.

## Data change

Matching "a boss of *this dungeon*" is impossible with the current
`DUNGEON_ZONE`, which maps names → **zone**: Utgarde Keep and Utgarde Pinnacle
both map to "Howling Fjord", so the zone cannot identify the dungeon.

`SpawnDB.DUNGEONS` becomes the source of truth:

```lua
["Utgarde Keep"] = { zone = "Howling Fjord", bosses = { "Ingvar the Plunderer", ... } }
```

`DUNGEON_ZONE` is derived from it (dungeon name + every boss name → zone), so
routing behaviour is unchanged and one table serves both features. Aliases (e.g.
"The Old Kingdom" for Ahn'kahet) are supported.

## Safety rails

These are requirements, not implementation details.

- **The Confirm click is verified, never blind.** Clicking
  `StaticPopup1Button1` on whatever dialog is open could confirm something
  destructive — deleting an item, abandoning a quest. CBH only clicks a popup
  whose own text identifies it as the reroll confirmation, and stops otherwise.
- **Three independent stops**, whichever hits first: reroll cap (default 10,
  settable to unlimited), gold reserve (never spend below it), and the 30s board
  expiry.
- **Stops and reports** on: board gone, insufficient gold, cap reached, no Reroll
  button found (server UI changed), or cards not changing after a reroll.
- **Spend is always reported** — a running line during the loop and a final
  "spent Xg over N rerolls".
- **Share-once guard** per quest per run, so a reroll loop or `/reload` cannot
  re-spam the group.
- **Off by default.** Automated click loops can look like botting to a server;
  opting in is the player's decision to make knowingly.
- **Never runs outside an instance**, and never while the player is not the one
  who summoned the board.

## Settings

`/cbh dungeon` — `on` | `off` | `status` | `rerolls <n|unlimited>` |
`reserve <gold>` | `share on|off`. The enable toggle also appears in
`/cbh config`.

Defaults: automation **off**, reroll cap **10**, gold reserve **0**, share **on**.

## Testing

fengari (Lua VM) against the real module with stubbed board frames, popups and
money:

- a card naming the instance matches; a card naming one of its bosses matches;
  an unrelated card does not
- reroll cap stops the loop and reports the spend
- gold reserve stops the loop before spending below it
- the confirm guard **refuses** a popup that is not the reroll confirmation
- share happens once, only in a group
- board despawning mid-loop stops cleanly

## Out of scope

- Casting the spell (impossible; see constraints)
- Re-summoning after the 30s window (needs another manual cast and a 45s cooldown)
- Deciding *which* dungeons have callboard quests ahead of time — the board tells
  us when it is up

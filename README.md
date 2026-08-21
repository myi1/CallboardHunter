# CallboardHunter

Companion addon for Project Ebonhold's rare-mob callboard quests (WoW 3.3.5a).
Reads zone-scoped rare quests from your quest log ("Slay N rares in <Zone>"),
points a HUD arrow at the nearest known rare spawn in that zone, announces
rares when they are actually detected near you, and gives you a one-click
Target button. Kills of counted rares advance the arrow and print progress.

Detected rares (including Ebonhold's custom ones) have their positions
**learned** into your SavedVariables, so the spawn database improves the more
you hunt. Bundled data covers the classic Northrend and Outland silver-dragon
rares (IDs matched to RareSpawnOverlay's list).

## Slash commands

| Command | Effect |
| --- | --- |
| `/cbh` | help |
| `/cbh scan` | dump quest log titles/objectives to chat (pattern tuning) |
| `/cbh track <zone>` | force a zone hot without a quest |
| `/cbh untrack` | clear forced zone + visited points |
| `/cbh debug` | treat the current zone as hot |
| `/cbh arrow` / `sound` / `party` | toggle arrow / sound / party announce |
| `/cbh reset` | reset options (keeps learned spawns), then `/reload` |

## First run

1. Pick up a rare callboard quest, then run `/cbh scan`.
2. If "Hot zones matched" is 0, the quest text doesn't contain both the word
   "rare" and a zone name this addon knows — copy the printed quest lines and
   report them so the match patterns can be extended
   (`CallboardHunterDB.questPatterns` accepts custom lowercase substrings).

## Calibration note

The arrow's rotation math is documented in `Arrow.lua` (`OnUpdate`). If the
arrow points *away* from targets, negate the `angle` variable at the marked
comment — one sign flip, done.

## Notes

- Targeting is a secure button you click; nothing is automated (Blizzard API
  blocks that, and automating it would be bot behavior on a live server).
- During combat the Target button shows "(in combat)" and re-arms itself when
  combat ends.
- Loads fine with or without RareSpawnOverlay.

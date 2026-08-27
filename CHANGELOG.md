# Changelog

All notable changes to CallboardHunter are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/); version numbers match the
GitHub releases and the `.toc`.

## [1.4.0] - 2026-08-27
### Added
- **Config panel** (`/cbh config`) — a dark, colorblind-safe panel to toggle the
  objective arrow, sound and party-announce; set/clear your home callboard; and
  manage blocked checkpoints (add box + per-row remove) without slash commands.

## [1.3.9] - 2026-08-27
### Added
- **Home callboard** — `/cbh sethome` (stand where you want it); the Callboard
  port button then brings you there when you have no active objective.
### Changed
- Blocked dungeon checkpoints (Azjol-Nerub, Ahn'kahet) are skipped **only** for
  outdoor objectives and **only** in auto-routing — manual map clicks and quests
  inside those dungeons still work.
### Fixed
- Cross-zone ports landing on the wrong map (e.g. an Icecrown objective porting
  to Moa'ki in Dragonblight) — the destination map is now confirmed before the
  checkpoint scan.

## [1.3.8] - 2026-08-27
### Changed
- Azjol-Nerub is blocked by default (its checkpoint drops you inside the
  dungeon). Re-enable with `/cbh unblock Azjol-Nerub`; block others that TP you
  inside an instance with `/cbh block <name>`.

## [1.3.7] - 2026-08-27
### Added
- `/cbh block` / `unblock` / `blocked` — exclude checkpoints that teleport you
  *inside* an instance (useless for outdoor travel) from auto-routing.

## [1.3.6] - 2026-08-27
### Fixed
- Port sometimes choosing a wrong zone (e.g. Alterac Mountains) for objectives
  that were actually elsewhere — it now trusts the zone named in the quest text
  instead of a map sweep that could read stale data.

## [1.3.5] - 2026-08-27
### Fixed
- With more than one active callboard objective, the Port button could resolve to
  a random one. It now follows the objective you're tracking in the quest log and
  is otherwise deterministic; the button label shows where it will send you.

## [1.3.4] - 2026-08-27
### Fixed
- Checkpoint teleport failing / not moving you: the port was interrupting its own
  **Rapid Transit** cast. It now clicks the checkpoint once and ignores re-clicks
  (and movement) until the cast resolves, with clear "on cooldown" /
  "interrupted — stand still" / "hold still until it finishes" messages.

## [1.3.3] - 2026-08-27
### Fixed
- Checkpoint-port bugs reported since v1.2.0: robust checkpoint click (fires the
  handler some checkpoints need on mouse-up), longer map-populate wait
  (0.4s → 0.7s), skips dead clicks when you're already at the nearest checkpoint
  or already in the destination zone.
### Added
- Better port diagnostics: the log records the game's error/cast at click time
  and verifies arrival within 6s (`/cbh log`).

## [1.2.0] - 2026-08-22
- First public release. Quest watcher, guidance arrow, kill-location learning,
  card advisor, one-click checkpoint port, rare detection/announce/targeting,
  and optional party announces.

# v0.7.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/v0.7.5-new-ground`, cut from `main` at `a20850f` (owner N1).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| CX | The Codex: a journal of every card (by pool), enemy, boss and biome, from the main menu and the pause menu; an entry unlocks the first time you meet it and shows its card or emblem, its text and your counts, kept in the profile ([evidence](evidence/CODEX.md)) | `v0.7.5 Step CX` commit (branch `v075-cx`) |
| NB1 | Biome 4, Frozen Shore: a cold moonlit snow biome over a frozen sea, ice patches you slide on, in the run's biome draw (3 floors from 4) | `v0.7.5 Step NB1` commit |
| MG | Floors of 16-20 rooms (was 11-13) with bigger rooms and an extra-large 4×4; 20 % fewer challenge rooms (3.23 → 2.42 a floor); the shop on floors 1, 3, 5 …; cursed chests only on floors 1, 3, 5 …, at most one a floor; all tunable in data (F10); a save made before v0.7.5 resumes on its v0.7.0 floor ([`evidence/MAPS.md`](evidence/MAPS.md)) | the `v0.7.5 Step MG` commit on `v075-mg` |
| AC | Local achievements: 37 to unlock (floors, wins, each boss and biome from the data, the wand, kills, sealed rooms, risks, the Codex, Ascension), a toast when one unlocks, an Achievements page in the Codex from both menus, kept in the profile ([evidence](evidence/ACHIEVEMENTS.md)) | `v0.7.5 Step AC` commit (branch `v075-ac`) |
| SM | The small things: a card's level on every pick card ("Lv 1", "Lv 2 → 3", the legendary "Lv N → 5") and on the HUD's wand pips and the Build page; ten first-run hints, each once, never blocking, with the keys of the device you use (Options: Show hints, Reset hints); the credits generated from the repo's manifests, fonts and addons, with the app icon; an Interface size option and reduced-motion / colour-blind fixes from an accessibility pass; the dev panel behind one release switch, left ON ([evidence](evidence/SMALL_THINGS.md)) | `v0.7.5 Step SM` commit (branch `v075-sm`) |

## Goldens changed on purpose
- none yet (CX changed none: the Codex is outside the sim; the replay golden passed in its content / arch run)
- NB1: none. `tests/golden` passes unchanged; ice is laid only on Frozen Shore floors and is not hashed itself.
- MG: none. `tests/golden` passes with its fixtures unchanged; every seed's floor layout changed on purpose (N9), and no golden fixture holds one
- AC: none. No sim file changed; `tests/golden` passed in its units run (evidence/ACHIEVEMENTS.md).
- SM: none. The one sim edit is a read key (`Wand.read`'s `wand`), nothing hashed; `tests/golden` not run by the agent (the lead's full suite).

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| The lead's readings in PLAN (the Ascension loop, the cosmic biome's name, the achievement list) | — | the owner asked for no interventions; corrected at the playtest | |
| SM: the owner's credit line (`CREDITS_OWNER`, "…" since v0.0.1, O4); the AI 3D generator's terms for shipping the kit models | — | pending (OWNER ONLY) | |
| EI-05: the sub-streams `map:ice` (NB1) and `map:overrun` (since v0.6.0) aren't named in the locked stream list; add them to EI-05? | — | pending (lead keeps them, the same pattern the owner approved for `map:event` on 2026-10-08) | |

## History
- 2026-10-12: plan from the owner's message (verbatim in PLAN), written while the v0.7.0 suite ran.
- 2026-10-13: v0.7.0 merged into `main` (`a20850f`); this branch, `claude/v0.7.5-new-ground`, cut from it (owner N1:
  "create a new branch"). Wave 1 (MG, NB1, CX) was started from `6381fcb`, the same tree as `a20850f`.
- 2026-10-12: CX (the Codex) built on `v075-cx` from `6381fcb`; the lead's readings are in PLAN "CX"; evidence in
  [`evidence/CODEX.md`](evidence/CODEX.md). The pause menu gained a Codex row (after Options) and the main menu one
  (after Credits); the menu e2e that count rows were updated. Not run by the agent: the full suite (the lead's, once
  per wave).
- 2026-10-12: NB1 Frozen Shore built on `v075-nb1` (from `6381fcb`): biome data, ice in the sim (`map:ice`), its look, tests; evidence [`evidence/FROZEN_SHORE.md`](evidence/FROZEN_SHORE.md). Not pushed.
- 2026-10-13: MG (agent, branch `v075-mg` from `6381fcb`): `data/map` (new `MapDefinition`, in the F10 panel's
  Difficulty page), `FloorCadence` for the shop and cursed chests, arena share 0.11, `RunState.floor_rules` so an
  old save keeps its floor. Measured before/after with `scripts/checks/map_stats.gd` (evidence/MAPS.md). Tests run by
  the agent (not the full suite): lint clean; `tests/unit/sim` 910/910 (its test_curses and test_shop_placement were
  edited during the run and re-run: with test_old_saves, 22/22); content + arch + golden + unit/application +
  unit/debug 160/160; 15 e2e files (shop, curses, events, arenas, arena, run_flow, saves, old_save, floor, routes,
  minimap, rewards, dev_master_panel, portal, after_boss) 26/26; 8 presentation files (minimap, minimap orientation,
  stage dresser, shard dressing, shop, routes, event and reward views) 54/54. Open for the lead: the full suite;
  the save snapshot cost on a bigger floor (save_bench NOT YET RUN); AP must pass the run's absolute floor number to
  the shop and curse cadence.
- 2026-10-13: AC (local achievements) built on `v075-ac` from `fa70fcb` (CX and NB1 merged); the lead's readings are in
  PLAN "AC"; evidence in [`evidence/ACHIEVEMENTS.md`](evidence/ACHIEVEMENTS.md). The Codex gained a fifth page
  (Achievements); `runs:ascended` is left for AP to report. Not run by the agent: the full suite and the bot sims
  (the lead's, once per wave). Not pushed.
- 2026-10-13: SM (agent, branch `v075-sm` from `0e58966`): card levels on the pick cards and wand pips, the first-run
  hints (`HintStore`, `OnboardingHints`; Options → Accessibility: Interface size, Show hints, Reset hints), the
  generated licence list (`scripts/content/build_credits.gd` → `data/credits/licences.tres`; a licence line added to
  `assets/models/manifest.json`), the app icon on the credits, the accessibility fixes, `DevGate` (ON). The lead's
  readings are in PLAN "SM"; evidence in [`evidence/SMALL_THINGS.md`](evidence/SMALL_THINGS.md). Run by the agent:
  lint; content + arch + unit/application + unit/app 193/193; 13 presentation unit files 88/88; 31 e2e files 61/61;
  re-runs 14/14, the dev switch e2e 1/1 and a final 16 files 52/52 on `191dbcd`; screenshots en + es at 1280×720.
  Not run by the agent: the full suite, goldens, the bot sims. Shared files touched additively:
  `main.gd`, `options_menu.gd`, `strings.csv` (26 rows), `project.godot` (a `[game]` section). Not pushed.

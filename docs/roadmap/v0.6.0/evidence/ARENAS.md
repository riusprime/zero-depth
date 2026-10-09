# v0.5.5 Step AR — sealed arenas, the Overrun's waves, the boss's legendary pick (evidence)

Rows: D2, S8, X1 ("open floor, sealed arenas"), X1b ("Pick a legendary card"). Build SHA: `bb0aa38` (branch
`worktree-agent-a85622707b3c7db52`, on top of `claude/lucid-fermat-9wv2tf` at `f0cf7f1`, which includes the v0.5.9
"Embers" merge). Every number below is a starting value the owner tunes by play. No bot balance sims were run
(owner P1); the tests prove mechanics.

## What was built
| Piece | Where |
|---|---|
| Arena rooms: round(combat rooms × 0.33), at least 1; combat rooms = all but the start hall (shrine), boss room, its host, the portal room, the Overrun and the shop's room; event rooms are picked afterwards among the rest; ≥ 3 spawn points; always skippable (every other room stays reachable with all arenas shut); a fixed order (fewest doorways, most hops, lower index), so no new RNG stream name was needed (EI-05 unchanged) | `src/sim/map/arena_rooms.gd`, `data/arenas/arena.tres` |
| Seal on the first tick inside: a barrier per doorway in `World.walls` (collision, shots, sight; never the flow field, so no rebuild hitch), the horde paused while the floor clock runs, no blink out; waves (2–3 of 3/5/7 on floors 1/2/3) spawn inside from the floor's kinds at the curve's level, from the room's own `combat:room:k` / `ai:room:k` streams; the next wave when none is left alive in the room; then the doors open and the room stays cleared | `src/sim/world/arenas.gd`, `arena_state.gd`, `arena_table.gd` |
| Rewards: arena item spots are filled first (nearest arena to the start first); a reward in an uncleared arena is locked (interact skips it); S1's cap of 2 altars kept (the Overrun's altar stays outside it, owner 2026-10-08) | `src/sim/items/rewards.gd` |
| Overrun = the hardest arena (S8): seals, 3–5 waves (drawn per room) of 4/8/12 ×1.5 HP/damage enemies inside; altar and double shards after the last wave. Replaces `kills_to_clear` and the spawn multiplier | `src/sim/world/overrun.gd`, `data/overrun/overrun.tres` |
| Boss reward (X1b): the boss's death leaves a free legendary altar at the boss's spawn; a pick of 3 from the boss-only tier (legendary stat cards = epic × 1.6 as a 4th rarity; the 9 rare mods), "Pick a legendary card", bright-gold frame (`CardFrames.LEGENDARY_TIER`: the gold frame overbright, a stronger glow) | `src/sim/items/boss_reward.gd`, `legendary_table.gd`, `data/legendary/boss.tres`, `Offers.roll_legendary`, `pick_panel.gd`, `card_frames.gd` |
| Presentation: amber door frames; glowing barriers while sealed (red in the Overrun); the rest of the floor goes dark with a veil over every other room, a layer on top of v0.5.9's lighting (sun, ambient, fog untouched: the e2e checks the sun and ambient energies); arenas on the minimap once discovered (amber doorways and mark, dim once cleared, legend row); a seal ring on locked rewards; the banner "ARENA / Wave n / N · k left" (OVERRUN in red); seal sound = the boss door's seal, clear = the Overrun fanfare (no new audio assets) | `src/presentation/world_view/arena_views.gd`, `reward_views.gd`, `hud/overrun_hud.gd`, `hud/minimap_*.gd`, `audio/audio_events.gd` |
| Saves: `ArenaState` in `WorldSnapshot.STATE_CLASSES`, `ArenaTable` / `LegendaryTable` / `CurveTable` loadout; a restore with barriers rebuilds only the wall grid; the save lab now builds floors like Main (floor curve, arenas, legendary tier) | `src/sim/core/world_snapshot.gd`, `tests/support/save_lab.gd` |
| Dev panel: Go to an arena door, Clear the arena wave (dev runs only; the e2e uses them by mouse clicks) | `src/application/debug_api.gd`, `src/debug/dev_panel.gd` |
| Strings en + es: HUD_ARENA, HUD_ARENA_WAVE, HUD_ARENA_CLEARED, MAP_LEGEND_ARENA, UI_DEV_GO_ARENA, UI_DEV_CLEAR_WAVE, PICK_TITLE_LEGENDARY, RARITY_LEGENDARY; HUD_OVERRUN_PROGRESS removed (kills no longer clear it); HUD_OVERRUN_CLEARED reworded | `locale/strings.csv` |

## Tests
- `tests/unit/sim/test_arenas.gd` (14): generation property over 300 seeds, determinism, exclusions, rewards first and
  locked, the seal, the barrier holding a walk and dash, waves inside at the floor's sizes, the clear, a locked
  reward opening only after the clear, a replay hash, save round trips (at the arena entry on floors 1–2, mid wave,
  after the clear, the Overrun's entry; equal hashes after restore and after 600 more ticks), legendary amounts, the
  boss's legendary altar of 3.
- `tests/unit/sim/test_overrun.gd` (7, rewritten in-play part): the seal, waves of 4 inside with ×1.5, 4/8/12 by
  floor, every wave then the doors, altar and double shards.
- `tests/e2e/test_e2e_arenas.gd` (2, `main.tscn`, input only): walk into an arena (seal, barriers drawn, banner,
  every other room veiled, sun/ambient untouched, reward sealed), Clear wave per wave until the doors open, the dark
  lifts, E on its reward; through the boss door, Kill boss, the legendary altar, E → "Pick a legendary card", 3
  legendary cards in the gold frame, Enter takes one.
- Changed on purpose: the stat-card number tests (a 4th, legendary value), the e2e walk helpers plan around
  uncleared arenas (`E2e.walk_walls`) and skip locked rewards; `test_e2e_card_pool` and `test_e2e_combo` start with
  the arenas cleared (labelled TEST HELPER), and `test_e2e_combo` holds the non-combo items (labelled TEST HELPER:
  with the arenas' spots filled first, the fixed seed's four rewards no longer happened to offer a combo pair).
  `tests/MIN_TEST_COUNT` 1076 → 1122 (the real count after the v0.5.9 merge and this step).

## Full suite (command and raw output)
```
$ bash /tmp/claude-0/vd.sh /home/user/zero-depth/.claude/worktrees/agent-a85622707b3c7db52 ar
verify exit 0
Tests              1122
Passing Tests      1122
check_gut_log: ok (1122 passing, minimum 1122)
```
From the log (`/tmp/claude-0/vd_ar.clean.log`): `Asserts 1237952`, `Time 1881.166s`, and
```
res://tests/unit/sim/test_arenas.gd
* test_about_a_third_of_the_combat_rooms_are_skippable_arenas
    arenas over 300 seeds: 653 in 2102 combat rooms, 4 floors without
...
14/14 passed.
res://tests/unit/sim/test_overrun.gd
    overrun over 1000 seeds: 0 floors without one, 979 dead ends
7/7 passed.
res://tests/e2e/test_e2e_arenas.gd
2/2 passed.
```
653 / 2102 = 31 % of combat rooms are arenas (fewer than a third where one more would cut the floor).

## Export smoke (command and raw output)
```
$ cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh
manifest: da4ca84cb7fedd16eb0aa1ff928c0dbf55baeee0abf0fd25a368dacc6188d95f (223 files, 0 errors)
Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash da4ca84cb7fe matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is PLAY / JUGAR
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 87
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```

## Goldens
None changed (the replay and export-smoke goldens run the kernel scenario, which has no arenas; arena state is hashed
only once an arena sealed).

## Not done / open for the owner
- Legendary **mods at higher values**: items have fixed numbers today, so the legendary mods are the 9 rare mods at
  their normal values; only the stat cards are stronger (epic × 1.6). Step MX swaps the pool for legendary modifiers
  (the pool is data: `data/legendary/boss.tres`).
- Screenshots of the dark veil and the legendary card: NOT YET RUN (the shot tour needs a renderer).
- Feel (veil darkness 0.82, wave sizes, 1/3 share, wave gaps): OWNER ONLY.

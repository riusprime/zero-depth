# v0.9.0 Step LK: Lockdown rooms, Normal and Hazard (evidence)

Build: branch `v090-lk`, cut from `31fd095f` (the DP merge). The Step LK commit is the one that adds this file. Tests
ran with LK's changes in the working tree (the hazard test's last edit was re-run on its own, below).
Machine: the owner's PC (Windows 11, Spanish OS locale), Godot 4.7.2, Git Bash. No timings are claimed; the seconds
below are sim time (ticks / 60), not wall time.

## What changed

- **A new room type beside the Arenas** (owner Q21 "A new room type"; Arenas unchanged: `arena_rooms.gd`, `arenas.gd`
  untouched, test_arenas green).
- **Generation** (`LockdownRooms.mark`, `src/sim/map/lockdown_rooms.gd`, run from `Lockdowns.setup` last in
  `FloorPlan.add_secrets`, after the purple-rune room):
  - 1-2 a floor: the count is drawn in `rooms_min..rooms_max` = 1..2 from the `map:lockdowns` sub-stream of the floor
    seed; the candidates are shuffled from it, rooms off the shortest start-to-boss path first.
  - Never the start hall, the boss room or its host, the portal room, the Overrun room, the shop's room, the curse
    room, an arena, a secret room (timed door, rune puzzle, cracked wall) or a secret's host, the purple-rune room,
    an event's room or the gamble shrine's room; at least 3 spawn points.
  - **Always skippable**, as an arena: every room reached from the start hall with the arenas and the Overrun room
    shut is still reached with the Lockdowns shut too. So a Lockdown never stands on the only way to the boss (no
    softlock even before the 90 s cap), and **never two side by side** (never two in a row on any path).
  - The kind per room, from the same stream, by `kind_weights` [Normal 750, Hazard 250, Elite 0] from
    `kind_floor_min` [1, 2, 4]: Normal from floor 1, Hazard from floor 2, **Elite is step EL's hook** (the
    `LockdownTable.Kind.ELITE` value, the data row with weight 0 from floor 4; EL sets its weight and its encounter).
  - The room's horde spawn points are dropped (a Lockdown room holds only its encounter).
  - `RunState.FLOOR_RULES` 12 → 13 (`FLOOR_RULES_V090_DP` = 12). A floor saved under rules 1-12 is rebuilt with no
    Lockdown, as it was saved.
- **Sim** (`Lockdowns` + `LockdownState`, `World.lockdown`, tick phase 9 after `Arenas.advance`):
  - Seal: the first tick the hero stands inside an unopened Lockdown room, a barrier joins the walls in each of its
    doorways (`ArenaRooms.barrier`, as an arena's), the horde waits (the floor clock runs on), a blink never lands
    outside. The room's stream `combat:lockdown:k` is derived at the seal.
  - Encounter: `waves` = 3 formations of `wave_sizes` = [5, 5, 5, 6, 6] (floors 1-5) enemies, first 1.0 s after the
    seal, the next 0.75 s after the last fighter falls. Kinds weighted as the spawn director's at the curve's level
    now; scaled on arrival like any spawn; no elite roll. Formations are set shapes round the room's middle, turned to
    face the hero: ring, line across the far side, pincer from both flanks, wedge (the first drawn, each next the next
    shape); a spot off the floor, against a wall or within 2.5 m of the hero falls back to the room's nearest spawn
    point.
  - Stuck-enemy safety (W26): a fighter (an encounter enemy anywhere, or any enemy in the room) outside the room, or on
    a cell the hero's flow field doesn't reach, for 180 ticks in a row is put back on the room's spawn point nearest its
    middle (2.5 m clear of the hero). 5,400 ticks (90 s) after the seal the exits open whatever is left (`forced`).
  - Hazard Lockdowns: every 2.0 s a strike is marked on the ground where the hero stands; it lands 1.0 s later (60
    ticks, over the 24-tick telegraph minimum) and hurts the hero within 1.3 m (+ the hero's radius) for 12
    (`lockdown_hazard` effect; the recap's cause `CAUSE_LOCKDOWN_HAZARD`, "A Lockdown's hazard" / "Un peligro del
    Bloqueo"; ReadableCause checks it like the barrel). The mechanic is shared; the look is the biome's.
  - Open (clear or cap): the bars leave the walls, the room stays open, and a free altar stands on its spawn point
    nearest the middle.
  - Saves: `LockdownState` in `STATE_CLASSES` and `_make`, `LockdownTable` in `LOADOUT_CLASSES`, `lockdown` in
    `ADDED_SINCE_V05`; a sealed room's bars count with the arena barriers in the save's wall check. Hashed when present.
  - Data: `data/lockdowns/lockdown.tres` (`LockdownDefinition`, category `lockdown`; validated), compiled by
    `RunContentCompiler.compile_lockdown`.
- **View** (`LockdownView`, `LockdownHud`, `AudioEvents`):
  - The owner's `lockdown_seal` bars (ShopModels; a code stand-in of iron rods when unlisted) wait unseen 3 m above
    every doorway of every Lockdown room; on the seal they slide down in 0.3 s and slam (a camera thud); on the open
    they grind up in 1.3 s and leave sight.
  - Sounds: `lockdown_close` (the bars' drop and slam, captioned "[Bars slam shut]") and `lockdown_open` (the grind,
    "[Bars grind open]"): placeholders from `scripts/audio/generate_sfx.py`; only the two new wavs and manifest entries
    were taken (the regenerated `barrel_*`, `bomb_throw`, `container_break`, `pillar_turn`, `wall_break` differ by
    this PC's numpy and were reverted). A strike landing plays `container_break` at it. Credits rebuilt (106 files).
  - Hazard look: each marked strike's ground warning (an orange disc growing and pulsing until it lands), then the
    biome's hazard where it landed: Ruins `hazard_cable`, Night Rocks `hazard_rock` (falls), Red Canyon `hazard_vent`,
    Frozen Shore `hazard_ice`, Starfall `hazard_star` (falls), looked up through ShopModels by those ids (SPECS added),
    code stand-ins until the owner's files are listed.
  - Banner: "LOCKDOWN" / "BLOQUEO" (or "HAZARD LOCKDOWN" / "BLOQUEO PELIGROSO"), "Formation n / 3 · k left", then
    "Lockdown cleared · the exits are open" (or "The bars give way · …" when the cap opened it), 4 s.
  - Dev panel: Clear wave also clears a sealed Lockdown's formation (the e2e clicks it).

## Choices where the docs were silent

1. **Skippable only** (the arenas' rule) rather than "on the path but always opens": the owner allowed either; this
   keeps every existing walk (and the e2e's planner) working and costs floor 1 some Lockdowns (below).
2. Hazard from floor 2 ("Normal from floor 1; … Hazard rarer"): a data value (`kind_floor_min`).
3. The cap's open still leaves the altar (a stuck or lost enemy is never the player's fault); enemies left stay alive.
4. Reward: a free altar (the Overrun's kind of clear reward), not a chest.
5. No elite roll in Normal/Hazard Lockdowns (elites are EL's).
6. Strike damage hurts the hero only, not enemies.

## Placement (test_lockdowns, 200 floor seeds a floor, layouts built as the run sizes them)

Command: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_lockdowns.gd -gexit`

```
LK_PLACEMENT| floor=1 seeds=200 none=64 one=120 two=16 normal=152 hazard=0 elite=0 on_short_path=6
LK_PLACEMENT| floor=2 seeds=200 none=10 one=121 two=69 normal=186 hazard=73 elite=0 on_short_path=2
LK_PLACEMENT| floor=3 seeds=200 none=2 one=116 two=82 normal=206 hazard=74 elite=0 on_short_path=2
LK_PLACEMENT| floor=4 seeds=200 none=1 one=115 two=84 normal=219 hazard=64 elite=0 on_short_path=1
LK_PLACEMENT| floor=5 seeds=200 none=1 one=100 two=99 normal=219 hazard=79 elite=0 on_short_path=0
```

Floor 1 (10-12 rooms): **136 of 200 seeds (68 %) get a Lockdown** (120 one, 16 two); floors 2-5: 95-100 %. Never a
forbidden room, never a room cut off, never two side by side, no Hazard on floor 1, no Elite (asserted, 0 bad).
`on_short_path` counts Lockdowns lying on the shortest start-to-boss path that still have a way round.

## Encounter sizing (starting values)

FightBot (the base Blade, no cards, unhurt) walks into each floor's first Lockdown (LockLab: the first run seed whose
floor holds one) and fights; sim seconds from the seal to the open:

```
LK_SIZING| floor=1 seed_room=5 enemies=15 total_hp=298 seconds=23.0 forced=false
LK_SIZING| floor=2 seed_room=4 enemies=15 total_hp=911 seconds=33.4 forced=false
LK_SIZING| floor=3 seed_room=12 enemies=15 total_hp=897 seconds=45.1 forced=false
LK_SIZING| floor=4 seed_room=16 enemies=18 total_hp=1871 seconds=55.3 forced=false
LK_SIZING| floor=5 seed_room=17 enemies=18 total_hp=1950 seconds=90.0 forced=true
```

How it was sized: a first try (2 formations of [4, 5, 6, 7, 8]) measured 9.8 s on floor 1 and 20.0 s on floor 2
(base Blade), short of the band at the hero's floor-1 DPS; it became 3 formations of [5, 5, 5, 6, 6]. Floors 1-2 are
in the 20-40 s band **at the base Blade's DPS**. Floors 3-5 measure 45-90 s with no cards at all; a real hero there
holds two to four floors of cards, so the "floor's expected DPS" is higher than this bot's. There is no measured
per-floor expected DPS in the repo (the Playground meter is a tool, not a table), so floors 3-5 are **NOT YET
MEASURED at the expected DPS**: OWNER ONLY (playtest). The numbers are data (`wave_sizes`, `waves`).

## Tests

All runs: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<files> -gexit` (or `-gdir`),
after `godot --headless --path . --editor --import --quit`, `APPDATA` set to a folder of this agent's own.

| Run | Raw summary |
|---|---|
| `tests/unit/sim/test_lockdowns.gd` (all 8) | `Tests 8 / Passing Tests 7 / Failing Tests 1` — the failure was the hazard test's own set-up (the formation knocked the hero off the mark); the test was fixed (no spawner, the hero held) and re-run alone: |
| `-gunit_test_name=test_a_hazard` | `Passing Tests 1` |
| `LK_STUCK` line (the stuck enemy) | `LK_STUCK| held_ticks=180 stuck_ticks=180 pulled=1` |
| `tests/unit/presentation/test_lockdown_view.gd` | `Tests 2 / Passing Tests 2 / Asserts 34` |
| `tests/content` (dir) | `Tests 140 / Passing Tests 140 / Asserts 10444` |
| test_old_saves, test_world_snapshot, test_state_hasher, test_layering, test_sim_purity | `Tests 32 / Passing Tests 32 / Asserts 19839` |
| test_e2e_run_flow, test_e2e_old_save, test_e2e_purple_portal, test_e2e_timed_door, test_e2e_lockdown | `Tests 7 / Passing Tests 7 / Asserts 173` |
| test_arenas, test_run_saves, test_intensity_director, test_purple_runes, test_purple_rune_view | `Tests 58 / Passing Tests 58 / Asserts 2581` |
| lint: `gdformat --check` + `gdlint` on every touched `.gd` | `Success: no problems found` |

The e2e line: `LK_E2E| seed=1 room=4 kind=1 clicks=3 seconds_sealed=5.9` (run seed 1, floor 2 continued from the
menu; walked in with the stick, the bars came down, three Clear wave clicks, the bars rose, the altar in sight).

Not run here: the full suite (GitHub), test_curse_room (slow), the known reds (test_final_pace; the Spanish-locale
test_frozen_shore, test_starfall, test_deep_bite, test_deep_look). Goldens: none changed (the golden fixtures use
KernelScenario, not floors).

## Shot

`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/lockdown_lk.gd` (GPU, forward_plus):

```
lockdown_lk: room=4 doors=3 formation=2 enemies=5
lockdown_lk: res://build/shots/v0.9.0/lk/lockdown_sealed.png bars_down=1.0
```

`lk_shots/lockdown_sealed.png`: run seed 1's floor 2, its first Lockdown sealed (Ruins stage for the shot): the
owner's iron bars down in its three doorways, the first formation (a pincer) inside, the hero in the middle.

## Owner

- Playtest the feel, the length on floors 3-5 and the hazard's damage: OWNER ONLY.
- Hazard props `hazard_cable`, `hazard_rock`, `hazard_vent`, `hazard_ice`, `hazard_star`: code stand-ins until
  delivered (docs/art/requests/v0.9.0_ART_LIST.md).

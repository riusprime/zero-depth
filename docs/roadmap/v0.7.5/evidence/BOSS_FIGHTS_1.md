# v0.7.5 Step BF1: the dodge-first engine, the Gatekeeper and the Warlord (evidence)

Owner N15 (verbatim in [`../../../design/BOSS_FIGHTS.md`](../../../design/BOSS_FIGHTS.md); picks "About 1.5×",
"Track, then lock 0.8 s", "Shielded during big patterns"; "Approve all", 2026-10-13) and N18 (the lead's message,
2026-10-13: "Bosses could be a bit bigger so we could see the model better and always put them in the big rooms").
Branch `v075-bf1`, from `edda87e`. The build SHA of the runs below is named with each.

## What was built
- **Bullet pattern engine (sim).** `BulletPatternDefinition` (content, `data/bullet_patterns/*.tres`, category
  `bullet_patterns`, in the F10 panel's Bosses page) → `PatternCompiler.compile_pattern` → `BulletPatternTable` →
  `BulletPatterns` (`src/sim/ai/bullet_patterns.gd`). Kinds: ring, spiral, fan, cross, wall, flower, burst-on-land.
  `wave_shots()` is pure (no stream, `Kin` angles, the flower's rose a `Kin.dir` lookup); `fire()` leaves out shots
  within the safe radius of the player or in a wall, caps 160 shots a tick / 900 alive (one `LIMIT`,
  `bullet_cap`), and queues ordinary hostile projectiles (they stop at walls). Each shot carries its pattern's look
  (`ProjectileStore.look`).
- **Tracked, then locked (sim).** `BossAttackDefinition.lock_seconds` (0.8 s): the windup aims at the exact position
  (no lead), then holds for the lock. New moves `marks` (circles in turn) and `row_lanes` (the player's row and
  column), in `BossDodge`. Telegraphs carry `tracked` / `locked`.
- **Shielded signature (sim).** `BossAttackDefinition.shielded`: hits spark off (`HIT` with `TAG_BLOCKED`, no
  damage, no DoT), the world's own hit passes; open between patterns. Reads: `WorldReader.boss_shielded(i)`,
  `boss_pattern(i)` (for BM's avatars: a shield pose), `projectile_look(i)`, `MOVE_PATTERN` / `MOVE_MARKS` /
  `MOVE_ROW_LANES`.
- **The two fights (data)**, per the design table:

| Boss | Phase 1 (100 %) | Phase 2 (66 %, opens with) | Phase 3 (33 %, opens with) |
|---|---|---|---|
| Gatekeeper | Rock Rings (3 × 16, gap 2, turns a step; shielded), Cross Quake (4 arms, 25°/s), Fist Slam (1 tracked circle), Shock Lanes (row + column), Sweep | Rock Rings ×4 (faster, turning back; shielded), Cross Quake, Fist Slam ×2, Shock Lanes, Sweep — opens with Rock Rings ×4 | Rock Rings ×4, Cross Quake fast (−35°/s, denser), Fist Slam ×3, Shock Lanes ×2, Sweep — opens with Cross Quake fast |
| Warlord | Shield Wall (a marching wall, gap 2.4 m moving 3 m a wave; shielded), Javelin Fan (3 × 7, offset each wave), Spear Lines (tracked, locked), Lunge (tracked lane), Shield Bash | the same with the Spear Wall (5 lines) — opens with Shield Wall | Shield Wall crossing (two walls at right angles; shielded), Javelin Fan fast (4 × 7), Spear Wall, Lunge, Javelin Rain (tracked), Shield Bash — opens with the crossing walls |

  HP 1400 → 1750 (×1.25) on both. Punish: Gatekeeper Shock Lanes, Warlord Javelin Rain; gap-closer: none for the
  Gatekeeper (a tracked circle as its gap-closer repeated forever on a far player, seen in the e2e's first run),
  the Warlord's Lunge.
- **Presentation.** `FireballViews` (three MultiMeshes per look: bright unshaded core, a dark edge drawn from the
  inside, a trail; blended between ticks by hand; Effects density Low = every other trail, shorter),
  `TelegraphViews` (tracking: a dull outline, no fill; locked: a bright filled flash pulsing at 7 Hz, steady with
  reduced motion; `marks` per marker), `BossShieldView` (a faceted crystal shell in the boss's colour, a brighter
  rim, rising in 0.15 s; a burst's lobbed shell), the Gatekeeper avatar posing the new moves as its slam, audio cues
  for the new moves. `ActorViews` no longer draws fireballs.

## N18: before / after (all six bosses, data)

| Boss | `radius_m` | `arena_cells` | Reach kept from the bigger body |
|---|---|---|---|
| Gatekeeper | 1.3 → 1.7 | 3×3 → 4×4 | Sweep `max_range_m` 3.4 → 3.8 (its reach is from the edge already) |
| Brood Mother | 1.2 → 1.55 | 2×2 → 4×4 | — (leaps and broods aim at spots) |
| Siege Engine | 1.4 → 1.8 | 3×3 → 4×4 | Shockwave inner 4.0 → 4.4 (the safe ring keeps its width); outer 40 → 50 (the 4×4 room's far corners: the test measured 41.49 m on seed 7093) |
| Warlord | 1.1 → 1.45 | 3×2 → 4×4 | Shield Bash `max_range_m` 3.3 → 3.65 |
| Hive Lens | 1.0 → 1.3 | 2×2 → 4×4 | Glare ring 1.2–3.6 → 1.5–3.9, `max_range_m` 3.8 → 4.1 |
| Foundry | 1.5 → 1.95 | 3×2 → 4×4 | Slam ring outer 4.2 → 4.65, `max_range_m` 4.5 → 4.95 |

Sweeps, charges and leaps measure from the body (`arc_of`'s own radius, the contact slop), so they grew with it.
`test_boss_room_builder.gd` and `test_floor_generator.gd` (the boss-room property tests) passed at 4×4 (below).

## How to add a boss's patterns (for the next BF agents and EF)
1. **A pattern** is a file in `data/bullet_patterns/<boss>_<name>.tres` (`script_class="BulletPatternDefinition"`):
   `id`, `kind` (0 RING, 1 SPIRAL, 2 FAN, 3 CROSS, 4 WALL, 5 FLOWER, 6 BURST), `look` (its fireball look key),
   `speed_mps` (1.5..7; 3–5 is the design), `radius_m`, `range_m`, `waves`, `wave_gap_seconds`,
   `turn_per_wave_degrees`, `alternate`, `aim_offset_degrees`, `safe_radius_m`, and the kind's own fields:
   - RING `count`, `gap_count`, `gap_width` (the gap must be ≥ 1 m wide 4 m out);
   - FAN `count`, `spread_degrees` (≤ 300);
   - SPIRAL `arms`, `spin_dps`, `reverse_at_seconds`; CROSS `arms`, `spin_dps`;
   - WALL `wall_length_m`, `spacing_m`, `gap_m` (≥ 1), `gap_offset_m`, `gap_shift_m`, `crossing`;
   - FLOWER `count`, `petals`, `petal_min_permille`, `petal_cut_permille` (100..900, the gaps);
   - BURST `count` (≤ 16), `lob_seconds`, `land_radius_m`.
   CONTENT_SCHEMA §4b has them all; the validation rejects a pattern without a gap.
2. **An attack that fires it** in the boss's `.tres`: `move = &"pattern"`, `shape = 4`,
   `shape_params = {"pattern_id": "<the id>"}`, `telegraph_seconds` (the wind-up before the first wave), `damage`
   (each fireball's), `cause_key`, and `shielded = true` for the signature. `active_seconds` is a floor; the attack
   runs for the pattern's whole length. A BURST aims its landing at the target its windup tracked (add
   `lock_seconds` to make the landing a tracked-then-locked circle).
3. **Markers**: `move = &"marks"` (`count`, `radius_m`, `stagger_seconds`; `shape = 0`) or `&"row_lanes"`
   (`count`, `length_m`, `width_m`, `stagger_seconds`; `shape = 2`) with `lock_seconds = 0.8` and
   `telegraph_seconds` = track + lock. Any existing aimed move (flood, charge, barrage, lanes, leap, rail, bolt fan)
   becomes tracked-then-locked with `lock_seconds`.
4. **Phases**: put the attack ids in `phases[k].attack_ids` and an `entry_attack`; a faster or denser variant is its
   own attack (and pattern file), as `rock_rings_4`.
5. **The look**: add the key to `FireballViews.LOOKS` (core, edge, trail, size, tip, trail_m); a key without an entry
   draws `DEFAULT_LOOK`. Keep the core 0.2+ (RGB) away from the hero's cyan and the heat colours
   (`test_boss_fight_views.gd` checks every entry), the core bright, the edge dark. A shell colour per boss is
   `BossShieldView.COLORS` (all six are set).
6. **An enemy (EF)** compiles a pattern with `PatternCompiler.compile_pattern(def)` and fires it with
   `BulletPatterns.fire(w, i, pattern, wave, origin, aim, origin_r, damage)` on the ticks `BulletPatterns.wave_at`
   names; nothing else is needed for the look, the caps and the fairness rules.

## Tests (raw)
Lint, on the final tree (the `v0.7.5 Step BF1` commit):
```
$ gdformat --check src scripts tests && gdlint src scripts tests
777 files would be left unchanged
Success: no problems found
```
New tests: `tests/unit/sim/test_bullet_patterns.gd` (each shape's counts and gap, turn per wave, determinism of a
pattern fight, no spawn on the player or in a wall, wall stop, the per-tick cap, looks), `tests/unit/sim/
test_boss_markers.gd` (marker follows until the lock and is fixed after, strike after the lock; a player who moves
after the lock is not hit; the strike is the drawn circle; three circles in turn; row and column; the Warlord's
lunge and spears aim exact and lock 0.8 s; no damage while shielded and open after; the dev kill passes; slow
fireballs in each boss's look; both phase scripts), `tests/content/test_bullet_pattern_validation.gd`,
`tests/unit/presentation/test_boss_fight_views.gd`, `tests/e2e/test_e2e_boss_dodge.gd` (main.tscn, real input:
the Gatekeeper summoned from the dev panel, a Fist Slam locks on the player, the stick walks out, the circle
strikes where it locked and misses; its ember stones drawn).

Changed tests (the fights changed on purpose): `test_bosses.gd`, `test_bosses_2.gd`, `test_boss_gates.gd` (wait out
the shielded entry pattern), `test_boss_challenge.gd` and the presentation parity / views (the pull move now on a
fixture, `BossLab.vortex_def`), `test_boss_pressure.gd` (tracking on the Warlord's bash; the gap-closer on the
Warlord), `test_boss_views.gd`, `test_boss_telegraph_parity.gd`, `test_boss_challenge_views.gd`,
`test_boss_validation.gd`, `test_e2e_bosses_2.gd` (a step aside out of a pillar's shadow before waiting for a hit:
the dev panel puts the boss 6 m off with a start-hall pillar between, and fireballs stop at walls).

### Runs
`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <-gtest / -gdir ...> -ginclude_subdirs -gexit`,
on a shared machine (another agent's run alongside). The GUT totals as printed:

| Run | Tree | Raw totals |
|---|---|---|
| `tests/unit/sim` (first part), with golden/application/debug/content/arch queued after | `b45ac0b` | `578/578` in the 52 scripts that finished before my wrapper's 3000 s `timeout` stopped the run (`exit 124`) inside `test_modifier_smoke_mx4.gd`; the every-card soak (`test_combos.gd`) among them: `SOAK\| kills=265 events=6696 most_in_a_tick=188 limits=0 (watchdog 0, heal cap 0)` |
| the rest of `tests/unit/sim` (from `test_modifier_smoke_mx4.gd`) + the boss files again + `tests/golden`, `unit/application`, `unit/debug`, `content`, `arch` | `2dcaf02`'s code (the N18 legacy-room fix landed while it ran) | `Scripts 93`, `Tests 725`, `Passing Tests 721`, `Failing Tests 4`: `test_ascension_saves.gd` "its snapshot still restores" and `test_old_saves.gd` (3 asserts) — `"World.walls: the snapshot's floor differs from the one generated from its inputs"`: an old save's floor rebuilt with today's 4×4 boss room; fixed (floor rules 3, `legacy_arena_cells`, below); `test_boss_pressure.gd` "gatekeeper has a gap-closer" — fixed (the Gatekeeper has none now, by design) |
| `tests/unit/application` + `tests/content` after the fix | final code | `Scripts 37`, `Tests 201`, `Passing Tests 201` |
| `test_boss_pressure.gd`, `test_boss_fights.gd`, `test_boss_challenge.gd`, `tests/golden`, `tests/arch`, `tests/unit/debug` after the fixes | final code | `Scripts 8`, `Tests 50`, `Passing Tests 50` |
| `tests/unit/presentation` | `2dcaf02` | `Scripts 75`, `Tests 473`, `Passing Tests 473` |
| e2e: `test_e2e_boss_dodge`, `test_e2e_bosses`, `test_e2e_bosses_2`, `test_e2e_boss_challenge`, `test_e2e_after_boss`, `test_e2e_ascension`, `test_e2e_dev_master_panel` | `2dcaf02` | `Scripts 7`, `Tests 12`, `Passing Tests 12` |
| e2e after the legacy-room fix: `test_e2e_old_save`, `test_e2e_saves`, `test_e2e_boss_dodge`, `test_e2e_after_boss` | final code | `Scripts 4`, `Tests 5`, `Passing Tests 5` |

`tests/golden` passed unchanged (no golden fixture changed). Not run: the full suite (the lead's, on GitHub), the bot
sims, `scripts/ci/seams.sh` (the lead's after the merge), the sim bench and the hitch probe with hundreds of
fireballs (NOT YET RUN; the caps hold the worst case at 160 new shots a tick and 900 alive).

### N18 and old saves
Moving every boss room to 4×4 changed the floor a save rebuilds under its snapshot. `RunState.FLOOR_RULES` is 3
now; a payload with floor rules 1 (v0.7.0) or 2 (v0.7.5 MG) rebuilds its boss room at the boss's
`legacy_arena_cells` (its room before N18, in data) through `RunSaver.boss_arena` (Main and the labs), and the next
floor is today's. Test: `test_old_saves.gd` "a save from before the big boss rooms keeps its room".

## Screenshots
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path .
--audio-driver Dummy --resolution 1600x900 -s scripts/shots/boss_fights.gd` (xvfb + llvmpipe), copied from
`build/shots/v0.7.5-dev/boss_fights/`:
- [`shots/boss_fights/1_gatekeeper_rock_rings_shielded.jpg`](shots/boss_fights/1_gatekeeper_rock_rings_shielded.jpg)
- [`shots/boss_fights/2_gatekeeper_cross_quake.jpg`](shots/boss_fights/2_gatekeeper_cross_quake.jpg)
- [`shots/boss_fights/3_gatekeeper_fist_slam_tracking.jpg`](shots/boss_fights/3_gatekeeper_fist_slam_tracking.jpg)
  (the first circle locked and flashing, the second still a dull outline on the hero)
- [`shots/boss_fights/5_gatekeeper_shock_lanes_locked.jpg`](shots/boss_fights/5_gatekeeper_shock_lanes_locked.jpg)
  (the row and column cut short by the hall's pillar and wall)
- [`shots/boss_fights/6_warlord_shield_wall_shielded.jpg`](shots/boss_fights/6_warlord_shield_wall_shielded.jpg)
- [`shots/boss_fights/7_warlord_crossing_walls.jpg`](shots/boss_fights/7_warlord_crossing_walls.jpg)
- [`shots/boss_fights/8_warlord_javelin_fan.jpg`](shots/boss_fights/8_warlord_javelin_fan.jpg)
- [`shots/boss_fights/9_warlord_spear_lines_locked.jpg`](shots/boss_fights/9_warlord_spear_lines_locked.jpg)

The models in the shots are the current code/kit bodies at the old scale (BM installs the owner's models and their
1.3× scale in parallel).

## Not measured / open
- **Fight length ≈ 1.5×: NOT YET RUN.** HP is ×1.25 (data) and each signature keeps the boss shielded for its windup
  and waves (Rock Rings 0.8 s + 1.1 s; Shield Wall 0.8 s + 2.0 s); the fight length itself needs the bot sims (not
  an agent's run here) or the owner's playtest. OWNER ONLY: whether it feels 1.5× and whether the dodging is fun.
- The owner's tuning numbers (speeds, counts, gaps, lock 0.8 s, HP) are starting values (F10, the Bosses page now
  lists `data/bullet_patterns`).
- The other four bosses keep their v0.7.0 fights (with N18's size and room) until the next BF agents; their moves
  `lanes`, `pull` and `slam_ring` are untouched; `lanes` and `pull` have no shipped user after BF1.
- Avatars (BM's files): only the Gatekeeper's maps the new moves to its slam pose. The Warlord's shield pose can read
  `WorldReader.boss_shielded(i)` / `boss_pattern(i)` (BM's agent).
- Colour-blind modes don't recolour the fireball looks (they keep their shapes, edges and trails); a possible follow-up.
- `test_e2e_bosses_2.gd`'s Warlord needed a step out of a pillar's shadow; a dev-panel spawn spot with a clear line
  would make the dev panel's boss test fairer (not changed: the panel isn't this step's).

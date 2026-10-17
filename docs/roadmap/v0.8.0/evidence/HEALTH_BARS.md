# HEALTH_BARS: do the bars show the hit, the heal and the shield? (v0.8.0 N4, owner O56, O57, O59)

- **Status:** RUN (unit, e2e, content, arch, lint, the perf probe and the renders); how it feels in play is
  **OWNER ONLY**
- **Build:** the working tree of the commit `v0.8.0 Step N4` on `v080-n4` (parent `02f23d5`); the runs were made on
  that tree before it was committed. Godot `4.7.2.stable.official.ed1daf0bf`; a shared Linux cloud container
  (headless; renders on software Vulkan, llvmpipe, under xvfb), not the owner's hardware
- **Date:** 2026-10-17
- **Who ran it:** agent

Owner (PLAN O56, O57, O59, verbatim there): a damage chunk that waits a moment, then drains; the wait counted from
the burst's first hit so the chunk always moves and a huge crit looks huge; a refill that animates; a shield that
recolours the bar, says invulnerable and shows the shields left; one full bar per boss phase, refilling, the last
boss too; the chunk on enemies' bars too; the final boss's bar names the body only, never "1/3".

## The change (presentation; the sim is only read)
- `HealthBarTrail` (`src/presentation/hud/health_bar_trail.gd`), the one model every bar uses: the fill drops at
  once and a light chunk keeps the loss; the chunk holds `HOLD_S` 0.5 s from the burst's **first** hit (later hits
  add to it, never restart it), then drains in `DRAIN_S` 0.4 s; a hit while it drains speeds the drain so it catches up
  within 0.4 s of that hit. A burst ends once the chunk has caught up and no hit came for `QUIET_S` 0.5 s; until then
  a new hit drains at once, so steady fire never parks the chunk. A single drop of 8 % of the bar or more (`BIG_HIT`)
  lights the chunk brighter for 0.35 s. A rise (heal, refill) grows the fill over `REFILL_S` 0.8 s. Reduced motion:
  no hold, drain and refill 0.05 s. All starting values.
- The hero's HUD bar (`HudBar`) runs on it (its old fading echo is gone); the regen pulse follows the drawn fill.
- Bars over enemies and the hero (`ActorViews`): each bar's trail lives in `BarChunks`, one `MultiMeshInstance3D`
  for every chunk on screen (two strips a bar, each side of the fill, since the bar shrinks toward its centre),
  billboarded to the camera's basis at the bar's interpolated position. The bars themselves are unchanged (shown once
  hurt; bosses keep the HUD bar).
- The boss bar (`BossBar`): its HP is a `HudBar`. One full bar per phase (`WorldReader.boss_phase_permille`: the HP
  between the phase's threshold and the next one's): a phase change empties it and refills it over 0.8 s; the line
  under it says "Phase 2 / 3" (en) / "Fase 2 / 3" (es). The rise keeps the sim's own fill (L22: exactly the intro
  ticks). The phase marks and the final boss's three segments are gone: **the final boss shows one bar for the body
  fighting now, the line naming it only ("The Colossus"), no count (O59)**; the next body's name appears as it rises
  and its rise fills the bar. The Fallen's window line (N2) stays.
- Invulnerable (`WorldReader.boss_invulnerable`: invulnerable ticks, a shielded pattern (`boss_shielded`), a phase
  gate, a final shatter): the bar turns steel blue (`BossBar.INVULNERABLE` `#8FB8E8`) and the line says
  "Invulnerable" (en and es), with "· 1 shield left" / "· N shields left" ("1 escudo restante", "N escudos
  restantes") from `WorldReader.boss_shields_left`. **No store counts shields**, so the reader derives it: the phase
  gates still to come. On a final body, its own gates only (O59: nothing hints at the bodies to come). OWNER_TODO D47.
- New strings: `HUD_BOSS_INVULNERABLE`, `HUD_BOSS_SHIELD_ONE`, `HUD_BOSS_SHIELDS`, `HUD_BOSS_PHASE` (en, es).

## Commands
```
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<file> -gexit
  (each of tests/unit/presentation/test_health_bars.gd, test_final_boss_views.gd, test_boss_views.gd,
   test_boss_challenge_views.gd, test_status_visuals.gd after O59; tests/e2e/test_e2e_health_bars.gd,
   test_e2e_final_boss.gd, test_e2e_nemesis.gd, test_e2e_prism.gd, test_e2e_boss_strikes.gd,
   test_e2e_damage_soak.gd, test_e2e_run_flow.gd, test_e2e_bosses.gd, test_e2e_bosses_2.gd,
   test_e2e_boss_challenge.gd)
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=<dir> -ginclude_subdirs -gexit
  (each of res://tests/content, res://tests/arch)
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10
  (three times on `02f23d5` (a `git archive` copy, imported) and three on this tree, alternating)
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/health_bars_n4.gd
```

## Results (raw summary lines)
Lint:
```
994 files would be left unchanged
src/application/content_compiler.gd:1001: Error: Max allowed file lines num (1000) exceeded (max-file-lines)
Failure: 1 problem found
```
**gdlint fails on a file this step doesn't touch**: `content_compiler.gd` is 1001 lines at `02f23d5` already
(`git show 02f23d5:src/application/content_compiler.gd | wc -l` → `1001`). Every file N4 touches passes gdlint.

`tests/unit/presentation` (the whole folder, on this tree before the O59 change):
```
Tests               734
Passing Tests       734
Asserts           1945665
Time              518.877s
```
After the O59 change, the files it touches:
```
test_health_bars.gd           Tests 10  Passing Tests 10  Asserts  70
test_final_boss_views.gd      Tests 10  Passing Tests 10  Asserts 307
test_boss_views.gd            Tests  8  Passing Tests  8  Asserts 394
test_boss_challenge_views.gd  Tests  5  Passing Tests  5  Asserts 217
test_status_visuals.gd        Tests  5  Passing Tests  5  Asserts  36
```
`test_health_bars.gd`: the hold from the first hit (hits at 0, 0.2, 0.4 s: still holding at 0.45 s, draining at
0.55 s, drained by 0.95 s), steady hits (10 a second for 3 s: the chunk's edge goes down every half second after the
first hold, the chunk never over 5 % of the bar), the big hit, the refill (0.6 at half time, full at 0.8 s), reduced
motion, the hero's HUD bar, six enemy bars in one MultiMesh (12 strips, then 0), the boss bar's phase refill and
invulnerable gate ("Invulnerable  ·  1 shield left", the colour), a shielded pattern (the Hive Lens's Prism Spiral:
"· 2 shields left"), and the final boss's bar (its name only, no count; the shatter's line counts no bodies).

E2e (main.tscn, real input) and the content and arch folders:
```
test_e2e_health_bars.gd     Tests 1  Passing Tests 1  Asserts   33
test_e2e_final_boss.gd      Tests 1  Passing Tests 1  Asserts   70
test_e2e_nemesis.gd         Tests 3  Passing Tests 3  Asserts 4189
test_e2e_prism.gd           Tests 1  Passing Tests 1  Asserts  167
test_e2e_boss_strikes.gd    Tests 1  Passing Tests 1  Asserts   27
test_e2e_damage_soak.gd     Tests 1  Passing Tests 1  Asserts   13
test_e2e_run_flow.gd        Tests 3  Passing Tests 3  Asserts   56
test_e2e_bosses.gd          Tests 1  Passing Tests 1  Asserts    7
test_e2e_boss_challenge.gd  Tests 1  Passing Tests 1  Asserts  194
test_e2e_bosses_2.gd        Tests 3  Passing Tests 2  Failing Tests 1  Asserts 29/30
    [Failed]:  hive_lens: its telegraph is drawn
tests/content               Tests 132  Passing Tests 132
tests/arch                  Tests   4  Passing Tests   4
```
**`test_e2e_bosses_2.gd` fails, and fails the same on the parent**: the same command on a `git archive 02f23d5` copy
(imported) gave `[Failed]: hive_lens: its telegraph is drawn`, `Tests 3`, `Passing Tests 2`, `Failing Tests 1` (three
runs on this tree, one on the parent: the same assert each time). Not caused by N4 (no sim change; the Hive Lens's
telegraph is not drawn by any file N4 touches); left for the lead.

`test_e2e_health_bars.gd`: a Gun run, God and Spawn boss from the dev panel, the pad's right stick on the boss and
the right trigger held: the first hit opens the chunk; its edge holds for 22 frames while the shots keep landing,
then it drains while they still land; the trigger let go, the chunk drains to the fill and the fill is the HP.

## Perf (PF budget: one draw call for every chunk; CPU per tick)
The probe's frame cost of the new node (the Gun's level-5 build on 6 dummies, 10 s; `frame cost by node`, ms per tick
avg) and the totals:

| Run | base `total_ms` avg / p95 | N4 `total_ms` avg / p95 | N4 `BarChunks` |
|---|---|---|---|
| 1 | 6.883 / 12.448 | 6.984 / 13.217 | 0.019 |
| 2 | 6.761 / 12.132 | 6.886 / 12.619 | 0.016 |
| 3 | 6.848 / 12.475 | 7.132 / 12.792 | 0.016 |

The base's `ActorViews` row reads 0.005–0.006 ms (its flash countdown); on N4 the probe printed no `ActorViews` row and
`BarChunks` 0.016–0.019 ms. The total moved +0.10..+0.28 ms avg, inside the container's ±15 % run to
run. Draw calls in the render (RenderingServer `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`, shot 5 vs 6, the same
frame with the chunk layer shown and hidden, six hurt enemies, 12 strips): **703 vs 702**: one draw call for all the
chunks.

## Shots ([`n4_shots/`](n4_shots/), raw lines)
```
health_bars_n4: res://build/shots/v0.8.0/n4/1_chunk_mid_hold.jpg (tick 114) bar: target 0.800 fill 0.800 chunk 0.200 big false invulnerable false line '' phase 'The Colossus' | enemy chunk strips 0 | draw calls 362
health_bars_n4: res://build/shots/v0.8.0/n4/2_big_crit_chunk.jpg (tick 104) bar: target 0.607 fill 0.607 chunk 0.393 big true invulnerable false line '' phase 'The Colossus' | enemy chunk strips 0 | draw calls 373
health_bars_n4: res://build/shots/v0.8.0/n4/3_refill_mid_way.jpg (tick 112) bar: target 1.000 fill 0.458 chunk 0.000 big false invulnerable true line 'Invulnerable' phase 'The Colossus' | enemy chunk strips 0 | draw calls 379
health_bars_n4: res://build/shots/v0.8.0/n4/4_invulnerable_bar.jpg (tick 141) bar: target 1.000 fill 1.000 chunk 0.000 big false invulnerable true line 'Invulnerable' phase 'The Prism' | enemy chunk strips 0 | draw calls 506
health_bars_n4: res://build/shots/v0.8.0/n4/5_enemy_bars.jpg (tick 180) bar: target 1.000 fill 1.000 chunk 0.000 big false invulnerable false line '' phase 'The Colossus' | enemy chunk strips 12 | draw calls 703
health_bars_n4: res://build/shots/v0.8.0/n4/6_enemy_bars_chunk_layer_hidden.jpg (tick 180) bar: target 1.000 fill 1.000 chunk 0.000 big false invulnerable false line '' phase 'The Colossus' | enemy chunk strips 12 | draw calls 702
```
1. A burst of four small hits on the Colossus, 0.4 s after the first: the chunk holds all four (0.8 → 1.0).
2. A small hit, then a crit of 18 % of its HP (36 % of the phase's bar): a 0.39 chunk, lit.
3. The Colossus's 50 % gate: its second phase's bar growing back (0.46 of the way), blue, "Invulnerable", PHASE SHIFT.
4. The Prism's Cross spinning (shielded): the blue bar, "Invulnerable", her name only.
5. Six Chargers hit for 20–80 %: the light strips each side of each red fill (6: the same frame, the layer hidden).

The shots show the Colossus's and the Prism's shield lines without a count (their own gates are none left there); a
floor boss's count ("· 1 shield left") is proved by the unit tests, not rendered. How the motion feels, and the
values (0.5 s hold, 0.4 s drain, 0.8 s refill): **OWNER ONLY**.

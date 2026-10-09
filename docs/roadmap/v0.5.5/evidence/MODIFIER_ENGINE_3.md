# Step MX3: the modifier engine, stage 3 — the visual layers (v0.6.0)

Design: [`../../../design/MODIFIER_ENGINE.md`](../../../design/MODIFIER_ENGINE.md) §4 (owner pick "Element core, heat
edge") and "Order of work" 3. Contracts: [`PRESENTATION_CONTRACTS.md`](../../../architecture/PRESENTATION_CONTRACTS.md)
§4 (MX3 rows, ground marks) and §7 (the attack-form budget); [`ART_DIRECTION.md`](../../../art/ART_DIRECTION.md) §4
(element palette). Presentation only: no sim outcome, no golden, no new randomness.

## What was built
All under `src/presentation/world_view/attack_forms/` (new files, so it merges beside MX2):
- `AttackFormLooks` (pure): `compose(spec, heat tier, {crit, weight})` → the look. Form → which pools; size / reach /
  count / spread / directions → scale, number and layout (`angles_of`: a fan over the spread, `circle` evenly round,
  `back` adds the mirror; a halo of 12 shots is 12 darts evenly round). Elements → core colour and particles: storm
  `#7FB2FF` crackle, ember `#FFAA33` with orange sparks, frost `#B5F2FF` shards, venom `#5FE03C` drip, void `#8B55FF`
  smear, bleed MX1's blade tint. Two elements: the first's core, the second's rim (half the particles each). Heat →
  the edge: `HeatLooks.attack_color(rim, tier)` (its values untouched). Behaviour → cues: pierce a long streak, bounce a
  flash at the bounce, home a curved trail, return a tether. `damage_mul_permille` (or `weight`) → thicker and brighter;
  crit → a white-hot (`HeatLooks.WHITE_HOT`) flash. `ground_safe()` keeps every flat floor mark (zone patch, lob circle,
  ring / burst fill) out of the telegraphs' hostile hue band (300°–34°, saturation ≥ 0.35) by leaning it toward the
  player's cool core; only the light rising off the floor carries the heat edge.
- `AttackFormMeshes`: shared meshes (quad, dart, disc, patch, ring, raised band, shard, bomb, spark) with their falloff
  in vertex alpha, one additive unshaded material (the A3 audit's rule: a flash of light is additive, its colour over
  1 feeds the scene's glow) and one lit material for matter (the lob's bomb shell). Built once; nothing toggles a
  material feature at runtime.
- `AttackFormPool`: one `MultiMeshInstance3D` per form layer (21) and per particle kind (5), fixed size (384 / 600),
  refilled each drawn frame.
- `AttackFormCanvas`: the budget (at most 1,024 form meshes and 1,200 particles a frame, live attacks first, then the
  newest effects; at most 256 effects), `spawn(spec, origin, angle, opts)` for any spec, the eight layouts, stateless
  particles (hash-seeded, the same every frame), all timed by sim ticks (start tick + life, drawn at the frame's tick
  plus the physics interpolation fraction).
- `AttackFormView` (in `WorldViewRoot`): the live wiring, read through `WorldReader` only — the Blade's arc layer when
  the step spec has an element / cue / weight; every player projectile in **its own spec's** look (MX2's
  `spec_key`); Overcharge's burst; the Static Chain jump (beam); crits; MX2's runners: rings at the runner's radius
  now (the drawn front is the hit front), every patch that names a spec, every bomb on its arc over its blast circle and
  its landing, the orbit blades' element glow and trail. With the view present, `ElementVisuals` and `AbilityVisuals`
  (`forms_drawn`) leave those to it and keep what names no spec (Napalm Drone's patches, the drones, the blades' steel).
  Plain attacks (no element, cue or weight) add nothing over the v0.5 blade and dart: the v0.5.9 look is unchanged
  until a card changes the spec.
- `WorldReader` read-only additions: `attack_spec_at(key)`, `projectile_spec_key(i)`, `bomb_spec_keys()`,
  `fire_spec_keys()`, `rings_live()`.
- Options > Display > **Effects density** (Low / Medium / High; default High; `GameSettings` `effects_density`,
  `ViewPrefs.effects_density`): particles × 0.25 / 0.55 / 1, mesh cap 384 / 640 / 1,024. Strings `UI_EFFECTS_DENSITY`
  ("Effects density" / "Densidad de efectos") and `UI_OPT_MEDIUM` ("Medium" / "Media") in en and es.
- Shot script `scripts/shots/attack_forms.gd`. No v0.5.9 lighting, environment, kit, room or model value was touched.

## Tests
- `tests/unit/presentation/test_attack_forms.gd` (15): the form numbers are the sim's (`WorldReader.FORM_*`,
  `AttackSpec.Trigger`); every layer is additive light (the bomb lit); each of the 8 forms from a constructed spec → its
  pool, count and scale (arc segments at the reach, 3 arcs for `count 3, circle`; 12 darts evenly round for a halo; a
  fan's angles; a faster bolt a longer dart; a ring at its radius at the end and 3 staggered rings; a beam to its end;
  a zone for its life then gone; orbiters at their orbit; a lob over its blast circle, then its landing; a burst's rim at
  its radius); the budget (meshes and particles capped exactly, the oldest effects drop); the density (fewer particles
  low → medium → high, lower mesh cap at low, an unknown value falls back); the option row, its save / apply and its en
  and es strings.
- `tests/unit/presentation/test_attack_form_looks.gd` (10): two elements core vs rim and their particle shares; each
  element's own core and particle kind (cores ≥ 0.15 apart in RGB), every content element draws; the drawn core is the
  element colour × energy; the edge is `HeatLooks.attack_color(rim, tier)` at all four tiers and the drawn Hot edge is
  the meter's orange; no ground mark of any element or pair at Cool or Overclock is a hostile hue (bleed's own core is,
  only its floor mark leans); the four cues; crit flash is white-hot, weight thickens and brightens and caps; live:
  plain Blade / Gun add nothing, Ember Edge's swing spawns one arc at the hit reach, Cinder Shot rides every live bolt.
- `tests/unit/presentation/test_attack_forms_live.gd` (5, on MX2's runners): Arc Field's shock field drawn at the
  sim's radius in a non-hostile hue (and `ElementVisuals` leaves it when `forms_drawn`, still draws it alone); a frost
  ring at `ModifierAbilities.ring_radius` now, frost's core; Bomb Lobber's bombs over their `bomb_r` circle, hidden
  in `AbilityVisuals` when `forms_drawn`, the landing in ember (the bomb carries Ember Edge); the drone's bolts in
  their own spec's look (the gun's ricochet cue); the reader's key reads.
- The existing view tests are unchanged and green (`test_attack_view.gd` 6/6 in the suite below; the three new
  files 15/15, 10/10, 5/5 there).

## Full suite
Command: `bash /tmp/claude-0/vd.sh <worktree> mx3` (import, gdformat / gdlint, `scripts/verify.sh`), tree at `30d659b`
(MX3 merged with `claude/lucid-fermat-9wv2tf` at `321e66b`, MX2 included), worktree clean. Raw summary:
```
verify exit 0
Tests              1283
Passing Tests      1283
check_gut_log: ok (1283 passing, minimum 1253)
```
From `/tmp/claude-0/vd_mx3.clean.log`: `Scripts 201`, `Time 2460.039s`; `grep -c "SCRIPT ERROR"` → 0,
`grep -c "Ignoring script"` → 0. Run alone with `-gtest`, `tests/unit/application/test_settings_profile.gd` fails its
round-trip case (an InputMap read) with or without this step's `game_settings.gd` change; in the full suite it passes.

## Export smoke
Command: `cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh` (on `30d659b`). Raw output (the check list):
```
manifest: b22f3301eada451b08db0146544739c75898bf676d808c7af92596398eafa8c1 (248 files, 0 errors)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash b22f3301eada matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is Play / Jugar
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 87
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
exit 0
```

## Screenshots (real renderer)
Command (on `30d659b`):
```
XDG_DATA_HOME=/tmp/claude-0/mx3_xdg_shots xvfb-run -a godot --path . --fixed-fps 60 --audio-driver Dummy \
  --resolution 1280x720 -s scripts/shots/attack_forms.gd
```
Renderer line: `attack_forms: renderer=forward_plus` (xvfb + Mesa lavapipe). The script writes to
`build/shots/v0.6.0/attack_forms/`; the three PNGs were copied here by hand. Excerpt of the output (one line per row's
first tile; 45 tiles in all):
```
attack_forms: tile arc_0 tick=188 meshes=22 particles=39
attack_forms: tile bolt_0 tick=208 meshes=60 particles=15
attack_forms: tile ring_0 tick=228 meshes=4 particles=64
attack_forms: tile beam_0 tick=248 meshes=6 particles=54
attack_forms: tile zone_0 tick=268 meshes=2 particles=50
attack_forms: tile orbiter_0 tick=288 meshes=20 particles=5
attack_forms: tile lob_0 tick=308 meshes=12 particles=6
attack_forms: tile burst_0 tick=328 meshes=3 particles=55
attack_forms: tile cues_0 tick=348 meshes=52 particles=17
attack_forms: sheet res://build/shots/v0.6.0/attack_forms/attack_forms_sheet.png 1300x2340 tiles=45
attack_forms: res://build/shots/v0.6.0/attack_forms/attack_forms_ingame_blade.png tick=394 heat_tier=1 swing=3 effects=1 meshes=22 particles=68
attack_forms: res://build/shots/v0.6.0/attack_forms/attack_forms_ingame_forms.png tick=432 heat_tier=1 swing=0 effects=0 meshes=14 particles=54
```
Honesty note: an earlier run of the same script (before the last colour change) was still finishing its in-game shots
when this run started and appended to the same log file; its two in-game lines have the same ticks. The PNGs here are
this run's (written 06:00 / 06:02, after the earlier run had ended at 05:26).

- [`attack_forms_sheet.png`](attack_forms_sheet.png): the contact sheet, crops round the hero in the first room of
  Floor 1 (Ruins, its v0.5.9 mood). **Rows** (top to bottom): arc (half arc 1100, reach 1.9), bolt (a halo of 12),
  ring (2 staggered, radius 3.2), beam (3 over a spread), zone (radius 2.2), orbiter (5), lob (3 over a spread, mid-air
  over their circles), burst (radius 2.6), cues (a piercing homing fan of 5, a returning bolt with its tether, a bounce
  flash, a crit flash). **Columns** (left to right): ember; storm; frost core + void rim; venom; bleed core + storm rim
  at Hot heat (orange edge). Constructed specs through `AttackFormView.spawn` (the gamble shrine stands beside the
  start point).
- [`attack_forms_ingame_blade.png`](attack_forms_ingame_blade.png): the live game, Blade with Ember Edge and Conductor
  (two elements: one core, the other rim) mid-swing at Hot among six training dummies: the arc layer over KitView's blade.
- [`attack_forms_ingame_forms.png`](attack_forms_ingame_forms.png): the same fight later with MX2's Orbit Blades, Arc
  Field and Bomb Lobber granted (as the dev panel would): the shock field (ZONE) right of the hero and the orbit blades'
  glow, drawn from the sim's live attacks. No bomb was in the air on that frame.

What I see in them (not the owner's judgement): the forms and patterns read (the halo, the staggered rings, the
spread lobs over their circles, the orbiters); the element hues show but are soft on the ground forms under this
light, the zone and ring fills lean pale; the darts, rims and particles carry the colour better. Whether that is the
look the owner wants: `OWNER ONLY`.

## Goldens
None changed (`git diff claude/lucid-fermat-9wv2tf --stat -- tests/golden` is empty); the export smoke's 600-tick hash
`e5365ddb6dcb` matches.

## Known limits (honest list)
- The damage-multiplier weight reads `damage_mul_permille` from the spec, which `AttackSpec.read()` doesn't carry yet:
  live attacks draw at weight 1 until the stat cards become modifiers (MX stage 4) and the read includes it. Tested
  with constructed specs only.
- `directions`, `home` and `return` are read from the spec when present (MX stage 4 cards); no shipped spec sets them
  yet, so those cues are tested with constructed specs only.
- The Effects density is a three-way option row (the Options screen's cycler, like Lighting quality), not a slider.
- The live Blade arc layer is drawn once per swing over KitView's blade (the laser blade itself is still KitView's);
  the Twin Arc echo and the Skills keep their own views.
- No bomb happened to be in the air in the in-game shot; the lob is shown on the sheet (constructed) and tested live.
- Owner-only: whether the colours, the glow level and the density read well on their hardware: `OWNER ONLY`.

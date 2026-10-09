# v0.5.5 Step LK: evidence (A1, A2, A3, A6)

Branch `worktree-agent-a137005521eefc11d`, built on `claude/lucid-fermat-9wv2tf` (`8e248ab`), with that branch
merged in again at `e27e543` (the v0.5.9 "Embers" visual rework) in merge commit `5bba4ba`. The suite and the shots
below ran on the working tree of `5bba4ba` plus this step's uncommitted edits (the code in the step's commit; only
docs and the contact sheets changed after the suite started). Not a clean worktree of the final commit: noted, not
hidden.

## What was built
- **A2, heat-coloured attacks.** `HeatLooks.attack_color(base, tier)` and `HeatLooks.tier_of(state)`
  (`src/presentation/world_view/heat_looks.gd`): the attack's own colour below Hot, the heat meter's Hot orange
  (`HeatLooks.HOT`, `#FFA63A`) at Hot, its Overclock red (`HeatLooks.OVERCLOCK`, `#FF4A1A`) at Overclock and while
  overheated. The meter already draws its Hot and Overclock ticks in these two colours, so one table feeds both. Users:
  `KitView` (blade core, glow, slash trail and thrust streak; it reads the tier itself each sync; a hot core whitens
  less so the colour reads), `ActorViews` (a player bolt takes the tier colour when it is fired, `bolt_color()`),
  `SkillVisuals` (forecast fan, cleave sweep and flash, lunge streak, blast cone, tracers, muzzle flash). The visor's
  gradual heat tint (`PlayerAvatar.set_heat`) is unchanged.
- **A1, skill animations** (code-built hero, `PlayerAvatar`, animated as its combo poses are: targets from the sim's
  ticks, smoothed in frame time):
  - Lunge Cleave: a low lunge (front leg reaching, back leg trailing, body and hood pitched into it), the head and
    poncho wound back to the arc's starting side, then whipped through the arc. The cleave is drawn as a sweep across
    the real hit fan (the hero's edge out to edge + `reach_m`, ±`half_arc` = 180° with the data's 1024) led by a
    bright blade edge; it crosses over the lunge's last 4 ticks and reaches the far edge on the hit tick
    (`SkillVisuals.cleave_progress`, read by both the sweep and the pose), holds 6 ticks, fades over 10.
  - Scatter Blast: a braced, wide, low stance square to the aim; a recoil kick (lean back, hood thrown back) peaking
    on the blast's tick and easing out over the sim's recoil step-back (6 ticks); a muzzle flash; the cone flash is
    the real cone (2 × `half_cone` 341 = 60°, `range_m`).
  - Every `SkillVisuals` effect now ages in sim ticks (on sync), not frames.
- **A3, VFX audit** ([`VFX_AUDIT.md`](VFX_AUDIT.md), G1, 48 rows) against the v0.5.9 look. Applied (low-risk,
  material only): the vent's disc and the skills' flashes additive at lower alphas; the death pop's shards and the
  overheat steam shaded by the scene light. The rest is awaiting the owner. No v0.5.9 value (moods, lights, kit,
  ground, hero light, environment) was touched.
- **A6, art request** [`../../../art/requests/v0.5.5_bosses_2_models.md`](../../../art/requests/v0.5.5_bosses_2_models.md):
  an image prompt and a 3D model prompt for the Warlord, the Hive Lens and the Foundry (and the optional Lens Drone),
  in the style read from the owner's boss and kit models; linked from ART_DIRECTION §4.

## Tests added or changed
- New `tests/unit/presentation/test_heat_attack_colours.gd` (4): the palette is the meter's tier colours; the blade
  follows the tier from a real world; a bolt fired at 10 / 50 / 90 heat is cyan / orange / red; the skill effects
  take the tier colour.
- New `tests/unit/presentation/test_skill_animations.gd` (3): `cleave_progress` timing; the lunge pose, the wind-up
  and the whip, and the sweep landing on the hit tick with the hit's own half arc and reach; the blast's brace,
  recoil and the sim's step back, the cone and muzzle flash ageing out in ticks.
- `tests/e2e/test_e2e_kit.gd` (through `main.tscn`, real input only): after Q the hero takes the lunge pose and the
  sweep crosses the whole arc; after pad Y the recoil kicks the hero back and it braces. The dash check's wait went
  from 10 frames to 6 so the timing after the blast is unchanged (4 frames were added to read the recoil).
- `tests/e2e/test_e2e_heat.gd`: Hot from real swings, the blade is the tier colour and not its cool colour; after the
  vent it is back to its own colour.
- `tests/unit/presentation/test_heat_views.gd`: the blade reads its tier itself now, so the test syncs `KitView`
  before reading it, and checks it equals the meter's Hot orange.

## Full suite
Command: `bash /tmp/claude-0/vd.sh /home/user/zero-depth/.claude/worktrees/agent-a137005521eefc11d lk` (import,
`gdformat --check` + `gdlint`, then `scripts/verify.sh`). Raw summary lines (from `/tmp/claude-0/vd_lk.clean.log`):

```
verify exit 1
Tests              1115
Passing Tests      1114
Failing Tests         1

res://tests/e2e/test_e2e_heal_orbs.gd
* test_a_kill_drops_a_heal_orb_and_walking_onto_it_heals
    [Failed]:  with the card a kill dropped a heal orb
      at line 69
0/1 passed.
...
Scripts             179
Tests              1115
Passing Tests      1114
Failing Tests         1
Asserts           1235521/1235522
Time              1796.037s
```

**The one failure is not this step's.** The same test, run alone on this branch and on a copy of the branch with this
step's seven presentation files reverted to `e27e543`, fails the same way in both:

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_heal_orbs.gd -gexit
(this branch)            [Failed]:  with the card a kill dropped a heal orb   Passing Tests none / Failing Tests 1
(e27e543 presentation)   [Failed]:  with the card a kill dropped a heal orb   Passing Tests none / Failing Tests 1
```

It drives real kills with the Lifesprout card (Step EC's D9, 10 % per kill) and asserts an orb dropped; it fails at
the merged base. Reported to the lead; not touched here.

`bash scripts/ci/check_gut_log.sh build/gut.log` → `check_gut_log: FAIL: 1114 of 1115 tests passed` (the same
failure). Because GUT exited 1, `verify.sh` stopped before its own run of that guard.

This step's tests in that run: `test_heat_attack_colours.gd 4/4 passed`, `test_skill_animations.gd 3/3 passed`,
`test_e2e_kit.gd 2/2 passed`, `test_e2e_heat.gd 1/1 passed`, `test_heat_views.gd 7/7 passed`,
`test_kit_views.gd 5/5 passed`, `test_hit_feel.gd 3/3 passed`.

**Goldens:** unchanged. `tests/golden/test_replay_ground_plane.gd 2/2 passed` (`REPLAY| final=70ac7ca24761c818e8e103b4281da76358e98e880d80ff54754adefa0bfd0add`); no golden file was edited.

`tests/MIN_TEST_COUNT` (1076) was not changed; the suite now has 1115 tests (this step adds 7; the rest came with the
merge).

## Export smoke
Command: `cd /tmp && bash /home/user/zero-depth/.claude/worktrees/agent-a137005521eefc11d/scripts/ci/export_smoke.sh`
(exit 0). Last lines:

```
  ok    content validates inside the pack (0 errors)
  ok    manifest hash 370fedadb6c0 matches the project's
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

## Screenshots (A3)
Renderer: `xvfb-run` with Mesa lavapipe (`Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM
20.1.2, 256 bits)`). Commands (each pass, from the project folder):

```
xvfb-run -a godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vfx_audit.gd -- build=blade
xvfb-run -a godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vfx_audit.gd -- build=gun
```

Run twice: in this worktree (**after**) and in a copy of it with the seven presentation files this step changes
restored from `e27e543` (**before**). Raw lines, after, blade (the before passes print the same lines, checked with `diff`):

```
vfx_audit: renderer=forward_plus
vfx_audit: res://build/shots/v0.5.5/vfx_audit/blade/01_attack_cool.png tick=21 heat_tier=0 skill_kind=0 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/blade/02_attack_hot.png tick=43 heat_tier=1 skill_kind=0 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/blade/03_attack_overclock.png tick=65 heat_tier=2 skill_kind=0 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/blade/04_vent_blast.png tick=86 heat_tier=0 skill_kind=0 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/blade/05_skill_start.png tick=112 heat_tier=0 skill_kind=0 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/blade/06_skill_hit.png tick=121 heat_tier=0 skill_kind=0 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/blade/07_enemy_telegraphs.png tick=161 heat_tier=0 skill_kind=0 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/blade/08_element_abilities.png tick=201 heat_tier=0 skill_kind=0 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/blade/09_hits_and_deaths.png tick=210 heat_tier=0 skill_kind=0 projectiles=0
```

After, gun (`skill_kind=1`, Scatter Blast):

```
vfx_audit: res://build/shots/v0.5.5/vfx_audit/gun/01_attack_cool.png tick=27 heat_tier=0 skill_kind=1 projectiles=1
vfx_audit: res://build/shots/v0.5.5/vfx_audit/gun/02_attack_hot.png tick=49 heat_tier=1 skill_kind=1 projectiles=2
vfx_audit: res://build/shots/v0.5.5/vfx_audit/gun/03_attack_overclock.png tick=71 heat_tier=2 skill_kind=1 projectiles=4
vfx_audit: res://build/shots/v0.5.5/vfx_audit/gun/04_vent_blast.png tick=86 heat_tier=0 skill_kind=1 projectiles=2
vfx_audit: res://build/shots/v0.5.5/vfx_audit/gun/05_skill_start.png tick=112 heat_tier=0 skill_kind=1 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/gun/06_skill_hit.png tick=121 heat_tier=0 skill_kind=1 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/gun/07_enemy_telegraphs.png tick=161 heat_tier=0 skill_kind=1 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/gun/08_element_abilities.png tick=201 heat_tier=0 skill_kind=1 projectiles=0
vfx_audit: res://build/shots/v0.5.5/vfx_audit/gun/09_hits_and_deaths.png tick=216 heat_tier=0 skill_kind=1 projectiles=1
```

Contact sheets (crops round the hero, made from those PNGs): [`shots/vfx_audit_blade_before.jpg`](shots/vfx_audit_blade_before.jpg),
[`shots/vfx_audit_blade_after.jpg`](shots/vfx_audit_blade_after.jpg), [`shots/vfx_audit_gun_before.jpg`](shots/vfx_audit_gun_before.jpg),
[`shots/vfx_audit_gun_after.jpg`](shots/vfx_audit_gun_after.jpg).

What the shots show and don't:
- Blade at Hot: the blade is the meter's orange (after) instead of the old gradual lean, a pale pink-white (before). At Overclock the shot fell between swings, so
  no red blade is in the sheet; the red is proved by the unit and e2e tests, not by a shot.
- Gun: the bolts are small and mostly hidden under the Chargers' telegraphs in tiles 1–3, so their colour does not
  read in the sheet; proved by `test_bolts_take_the_heat_tier_colour_when_fired`.
- The cleave sweep (tile 6) and the blast's tracers and muzzle flash (gun tile 5) are visible; the poses are small at
  this zoom.
- The vent disc (tile 4) looks nearly the same before and after under the v0.5.9 light: the applied change is
  small there (VFX_AUDIT V10).
- The heat tier is 0 for the skill tiles (the vent reset it), so the skills show their cool cyan.
- Software rendering is slow under the v0.5.9 light (SSAO, SSIL); the shots are not a performance figure
  for any hardware.

## Owner only
- Does the orange / red read as "the current hit colour" in play? Does the cleave / blast feel matched? `OWNER ONLY`
- G1 on every VFX_AUDIT row marked awaiting owner. `OWNER ONLY`

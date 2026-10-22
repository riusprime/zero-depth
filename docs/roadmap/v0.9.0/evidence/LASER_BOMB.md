# v0.9.0 LZ + BM: the Laser and the Bomb forms (evidence)

Owner rows: C §6.2, §6.3 (verbatim in the PLAN), C46–C53, C72, C75, Q2–Q9, Q11, Q13, Q14 in [`../PLAN.md`](../PLAN.md);
forms F2, F3 in [`../ATTACK_FORMS.md`](../ATTACK_FORMS.md); the AS framework in [`ATTACK_SLOTS.md`](ATTACK_SLOTS.md).
Branch `v090-lzbm`, cut from `effd030a`. Machine: the owner's PC (Windows 11, Git Bash, i7-10700K, RTX 3060), Godot
4.7.2; GUT jobs in parallel, each with its own `APPDATA`.

Every run: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit
-gtest=<files>` (or `-gdir=<dir> -ginclude_subdirs`). Lint: `gdformat --check` + `gdlint` on every touched `.gd`
(clean).

## LZ: the Laser

### What was built

- **Card.** `gun_laser` (Laser / Láser, "Hold to burn a beam." / "Mantén para quemar con un rayo."): Rare, Gun only,
  slot Form, `loot_category` form. Its modifier (`data/modifiers/gun_laser.tres`) makes the Gun's shot a held beam:
  form BEAM, `beam_hold` 1, 9 m reach, 0.15 m wide, a damage tick every 0.1 s (6 ticks), `beam_permille` 800
  (+40 a level), `rate_scale_permille` 500, `move_permille` 750. A Form card's modifiers compile first wherever it
  sits in the wand (`Modifiers.build_modifiers`), so it always makes the Gun's own shot (never a trigger's cast).
- **Compatibility row** (`data/wand/attack_slots.tres`, ATTACK_FORMS F2): Twin, Pierce, Fire, Lightning, Frost, Venom,
  Bleed on; every other Pattern and Secondary off (Halo, Ring, Backfire, Spiral, Swirl, Ricochet, Homing, Echo, Big
  Shot, Rapid Fire, Split, Mine, Charge, Orbit, Boomerang, Threadline); Void (`gravity_well`, leaving in VP) off.
- **Sim** (`src/sim/combat/laser.gd`). The hold path is PlayerKit's existing one (a shot every period while SHOOT is
  held, the first at once); `Attacks._shared_form` hands a held beam to `Laser.fire`. `Laser.trace` is the one beam
  geometry (the hits and the view): from the hero's edge along the aim, a wall stops it, it stops on the first enemy
  or passes `pierce` of them. `PlayerKit.armed` is the old `can_attack` made public. The move slow is
  `Laser.move_factor` in World's move step. `AttackRate.form_rate` halves the attack-speed bonus for a form with
  `rate_scale_permille` 500 (`ItemEffects.shot_period_ticks`, `ShotCap.reserve`). New AttackSpec fields are
  LATE_INT_FIELDS (hashed only when not 0), so no golden moves.
- **View** (`laser_view.gd`, `beam_looks.gd`): per beam a camera-facing ribbon with a scrolling strip (the owner's
  `beam_core_<look>` PNG in `assets/textures/vfx/` when installed, else a code-made 256 × 32 strip), a muzzle glow and
  a flickering impact star where it ends on an enemy or a wall; with the effects layer the element's accent along the
  beam (VfxLayer.line: Fire's flames, Lightning's arcs, Frost's motes, Venom's and Bleed's drips) and sparks and a light
  at the impact. Looks: default energy blue (clean core, travelling pulses), Fire layered (white-yellow core in orange
  tongues), Lightning blue-white (a jagged arc), Frost pale cyan (frost motes), Venom toxic green (bubbles), Bleed dark
  red (streaked). Impacts differ by spikes, softness and flicker.
- **Sound.** `laser_loop` (0.5 s, seamless: every partial and the wobble complete whole cycles; `smpl` loop chunk),
  held by `AudioDirector.hold` while the beam fires. Rendered by a pure-Python copy of `generate_sfx.py`'s pipeline
  (numpy is not installed here); `generate_sfx.py` holds the recipe (`s_laser_loop`, `SFX_LOOPS`). A later numpy run
  may rewrite the file with a slightly different hash.

### Rules decided (simplest reading; listed for the owner)

| Question | Rule |
|---|---|
| **Q8's numbers disagree** (needs the owner) | "10 ticks/s at 18 % of an orb hit" gives 10 × 0.18 × 5 = 9 DPS, **0.27 ×** the orbs' 33.3 (5 every 9 ticks), not the "≈ 1.2 ×" Q8 says (and 18 % of 5 is 0.9, under the 1-damage step). Kept: 10 ticks a second and 1.2 × the orbs' single-target DPS (the outcome the owner's words ask for: "competitive, potentially higher"), so each tick is **80 %** of an orb hit (4 damage), `beam_permille` 800 in data. To get 18 % instead, set `beam_permille` to 180 (the dither below keeps it exact). |
| Elements per tick | A beam's statuses and its hit hooks (Lightning's jump, a trigger's cast) fire only on "feeding" ticks: the beam period over the Gun's own shot period (6 / 9, two ticks in three), dithered exactly. A beam held on one enemy feeds it as often as the orbs would (measured: 66 Venom feeds in 10 s, orbs 66). A Twin's second and third beams feed at the secondary proc (500), as a second orb. A kill always runs On Kill (Fire's burning ground). |
| Damage in whole numbers | Each beam's tick damage is the shot's × beam_permille × its share, in thousandths, dithered over the ticks (`Laser.dealt`): exact on average. Twin Lv 1: 2 beams × 2.4 = 4.8 a tick. |
| Attack speed | At half its bonus on the tick period (`AttackRate.form_rate`), after the curve; a cut (Heavy Hands) also at half. |
| Caps | The beam is no projectile: no ShotCap room or spend, `ShotCap.shots` = 1. A trigger cast from a feeding tick is a projectile and counts as any cast. |
| Twin | 2 parallel beams ~0.5 m apart at Lv 1–4 (60/70/80/90 %), 3 at Lv 5 (70 %, the outer two 15° out): GunForms' lanes with a 0.2 m lane radius. |
| Move slow | 75 % while the beam fires (SHOOT held, the hero may attack, the Laser is the form). |
| Levels | The Laser card levels like any card: +5 % of an orb hit per tick a level (beam_permille 800 + 40). |
| Void | Off for the Laser (Q11 lists five elements; VP retires `gravity_well`). |

### Tests (raw summary lines)

| Run | Summary |
|---|---|
| `tests/unit/sim/test_laser.gd` (16: card, 10 ticks/s and 1.2 ×, first enemy, Pierce, wall and 9 m, Twin 2/3, Twin share, attack speed at half, 75 % move, per-tick feeding, Lightning's jumps, no shot budget, the row offers only its cards, replaces the Orbs, any wand position, a later form replaces it) | in the sim run below |
| sim: test_wand, test_combos, test_attack_slots, test_shot_cap, test_laser, test_player_builds, test_rewards, test_attack_rate, test_gun_pool, test_wand_compile, test_build_slots, test_offers, test_items, test_player_kit, test_gun_feel, test_loot_rewards, test_loot_pacing, test_shop | `Tests 248 / Passing Tests 248 / Asserts 5195` |
| goldens + arch: tests/golden/test_replay_ground_plane, test_modifier_equivalence, test_state_hasher, tests/arch/test_layering, test_sim_purity | `Tests 13 / Passing Tests 13 / Asserts 13183` (no golden moved) |
| test_modifier_smoke (the every-card soak) | `Tests 8 / Passing Tests 8 / Asserts 12564` (after its card count went 95 → 96) |
| tests/content (whole folder) | `Tests 138 / Passing Tests 138 / Asserts 9984` |
| presentation: test_laser_view, test_attack_forms_live, test_plaques, test_card_frames, test_audio_director, test_attack_slot_views, test_attack_form_looks | `Tests 59 / Passing Tests 59` |
| e2e: test_e2e_laser, test_e2e_attack_slots, test_e2e_audio, test_e2e_gun_pool | `Tests 5 / Passing Tests 5 / Asserts 56` |

The DPS line (test_laser, its `gut.p`): `LZ one target, 10 s held: beam 400 dmg in 100 ticks, orbs 330 dmg in 66
hits, ratio 1.212`; the feeding line: `LZ venom feeds in 10 s on one target: beam 66 (100 ticks), orbs 66`. The e2e
(`test_e2e_laser`, the altar's Laser card, right click held on a dummy): `LZ e2e: dummy hp 4940 / 5000 after 90 frames
held`.

Data tests that count cards were raised by one with a "v0.9.0 LZ" note (items 108, modifiers 96, the item pool 60, the
Gun and rare lists). `data/credits/licences.tres` rebuilt (`scripts/content/build_credits.gd`: the sound count 94 → 95).

### Shots

`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/laser_bomb.gd` (RTX 3060) →
`build/shots/v0.8.0/lzbm/`, copied by hand to [`lzbm_shots/`](lzbm_shots/): `1_laser_default` … `6_laser_bleed`
(the beam held 20 ticks at a dummy 5 m out, Ruins stage).

## BM: the Bomb

NOT YET BUILT (Step BM, the next commit).

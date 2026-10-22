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

### What was built

- **Card.** `gun_bomb` (Bomb / Bomba, "Throw bombs that burst." / "Lanza bombas que estallan."): Rare, Gun only, slot
  Form. Its modifier (`data/modifiers/gun_bomb.tres`) keeps the Gun's shot a bolt and makes it a bomb: `blast_mm`
  2200, damage × 4.5 (+0.225 a level; 5 → 22, rounded down by the multiply), one a second (period 1.0 s), 12 m/s for
  0.667 s (8 m), radius 0.3 m, `rate_scale_permille` 500.
- **Compatibility row** (ATTACK_FORMS F3): Twin and the five elements on; Halo, Ring, Backfire, Spiral, Swirl and every
  Secondary off; Void off (as the Laser's).
- **Sim** (`src/sim/combat/bomb.gd`). World's projectile pass skips a bomb's hit on touch (`Bomb.touches`); the bomb
  ends there (or on a wall, or at the end of its 8 m), and `Attacks.on_projectile_end` bursts it (`Bomb.blast`): every
  enemy within the radius (the area stat scales it) takes the bomb's damage once, under its spec (its elements'
  statuses per enemy as a projectile hit, On Hit / On Kill hooks per enemy), with one `BLAST` event (SimEvent.Kind,
  appended). `Attacks.merged` is split into `merged_at`, the existing 8-a-tick blast budget, which the bomb uses. The
  new AttackSpec field is a LATE_INT_FIELD (no golden moves).
- **View** (`bomb_view.gd`): a low-poly faceted iron bomb with a brass fuse cap, tumbling as it flies, and a flickering
  fuse spark in the element's colours (HeroPulseViews and AttackFormView leave bombs to it); each `BLAST` a flat ring
  sweeping out to the blast's radius and fading, in the element's look (BeamLooks' colours), with the owner's
  `blast_ring` PNG when installed (else a code band), plus VfxLayer's burst of the element (the fire explosion for Fire
  and the default).
- **Sound.** `bomb_throw` (new placeholder, 0.26 s whoosh and thump; pure-Python render as LZ's, recipe
  `s_bomb_throw` in `generate_sfx.py`) replaces the orb's `bolt_fire` on a Bomb run; the blast plays the existing
  `bomb_blast` (the retired Bomb Lobber's sound, kept as the id the art list names).

### Rules decided (simplest reading; listed for the owner)

| Question | Rule |
|---|---|
| Flight (Q9 "Straight") | A straight bolt; bursts on the first enemy touched, on a wall, or at 8 m. Its touch deals nothing; only the blast hurts (the enemy touched is in the blast). |
| Damage | 4.5 × the orb's 5 = 22.5, rounded down to 22 by the card's multiply (4.4 ×). |
| Blast | 2.2 m, every enemy in it once (centre to the enemy's edge), area stat scales it. |
| Attack speed | Half its bonus (as the Laser). |
| Twin | 2 bombs side by side at Lv 1–4, 3 fanned at Lv 5, each at Twin's share (Lv 1: 13 each; two blasts land apart, so the pair is not double on one target). The extra bombs feed statuses at the secondary proc. |
| Elements | On the blast, per enemy in it (Venom and Fire tested on three). Fire's burning ground still comes from a burning enemy's death (XP); the blast is the only explosion. |
| Overlap | Past 8 blasts a tick, one within its radius of a blast already set off merges into it (the existing budget, now `Attacks.merged_at`). |
| Replace | A Bomb card replaces the Laser and a Laser card the Bomb (one Form). |
| Caps | Bombs are projectiles: they go through ShotCap like any shot (a Twin volley is 2–3, far under 12 an attack and 40 a second). |

### Tests (raw summary lines; final code)

| Run | Summary |
|---|---|
| `tests/unit/sim/test_bomb.gd` (11: card, 1 a second bursting on the first enemy with only the blast hurting, wall and 8 m, the blast hits all in 2.2 m once, attack speed at half, Twin 2/3 at its share, elements on the blast, the 8-a-tick merge, the row and never Ring, Bomb ↔ Laser) | in the sim run below |
| sim: the LZ list + test_bomb, test_mx4_modifiers, test_mx4_modifiers_2, test_modifier_abilities | `Tests 299 / Passing Tests 299 / Asserts 5703` |
| goldens + arch (as LZ) | `Tests 13 / Passing Tests 13 / Asserts 13234` (no golden moved) |
| test_modifier_smoke (the every-card soak) | `Tests 8 / Passing Tests 8 / Asserts 12946` |
| tests/content (whole folder) | `Tests 138 / Passing Tests 138 / Asserts 10016` |
| presentation: the LZ list + test_bomb_view | `Tests 62 / Passing Tests 62 / Asserts 8017` |
| e2e: test_e2e_laser, test_e2e_bomb, test_e2e_attack_slots, test_e2e_audio, test_e2e_gun_pool | `Tests 6 / Passing Tests 6 / Asserts 68` |

The e2e (`test_e2e_bomb`, the altar's Bomb card, right click held on a group of three dummies): `BM e2e: 3 of 3
dummies hurt after 90 frames held`. After BM's bomb-view tweak (its colour and the spark on top) test_bomb_view was
re-run: `Tests 3 / Passing Tests 3`.

Card counts raised again by one with a "v0.9.0 LZ, BM" note (items 109, modifiers 96 → 97, the pool 61);
`data/credits/licences.tres` rebuilt (95 → 96 sounds).

### Shots

Same command → `7_bomb_flight` (tick 10), `8_bomb_blast` (tick 24, the default ring), `9_bomb_blast_fire` (Fire) in
[`lzbm_shots/`](lzbm_shots/).

### Not run here

The four old-save tests failing on the base (`World.walls: the snapshot's floor differs…`, test_old_saves ×2,
test_e2e_old_save, test_ascension_saves `test_an_older_payload_is_loop_one`) and the Spanish-locale ones
(test_frozen_shore, test_starfall) were not run (known on `effd030a`, not these steps).

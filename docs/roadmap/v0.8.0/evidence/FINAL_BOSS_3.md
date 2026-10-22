# v0.8.0 Step FB3: the Nemesis, the final boss's third body (evidence)

Owner O17 (2026-10-14, verbatim in [`../FINAL_BOSS.md`](../FINAL_BOSS.md)): "the third model, the small black one.
That's supposed to be the nemesis of the main character, and it would be like a fight where he mimics some of the
movements of the main character and uh, has a mix of both a melee and range fight." G1 FINAL_BOSS row F6, owner pick
"Weapon + dash + 2-3 cards (Recommended)": it uses your weapon and dash, echoes your moves and casts the strongest 2–3
cards of your wand; F7 "Phase-by-phase mix": "Nemesis takes its HP and damage from your own build, an even duel"
(2026-10-14).

Build: branch `v080-fb3` from `1bace56`. Every command below ran on that branch's working tree before the
`v0.8.0 Step FB3` commit (its SHA is in the hand-off report, not here). Machine: a shared cloud container, Godot
4.7.2.stable; shots on llvmpipe (software Vulkan) under xvfb, not the owner's hardware.

## What was built

| Row | As built | Starting values (data: `data/final_boss/nemesis.tres`; F10 Bosses page) |
|---|---|---|
| F6, **your weapon** | As it rises the Nemesis reads your build once (`NemesisBuild.prepare`; a card taken later changes nothing mid-duel). **Blade run:** `nemesis_combo` swings your own combo steps in order, each with its arc and reach as your wand compiled them (`Modifiers.step`, `Attacks.arc_reach_m`), each following you (it steps in) until its lock, then held; after a combo it backs off and throws `nemesis_crescents` (the crescents or blades your wand throws, else 3 plain crescents). **Gun run:** your own shot with every card on it (`Modifiers.bolt`: count, spread, ring, back shot, splits), at range (`nemesis_volley`) and point-blank (`nemesis_point_blank`). The pick never takes the other weapon's attacks | combo 3 swings 0.5 s apart, 6 m/s step-in; crescents 3 × 18°, 2 volleys 0.35 s apart; volley 3 × 0.25 s; point-blank 2 × 0.2 s; every attack a 0.4 s lock |
| F6, **your dash** | When you dash, the fight notes it (tick phase 9) and the Nemesis dashes 0.25 s later with your dash (your distance over your ticks, your i-frames), your way, or the other way in its mirror stance; never out of a windup or a strike (a dash due then is dropped); it never hurts | `dash_reaction_seconds` 0.25 |
| F6, **your path, the mirror** | The fight records your position every tick (a 120-tick ring). Between attacks the Nemesis keeps a stance for 1.5 s, drawn from the ai stream: **echo** (it walks where you stood 0.5 s before), **mirror** (it stands across the arena's centre from you), **close** (at you), **back** (6 m off) | `echo_seconds` 0.5, `stance_seconds` 1.5, weights 3 / 2 / 2 / 2, `back_off_m` 6 |
| F6, **your cards** | The strongest 3 wand cards you hold (by level, then rarity, then the slot; never a trigger, a stat card, an ability or a retired card) are each compiled alone by the wand compiler on your weapon at their level (`WandCompile.for_world(...).spec`) and copied as a hostile cast (`NemesisCast`): its swing (a slash card: arc, reach, Double Slash's repeats up to 3 strikes), its volley (a shot card's count, fan, ring, back shot; a slash's thrown crescents; Split's splits) and its blast (Explosive, Mine, Fire's flame, Void's pull). Only the first hook level is copied and a hostile shot runs no spec, so nothing splits, explodes or casts again (BL's once-per-line, PF2's cast-free). Each `nemesis_card_1..3` winds up 1.0 s, locked for its last 0.5 s: the card's own name over its head, a violet sigil at its feet, its swing, lines and blast drawn on the ground | weights 3 / 2 / 2; arc repeats 0.2 s apart; clamps: shots 7–13 m/s, 0.15–0.5 m, ≤ 14 m, ≤ 12 a volley; reach ≤ 4.5 m; blast 1.0–3.0 m |
| F6, **fair** | Every strike shows locked for its lock before it lands; no shot is queued within 1.0 m (+ your radius) of you or in a wall; every volley goes through the hostile caps (`BulletPatterns.room`: 160 a tick, 900 alive; past it one LIMIT); no hit deals more than its cap | — |
| F7, **an even duel** | Its HP (`NemesisBuild.hp_of`) and its hit (`hit_of`, `cap_of`) come from your build (below). Loops and the hidden catch-up don't scale it: `RunState.scale_bosses` skips a mimic table (your build carries what loops gave you) | below |
| F8 (part) | Deaths named, en + es: "The Nemesis cut you down." (`CAUSE_NEMESIS_SLASH`), "The Nemesis threw your own slash back at you." (`CAUSE_NEMESIS_CRESCENTS`), "The Nemesis shot you with your own gun." (`CAUSE_NEMESIS_SHOTS`), "The Nemesis turned one of your own cards against you." (`CAUSE_NEMESIS_CARD`); the stand-in's `CAUSE_NEMESIS_DASH` removed (its dash never hurts). Codex line `BOSS_NEMESIS_DESC` rewritten for the real fight | — |
| F9 (part) | Its dash plays the hero's dash cue, lower (`AudioEvents`) | — |
| Victory | The Nemesis is the last body: its fall wins the fight (FB1's flow, unchanged): the victory recap's true ending line; the three achievements fire end to end (e2e below) | — |

### The formula (owner F7)

```
HP  = max_hp × build_hp_permille / 1000                                 (2.5 × your max HP)
    + Σ damage of the last n measured seconds × dps_target_ticks / (n × 60)   (your DPS × 12 s), when n ≥ 5
      (n = min(20, seconds the fight's meter closed): FB2's meter, which measures the Colossus's fight)
HP  = clamp(HP, 400, 150000)
cap = max(1, max_hp × 200 / 1000)                                       (a fifth of your max HP: never a one-shot)
hit = min(max(weapon_damage × 1500 / 1000, 8), cap)                     (Modifiers.weapon_damage: your build's hit)
an attack deals clamp(hit × damage% / 100 × weight‰ / 1000, 1, cap)     (combo 100 %, crescents 70 %, volley 80 %,
                                                                         point-blank 100 %, cards 120 % × the card's
                                                                         own weight: its damage ÷ the plain attack's,
                                                                         0.5..2.0)
```

Worked cases (the test's): max HP 400 and 100 DPS over 20 s → 1,000 + 1,200 = 2,200 HP; max HP 100 with nothing
measured → 250, raised to the floor 400; your weapon 11 → hit 16 (cap 20 at max HP 100); weapon 5,000 → 20. Integer
maths, so the same build and meter give the same numbers. Starting values (F10), for the owner's playtest.

### Presentation (reads only)

- **`NemesisClips`** (placeholders the owner's animations replace by name), in the hero's motion vocabulary: idle,
  walk (the run), `mimic_combo` (the slash: coil, cut across, follow-through; "swing"), `mimic_shots` (aim and shot;
  "aim", "recoil"), `card_cast` (a card raised and thrown down; "sigil"), `dash` (the low lean), shielded, flinch (the
  hit), stagger, roar, rise, death. Attack clips are named by their move (BossAnimator's convention).
- **`NemesisAvatar`**: the owner's small dark figure holds a dark copy of the run's weapon (black steel, a violet-red
  edge: a blade or a gun), swung, raised and kicked by the clips' parameters; the dash clip's lean while the sim says
  it dashes; the sigil lights its edge.
- **`NemesisViews`** (new, in `WorldViewRoot`): a card's name over its head (tr of your card's name key) and a violet
  sigil at its feet through the cast; dark afterimages along its dash, fading.
- **Ground and strikes**: a card's `marks` telegraph may hold an `arc` item (TelegraphViews); the Nemesis's swings
  strike as `nm_slash` (a steel arc) and a card's blast as `nm_cast` (a light burst) in a new `VOID` pattern (dark
  rifts, a violet glow) on the sim's strike tick (BossStrikeViews).
- **Shots**: `nemesis_bolt` (a pale violet spear on a black body) and `nemesis_crescent` (a new `crescent` mesh: a
  black blade bowed across its flight, a magenta-violet core), never the hero's colours.

### Old saves

`FinalFight.ready, weapon, hit, hit_cap, combo_half, combo_reach, shot, casts, echo_x, echo_y, echo_head, echo_n,
dash_due, dash_dir, dash_t, dash_vel, stance, stance_t` are in `WorldSnapshot.ADDED_SINCE_V05`; `NemesisCast` is a
state class. An FB2 save mid-phase-3 restores with no mimic state (`ready` false, hashing as before); the Nemesis reads
the build at its next tick and fights on (its HP stays as saved: FB2 saves at each body's start held the stand-in's).
They hash only once a mimic body has fought, so an earlier fight hashes as before.

### Sim and content

New: `src/sim/ai/boss_nemesis.gd`, `src/sim/ai/nemesis_build.gd`, `src/sim/world/nemesis_cast.gd`,
`src/sim/ai/boss_causes.gd` (BossAi's `cause_key`, moved unchanged to keep `boss_ai.gd` under the 1,000-line lint);
changed: `BossAttackTable` (`MIMIC_COMBO`, `MIMIC_SHOTS`, `CARD_CAST`, `weapon`, `card`), `BossTable` (the mimic
fields), `BossAi` (hooks), `FinalBoss` (the read at the rise, the record), `FinalFight`, `RunState.scale_bosses`,
`WorldReader` (`nemesis`, the moves, stances, effects), `WorldSnapshot`; content: `BossSchemas` (the three moves,
`WEAPONS`, `MAX_CARD_CASTS`), `BossAttackDefinition` (their checks), `FinalBossDefinition` (the mimic fields, their
checks), `FinalBodyCompiler`, `ContentCompiler`, `PatternCompiler`. Rules in SIM_CONTRACTS §10h, params in
CONTENT_SCHEMA §4 "v0.8.0 FB3". `FinalStubClips` is no longer used (left in place).

## Tests (raw)

Lint, on the final tree:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
925 files would be left unchanged
Success: no problems found
$ bash scripts/ci/gut_shard.sh --check
gut_shard: ok (327 test files in 6 shards)
```

Each batch ran as `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <-gtest=a,b,… | -gdir=…> -gexit`
(GUT totals as printed).

1. Sim: `test_nemesis, test_final_boss, test_prism, test_colossus, test_world_snapshot` (the snapshot guard among
   them), `test_ascension, test_readable_cause, test_bosses, test_bosses_2, test_boss_gates, test_damage,
   test_state_hasher, test_bullet_patterns`, and the wand / Blade combos: `test_blade_combos, test_combos,
   test_four_slash_combo, test_wand, test_wand_blade, test_wand_blade_order, test_wand_compile, test_wand_shared,
   test_wand_shared_order, test_wand_preview, test_wand_order_fight` (tests/unit/sim):
   ```
   Scripts              24
   Tests               316
   Passing Tests       316
   Asserts           13263
   Time              480.496s
   ```
2. `tests/content`, `tests/arch`, `tests/golden`, `tests/unit/application` (the saves, the achievements and the final
   achievements), `tests/unit/debug` (`-gdir=… -ginclude_subdirs`; before `test_dev_nemesis.gd` was added, batch 3):
   ```
   Scripts              45
   Tests               243
   Passing Tests       243
   Asserts           21037
   Time              81.109s
   ```
3. `test_dev_nemesis, test_nemesis_views, test_final_boss_views`:
   ```
   Scripts               3
   Tests                20
   Passing Tests        20
   Asserts             455
   Time              15.278s
   ```
4. Presentation: `test_nemesis_views, test_final_boss_views, test_prism_views, test_boss_signature_views,
   test_boss_signature_views_2, test_attack_visuals, test_attack_visuals_2, test_boss_animations, test_boss_rigs,
   test_boss_models, test_boss_models_2, test_audio_director, test_enemy_fireball_views, test_boss_fights_2_views,
   test_boss_views, test_boss_fight_views, test_boss_telegraph_parity, test_codex_view, test_run_recap`:
   ```
   Scripts              19
   Tests               162
   Passing Tests       161
   Failing Tests         1
   Asserts           40561/40565
   Time              186.901s
   ```
   The one, `test_boss_fight_views.gd` (every fireball look has a bright core off the hero's colours):
   ```
   [Failed]:  [0.33266824483871] expected to be > than [0.55]:  crown_orb: a bright core
   [Failed]:  [0.11790820211172] expected to be > than [0.2]:  crown_bolt's core is not a hero colour
   [Failed]:  [0.30785647034645] expected to be > than [0.55]:  nemesis_bolt: a bright core
   [Failed]:  [0.21015843749046] expected to be > than [0.55]:  nemesis_crescent: a bright core
   ```
   FB3's two looks were too dark: their cores are now `#B4A0FF` and `#E07CFF`. Again with the look tests:
   `test_boss_fight_views, test_boss_fights_2_views, test_boss_fight_views_3, test_nemesis_views`:
   ```
   Scripts               4
   Tests                25
   Passing Tests        24
   Failing Tests         1
   Asserts           627/629
   Time              24.587s
   [Failed]:  [0.33266824483871] expected to be > than [0.55]:  crown_orb: a bright core
   [Failed]:  [0.11790820211172] expected to be > than [0.2]:  crown_bolt's core is not a hero colour
   ```
   **Not FB3's:** FB2's Prism looks (`crown_orb` #F02848, `crown_bolt` #FFD6DC), lines FB3 doesn't touch (`git diff`
   holds no `crown` line); FB2's evidence didn't run this file. Not reproduced at the base here (the values are the
   base's). Left for the lead.
5. E2e: `test_e2e_nemesis, test_e2e_final_boss, test_e2e_prism, test_e2e_playground, test_e2e_achievements,
   test_e2e_ascension, test_e2e_old_save, test_e2e_saves, test_e2e_codex`:
   ```
   Scripts               9
   Tests                14
   Passing Tests        14
   Asserts             863
   Time              182.478s
   ```

Failures on the way (fixed before the batches above): the Playground's picker opens on the Gun (the Blade e2e pressed
Left); a typed-array assignment in the e2e; the Nemesis's attack clips first had the hero's names (`slash`, `shoot`,
`cast`), but BossAnimator plays the clip named by the data's move (`test_final_boss_views` checks it), so they are named
`mimic_combo`, `mimic_shots`, `card_cast`; the slash's "swing" didn't end at rest.

New tests:
- `tests/unit/sim/test_nemesis.gd` (26): its data; the weapon follows the run (the pick, the combo's steps, the Gun's
  own shot); the dash answered exactly a reaction later, the same way, mirrored the other way, dropped mid-attack,
  never hurting; the echo is the player's place `echo_ticks` ago and it walks it; the mirror stands at `home × 2 −
  player`; it backs off after a combo; the cards picked by level, rarity, slot (a tie: the rare first), the pick's
  determinism, triggers left out; each card's hostile copy (Split splits, Explosive's blast 1.4 m, Spread's count and
  fan from the wand compiler, Whirl's full circle, Wave's crescents, Double Slash's 3 strikes); a card locks for its
  lock then lands where it locked; hostile shots run no spec; the caps (shots_max, speed; none on the player; the
  hostile cap's single LIMIT); every swing locks before it lands; the HP formula and its clamps; the hit and its cap
  (a monstrous build still can't one-shot); deaths named; determinism over 900 ticks with dashes; a snapshot
  mid-card-cast round trips (400 ticks on); an FB2 save mid-phase-3 (the FB3 fields erased) restores, reads the build
  at its next tick and two restores go on the same; the last body's fall wins.
- `tests/unit/presentation/test_nemesis_views.gd` (8): its clips (the hero's vocabulary, each move's); the run's weapon
  in its hand; the blade swings with the sim's combo; the dash pose and its afterimages fading; a card's name and sigil
  through the cast, its parts on the ground, its blast struck in `nm_cast`; its swings struck in `nm_slash` on the
  sim's strike tick; its shot looks off the hero's colours and the crescents drawn; reduced motion.
- `tests/unit/debug/test_dev_nemesis.gd` (2): its numbers are F10 rows with their values; its data validates and a
  one-shot cap, a fourth card and an unknown weapon are refused.
- `tests/e2e/test_e2e_nemesis.gd` (3): main.tscn, real input only: the Playground on a Blade run and on a Gun run (a
  wand card added at level 3, God mode, "Phase 3"): it holds the run's weapon, uses only that weapon's attacks, answers
  the hero's dash (Space) with its own and casts the card, its name shown; a run on loop 2 (a labelled TEST HELPER sets
  the loop and the floor, F10's Restart floor rebuilds it): God mode and Kill boss through the Colossus and the Prism,
  End the run; at the Nemesis its HP is the formula, it answers a dash; Kill boss: the end panel, a victory, the true
  ending line, Crown Breaker, Untouched (no hit landed under God mode) and Beyond the Loop unlocked, no engine error.

Not run locally: the full suite (CLAUDE.md: once per version, on GitHub); `scripts/ci/seams.sh` (the lead's after the
merge); bot balance sims (not asked).

**Goldens:** `tests/golden` passed unchanged (batch 2). No golden fixture holds the final fight; the FB3 fields hash only
once a mimic body has fought.

## Shots

```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/final_boss_3.gd -- <n>   (n = 1..6, one at a time)
final_boss_3: res://build/shots/v0.8.0/fb3/1_nemesis_mirroring_across_the_arena.jpg (tick 241)
final_boss_3: res://build/shots/v0.8.0/fb3/2_nemesis_answers_the_dash.jpg (tick 169)
final_boss_3: res://build/shots/v0.8.0/fb3/3_card_cast_whirl_named_and_locked.jpg (tick 165)
final_boss_3: res://build/shots/v0.8.0/fb3/4_card_cast_wave_crescents_flying.jpg (tick 190)
final_boss_3: res://build/shots/v0.8.0/fb3/5_nemesis_falls_the_fight_is_won.jpg (tick 165)
final_boss_3: res://build/shots/v0.8.0/fb3/6_victory_recap_true_ending.jpg (tick 165)
```
Each exited 0 (each also printed Godot's exit notice "2 RID allocations … leaked at exit"); copied to
[`fb_shots/`](fb_shots/) as `fb3_<n>_<label>.jpg` (1280×720). The world is the final arena as the game builds it
(`FinalLab`) on a Blade run holding Wave L3, Double Slash L2 and Whirl L4 (granted as found cards), the fight jumped to
the Nemesis; the hero is held (except for its dash in shot 2) and kept up; the Nemesis's own picks are off and each shot
sets the stance or starts the card it shows:
- [`fb3_1`](fb_shots/fb3_1_nemesis_mirroring_across_the_arena.jpg): the mirror stance: it stands across the centre.
- [`fb3_2`](fb_shots/fb3_2_nemesis_answers_the_dash.jpg): the hero dashed; the Nemesis dashes after it, leaning in,
  its afterimages behind.
- [`fb3_3`](fb_shots/fb3_3_card_cast_whirl_named_and_locked.jpg): your Whirl cast back: "Whirl" over its head, the
  sigil, the full-circle swing locked in its void pattern.
- [`fb3_4`](fb_shots/fb3_4_card_cast_wave_crescents_flying.jpg): your Wave: its swing struck, the crescents flying.
- [`fb3_5`](fb_shots/fb3_5_nemesis_falls_the_fight_is_won.jpg): its segment ended (the shot's own hit, as Kill boss):
  the last body falls, the fight won, the bar gone.
- [`fb3_6`](fb_shots/fb3_6_victory_recap_true_ending.jpg): the end panel for that win, `EndPanel` built by the shot
  script with the recap keys Main uses from this world (so its time, 0:02, and kills, 1, are the jumped world's, not a
  played run's); the game's own path to it is the e2e above.

## Owner only

- The duel's feel, pace and difficulty, the formula's numbers (2.5 × max HP + 12 s of your DPS; your hit × 1.5, a fifth
  of your max HP at most), its look, the clips and the weapon prop: **OWNER ONLY**.
- Whether 3 cards (built) or 2 is right: **OWNER ONLY** (one number, `card_casts`).
- Frame rate on the owner's hardware in phase 3: **OWNER ONLY** (not measured here).
- The final names (working names in the strings): **OWNER ONLY**.

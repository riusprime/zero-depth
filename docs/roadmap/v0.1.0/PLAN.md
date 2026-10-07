# v0.1.0 — Combat Lab: one arena, three enemies, a swing, a charged shot, guard or blink (plan, owner-approved 2026-10-06)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **On the branch:** v0.0.1 "Ground Plane" at `b99a78c` (+ `ea8e403`, the playtest record) on
  `claude/lucid-fermat-9wv2tf`. `main` still doesn't exist (O3), so v0.1.0 continues on the same branch.
- **What the owner played (2026-10-06):** the v0.0.1 Windows build. Verbatim: *"the windows version I played was
  the bare minimun, just the box moving no enemies or no attacking so I could not really try it"*
  ([`../v0.0.1/PLAYTEST.md`](../v0.0.1/PLAYTEST.md)). That counts as the v0.0.1 playtest (ROADMAP §0.3); its
  feedback is this version's scope.
- **Owner rule:** anything that isn't a direct fix is decided before it's built. The four design questions below
  were answered on 2026-10-06.
- **Gates in this version:** the v0.0.1 gates still open (renderer, pitch, occlusion, kit values, the bench's stress
  miss) block nothing here; the defaults in use stay (Forward+, 35.26°, X-ray). The mid-version fight build
  (Step 7) is an owner check; the Options screen (Step 10) is a G2 mockup gate.

## Owner decisions (2026-10-06)
| Q | Question | Answer |
|---|---|---|
| Q1 | Primary attack | **Both: a melee swing and a charged shot** |
| Q2 | Utility in v0.1.0 | **Both, guard and a mobile skill (blink), picked before play** (PD-01) |
| Q3 | Enemy designs | **The proposals as written** (Charger, Warden, Needle below; every attack telegraphed ≥ 0.4 s) |
| Q4 | Delivery | **Playable fight first**: a Windows build as soon as the fight works; options and the rest follow |

## Every owner line → where it lands
| # | Owner line | Decision | Step |
|---|---|---|---|
| L1 | "just the box moving no enemies or no attacking so I could not really try it" | The fight comes first: damage, the primary, the utility, three enemies, death and restart, then a build for the owner | 1–7 |
| L2 | Q1: swing + charged shot | Press = swing (3-hit combo); keep holding = charge; release = bolt | 2 |
| L3 | Q2: both utilities, picked before play | Guard (hold) and Blink (press); a picker screen between Play and the arena; the last pick is remembered | 3 |
| L4 | Q3: the enemy proposals | Charger, Warden, Needle as specified below; `MIN_TELEGRAPH_TICKS = 24` | 4 |
| L5 | Q4: playable fight first | Steps 1–7 before options, accessibility and audio hooks | order |
| L7 | (fight build, 2026-10-07) "dash worked toward I was moving … same should happen with blink" | Blink goes the way you're moving (the aim only when standing still), like the dash | 7b |
| L8 | "with the controller the movement felt a bit different than with keys … check it is meant to be this way or can it be fixed" | Investigated: a stick's tilt went through two dead zones (Godot's, then ours), so ~36% of the travel did nothing and half tilt gave ~37% speed. Fix: one dead zone, full speed from 85% tilt | 7b |
| L9 | "both attacks should have different keys, in controller the triggers should be attacks and the R1 L1 should be the blink and dash" | Melee and shooting get separate buttons. Pad: LT melee, RT shoot, RB dash, LB utility. KB+M: left click melee, right click shoot, Space dash, Shift utility (lead's pick; remappable in Step 10) | 7b |
| L10 | "instead of charging one stronger attack we long press for continuous shooting that deals less damage each bullet" | Hold to fire continuously: 4 damage per bolt, 8.3 bolts/s (~33 dps, below the swing's ~45, so melee keeps its risk/reward). Replaces the charged bolt (changes Q1) | 7b |
| L11 | "movement feels okay, but we could improve it still on how it feels" | Open: the owner names what to change after the next build; L8's fix may cover the pad side | — |
| L12 | "a light and thin black stroke to borders of things … closer to a hand draw sketch … just the feeling" | A screen-space ink outline on every edge (walls, props, actors), thin and black, with a slight hand-drawn wobble. Three strengths are shown in game (Options: off / ink / sketch / sketch + paper) so the owner judges them live (a G2 pick in the build itself) | 7c |
| L6 | ROADMAP §4 v0.1.0 scope (approved roadmap) | Options (audio, display, remap, shake, reduced motion, colour-blind), SFX hooks with captions, readable-cause test, bench with real AI | 8–12 |

## Design (starting values; the owner tunes them after playing)
All numbers are **starting values** ([`../../design/GAME_BLUEPRINT.md`](../../design/GAME_BLUEPRINT.md) §C, §E).

**Player:** HP 100. 0.5 s of invulnerability after taking a hit. The dash (4 m, 0.15 s) is invulnerable for its
whole length.

| Verb | Rule | Numbers |
|---|---|---|
| Swing (press primary) | Instant. A 120° arc toward the aim, reach 1.6 m from the cube's edge, hits each enemy once. Pressing again during the follow window chains the combo | 10 / 10 / 18 damage; 14 ticks per swing; follow window 12 ticks after a swing ends |
| Charge (keep holding) | Charging starts 12 ticks after the press; you move at 50% while charging | full at 0.8 s |
| Charged bolt (release while charging) | A cyan bolt along the aim | 12 → 36 damage by charge; 16 m/s; stops at walls and the first enemy |
| Guard (hold utility) | Faces the aim. Hits from within ±60° of the facing are cut to 20% (per-mille 200, no flat reduction). No attacking, 40% speed while guarding | — |
| Blink (press utility) | Teleports toward the aim point, up to 5 m, stopping before walls. 0.1 s invulnerable | 2.5 s cooldown |

**Enemies** (`MIN_TELEGRAPH_TICKS = 24`, 0.4 s):

| Enemy | Behaviour | Attack and telegraph | Numbers |
|---|---|---|---|
| Charger | Runs at you | Within 6 m: locks a straight lane toward you and shows it (outline + filling) for 0.6 s, then charges along it up to 7 m, stopping at walls; hits once on contact. Then **dazed** 1 s (the punish window) | HP 45, 3 m/s, charge 15 m/s, 20 damage |
| Warden | Slow, turns to face you | A front shield (±60°) blocks your swings and bolts completely. Within 2.4 m: shows a circle around itself for 0.8 s, then slams it | HP 100, 1.6 m/s, turn 130°/s, 25 damage, 1.5 s between slams |
| Needle | Keeps 7 m away, backs off inside 5 m | Every 2.5 s: shows a locked aim line for 0.5 s, then fires 3 yellow bolts down it, 0.1 s apart | HP 30, 3.2 m/s, bolts 9 m/s, 8 damage each |

**Arena:** the v0.0.1 room. Three waves: (Charger, Needle) → (Charger, Warden, Needle) → (2 Charger, Warden,
2 Needle). Enemies appear at spawn points at least 6 m from you, with a 0.6 s spawn-in marker during which they
neither act nor take damage. The next wave comes 1 s after the last enemy dies. Clearing wave 3 shows **Arena
cleared**; reaching 0 HP shows **You died** with the cause. Both offer Restart and Main menu.

## Steps

### 0. Setup (docs)
- This PLAN, PROGRESS, the BLUEPRINT §C and §E tables filled, LOCKED_DECISIONS log rows, ROADMAP status.

### 1. Damage, health and death (sim + tests)
- **Files:** `src/sim/combat/damage.gd` (the pipeline of SIM_CONTRACTS §8 steps 1–5, minus items), actor HP and
  max HP, invulnerability ticks, the dead flag; deaths removed in tick phase 9; `World.add_freeze` used for hit-stop.
  Projectiles carry damage. The kernel scenario's dummies keep shooting harmless 0-damage shots.
- **Goldens:** the replay golden and the export-smoke hash change **on purpose** (new state in the hash).
- **Tests:** one `KILL` per death; dash and post-hit invulnerability; HP never below 0; provenance fields set.
- **Done when:** tests pass and the goldens are re-recorded and named in PROGRESS.

### 2. The primary: swing combo and charged bolt (sim + presentation + e2e)
- **Files:** `src/sim/combat/player_kit.gd` (swing, combo, charge, bolt); `PrimaryDefinition` in content; view: a
  swing arc flash, a charge ring, cyan bolts.
- **Tests:** arc hit/miss geometry; combo timing; tap-shorter-than-a-frame still swings; charge scaling; e2e:
  click swings, hold-release fires a bolt (mouse and pad trigger).

### 3. Utility: guard or blink, picked before play (sim + presentation + e2e)
- **Files:** guard and blink in `player_kit.gd`; `GuardDefinition`, `BlinkDefinition`; `UtilityPicker` screen
  (Play → picker → arena), remembered in the profile.
- **Tests:** guard cuts frontal hits to 20% and not rear ones; blink stops before walls; e2e: pick each, use it.

### 4. Enemies: Charger, Warden, Needle with telegraphs (sim + content + presentation)
- **Files:** `EnemyDefinition` (+ validation: windup ≥ `MIN_TELEGRAPH_TICKS`), `data/enemies/*.tres`,
  `src/sim/ai/enemy_ai.gd`, `src/sim/combat/attack_shapes.gd` (the one function per attack that both resolves the
  hit and draws the telegraph, EI-07), `TelegraphViews` (outline + fill from 0 to 100%), distinct silhouettes.
- **Tests:** each behaviour's state machine; `test_telegraph_parity.gd` (drawn area == hit area); Warden blocks
  from the front only; content validation rejects a short windup.

### 5. The arena: waves, death, restart, HUD (application + presentation + e2e)
- **Files:** `EncounterDefinition` (`data/encounters/combat_lab.tres`), wave director in the sim, end panels,
  HUD (HP bar, dash/utility cooldowns, wave counter).
- **Tests:** waves advance; death and clear panels; e2e: die, restart, back to menu.

### 6. Hit feel (presentation, sim hit-stop)
- Hit-stop 3 ticks on a swing hit, 5 on a full charged bolt, 4 when you're hit. Flash 3 frames. A small camera
  shake on taking damage and on a full bolt, with an on/off option. Death pop of shards (cosmetic stream).
- **Tests:** freeze ticks per event; the shake option turns shake fully off.

### 7. Fight build for the owner (release-lite)
- Tour updated (fight shots), `PLAYTEST_FIGHT.md` for the owner (OWNER ONLY answers), CI Windows artifact.
- **Done when:** the build is on CI and the owner has the sheet.

### 7b. Controls from the fight check (sim + application + e2e)
- Separate melee (InputFrame `PRIMARY`) and shoot (a new bit, `SHOOT`, appended). Hold shoot: a bolt every
  0.12 s, 4 damage, 18 m/s. The charged bolt goes away.
- Blink follows the move direction (the aim when standing still), always its full 5 m unless a wall is closer.
- Bindings: LT melee, RT shoot, RB dash, LB utility; left click melee, right click shoot, Space dash, Shift utility.
- Stick movement: one dead zone (Godot's), full speed from 85% tilt.
- **Tests:** the shoot cadence and damage; blink follows movement; e2e for every binding on both devices; the
  stick speed curve.

### 7c. Sketch outlines (presentation; shown in game for the owner to pick)
- A full-screen ink pass from depth and normals: thin black lines on every silhouette and crease, with optional
  hand-drawn wobble and paper grain. Options → "Outline style": off / ink / sketch / sketch + paper.
- Screenshots of all four in `evidence/OUTLINES.md`; the owner picks one in the next build.

### 7d. Second fight build for the owner
- `PLAYTEST_FIGHT_2.md`; Windows artifact.

### 8. Bench with real enemy AI (evidence)
- The reference encounter is now the real arena; re-run `sim_bench`, `evidence/BENCH.md`.

### 9. No damage without a readable cause (sim test)
- From the event log of scripted runs: every `DAMAGE` to the player traces to a telegraphed attack or a visible
  projectile.

### 10. Options (G2 mockups first)
- Audio, display, remap on both devices, shake and intensity, reduced motion, colour-blind modes (+ palette
  test), flash safety.

### 11. SFX hooks and captions
- Placeholder cues for the P1 list in `docs/audio/SFX_NEEDS.md`, each with a caption key.

### 12. Release
- Version `0.1.0`, patch notes en + es, tour, ROADMAP, README, PROGRESS final, PLAYTEST.md (fun without loot).

## Open items (what they block)
- O3 `main` (blocks the PR). O4 credit line.
- v0.0.1 gates (renderer, pitch, occlusion, kit values, bench stress miss): block nothing; defaults stay in use.

## Verification
- Tests per step, the full suite before every code push, CI green on both OSes, goldens changed only on purpose
  (Step 1), screenshot tour, the bench as evidence, then the owner's playtests (Step 7 and the release).

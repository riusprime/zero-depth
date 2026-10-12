# WAND_BLADE: does every Blade card rebuild the slash, in slot order, visibly, and level up?

- **Status:** RUN (agent: lint and the tests of the touched folders and their e2e; NOT the full suite, which is the
  lead's one run per wave)
- **Build:** the commits `ddb6e0a` … this step's commit on the agent's session branch (cut from
  `claude/lucid-fermat-9wv2tf` at `fb7dab3`); Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18 (cloud container)
- **Date:** 2026-10-12
- **Who ran it:** agent

Design: [`../../../design/WAND.md`](../../../design/WAND.md) B1–B16 (owner-approved, G1 "Approve all"; W5: "the slash
becomes a spell"). Contracts: [`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §8f;
[`CONTENT_SCHEMA.md`](../../../architecture/CONTENT_SCHEMA.md) §2 "the Blade pool". PLAN rows W4, W5, W7.

## The cards as built (every number a starting value; L = the card's level, 1–5)
| # | Card (id) | Ops (target `[weapon, melee]` unless named) | Per level | You see |
|---|---|---|---|---|
| B1 | Wide Arc (`wide_arc`, the v0.6 card's id) | +60° arc, +30 % reach (`reach_bonus_permille` +300) | +15°, +7.5 % | the blade's sweep (KitView reads the arc and reach) |
| B2 | Wave (`echo_slash`) | `ON_LAUNCH` hook: a bolt crescent as wide as the arc, tags `projectile, wave`, 60 % damage, 14 m/s, 0.5 s | +10 % damage, +0.1 s | a flying crescent (BladeFormView; `crescent` cue) |
| B3 | Split Wave (`split_wave`) | target `wave`: `ON_HIT` hook, 3 crescents over 80°, 50° wide, radius 0.2 m, 45 % | +1 crescent, +5 % | small crescents fanning out |
| B4 | Whirl (`whirl`) | `directions` circle (full arc), `motion` spin | +10 % reach | the blade spins all round; the hero's spin pose; `spin` cue |
| B5 | Double Slash (`double_slash`) | repeat 0.15 s later at 60 %, `echo_mirror` | +10 % repeat | a mirrored ghost slash: a criss-cross |
| B6 | Thrust (`thrust`) | `motion` thrust, damage × 1.3, reach × 2, arc × 0.4 | +0.1 × damage | the stab motion and streak; the hero's stab pose |
| B7 | Heavy (`heavy`) | damage × 1.7, knockback 1.5 m, +0.05 s hit-stop, swing speed −30 % | +0.1 ×, +0.25 m, +2.5 % speed | a slower, thicker blade; the hero braces; enemies slide back |
| B8 | Flurry (`flurry`) | swing speed +50 %, damage × 0.75 | +10 % speed, +0.025 × | faster swings with a longer trail (a blur) |
| B9 | Fissure (`fissure`) | `ON_END` hook (the arc's tip), 0.3 s later: a 4 m line, 0.6 m wide, 70 % | +0.5 m, +10 % | the crack growing ahead, then its eruption |
| B10 | Chain Cut (`chain_cut`) | `ON_HIT` hook: a seeking jump within 4 m, 60 % | +1 jump (`chains`), +5 % | the jump line (AttackFormView's chain beam) |
| B11 | Parry Edge (`parry_edge`) | `parry`: the arc cuts the enemy shots it touches (its hit tick and the rest of the swing) | +10 % damage | sparks where shots were cut; `cut` cue |
| B12 | Afterimage (`long_shadow`) | target `dash`: `ON_LAUNCH`, 0.15 s later, a copy of the last slash at 80 % | +10 % | a ghost slash where you dashed |
| B13 | Lunge Step (`lunge_step`) | `step_m` +1 m: each slash steps you forward (over ≥ 0.1 s) | +0.2 m | you drive forward; the hero leans in |
| B14 | Finisher+ (`finisher_plus`) | target `finisher` (the 4th step): `ON_LAUNCH` burst 3 m, 200 %, `carry` (it takes the slash's statuses, elements and hit hooks) | +25 %, +0.3 m | a big shockwave ring |
| B15 | Orbit Blades (`blade_orbit`) | `ON_LAUNCH` orbiter: a blade circling you at 1.6 m for 3 s, 40 %, resting 0.2 s after a hit, at most 6 | +7.5 % | blades orbiting you |
| B16 | Counter (`counter`) | within 0.5 s of a dash's end: × 2 damage (once per dash) and a `WHEN_COUNTER` crescent (8 m, 16 m/s, 100 %, tag `wave`) | +0.1 s, +0.1 × | a flash round the hero and a big flying wave |

Runner numbers no card names (Orbit Blades' count, turn and rest; Heavy's push time; Lunge Step's stride; the slowest
swing): `data/wand/blade_forms.tres` (`BladeFormsDefinition`), its own file for the dev panel.

**Old cards.** Wide Arc, Echo Slash, Long Shadow and Blade Orbit became B1, B2, B12 and B15 with their ids, kinds and
item indices kept (saves still name them). Twin Arc stays as it is (a v0.5 kind whose numbers the equivalence golden
pins); B5 Double Slash is a new card of the same repeat mechanism. For WN5's migration: `twin_arc` → `double_slash`,
`long_edge` → `wide_arc` (suggested; WN5 decides). No other old card was deleted or changed. Wide Arc no longer widens
the Gun's shots and blasts; Long Shadow and Blade Orbit are no longer offered on the Gun or as an Orbit Blades merge.

## Commands and raw outputs
NOT YET RUN (filled in below from the runs' outputs).

## Known limits (honest list)
NOT YET RUN.

## Owner only
Feel, the starting values, the names (Afterimage now names two cards until WN5 retires the blink one; Orbit Blades
names the card and the old ability): `OWNER ONLY`.

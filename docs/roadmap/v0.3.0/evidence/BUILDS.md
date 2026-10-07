# BUILDS: does a run start from Blade or Gun, with only that weapon, the L16 damage factors and out-of-combat regen?

- **Status:** RUN (unit tests, e2e, boss fight-length bots, render); feel and balance are OWNER ONLY
- **Build:** the working tree of the commit that adds this file (`v0.3.0 Step P`), parent `817fc7d`, on the
  workstream branch `worktree-agent-a2b90bfa23aadeba2`; Godot `4.7.2.stable.official.ed1daf0bf`; OS
  `Linux 6.18.44-fc-v77` (cloud container, llvmpipe Vulkan for the render)
- **Date:** 2026-10-07
- **Who ran it:** agent

Owner lines (v0.3.0 PLAN): L15 "melee and ranged should be separate runs … you start from one build or the other"
+ "pick at start, have a two card screen with a cool animation of appearing that shows both"; L16 "melee should do
just a bit more damage, because shooter is OP"; L25 "an out of combat HP regen feature, when after 10s after no
combat you start to regen a bit of health that can later be increased"; L29 "Sword should be used towards where
the character is looking, shooting towards the aimed with the other joystick".

## What was built (all numbers are starting values, in data)
| Piece | Where | Value |
|---|---|---|
| Builds | `data/builds/blade.tres`, `data/builds/gun.tres` (`BuildDefinition`, validated) | Blade: melee only; Gun: shooting only |
| Damage factor (L16) | `BuildDefinition.damage_permille` | Blade 1150 (+15 %), Gun 850 (−15 %) |
| Remainder | `PlayerBuild.melee_damage` / `bolt_damage` | the per-mille remainder carries to the next hit of that weapon, so averages are exact (Gun bolt 4 → 3, 3, 4, 3, 4 …) |
| Other weapon's input | `PlayerKit.advance` / `PlayerKit.shooting` | does nothing (a Gun melee press is dropped, not buffered) |
| Melee direction (L29) | `PlayerBuild.melee_angle` | the last move direction; the aim only before the first move; shots stay on the aim |
| Item gating | `ItemDefinition.requires_weapon` → `ItemPool._usable` | 9 blade-only, 7 gun-only, 8 any (table below) |
| Regen (L25) | `PlayerRegen`, `data/player/runner.tres` | after 10 s (600 ticks) without dealing or taking damage: 10 ‰ of max HP a second (1 HP/s at 100 HP), integer accumulator |
| Regen hook | `World.regen_bonus_permille` (carried between floors by `RunCarry`) | extra ‰ of max HP a second; 0 by default |
| Run state | `RunState.build_id` | chosen on the start screen; the same on every floor; the world hashes weapons, factors, facing, remainders and regen |
| Start screen | `BuildPicker` + `BuildCard` | Play → build → utility → run; mouse, ←/→ + Enter, d-pad/stick + A; Esc/B back |
| HP bar pulse | `RegenPulse` (two lines in `hud.gd`) | green, 1 s breathing, peak alpha 0.45, only while regen heals |

### Items by weapon (tagged by what each item actually feeds)
| Blade only (9) | Gun only (7) | Any (8) |
|---|---|---|
| Long Edge, Twin Arc, Ember Edge, Overcharge, Momentum, Conductor, Serrated Edge, Glacial Edge, Bulwark (its charges are spent by the next swing; still also needs Guard) | Splinter Shot, Rapid Coil, Ricochet Core, Static Chain, Frost Core, Cinder Shot, Barbed Bolts | Kinetic Dash, Vampiric Core, Thorn Mantle, Executioner, Swift Feet, Phase Strike, Wildfire, Cold Snap |

Combos that follow (owning both items is the only unlock rule, so a combo whose pair can't both be offered never
unlocks): Blade runs can unlock Resonance, Slipstream, Frozen Bastion, Blood Harvest, Spiked Phase; Gun runs can
unlock Shrapnel Storm, Shatter Dash, Blood Harvest, Spiked Phase. **Plasma Arc** (Ember Edge + Static Chain) now
unlocks in neither build.

### Gun and close range (decision for the owner)
The Gun's melee input does nothing (L15 as written). Its close-range answers are the dash, the chosen utility (Guard
blocks, Blink escapes) and the "any" items (Kinetic Dash, Thorn Mantle, Phase Strike). No shove was added.
**Proposal, not built:** if the Gun feels helpless up close, give it a short-range shove on the melee input
(knockback, no damage). OWNER ONLY to decide.

## Command
```
bash scripts/verify.sh
```

## Raw output
```
[… trimmed …]
BOSSFIGHT| gun gatekeeper ticks=4211 seconds=70.2
BOSSFIGHT| gun brood_mother ticks=5448 seconds=90.8
BANDMISS| gun brood_mother: 90.8 s, outside 30-90 s. v0.3.0 P: the Gun build at 85 % damage (L16) measured 90.8 s; reported in evidence/BUILDS.md for the owner.
BOSSFIGHT| gun siege_engine ticks=3890 seconds=64.8
BOSSFIGHT| blade gatekeeper ticks=2787 seconds=46.5
BOSSFIGHT| blade brood_mother ticks=3129 seconds=52.1
BOSSFIGHT| blade siege_engine ticks=2755 seconds=45.9
[… trimmed …]
Totals
------
Scripts              90
Tests               515
Passing Tests       515
Asserts           403195
Time              1073.358s
[… trimmed …]
check_gut_log: ok (515 passing, minimum 482)
```

The shooter bot before the builds reached it (both weapons, full damage: `PlayerTable.starting_values()`), from this
session's first full-suite run (same command), when the bot test was not yet build-aware:
```
BOSSFIGHT| gatekeeper ticks=3379 seconds=56.3
BOSSFIGHT| brood_mother ticks=4307 seconds=71.8
BOSSFIGHT| siege_engine ticks=3310 seconds=55.2
```

```
bash scripts/ci/export_smoke.sh
[… trimmed …]
  ok    600-tick World run hash 9c324d3dbf34 matches the project's
  ok    manifest hash 46c51a734a27 matches the project's
[… trimmed …]
0 miss(es)
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Boss fight length, perfect-uptime bot | 30–90 s | `tests/unit/sim/test_boss_fights.gd` (PLAN v0.3.0 C) |

## Result
| Bot | Gatekeeper | Brood Mother | Siege Engine | In band? |
|---|---|---|---|---|
| Shooter, before (4 dmg) | 56.3 s | 71.8 s | 55.2 s | yes |
| **Gun** (shooter, 85 %) | 70.2 s | **90.8 s** | 64.8 s | **no: Brood Mother is 0.8 s over** |
| **Blade** (melee bot, 115 %) | 46.5 s | 52.1 s | 45.9 s | yes |

The Blade bot walks into melee range, keeps a light push toward the boss (melee goes the way it faces) and presses
melee whenever no swing runs, so it chains the four-slash combo with perfect uptime. It ignores the bosses'
attacks (its HP is raised); a real player dodges, so real fights are longer than both bots.

## Interpretation
- **Band miss, reported, not retuned:** the Gun at −15 % takes the Brood Mother 90.8 s, just over the 90 s band.
  The test keeps the band for every other boss and build; this one case only has to die, and prints `BANDMISS` on
  every run until the owner decides (keep −15 %, soften it, or change the band). BX is making bosses harder in
  parallel, so these numbers will move again.
- With perfect uptime the Blade now kills every boss faster than the Gun (46–52 s against 65–91 s). That is the
  direction L16 asked for; whether the gap is right depends on how much uptime melee really gets against the bosses'
  attacks — OWNER ONLY.
- Goldens unchanged: the replay golden and the export-smoke hash (`9c324d3dbf34`) match. The build and regen state
  joins the hash only once a world has a build, a loadout or regen activity, so the kernel worlds hash as before.

## Start screen
![start screen](start_screen.png)

Top: the settled screen (Blade focused). Middle row: the appear animation scrubbed at 0.20, 0.36, 0.52 and 0.80 s
(cards rise in staggered by 0.16 s, trailing cyan/magenta echo frames, then a landing glitch). Bottom: the Spanish
screen, and the 0.36 s frame enlarged. Rendered with
`xvfb-run … godot --path . --audio-driver Dummy --resolution 1600x900 -s <shot script>` (llvmpipe).

## Owner checks
| Question | Answer |
|---|---|
| Does the start screen look and feel right (animation, cards, icons)? | OWNER ONLY |
| Blade +15 % / Gun −15 %: is melee now worth it? | OWNER ONLY |
| Melee toward the facing (L29) on a pad and on mouse + keyboard | OWNER ONLY |
| Regen: 10 s wait and 1 %/s right? Is the green pulse visible but subtle? | OWNER ONLY |
| Gun close range: fine without a shove? | OWNER ONLY |

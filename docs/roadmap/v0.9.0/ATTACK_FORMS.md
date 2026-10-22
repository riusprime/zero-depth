# v0.9.0 Attack forms (G1)

The owner, 2026-10-22 ([`feedback/2026-10-22_combat_visual_overhaul.md`](feedback/2026-10-22_combat_visual_overhaul.md)
§6): "Keep the existing normal ranged attack as the default … we should have around 8-10 total attack replacements. so
there are multiple builds possible with the modifiers like twin or swirl". §7: "Each attack form should define its
supported patterns and supported effects … Do not silently introduce unapproved interactions."

**How to answer:** mark each row **Yes**, **No** or **Change: …**, and its compatibility cells if you disagree. Only
Yes rows get built. Every number is a starting value, tuned after you play. A cell marked "off" stays off until you
turn it on (C62).

**Today** (live code, 2026-10-22): the Gun fires one kind of shot, the blue pulse orb (`data/player/runner.tres:63-67`:
every 0.15 s, 5 damage, 16.2 m/s). Its cards change that shot. The sim already has the shapes most forms need: the
`Form` enum has BOLT, BEAM, LOB, BURST, ORBITER and others (`src/sim/combat/attack_spec.gd:11`). The BEAM form is only
used as chains and rays today, and LOB as nothing the player can pick. The forms below are **Gun forms**. Whether the
Blade gets forms is Q6 in the [PLAN](PLAN.md).

The columns are the patterns from Q3 (b), with Spiral and Swirl as motion cards that ride on a pattern. If you pick
Q3 (a), Spiral and Swirl become pattern columns.

| # | Form | What it does in play | Starting values | Twin | Spread | Halo | Ring | Backfire | Spiral / Swirl | Elements | Closest existing | Owner |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F1 | **Orbs** (default) | Today's blue pulse | as today | yes | yes | yes | yes | yes | yes | all | — | (yours: §6.1) |
| F2 | **Laser** | Hold to fire a beam that follows your aim | Q8 | yes (2 beams, 60 %) | yes (3 thin, 40 %) | off | off | off | off | all: per-element beam look | the BEAM chains | (yours: §6.2) |
| F3 | **Bomb** | A thrown bomb that bursts in an area | Q9 | yes (2 bombs, 65 %) | Q9 | off | off | off | off | all: on the blast | retired Bomb Lobber, Explosive | (yours: §6.3) |
| F4 | **Void** | A slow black hole that tugs enemies toward its path | Q10 | yes | off (test) | off | off | off | off (test) | all except Frost's freeze on bosses | the floor black hole it replaces | (yours: §6.4) |
| F5 | **Lance** | Hold to charge, release one piercing line shot; longer charge, more damage | up to 1.2 s, ×1 → ×5 damage, pierces all | yes | off | off | off | off | off | all: along the line | the Charge card (retired if Yes) | |
| F6 | **Scatter** | A short-range cone of pellets: brutal up close, weak at range | 6 pellets, 25°, 5 m range, every 0.55 s | yes | off (it is a spread) | off | off | yes | off | all: per pellet, at a lower chance | Spread | |
| F7 | **Glaive** | A spinning disc that flies out and returns, hitting on both ways | 7 m out, ×1.6 damage per pass, every 0.7 s | yes | yes | off | off | off | Spiral off, Swirl yes | all | the Boomerang card (retired if Yes) | |
| F8 | **Seekers** | Three small darts that curve to the nearest enemies | 3 × 45 % a shot, every 0.3 s, homing 360 °/s | off | off | off | off | off | off | all: lower status chance per dart | the Homing card | |
| F9 | **Wave** | A wide slow wave that rolls forward through everything | 3 m wide, 6 m/s, pierces, every 0.9 s | yes | yes (3 waves) | off | off | yes | off | all | the Blade's Wave (Echo Slash) | |
| F10 | **Wisps** | Orbs circle you and fire on their own at the nearest enemy while you aim and fire too | 3 wisps, each a 40 % orb every 0.6 s | off | off | off | off | off | off | all | Orbit, Blade Orbit | |

**Secondaries** (Pierce, Ricochet, Homing, Echo, Big Shot, Rapid Fire, Split, Mine, Charge, Orbit, Boomerang,
Threadline, and Explosive if Q11 (a)) get one compatibility row per form once the forms are chosen. Until then, every
secondary is **off** for F2–F10.

If you want another form, add a row at the bottom with its name and what it does in play.

## Decisions (owner, date)
| Row | Answer | Built in |
|---|---|---|
| — | | |

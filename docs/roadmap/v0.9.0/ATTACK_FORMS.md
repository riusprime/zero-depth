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

**Updated after the owner's answers (2026-10-22):** Twin and Spread are now **one** Pattern card for every form (Q8):
2 copies at Lv 1–4 (60 / 70 / 80 / 90 % each), 3 at Lv 5 (70 % each); two fly side by side, three fan about 15°. The
"Twin" column below is that merged card, on wherever the old Twin cell was yes. Explosive is deleted and Fire loses its
kill blast (Q11), so the elements are Fire, Lightning, Frost, Venom and Bleed.

| # | Form | What it does in play | Starting values | Twin (merged) | Halo | Ring | Backfire | Spiral / Swirl | Elements | Closest existing | Owner |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F1 | **Orbs** (default) | Today's blue pulse | as today | yes | yes | yes | yes | yes | all | — | (yours: §6.1) |
| F2 | **Laser** | Hold to fire a beam that follows your aim | Q8: 10 ticks/s at 18 % of an orb hit, 9 m, stops at the first enemy unless Pierce, 75 % move speed while firing | yes (2 or 3 beams) | off | off | off | off | all: per-element beam look | the BEAM chains | Yes (§6.2, Q8) |
| F3 | **Bomb** | A thrown bomb that bursts in an area | Q9: straight, bursts on contact or at 8 m, 1 a second, 2.2 m at 4.5 × an orb hit | yes (2 or 3 bombs) | off | off | off | off | all: on the blast | retired Bomb Lobber | Yes (§6.3, Q9) |
| F4 | **Void** | A slow black hole that tugs enemies toward its path | Q10: every 0.6 s, 0.6 × orb speed, 1.0 m aura, pull 3 m at most 1.0 m/s; no pull on bosses and elites | yes | off | off | off | off (test) | all except Frost's freeze on bosses | the floor black hole it replaces | Yes (§6.4, Q10) |
| F5 | **Lance** | Hold to charge, release one piercing line shot; longer charge, more damage | up to 1.2 s, ×1 → ×5 damage, pierces all | yes | off | off | off | off | all: along the line | the Charge card (retired) | Yes (Q7) |
| F6 | **Scatter** | A short-range cone of pellets: brutal up close, weak at range | 6 pellets, 25°, 5 m range, every 0.55 s | yes | off | off | yes | off | all: per pellet, at a lower chance | the old Spread | Yes (Q7) |
| F7 | **Glaive** | A spinning disc that flies out and returns, hitting on both ways | 7 m out, ×1.6 damage per pass, every 0.7 s | yes | off | off | off | Spiral off, Swirl yes | all | the Boomerang card (retired) | Yes (Q7) |
| F8 | **Seekers** | Three small darts that curve to the nearest enemies | 3 × 45 % a shot, every 0.3 s, homing 360 °/s | off | off | off | off | off | all: lower status chance per dart | the Homing card | Yes (Q7) |
| F9 | **Wave** | A wide slow wave that rolls forward through everything | 3 m wide, 6 m/s, pierces, every 0.9 s | yes | off | off | yes | off | all | the Blade's Wave (Echo Slash) | Yes (Q7) |
| F10 | **Wisps** | Orbs circle you and fire on their own at the nearest enemy while you aim and fire too | 3 wisps, each a 40 % orb every 0.6 s | off | off | off | off | off | all | Orbit, Blade Orbit | Yes (Q7) |

**Secondaries** (Pierce, Ricochet, Homing, Echo, Big Shot, Rapid Fire, Split, Mine, Orbit, Threadline, plus Spiral and
Swirl as motion cards) get one compatibility row per form in the AS step. Until a cell is approved, every secondary is
**off** for F2–F10.

## Decisions (owner, 2026-10-22)
| Row | Answer | Built in |
|---|---|---|
| F1–F4 | The owner's own forms; values from Q8–Q10 | |
| F5–F10 | "F5 Lance, F6 Scatter, F7 Glaive"; "F8 Seekers, F9 Wave, F10 Wisps" (all six, cells as proposed) | |
| Twin + Spread | Merged into one Pattern for every form (Q8) | |

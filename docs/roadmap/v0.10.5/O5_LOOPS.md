# v0.10.5 O5a + O5b: reasons to loop, and loops that remix rules

Owner (2026-11-01, L2): "For now loop difficulty is fine but we are actually missing something to make the player want
to go further"; P13: "go for it" (each loop remixes rules instead of only inflating numbers). Overnight mode: "Pick and
build". Every pick below is the lead's starting value, built, and listed for the owner to keep or change (G1 rows).

## The loop today (before O5)

Taking the Loop device on a loop's last floor (`Ascension`, `RunState.finish_floor`) starts loop + 1 at floor 1 with
the build carried. What changes per loop:

| What | Where | Per loop past the first |
|---|---|---|
| Normal enemies' HP / damage | `RunState.scale_enemies`, `loop_enemy_*_permille` | ×6 / ×1.2, compounding (cap ×100) |
| Bosses' HP / attack damage | `RunState.scale_bosses`, `loop_boss_*_permille` | ×6 / ×1.2, compounding |
| Threat T | `World.loop_threat` | +2 |
| Hidden catch-up caps | `World.loop_cap_permille` | +500 ‰ |
| Legendary chance at the boss altar | `LegendaryTable.card_loop_permille` | + the data's step |
| Biomes | `RunState._draw_loop_biomes` | a new shuffle |
| Deep floor past loop 1 | `loop_deep_ease_permille` | ×0.9 ease |

So every loop is the same floors with bigger numbers: the "repetition of mastered patterns" Koster calls tedious.
The only rewards were the Codex's "best loop" counter (not shown anywhere) and the `ascend_1` / `ascend_5` achievements.

## O5a. Reasons to loop

### 1. Loop-only rewards (PD-06: sideways only, nothing is a stat)

| # | Pick | Built as |
|---|---|---|
| R1 | **Two loop robes**, earned, not bought: **Ouroboros** (reach loop 3) and **Abyssal** (reach loop 5) | `data/wardrobe/robe_ouroboros.tres`, `robe_abyssal.tres` (colour robes with `unlock_hint_key`, like the Runic robe); `RunRecords.unlock_loop_robes` gives them when the loop is reached, with a toast. Cosmetic only |
| R2 | **A Codex entry per loop rule** (the Lore page): each rule's line unlocks the first time a loop draws it | `CodexStore.LORE_IDS` + `rule_*`; `CodexRecorder._lore` reads `WorldReader.loop_rules()` |
| R3 | **More fragments a loop** (part 3 below) | data |

Not picked: a loop-only card pool (needs new cards and art; the boss altar's legendary chance already grows per loop),
a robe aura (needs new view work; the tint robes reuse the avatar's cloak colours).

### 2. Records and depth

| # | Pick | Built as |
|---|---|---|
| D1 | **Deepest loop per weapon** (Gun, Blade) and overall | profile section `records` (`RunRecords`), written when the Loop device is taken |
| D2 | **Fastest true ending per weapon** (the final boss beaten; run time) | the same section, written when the run's recap banks |
| D3 | Shown in the **hub** at the Achievements station (a Records block above the groups) and in the **run recap** ("New record: deepest loop", "New record: fastest true ending") | `AchievementsPage`, `EndPanel` |
| D4 | **Loop achievements**: `loop_3` "Third Turn" (reach loop 3) and `loop_5` "Bottomless" (reach loop 5), on a new `runs:loop_best` stat (raised, not counted). Loop 2 already has `ascend_1` | `data/achievements/loop_3.tres`, `loop_5.tres` |

A record holds the run seed that set it, so the recap of the same run (even after Continue) can say "new record".
A tweaked run (the dev panel's balance edits) records nothing, as the Codex.

### 3. More fragments a loop

Every fragment source a floor earns (floor cleared, boss, secrets, Purple Portal, final boss, collectibles) ×
(1 + 0.5 × (loop − 1)), rounded down: `RuneFragmentsDefinition.loop_bonus_permille = 500` (starting value). Loop 1
earns as before. The recap shows the multiplier on loop 2+ ("Loop bonus: ×1.5 fragments").

## O5b. Each loop remixes a rule (P13)

From loop 2, each loop adds **one rule** drawn from a pool of five, without repeats, on the named stream
`loop_rule_<loop>` of the run seed (so a run always draws the same rules; a different seed, different rules). Loop 2 has
one rule, loop 3 two, … loop 6 all five. The rule is announced on the loop's first floor card ("New rule: …"), listed in
the pause menu and the recap, and has its Codex line. A run saved before O5 has no rules (its floors rebuild as saved);
its next loop draws one.

| # | Rule (id) | What changes | The pattern it breaks | Numbers (starting values, `RunDefinition`) |
|---|---|---|---|---|
| M1 | **Quickened** (`swift`) | Normal enemies move and charge faster | kiting at a known pace | speed and charge speed ×1.2 |
| M2 | **Lean Mending** (`lean_mending`) | Heal orbs drop half as often but heal twice as much | steady sipping; each orb becomes a decision | chance ×0.5, heal ×2 |
| M3 | **Elite Hunt** (`elite_hunt`) | Elite rooms appear on every floor, at the last floor's rate | early floors being safe warm-ups | the last floor's `room_permille` |
| M4 | **Shielded** (`shielded`) | Every normal enemy guards its front: hits from within 45° of its facing deal 60 % (shown ARMOURED) | face-tanking a pack; flanking and the dash matter | 60 %, 45° half-arc |
| M5 | **Point Blank** (`point_blank`) | Ranged enemies close in and shoot faster bolts | sniping casters from range | bolt and spread speed ×1.3, keep distance ×0.6 |

Not picked (heavier, or in the other agent's files): "packs arrive in waves from one side" (the spawner and the
intensity director), "one boss phase borrowed from another boss" (boss AI per boss), "enemies inherit an element" (no
enemy element on the hero today).

### The HP step goes down: ×6 → ×3.5 a loop (enemies and bosses)

Each rule now carries part of a loop's difficulty, so the numbers needn't: ×6 compounding is ×36 HP on loop 3 and ×1296
on loop 5, which only inflates the fight's length. ×3.5 is ×12.25 on loop 3 and ×150 on loop 5, with one to four rules
on top. Damage stays ×1.2. `loop_enemy_hp_permille` and `loop_boss_hp_permille` 6000 → 3500 in both run shapes.

## Dev panel

The dev panel has no loop values today (the loop numbers are content only), so no entry was added.

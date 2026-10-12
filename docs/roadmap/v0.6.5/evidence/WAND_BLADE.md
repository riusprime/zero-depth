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
Lint (on the final tree):
```
gdformat --check src scripts tests && gdlint src scripts tests
654 files would be left unchanged
Success: no problems found
```

The new tests (B1–B16 in a scripted fight, the order, levels and pool tests, the views, the e2e; on `d056ab7` plus the
file split, before the runner-numbers table; run again after it inside the folder runs below):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_wand_blade.gd,res://tests/unit/sim/test_wand_blade_order.gd,res://tests/unit/presentation/test_blade_form_view.gd,res://tests/e2e/test_e2e_wand_blade.gd -gexit
Tests                36
Passing Tests        36
Time              31.805s
```

Content, arch, the replay golden and the application tests (on `f4d37e4`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/application -ginclude_subdirs -gexit
Tests               139
Passing Tests       139
Time              30.433s
```
(The first run of that set failed the arch rule once: `blade_form_view.gd (presentation) uses BladeForms (sim)`; the
view now reads the mark kinds as `WorldReader.BLADE_FX_*`, then the 139 passed as above.)

Presentation (on `f4d37e4`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Tests               398
Passing Tests       398
Time              344.143s
```

The whole `tests/unit/sim` folder (on `b72303b`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/sim -ginclude_subdirs -gexit
    wand smoke: 1152 runs (72 cards × 8 slots × 2 weapons)
Tests               840
Passing Tests       831
Failing Tests         9
Time              2940.007s
```
The failures, pasted (`[Failed]` lines, deduplicated):
```
ARRAY(["blade_orbit", "bulwark", "chain_cut", "conductor", "counter", "double_slash", "ech...ide_arc"]) != ARRAY(["bulwark", "conductor", "echo_slash", "echo_storm", "ember_edge", "glacial_edge", "...win_arc"]).
Expected [ARRAY([25, 29])] to contain value:  [62]:
Expected [ARRAY([25, 29])] to contain value:  [69]:
[-1] expected to equal [2]:
[2] expected to equal [-1]:
[34] expected to equal [33]:  the 31 v0.5 kinds, MODIFIER and (v0.6.5 WN1) TRIGGER
[385] expected to be < than [256]:  well under the per-tick watchdog (T-FUZZ's stricter bound)
[3] expected to equal [2]:  only two items left
[56] expected to equal [43]:  48 - owned - 4 placed
[60] expected to equal [47]:
[60] expected to equal [47]:  everything but the owned one (v0.6.0 MX4: the M-list's 24 usable here too)
[61] expected to equal [48]:  no repeats
[61] expected to equal [48]:  the v0.3.0 pool of 24 + the M-list's 24 usable here (v0.6.0 MX4: no heat, no ability, no legendary)
[67] expected to equal [55]:  the 14 migrated attack items (MX1), ...; v0.6.5 WN1: 4 triggers
[77] expected to equal [78]:
[79] expected to equal [67]:  16 + 8 engine items (G) + ... + the wand's 4 trigger cards (v0.6.5 WN1)
the taken one did not
```
Eight of the nine are the shipped data's counts and lists (12 new cards, Blade Orbit no longer gated by its ability, a
new item kind, the Blade-only list) and the rewards tests that assumed a held card is never offered again (WAND.md rule
6: a card below level 5 still is; those tests now hold every card at its top level). Fixed in this step's commit
(`test_items`, `test_items_j`, `test_modifier_smoke`, `test_player_builds`, `test_rewards`) and the six files run again:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_items.gd,res://tests/unit/sim/test_items_j.gd,res://tests/unit/sim/test_modifier_smoke.gd,res://tests/unit/sim/test_player_builds.gd,res://tests/unit/sim/test_rewards.gd,res://tests/unit/sim/test_card_pool_reach.gd -gexit
Tests                87
Passing Tests        87
Time              241.946s
```
The `tests/unit/sim` folder was not run again as a whole after these fixes.

**Still failing, not fixed (reported, not widened):** `test_combos.gd`
`test_all_24_items_for_5000_ticks_raise_no_limit_and_repeat_exactly`:
```
SOAK| kills=211 events=5861 most_in_a_tick=385 limits=0 (watchdog 0, heal cap 0)
[385] expected to be < than [256]:  well under the per-tick watchdog (T-FUZZ's stricter bound)
```
The soak holds every item at once (79 now) with every combo. No watchdog LIMIT fires; the most events in one tick is
385 against the test's bound of 256. Diagnosed with a scratch copy of the soak (not committed): the peak tick's events
are the Gun and trigger cards' (by effect id: `tempest_core` 70 HIT / 34 DAMAGE, `gravity_well` 32 / 12, `storm_core`
28 / 13, `trigger_on_end` 26 / 11, …; no Blade card's effect id among them). Without the 12 new cards the peak is
still 385; without Wide Arc it is 135, without Long Shadow 118, without the 16 Blade cards 100: the two reused cards
changed (Wide Arc no longer scales the Gun's shots, Long Shadow left the Gun), which moves the chaotic soak onto a
different peak. The bound was not changed; whether to keep it for an every-card soak is the lead's call.

The e2e tests that reach what changed (main.tscn, real input; on `f4d37e4` + the tests' edits of `b72303b`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_wand_blade.gd,res://tests/e2e/test_e2e_modifiers_mx4.gd,res://tests/e2e/test_e2e_swap.gd,res://tests/e2e/test_e2e_combo.gd,res://tests/e2e/test_e2e_four_slash.gd,res://tests/e2e/test_e2e_builds.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_card_pool.gd,res://tests/e2e/test_e2e_kit.gd,res://tests/e2e/test_e2e_attacks.gd,res://tests/e2e/test_e2e_hud_style.gd,res://tests/e2e/test_e2e_rewards.gd,res://tests/e2e/test_e2e_shop.gd -gexit
Tests                30
Passing Tests        30
Time              198.761s
exit 0
```

## What the tests assert
- `test_wand_blade.gd` (16): per card, the rewrite (the spec's fields, hooks, motion, the swing's ticks) and its effect
  in the AttackScenario fight: more hits than a plain Blade (Wide Arc, Whirl, Flurry), its own effect id landing (Wave,
  Split Wave, Double Slash's repeat, Fissure, Chain Cut, Afterimage, Finisher+, Orbit Blades, Counter), enemies pushed
  (Heavy), shots cut (Parry Edge), the view's marks recorded (the mirror echo, the eruption, the sparks, the ghost
  slash, the counter's flash), 1 m more forward per slash (Lunge Step), Finisher+'s shockwave burning when Ember Edge
  sits right of it (carry).
- `test_wand_blade_order.gd` (9): Wave·Split Wave splits and Split Wave·Wave doesn't (spec and fight, different
  hashes); Heavy·Whirl and Whirl·Heavy commute (the same crushing spin, the same hits); Whirl·Wave throws a ring of 4
  crescents, Wave·Whirl one; Wide Arc·Thrust is narrower than Thrust·Wide Arc; a duplicate levels a card up in its slot
  (no new slot, +15° at level 2, offered until level 5, then not); levels grow Wave's damage, Split Wave's count and
  Chain Cut's jumps; a level rides the carry and a snapshot round trip with equal hashes; the 16 cards are offered in
  Blade runs only; the new cards' indices come after every earlier card.
- `test_blade_form_view.gd` (10): BladeFormView draws nothing for a plain Blade, crescents (Wave, Split Wave, a ring for
  Whirl·Wave, Counter), ghost slashes (Afterimage, Double Slash), the crack then the eruption, sparks, orbiting blades,
  the counter's and Finisher+'s rings; KitView's blade spins (Whirl) and stabs (Thrust) and thickens (Heavy); the hero
  leans into Lunge Step; AttackFormLooks gives the `spin`, `cut`, `stab` and `crescent` cues.
- `test_e2e_wand_blade.gd` (1): through main.tscn and real input, a Blade run takes Whirl then Wave (the dev panel's
  clicks, labelled TEST HELPER), the wand reads them back in that order, and swinging with the mouse spins the laser
  blade all round and throws at least 4 crescents at once, drawn as crescents.
- `test_wand_smoke.gd` (unchanged code): every slot card, the 12 new ones included, in each of 8 slots on both weapons:
  1152 runs, the launches capped, bounded projectiles and queue, replays equal.

## Goldens
None changed. The modifier equivalence fixture and the replay golden pass unchanged (in the sim folder run and the
golden run above). The export smoke was NOT RUN.

## Known limits (honest list)
- **The every-card soak's event peak** (above): 385 per tick against its bound of 256; reported, not changed.
- **The card-pool bound** (`CardPoolSurvey.POOL_MAX`) went from 80 to 92 for the Blade pool's 12 new cards (owner G1
  "Approve all"), in the open: the old cards stay until WN5 migrates or retires them, which is when the pool shrinks.
  WN3's Gun cards will need the same.
- **Levels have no UI yet.** A held card below level 5 is offered again and levels up in its slot; the offer card and
  the wand pips don't say "level 2" yet (WN2's Build page). The dev panel's GrantMod skips held cards, so the e2e
  doesn't level a card; levels are tested in the sim.
- **The levels system is general** (`CardLevels`, `ModifierOpDefinition.per_level`, `ItemDefinition.max_level`,
  `ItemDefinition.Kind.WAND`): WN3 needs the same for the Gun pool; the lead merges one copy.
- **Names collide until WN5:** "Afterimage" names B12 and the old blink card; "Orbit Blades" names B15 and the old
  ability. Wide Arc, Long Shadow and Blade Orbit lost their Gun / ability uses.
- **Twin Arc stays** next to Double Slash (the equivalence golden pins Twin Arc's numbers); WN5 maps it.
- **Parry Edge** cuts at the hit tick and each later tick of the swing, not before the hit; a shot faster than the
  swing's arc may pass between ticks.
- **Counter** opens on a dash's end, once per dash; a slash during the dash is impossible already.
- The Blade's trigger child slash (WN1) is reached by the Blade cards to its right, but it never repeats or counters
  (depth > 0) and carries no Finisher+ (it is not the 4th step).
- `tests/MIN_TEST_COUNT` not raised (the lead's, after the full run). The full suite, the export smoke and the
  screenshot tour: NOT RUN.

## Owner only
Feel, the starting values, the names (Afterimage now names two cards until WN5 retires the blink one; Orbit Blades
names the card and the old ability): `OWNER ONLY`.

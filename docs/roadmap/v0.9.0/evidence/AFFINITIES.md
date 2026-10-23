# v0.9.0 Step RB: affinities and robes (evidence)

Owner lines (PLAN "Owner decisions" row `RB`, 2026-10-23, the G1 in [`../AFFINITIES.md`](../AFFINITIES.md)): A1 Ember, A2
Storm, A3 Venom, A4 Astral, A5 Guardian "Approve (Recommended)" each; access "Free, swap between runs (Recommended)";
display "The rune could be under the feet matching the color of the element being used" and "Rune on the robe's back";
robes "Approve (Recommended)". Built as recorded there: free from the start, changed at the Wardrobe between runs,
locked when a run starts; a rune on the robe's back and a rune circle under the feet in the affinity's colour, none for
None; no run-summary line; robes R1-R6 (Cream and Ash free; Night, Canyon, Frost, Moss for Rune Fragments, locked until
MP); K1-K3 run as proposed, numbers reported, nothing retuned.

Build: branch `v090-rb`, cut from the local `claude/world-combat-v090` at `6ea476e1`. Code commits `5f84abcf` (the step)
and `5a55f3f3` (the circle's blend on light ground; the K1 bot's columns and one bot stream per seed). Machine: the
owner's PC (Windows 11, i7-10700K, RTX 3060), Godot 4.7.2 (`Godot_v4.7.2-stable_win64_console.exe`), Git Bash, one Godot
job at a time, its own `APPDATA`.

## What was built

| Row | Built |
|---|---|
| Data | `data/wardrobe/`: `affinity_{none,ember,storm,venom,astral,guardian}.tres` (`AffinityDefinition`, category `affinity`) and `robe_{cream,ash,night,canyon,frost,moss}.tres` (`RobeDefinition`, category `robe`). Every number is a field (starting values). The folder is in the dev panel's Player group (`src/debug/dev_fields.gd`) |
| A0 None | No state: `RunContentCompiler.compile_affinity` returns null, `World.affinity` stays null, nothing is hashed or snapshotted, no save key. A None run hashes as before RB (tested) |
| A1 Ember | The hero's burns last `burn_duration_permille` 1500 of their duration (both burn writes: `Engines.add_burn`, `ItemEffects.on_melee_hit`). Fire cards (ember_core, cinder_shot, ember_edge, ember_trail, inferno_core, wildfire, chain_blast, shared_explosive) x1.3; frost cards (frost_core, cold_snap, glacial_edge, shatter) x0.7 |
| A2 Storm | After Kinetic Dash in tick phase 6 (`Affinities.dash_shock`): each enemy within 1.0 m of the dash's swept path gains 1 shock stack, once a dash, through `Engines.add_shock`, so it needs a shock card on the wand (without one, nothing). Dash cooldown +0.3 s (84 -> 102 ticks: 1.4 -> 1.7 s), applied to the run's compiled PlayerTable (FloorPlan; the dev panel's live apply too). Lightning cards (storm_core, aftershock, conductor, overcharge, shock_circles, static_chain, tempest_core) x1.3; venom_core x0.7 |
| A3 Venom | When a poisoned enemy dies (`Venom.on_kill`), its stacks jump to the nearest living enemy within 3.0 m (lower index on a tie; its own ProcLedger code 71). venom_core x1.3; the fire cards x0.7 |
| A4 Astral | No sim effect. `AstralSenseView`: every secret not yet found (the timed door's, the rune puzzle's and the cracked wall's doorway, which is the hidden room's way in) and its rune marking pulse faintly in the void violet while the hero is within 8 m (full within 4 m, at most 0.55 strength). The minimap (corner and full) draws a violet star in a room holding an unfound secret once that room is entered, with a legend row `Secret (Astral)`. Void cards (gun_void, gravity_well, shared_gravity_stitch) x1.3 |
| A5 Guardian | One ward (`ward_charges`) blocks the next hit from an enemy that would damage the hero (`Damage.hit`, after guard and armour; the hit is marked BLOCKED; a `guardian_ward` STATUS_APPLY event). Each floor's World is built with it full again; Continue restores it as saved. Run shards picked up x0.8, rounded half up: kill shards (`Rewards.on_kill`) and containers (`Breakables`); the Overrun's bonus follows the kills it is counted from. No offer bias |
| Offers | `ItemPool.card_weight` multiplies by the affinity's per-mille factor for the card (`AffinityTable.card_permille`, one per item index); no factor without an affinity, so the integers of a None run are unchanged |
| Run lock | `FloorPlan.of_profile` / `new_run(..., affinity)`: `RunState.affinity` is set when the run starts; every floor (and the final arena) builds the state from it. The run save writes `run.affinity` only when it is not None; an old payload (no key) loads as None (`RunSaver.run_from`) |
| Profile | `profile.loadout.robe` and `profile.loadout.affinity` (`Wardrobe`); no profile version change: an old profile has neither and reads as Cream and None (tested). A robe that isn't `free` is worn only when its id is in `profile.unlocks.robes`; **MP's hook is `Wardrobe.unlock_robe(profile, id)`** |
| Wardrobe panel | `WardrobePanel` (hub, `HubSession.open_wardrobe`): Robe and Rune affinity cyclers (left/right, or press; keyboard, mouse, pad through focus), the affinity's gain and trade-off lines, Back (Esc / pad B). A locked robe shows "locked" and a note, and isn't worn. Each pick is worn by the hub's hero at once; the profile is written when the panel closes. en and es strings |
| Robe | `PlayerAvatar.set_look`: the cloak's outside and the hood take the robe's colour, the underside its shade; the blue core (visor) never changes. The hub's hero wears it; `HubView.set_robe` recolours the Wardrobe's stand-in robe. With the owner's `hub_wardrobe` model installed the robe is fused into his mesh, so nothing there recolours until the art list's `hub_wardrobe_robe` arrives (as HB recorded) |
| Runes | `AffinityRunes`, layered: a soft ground glow, the circle (two rings with a white-hot core line over a coloured glow, a band of 24 rune strokes, the affinity's glyph in the middle, a shimmer running round), a small light and rising motes; it turns slowly and breathes. On the robe's back: the glyph in a thin ring over a glow, placed on the cloak's back facet every frame. Glyphs: Ember a flame, Storm a bolt, Venom a drop, Astral a four-point star, Guardian a shield. Effects density Low keeps the circle, glow and back glyph and drops the light and motes; Medium halves the motes; reduced motion stills the turn and pulses. Guardian: a spent ward dims the circle to 0.38; the break flashes a gold ring out from the feet |

Not built (not asked): no run-summary line (the owner did not pick it); robes R7-R8 (not approved).

## Tests

Lint (the step's 40 `.gd` files, from `6ea476e1`):

```
$ files=$( { git diff --name-only 6ea476e1 -- '*.gd'; git ls-files --others --exclude-standard -- '*.gd'; } | sort -u ); gdformat --check $files; gdlint $files
40 files would be left unchanged
Success: no problems found
```

New tests: `tests/unit/sim/test_affinities.gd` (each affinity's effect, None's hash), `tests/unit/application/test_wardrobe.gd`
(old profile, locked robes and MP's hook, the run lock, Storm's 102-tick dash, the ward on the next floor, the save and an
old save, Continue rebuilding the saved ward exactly), `tests/content/test_wardrobe_content.gd` (the approved numbers,
colours, cards exist, no robe near the enemy red or hostile yellow), `tests/unit/presentation/test_affinity_runes.gd`
(robe colours, core unchanged, runes per affinity in colour, Low and Medium, the ward's dim and flash, the hub's hero,
the panel and its locked robe, Spanish, Astral's pulse distances and the minimap draw), `tests/e2e/test_e2e_wardrobe.gd`
(main.tscn, real input only: Play, walk to the Wardrobe, E, Right = Ash, Down, Right x5 = Guardian, Esc; the profile
keeps both; the Portal Machine's run has Guardian locked, its ward up, the hero in Ash with the gold circle and back rune;
pause, Main menu, Play: the hub's hero still in Ash with the Guardian rune and the Wardrobe shows both).
`tests/e2e/test_e2e_hub.gd` changed: the Wardrobe opens its own panel now (Esc closes it); the Progression stand-in as
before.

The regression set, on the step commit's tree (`5f84abcf` content):

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gdir=res://tests/arch,res://tests/golden,res://tests/content,res://tests/unit/debug -ginclude_subdirs -gtest=res://tests/unit/application/test_old_saves.gd,res://tests/unit/sim/test_world_snapshot.gd,res://tests/unit/sim/test_state_hasher.gd,res://tests/unit/presentation/test_hub_view.gd,res://tests/unit/application/test_hub.gd,res://tests/unit/application/test_run_saves.gd,res://tests/unit/presentation/test_minimap.gd
Tests               235
Passing Tests       235
Asserts           34436
Time              241.673s
```

(This ran test_layering, test_sim_purity, every `tests/content` file including test_locale_coverage and the new
test_wardrobe_content, tests/golden's replay, every `tests/unit/debug` file including the master panel's folder check, and
the listed files.)

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=res://tests/e2e/test_e2e_hub.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_old_save.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_wardrobe.gd,res://tests/unit/sim/test_affinities.gd,res://tests/unit/application/test_wardrobe.gd,res://tests/unit/presentation/test_affinity_runes.gd
Tests                43
Passing Tests        43
Asserts             384
Time              144.646s
```

After `5a55f3f3` (the circle's blend; scripts):

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=res://tests/unit/presentation/test_affinity_runes.gd,res://tests/e2e/test_e2e_wardrobe.gd,res://tests/unit/application/test_balance_tools.gd
Tests                16
Passing Tests        16
Asserts             138
Time              50.704s
```

Goldens changed on purpose: none. None leaves every hash, replay and save as it was (the golden replay, test_old_saves,
test_world_snapshot, test_state_hasher green; `test_none_keeps_the_hash_of_a_run_without_rb`).

## K1-K2 (report; nothing retuned)

`scripts/balance/affinity_bot.gd`: each of the 10 Gun forms x 6 affinities, seeds 1101-5505, five floors a run built as
Main builds them (FloorPlan: the affinity locked, its state on every floor, the carry), FightBot (SaveLab.frame) on a Gun
run; floor 1 starts with the form's card; each floor's start the bot takes 2 cards, each the first of a 3-card altar draw
(`ItemPool.draw_weighted`, so the offer bias applies); 2400 ticks on the floor's spawning, then the boss room for at
most 3600. Same bot stream for every affinity of a seed.

```
$ godot --headless --path . -s scripts/balance/affinity_bot.gd -- seeds=5
K1: 10 forms x 6 affinities x 5 seeds [1101, 2202, 3303, 4404, 5505], 5 floors, floor 2400 ticks + boss 3600 ticks, 2 picks a floor
form | affinity | floor reached (mean) | clear rate % | floors cleared / possible | deaths (in a boss room) | seconds survived (mean) | kills (mean)
orbs | none | 1.00 | 0.0 | 0 / 25 | 5 (5) | 72.5 | 13.4
orbs | ember | 1.00 | 0.0 | 0 / 25 | 5 (5) | 73.6 | 13.4
orbs | storm | 1.00 | 0.0 | 0 / 25 | 5 (5) | 77.8 | 12.4
orbs | venom | 1.00 | 0.0 | 0 / 25 | 5 (5) | 68.6 | 11.8
orbs | astral | 1.00 | 0.0 | 0 / 25 | 4 (4) | 70.3 | 10.6
orbs | guardian | 1.00 | 0.0 | 0 / 25 | 5 (5) | 78.6 | 12.6
laser | none | 1.00 | 0.0 | 0 / 25 | 5 (5) | 65.4 | 10.8
laser | ember | 1.00 | 0.0 | 0 / 25 | 5 (5) | 65.4 | 10.8
laser | storm | 1.00 | 0.0 | 0 / 25 | 5 (5) | 60.6 | 11.0
laser | venom | 1.00 | 0.0 | 0 / 25 | 5 (5) | 61.1 | 11.4
laser | astral | 1.00 | 0.0 | 0 / 25 | 4 (4) | 82.0 | 12.0
laser | guardian | 1.00 | 0.0 | 0 / 25 | 4 (4) | 68.2 | 11.2
bomb | none | 1.00 | 0.0 | 0 / 25 | 4 (4) | 74.6 | 11.6
bomb | ember | 1.00 | 0.0 | 0 / 25 | 4 (4) | 74.6 | 11.6
bomb | storm | 1.00 | 0.0 | 0 / 25 | 3 (3) | 76.4 | 10.6
bomb | venom | 1.00 | 0.0 | 0 / 25 | 4 (4) | 79.2 | 10.0
bomb | astral | 1.00 | 0.0 | 0 / 25 | 5 (5) | 67.0 | 11.0
bomb | guardian | 1.00 | 0.0 | 0 / 25 | 5 (5) | 68.3 | 10.8
void | none | 1.00 | 0.0 | 0 / 25 | 4 (4) | 74.6 | 11.6
void | ember | 1.00 | 0.0 | 0 / 25 | 4 (4) | 74.6 | 11.6
void | storm | 1.00 | 0.0 | 0 / 25 | 3 (3) | 80.2 | 11.2
void | venom | 1.00 | 0.0 | 0 / 25 | 4 (4) | 69.8 | 10.6
void | astral | 1.00 | 0.0 | 0 / 25 | 5 (5) | 72.6 | 11.2
void | guardian | 1.00 | 0.0 | 0 / 25 | 5 (5) | 76.0 | 11.2
lance | none | 1.00 | 0.0 | 0 / 25 | 4 (4) | 76.3 | 11.4
lance | ember | 1.00 | 0.0 | 0 / 25 | 4 (4) | 76.3 | 11.4
lance | storm | 1.00 | 0.0 | 0 / 25 | 4 (4) | 73.2 | 10.6
lance | venom | 1.00 | 0.0 | 0 / 25 | 4 (4) | 71.7 | 11.0
lance | astral | 1.00 | 0.0 | 0 / 25 | 5 (5) | 72.9 | 12.0
lance | guardian | 1.00 | 0.0 | 0 / 25 | 5 (5) | 76.0 | 11.4
scatter | none | 1.00 | 0.0 | 0 / 25 | 5 (5) | 66.6 | 10.6
scatter | ember | 1.00 | 0.0 | 0 / 25 | 5 (5) | 66.6 | 10.6
scatter | storm | 1.00 | 0.0 | 0 / 25 | 5 (5) | 68.4 | 9.6
scatter | venom | 1.00 | 0.0 | 0 / 25 | 4 (4) | 65.6 | 10.4
scatter | astral | 1.00 | 0.0 | 0 / 25 | 4 (4) | 76.7 | 10.8
scatter | guardian | 1.00 | 0.0 | 0 / 25 | 5 (5) | 68.2 | 10.2
glaive | none | 1.00 | 0.0 | 0 / 25 | 4 (4) | 73.5 | 10.2
glaive | ember | 1.00 | 0.0 | 0 / 25 | 4 (4) | 73.5 | 10.2
glaive | storm | 1.00 | 0.0 | 0 / 25 | 5 (5) | 80.1 | 11.0
glaive | venom | 1.00 | 0.0 | 0 / 25 | 4 (4) | 73.3 | 12.2
glaive | astral | 1.00 | 0.0 | 0 / 25 | 5 (5) | 80.7 | 11.4
glaive | guardian | 1.00 | 0.0 | 0 / 25 | 3 (3) | 73.7 | 10.4
seekers | none | 1.00 | 0.0 | 0 / 25 | 5 (5) | 72.7 | 12.2
seekers | ember | 1.00 | 0.0 | 0 / 25 | 5 (5) | 70.6 | 12.2
seekers | storm | 1.00 | 0.0 | 0 / 25 | 4 (4) | 80.9 | 11.6
seekers | venom | 1.00 | 0.0 | 0 / 25 | 5 (5) | 73.8 | 11.0
seekers | astral | 1.00 | 0.0 | 0 / 25 | 4 (4) | 76.8 | 10.8
seekers | guardian | 1.00 | 0.0 | 0 / 25 | 4 (4) | 75.6 | 11.2
wave | none | 1.00 | 0.0 | 0 / 25 | 5 (5) | 70.9 | 11.4
wave | ember | 1.00 | 0.0 | 0 / 25 | 5 (5) | 70.9 | 11.4
wave | storm | 1.00 | 0.0 | 0 / 25 | 5 (5) | 69.9 | 10.0
wave | venom | 1.00 | 0.0 | 0 / 25 | 5 (5) | 61.0 | 10.8
wave | astral | 1.00 | 0.0 | 0 / 25 | 4 (4) | 77.7 | 11.8
wave | guardian | 1.00 | 0.0 | 0 / 25 | 5 (5) | 73.3 | 11.0
wisps | none | 1.00 | 0.0 | 0 / 25 | 5 (5) | 70.7 | 13.2
wisps | ember | 1.00 | 0.0 | 0 / 25 | 5 (5) | 70.2 | 13.0
wisps | storm | 1.00 | 0.0 | 0 / 25 | 4 (4) | 74.9 | 13.6
wisps | venom | 1.20 | 4.0 | 1 / 25 | 5 (5) | 82.5 | 24.2
wisps | astral | 1.00 | 0.0 | 0 / 25 | 4 (4) | 79.0 | 13.8
wisps | guardian | 1.00 | 0.0 | 0 / 25 | 4 (4) | 74.0 | 13.0
K2 best affinity per form:
  orbs: none, ember, storm, venom, astral, guardian (0.0 %) tie
  laser: none, ember, storm, venom, astral, guardian (0.0 %) tie
  bomb: none, ember, storm, venom, astral, guardian (0.0 %) tie
  void: none, ember, storm, venom, astral, guardian (0.0 %) tie
  lance: none, ember, storm, venom, astral, guardian (0.0 %) tie
  scatter: none, ember, storm, venom, astral, guardian (0.0 %) tie
  glaive: none, ember, storm, venom, astral, guardian (0.0 %) tie
  seekers: none, ember, storm, venom, astral, guardian (0.0 %) tie
  wave: none, ember, storm, venom, astral, guardian (0.0 %) tie
  wisps: venom (4.0 %)
K2 affinity | forms where it is the unique best | mean clear rate % | vs None (points)
  none | 0 | 0.0 | +0.0
  ember | 0 | 0.0 | +0.0
  storm | 0 | 0.0 | +0.0
  venom | 1 | 0.4 | +0.4
  astral | 0 | 0.0 | +0.0
  guardian | 0 | 0.0 | +0.0
K2: best for more than 4 of 10 forms: none over 4 (pass); every mean within 5 points of None: pass
time 1371 s
```

**What this does and doesn't show.** K2's two checks pass, but **only because the bot almost never clears a floor**: in
299 of 300 runs it dies to (or is outlasted by) floor 1's boss, so the clear rates are 0 % nearly everywhere and the
check can't tell the affinities apart. K1 as proposed (floor reached, clear rate) is therefore not a useful measurement
with FightBot; it is reported as it came out, not widened or retuned. The survival and kill columns do differ (for
example Astral and Storm survive a few seconds longer than None in most forms, and Ember equals None wherever the bot
drew no fire card), but with 5 seeds and a bot that picks cards blind those gaps are noise-sized; no conclusion is drawn
from them. A meaningful K1 needs a bot that clears floors (or the owner's playtest). Owner decision: **OWNER ONLY**.
K3 (Astral judged in play): **OWNER ONLY**.

## Shots

`scripts/shots/rb_shots.gd` (a tool: it places the hero and opens the panel directly; the hero shots zoom the camera 3x
on the hero and hold it facing away so the back rune shows):

```
$ godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/rb_shots.gd
rb_shots: res://build/shots/v0.9.0/rb/en_1_wardrobe_panel.png
rb_shots: res://build/shots/v0.9.0/rb/en_2_hero_ember_cream.png
rb_shots: res://build/shots/v0.9.0/rb/en_2_hero_storm_ash.png
rb_shots: res://build/shots/v0.9.0/rb/en_2_hero_venom_cream.png
rb_shots: res://build/shots/v0.9.0/rb/en_2_hero_astral_ash.png
rb_shots: res://build/shots/v0.9.0/rb/en_2_hero_guardian_cream.png
rb_shots: res://build/shots/v0.9.0/rb/en_2_hero_ember_cream_low.png
rb_shots: res://build/shots/v0.9.0/rb/es_1_wardrobe_panel.png
```

Copied to [`rb_shots/`](rb_shots/): the Wardrobe panel (Ash and Ember picked) in English and Spanish; the hero in the hub
with each affinity (Ember, Venom, Guardian in Cream; Storm, Astral in Ash) and Ember at Effects density Low. Seen by the
agent: the circle and the back glyph show in the affinity's colour; Guardian's gold reads weakest on the Ruins sand, and
the back rune is small at the default zoom. Whether they read well enough: **OWNER ONLY**.

## Owner-facing notes

- The Wardrobe's own robe (the owner's `hub_wardrobe` model) doesn't change colour until `hub_wardrobe_robe` is
  delivered; the hero in the hub wears the choice meanwhile.
- MP: call `Wardrobe.unlock_robe(profile, id)` when Night, Canyon, Frost or Moss is bought.

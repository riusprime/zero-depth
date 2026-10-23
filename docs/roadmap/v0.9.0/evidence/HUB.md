# v0.9.0 HB: the hub (option A, the Rune Ring)

Owner decisions: Q27 (the small menu, "the rest of the thing go into the hub"), "3. option A" (HUB_MOCKUPS option A,
the Rune Ring), RB (the Wardrobe is where robes and affinities are changed, later), VX (layered glows, never flat).
Built by an agent on branch `v090-hb` (owner's PC: i7-10700K, RTX 3060, Godot 4.7.2, Windows 11).

## What the player sees

- **The main menu** is Continue, Play, Options, Quit. Continue resumes the saved run straight away and is greyed out
  (and skipped by the focus) without a save; Play goes to the hub. The Codex, Credits and achievements left the menu;
  the debug-only Galleries row moved to the F10 master dev panel.
- **The hub, the Rune Ring:** one round plaza (25 m) in one iso view. The hero spawns on the south side and walks with
  the normal controls (move, dash; no attack). Standing at a station shows its name and prompt (`[E / X] …`); the
  interact opens its panel, and Back / Esc returns to the hub where the hero stood:
  - **Portal Machine** (centre): the build screen (Blade / Gun) and the seed flow as before; a pick starts the run;
  - **Rune Archive** (NW): the Codex, its first page;
  - **Trophy Area** (NE): the Codex on its Achievements page; one pedestal per floor boss (its plaque gold once that boss
    fell), a brazier lit once any boss fell, a golden crown once the final boss fell;
  - **Wardrobe** (W) and **Progression Station** (E): stand-in panels (one line on what will be there, Back);
  - **Credits stone** (SW): the credits.
  - 16 dark floor runes ring the machine; the north gate is sealed (a violet sigil on a slab in the kit's stone arch),
    the alcove past it walled in.
  - Esc / Start in the hub: Resume, Options, Main menu.
- **After a run:** the summary, then **Restart** (focused; one press, a new seed, straight into a run) or
  **To the Rune Ring** (the hub, at its spawn).
- en and es for every new string (17 keys in `locale/strings.csv`).

## How it is built (and why)

The hub runs on the **same deterministic World rules** as a run: `HubScenario` builds a World with the hub's walls
only (`HubLayout`: the rim, the gate, the alcove, the machine's base and each station's footprint as Obbs), stepped by
a `HubDriver` (a SimDriver that passes only the dash: no attack, skill, vent, utility or interact reach the sim) at
60 Hz. Why: the hero's walk, dash, collision and feel are the run's from the one movement code, the World is pure
(EI-02) and holds nothing of a run, and the stations are presentation reading the hero's position (EI-07). The hub
never touches the run's save (RunSaver never sees this World; e2e `test_the_hub_never_touches_the_run_save`) and reads
the profile only (`HubFlags`; a missing section is never created).

- Data: `data/hub/rune_ring.tres` (`HubDefinition`, `HubStationDefinition`, `HubStateDefinition`; validated).
- The plan's north is the screen's top (`HubLayout.to_sim`: the plan turned 45° onto the sim plane, IsoRig's yaw).
- View: `HubView` (the plaza, the rim of kit wall pieces and columns, braziers, the gate, the runes, the stations,
  the hero's `PlayerAvatar`, an IsoRig that leans a quarter of the way from the machine toward the hero, the ink pass,
  the Ruins mood's light plus a soft fill from the camera's side), `HubMachine`, `HubStations`, `HubProps`.
- The owner's hub models (delivered 2026-10-22) draw the machine and the stations: `hub_portal_machine` (drawn 4.6 m
  tall, a starting value; the art list says 6.0 m), `hub_archive`, `hub_wardrobe`, `hub_station`,
  `hub_trophy_pedestal`, `hub_collectible_pedestal` (three before the Archive). Each has a code stand-in when the model
  isn't installed. The code fills the machine's empty ring with the portal.
- **Glows (VX bar):** every station's glow is a stack: an emissive core, a camera-facing halo with a white-hot centre,
  a glow pooled on the floor, a real light, and motes where it lives (the machine, the braziers); the machine's portal
  is a layered swirling-noise shader with a hot rim; the focused station brightens.
- Session: `HubSession` (which station the hero stands at, the prompt, the interact, the hub's pause and the stand-in
  panels); `Main` opens the panels it owns (build pick, Codex, credits).
- To keep `main.gd` under 1000 lines: `RunRecap` (Main.run_recap's body), `PlaygroundScenario.biomes/source_names`,
  `DevMasterPanel.mark_label` moved out unchanged.

## Evolving states (profile flags) and the hooks left

| State / hook | Flag or call | Today |
|---|---|---|
| `gate_open` (the north gate opens, the alcove lights) | `count:collectibles:12` | sealed (no collectibles section yet: CL, profile v2) |
| 16 floor runes, one per collectible | `rune_flag = count:collectibles:%d`; `HubView.set_runes(lit)` | all dark |
| Archive shelf: 16 slots, 3 pedestals | `HubView.show_collected(count)` (CL) | dark |
| `trophy_lit` (the Trophy Area's brazier) | `codex_total:bosses:kills:1` | lit once any floor boss fell |
| Trophy pedestals' plaques | `HubFlags.boss_trophies` (Codex bosses' kills) | gold per fallen boss |
| `trophy_crown` | `achievement:final_boss` | shown once the final boss fell |
| `machine_looped` (a violet outer ring on the machine) | `achievement:ascend_1` | shown after an Ascension |
| Wardrobe (RB) | `HubStationPanel` stand-in; `HubView.set_robe(c)` recolours the stand-in robe | the owner's wardrobe draws the robe fused into his mesh, so RB needs it as its own part (art list `hub_wardrobe_robe`) |
| Progression Station (MP) | `HubStationPanel` stand-in (`HUB_PROGRESSION_SOON`) | placeholder |
| More states | `profile:<section>:<key>`, `achievement:<id>`, `codex:<page>:<id>` in `HubStateDefinition` | grammar ready |

No toast for any of them (W46).

## Tests

Commands (Git Bash, the owner's PC, own APPDATA, one Godot process at a time):

```
godot --headless --path . --editor --import --quit
gdformat --check src tests scripts && gdlint src tests scripts      # Success: no problems found
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<files> -gexit
```

| Run | Build | Result |
|---|---|---|
| `tests/content, tests/arch, tests/unit/debug, tests/unit/app, tests/unit/application` | 573e13a6 (before the merge) | 289 tests, 288 passing; the 1 red (`test_dev_master_panel` "data/hub is in the panel") fixed after: `hub` added to NOT_BALANCE |
| `tests/unit/presentation, tests/unit/debug` | 573e13a6 | 969 tests, 968 passing; the red: `test_shop_stall_view.test_the_owners_stall_is_the_tent` (devices delivered in MI2 are listed; the test still wants them unlisted: not HB's, already red) |
| `test_hub.gd, test_hub_view.gd, test_shop_stall_view.gd, test_dev_master_panel.gd, test_e2e_hub.gd` | after the merge and the models | 31 tests, 29 passing: test_shop_stall_view's same pre-existing red, and one hub e2e (the walk round the machine's larger base), fixed in HubWalk; `test_e2e_hub.gd` then 7/7 |
| **all of tests/e2e, first half** (52 files) | f243ffd7 (merged with claude/world-combat-v090 at 14bd36f9) | 85 tests, 82 passing, 3 failing (below) |
| **all of tests/e2e, second half** (52 files) | f243ffd7 | 101 tests, 100 passing, 1 failing: `test_e2e_input.test_remapped_key_from_profile_moves_the_player` (its profile maps move_up to I only, so HubWalk's stick couldn't walk to the machine); fixed (HubWalk uses the remapped keys); `test_e2e_input.gd` + `test_e2e_hub.gd` re-run: 13/13 |

The three first-half reds, and why they are not the hub's:
- `test_e2e_bosses` "the run carries the compiled bosses": 7 vs 6 (NB1 added a boss; the test's count is 6);
- `test_e2e_events.test_take_an_event_choice_and_a_cursed_chest_card`: the event/chest/curse chain fails after the
  floor starts (EL removed the Ambush Cache and Marked, `data/events/ambush_cache.tres`, `data/curses/marked_hunt.tres`);
  re-run alone: still red;
- `test_e2e_damage_soak` "no orphan nodes": 6 vs 0 in the batch (the count is the process's; earlier files such as
  test_e2e_ascension and test_e2e_blade_feel leave orphans); **re-run alone: passes** (1/1).

New tests: `tests/unit/application/test_hub.gd` (8), `tests/unit/presentation/test_hub_view.gd` (6),
`tests/e2e/test_e2e_hub.gd` (7: the small menu; Play → walk to the machine → its build screen, Esc back, the pick
starts a run; every station's panel; the hub's pause → Options → Main menu; die → summary → Restart in one press →
die → the hub; the hub in Spanish; the run save untouched). `E2e.start_from_menu` (same signature) now walks through
the hub (`tests/support/hub_walk.gd`), so every e2e starts a run through the hub; the menu e2e that opened the Codex,
Credits or the build screen from the menu go through the hub's stations.

Not run here: the full GitHub suite (the PR runs it), timing (none measured).

## Shots

`godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/hub_shots.gd` (RTX 3060, Vulkan
Forward+), written to `build/shots/v0.9.0/hb/`, copied by hand into `hb_shots/`:

- `en_1_menu.png`, `es_1_menu.png`: the small menu (no save: Continue greyed out, Play focused);
- `en_2_hub_spawn.png`, `es_2_hub_spawn.png`: the hub from the spawn, every station, the sealed gate at the top;
- `en_3_hub_portal_machine.png`, `es_3_hub_portal_machine.png`: the hero at the Portal Machine, its prompt.

Owner fields: how the hub feels, the machine's size, the camera: **OWNER ONLY**.

## Open points for the lead

- Continue: the brief said "Play and Continue go to the hub"; HUB_MOCKUPS (approved, "Shared by all three options")
  says Continue resumes the saved run. Built per HUB_MOCKUPS (Continue resumes the run directly). Flagged, not decided.
- The pause menu in a run still offers Main menu (not the hub).
- `hub_portal_machine` at 4.6 m instead of the art list's 6.0 m (starting value).

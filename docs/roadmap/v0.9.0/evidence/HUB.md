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

# v0.9.0 HB2: the walk into the portal

Owner (PLAN `| HB2 |`): "there is no animation when taking the portal, you should click, choose weapon and then the
character walks upstairs towards the portal and crosses it". Built by an agent on branch `v090-hb3` (owner's PC:
i7-10700K, RTX 3060, Godot 4.7.2, Windows 11).

- At the Portal Machine: E, then the weapon pick (the build screen as before). The build screen closes and the hero
  walks from where it stands (round the machine's side first if it stood north of the steps) to the foot of the
  machine's front steps, climbs them (its node rises to the dais, 1.28 m) and walks into the ring; the portal flares
  as it nears (the swirl and the core glow brighten, a burst of light motes fires once), the hero shrinks into the
  light while crossing, the camera eases toward the ring and closes in a little (zoom 1.18; none with shake off or
  reduced motion). Then the run's load behind the cover and floor 1's arrival, as before.
- Length: the walk at 2.6 m/s (faster when far round the machine: the walk never takes more than 2.2 s) + 0.35 s
  crossing + 0.35 s hold. From the machine's prompt south of it: **126 frames, 2.10 s** (test_e2e_hub, below).
- Input is ignored during it (the hub's World is held: nothing steps); a press of E / accept skips the rest.
- Presentation and app flow only: `HubPortalWalk` (the path, sampled in frame time), `HubView.walk_into_portal`
  (moves the hero's node, feeds the avatar walk states, the flare, the camera), `HubMachine.walk_points/set_flare`,
  `HubSession.walk_into_portal(done, before)` (holds the hub; `done` is Main's old load call). The sim is untouched.
- Tests: `E2e.frames()` / `loaded()` wait a walk out like a load (so every e2e that picks a weapon is unchanged);
  `HubWalk.through_portal()` watches it on raw frames. New: test_e2e_hub `test_the_pick_walks_the_hero_up_into_the_portal`,
  `test_a_press_skips_the_walk`; test_hub_view `test_the_walk_into_the_portal`; test_e2e_loading_cover waits the walk
  before its "covered at once".

Raw output (test_e2e_hub):

```
    HB2: the walk into the portal took 126 frames (2.10 s)
```

# v0.9.0 HB3: a bigger, rearranged, dressed Rune Ring

Owner (PLAN `| HB3 |`): "a bit bigger and separate the runes a bit from the portal … use the top part of the hub to
place all the interactive things, looking into the middle, not all loking down … decoration, floor … different
walls"; the eight pieces of art list §4b, delivered 2026-10-23.

## The layout (data/hub/rune_ring.tres, plan metres, +y north = the screen's top)

| | HB | HB3 |
|---|---|---|
| Plaza radius | 12.5 | **16.0** |
| Rune ring | 5.4, even | **7.8**, on the medallion's 16 sockets (`rune_angles`, measured by the prep) |
| Spawn | (0, -10.4) | (0, -13.2) |
| Rune Archive | (-7.4, 4.4) | 12.5 m at 135°: (-8.84, 8.84) |
| Trophy Area | (7.4, 4.4) | 12.5 m at 45°: (8.84, 8.84) |
| Wardrobe | (-8.8, -3.4) | 12.6 m at 165°: (-12.17, 3.26) |
| Progression | (8.8, -3.4) | 12.6 m at 15°: (12.17, 3.26) |
| Credits stone | (-5.4, -8.4) | 12.8 m at 70°: (4.38, 12.03), footprint 2.2 x 2.0 |
| Alcove | (0, 15.2) | (0, 19.8) |
| Camera | view 17 m, lean 0.25 from (0, 3.4) | view 22.5 m, lean 0.25 from (0, 4.4) |

Every station stands in the top half, turned to face the plaza's middle (`HubLayout.facing`: its footprint, its
prompt reach and its drawing turn together). Pillar braziers at 8 spots (two flanking the gate, the rest round the
ring), 5 props (3 crate clusters, 2 crystal planters near the spawn), all solid. The north gate stays at the top,
reachable along the gate lane; every hook stays (runes per collectible, `gate_open`, `set_robe` / RB's `set_look`,
the Wardrobe panel, the Archive slots, the trophy states).

Walking times from the spawn (test_hub `test_walking_times_from_the_spawn_stay_short`, the hub's World stepped at 60
Hz, the hero steered straight, round the machine where it is in the way), raw output:

```
    HB3 walking times from the spawn: portal 1.62 s, wardrobe 2.97 s, progression 2.97 s, archive 3.55 s, trophy 3.55 s, credits 3.97 s
```

## The owner's eight pieces (scripts/assets/hb3_prep.py; mi2_prep's weld, Godot's simplifier, atlas, bake)

Command: `GODOT=<godot> python -I scripts/assets/hb3_prep.py` (the venv with numpy, Pillow, xatlas, scipy; backend
`godot`, scripts/assets/gd_simplify.gd). Raw triangles -> installed (budget), size in game:

| Piece | Raw tris | Installed | Map | Size (m) | How |
|---|---|---|---|---|---|
| `hub_wall_segment` | 18,517 | 2,975 (3,000) | 1024 | 9.39 x 4.6 x 2.36 | re-bent onto the plaza's ring (its own curve was about 6 m radius): scaled to 30° of a 16 m ring, straightened on a fitted quadratic, wrapped; written in the plaza's frame; 11 copies (the north slot is the gate's); the 5 south ones sunk to show 1.5 m (the low south rim, nothing tall before the camera) |
| `hub_pillar_brazier` | 19,036 | 1,798 (1,800) | 1024 | 1.65 x 3.6 x 1.54 | 8 placed; the game's fire in its bowl |
| `hub_floor_rune` | 19,764 | 448 (450) | 512 | 1.25 x 0.14 x 1.25 | 16, on the sockets, glyph to the middle; lit: its carved grooves glow blue (a shader on its own map) + the halo, floor pool and light |
| `hub_sealed_gate` | 18,987 (14,062 kept) | 2,598 (2,600) | 1024 | 6.4 x 5.05 x 2.22 | cut by region from its doors, both in the whole gate's frame |
| `hub_sealed_gate_doors` | 4,925 of the gate | 597 (600) | 1024 | 2.66 x 3.93 x 0.88 | hidden when the gate opens; the violet sigil and glow on it |
| `hub_credits_stone` | 3,998 of hub_props | 1,500 (1,500) | 1024 | 2.2 x 1.68 x 2.05 | the Credits station |
| `hub_trophy_wall` | 7,525 of hub_props | 1,499 (1,500) | 1024 | 3.8 x 2.86 x 2.04 | behind the Trophy pedestals (the code wall is its stand-in) |
| `hub_crates` | 4,740 of hub_props (2 pieces) | 1,498 (1,500) | 1024 | 1.9 x 1.23 x 2.30 | 3 placed at the edges |
| `hub_crystal_planter` | 3,210 of hub_props | 1,496 (1,500) | 1024 | 1.45 x 2.4 x 1.29 | 2 placed by the spawn |
| `hub_ground.png` | 1254² | 1024² | | tiled every 6 m | the plaza's paving |
| `hub_ground_path.png` | 1536 x 1024 | 1024 x 683 | | 2.4 m wide | the walkway: spawn lane, a ring past the stations' fronts, the gate lane, a band along the walls |
| `hub_ground_centre.png` | 1254² | 1024² (alpha) | | 20.2 m across | the medallion: it had 14 sockets (none at 3 and 9 o'clock); the prep found them, fitted their circle (socket ring 0.7729 of its radius) and copied the top socket, turned, to 3 and 9 o'clock: 16 |

hub_props was cut by its connected pieces' centres (raw x): the credits stone, the trophy wall, the crates/barrel/
scrolls (two pieces), the planter. All listed in assets/models/manifest.json with their sha256; the credits list
rebuilt (`scripts/content/build_credits.gd`). `ShopModels` reads the nine with `as_is` (prepared at game size and
frame). Every piece keeps a code stand-in when it isn't installed (L15).

**Fire (VX bar):** each pillar's fire is layered: flame licks from the owner's `fx_flame_shapes` sheet (16 particles,
rising and shrinking, white-gold to deep orange), a hot halo, a warm pool on the floor, a flickering light, embers.

## Tests (Git Bash, the owner's PC, own APPDATA, one Godot process at a time)

```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests      # Success: no problems found
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -gtest=<test_hub, test_hub_view> -ginclude_subdirs -gexit
godot ... -gtest=<tests/e2e, the first 54 files by name> -gexit ; then the other 53
```

| Run | Build | Result |
|---|---|---|
| tests/content + test_hub + test_hub_view | 94b4c18c (merged with claude/world-combat-v090 at 67bc60a8, RB) | 32 scripts, 172 tests, 172 passing (an earlier run: 3 red, fixed: the pillar list as a PackedVector2Array didn't hash (CanonicalValue), the credits list not rebuilt) |
| tests/e2e, first half (54 files) | 94b4c18c | 87 tests, 86 passing; 1 red: `test_e2e_damage_soak` "no orphan nodes" 17 vs 0 in the batch (HB's known batch red); **alone: 1/1 passing** |
| tests/e2e, second half (53 files) | 94b4c18c | 105 tests, 103 passing; 2 red, fixed after: test_e2e_hub's new walk test asserted the closed build screen gone in its own frame (it is queued for deletion; now checked so); test_e2e_wardrobe (RB's) still looked for the run pause's Main menu row, which HB made "To the Rune Ring" (now `HubWalk.from_run`). Re-run `test_e2e_hub.gd` + `test_e2e_wardrobe.gd`: 10 tests, 10 passing |

test_e2e_run_flow, test_e2e_saves, test_e2e_pad_menus and every e2e using `start_from_menu` are in the two halves
(green). Not run here: the full GitHub suite; timing (none measured).

## Shots

`godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/hb3_shots.gd` (RTX 3060, Vulkan
Forward+), written to `build/shots/v0.9.0/hb3/`, copied by hand into `hb_shots/`:

- `en_hb3_1_hub_spawn.png`: the hub from the spawn (the whole ring in view, the gate at the top);
- `en_hb3_2_hub_top_half.png`: a tool view from above the top half (camera pitched to 52°): the stations facing in;
- `en_hb3_3_walk_up_the_steps.png`, `en_hb3_4_walk_through_the_portal.png`: the walk, mid-climb and crossing.

Owner fields: how the walk and the new hub feel, the sizes, the camera: **OWNER ONLY**.

## Open points for the lead

- The medallion had 14 sockets; two were added by the prep (copied from its top socket) so the 16 runes each sit in
  one. The spacing round the ring is the owner's image's (not even).
- The stations' plinths (the Archive's ledge, the Trophy step) now wear the paving; they are still code boxes.

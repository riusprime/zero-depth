# BOSSES_NB: the four new bosses' models and The Tidecaller (v0.9.0 Step NB1)

- **Status:** RUN (agent, on the owner's PC: Windows 11, i7-10700K, RTX 3060; Godot `4.7.2.stable.official.ed1daf0bf`;
  shots on the GPU, Vulkan Forward+). How the fight feels and how the models move: **OWNER ONLY**.
- **Build:** branch `v090-nb1` from `claude/world-combat-v090` at `ebb485ca`; the install commit `7d4b9fb0`, the boss
  commit after it (its SHA is in the report and PROGRESS).
- **Date:** 2026-10-23
- **Who ran it:** agent

Owner (OWNER_QUESTIONS 1, 2026-10-23): "ok go for those" (BOSSES_4_5.md); on the models: "you will have to animate the
bosses like with the other ones".

## 1. The models (`scripts/assets/nb_prep.py`)
`python -I scripts/assets/nb_prep.py` (the venv: numpy, Pillow). Each file: centred, feet at y = 0, front kept on +Z,
scaled to the art list's height; its own UVs and all three maps kept (base, metallic-roughness, normal), each reduced
to 1024 px (the Tidecaller's base was 8192 px, its other two 4096; the rest 2048); nothing simplified.

| id | raw | triangles | size (m, x y z) | how | parts (triangles; pivot m, file frame) |
|---|---|---|---|---|---|
| boss_tidecaller | 13,645,948 B | 18,928 | 3.2 × 3.2 × 2.42 | cut into parts | Body 13,763; Bell 946 (-1.10, 2.69, 0.32); Staff 787 (-1.06, 1.60, 0.10); ArmL 686 (0.70, 1.92, 0.06); Shell 2,746 (0, 2.24, -0.38) |
| boss_twin_warden_amber | 3,903,252 B | 19,372 | 1.96 × 2.2 × 1.43 | rigged, skeleton kept (52 joints) | — |
| boss_twin_warden_violet | 3,528,412 B | 18,634 | 1.99 × 2.2 × 1.17 | cut into parts | Body 14,279; Helm 848; Shield 2,797; Sword 710 |
| boss_clockwork_judge | 4,375,944 B | 19,292 | 2.76 × 3.6 × 1.16 | cut into parts (its skin is unusable, below) | Body 14,805; ArmL 1,347; ArmR 1,544; Gears 1,375; HandHour 107; HandMinute 114 |
| boss_lantern_shade | 3,056,604 B | 19,702 | 2.71 × 3.4 × 1.45 | cut into parts | Body 17,186; ArmL 1,042; ArmR 749; HandLantern 725 |

The cuts are regions of the figure (shares of its height) read from orthographic renders of each raw file with the
labels painted on (a check script in the agent's scratchpad, not shipped). Findings:
- **Lantern Shade:** the delivered model has no lantern cage for a head (a dark empty hood) and only the one held
  lantern, so there is no `Cage` or `Lantern1-4` to cut: Body, ArmL, ArmR and HandLantern only. Its art row asked for
  the cage: **owner's call** (a new file, or the cage made in code when its step comes).
- **Amber Warden (rigged):** its joints have no transforms in the file (every joint node at the origin, unturned),
  only inverse bind matrices; as delivered the rest pose folds the mesh up (the first lineup render showed it crouched
  small). nb_prep rebuilds each joint's rest from its bind (`repair_joints`: its global transform is the inverse of
  its inverse bind matrix, its local one relative to its parent, the turn re-orthonormalised: the binds are stored to
  3 decimals). Only 11 of its 52 joints carry weight (`ibm.py`: "joints used 11 of 52").
- **Clockwork Judge (rigged as delivered):** its inverse bind matrices are not matrices (the bytes at their buffer
  view decode to values up to about 1e32 against the accessor's own min/max of ±1; Godot imported it with the mesh
  out of sight, the first lineup render showed nothing), and its joints have no transforms either, so no rest pose can
  be recovered. Its skin is left out and it is cut into the art list's parts like the static ones (the vertices are the
  bind pose: the shape the renders show). The hands are the triangles standing proud of the clock face, split by side;
  the longer is the minute hand.

Hashes (assets/models/manifest.json): tidecaller `c88d0ef7…`, amber `ed2cdf3f…`, violet `adcfc52c…`, judge
`54562507…`, shade `69061939…` (full hashes in the manifest).

In game (BossModels `parts`, NB1): a cut model is merged into one mesh in our frame (+X front) and rigged one bone per
part (Body → body, ArmL → arm_l …; the Tidecaller's bell hangs from its staff), so its avatar plays BossClips like the
code-rigged bosses. Only the Tidecaller is wired in this step (BossModels.SPECS); the other four wait for their steps.

## 2. The Tidecaller (BOSSES_4_5.md N1)
`data/bosses/tidecaller.tres`, floor 4's pool (`data/boss_pools/floor_4.tres`). Kind `TIDECALLER` (appended);
`BossOrder` compiles it after the six (`save_order = 1`) so every saved boss index stays (alphabetically it would have
taken the Warlord's; `test_final_boss` pins the order).
- **The Pull** (`the_pull`, move `tide`, shielded, `BossTide`): the bell rings 1.0 s, then the room pulls the hero in
  at 1.2 m/s for 3 s (Tide Rings: `tidecaller_pull_rings`, 3 rings of 14 with 2 gaps, every wave inside the pull, the
  boss's shots bending toward it at 25 °/s), then pushes out at 1.0 m/s for 2 s (no ring spawns). Every 9 s start to
  start (`signature_every_seconds`; the first 3 s in), never by the weighted pick; phases 2 and 3 open with it.
  Phase 3: `the_pull_3`, 1.5 / 1.2 m/s, 4 rings, 30 °/s.
- **Fair:** the drift is capped at 1.5 m/s (`BossSchemas.TIDE_MAX_MPS`, validated and clamped); it never presses the
  hero deeper toward a wall (0.6 m margin; whole step, else x, else y, else none), so never into a corner or pinned;
  it stops 0.3 m short of the body; none while dashing. No closing arena for this boss (the tide is its pressure).
- **Tide Rings** (`tide_rings`, `tide_rings_fast` in phase 3): rings of sea-green bubbles with gaps (`tide_bubble`).
- **Undertow** (`undertow`; `undertow_2` from phase 2: two): a tracked circle (1.6 m, locks 0.8 s) that on its strike
  drags the hero 1 m toward its centre from within 3 m (`drag_m`, `drag_reach_m`); also its gap-closer and punish.
- **Shell Slam** (`shell_slam`, big, 4.2 m ring when close; its punish window).
- Numbers: HP 2500 (before the floor's scaling), radius 1.6 m, 1.4 m/s; phases at 66 % and 33 %. Starting values.
- Deaths (en, es): "The Tidecaller's tide dragged you into its rings." / "La marea de The Tidecaller te arrastró a sus
  anillos."; rings, undertow and slam lines too; the telegraph caption "[Warning: the Tidecaller's bell tolls]".
- Looks: TidecallerAvatar (the owner's model; bell swing, shell pulse and arm reach driven by the tide on top of
  TidecallerClips; a code stand-in of the same parts when the file is missing), TideViews (the current: a water shader
  with spiral seafoam streaks flowing in, then out, caustics and foam; droplets riding it, halved on Low density; the
  bell's toll rings; the push's swell wave; a sea-green light), a WATER marker pattern for the Undertow and the slam,
  a sea-green shield. Sounds (placeholders, `generate_sfx.py`): `boss_telegraph_tidecaller` (a muffled bell),
  `boss_tide_pull` (a water surge).

## 3. Tests
Lint: `gdformat` / `gdlint` on every changed .gd: "0 files reformatted, 43 files left unchanged. Success: no problems
found".

Each run: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>` (own APPDATA).

| run | files | result |
|---|---|---|
| the Tidecaller's sim | tests/unit/sim/test_tidecaller.gd | 15/15 (data, bad numbers, pull 1.2 m in its first second and push 1.0 m, the 3 s / 2 s timing, the cap with a mistuned 5 m/s, body and dash, corners and walls, rings only in the pull and bending, the Undertow's drag and strike, the shield, the 9 s cadence, phases, determinism and a mid-fight save, an older snapshot, the death lines) |
| view | tests/unit/presentation/test_tidecaller_views.gd (with test_boss_animations, test_boss_models, test_boss_models_2, test_bosses_2_views, test_boss_rigs) | 63/63 |
| e2e | test_e2e_tidecaller, test_e2e_run_flow, test_e2e_old_save | 5/5, 91 asserts, 80.3 s |
| boss and save sims | test_old_saves, test_world_snapshot, test_state_hasher, test_bosses, test_bosses_2, test_boss_gates, golden test_replay_ground_plane | 71/71 (447 s) |
| all boss sims (before BossOrder) | test_boss_challenge … test_boss_signatures_2, test_bosses, test_bosses_2, state hasher, snapshot, old saves, golden | 198/200: test_boss_pace (big attacks 11 → 12: the Shell Slam) and test_boss_pressure (every boss but the Gatekeeper has a gap-closer: the Tidecaller got the Undertow) fixed, then 46/46 with test_tidecaller, both content boss tests and the view test |
| arch | tests/arch | 4/4 |
| debug | tests/unit/debug | 16/16 |
| presentation boss views | 17 files (audio director, boss views, fireballs, vx looks …) and test_final_boss | 182/185 → fixed (the bubbles' first colour sat near the hero's frost mint; the Tidecaller in the boss-views map; the boss order), then 74/74 |
| assets | test_model_manifest, test_assets | 11/11 |
| content | tests/content | 143/145: **test_credits_licences** (2) fail |

**Not green: the credits.** `godot --headless --path . -s scripts/content/build_credits.gd` refuses to write:
```
ERROR: assets/textures/vfx has no licence
ERROR: could not write res://data/credits/licences.tres
```
`assets/textures/vfx/manifest.json` (from Step VX) has no `licence` key, so the credits can't be rebuilt on this base
and `test_the_committed_list_matches_a_fresh_build` is red before NB1 too; NB1's change to the models manifest's
licence line (the four bosses) waits in that same rebuild. Not fixed here (VX's file).

Not run here (GitHub's shards): the rest of the suite.

## 4. Shots
`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/nb_bosses.gd` (written to build/, copied
by hand):
- [`nb_shots/1_five_boss_models_side_by_side.jpg`](nb_shots/1_five_boss_models_side_by_side.jpg): the five files as
  prepared, front to the camera.
- [`nb_shots/2_tidecaller_mid_pull.jpg`](nb_shots/2_tidecaller_mid_pull.jpg): the Pull 75 ticks in (the script
  printed: hero from (-6.5, 4.5) to (-5.19, 3.73), tide phase 1, progress 416 ‰, 1.2 m/s), its shield up, its rings
  bending, the water drawn round it.

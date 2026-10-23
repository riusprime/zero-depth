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

---

# NB2: The Twin Wardens (v0.9.0 Step NB2)

- **Status:** RUN (agent, on the owner's PC: Windows 11, i7-10700K, RTX 3060; Godot `4.7.2.stable.official.ed1daf0bf`;
  the shot on the GPU, Vulkan Forward+). How the fight feels and how the two models move: **OWNER ONLY**.
- **Build:** branch `v090-nb2` rebased on `claude/world-combat-v090` at `14bd36f9` (EL merged); the step's commit SHA
  is in the report and PROGRESS.
- **Date:** 2026-10-23
- **Who ran it:** agent

Owner (OWNER_QUESTIONS 1, 2026-10-23): "ok go for those" (BOSSES_4_5.md row N2).

## 5. The fight as built (BOSSES_4_5.md N2)
`data/bosses/twin_wardens.tres` (`save_order` 2: compiled after the Tidecaller, every saved boss index unchanged);
floor 4's pool is now the Tidecaller and the Wardens (`data/boss_pools/floor_4.tres`). Kinds `TWIN_WARDEN` and
`TWIN_WARDEN_VIOLET`, appended after EL's `CONDUIT`. SIM_CONTRACTS §10k, CONTENT_SCHEMA (boss fields, two moves).

**Two bodies: two linked actors (`BossTwin`), not one actor with a drawn twin.** Why: the twin has to be hit by every
player weapon (blade arcs, bolts, Seekers, bombs, Void pulls, DoTs), immune like a boss (knockback, freezes, executes,
Remnants, heal orbs) and able to wind up, shield, telegraph and stagger. All of that already works for an actor of a
boss kind with a BossStore entry, through about 40 `is_boss_kind` checks; a drawn body would need every one of those
paths taught about it. So both bodies are boss-kind actors with their own BossStore entry (same table), and
`BossTwin` makes them one boss:
- the amber body is the boss: the HUD bar (`boss_index`, the first live boss), `World.boss_id`, the codex's fight, the
  single `BOSS_DEFEATED`, the reward, the kill count and the legendary core; the twin rises beside it (`on_spawn`,
  5 m to a clear side) with its HP, max HP, catch-up and intro, and leaves with no defeat, shards, kill or core of its
  own (`leaves`); only the boss's phase gate brings adds;
- one HP (`Damage._apply` → `share_hp`, `fall_together`): both cross 66 % and 33 % on the same tick and fall on the
  same hit (the twin's own KILL, for its death in the views);
- one mind: the twin never picks an attack; it starts the boss's attack on the same tick (`on_start`) when free;
- the door/arena flow is the boss flow's (`boss_alive` turns false when both are gone); the death recap names the pair
  for either body's attack (`boss_table_of_kind` answers the twin's kind); save/restore is the five `BossStore.twin_*`
  lists (hashed after a sentinel only while a pair lives; `ADDED_SINCE_V05`, so an older save loads).

Mechanics (starting values):
- **The chain:** held 3..9 m (the twin is drawn in or out along it after the steps and again after walls and bodies
  push; if a wall stands there the boss gives way); not solid, so it never pins; burns a touching player 12 every
  0.5 s (damage over time; the hurt iframes and the hurt hit-stop apply: in sim ticks the gap is 30 + the 4-tick
  hit-stop), never while dashing, never while the player stands against a wall, never while a body rises or is in a
  gate, and not while the Chain Sweep holds it; a kill by it reads "The Twin Wardens' burning chain seared you."
- **Anger:** a hit from the player on one body angers the other for 3 s at +40 % speed; one angry at a time.
- **Steps:** the boss pursues (1.6 m/s, keeps 2 m); the twin keeps 4.5 m from the player at a right angle from its
  boss, so the chain runs past the player, not through them.
- **Crossfire** (`crossfire`, shielded: the signature pattern): the safe spot stands 2 m off the chain's middle on the
  player's side; each body fires a fan (17 shots over 150°, 3 waves 0.7 s apart, 3.0 m/s) centred on the spot with no
  shot within 1.2 m of it there, so the two gaps cross only at the spot; phase 3 `crossfire_3` (19 over 160°, 4 waves,
  3.3 m/s, gap 1.1 m). Embers: gold-amber from the boss, pale violet from the twin.
- **Chain Sweep** (`chain_sweep`): the boss's line from its body through the player and 2.5 m on (3..9 m, cut by
  walls) tracks through the 1.6 s windup and locks for its last 0.8 s; the twin swings to its end; the lash hits a
  1.2 m lane (30); the boss's punish and gap-closer; phase 3 `chain_sweep_fast` (1.4 s).
- **Shield Bash** (`shield_bash`, big): each body's 2.6 m ring when close (50); the punish window.
- **"Shielded during the signature":** the signature *mechanic* (two bodies, one life) is passive, so both bodies are
  shielded through Crossfire, the signature *pattern* (BOSS_FIGHTS.md rule 3). Lead/owner may say otherwise.
- HP 2500 shared (before the floor's scaling), radius 1.0 m each, stagger 2.5 s; phases at 66 % (opens with
  Crossfire) and 33 % (opens with `crossfire_3`).
- en/es: the name ("The Twin Wardens"), a description, four death lines (crossfire, sweep, chain, bash), two captions.

**Looks.** `TwinWardenAvatar` / `TwinWardenVioletAvatar` play one clip library (`TwinWardenClips`) so they move as a
pair. Finding: the amber file's skeleton (52 joints, rests rebuilt in NB1) weights almost every vertex to
`mixamorig:Hips` (a weight count over the file's JOINTS_0/WEIGHTS_0: Hips 12,889 vertices, the next joint 15), so its
shield, sword and helm cannot move apart from the body. Both models are therefore posed through the whole figure
(the clips' BODY channel: bob, roll, lean, lunge, squash), identically; the violet's cut parts add small accents only
(helm turn, shield set, sword raise). Matching the amber's arms would need the file cut into parts like the violet:
**owner's call.** An angry Warden leans in and its crack light flares. `TwinViews` draws the chain (lit iron links
each turned a quarter, a hot core per link fading amber to violet along it, a soft halo, rising embers halved on
Low, a light; dim when cooled, white-hot at the angry body's half), a burn flash where it touched, Crossfire's two gap
lanes and its gold safe-spot ring, and the Chain Sweep's white-hot lash. Strike looks: the sweep's lane scorches
(MOLTEN, skid), the bash cracks a stone ring; shield colours amber and violet; sounds (placeholders,
`generate_sfx.py`): `boss_telegraph_twin_wardens` (a chain rattling taut over a stone grind) and `boss_twin_chain` (a
link whip and a hiss: the lash, a burn, a Warden turning angry). Codex glyph: two shields and a chain.

**Sounds and credits.** `python -I scripts/audio/generate_sfx.py` (the venv) rendered every file; on this machine six
files not ours came out different (barrel_blast, barrel_fuse, bomb_throw, container_break, pillar_turn, wall_break),
so those were restored from git and only our two wavs and their two manifest rows are committed. Then
`godot --headless --path . -s scripts/content/build_credits.gd`: "wrote res://data/credits/licences.tres (5 entries)"
(audio 123 → 125 files).

## 6. Tests (NB2)
Lint: `gdformat --check` / `gdlint` on the 46 changed or new .gd files: "46 files would be left unchanged",
"Success: no problems found".

Each run: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>` (own APPDATA, one
Godot at a time).

| run | files | result |
|---|---|---|
| the Wardens' sim | tests/unit/sim/test_twin_wardens.gd | 17/17, 165 asserts (data, bad numbers, one HP and one bar, one defeat / kill / reward, gates on both at once, the chain 3..9 m over 40 s in the open and in a 9 m room plus forced 20 m and 0.5 m, the burn 12 every 0.5 s (+ hit-stop) and not solid, no burn dashing / against a wall / rising, anger one at a time and +40 %, Crossfire's gaps meeting only at the spot (no damage there, damage off it) and the twin's violet embers, the Chain Sweep tracking, locking, lashing on the line and missing off it, the twin never picking, determinism and a mid-fight save, an older save, the death lines, a chain kill's line) |
| boss sims, saves | test_twin_wardens, test_tidecaller, test_final_boss, test_boss_pace, test_boss_gates, test_boss_pressure, test_boss_markers, test_bosses, test_bosses_2, test_boss_fights, test_boss_fights_2, test_boss_fights_3, test_boss_signatures, test_boss_signatures_2, test_boss_challenge, test_world_snapshot, test_state_hasher, test_old_saves | 243/243, 66,247 asserts, 1201 s |
| (before it) | the first boss run (8 files) | 75/81: the expected counts (bosses 7 → 8, classed attacks 90 → 95, big attacks 18 → 19 and 12 → 13, the boss order with `twin_wardens`, KEPT_SLOW) and the PLAN's 2.5 s stagger (the data had 2.0, set to 2.5); fixed, inside the 243 |
| view | 23 presentation files (test_attack_visuals, _2, test_audio_director, test_boss_animations, test_boss_challenge_parity, test_boss_challenge_views, test_boss_fight_views, _3, test_boss_fights_2_views, test_boss_models, _2, test_boss_rigs, test_boss_signature_views, _2, test_boss_telegraph_parity, test_boss_views, test_bosses_2_views, test_codex_view, test_enemy_fireball_views, test_final_boss_views, test_telegraph_parity, test_tidecaller_views, test_vx_looks) | 194/199: the embers' first colours sat near a hero colour (#FFB347 vs #FFAA33) and near the Nemesis's (#C08CFF); a test's boss-kind map and the strike-shape map lacked the new kind and move. Colours moved to #FFDD00 / #BB99CC (a probe over every hero colour and every other look's core), maps added: those five files 47/47 |
| the Wardens' views | tests/unit/presentation/test_twin_warden_views.gd | 5/5 (both models at 2.2 m, the violet's four bones, driven alike they hold the same pose, the angry one's light, both stand-ins, the chain view: links, heat, embers High/Low, sag, both lanes and the spot in Crossfire, cooled in the sweep, the lash, the burn flash); with test_twin_wardens after the last edits: 22/22 |
| content, debug, arch | tests/content, tests/unit/debug, tests/arch | 169/170: test_credits_licences (the audio count) → credits rebuilt → 4/4 |
| e2e | test_e2e_twin_wardens, test_e2e_tidecaller, test_e2e_run_flow, test_e2e_old_save | 6/6, 111 asserts, 111.6 s |

The e2e: a floor-4 save (the first seed whose floor 4 draws the Wardens; `test_e2e_tidecaller` now picks the first
that draws the Tidecaller, since floor 4 has two) continued with Enter, God clicked, E opens the door, the stick walks
in, the door seals, both owner models rise under one bar named "The Twin Wardens", the chain is drawn, the stick walks
to the violet twin and the mouse's attacks land: the shared HP drops on both bodies and a Warden turns angry.

Not run here (GitHub's shards): the rest of the suite.

## 7. Shot (NB2)
`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/nb_twin_wardens.gd` (written to build/,
copied by hand):
- [`nb_shots/3_twin_wardens_crossfire_chain.jpg`](nb_shots/3_twin_wardens_crossfire_chain.jpg): Crossfire 50 ticks
  into its firing on the Ruins stage; the script printed: "tick 123 hero (-0.4, -0.8) hero hp lost 0 chain
  [(-2.8, 1.2), (2.0, 1.2)] hot true safe (-0.4, -0.8) links 17 shots 38" (the hero standing on the safe spot took
  nothing). Both owner models shielded, the burning chain between them, amber and violet embers, the safe spot's ring.

# NB3: The Clockwork Judge (v0.9.0 Step NB3)

- **Status:** RUN (agent, on the owner's PC: Windows 11, i7-10700K, RTX 3060; Godot `4.7.2.stable.official.ed1daf0bf`;
  the shot on the GPU, Vulkan Forward+). How the fight feels and how the model moves: **OWNER ONLY**.
- **Build:** branch `v090-nb3` from `claude/world-combat-v090` at `6ea476e1`; the step's commit SHA is in the report
  and PROGRESS.
- **Date:** 2026-10-23
- **Who ran it:** agent

Owner (OWNER_QUESTIONS 1, 2026-10-23): "ok go for those" (BOSSES_4_5.md row N3); PLAN NB: "can you ignore the
skeleton?" (the Judge moves as cut parts).

## 8. The fight as built (BOSSES_4_5.md N3)
`data/bosses/clockwork_judge.tres` (`save_order` 3: compiled after the Wardens, every saved boss index unchanged);
floor 5's pool is new (`data/boss_pools/floor_5.tres`): the Judge only, until NB4 adds the Shade. Kind
`CLOCKWORK_JUDGE`, appended after `TWIN_WARDEN_VIOLET`. SIM_CONTRACTS §10l, CONTENT_SCHEMA (two moves).

- **Your echo** (`the_echo`, move `echo`, shielded; `BossJudge`): while the Judge lives it keeps the hero's last 3 s,
  a point every 0.25 s (12 points, sim state: `BossStore.echo_*`, snapshotted and hashed). Every 10 s start to start
  (the first 4 s in; never by the pick; the Tidecaller's cadence, `BossTide`, now takes `tide` or `echo`) the
  recording locks into the path, the points within 0.9 + 0.35 + 0.3 m of where the hero stands left out (it never
  strikes where you stand at its start); the whole path shows for 0.8 s (the windup); then a ghost strike (a 0.9 m
  disc, 20) lands on each point in the order walked, 0.25 s apart. Standing still through its start: no point
  strikes. Looping on the echo's lag: struck. One echo at a time (one attack at a time; 10 s cadence).
- **Gear Spiral** (`gear_spiral`, pattern): two arms of gear-sparks turning (`clockwork_gear_spiral`, +80 °/s, 30
  waves 0.12 s apart, 3.0 m/s); phase 2 opens with `gear_spiral_2` (−85 °/s, reversed), phase 3 with `gear_spiral_3`
  (+100 °/s, reversed again, 3.4 m/s).
- **Verdict** (`verdict`, move `verdict`): a 3 m square (`half_m` 1.5; not a circle: its corner is struck) tracks the
  hero's exact position, locks for its last 0.8 s of a 1.6 s windup, and the pendulum drops (30, medium); also its
  punish and gap-closer.
- **Gavel Slam** (`gavel_slam`, big, a 4.0 m ring when close, 50; its punish window).
- **The cadence holds (a fix found by the e2e):** the first e2e run failed ("the echo came and replayed" false): with
  the hero circling far, the punish and the gap-closer (both the Verdict) started during every cooldown, so the boss
  was never free with no cooldown and the echo never came. `BossTide.due` now returns `HOLD` when the signature is
  due but the cooldown runs, and those two wait for it. This changes the Tidecaller's timing the same way (its tests
  pass, below).
- HP 2500 (before the floor's scaling), radius 1.4 m, 1.3 m/s, stagger 2.5 s; phases at 66 % and 33 %. Starting values.
- en/es: the name, a description, four death lines ("The Clockwork Judge's verdict caught your old steps." for the
  echo; the spiral, the pendulum, the gavel), two captions.

**Looks.** `ClockworkJudgeAvatar` on the owner's model cut into parts (`BossModels` `parts`, 3.6 m: body, arm_l,
arm_r, gears, hand_hour, hand_minute; the broken skeleton ignored) plays `ClockworkJudgeClips` (the stiff walk with
the pendulum arms counter-swinging, the echo's arms spread wide, the Gear Spiral's brace, the Verdict's gavel hauled
up and swung down, the two-gavel slam, roar, stall, rise, collapse); on top the sim drives it: the clock hands sweep
faster as the echo's recording window fills and race through the replay, the gears turn (whirring in the echo), the
arms keep a slow pendulum sway that stills while the Verdict locks; a gold light at the clock face. A code stand-in of
the same parts when the file is missing. `JudgeViews`: the recording's gold glints over the points kept (halved on
Low); the path as clock-gear markers (a shader: turning toothed rim, twelve ticks, a sweeping hand, a hot core filling
as its strike nears) joined in order by a hot ribbon over a soft halo; at each strike a translucent gold afterimage of
the hero with a rim and an inner glow rising, a light ring, gear filings (halved on Low) and a light flash; the
Verdict's brass pendulum hanging over the square, hauled to its apex as it locks, swinging down with a shockwave.
Strike looks: the Verdict's square takes a gold beam (LIGHT), the slam a light ring; brass shield; `gear_spark`
fireballs (core #FFEF40, probed against every hero colour and every other look's core: the first pick #FFF2A0 was
0.194 from hero #D2FFB0 and 0.149 from `molten_drop`, both red in the view run below). Sounds (placeholders,
`generate_sfx.py`): `boss_telegraph_clockwork_judge` (ticks speeding over a ratchet, a brass chime) and
`boss_judge_echo` (a glassy chime over a swelling whoosh: each ghost strike). Codex glyph: a clock face and a gear.

**Sounds and credits.** `python -I scripts/audio/generate_sfx.py` (the venv): "125 files, 13572832 bytes, generator
v2"; six files not ours came out different (barrel_blast, barrel_fuse, bomb_throw, container_break, pillar_turn,
wall_break) and were restored from git, with the manifest; only our two wavs and their two manifest rows are
committed. `godot --headless --path . -s scripts/content/build_credits.gd`: "wrote res://data/credits/licences.tres
(5 entries)".

## 9. Tests (NB3)
Lint: `gdformat --check` / `gdlint` on the 51 changed or new .gd files: "51 files would be left unchanged", "Success:
no problems found".

Each run: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>` (own APPDATA, one
Godot at a time).

| run | files | result |
|---|---|---|
| the Judge's sim | tests/unit/sim/test_clockwork_judge.gd | 16/16, 165 asserts (the data, bad numbers, the recording (12 points, oldest first), the replay's timing and spacing (each strike on its tick, 0.8 s then 0.25 s apart, in order, 20 each), never where you stand at its start, standing still never struck, looping struck and stepping off safe, shielded through it, every 10 s and never by the pick, a far player can't starve it, the Verdict's square tracking, locking, its corner struck and past its edge safe, the phases opening with the reversed spiral, determinism and a mid-echo save, an older save, no echo state without a Judge, the echo going with the Judge, the death lines) |
| boss sims, saves, arch | test_clockwork_judge, test_tidecaller, test_twin_wardens, test_bosses, test_bosses_2, test_boss_gates, test_boss_pace, test_final_boss, test_boss_fights, _2, _3, test_boss_signatures, _2, test_world_snapshot, test_state_hasher, test_old_saves, test_layering, test_sim_purity | 221/221, 81,194 asserts, 1180.7 s |
| view (1) | test_attack_visuals, _2, test_audio_director, test_boss_animations, test_boss_challenge_parity, test_boss_challenge_views, test_boss_fight_views, test_boss_fight_views_3, … | the process stopped with no error inside test_boss_fight_views_3 after 7 files (72/72 passed); that file alone: 7/7 |
| view (2) | test_boss_fights_2_views, test_boss_models, _2, test_boss_rigs, test_boss_signature_views, _2, test_boss_telegraph_parity, test_boss_views, test_bosses_2_views, test_codex_view, test_enemy_fireball_views, test_final_boss_views, test_telegraph_parity, test_tidecaller_views, test_twin_warden_views, test_clockwork_judge_views, test_vx_looks | 128/130: the gear-spark colour (above); recoloured: the colour files 39/39; test_clockwork_judge_views 5/5 (with the sim file after the last edits: 21/21) |
| content, debug, arch | tests/content, tests/unit/debug, tests/arch | 170/170, 27,775 asserts |
| e2e | test_e2e_clockwork_judge, test_e2e_bosses, test_e2e_bosses_2, test_e2e_run_flow, test_e2e_old_save, test_e2e_tidecaller, test_e2e_twin_wardens | 11/11, 172 asserts, 172.4 s |

The e2e: a floor-5 save (seed 1; floor 5 draws only the Judge) continued with Enter, God clicked, E opens the door,
the stick walks in, the door seals, the owner's model rises named "The Clockwork Judge"; the stick circles while it
records; its echo comes, shielded, its path's markers drawn before the first strike, ghosts rising as it replays;
then the stick walks to it and the mouse's attacks land.

Not run here (GitHub's shards): the rest of the suite.

## 10. Shot (NB3)
`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/nb_clockwork_judge.gd` (written to build/,
copied by hand):
- [`nb_shots/4_clockwork_judge_echo_replay.jpg`](nb_shots/4_clockwork_judge_echo_replay.jpg): the echo 62 ticks into
  its replay on the Ruins stage; the script printed: "tick 310 phase 2 echo t 110 path 12 struck 5 markers 7 ribbon 7
  ghosts 5 shielded true hero hp lost 0". The owner's model shielded, the first five ghosts risen with their rings,
  the seven points left as clock-gear markers joined by the ribbon. Seen in the shot: a translucent grey rectangle
  round the hero, present with JudgeViews hidden too (a diagnostic render), so not this step's; left for the lead.


# NB4: The Lantern Shade (v0.9.0 Step NB4)

- **Status:** RUN (agent, on the owner's PC: Windows 11, i7-10700K, RTX 3060; Godot `4.7.2.stable.official.ed1daf0bf`;
  the shot on the GPU, Vulkan Forward+). How the fight feels, how dark is dark enough and how the model moves:
  **OWNER ONLY**.
- **Build:** branch `v090-nb4` from `claude/world-combat-v090` at `5f24f9d5`; the step's commit SHA is in the report.
- **Date:** 2026-10-23
- **Who ran it:** agent

Owner (OWNER_QUESTIONS 1, 2026-10-23): "ok go for those" (BOSSES_4_5.md row N4); PLAN NB: "Keep the empty hood" (no
head lanterns: the room's edge lanterns and the one in its hand carry the fight).

## 11. The fight as built (BOSSES_4_5.md N4)
`data/bosses/lantern_shade.tres` (`save_order` 4: compiled after the Judge, every saved boss index unchanged); floor
5's pool now draws the Judge or the Shade. Kind `LANTERN_SHADE`, appended after `CLOCKWORK_JUDGE`. SIM_CONTRACTS
§10m, CONTENT_SCHEMA (`ShadeRules`). The row's starting value "dark 4 s after the signature starts" is read as: the
room goes dark 4 s after each Lights Out starts (its windup and shielded wisps), and stays dark while the Shade lives.

- **Lights Out** (`lights_out` / `lights_out_3`: a shielded `pattern` with `dark_seconds`; `BossShade`): on the
  cadence every 12 s start to start (the first 3 s in, never by the pick; phases 2 and 3 open with it). Windup 1.0 s,
  then 3.0 s of slow wisp rings with two gaps (`shade_lights_out_wisps`, 12 a ring, 2.4 m/s; phase 3: 14, 2.7 m/s);
  the shield drops as the dark falls, 4.0 s after the start. As the dark falls every lantern is lit afresh.
- **The light (sim state):** four lanterns 1.5 m in from the middle of each wall of the sealed room. In the dark only
  3.5 m round the hero and 3.0 m round each lit lantern are lit. A lantern burns 6 s; the hero passing within
  1.2 m (+ their radius) relights it for 6 s (the lit area widens). `BossStore.shade_*`, `lamp_*`: snapshotted, hashed
  only while a Shade lives; older saves load (the Shade takes the light on its next tick). The Shade gone, the room
  relights.
- **Hittable only when lit:** in the dark a hit on the Shade whose body touches no light sparks off like a shield
  (`Damage._blocked`: `TAG_BLOCKED`, no HP lost); the boss bar shows it invulnerable then.
- **Wisp Bloom** (`wisp_bloom`, `_2`, `_3`: FLOWER patterns of `shade_wisp`, 5-6 petals, 2.2-2.6 m/s, 20 a wisp).
- **Snuff** (`snuff`, `snuff_3`: a `marks` circle 1.8 m, tracked, locked 0.8 s of a 1.6 s windup, 30; phase 3 two):
  its strike puts out the lit lantern nearest its centre. Also its punish and gap-closer.
- **Lantern Sweep** (`lantern_sweep`, big, a 3.6 m ring, 50; its punish window).
- HP 2400 (before the floor's scaling), radius 1.2 m, 1.4 m/s, stagger 2.5 s; phases at 66 % and 33 %. Starting values.
  Lights Out's wisps 22 (5 hits: small); content tests first flagged 18 (6 hits) and a 45 sweep (3 hits: not big), both
  retuned to the class rules.
- en/es: the name, a description, four death lines ("The Lantern Shade found you in the dark." for Lights Out; the
  bloom, the Snuff, the sweep), three captions.

**Looks.** `LanternShadeAvatar` on the owner's model cut into parts (`BossModels` `parts`, 3.4 m, lifted 0.3 m:
body, arm_l, arm_r, hand_lantern hanging from arm_r; the empty hood kept) plays `LanternShadeClips` (a hover, a glide
with the cloak trailing; Lights Out lifts the lantern high and spreads the free arm; Wisp Bloom holds it out; the
Snuff's two long arms reach to the circle and close; the sweep swings the lantern round; flinch, sag, a silent scream
at the gates, a rise out of smoke, a fold into its cloak); on top: a floating bob, the cloak's sway, the lantern
swinging on its chain (a damped pendulum kicked by the glide and the clips), and its light (a hot core and soft halo
drawn over the dark, a pale gold light) flaring for Lights Out and the Snuff and burning low in the dark, so the
Shade is always found by its lantern. A code stand-in of the same parts when the file is missing. `ShadeViews` (the
VX quality bar: layered): the dark is a full-screen pass that reads the depth buffer for each pixel's place on the
floor and uses the sim's light circles: a multiply layer to a violet-black night (an alpha blend only dimmed the HDR
floor: the first shot read flat brown), deepest at the screen's corners and in the fog's darker swirls, and an
additive layer of drifting violet mist with warm rims at the lanterns' light and a cool one at the hero's; it ramps in
over Lights Out's 4 s; the stage's sun and ambient dim with it (so walls and their see-through cutaways go dark too).
It draws before every see-through thing, so markers, telegraphs, bars and strike effects always draw over it; solid
bodies and the wisps' cores are darkened outside light. Four iron lantern posts with caged glass, a flickering flame,
a warm light, a warm pool over the dark and a burn ring that empties over its 6 s (flickering in its last second);
an out lantern shows cold glass and a dashed violet ring (where to relight it), puffs smoke going out and sparks
relighting. Every Shade wisp within 4 m of the hero shows an outline over the dark (never thinned by Effects density)
and a glow brightening as it nears. `shade_wisp` fireballs (core #C38CFF; the first pick #8F5CFF failed the "bright
core" luminance rule, below), pale gold shield, strike looks (the Snuff a void burst, the sweep a light ring), codex
glyph (an empty hood over a hanging lantern). Sounds (placeholders, `generate_sfx.py`): `boss_telegraph_lantern_shade`
(a chain creak, an inhale, a hum, a chime), `boss_shade_snuff` (the dark falling, a lantern out), `boss_shade_relight`
(a lantern relit).

**Code limits.** `src/sim/ai/boss_ai.gd` stays at 1000 lines (one line changed: the boss-kind list);
`ContentCompiler.BOSS_KINDS` now points at `BossKinds.ALL` (the same table in its own file, with the Shade), so
`content_compiler.gd` is 987 lines. The Shade's compile and validation live in `ShadeCompiler` and `ShadeRules`.

**Sounds and credits.** `python -I scripts/audio/generate_sfx.py` (the venv): "128 files, 13930174 bytes, generator
v2"; six files not ours came out different (barrel_blast, barrel_fuse, bomb_throw, container_break, pillar_turn,
wall_break) and were restored from git; the manifest was restored and only our three rows added. `godot --headless
--path . -s scripts/content/build_credits.gd`: "wrote res://data/credits/licences.tres (5 entries)".

## 12. Tests (NB4)
Lint: `gdformat --check` / `gdlint` on every changed or new .gd file: no problems (`content_compiler.gd` and
`boss_ai.gd` pass the 1000-line rule).

Each run: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>` (own APPDATA, one
Godot at a time).

| run | files | result |
|---|---|---|
| the Shade's sim | tests/unit/sim/test_lantern_shade.gd | 16/16, 119 asserts (the data, bad numbers, four lanterns at the walls' middles and the room lit before Lights Out, shielded while the light drains and the dark falling 240 ticks after its start with every lantern lit afresh, the 3.5 m circle and 3.0 m lantern pools, a lantern burning out in 6 s and relit by passing, hittable only when lit (blocked in the dark with TAG_BLOCKED, the bar invulnerable; lit by the hero's light or a lit lantern: hit), the Snuff putting out the lantern nearest its strike and its marker drawn in the dark, the marker the same lit or dark, every 12 s and never by the pick, the phases opening with Lights Out, determinism and a mid-dark save, an older save, no light state without a Shade, the room relighting with the Shade gone, the death lines) |
| boss sims, saves, arch | test_lantern_shade, test_clockwork_judge, test_tidecaller, test_twin_wardens, test_bosses, _2, test_boss_gates, test_boss_pace, test_final_boss, test_boss_fights, _2, _3, test_boss_signatures, _2, test_world_snapshot, test_state_hasher, test_old_saves, test_layering, test_sim_purity | 235/237, 81,760 asserts, 1193.4 s: the two reds were counts this step changes (big attacks 14 → 15; the compiled boss order now ends with the Shade); fixed, those two files: 26/26 |
| views | test_lantern_shade_views, test_attack_visuals, _2, test_audio_director, test_boss_animations, test_boss_challenge_parity, test_boss_challenge_views, test_boss_fight_views, test_boss_fights_2_views, test_boss_models, _2, test_boss_rigs, test_boss_signature_views, _2, test_boss_telegraph_parity, test_boss_views, test_bosses_2_views, test_codex_view, test_enemy_fireball_views, test_final_boss_views, test_telegraph_parity, test_tidecaller_views, test_twin_warden_views, test_clockwork_judge_views, test_vx_looks | 206/207, 44,222 asserts, 502.3 s: "shade_wisp: a bright core" (luminance 0.449 < 0.55); recoloured, the colour files (test_boss_fight_views, _3, test_enemy_fireball_views, test_vx_looks, test_gun_pulse, test_lantern_shade_views): 53/53 |
| content, debug, arch | tests/content, tests/unit/debug, tests/arch | 175/175, 28,606 asserts |
| e2e | test_e2e_lantern_shade, test_e2e_clockwork_judge, test_e2e_bosses, test_e2e_bosses_2, test_e2e_run_flow, test_e2e_old_save, test_e2e_tidecaller, test_e2e_twin_wardens | 12/12, 193 asserts, 208.1 s |

The e2e: a floor-5 save (seed 1: floor 5 now draws the Shade; the Judge's e2e moves to seed 2, which draws the Judge)
continued with Enter, God clicked, E opens the door, the stick walks in, the door seals, the owner's model rises named
"The Lantern Shade"; the stick circles; Lights Out comes, shielded; the room goes dark (ShadeViews' dark at full,
four lanterns); the stick waits out a lantern's burn, walks to the nearest out lantern and relights it by passing;
then walks to the Shade, which stands in the hero's light, and the mouse's attacks land.

Not run here (GitHub's shards): the rest of the suite.

## 13. Shot (NB4)
`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/nb_lantern_shade.gd` (written to build/,
copied by hand):
- [`nb_shots/5_lantern_shade_dark.jpg`](nb_shots/5_lantern_shade_dark.jpg): the dark on the Ruins stage; the script
  printed: "tick 384 dark true lamps left [0, 0, 218, 218] boss lit true dark strength 1.0 lights 3 wisps outlined 5
  telegraph marks hero hp lost 0". Two lanterns lit with their warm pools and burn rings, two out (dashed rings), the
  hero's cool-rimmed circle, a Wisp Bloom with the wisps near the hero outlined, the Snuff's circle on the hero, the
  Shade at a lantern's pool edge with its held lantern glowing. Looked at and fixed: the first renders read flat
  (only dimmed: the light circles never reached the shader, and an alpha blend over the HDR floor stayed brown); the
  dark became a multiply night with mist, the stage's sun dims with it, the hero's light brightened.

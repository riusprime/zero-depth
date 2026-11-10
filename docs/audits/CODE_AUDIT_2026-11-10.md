# Code audit — Zero Depth, 2026-11-10

Branch `claude/v0110` at `c339458a`. Read-only: no file in the repo was changed, no Godot run, no test run.

## 1. Verdict

The architecture is sound and should stay. The layer rules hold, the sim is typed and deterministic, the hot data
is in packed columns, and the hitch work (shader warm-up, pooling, loading cover) is real engineering. This is not
a rewrite candidate.

What a senior dev would change falls into five groups, in order of value:

1. **Tests are slow because of fixed costs, not test count.** Every e2e test boots the whole game and walks the hub
   (about 20 s each), and sim tests regenerate the same floors and recompile all content per seed. This is the
   biggest drag on every step.
2. **A few structural costs scale with the fight.** Each enemy is still a stack of nodes with its own `_process`;
   each projectile searches its card's table every tick; each hit and each random draw allocates small objects.
3. **Code that can no longer run is still threaded through everything.** Old-save compatibility (about 1,000 lines
   plus 84 tests), four HUD styles the game can't select, the switched-off outline (411 references), and X-ray's
   `technique` parameter (122 references, read nowhere).
4. **The 1000-line lint cap shapes the code instead of the design.** Six files sit at exactly 999 or 1000 lines, ten
   switch the cap off, and at least 19 comments say a file exists only to stay under it.
5. **Comments record history, not intent.** About a quarter of all comment lines in `src/` cite a version, a step,
   an owner quote or a question number. Git already holds that.

Exact copy-paste is rare (under 1% of `src/`), there are no dead signals, and typing is essentially complete. The
"slop" here is accumulation, not carelessness: each step added, almost none removed.

## 2. How this was done, and its limits

- Four auditors each read one area (sim; 3D view and camera; UI, app, application and content; tests, scripts, CI
  and repo), following the real per-tick and per-frame paths. I ran repo-wide mechanical scans (unreferenced
  functions, constants, signals, scripts; identical function bodies; comment and typing statistics) and then checked
  the main claims of each auditor against the code myself. Rows marked **✔** in the tables are ones I re-checked.
- **Correction, 2026-11-10 (same day, after the first measurements):** three findings below overestimated their
  cost. T1: a boot plus the hub walk and arrival is under 2 s a test, not about 20 s. T5: the 9,000–18,000-frame
  numbers are limits the tests never reach. U3: the per-floor content load and compile is under 100 ms. The
  measurements, and the cost they found instead (a floor's walls and paths built two or three times per floor
  build), are in [`../roadmap/v0.11.1/evidence/E2E_FIXED_COST.md`](../roadmap/v0.11.1/evidence/E2E_FIXED_COST.md).
- **Nothing was profiled.** Every performance finding is a reading of the code. Costs in milliseconds are not
  known, except where the code's own comments quote an earlier measurement (those are cited as such). Before any
  performance item is built, measure it on the owner's PC with the existing `--perf-log` and `PerfMarks` buckets.
- "Unused" means a whole-word search over `src/`, `tests/`, `scripts/`, `data/` and all `.tscn`/`.tres` files found
  only the definition. Names built at run time (`call("…")`, `tr("PREFIX_" + id)`) were looked for and excluded, but
  a name built in a way the scan didn't recognise could be a false positive. Each deletion should be confirmed by
  lint plus the folder's tests.
- Effort: **S** = hours, **M** = one or two PLAN steps, **L** = several steps. "Goldens" says whether the change
  alters golden hashes.

## 3. The codebase in numbers

| Area | `.gd` files | Lines | Note |
|---|---|---|---|
| `src/` | 889 | 207,098 | non-blank lines: sim 59k, presentation 99k |
| `tests/` | 683 | 131,736 | 4,658 `func test_` |
| `scripts/` | 262 | 50,747 | `scripts/shots` alone is 35,219 |
| `data/` | 599 `.tres` | — | |
| `docs/` | 1,171 files | — | 335 MB, almost all evidence images |

| Measure (in `src/`) | Value |
|---|---|
| Functions checked | 10,105 |
| Public functions referenced nowhere | 48 |
| Public functions referenced only by tests | 322 |
| Public functions referenced only by `scripts/` | 60 |
| Constants unused by the game (of 6,260; 42 of them still read by tests or scripts) | 78 |
| Signals unused (of 84) | 0 |
| Scripts never referenced | 1 (`final_stub_clips.gd`) |
| Classes used only by tests or scripts | 4 |
| Lines inside exact 12-line duplicates across files | 1,321 |
| Untyped variables | 2 |
| Comment lines / of them citing history | 27,651 / 6,782 (25%) |
| Lint switch-offs (`gdlint: disable`) | 23, ten of them `max-file-lines` |
| Functions over 120 lines | 24 |

## 4. Game performance

### 4.1 Frame time: the 3D view

| ID | What | Where | Fix | Effort | Risk |
|---|---|---|---|---|---|
| V1 ✔ | **Every regular enemy is a node stack with its own `_process`**, even on the VAT path: root, facing node, avatar, bar quad, disc and ring. The MultiMesh only replaces the body. `critter_crowd.gd` already does it without a node per enemy, and its header quotes the measured cost it removed: about 40 µs per node-enemy per frame. Only critters use it. | `vat_crowd.gd:3-8`, `actor_views.gd:832-870`, `avatar_base.gd:82-89`, `critter_crowd.gd:3-6` | Move every VAT kind onto the CritterCrowd model, kind by kind, behind the existing `enemy_vat` switch: pose state in per-slot packed arrays, each avatar's pose code a static function. | L | Medium to high: flinch and rise-in must feel the same (owner check) |
| V2 ✔ | **Each enemy spawn builds 3 meshes and 3 unique materials** (contact disc, team ring, HP bar). N enemies means 3N materials and 3 extra draws each, built mid-fight. | `actor_views.gd:659, 672, 894` and `_unshaded` at `:563` | One shared unit disc, ring and quad, scaled; one material per team. Or draw them in the crowd MultiMesh, as CritterCrowd already does for bars. | S | Low |
| V3 ✔ | **The VAT write loop does dynamic `call()`s and allocations per enemy per frame**: `avatar.call(&"vat_lift")`, `avatar.call(&"glow_energy")`, a new `PackedFloat32Array` per enemy for its drives, and for rigs with more than 4 drives a new `Image` every frame. | `vat_crowd.gd:227, 243`, `vat_bake.gd:650-663, 744` | Typed virtual methods on `AvatarBase` that write into the caller's buffer; one reused `Image`. | S–M | Low |
| V4 | Per actor per frame: `get_meta(&"enemy_avatar")` re-read although the record already caches it, `set_process(on)` called without a change check, and the actor record is an untyped Array with magic indices 0–8. | `actor_views.gd:243, 252` | A typed record class; call `set_process` only on change. | S | Low |
| V5 | **Three band-aids that run globally.** `EmptyDrawCull` calls the RenderingServer for every watched pool every frame, changed or not. `ParticleShadowOff` hooks `node_added` for the whole tree and fires again each time a pooled effect is re-added. Ten pools set a 16 km cull margin, which puts them in every pass. | `empty_draw_cull.gd:84-95`, `particle_shadow_off.gd:22,47`, 10 × `extra_cull_margin = 16384` | Pools toggle their own visibility when their count crosses zero; shadows off once in `PackFx._make`; a room-sized bounding box. | S | Low |
| V6 | `PackFx` keeps live effects in an Array of Dictionaries and scans it linearly on release, on "oldest", and on animation end; pooled instances leave and re-enter the tree. At the caps (about 400 in total) one spawn costs two scans. | `vfx/pack_fx.gd:316-345, 462-472, 514-583` | Per-family ring buffers and a node→slot map; keep idle instances in the tree, hidden. | S–M | Low |
| V7 | **All 55 view parts are built and synced in every room**, including 14 boss-only views, many with their own `_process`. | `world_view_root.gd:18-75, 709-790` | Build views from what the room has; `set_process(false)` while a view is empty. | M | Medium |
| V8 | `VfxCore` makes 3 RenderingServer calls and about 4 Dictionary lookups per sprite, up to 2,000 sprites a frame. | `vfx/vfx_core.gd:480-502` | One packed buffer per pool, written once in `finish()`. | S–M | Low |
| V9 | 58 places duplicate a material per instance just to fade or tint it; only 9 use per-instance shader parameters. Each unique material is its own draw. | e.g. `spell_fx.gd:123`, `dash_trail.gd:108`, `pack_fx.gd:531` | Instance uniforms or vertex-colour alpha on shared materials. | M | Low |
| V10 | Every shader is an inline string: 80 `Shader.new()`, no `.gdshader` file in `src/`. 29 carry the identical additive `render_mode` line. | 50 files | `.gdshader` files with a shared `.gdshaderinc`; collapse the additive sprites into a few shaders. Fewer pipelines to warm. | M | Low |

### 4.2 Tick time: the sim

None of these change results unless marked.

| ID | What | Where | Fix | Effort | Goldens |
|---|---|---|---|---|---|
| S1 ✔ | **Every projectile searches its card's row table every tick.** `row_of` is a linear scan, copied in 5 files, called from 25 sites; the steer path calls several per projectile. Cost grows with projectiles × rows: the worst case is exactly the bullet-heavy build in a horde. | `glaive_mods.gd:259`, also `seeker_`, `void_`, `lance_`, `wave_mods.gd` | Store the row index in a `ProjectileStore` column at spawn and fix it on removal. | M | No |
| S2 | **One landed hit allocates 3–7 small Arrays and 2 event objects.** 84 sim functions return two-element Arrays as tuples; a boss hit rebuilds the multiplier tuple 2–3 times. | `damage.gd:74-160`, `matchups.gd:31`, `stats.gd:355` | Return an int and write tags to a scratch field (the pattern `last_hit_crit` already uses). | M | No |
| S3 ✔ | **`SimEvent.ancestry` is copied onto every hit event and nothing in `src/` reads it.** Only two test files do. | `sim_event.gd:156`; written at `damage.gd:133` and 7 more sites | Drop the field, or fill it under a debug flag. | S | No |
| S4 ✔ | **Each random draw allocates one or two `RngStep` objects** (235 call sites). | `rng_stream.gd:17-43`, `deterministic_rng.gd:40-92` | Inline the xorshift into `RngStream`; return an int. | S | No |
| S5 ✔ | A surge re-counts every live enemy before each spawn in its loop. | `surges.gd:69` | Count once, add locally. | S | No |
| S6 | The actor's kind is classified three times per tick in three loops, with Dictionary lookups and an `in [...]` test; `behaviour_of` does two Dictionary lookups and is called several times per enemy per tick. | `world.gd:904-910, 1780-1789, 1907-1943`, `enemy_ai.gd:123-126` | Per-kind lookup arrays built once when the tables are set. | S | No |
| S7 | The nine card files each copy `param(w, key)`, a string-keyed double Dictionary lookup, called at 235 sites, some per projectile per tick. | `bomb_`, `glaive_`, `lance_`, `laser_`, `rune_`, `seeker_`, `void_`, `wave_`, `wisp_mods.gd` | Compile card parameters into typed fields once per build. | S–M | No |
| S8 | The Laser's beams are Dictionaries with string keys (91 string-key accesses on the fire path). | `laser.gd:108-194`, `laser_mods.gd` | A small typed `Beam` class. | M | Check |
| S9 | Removing a projectile does about 30 `remove_at` calls, each shifting the whole column. | `projectile_store.gd` `remove_sorted` | One compaction pass per column. | S | No |

A correction to one auditor claim: `actor_store.gd:217-226` adds an actor by `get(f)` → `append` → `set(f)` over 47
columns, under a comment saying "Packed arrays are values: get() returns a copy". That was true in Godot 3. In
Godot 4 packed arrays are shared references, so this probably does not copy every column; the real cost is 94
reflective property calls per spawn, and the `set` is likely redundant. `vat_crowd.gd` carries the same belief in a
comment. Worth a five-line probe, then direct appends as `ProjectileStore` already does. Low value either way.

### 4.3 HUD, audio and loading

| ID | What | Where | Fix | Effort |
|---|---|---|---|---|
| U1 | **Five HUD widgets redraw every frame whether or not anything changed** (HP/mana bars, danger meter, ability squares, spell squares, heat meter). Their `_draw` repaints shapes and serif text. | `hud_bar.gd:31-36`, `danger_meter.gd:106-112`, `ability_squares.gd`, `spell_squares.gd`, `heat_meter.gd` | Compare with the last drawn state, as `minimap_view.gd:128-148` already does. | S |
| U2 | Boss bar and kit HUD call `tr()` and build strings every frame; `build_card` redraws every frame while idle. | `boss_bar.gd` sync, `kit_hud.gd` sync, `build_card.gd:106-110` | Reuse `Hud._changed()`. | S |
| U3 ✔ | **Content is loaded and compiled per floor, not per session.** `ContentRepository.load_all()` (a directory walk plus a `load()` of every `.tres`) has 10 call sites in `src/`, including every run start and every floor; each floor then runs about 40 compiler calls from scratch. | `content_repository.gd:28`, `floor_plan.gd:117-119` and `:147-216`, `main.gd:230, 292, 320, 869, 1000` | One repository per process, invalidated only by a dev-panel edit. Cache the tables that don't depend on the floor. First confirm the sim never writes into a compiled table. | M |
| U4 | Code that only needs an enemy's kind runs the full 72-line enemy compile to read `.kind` (6 sites). | `content_compiler.gd:291, 318, 396, 419, 764`, `codex_catalog.gd:113` | A one-line kind lookup. | S |
| U5 ✔ | Content validation runs in every build, release included, at the first load. CI already proves the shipped content has no errors. | `content_repository.gd:44-46` | Debug builds only. | S |
| U6 | Every sound creates a new player node and frees it; the bus volume is written every frame; `AudioEvents.collect` polls 22 subsystems per tick by comparing state. | `audio_director.gd:144-156, 196-220`, `audio_events.gd:196-219` | A small pool of players; write volume on change; drive cues from the sim's event log where one exists. | M |

## 5. Code that can no longer run

| ID | What | Size | Fix | Needs the owner? |
|---|---|---|---|---|
| D1 | **Old-save compatibility.** Sim: `world_snapshot.gd:194-736` (a 540-line list of fields added since v0.5), the padding and migration branches, `wand_migration.gd` (143 lines), and 12 size guards on projectile columns. App: `run_saver.gd` reads payload versions 2, 3 and 4; `card_order.gd` (359 lines of frozen orders); legacy branches in `floor_scenario.gd`, `floor_plan.gd`, `event_compiler.gd`, `profile_store.gd`; `user_dir_migration.gd`. Tests: 84 test functions and `test_wand_migration.gd` (455 lines, in the heavy shard). | About 300 references in 50 files outside the sim, about 700 lines inside it | Bump the save format, reject older saves, delete the branches and their tests together. | **Yes.** The owner said on 2026-11-05 that old saves don't matter, but "old saves" is still a named seam in `CLAUDE.md`. `CardOrder`'s frozen order also keeps goldens stable: removing it is a named golden change. |
| D2 ✔ | **Four HUD styles the game cannot select.** `HudStyle.current` defaults to ASTRAL and is assigned only in two test files and one shot script. Every LINE, BARE, SLATE and EMBER branch is unreachable: 32 branch sites in 13 files. | 32 branches + tests + shots | Delete the four styles. | The menus are a separate case: 4 menu panels use Astral and 4 still use Ember. That looks like drift; the owner should say which. |
| D3 ✔ | **The outline and X-ray plumbing.** `ActorLooks.OUTLINES` is a constant `false`; the `technique` parameter is passed through about 30 functions and compared nowhere. | 411 `outline` and 122 `technique` references in `world_view/` | Delete both, keeping `outline_color` only where it colours the contact disc. | No |
| D4 ✔ | **Six `World` fields that are never written**, only declared and hashed: `plasma_tick`, `plasma_from`, `plasma_to`, `resonance_tick`, `shrapnel_tick`, `bastion_tick`. | 6 fields | Delete. Changes goldens, so batch it with another planned golden change. | No |
| D5 ✔ | **48 public functions referenced nowhere.** 21 are in `world_reader.gd`; the rest are single getters across the view and HUD. Full list in Appendix A. | 48 functions | Delete. | No |
| D6 | **78 constants the game never reads**, 43 of them in `src/sim/world` (mostly `world_reader.gd` re-exports). 36 are read by nothing; 42 only by tests or scripts. | 78 | Delete the 36; move or drop the 42 with their tests. | No |
| D7 | **Test and bot code inside the shipped game.** `FightBot`, `KernelScenario` and `ScriptedInput` live in the pure sim; `StageScenario`, `ComboCard` and the Combat Lab encounter are used only by tests; the VAT bake verifier (`vat_bake.gd:567-830` plus `vat_sample` in 10 avatars, about 430 lines) runs only from tests. | About 700 lines | Move to `tests/support`. | No |
| D8 | `AimAssist` (22 lines) is never wired into input, though the docs record it as an owner decision. | — | Either wire it or remove it. | **Yes**: this is a missing feature, not just dead code. |
| D9 | 25 translation keys used nowhere (retired boss-attack causes, old volume labels, old HUD words); 7 more only in tests. Listed in Appendix B. | 32 keys | Delete. | No |
| D10 | 6 exported content fields no code reads: `BiomeDefinition.hazard_flavour`, `template_tags`, `EncounterDefinition.max_floor`, `threat_cost`, `EnemyDefinition.stress_tags` (set in 34 files), `WaveSpawn.spawn_slot_tag`. | 6 fields + their `.tres` values | Delete. | No |
| D11 ✔ | `data/patch_notes` (7 files) is loaded by every `load_all`, and nothing in `src/` reads it; only the docs build script does. | 7 files | Keep it out of `res://data`, or build the in-game panel its header promises. | Small |
| D12 | `boss_anim/final_stub_clips.gd` (its header says "No longer used") and `procedural_wall.gd`'s `legacy_look` (used only by one shot script). | 87 lines + 7 branches | Delete. | No |

**322 public functions exist only for tests** (190 in the 3D view, 60 in the HUD, 23 in `src/sim/world`): counters
such as `warning_count`, `fire_count`, `cross_drawn`. Some test surface is healthy. This much means the tests assert
how the code works inside rather than what the player gets, which is why they break on refactors. No bulk fix; stop
adding them, and remove each as its test is next touched.

## 6. Redundancy

| ID | What | Where | Fix | Effort |
|---|---|---|---|---|
| R1 | **Seven hand-written row tables in one class**, each 10–16 parallel columns with its own clear, touched flag, remove and hash block. `hash_into` alone is 218 lines. | `modifier_state.gd` (800 lines, 201 variables) | One `RowTable` class with a declared column list. Hash order kept, so no golden change. | M |
| R2 | The nine card files repeat `param`, `cull`, `_ring`, `add_echo`, `read_rings`, `note_card`: 10 groups, about 194 duplicated lines. | `src/sim/combat/*_mods.gd` | One `CardParams` (see S7). | S–M |
| R3 | **The owner-model enemy avatars share a copy-pasted skeleton.** `_build_model` is the same 33-line block in 6 files; `vat_lift`, `vat_drives`, `glow_energy`, `attach` are near-identical in 5–10; the same hash constant appears 12 times. `BossAvatar` re-implements `hold`, `flinch` and gait from `AvatarBase` instead of extending it. | 32 `*_avatar.gd`, 14,605 lines | An `OwnerModelAvatar` base driven by a part table; subclasses keep only pose and clips. Estimated cut about 1,500 lines (auditor's estimate, not measured). | M–L |
| R4 | MultiMesh pool setup is written out 30 times; two copies are line-for-line the same. The "collect live ids, then sweep" sync pattern is in 26 views. | `boss_strike_views.gd:141-162` = `vfx/vfx_core.gd:225-240`, 25 files | One pool helper and one reconcile helper. | M |
| R5 | **About half of the compiler code is same-name field copying**: 544 of 1,107 assignments are `t.x = def.x`. | `src/application/*compiler*.gd` (21 files, 3,542 lines) | A helper that copies same-named properties, plus a small table for the unit conversions. Estimated cut 600–900 lines (auditor's estimate). Hashes must stay identical. | M |
| R6 | The icon-shape helpers (`_line`, `_loop`, `_poly`, `_circle`) are copied in 5 files, three byte-identical. 221 colour literals, 160 unique, with the same Astral colours redefined in 3–5 files. | `ability_icons.gd`, `card_pool_icons.gd`, `item_icons.gd`, `gamble_icons.gd`, `codex_glyphs.gd` | One `IconShapes`, one Astral palette. | S–M |
| R7 | Every sim state class hand-lists its fields in `hash_into` (66 bodies, about 970 lines), each guarded "so worlds without X hash as before". The snapshot already walks fields by reflection. | `world.gd:1483-1668` and 66 files | One reflective hasher, then regenerate all goldens once. It also closes the risk of a new field silently missing from the hash. | L, **changes every golden** |

## 7. Structure and style

| ID | What | Evidence | Suggestion |
|---|---|---|---|
| A1 ✔ | **The 1000-line cap is being gamed.** | `main.gd`, `stage_view.gd`, `procedural_wall.gd`, `attack_form_canvas.gd`, `boss_ai.gd` are exactly 1000 lines; `player_avatar.gd` is 999. Ten files disable the cap (4,656 down to 940 lines; `hud.gd`'s switch-off is stale). 19 comments say a file was split to fit, for example `charger_vat.gd:6` and `training_flow.gd:8`. `boss_ai.gd` keeps one-line wrappers that exist because the body was moved out "for this file's length". | Split by responsibility, not by line count. After D1, D3 and R1–R3 most of the pressure goes away. Then either enforce the cap everywhere or raise it; today it is neither. |
| A2 | **`main.gd` is a god object**: boot, settings, menus, hub, run and floor lifecycle, pause, dev panels, playground, training, saves and input routing. Its overflow files (`meta_hooks.gd`, `training_flow.gd`) take `main: Main` and reach into its fields. | 79 functions, 40 variables | Extract a run controller, a pause controller and the dev hooks. `Main` keeps boot and screen routing. Effort L. |
| A3 | **`World` is a 334-field bag.** Older features have state objects; newer ones flatten onto `World` (36 `spell_*` fields, 11 `starbound_*`, 10 `gamble_*`). | `world.gd:1-622` | Group into state objects. The snapshot is reflective, so the cost is small. Changes hash order. |
| A4 | **`WorldReader` is 4,656 lines, 712 functions and 346 re-exported constants.** 482 functions are four lines or fewer and forward one call. It is a facade by design. | `world_reader.gd` | The design is the owner's (ARCHITECTURE). The cheap part is D5 and D6. Letting the view name the sim's enums directly would remove the 346 constants, but that changes a ranked rule. |
| A5 ✔ | **History in comments.** | Lines carrying a version tag: sim 3,819, 3D view 2,596, rest of `src/` 2,796, tests 2,170. In my scan 25% of all comment lines in `src/` cite a version, step, owner quote or question number. 97 comments say "hashes as before". | One mechanical sweep: remove the tags and keep the sentences that explain why. Add a comment rule to `CLAUDE.md`: say what and why, not which step. |
| A6 | Untyped tuples with magic indices on hot paths. | A pending projectile is a 16-slot Array (`p[9]`, `[-1][14]`) at `world.gd:688-762`; the actor record in `actor_views.gd` is `parts[0..8]`. | Small typed classes. |
| A7 | 24 functions over 120 lines. | `astral_ui.band` 265, `astral_chrome.veil` 238, `actor_views._make_actor` 229, `modifier_state.hash_into` 219, `world._move_and_collide` 196, `world.state_hash` 190, `world.step` 186, `world_view_root.sync` 171 | Split along the phases they already contain. |
| A8 | Debug tooling ships switched on: `DevGate.enabled()` defaults to true and no export preset sets the `public_release` feature. | `dev_gate.gd:5-7` | By design for now; the release checklist must set the tag. |

## 8. Tests, scripts and CI

The seams run took 3,131 s for 667 tests on the owner's PC: 4.7 s per test.

| ID | What | Evidence | Fix | Effort |
|---|---|---|---|---|
| T1 ✔ | **Every e2e test boots the game and walks the hub.** | 231 boots and 168 run starts over 144 e2e files; no e2e file uses `before_all`. A local GUT log shows 5 such tests taking 113.9 s. | Boot once per file; add a test-only switch on `Main` (like `Main.fixed_seed`) that skips the hub walk and the 4 s arrival everywhere except the hub and arrival tests. | M. **Owner call**: it touches the "input only" e2e rule. |
| T2 ✔ | **`seams.sh` runs whole heavy files to check one seam each.** | `test_modifier_smoke.gd` is on `gut_shard.sh`'s own list of the heaviest files; `test_five_floors.gd` is there for one roster test but also generates 5,000 floors; `test_final_pace.gd` runs four full bot fights. | Run only the named test (`-gunit_test_name`), or split the heavy cases into files that stay on GitHub. Add the JUnit timing output `gut_shard.sh` already uses, so the next cut is measured. | S |
| T3 | **13 sim test files each generate 1,000 floors** through their own copy of the layout pipeline; two generate the identical floors. | `SEEDS := 1000` in 13 files; `test_elite_rooms.gd:61` and `test_lockdowns.gd:75` share the seed formula. Local log: the curse-room trio took 958.6 s. | A shared, cached floor corpus in `tests/support`. | M. Fewer seeds per PR is an **owner call**. |
| T4 | Content is recompiled inside per-seed loops; the test floor builder rescans and recompiles everything on each of 263 calls. | `test_five_floors.gd:152`; `tests/support/save_lab.gd:50-69` | Hoist into `before_all`; memoize in support. | S–M |
| T5 | e2e tests wait 9,000–18,000 rendered frames for a boss to roll a move. | `test_e2e_boss_signatures.gd:75, 104, 133` and five more files | Assert the pattern in the sim (`BossLab.start` can force an attack); keep a short e2e that proves the summon reaches the game. | M |
| T6 ✔ | A test that became a duplicate: `ABILITY_MODS` is now `[]`, so one modifier smoke test repeats another on a subset. | `test_modifier_smoke.gd:19, 168-178` | Delete it. | S |
| T7 | Copy-pasted twins and per-step files never merged. | Ice vs. starglow 1,000-seed tests are the same code; 21 files carry step suffixes (`_2`, `_3`, `_mx4`, `_o11`), for example three `boss_dodge` files with one test each. | Parameterize and merge. With T1 this also shares one boot. | M |
| T8 | At least 193 asserts pin a tuning number to a literal (`assert_eq(table.hp, 1750)`). They fail on every balance change and catch no bug. | e.g. `test_curse_room.gd:54` | Assert relations and ranges. | M |
| T9 | Helpers copied into test files instead of support: `_click` 81 copies, `_walk` 27, `_focused` 16, `_take_at_altar` 11. | e2e files | Add them to `tests/support/e2e.gd`. | S |
| T10 | 37 e2e files write into the sim (`w.shards = 10000`), against the e2e header's own rule. | 69 assignments | Use dev-panel actions, or state the exception. | M |
| T11 ✔ | The test-count floor is stale: `MIN_TEST_COUNT` is 3,292 and there are 4,658 tests. Losing 1,300 tests would pass the guard. | `tests/MIN_TEST_COUNT` | Raise it from the next green `verify`. | S |
| T12 | **`scripts/shots` is mostly one-off scripts.** | 193 `.gd` files, 35,219 lines; CI uses two (`galleries.gd`, `tour.gd`). 131 files (20,786 lines) are referenced by no code; 26 of those (4,131 lines) not even by docs. Three mock-UI generations coexist. | Delete the 26; tag the repo and delete the other 105; keep a short README of live tools. Lint gets faster too. | S |
| T13 | `scripts/checks`: about 5 of 44 are wired into CI; 3 are referenced nowhere (`shard_taper.gd`, `surge_probe.gd`, `pairing_counts.gd`). | 9,883 lines | Delete the 3; retire docs-only probes after their version ships. | S |
| T14 ✔ | CI: 7 jobs each run a cold asset import; there is no cache. The six test shards don't wait for lint, so a format error still burns all six. | `.github/workflows/verify.yml` | Cache `.godot/imported`, keyed on the assets; make the shards depend on a small lint job. | S |

## 9. Repo hygiene

| ID | What | Fix |
|---|---|---|
| H1 | The repo pack is 1.10 GiB with no LFS. `unprocessed_images/` holds 616 MB of tracked raw models and images; `docs/` holds 335 MB of evidence images. | Move raw art out (a release asset or LFS); put new evidence images in LFS. Shrinking history needs a rewrite: **owner call**. |
| H2 ✔ | One 9.2 MB boss texture is stored three times, byte-identical (colossus, prism, nemesis). | Point the three materials at one file. |
| H3 | `art_raw/` (32 MB, with `.import` files, no `.gdignore`) is not in the export exclude filter, so a local export probably ships it. Not confirmed by an export. | Add a `.gdignore` and extend `exclude_filter`. |
| H4 ✔ | 21 untracked `.uid` files whose scripts are tracked; a 0-byte `PLAN.md.tmp`; `newVFX/` with 14 MB of zips. | Commit the uids, delete the tmp file, ignore or remove `newVFX/`. |
| H5 | 144 of 265 scenes under `assets/` are referenced by nothing (unused effects from the VFX packs). They are small, but they are imported and exported. | Prune the packs to the effects in use once PD-13's choices settle. |

## 10. One likely bug

**The wall-fade index never rebuilds on a wall change.** `world_view_root.gd:856` compares the index's `count` with
`_occ_specs.size()`, the same array the index was built from, so the check cannot fail. Only a camera pitch change
rebuilds it. If the cracked slab's spec appears after the first sync, or the stage's walls change mid-floor, the new
wall never fades. No visible symptom was confirmed; the fix is to compare against `stage.wall_specs.size()` plus the
slab.

Two smaller leads, not verified: `camera/iso_rig.gd:76` smooths with `delta * smoothing`, which behaves differently
at different frame rates; and a VAT mesh for an enemy tint that was not warmed may be baked mid-fight
(`vat_bake.gd:341-369`).

## 11. What is good and should not be touched

- The sim's packed-column stores with sorted ids and binary-search lookup; the dense grid; the nav flood sliced
  over ticks.
- Determinism hygiene: sorted Dictionary iteration, named RNG streams, a trig table. The purity rules held
  everywhere the auditors read.
- The snapshot's reflective field walk, which errors on an unknown class.
- `RunSaveStore`: compressed, checksummed, atomic, off the main thread, saved on room entry and never per tick.
- `CritterCrowd`: the right model for drawing enemies. It should become the only one (V1).
- The shader warm-up, the loading cover with a worker thread, the pooled damage numbers, and the write-on-change
  checks already in many views.
- `MinimapView`'s cached layer and redraw-on-change.
- CI's guards: every test file is proven to be in exactly one shard, versions are pinned, and the Windows zip is
  audited for stray folders.
- Typing: effectively every variable and almost every function is typed.

## 12. Decisions that are the owner's

**Answered 2026-11-10.** The answers and the plan built from them are in
[`../roadmap/v0.11.1/PLAN.md`](../roadmap/v0.11.1/PLAN.md). The list below is kept as it was asked.

1. **Old saves (D1).** Reject saves from before the next version and delete the compatibility layer? This removes
   the "old saves" seam.
2. **Menus (D2).** Should the four Ember menu panels move to Astral?
3. **e2e start (T1).** May e2e tests skip the hub walk and arrival through a test-only switch?
4. **Seed counts (T3).** 200 seeds per PR and 1,000 at release, or 1,000 always?
5. **AimAssist (D8).** Wire it in or remove it?
6. **Line cap (A1).** Keep 1,000 and enforce it without exceptions, or raise it?
7. **Repo size (H1).** Move raw art to LFS, and rewrite history or not?
8. **Reflective hashing (R7) and `World` grouping (A3).** Both regenerate every golden. Worth one deliberate
   golden reset?

## 13. A suggested order

Each phase is safe to stop after.

1. **Make steps faster first** (T2, T4, T6, T11, T14, then T1 and T3 once decided). Everything after this is
   cheaper to verify.
2. **Delete what cannot run** (D2, D3, D5, D6, D7, D9, D10, D12, T12, T13, H2, H4). Mechanical, low risk, and it
   removes most of the line-cap pressure.
3. **Cheap performance wins** (V2, V3, V4, V5, S3, S4, S5, S6, U1, U2, U4, U5). Small local changes; measure before
   and after with `--perf-log`.
4. **Old saves** (D1), once decided, with the fields in D4 in the same golden change.
5. **Structural performance** (S1, S2, U3, V6, V7, then V1). V1 is the largest item in this report and the only one
   that changes how the horde scales; it needs the owner's feel check per enemy kind.
6. **Consolidation** (R1–R6, A2, A5) as the files are next touched, not as one big refactor.

## Appendix A — the 48 unreferenced functions

`src/sim/world/world_reader.gd`: `sniper_line` :915, `shard_drop_reach` :1171, `echo_pending` :1295, `final_dps`
:2353, `final_interphases_done` :2469, `approach_pylon_tick` :2513, `final_phase_tick` :2571, `pair_desc_key` :3019,
`gamble_fail_permille` :3176, `spell_aim` :3508, `interactable_count` :3915, `timed_door_slab` :3963,
`timed_ticks_left` :3988, `hidden_room_cells` :4029, `rune_door_depth` :4109, `purple_dais_entry` :4127,
`heart_take_tick` :4202, `relic_spent` :4221, `breakable_break_tick` :4320, `affinity_shocks` :4385,
`affinity_jumps` :4389.

Sim: `boss_nemesis.gd:419 cast_of`, `boss_twin.gd:198 roles_phase`, `void_shots.gd:66 aura_m`.

Application and content: `card_order.gd:328 ability_ids`, `collectible_book.gd:46 of_source`,
`room_layout_definition.gd:216 gap_between`.

HUD, menus, UI: `build_hud.gd:186 cut_slots`, `card_style.gd:63 is_plain`, `wand_row.gd:683 tile_box`,
`game_cursor.gd:163 set_context`.

3D view and camera: `iso_rig.gd:126 shake_to`, `ability_visuals.gd:74 bomb_count`, `arena_views.gd:129 veiled_rooms`
and `:137 veil_target`, `attack_form_looks.gd:139 bleed_core`, `spell_shapes.gd:102 strips_used` and `:106 orbs_used`,
`baked_mesh_pools.gd:55 shape_count`, `boss_clip.gd:145 target_names`, `boss_avatar.gd:808 bone_q`,
`element_visuals.gd:110 fire_count`, `hazard_views.gd:67 warning_count` and `:75 rubble_count`,
`portal_gate.gd:288 is_shown`, `prism_views.gd:189 cross_drawn` and `:232 shard_flash_drawn`,
`starfall_avatar.gd:197 reel_pose`.

`astral_button.gd:116 _toggled` was flagged by the scan and is not dead: it is an engine callback.

## Appendix B — unused translation keys

Used nowhere: `UI_VOLUME_MASTER`, `UI_VOLUME_EFFECTS`, `UI_VOLUME_AMBIENCE`, `UI_CHOOSE_UTILITY`, `HUD_DASH`,
`HUD_UTILITY`, `HUD_PICKED`, `HUD_BOSS_STAGGER`, `HUD_BOSS_STAGGERED`, `CAUSE_GATEKEEPER_QUAKE`,
`CAUSE_GATEKEEPER_CHARGE`, `CAUSE_WARLORD_JAVELINS`, `CAUSE_HIVE_SWEEP`, `CAUSE_HIVE_PRISM`, `CAUSE_FOUNDRY_SLAG`,
`REWARD_TOO_POOR`, `PICK_TITLE_LEGENDARY`, `ITEM_TRIGGER_ON_CRIT`, `ITEM_TRIGGER_ON_CRIT_DESC`, `UI_PAIR_LEVEL`,
`UI_PAIR_BIG`, `UI_CARD_SPELL`, `UI_SWAP_LEVEL`, `UI_CURSE_UPSIDE`, `UI_ABILITY_AUTO`.

Only in tests or scripts: `UI_VOLUME_MUSIC`, `GATE_NAME`, `HUD_PICKED_UP`, `CAUSE_SIEGE_BOLTS`, `UI_COMBO_UNLOCKED`,
`CAUSE_GATEKEEPER_PULL`, `UI_PAIR_ON`.

All 1,766 keys have both `en` and `es`; there are no duplicate keys.

## Appendix C — how to reproduce the scans

The scan scripts are not in the repo. They were run from a scratch folder against `git ls-files`: a whole-word
index of every `.gd`, `.tres`, `.tscn` and config file, then, for each `func`, `const`, `signal` and `class_name` in
`src/`, a count of references by area. Duplicates were found by hashing function bodies of six lines or more and
every 12-line window with whitespace and comments removed. Ask and they can be added under `scripts/checks/` as a
repeatable dead-code report.

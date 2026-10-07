# Locked decisions

## Authority

This file holds two kinds of decision, and they change in different ways.

- **Engineering invariants (EI)** keep the simulation deterministic, testable and shippable. Changing one needs:
  - evidence (a test, bench or sim result in a version's `evidence/` folder) showing why the invariant fails;
  - a migration plan for code, tests and goldens;
  - the owner's explicit approval;
  - a row in the change log below.
- **Product defaults (PD)** are what the game is today. The owner can flip any of them at any time, for any
  reason. The lead records each flip in the change log the same day, and updates every doc that cites the old
  value. A flip never needs evidence.

The split exists because Deathventory locked product choices as hard as engineering ones, then overturned them
within days ([`../LESSONS.md`](../LESSONS.md) L9). Here, product choices are expected to move.

Authority order for the whole repo is in [`../../CLAUDE.md`](../../CLAUDE.md). This file and
[`../design/GAME_BLUEPRINT.md`](../design/GAME_BLUEPRINT.md) share rank 2, right below the owner's written
instructions. If they disagree, stop and ask the owner; never pick one quietly.

---

## Engineering invariants

| ID | Invariant | Enforced by |
|---|---|---|
| EI-01 | **Pinned engine and test stack.** Godot `4.7.x` (the exact patch is pinned in both CI workflows and recorded in PROGRESS; `project.godot`'s `config/features` says `4.7`) and GUT `9.7.1`, vendored in `addons/gut/`. CI prints `godot --version` and fails if it doesn't match the pin. | CI `verify` and `windows` jobs; [`TEST_MATRIX.md`](TEST_MATRIX.md) T-CI |
| EI-02 | **Pure sim.** Everything under `src/sim/` is GDScript `RefCounted` code. It never uses Nodes, the scene tree, signals to presentation, Godot physics, `Input`, `OS`, `Time`, `Engine`, `load()`/`preload()` of content, `randf`/`randi`/`RandomNumberGenerator`, or trig/transcendental functions (`sin`, `cos`, `tan`, `atan2`, `pow`, `exp`, `log`). | Arch-lint test `tests/arch/test_sim_purity.gd` ([`ARCHITECTURE.md`](ARCHITECTURE.md) §3) |
| EI-03 | **One gameplay clock.** The sim advances in fixed ticks at 60 Hz. `World.tick` is the only gameplay clock. Content is authored in seconds and converted to whole ticks once, when content is compiled. Presentation never owns gameplay time: no `Timer`, tween or animation decides an outcome. | [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §2; hitch test (`tests/unit/sim/test_hitch_rules.gd`) |
| EI-04 | **Input is a per-tick frame.** Player input reaches the sim only as one quantized `InputFrame` per tick. A replay is (sim version, content hash, seed, loadout, `InputFrame` log), and nothing else. | [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §3; replay golden |
| EI-05 | **Named RNG streams.** Gameplay randomness comes only from the named streams `map`, `loot`, `combat` and `ai`, each a seeded `RngStream`. The `cosmetic` stream exists only in presentation and never feeds the sim. | [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §5; arch lint |
| EI-06 | **Provenance and bounded chains.** Every damage, heal, barrier and status event carries provenance (`root_id`, `parent_seq`, `depth`, `ancestry`, `proc_pct`). Each item effect activates at most once per root chain. Damage-over-time ticks never proc on-hit effects. A death resolves exactly once. A watchdog caps chain depth and event counts, emits a `LIMIT` event when hit, and tests and sims fail on any `LIMIT`. | [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §7–§8; chain tests; fuzz test |
| EI-07 | **Presentation is read-only.** Presentation reads `World` snapshots and the event log and never writes sim state. Every forecast (damage numbers, telegraph areas, previews) calls the same sim function that resolves the real outcome. | Arch lint: presentation may reference the read-only `WorldReader`, never `World` ([`ARCHITECTURE.md`](ARCHITECTURE.md) §3); forecast-parity tests |
| EI-08 | **Typed, validated, export-safe content.** Content is typed `.tres` Resources with a `validate()` method, checked at load. Discovery goes through one `ContentScanner` built on `ResourceLoader.list_directory`, which survives export remapping. The CI export smoke proves the exported pack holds the same content as the project. | [`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md); export smoke |
| EI-09 | **Save format ≠ game version.** Saves carry a `save_version` that is separate from the game version and changes only when the format does. A save that fails to load is kept on disk and reported, never deleted. | [`ARCHITECTURE.md`](ARCHITECTURE.md) §10; save tests |
| EI-10 | **Every visible string is translated.** Every string a player can see goes through `tr()` with a key in `locale/strings.csv`. English is the source. Spanish is updated in the same version as the English text. | Locale coverage test; release checklist |
| EI-11 | **Determinism is tested in CI.** A replay-hash golden runs on the ubuntu `verify` job and the `windows` job and must produce the same hash on both. | `tests/golden/`; CI |

## Product defaults

| ID | Default | Notes |
|---|---|---|
| PD-01 | **Single player, one starting character.** The character has a primary attack, a dash, and one utility slot holding either **guard** or a **mobile skill**, chosen before the run. | A second kit or character is v0.8.0 scope ([`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md) §4) |
| PD-02 | **Flat gameplay plane, fixed camera.** All gameplay happens on a 2D plane. The camera is orthographic and isometric with a fixed 45° yaw and no rotation. Movement input is screen-relative. | Pitch is picked in v0.0.1 from the camera gallery |
| PD-03 | **Run shape.** A run is 3 floors. Each floor has 7–9 mandatory encounters plus 1–3 optional branches, ending in a boss. Median run length is 35–45 minutes. | Numbers from the gap analysis (GA: run structure) |
| PD-04 | **Procedural floors, biome pool.** Floors are built from authored room templates plus seeded variation. A biome is independent of difficulty: the floor index drives scaling. Each run draws its biomes from the unlocked pool without repeats. Ruins, Night Rocks and Red Canyon ship first. Frozen Shore and any others are added in balance passes before content complete. | Owner decision 2026-10-06 |
| PD-05 | **Choice-driven threat.** Difficulty rises through threat **T**, which the player raises by choosing branches and rewards that show their threat cost. There is no global clock and no enrage timer. | Formula: GA: threat; locked by evidence in v0.3.0 |
| PD-06 | **Meta-progression is sideways.** Meta unlocks add alternatives, information and cosmetics. There are no permanent stat increases. | GA: meta |
| PD-07 | **Reward schedule.** A starter reward after Room 1. A guaranteed compatible payoff after Room 3. A fallback offer in Room 4 if no engine has formed. A drought limit of 2 rooms without a build-relevant offer. | GA: rewards; measured by the scorecard |
| PD-08 | **Slot cap (prototype).** 6 mechanism slots plus a 3-slot reserve, built behind a feature flag. Kept or dropped at balance alpha (v0.6.0). | GA: slots |
| PD-09 | **Platform and input.** Windows desktop. Mouse+keyboard and twin-stick gamepad have parity from v0.0.1, with full remapping from v0.1.0. | Owner decision 2026-10-06 |
| PD-10 | **Languages.** English and Spanish. | |
| PD-11 | **Look.** Primitives-first, low-poly, flat-shaded 3D in the reference image's palettes. This is the target look, not a placeholder. | [`../art/ART_DIRECTION.md`](../art/ART_DIRECTION.md) |
| PD-12 | **Out of scope until the owner says otherwise:** multiplayer, crafting, persistent stat trees, a mod editor, an Endless mode, ten characters. | Endless is barred before balance alpha (L8) |

---

## Decision-change log

Every EI change and every PD flip gets a row, newest last. Use the decision-row template in
[`../process/TEMPLATES.md`](../process/TEMPLATES.md) §4.

| Date | Changes | Decision | Why / evidence | Approved by |
|---|---|---|---|---|
| 2026-10-06 | EI-01..EI-11, PD-01..PD-12 | Initial set, from the starter doc kit | Deathventory lessons ([`../LESSONS.md`](../LESSONS.md)) and the owner's decisions of 2026-10-06 (engine, procedural floors, 3 biomes first, Windows with KB+M and pad parity) | Owner |
| 2026-10-06 | PD-03, PD-06, PD-07, PD-08; ROADMAP §4 milestones; pool and enemy-name rules | The audit framework is the whole design source; there is no separate gap-analysis report. Every number the kit attributed to "GA" is an owner decision from the approved kit plan. Topics without numbers are design questions for the version that needs them ([`../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md`](../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md)) | Owner: "the framework is all there is" | Owner |
| 2026-10-06 | ARCHITECTURE §13 (bench) | Bench: the stress scene must hold mean ≤ 2 ms / p99 ≤ 4 ms per tick; the reference encounter must run ≥ 15× real time headless | Owner confirmed the kit's reading (O5) | Owner |
| 2026-10-06 | BLUEPRINT §C (primary, utility), §E (Charger, Warden, Needle), `MIN_TELEGRAPH_TICKS` | Primary = a melee swing + a charged shot. v0.1.0 builds both utilities (guard, blink), picked before play (PD-01 unchanged). The three enemy designs and a 24-tick minimum telegraph as proposed in the v0.1.0 PLAN. The playable fight ships to the owner before options and audio | Owner answers Q1–Q4 after the v0.0.1 playtest ("just the box moving no enemies or no attacking") | Owner |
| 2026-10-07 | BLUEPRINT §C (primary, utility, bindings) | The primary splits into **melee** (the swing combo) and **shooting** (hold for continuous low-damage bolts) on separate buttons; the charged bolt is dropped. Blink follows the move direction. Pad: triggers attack, bumpers dash and utility | Owner's fight-build feedback (`v0.1.0/PLAYTEST_FIGHT.md`) | Owner |
| 2026-10-07 | BLUEPRINT §C (blink, movement) | Blink is a teleport that passes through walls (it never ends inside one or outside the room). Movement accelerates and stops on a fast, smooth curve instead of instantly | Owner's second-build feedback (`v0.1.0/PLAYTEST_FIGHT_2.md`) | Owner |
| 2026-10-07 | **PD-05 flipped** for floors; ROADMAP §4 order | A floor's fights are a **continuous, controlled spawn** that gets a little harder every 30 s, not waves and not only player-chosen threat. (PD-05's "no global clock" and the framework's warning about enrage timers are noted: the ramp is gentle and readable; the owner judges it.) The roadmap jumps to a full first floor (procedural layout, items, a portal gate) as v0.2.0, pulling scope from the old v0.2.0 and v0.3.0; v0.1.0's remaining steps move into it. Melee becomes a laser blade with a trail; INK is the default outline | Owner's third-build message (`v0.1.0/PLAYTEST_FIGHT_2.md`) | Owner |

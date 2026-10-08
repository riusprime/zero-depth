# v0.4.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3). Starts when v0.3.5 wave 1 is
merged.

## Owner decisions (2026-10-07)
- The build direction F7–F11, F13 (verbatim in `../v0.3.0/PLAYTEST_RUN_2.md`).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| BS | Four ability slots (slot 1 = Combo Sword / Pulse Gun; Bomb Lobber, Drone Buddy, Orbit Blades, Blink with a landing shock, Aegis as cards; full slots level up to L5); no utility at the start (F11); 12 stat cards × 3 rarities and crit (5 %, ×1.5, `crit` stream); altars and chests offer abilities, stat cards and the items as mods; the shrine pays into the same stats; ability HUD, card faces, damage numbers (crits big and yellow), bombs / drones / blades / shock in the world; dev panel grants abilities. Evidence: [`evidence/BUILD_SYSTEM.md`](evidence/BUILD_SYSTEM.md) | `7a4a453` + this commit |
| AB | Arc Field, Frost Nova, Flame Trail (auto abilities feeding the shock, frost and burn engines; L1–L5); eight ability combos (both at L3 evolve: Storm Bombs, Napalm Drone, Glacier Ring, Blink Charge, Blade Dance, Wingman, Superconductor, Ember Ward; combo card, badge, look); the Overrun threat branch (one optional red-framed side room per floor, ×1.5 HP and damage, +50 % spawns inside, 12 kills clear it for an ability-card altar and 2× shards; minimap mark, banner, sounds); dev panel route to the Overrun door. Evidence: [`evidence/ABILITIES_2.md`](evidence/ABILITIES_2.md) | `v0.4.0 Step AB` |
| EN | Six horde enemies (Swarmer packs, Splitter, Shield Bearer, Mender, Mine Layer, Sniper): 12 behaviours ([`evidence/ENEMIES_12.md`](evidence/ENEMIES_12.md)) | `v0.4.0 Step EN` |
| BO | A second boss in every pool: the Warlord (floor 1), the Hive Lens (floor 2, splits into three Lens Drones), the Foundry (floor 3); the `flood` move; sounds, strings, image prompts ([`evidence/BOSSES_2.md`](evidence/BOSSES_2.md), [`../../art/BOSSES_2.md`](../../art/BOSSES_2.md)) | `v0.4.0 Step BO` |
| SC | Enemies scale per floor (HP ×1.9, damage ×1.4) and every 30 s danger tier (×1.10, ×1.05); hordes grow from 14/30/50 to 120 alive in packs at the room edges; the sim carries 120 enemies + 200 shots at 3.66 ms a tick (evidence/HORDES.md) | this commit |
| TU | A difficulty curve per floor (`data/curves/`): a calm first minute (5 / 7 / 9 alive, the basic kinds one at a time, no tier growth, eased HP and damage), then They stir / The hunt / The swarm bring the floor's kinds in by 3:00 and ramp to SC's peak at 10:00; enemy kinds spread over floors 1–3 (owner D5), each phase and each new kind announced on the HUD (en/es); a free altar next to the start hall; Splitlings and boss summons scaled like the spawner's; Gun ×1.00 (owner D6); the expected-build bot and run sims. Bands missed and reported ([`evidence/TUNING.md`](evidence/TUNING.md)) | `v0.4.0 Step TU` |
| SV | Saves at each first room entry and on close (pause → Main menu, window close); **Continue** on the main menu resumes at the last room's entry with the same state hash; a death or a win deletes the save ([`evidence/SAVES.md`](evidence/SAVES.md)) | `v0.4.0 Step SV` |

## Goldens changed on purpose
- TU: none (the replay golden passes; the export smoke's 600-tick hash stays `e5365ddb…`; the curve is loadout and
  the collision change keeps every result).
- SV: none (no hashed field added; the snapshot reads the world, it doesn't change how it steps).
- BS: none (the replay golden passes unchanged; the new hash block is added only once a slot, a stat card or a crit
  chance is in play, which the kernel worlds never have).
- BO: none (replay and export-smoke hashes unchanged).
- AB: none (the new ability-state and Overrun hash blocks are added only once those are in play).
- SC: `tests/golden/fixtures/replay_ground_plane.json` (final `5171fdad…41ae` → `70ac7ca2…0add`, first different
  checkpoint tick 420) and `tests/golden/fixtures/export_smoke_hash.txt` (`9c324d3d…17f2` → `e5365ddb…7391`). Why:
  the broadphase changed from 1 m Dictionary cells to `DenseGrid` (2 m cells; actors listed by centre). Collision
  resolves each body against its candidate walls and neighbours one after another, positions updating in between, so
  a different candidate set lets a body pushed by one wall be resolved against another in the same pass. Bisected:
  with the old grids and every other SC change the old fixture matched through tick 1200. The kernel scenario has no
  enemies, so staggering and scaling don't touch it. After the merge with BS/EN/BO (`a2b6d5b`) both fixtures hold
  unchanged (the replay golden passes; the export smoke's pack hash is `e5365ddb…`).

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1 Echoes / Core theft / Depth descent in the new direction | 2026-10-07 | pending | |
| Q2 v0.5.0 before a v0.4.0 playtest | 2026-10-07 | "skip the rule, keep going to v0.5.0" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.
- ~~BS: EI-05 still lists four streams~~ — updated with the owner's OK (2026-10-07).
- BS deferred (PLAN levels table): Aegis L5 "reflects bolts"; Pulse Gun L3 "+1 pierce" shares the Hot bolt's single
  pierce (a Hot L3 bolt still pierces once). Attack speed shortens a swing's recovery and the shot/drone periods, not
  a swing's wind-up. Regen cards heal in and out of combat (the PLAN doesn't say; the old regen stays out of combat).
- BS: `scripts/shots/vfx_cards.gd` still sets the removed utility pick in its profile (it no longer gets Blink); not
  run in CI.

- AB decisions (starting values, the owner tunes after playing): Frost Nova's "L3 freezes on 4 stacks faster" is
  read as 4 frost stacks per nova from L3 (a nova freezes on its own; 2 stacks a nova at 4 s never reach the 3 s
  stack life). Flame Trail drops a 0.9 m patch every 0.8 m moved (at most every 0.15 s); "6 dmg/s" = 3 every 0.5 s.
  The three borrow their engine's numbers from an item (Static Chain, Glacial Edge, Ember Edge). Ability combos
  reuse the v0.3.0 combo framework (ComboDefinition with two abilities). Overrun: the room is picked among the rooms
  already generated (no new room or wall: layouts and goldens unchanged), from the `map:overrun` sub-stream; "while
  you're in it" = enemies that arrive while you stand in the room are Overrun enemies (×1.5 HP and damage for life);
  the clear is a kill count (12 Overrun kills), "2× shards" = the shards those kills paid are paid again on the clear.
- AB not done: no ability-combo or Overrun line in the run recap; the Overrun altar looks like any altar (its offer
  is ability cards only).
- SV: ARCHITECTURE §10 said "never `World` in a save"; the PLAN's SV text (owner-directed) says the save holds the
  room-entry snapshot of the full `World`. Built as the PLAN says and ARCHITECTURE §10 rewritten to match; **owner confirmed** (2026-10-08: "Keep
  room-entry snapshots").
- SV: a save that can't be used is ignored with a warning and kept as `run.bad.<time>.save`; the menu shows no
  "Can't load this save" message (ARCHITECTURE §10 asked for one with Abandon). Not built.
- SV: AB, SH and EV add state. `WorldSnapshot` copies every script variable of `World` and of known state classes;
  a new store class fails `test_every_hashed_store_is_snapshotted` with its path until it is added to
  `WorldSnapshot.STATE_CLASSES` (and `_make` if it sits in an array) or `LOADOUT_CLASSES`. A new World field holding
  content tables needs a `WORLD_KEPT` entry. New run-level state in `RunState` needs a line in `RunSaver.payload_of`
  and `run_from`.

- TU (owner questions, `evidence/TUNING.md`): **Q-T1** the bots reach the floor-1 boss door at ~3 min, M-FLOOR says
  10–15 min (the peak is at 10:00); **Q-T2** no healing in a fight, so attrition kills the expected-build bot whatever
  the curve; **Q-T3** the floor-1 boss kills half the bots that reach it; **Q-T4** the PLAN's bands (floor-1 deaths
  < 30 %, 30–60 % by floor 3, TTK falling 20–40 %) are all missed (90 %, 100 %, +101 %) and were not widened.
- TU: horde bench still over 4 ms (CPU 4.95–5.02 ms a tick, ~5–6 % under the pre-pass tree, load ~6); not measured
  on a quiet machine. FightLab (readable cause, `stress_ai`) still runs floors without a curve on purpose.

## Blockers
- none

## History
- 2026-10-08 — AB merged with the lead branch (BO, CP, SC at `55a895d`): bombs, blink, Fast Hands and the Overrun
  spawn hooks composed as in `evidence/ABILITIES_2.md`; 924 / 924, readable cause 0 violations, export smoke ok.
- 2026-10-07 — Step AB: three element abilities, eight ability combos and the Overrun branch built and verified (see
  `evidence/ABILITIES_2.md`: 845 / 845, lint clean, minimum test count 845); no golden changed.
- 2026-10-08 — Step SV: `WorldSnapshot` (every World script field, loadout kept from a base built from the save's
  inputs; the guard tests), `RunSaver` / `RunSaveStore` (room-entry and close saves, worker-thread writes, checksum,
  `.bad` copy), Continue (en/es). 914 / 914, hitch probe ok, entry save 0.64–0.72 ms on the frame; goldens unchanged;
  `MIN_TEST_COUNT` 914 ([`evidence/SAVES.md`](evidence/SAVES.md)).
- 2026-10-07 — BS: build system built and verified on `7a4a453` (743 / 743, lint clean); final commit adds the
  evidence and this file. Owner note mid-step ("spell cooldowns have to be a bit bigger"): the ability slots are 52 px
  with a sweep and seconds left; their frames follow `CardStyle.current`.
- 2026-10-07 — Step BO: three new bosses, two per pool; fight-length bands unchanged and met (melee 29.1-34.3 s, near
  59.7-68.3 s, far >= 2.8x melee); readable cause 0 violations over 12 seeds; `MIN_TEST_COUNT` 769. The Warlord's
  arena is OPEN (CROSS walled the player out of the fight on a real floor).
- 2026-10-07 — SC: scaling tables (run + spawning data), packs at room edges, staggered AI plans, DenseGrid,
  bounded flood, view pooling/bars/occlusion focus; horde bench 14.13 → 3.66 ms, `stress_ai` 6.38 → 1.73 ms;
  kernel `stress` still 2.22 ms (> 2 ms, reported). Scorecard sims against the new scaling are TU's.
- 2026-10-07 — PLAN drafted from the owner's direction while v0.3.5 wave 1 runs.
- 2026-10-07 — Step EN: six horde kinds (starting values in CONTENT_SCHEMA §3 and SIM_CONTRACTS §10c), in the
  spawn mix from tiers 1-3 (`SpawnMixEntry.pack` for Swarmer packs of 8, within the alive cap); no golden changed.
- 2026-10-07 — Owner: "skip the rule, keep going to v0.5.0". ROADMAP §0.3 waived once: v0.5.0 follows v0.4.0
  without a v0.4.0 playtest; both are played together afterwards.
- 2026-10-07 — Owner: "okay let's bove the bigger card pool to v0.5 and make it in this current development sprint". The
  40–50 card pool (ROADMAP v0.6.0 → v0.5.0) runs as step CP in wave 3, after BS.
- 2026-10-07 — Owner on the altar mix (43 % ability cards while a slot is free): "ill test it after"; on EI-05: "change the
  locked rule yea" → EI-05 lists `crit` and `ability` (and the `ai:enemy` sub-stream).
- 2026-10-07 — BS merged on top of v0.3.5 (keep-both conflicts in world, debug API, dev panel, strings, SIM_CONTRACTS,
  LOCKED_DECISIONS). 777 tests pass; goldens unchanged.
- 2026-10-07 — EN merged (812 tests), then BO on top (by hand: the Kind enum keeps EN's kinds then BO's; EnemyAi matches run
  on `behaviour_of()` with the Swarmer included; both telegraph style sets kept). 846 tests pass; export smoke 0 misses;
  goldens unchanged. A container restart stopped SC, CP and AB mid-run; their work survived on disk and they resumed.
- 2026-10-07 — SC merged with BS, EN and BO (`a2b6d5b`): one pack rule (`SpawnMixEntry.pack`: 0 = the floor's draw,
  > 0 fixed; Swarmer 8, the other horde kinds 1); EN/BO AI under the 4-tick plans; mine damage by tier power;
  873 / 873, readable cause 0 violations, export smoke ok. Horde bench after the merge 4.84–4.89 ms: **target
  missed** (SC's own commit measured 4.55 ms in the same session; the machine is slower than when it measured
  3.66 ms). Reported, not retuned.
- 2026-10-08 — SC merged (re-integrated by its agent on BS+EN+BO, then on top of CP; one conflict: MIN_TEST_COUNT). 891 tests
  pass; export smoke 0 misses. Goldens changed on purpose by SC (new collision grid order): replay `5171fdad…` →
  `70ac7ca2…`, export smoke `9c324d3d…` → `e5365ddb…`. **Horde bench target missed after the merge:** 4.84–4.89 ms
  mean per tick vs ≤ 4 ms (4.55 ms for SC alone in the same session; machine load 4.5–6.2). Reported to the owner;
  a further optimisation pass goes into TU. Gap: split/summoned enemies get floor scaling only (fix in TU).
- 2026-10-08 — Owner played a playable build: too hard from the start; wants an easy first minute, enemies introduced in
  phases, the peak reached near the floor's end (verbatim in the PLAN, D1–D4). Goes into TU, started now.
- 2026-10-08 — Step TU: difficulty curve (5 phases per floor, data), phase HUD + dev "Next difficulty phase", kinds by
  floor (D5), altar by the start, queued-enemy scaling, Gun ×1.00 (D6), the expected-build bot (`RunBot`, `TuningRun`,
  `scripts/sim/tuning_sim.gd`). Sims: floor-1 deaths 100 % → 90 %, median death 61 s → 210 s, alive at 2:00 1/20 →
  20/20; bands missed (reported, Q-T1–T4). Readable cause 0 violations; boss bands in with the Gun at ×1.00; horde
  bench still missed. Goldens unchanged. `MIN_TEST_COUNT` 964.

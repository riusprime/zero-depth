# v0.2.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | `39d7b35` |
| G | The hooded wanderer from the owner's reference replaces the cube: animation + cloak springs ([CHARACTER](evidence/CHARACTER.md)) | `701302f`, `77414ca`, merge (this commit's parent) |
| F | The game runs on the floor; item visuals; lower walls; pedestal e2e; version `0.2.0-dev`; [`PLAYTEST_FLOOR.md`](PLAYTEST_FLOOR.md) | `088a852`, `8692b6e`, this commit |
| A | Laser blade with a motion trail (cone removed), smooth shadows ([SHADOWS](evidence/SHADOWS.md)), pad A/Cross presses menu buttons, INK default | `16a90b1`, `3dc4c1f`, `102ce4e`, `381bef0`, merge (this commit) |
| E | Eight items that change the attacks, pickups to walk over, a no-repeat pool (sim + content; visuals and pedestals in F) | `d684c37`, merge (this commit) |
| B | A seeded floor: 3×3 rooms joined by doorways, cover slabs, item spots, spawn points, a gate spot ([FLOORS](evidence/FLOORS.md)); placed in the game in F | `40f9936`, `ee24b66`, merge `eb32d61` |
| D | A stone gate with a swirling green portal, sealed ([PORTAL](evidence/PORTAL.md)); placed in the floor in F | `85e99c7`, merge `c3caa19` |
| C | Enemies arrive continuously; cap, pace, mix and HP step up every 30 s (sim + data; wired into the floor in F) | `97e3387`, merge `6d85d36` |

## Goldens changed on purpose
- **C** (spawner state hashed: run ticks, spawn cooldown, kills): replay golden final `815b1648…91f4e6` →
  `6e73b137…010326`; export-smoke hash `39e66d22…d3756c` → `e011ccdd…a17af8`. Kernel behaviour unchanged.
- **E** (item, pickup, burn, echo, dash-hit, bounce state hashed; direct DAMAGE now carries proc_pct 100): replay
  golden `6e73b137…010326` → `cc3595c1…54c565`; export-smoke hash `e011ccdd…a17af8` → `d18fc1dc…42d4cb`.
- **J** (8 more items' state hashed: heal window, chain, momentum, thorn, phase, per-actor slow): replay golden
  `cc3595c1…54c565` → `c798f9e5…a309df`; export-smoke hash `d18fc1dc…42d4cb` → `921997d9…5e4234`. The subagent
  confirmed the kernel's behaviour is unchanged by re-running the golden with the new fields un-hashed.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Floor build check ([`PLAYTEST_FLOOR.md`](PLAYTEST_FLOOR.md)) | 2026-10-07 | pending | |
| M | The Warden no longer blocks: front hits deal 80 %, rear hits 110 %, sides 100 % (data: arcs 120°/120°); grey spark on armour, bright spark on the weak spot. 239 tests; goldens unchanged (the hashed runs have no Warden) | `628f30a`, merge `3ff2d40` |
| I | Floor v2: a 3×3-cell start hall with one exit on a random side, 9–11 more rooms (1×1 … 3×3 cells) in a tree plus 1–2 loop doors, 7 interior layouts, 1 item spot in 1×1 rooms and 1–2 in bigger ones (none in the hall), portal room farthest ([FLOORS](evidence/FLOORS.md)); NavField build 1.5 s → ~72 ms on these floors, identical results | `c8575b6`, `7a4da9e`, merge `d9313c2` |
| Character matches the reference | 2026-10-07 | pending (lead's check: 3/4 views close; face-on boxy) | |

## Open
- O3 `main`. O4 credit line.

## History
- 2026-10-07 — Owner directed the first floor (verbatim in `../v0.1.0/PLAYTEST_FIGHT_2.md`). PLAN committed.
  Workstreams A–D run in parallel (subagents in separate worktrees), then E and F.
- 2026-10-07 — C merged (15 new tests; subagent report: tiers, cap/interval formulas, mix unlocks, ≥ 8 m spawns,
  HP scale, no spawns after death, determinism). Goldens re-recorded once for it; 154 tests pass locally,
  export smoke 0 misses. Not yet applied: "spawn in the player's room or a neighbour" (needs B's rooms; in F).
- 2026-10-07 — D merged (portal gate, 5 tests; renders in evidence/PORTAL.md: reads well facing the camera and
  at ±45°, edge-on only a pillar shows, so the integrator avoids edge-on placement). 159 tests pass locally.
- 2026-10-07 — B merged (6 tests over 50 seeds: deterministic, every room/spot/spawn/gate reachable; ~33 ms per
  floor). Notes for F: the gate isn't a wall (add a collider); slabs average ~1.2 per room (a 2.2 m spacing rule
  removed sealed pockets found in 7/50 seeds); the floor is ~45 × 39 m. 165 tests pass locally.
- 2026-10-07 — E merged (22 tests; each item's effect checked numerically). Conflicts were two append-only
  blocks (strings.csv, world_reader.gd) kept from both sides; translations reimported and checked in en/es.
  Subagent's calls for the owner: Overcharge shockwave 2.0 m / 50% (invented starting values), one shared burn
  timer refreshed per stack, Twin Arc echoes every swing (the PLAN's wording). 187 tests pass; goldens
  re-recorded.
- 2026-10-07 — F part 1 (`088a852`): the game runs on the floor (FloorScenario, pedestals, gate, floor HUD).
  The owner asked for a character rework from a reference image (a hooded figure with a cyan visor, a cloak,
  animation, light cloak physics): PLAN L10, workstream G started in parallel. The image arrived in chat only,
  so G works from a written description (in its brief); it is not in the repo.
- 2026-10-07 — The owner uploaded the character reference (`e63c661`); renamed to
  `docs/art/main_character_visual_reference.png` and linked from ART_DIRECTION. Workstream G checks against it.
- 2026-10-07 — A merged cleanly (8 new tests). Pad bug root cause: Godot 4.7's built-in `ui_accept` has no pad
  button; `InputDefaults.apply()` now adds JOY_BUTTON_A. Shadow saw: mostly the camera's far plane (200 → 100) plus
  an 8192 atlas, high soft-shadow filter, blur 0.5 (lavapipe renders; GPU cost and motion shimmer unverified).
  The blade is hidden when not swinging. 195 tests pass.
- 2026-10-07 — F part 2: `ItemVisuals` (blade colour/width/trail per item, bolt looks, Twin Arc echo flash,
  Overcharge shockwave ring, Kinetic Dash afterimages, burning enemies glow orange), `WorldReader.wall_class`
  (structural walls drawn low, slabs 1.8 m instead of 2.4, the gate's footprint not drawn), props scaled to the
  floor's area. New e2e walks to the nearest pedestal with the left stick only and takes the item. 200 tests pass.
- 2026-10-07 — G merged after one refinement round: the lead compared the first turnaround with the owner's
  reference and sent back seven fixes (cloak silhouette, hood height, visor size/placement, separate legs,
  lighter outline, dead pose, swing-twist evidence). The 3/4 views now read like the reference; face-on views
  still look boxy (reported to the owner). Version `0.2.0-dev`; `PLAYTEST_FLOOR.md`. 208 tests pass; export smoke
  0 misses.
- 2026-10-07 — The owner uploaded a detailed character sheet (`docs/art/main-character-sheet.png`, `63a0d24`): "we
  should keep working on matching it as much as we can". It becomes the primary character reference
  (ART_DIRECTION); workstream G2 matches the avatar to it while the owner tests the floor build.
- 2026-10-07 — G2 merged (`10c2c07`): the avatar rebuilt to the character sheet (shield-faced tapered hood, centred
  visor, diamond poncho with a V-neck, chunky legs and boots); `evidence/character_sheet_compare.png` puts the sheet
  over the renders. Lead check: the front view matches closely; side views still differ (the poncho's front corner
  juts forward; the sheet's hangs down and the sides flare lower/wider); from the game camera the hood top is large.
  A G3 round targets those. 210 tests pass.
- 2026-10-07 — The owner played the floor build (verbatim in `PLAYTEST_FLOOR.md`): it "feels good"; damage
  sometimes lags or crashes; dash/blink VFX and a blue portal; compact item cards with icons; a bigger, more
  varied floor (3×3 hall + connecting rooms, 10–12 total); 1–2 items per room; more items. PLAN L11–L16;
  workstreams H (crash), I (floor v2), J (8 more items), K (VFX + item cards) run in parallel with G3.
- 2026-10-07 — G3 merged (`c99081e`): the poncho hangs under the face (front corner reach 0.40 → 0.32 m), side
  corners flare wider and lower, the V ends at knee height so legs and boots show, the hood is longer, the neck
  sliver is gone. Lead check against the sheet: front, right-front and right views now match closely; still
  differs: the hood's top reads large from the game camera, and the sheet's hood sides flare a little more. 210 tests.
- 2026-10-07 — J merged (`b7b9f2e`): Vampiric Core, Static Chain, Momentum, Frost Core, Thorn Mantle, Executioner,
  Swift Feet, Phase Strike (numbers in the subagent's report and data/items); all 16 descriptions ≤ 60 characters
  in en and es. Item indices are alphabetical, so a seed's pedestal draws changed. 231 tests pass; goldens
  re-recorded; export smoke 0 misses.
- 2026-10-07 — Owner confirmed `docs/art/image.png` is the enemy sheet (renamed `enemies_visual_reference.png`) and asked for 1:1 enemy visuals (L17) and a Warden without the front block: −20 % from the front, +10 % from behind (L18). Workstreams L (three enemy-model agents) and M (Warden armour) started in parallel with H, I, K.
- 2026-10-07 — M merged: Warden armour per L18. Validation ranges the agent chose (front 1..1000 ‰, rear 1000..3000 ‰, arcs summing ≤ 360°) are starting values. Sparks not yet checked on screen. 239 tests pass; MIN_TEST_COUNT 239.
- 2026-10-07 — I merged. 241 tests pass; goldens unchanged (the hashed runs use the kernel scenario); export smoke 0 misses; hitch probe ok (4 ticks after a 250 ms stall, limit 4). Open: the ground plane still covers the floor's whole bounding box (unreachable cells look like floor); cell size and weights are starting values.

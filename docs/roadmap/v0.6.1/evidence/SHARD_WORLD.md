# v0.6.1 Step SW: shard-style world pieces (evidence)

Owner line R3: "we'd have to also modify some renders in game to match the more shard like style like altars or
other elements". The G1 audit is [`SHARD_AUDIT.md`](SHARD_AUDIT.md). Build: the step's working tree on top of
`c684ed2fea44e88095d5059f1d54cc45867585f1` (`claude/lucid-fermat-9wv2tf`); the commit SHA is the step's commit
(`v0.6.1 Step SW: …`). Godot `4.7.2.stable.official.ed1daf0bf`, Linux cloud container, lavapipe (`llvmpipe`) for the
shots. Presentation only: no file under `src/sim/` changed, so every altar's position, reach and interaction are what
they were.

## What was done
| Piece | Where |
|---|---|
| `ShardMesh`: the shared shard builder (faceted shard, chip, rough stone; lit crystal material with facet tones, rim and a little emission; dark inverted-hull outline; soft additive glow sprite; cluster; fragment). Its own file so step SD's dressing can reuse it | `src/presentation/world_view/shard_mesh.gd` |
| The altars (plain, Deep epic, boss legendary): stone base on the old 0.62 m footprint, 8 outlined shards in the tier's card-frame colour (`ALTAR_FRAME`: blue / purple / gold through `CardFrames.tint`), glow, 4 floating fragments each bobbing on its own beat; in reach the crystals' emission, the glow and the light brighten (energies and alpha only: flash-safe). Kept: the light colours, the arena seal ring (`_add_seal`), the metas the e2e tests read (`epic`, `legendary`, `light`, `spin`, `body`), removal when used, the HUD prompt (untouched) | `src/presentation/world_view/reward_views.gd` |
| The dropped core: an outlined shard in the card's colour, 2 chips, glow; the ring kept; floats at 1.0 m | same |
| Heal orbs: an outlined green shard (lit, emission 1.4) turning in a soft green glow; same colour, height, pulse | `src/presentation/world_view/heal_orb_views.gd` |
| Shard gems: outlined violet shards (lit, emission 1.6), own material; the chest price gem keeps `shared_material()` | `src/presentation/world_view/shard_views.gd` |
| Shot script | `scripts/shots/shard_world.gd` |
| ART_DIRECTION §4 paragraph, PROGRESS row and gate | `docs/art/ART_DIRECTION.md`, `../PROGRESS.md` |

Not touched: the v0.5.9 lighting, moods, kit, rooms, dresser; the owner's chest and shrine models; the HUD; any sim
code.

## Tests
- New `tests/unit/presentation/test_shard_altar.gd` (5): the builder (facet tones, stands on y = 0 at the asked
  height, deterministic, outline shell back-faced in the line colour, lit material with emission and vertex tones, a
  cluster has one shard per count); the altar at the sim's altar position, named `ShardAltar`, ≥ 8 outlined lit shards,
  no solid vertex past `ALTAR_RADIUS` + 0.06 m (glow sprite and seal ring excluded), gone when its reward goes; each
  tier's card-frame colour on every shard and the legendary light; in reach brighter emission, light and glow than an
  altar out of reach, fragments bobbing, emission never toggled, seal hidden outside an arena and its ring outside
  the base; heal orbs, shard gems and the dropped core are outlined lit shards in their colours.
- Unchanged and passing: `test_reward_views.gd` (altar glow, chest price, flash-safety, shake), `test_routes_view.gd`
  (`test_the_epic_altar_glows_violet`: the light colours were kept), `test_kit_chest.gd`; e2e `test_e2e_rewards.gd`,
  `test_e2e_arenas.gd` (the legendary altar `legendary` meta; the seal on a locked reward), `test_e2e_heal_orbs.gd`,
  `test_e2e_curses.gd` (cores); arch `test_layering.gd`, `test_sim_purity.gd`.
- `tests/MIN_TEST_COUNT` not raised here (other wave-1 agents add tests too; the lead sets it after the merge).

## Commands
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_rewards.gd,res://tests/e2e/test_e2e_arenas.gd,res://tests/e2e/test_e2e_heal_orbs.gd,res://tests/e2e/test_e2e_curses.gd,res://tests/arch/test_layering.gd,res://tests/arch/test_sim_purity.gd -gexit
XDG_DATA_HOME=<empty folder> timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy \
  --resolution 1280x720 -s scripts/shots/shard_world.gd
cp build/shots/v0.6.1/shard_world/{near,tiers,pieces}_crop.png docs/roadmap/v0.6.1/evidence/shard_world_{near,tiers,pieces}.png   # by hand
```
The full suite was not run (CLAUDE.md: agents run lint and the tests of what they touched; the lead runs one full
suite after the wave).

## Raw output
Lint:
```
616 files would be left unchanged
Success: no problems found
```
`tests/unit/presentation` (the folder of the new and touched tests; no "SCRIPT ERROR" or "Failed" line in the log):
```
Scripts              58
Tests               347
Passing Tests       347
Asserts           609210
Time              101.985s

---- All tests passed! ----
exit 0
```
(The log's one "Deprecated" line is GUT's `wait_frames` notice from an existing HUD test, not from this step.)

E2e and arch:
```
res://tests/e2e/test_e2e_rewards.gd
res://tests/e2e/test_e2e_arenas.gd
res://tests/e2e/test_e2e_heal_orbs.gd
res://tests/e2e/test_e2e_curses.gd
res://tests/arch/test_layering.gd
res://tests/arch/test_sim_purity.gd
...
Scripts               6
Tests                12
Passing Tests        12
Asserts            7260
Time              45.619s

---- All tests passed! ----
exit 0
```

A first run of `test_shard_altar.gd` failed the footprint check: `[0.82018291950226] expected to be <= than [0.68]: on
the old footprint (0.82 m)`. The test measured transformed AABB corners (a rotated box's corners overshoot the mesh);
it now measures the mesh's vertices. No geometry changed for the fix.

Screenshot run (renderer, 1280 × 720):
```
shard_world: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1280, 720)
shard_world: frame 20 step boot
shard_world: altar id=5 sim_pos=(3.555002, -33.99) view_pos=(3.555002, 0.0, 33.99) tier=normal colour=4fa8f0 in_reach=true mood=true
shard_world: res://build/shots/v0.6.1/shard_world/near.png (frame 31, tick 137)
shard_world: res://build/shots/v0.6.1/shard_world/tiers.png (frame 37, tick 161)
shard_world: frame 40 step pieces
shard_world: res://build/shots/v0.6.1/shard_world/pieces.png (frame 41, tick 177)
shard_world: done
exit 0
```
`view_pos` is `SimPlane.to_3d(sim_pos)`: the altar stands at the sim's altar. `mood=true`: the floor's v0.5.9
lighting mood is on (Ruins).

The shots (crops round the altar, ×2 nearest):
- [`shard_world_near.png`](shard_world_near.png) (sha256 `f6747daa…0bc87ee0`): the plain blue altar, the hero in
  reach, the HUD prompt "[E / X] Open the altar".
- [`shard_world_tiers.png`](shard_world_tiers.png) (sha256 `8d06a7ea…79f631a23`): plain (blue), epic (purple) and
  legendary (gold) side by side.
- [`shard_world_pieces.png`](shard_world_pieces.png) (sha256 `200dde26…782f981c`): the same plus a pink dropped core
  with its ring, a green heal orb and a burst of violet shard gems.

SHOT HELPERS (labelled in the script): the hero is placed beside the altar (`ActorStore.set_pos`) instead of walked
there; the epic and legendary altars are added with `World.add_reward`; the dropped core, heal orb and gems are built
straight in the view. The extra altars stand where the helper put them (partly over the floor's crates): that
placement is the helper's, not the game's.

Earlier screenshot attempts, reported as they ran: three runs that walked the hero with the stick were killed by
`timeout 300` (`exit 124`) before reaching the altar (the last got to `frame 80 step walk`): other agents' renders and
tests shared the 4 cores (load average ~10) and lavapipe drew ~1 frame per 4 s. One of those logs was overwritten by
another agent's shot output in the shared scratchpad; later runs used a folder of their own.

## Owner
- How the shard altars, heal orbs, gems and dropped cores read in play, their size and brightness, and the colours
  (the epic altar's purple vs the epic cards' gold): **OWNER ONLY**.
- The G1 pick for the other rows: **OWNER ONLY** ([`SHARD_AUDIT.md`](SHARD_AUDIT.md)).

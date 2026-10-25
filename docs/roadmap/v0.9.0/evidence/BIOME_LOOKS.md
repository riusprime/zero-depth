# v0.9.0 BV: biome looks for every Wave 4 interaction (evidence)

Owner row: W71 (§11 Biomes: Ruins "machinery, destructible walls, pressure plates", Night Rocks "hidden paths, glowing
switches, statues", Red Canyon "heat vents, unstable structures, explosives", Frozen Shore "frozen mechanisms, ice
runes", Starfall "cosmic relays, floating runes, unstable portals"; "share scripts … different models, sounds, and
visual effects") in [`../PLAN.md`](../PLAN.md). Branch `v090-bv`, cut from `d5867aa2`; the step's commit is the one
that adds this file, and every run below was on that tree before the commit (no code changed after the runs). Machine:
the owner's PC (Windows 11, i7-10700K, RTX 3060), Godot 4.7.2; one Godot process at a time, with its own `APPDATA`.

**Where the looks live.** W71's row says "a per-biome look in `BiomeLook` (data)". This step was given as presentation
only (another agent changes the content schema in parallel), so the table is a presentation class,
`src/presentation/world_view/interaction_looks.gd` (`InteractionLooks`), keyed on the biome id the views already get
(`StageView.prop_style`). Moving it into `BiomeLook` later is a data move with no change to the views' reads. Lead:
flag this to the owner if the data placement matters.

## What changes per biome

The mechanics are shared; each view reads its biome's colours from `InteractionLooks` once at setup. The owner's
installed models are kept and tinted (their material's albedo × the biome's `tint`, one copy per material and biome;
Ruins keeps the delivered material). Code stand-ins take the biome's colours. Each biome adds a small mesh accent at an
interaction's foot (no particles, so Effects density Low keeps it): Ruins grey rubble, Night Rocks glowing blue
crystals, Red Canyon basalt with ember cracks, Frozen Shore a snow drift and ice shards (and snow on top), Starfall
floating star shards. A bare stage (`prop_style` "", the older tests) draws Ruins' colours with no accent: the look
before BV.

| | Ruins | Night Rocks | Red Canyon | Frozen Shore | Starfall |
|---|---|---|---|---|---|
| Rune glow (timed door seal, notches, switch runes; rune puzzle's matched face) | amber `#FFB347` | mint `#7CFFC4` | copper `#FF9E6B` | ice `#6FD6FF` | magenta `#FF7BEA` |
| Rune puzzle's shown face | pale blue `#9FD8FF` | periwinkle `#C8D2FF` | sand `#FFE2B0` | white `#F2F6FF` | starlight `#B8C4FF` |
| Hidden room's light | `#FFE7B8` | `#D8FFF0` | `#FFD6B0` | `#E8F4FF` | `#FFE0FA` |
| Owner model tint | as delivered | cool blue `#B4C6EC` | warm sand `#F0C2A8` | frost `#E2EEFF` | lavender `#C9B8F0` |
| Metal (door bolts, bar rods, hoops) | `#2E2B29` | slate `#2A3142` | rust `#4A2E24` | frosted steel `#5C6E80` | star metal `#3A2E5C` |
| Containers: wood / clay | `#7A5634` / `#A0603A` | `#4E5A70` / `#5E6F94` | `#A0784A` / `#C0623E` | `#8C8A86` / `#7FA4C4` + snow cap | `#4A3D6E` / `#7A5CB0` |
| Explosive barrel: body / band | `#8E2B1E` / `#C8A23A` | `#9A2A2A` / `#E0892B` | dark `#5A1A12` / yellow `#F2C14E` (it read 1.2:1 on red ground) | `#A3302A` / `#2E2B29` | `#8E2440` / `#F4E3FF` |
| Fountain water and light | `#6FD8FF` | moon teal `#8CF0D8` | oasis `#58D8C8` | pale ice `#A8E8FF` | star lilac `#D6B8FF` |
| Hidden rune marking scratch | pale `(0.92, 0.95, 1.0)` | faint mint `#A8FFE0` | soot `#3A1E18` | dark blue `#3A5A80` (a pale one vanished on snow) | faint violet `#F0B8FF` |
| Accent | rubble | glowing crystals | basalt + embers | snow + ice shards | floating star shards |

Per interaction:
- **Timed door and rune switches** (`timed_door_view.gd`): seal, frame notches and switch runes in the rune glow; bolts
  in the biome's metal; the owner's `rune_switch` tinted; accent at both jambs' feet and each switch; the room light.
  The door slab stays the code stand-in (`timed_door` is unlisted) in the biome's `cover` stone, as before.
- **Rune pillars and carving** (`rune_alignment_view.gd`): matched face in the rune glow, shown face in the biome's glyph
  colour; the owner's `rune_pillar` and `rune_mural` tinted; accent at each pillar's foot (snow on Frozen Shore's
  capstones); the room light. The pillars' own red, green and blue (the clue) are the same in every biome.
- **Cracked wall, containers, explosive barrels** (`breakables_view.gd`): the owner's `cracked_wall` and
  `cracked_wall_broken` tinted; accent at the wall's feet; the containers' stand-ins and their chips in the biome's wood,
  clay and metal (snow caps on Frozen Shore); the barrel's body and band as the table (the band and fuse cap stay clear).
- **Hidden rune markings** (`rune_markings_view.gd`): the scratch colour, same faint alpha.
- **Purple-rune dais** (`purple_rune_view.gd`): the owner's `purple_rune_dais` tinted and the accent round its foot; the
  runes, crystal and light stay violet in every biome (the Deep gate's colour).
- **Lockdown bars, hazards and warnings** (`lockdown_view.gd`): the owner's `lockdown_seal` tinted (stand-in rods in the
  biome's metal); each strike's warning disc (hostile `#FF5A1F`, unchanged) now ringed by a dark band (ART_DIRECTION's
  hazard "orange with a dark band"), so it reads on Red Canyon's red ground. The hazard props already differ per biome;
  their stand-ins were checked and changed where they read badly: Ruins' cable was a storm-blue `#7FD8FF` emissive box
  (the hero's storm core `#7FB2FF`), now a dark post with a hostile-yellow spark `#FFE066`; Night Rocks' rock was grey
  `#5C5A66` on blue ground, now dark `#2C3040`; Red Canyon's vent was all emissive orange on red ground, now a dark
  basalt cone `#3A2420` under a hot plume `#FF4E1A`; Frozen Shore's ice was near-white `#CDEFFF` on white snow (and the
  frost core's hue), now a deep-blue ice spike cluster `#3F6E9C`; Starfall's pale-gold star kept.
- **Shrines and healing fountain** (`shrines_view.gd`, `gamble_shrine_view.gd`): the owner's `shrine_blood`,
  `shrine_chaos`, `healing_fountain`, `shrine_fortune` (and the old `gamble_shrine`) tinted; the fountain's water, its
  glow and light in the biome's water; the accent round each foot. Blood stays red, Chaos violet, Fortune gold. The
  fountain's dry look darkens the tinted body (before, the wet look reset it to white).
- **Interact prompt**: HUD only (`interact_prompt_hud.gd`), no world part, so nothing to change.
- `world_view_root.gd` hands `stage.prop_style` to the views that have no stage (purple dais, shrines, markings, gamble
  shrine).

Readability: the hostile warning and the hazard stand-ins' colours are tested to sit more than 0.2 (RGB distance) from
the hero's core and the five element cores, the warning stays a hostile hue, and every biome's warning band is dark.
No per-frame allocation: materials and accents are made at setup; `sync` and `_process` only set existing values.

Not changed, noticed: `RuneMarkingsView.TEXTURE` points at `res://assets/textures/decals/rune_marking.png`, but the
manifest installs the owner's `rune_marking` at `assets/textures/kit/rune_marking.png`, so the code glyph still draws.
Left for the lead (it changes what the markings look like).

## Lint

```
$ gdformat --check src scripts tests
1219 files would be left unchanged
$ gdlint src scripts tests
Success: no problems found
```

## Tests

New: `tests/unit/presentation/test_biome_interaction_looks.gd` (10 tests): five looks with five different colours a
key; the hostile warnings out of the hero's attack colours; then, for each of the five biomes, the timed door and
switches, the rune pillars and carving, the cracked wall and markings, the containers and barrel, the purple dais, the
Lockdown bars and hazard (five different hazards), the shrines, fountain and Fortune shrine each pick that biome's look
(colours, tinted owner models, the accent); and a Starfall floor's `WorldViewRoot` hands Starfall to every interaction
view it builds.

Import first: `APPDATA=<own folder> godot --headless --path . --editor --import --quit` (exit 0).

```
$ APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit \
  -gtest=res://tests/unit/presentation/test_biome_interaction_looks.gd,res://tests/unit/presentation/test_timed_door_view.gd,res://tests/unit/presentation/test_rune_alignment_view.gd,res://tests/unit/presentation/test_breakables_view.gd,res://tests/unit/presentation/test_purple_rune_view.gd,res://tests/unit/presentation/test_lockdown_view.gd,res://tests/unit/presentation/test_shrines_view.gd,res://tests/unit/presentation/test_gamble_views.gd,res://tests/arch/test_layering.gd
Tests                36
Passing Tests        36
Asserts           14740
Time              67.718s
---- All tests passed! ----
```

The first run of the new file failed one assert, fixed before the run above:
`[Failed]: [0.19151555001736] expected to be > than [0.2]: hostile #ff7a2a is far from hero #ffaa33` (the vent's plume
was too near the ember core; it is `#FF4E1A` now).

```
$ APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit \
  -gtest=res://tests/e2e/test_e2e_timed_door.gd,res://tests/e2e/test_e2e_lockdown.gd,res://tests/e2e/test_e2e_shrines.gd
Tests                 4
Passing Tests         4
Asserts              63
Time              66.141s
---- All tests passed! ----
```

Not run locally: the full suite (GitHub runs it on the PR, CLAUDE.md).

## Shots

One GPU contact sheet per biome, nine tiles each (3 × 3, 640 × 360, labelled): the timed door with one switch lit, the
rune pillars and carving, the cracked wall, a crate, an urn, a barrel and an explosive barrel, the purple-rune dais, a
Hazard Lockdown (the bars, a strike's warning, the biome's hazard), the Blood shrine, the healing fountain, the Fortune
shrine. Real floors (the tests' labs) in the real game view (`WorldViewRoot` with the biome's palette, mood and
prop_style, the iso camera).

```
$ APPDATA=<own folder> godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/biome_looks_bv.gd
biome_looks_bv: renderer=forward_plus
biome_looks_bv: res://build/shots/v0.9.0/bv/ruins.png
biome_looks_bv: res://build/shots/v0.9.0/bv/night_rocks.png
biome_looks_bv: res://build/shots/v0.9.0/bv/red_canyon.png
biome_looks_bv: res://build/shots/v0.9.0/bv/frozen_shore.png
biome_looks_bv: res://build/shots/v0.9.0/bv/starfall.png
```

Copied by hand from `build/` and saved as JPEG (quality 85, 1920 × 1080):
[`bv_shots/ruins.jpg`](bv_shots/ruins.jpg), [`bv_shots/night_rocks.jpg`](bv_shots/night_rocks.jpg),
[`bv_shots/red_canyon.jpg`](bv_shots/red_canyon.jpg), [`bv_shots/frozen_shore.jpg`](bv_shots/frozen_shore.jpg),
[`bv_shots/starfall.jpg`](bv_shots/starfall.jpg).

The interactions are small at the game's camera; the accents are small touches by design. Whether each biome's look
reads as belonging there: OWNER ONLY.

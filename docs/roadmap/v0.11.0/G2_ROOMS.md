# v0.11.0 G2: rooms with a purpose (O15, PLAN P1, Q26)

The owner (brief §8): "Some procedurally generated rooms currently feel like random collections of placed assets … the
store rooms are a positive example … especially the larger ones." Q26 answer: "(a) G2 shots of purpose rooms from
authored templates (like shops) with seeded variation".

These are **mockups, not the feature**. `scripts/shots/o15_purpose_rooms.gd` builds a real run floor, clears one 3 x 3
room's interior and lays a purpose template into it; the game's own `WorldViewRoot` draws it (the biome's mood, kit and
dresser, the iso camera). The generator (`floor_generator.gd`, `room_layouts.gd`) is untouched.

- **Room:** run seed 20261018, floor 1, room 4: 3 x 3 cells, 42.7 x 34.2 m, 2 doorways (the first 3 x 3 room that is
  no special room from seed 20261014 on). The same room for every shot. The hero stands at the first doorway for scale.
- **Pieces:** only the kit's existing models (`assets/models/kit/`). No new effects (PD-13): the only lights are the
  kit's fire barrel and brazier.
- **Staging (labelled in the script):** in the template shots the biome's cover pools are switched off, so the named
  pieces are drawn as named (crates stay crates); its decoration pools stay (Frozen Shore's grass is snow drift).
- **Shots:** `build/shots/v0.11.0/o15/` (not tracked). Command, one biome per run:
  `godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/o15_purpose_rooms.gd -- biome=<id>`
  with `ruins`, `frozen_shore`, `starfall`, `red_canyon`, `night_rocks`.

## How the seeded variation works (all three)

A template is authored like a shop: its pieces have set places in a frame of the room's half-size (long axis first; a
tall room turns it). The room's seed then picks:
- the **mirror** (either axis): tried from the drawn one, the first that keeps the focal piece and most solids out of
  the doorways' boxes wins (as the designed layouts' turn and mirror today);
- the **optional parts and counts** (which shelter or stack is left out, 4 or 5 seats, 3 or 4 blocks to a stack, which
  column stands, is a stump or has fallen);
- **small shifts and turns** (under 1 m, under 15 degrees), stack heights;
- the **biome's pieces** for each part (a per-biome palette: Ruins' car wreck is Frozen Shore's upturned boat).

A solid that would stand in a doorway's box (the doorway's width plus 1 m each side, 3.4 m deep), on an item spot
(1.6 m) or outside the room is dropped. In the production version these rules would be the generation property tests
over 1,000 seeds (PLAN O15).

## 1. Camp

**What:** a camp round a fire. **Focal piece:** the fire pit in the middle (the fire barrel, a ring of stones, 4–5
seats, two drying racks). **Dressing that belongs to it:** five shelters on a ring at 60 % of the room, each turned to
face the fire, with its lean-to on one side and its crates on the other, maybe a brazier; supply piles in two opposite
corners; stone paths from the fire out to each shelter.
**Combat space:** the ring between the fire and the shelters (about 8 m wide) is open all round; the shelters are
deep cover with gaps of 10 m or more between them; the corners behind them are open except the two supply piles.
**Variation:** which of 6 shelter slots is empty, which side the lean-to and crates go, the corner pair for the piles,
the mirror.

| Biome | Seed 1 | Seed 2 |
|---|---|---|
| Ruins (car wrecks, barricades, tyre seats) | `camp_ruins_s1.png` | `camp_ruins_s2.png` |
| Frozen Shore (upturned boats, fish racks, crate seats) | `camp_frozen_shore_s1.png` | `camp_frozen_shore_s2.png` |

## 2. Collapsed hall

**What:** the nave of a fallen hall. **Focal piece:** at one end, the ruin the hall led to (Ruins: the stone arch
between two tall piers with building corners behind; Starfall: the ruined observatory between two monoliths), lit by
two braziers. **Dressing that belongs to it:** two colonnades down the long axis, each column standing, broken to a
stump or fallen across the aisle with its rubble spilt; broken walls in the side aisles; one or two great fallen
pieces across the nave.
**Combat space:** the nave (about 13 m) is open but for 1–2 fallen pieces; the columns are posts you fight round, not
walls; the side aisles have low broken walls with gaps.
**Variation:** each column's state, which side aisle walls stand, the nave falls, the mirror (the focal end).

| Biome | Seed 1 | Seed 2 |
|---|---|---|
| Ruins (stone arch, piers, broken columns, slabs) | `hall_ruins_s1.png` | `hall_ruins_s2.png` |
| Starfall (ruined observatory, monoliths, rocks) | `hall_starfall_s1.png` | `hall_starfall_s2.png` |

## 3. Quarry

**What:** a working quarry. **Focal piece:** the cut rock face against one long wall (a row of 7 rock masses, the
middle one the tallest), scaffolds and lights at its foot. **Dressing that belongs to it:** the cart where the stone is
loaded, a yard of cut-block stacks (stepped heights) with lanes between them, a haul road edged with rubble from the
cart to the far wall, two markers at its end.
**Combat space:** the face is a wall, not cover; the road (4.6 m) is a clear lane through the room; the stacks are
3 m blocks with 4–5 m lanes; the band in front of the face is open.
**Variation:** the cart's side (and the road with it), which stack is left out, stack sizes and heights, the number
of scaffolds, the mirror (the wall the face is on: its three middle masses must stay clear of doorways). Seed 1 puts
the face on the near wall, seed 2 on the far wall; the far wall reads better from the iso camera, so production could
prefer it.

| Biome | Seed 1 | Seed 2 |
|---|---|---|
| Red Canyon (rocks and mesa chunks, wagon, skull posts) | `quarry_red_canyon_s1.png` | `quarry_red_canyon_s2.png` |
| Night Rocks (rocks and spires, wagon, braziers) | `quarry_night_rocks_s1.png` | `quarry_night_rocks_s2.png` |

## Today's room, for comparison

The same room as the generator furnishes it now: `today_ruins.png` (also `today_frozen_shore.png`,
`today_starfall.png`, `today_red_canyon.png`, `today_night_rocks.png`).

## What the kit lacked (art request candidates)

- **Camp:** a tent or lean-to shelter (the shop tent is the stall's model), a log seat, a cooking pot or spit.
- **Collapsed hall:** a statue (whole and broken), a standing column that is not a square pier, a fallen column drum.
- **Quarry:** a crane or hoist, a mine cart on rails, cut stone blocks in the biome's stone (the concrete slab stands
  in), a tool rack.
- **All:** biome pieces (KitModels role `biome`) always draw at the kit's own height, so a large focal piece
  (the arch, the observatory, the monoliths) cannot be scaled up; bigger versions would make the focal pieces read
  from across a 3 x 3 room.

## Owner questions

**Q-O15a.** Which purposes should be built for large rooms (3 x 3 and up)? Any or all of: (1) Camp, (2) Collapsed
hall, (3) Quarry; or others (a shrine, a supply yard).

**Q-O15b.** Approve **authored templates with seeded variation** (as above: set places, a seeded mirror, optional
parts and counts, small shifts, per-biome pieces, doorway drops) as the method?

Answers: OWNER ONLY.

## Owner change (2026-11-07)
Collapsed hall: "The hall ruins have the pillars way too organized, can we shape them kinda in a way as Stonehenge, not
exactly like that but the vibe." The straight colonnades go; the hall becomes a loose ring or horseshoe of standing
stones around the focal ruin: irregular gaps (the lanes in and out), each stone with its own lean and turn, a few
lintels across neighbours, some broken or fallen outward, a couple of outliers. All drawn from the seed.

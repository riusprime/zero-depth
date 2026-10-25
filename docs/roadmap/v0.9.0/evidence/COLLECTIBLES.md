# v0.9.0 Step CL: the 16 collectibles (evidence)

Build: branch `v090-cl`, cut from `2f8f0c87` (the local `claude/world-combat-v090` head). The Step CL commit is the one
that adds this file. Tests ran with CL's changes in the working tree.
Machine: the owner's PC (Windows 11, RTX 3060), Godot 4.7.2, Git Bash, own `APPDATA`. No timings are claimed.

Owner line: "4. collectibles are fine" (PLAN "Owner decisions", row `NB, EL, HB, CL, BR, MP`): the 16 of
`docs/roadmap/v0.9.0/COLLECTIBLES.md` as drafted, names and lore lines unchanged (en + es).

## What the player sees

- **In a run:** when a source gives its collectible, a small pickup appears at the source: a faceted gem in the
  collectible's own colour, turning and bobbing, with a white-hot core, a halo, a glow pooled on the floor, a real
  light and motes rising (the VX bar: layered, never a flat shape). Walking over it takes it: it flares and rises
  away, a chime plays (the combo unlock's, a placeholder), and a toast reads **ADDED TO THE RUNE ARCHIVE** with the
  collectible's name and lore line. The run's Rune Fragments go up by one.
- **In the hub:** one floor rune lights per collectible found; the Rune Archive's shelf niche of each found one glows
  in its colour. At 12 found the north gate is open (HB's hook) and the **Keystone** waits on the alcove's pedestal
  (the same layered gem). Walking up to it takes it, and the hub's line says "Keystone · ADDED TO THE RUNE ARCHIVE".
  There's no toast in the hub: its changes stay silent (W46).
- **The Rune Archive** (E there) now opens the Codex on a new last page, **Collectibles**. It shows the four shelves
  (Stone, Sealed, Crown, Rune Ring), each with a "found / total" count and a row of niches. A found niche is the gem
  in its colour; looked at, it shows the name, the shelf and the lore line. A niche not found yet is a dark silhouette
  with "?": looked at, it shows "?" and the shelf's name only, no hint (P4). Q / E reach the Codex's other pages. The
  Archive's prompt now reads "[E / X] Open the Archive".

## The 16 and where each is found

| # | Collectible | Source (sim) | Where its pickup shows |
|---|---|---|---|
| 1-5 | Cold Lantern, Starless Map, Sunbaked Idol, Frozen Bell, Star Splinter | the cracked wall's hidden room on a floor of its biome (Ruins, Night Rocks, Red Canyon, Frozen Shore, Starfall) | in the room, between its reward and its doorway, once the wall breaks |
| 6 | Aligned Key | rune puzzle solved, floor 4 or 5 | in the puzzle's hidden room |
| 7 | Sand Shell | timed door, floor 3+ | in the timed room once it opens (a shut door's switches reopen it) |
| 8 | Broken Shackle | a Hazard Lockdown cleared by the fight (not by its 90 s cap) | beside its reward altar |
| 9 | Violet Eye | the floor reached through a Purple Portal | beside the hero once the arrival ends |
| 10 | Blood Coin | a Blood Shrine's deal taken | beside the shrine, on the side away from the hero |
| 11 | Dry Chalice | a healing fountain drunk on a run's last floor | beside the fountain |
| 12 | Rune Rubbing | the 3rd secret behind hidden rune markings in one run | in the room of the secret that made it 3 |
| 13-15 | Colossus Tooth, Prism Shard, Mirror Mask | the final boss's Colossus / Prism / The Fallen (`nemesis`) falls | comes to the hero at once (flare where the hero stands) |
| 16 | Keystone | the hub's alcove, behind the north gate (12 found) | on the alcove's pedestal |

A pickup never lies within the hero's reach when it shows (1.6 m), so you always see it before you take it.

## Choices (P1-P4 and where the doc was silent)

- **P1:** the floor bosses have no collectible, as drafted.
- **P2:** yes, a small one-time amount: each find gives MP's `collectible` fragment (1, `data/meta/rune_fragments.tres`,
  MP's starting value), through `RuneFragments.add_collectibles` in a run. The run banks it at its end, as MP's rule
  is. The Keystone banks its fragment into the profile at once.
- **P3:** the toast "ADDED TO THE RUNE ARCHIVE" + name + lore, on the find. A collectible is found once per profile,
  so the toast only ever shows once for it. The hub stays silent apart from the Keystone's line.
- **P4:** a "?" silhouette with the shelf name only, no hint.
- **Once per profile:** a run starts with the profile's finds in `RunState.collected`, so later runs don't drop a found
  one at all. One edge: a pickup taken after the last room-entry save, then Continue. It lies there again and gives
  nothing more.
- **Banked at pickup:** the profile's `collectibles` section is written the moment the pickup is taken, so a death
  never loses it.
- **One Stone a run:** once a Stone is taken, no later floor of the run arms another. Skipping one doesn't block a later
  floor's.
- **Rune Rubbing:** the markings are decor beside the secret doorways (DX). So "finding three hidden rune markings" is
  read as three marked secrets found in one run: the timed door opened, the rune puzzle solved, the cracked wall
  broken. The purple runes have no marking and don't count.
- **Violet Eye:** the walk through the portal ends the floor, so the Eye waits on the floor it led to. Because it's
  found once per profile, it is the first walk's.
- **Crown pieces** come to the hero as the body falls: the end panel follows the last body by 45 ticks, which leaves no
  time to walk to it.
- **Hazard Lockdown:** only a cleared one counts; one opened by its cap doesn't.
- **Dry Chalice:** the loop's last floor (`RunState.is_last_floor`, floor 5).
- **The alcove holds the Keystone** (the doc's #16) and nothing else.
- **A tweaked run** (dev panel balance edits) records no find, like the Codex, achievements and fragments.
- **The floor runes** count the finds (HB's `count:collectibles:N`: rune i lit at i+1 found). The niches are per
  collectible. The three collectible pedestals before the Archive are unchanged.

## How it is built

- Content: `CollectibleDefinition` (category `collectible`, `data/collectibles/*.tres`, 16, validated). It sits in
  the dev panel's Economy group (`src/debug/dev_fields.gd`).
- Sim (pure):
  - `Collectibles` + `CollectState` (`World.collect`, null on a floor with none: goldens and sims hash as before; hashed
    when present; in `WorldSnapshot.STATE_CLASSES`; `collect` in `ADDED_SINCE_V05`, so an older save keeps the base's).
  - `SimEvent.Kind.COLLECTIBLE` (appended at the end).
  - `RunState.collected`, `collected_run`, `marked_done` (`finish_floor` adds `Collectibles.marked`). No random draw.
- Arming (app side, `CollectibleBook.arm`, from `FloorPlan` after every source is set up, and in `SaveLab` as Main):
  the run's not-yet-collected ones whose source the floor has.
- Saves: `RunSaver` writes `run.collected`, `run.collected_run` and `run.marked` only when not empty (an older payload
  found none). No payload version change.
- Profile: `ProfileStore.PROFILE_VERSION` 2 -> 3, a `collectibles` section (id -> the run seed; 0 for the hub's).
  `_migrate`: an older profile loads with none found and keeps the rest.
- App: `MetaHooks.observe` (main.gd's achievements line now calls it; main.gd stays at 1000 lines, 2 lines edited)
  banks each new find: the profile, the run's lists, the fragment, the toast. `HubSession` lights the shelf and runes
  and takes the Keystone. `CodexView.page_of` opens the Archive on Collectibles.
- Presentation: `CollectibleView` / `CollectibleLooks` (the layered pickup), `ArchivePage` / `ArchiveTile` (the
  Codex page), `HubView.show_found` / `set_keystone`.
- Strings: 38 keys, en + es (16 names, 16 lore lines, 4 shelves, the toast, the tab). `HUB_PROMPT_ARCHIVE` reworded.
  Boss names stay English in es.

## How often each can appear in a run

`test_how_often_each_can_appear_in_a_run`: for run seeds 1-30, floors 1-5 (normal route), built as Main builds them.
The count is the runs in which some floor arms the collectible, i.e. its source is there to find. Raw line:

```
CL_ARMED| cold_lantern=6/30 starless_map=3/30 sunbaked_idol=6/30 frozen_bell=3/30 star_splinter=6/30 aligned_key=7/30 sand_shell=16/30 broken_shackle=18/30 violet_eye=0/30 blood_coin=18/30 dry_chalice=7/30 rune_rubbing=26/30 colossus_tooth=0/30 prism_shard=0/30 mirror_mask=0/30 keystone=0/30
CL_ARMED| purple_room_runs=30/30
```

The 0/30 rows aren't on normal floors by design:

- **Violet Eye:** on every floor reached through the Purple Portal, and every one of the 30 runs had a purple-rune room
  to awaken it (`purple_room_runs=30/30`).
- **Crown pieces:** armed in every final arena (unit test).
- **Keystone:** in the hub once 12 are found (e2e).

An earlier 40-seed run of the same test (before an unrelated test fix) printed cold_lantern 8/40, starless_map 5/40,
sunbaked_idol 8/40, frozen_bell 5/40, star_splinter 6/40, aligned_key 9/40, sand_shell 24/40, broken_shackle 25/40,
blood_coin 22/40, dry_chalice 10/40, rune_rubbing 35/40.

## Commands and raw summary lines

Command: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>`
(or `-gdir=... -ginclude_subdirs`). Import first: `godot --headless --path . --editor --import --quit` (exit 0). Lint
(`gdformat --check` + `gdlint`) on every changed or new .gd: "Success: no problems found".

Unit batch: test_collectibles (new), test_old_saves, test_world_snapshot, test_state_hasher, test_layering,
test_sim_purity, test_hub, test_hub_view, test_rune_fragments, test_meta_progress, test_codex, test_run_saves.

```
Tests               102
Passing Tests       101
Failing Tests         1
Asserts           23416/23417
```

The one failure was test_hub's "a missing section is not created". It had been written before CL, for a profile with
no `collectibles` section; a fresh profile now holds that section, empty. The assert now checks the section stays as
it was (empty: the flags only read). Re-run of test_hub alone:

```
Tests                 9
Passing Tests         9
Asserts              90
```

tests/content + tests/unit/debug:

```
Tests               171
Passing Tests       171
Asserts           12805
```

e2e batch: test_e2e_collectibles (new), test_e2e_hub, test_e2e_rune_fragments, test_e2e_run_flow, test_e2e_old_save,
test_e2e_codex, test_e2e_achievements, test_e2e_shrines.

```
Tests                22
Passing Tests        21
Failing Tests         1
Asserts           394/395
```

The one failure was test_e2e_codex's second test. After its second visit to the Archive it read a Cards tile while
the Codex was on Collectibles (`Invalid access to property or key 'locked' on a base object of type 'Nil'`, line
223). Fixed with one E press, as at its first visit. Re-run of test_e2e_codex alone:

```
Tests                 2
Passing Tests         2
Asserts              61
```

e2e lines (test_e2e_collectibles):

```
CL_E2E| blood coin seed=5 fragments_before=0
CL_E2E| keystone fragments 0 -> 1
```

1. Run seed 5's floor-2 save is continued from the menu. The hero walks to the Blood Shrine and E takes the deal. The
   Blood Coin shows and is drawn, then the hero walks onto it. Its toast shows, the profile has it, the run has +1
   fragment. Pause -> hub: rune 1 lit, its niche lit. The Archive opens on Collectibles: the Coin is found (name +
   lore once the arrows reach it), the first niche reads "?" with its shelf's name, "Found 1 / 16".
2. A 12-found profile: the gate is open, 12 runes lit, the Keystone is shown. The hero walks through the gate to it:
   it's taken, rune 13 lights, +1 fragment, the hub line names it.

Not run locally: the full suite (GitHub runs it on the PR).

## Shots (GPU, 1920x1080, en and es)

`godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/cl_shots.gd`, copied by hand into
`cl_shots/`:

- `<lang>_1_blood_coin_in_a_run.png`: the Blood Coin beside the paid shrine (world paused);
- `<lang>_2_rune_archive_five_found.png`: the Codex's Collectibles page, five found, the Sand Shell looked at;
- `<lang>_3_hub_runes_lit_gate_open.png`: 12 runes lit, the north gate open, the Keystone on its pedestal.

OWNER ONLY: how the pickups and the Archive look and feel on your screen.

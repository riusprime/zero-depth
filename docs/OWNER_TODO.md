# What the lead needs from Rius (the owner's to-do list)

Everything that waits on you, in one place: art, decisions, tests and the playtest. The lead keeps it up to date: a
row moves to **Done** with the date when it arrives, and new requests are added here as they come up. Last updated
2026-10-15, v0.8.0 (branch `claude/lucid-fermat-9wv2tf`).

**How to deliver art:** drop the `.glb` (with its textures) or `.png` into `unprocessed_images/` (or the repo root),
named by the **id** in the tables below, and say so in chat. The lead installs, sizes, lists and tests it. Prompts
for each item are in the request file named in its section. Nothing blocks the game: every item has a code-made
stand-in until yours arrives.

Priority: **P1** changes the game most · **P2** worth doing soon · **P3** nice to have.

---

## 1. Playtest v0.8.0 (P1)

Get it: `git fetch origin && git switch claude/lucid-fermat-9wv2tf && git pull`, open in Godot 4.7.2, Play.
Shortcut to every fight: Main menu → **Playground** → **F1**. Every new number: **F10**. The sheet:
[`roadmap/v0.8.0/PLAYTEST.md`](roadmap/v0.8.0/PLAYTEST.md).

### What I hope to get back
- **Answers to the 8 playtest questions** in your own words; I paste them verbatim into PLAYTEST.md and they become
  the next version's plan, as with v0.7.5.
- **Per boss (6) and per final-boss body (3):** too easy / right / too hard, how long it felt, the one thing that
  felt unfair or unreadable, the weakest animation or effect.
- **Numbers you can read off the game,** where you have them:
  - fps with your biggest builds (the stacked Gun: Spread + Split + Explosive; the Blade: Double Slash + Blade Storm +
    Wave + Split Wave + On Hit + Explosive), from the F10 overlay or Godot's monitor;
  - the Playground DPS meter for a Blade build against a Gun build you'd call "good";
  - how long the Prism and the Nemesis took you.
- **Bugs:** what you did, what you saw, what you expected; a screenshot if you can. "Saved and continued" matters
  (it rebuilds the floor from the save).
- **Anything you'd cut or change,** even if it isn't in the questions.

### Specific checks only you can make
- [ ] Can you dodge every melee enemy now that their red ground marks are gone (only the body tells the wind-up)?
- [ ] Enemy colours by role (palette A): do the roles read at a glance?
- [ ] Each boss's signature: does each fight now stand out?
- [ ] The final boss from a real run: End the run → arena → three bodies → the true ending.
- [ ] Blade vs Gun: does the Blade now combine as well? Is Blade Storm still worth taking?
- [ ] The Ember stone menus and cards, in English and Spanish.
- [ ] The 24 designed rooms and the shop stall in every biome.
- [ ] Loops: is loop 2+ hard without one-shotting you?
- [ ] On the **Windows export** (the CI build, not the editor): starts, plays, saves and quits cleanly.

---

## 2. Decisions waiting for you

| # | Question | Today (the lead's default) | Where |
|---|---|---|---|
| D1 | The Prism's length: about 60 s of **fight**, or 60 s of **hitting windows** (≈ 3.5 min) | 60 s of fight | `data/final_boss/prism.tres` `dps_target_seconds`; FINAL_BOSS_2.md |
| D2 | Blade Storm: lower its 36-blade cap (steadier 60 fps, less damage) or keep it and make the drawing cheaper | keep 36 | PERF.md "PF2" |
| D3 | The Nemesis casts **3** of your cards (you allowed 2–3) | 3 | `data/final_boss/nemesis.tres` `card_casts` |
| D4 | The final boss's names (working: the Hollow Crown; the Colossus, the Prism, the Nemesis) | working names | `locale/strings.csv` |
| D5 | The Hive Lens's Gaze is **not** shielded (its open eye is the window to hit it) | not shielded | BOSS_SIGNATURES_2.md |
| D6 | The Foundry's melt starts 4 m in from the room's edge (its rooms are 48–55 m across) | room radius − 4 m | BOSS_SIGNATURES_2.md |
| D7 | Two Blade readings: "up to 5 slashes at L5" built as 5 repeats; "blasts from one trigger merge past 8" built as "per tick" | as built | BLADE.md |
| D8 | The Gun stack's damage fell about half, not "an order of magnitude" as the audit guessed. Enough? | as built | BLADE.md |
| D9 | The old crystal card art (cards, plaques, build picker) was deleted with the shard cards. Restore it from git? | deleted | MENU.md |
| D10 | Shop, arena and Overrun rooms may get a designed interior too (they're chosen after the floor is built) | allowed | ROOMS.md |
| D11 | Two 4×4 layouts are a little sparser than your first three (about 12 % blocked vs 15–16 %) | kept | ROOMS.md RT2 |
| D12 | From v0.7.5: should the Siege Engine and the Foundry keep their gap-closers? | kept | v0.7.5 PROGRESS |
| D13 | From v0.7.5: add the sub-streams `map:ice`, `map:starglow`, `map:overrun` to EI-05's locked list? | kept, unlisted | LOCKED_DECISIONS EI-05 |
| D14 | The "win" achievement now counts only when the final boss is beaten (End the run no longer wins at once). OK? | as built | FINAL_BOSS_1.md |
| D15 | Merge v0.7.5 (PR riusprime/zero-depth#6) and then v0.8.0 into `main` | waiting for your test | — |

Answer in chat as "D1 fight, D2 keep, …"; the lead writes each answer into the docs the same day.

---

## 3. Art you can generate

### 3.1 Shop (P1): [`art/requests/v0.8.0_ART_LIST.md`](art/requests/v0.8.0_ART_LIST.md) §1
| ✓ | id | what | note |
|---|---|---|---|
| ✅ | `shop_tent` | the stall | **Done 2026-10-14** (your desert stall, in every biome) |
| ☐ | `shop_vendor_ruins` | the Ruins vendor | **as a separate model** so it can move (the stall's vendor is fused) |
| ☐ | `shop_vendor_night_rocks` | Night Rocks vendor | |
| ☐ | `shop_vendor_red_canyon` | Red Canyon vendor | |
| ☐ | `shop_vendor_frozen_shore` | Frozen Shore vendor | |
| ☐ | `shop_vendor_starfall` | Starfall vendor | |
| ☐ | `shop_wares` | goods for the counter | |
| ☐ | stalls for the other 4 biomes (P3) | optional | today your desert stall stands in every biome |

### 3.2 Enemy models (P1): [`art/requests/v0.8.0_enemy_models.md`](art/requests/v0.8.0_enemy_models.md)
`swarmer`, `splitter`, `shield_bearer`, `mender`, `mine_layer`, `sniper` (each in its role colour) — ☐ ☐ ☐ ☐ ☐ ☐.
Optional: `lens_drone` ([`v0.7.5_bosses_2_models.md`](art/requests/v0.7.5_bosses_2_models.md)) ☐.

### 3.3 Final boss (P1)
| ✓ | What | Why |
|---|---|---|
| ☐ | **Re-export your final-boss file with one shared, smaller texture** (2048 or 4096) | each of the three models carries its own copy of the same 8192² texture: +56 MB in the repo |
| ☐ | Animated versions of the Colossus, the Prism and the Nemesis | your "actual cool animations"; they replace the code clips by name (`idle`, `walk`, attack names in FINAL_BOSS_1..3.md) |
| ☐ | Arena pieces (P2): `arena_wall_segment`, `arena_gate`, `arena_pillar`, `arena_brazier`, `ground_arena` | ART_LIST §7 |

### 3.4 Boss attack pieces (P2): ART_LIST §4
`stone_spike` (3 variants in one file) ☐ · `javelin` ☐ · `brood_egg` ☐

### 3.5 Boss animation clips (P2)
Optional, any boss: clips named like the code ones (`idle`, `walk`, `marks`, `pattern`, `lanes`, `leap`, `death`…,
listed per boss in [`roadmap/v0.8.0/evidence/BOSS_ANIMATIONS.md`](roadmap/v0.8.0/evidence/BOSS_ANIMATIONS.md)) in an
AnimationPlayer inside the `.glb`; yours replace the code ones.

### 3.6 Room pieces (P2): ART_LIST §3
- **Ruins:** `building_corner`, `ladder_frame`, `column_broken`, `pipe_bundle`, `barricade`, `tire_stack`,
  `metal_post`, `dumpster`, `cable_spool`, `sign_frame` (10)
- **Night Rocks:** `boulder_small`, `rock_spire`, `stone_arch`, `mushroom_cluster`, `bone_pile` (5)
- **Red Canyon:** `mesa_chunk`, `dry_shrub`, `cactus`, `wagon_wreck`, `cattle_skull_post` (5)
- **Frozen Shore:** `snow_drift`, `ice_shard`, `ice_rock`, `ice_floe`, `ground_snow`, `boat_wreck`, `fish_rack` (7)
- **Starfall:** `star_crystal`, `meteorite`, `star_monolith`, `floating_island`, `void_spike`, `ground_star`,
  `ruined_observatory` (7)

### 3.7 Attack textures (P3): ART_LIST §5
`fx_orb_core`, `fx_beam`, `fx_lava_crack`, `fx_rock_burst` (today they're made in code).

### 3.8 Audio (P3)
A final-boss music track (FINAL_BOSS F9); today it uses the existing boss sounds.

---

## 4. Things only you can confirm (OWNER ONLY)
- [ ] Your credit line for the credits screen (`CREDITS_OWNER` is still "…").
- [ ] The AI 3D generator's terms allow shipping its models in a sold game (Tripo, used for every model).
- [ ] The Windows build on your hardware (above, §1).

---

## Done (moved here when it arrives)
| Date | Item |
|---|---|
| 2026-10-13 | Warlord, Hive Lens, Foundry models (v0.7.5) |
| 2026-10-14 | The final boss's three models (split from one file) |
| 2026-10-14 | The shop stall (`shop_tent`) |
| 2026-10-14 | v0.8.0 picks: palette A, menu style B, boss signatures, Blade audit, final boss rows, the ×100 loop cap, room density |

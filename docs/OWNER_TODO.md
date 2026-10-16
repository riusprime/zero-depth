# What the lead needs from Rius (the owner's to-do list)

Everything that waits on you, in one place: art, decisions, tests and the playtest. The lead keeps it up to date: a
row moves to **Done** with the date when it arrives, and new requests are added here as they come up. Last updated
2026-10-15 (textures added), v0.8.0 (branch `claude/lucid-fermat-9wv2tf`).

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
- [ ] The final boss from a real run: the Ascension portal (walk in, no menu since P2) → arena → three bodies → the true ending.
- [ ] P2: the last floor's two devices: do the Ascension portal and the green Loop device beside it read as two separate things? Is the Loop device easy to find and to step on?
- [ ] P2: Void's black holes (8 % a shot, +3 % a level): do they feel good, and is the pull strong enough?
- [ ] Blade vs Gun: does the Blade now combine as well? Is Blade Storm still worth taking?
- [ ] The Ember stone menus and cards, in English and Spanish.
- [ ] The 24 designed rooms and the shop stall in every biome.
- [ ] Loops: is loop 2+ hard without one-shotting you?
- [ ] P3: do Ruins, Night Rocks and Red Canyon now run as smoothly as Starfall on your PC (fps)? Do the fire
  lights still pop as you walk, or fade? Is the glow low enough (barrels, braziers, the hero), the mood kept? Is loop
  2 through the Purple Portal about 10 % easier? ([evidence](roadmap/v0.8.0/evidence/BIOME_PERF_AND_LIGHT.md))
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
| D16 | The Gun's new feel (O18): the blue shade (kept off the Arc Caster's periwinkle shots), whether its range should shrink with the slower speed (kept at 10.8 m), and the stacked Gun builds' damage rising again with the bigger shot (Spread + Split + Explosive +12 %; with Twin +44 %) | as built | GUN_FEEL.md "For the owner" |
| D17 | The blue pulse costs more to draw than the old squares: the stacked-Gun test went from 7.7 to 8.1 ms a frame (with Twin 8.4 to 11.1 ms), still under the 12 ms target on average. Keep the look, or simplify it under heavy fire | keep | GUN_FEEL.md |
| D18 | **Blade hit-stop:** the game already freezes on every landed Blade swing (3, 3, 4 and 7 frames by combo step, since v0.1.0) and GF3 added the 2-frame view freeze you asked for on top. Keep both, keep only the game's, or shorten the game's to 2 frames | both | BLADE_FEEL.md "Found" |
| D19 | The Blade's slash impact reads faint in the renders (big bodies hide it, its sparks wash out on pale sand and the white flash). Bigger / brighter? | as built | BLADE_FEEL.md |
| D20 | Void's black holes (P2, starting values): 8 % a shot +3 % a level (20 % at 5), 2 s, at most 3, pull 3.5 m at 3 m/s, every 0.2 s 30 % of the shot on enemies within 1.4 m; on the Blade a slash rolls where it first lands; the roll uses the existing `ability` stream (no new stream). OK? | as built | PLAN "P2"; VOID_AND_PORTALS.md |
| D21 | The Loop device stands beside the Ascension portal where a Deep gate would (no menu, no "End the run"); the two Ascension achievements now say "Take the Loop device". OK? | as built | FINAL_BOSS.md "The flow since P2" |
| D22 | The Purple Portal (Deep gate) 10 % ease (P3, O35) applies on loop 2 **and every later loop**. Loop 2 only instead? | loop 2 and later | [`BIOME_PERF_AND_LIGHT.md`](roadmap/v0.8.0/evidence/BIOME_PERF_AND_LIGHT.md) |
| D23 | Rarity (RR): which combinations count as a **broken build** (Chain Blast + Split + Spread/Twin on the Gun, Chain Blast + Double Slash + On Hit on the Blade, and each ×2 trigger with Explosive or Chain Blast), and the odds model (every altar and chest opened, a player who chases the pieces). Right list? | as built | [`RARITY.md`](roadmap/v0.8.0/evidence/RARITY.md) "What counts as broken" |
| D24 | Rarity (RR): the boss's altar now shows each card's **own** tier (a level-5 Common card says "Mod · Level 5 · Common"; only Legendary cards and the 1.6× stat cards are gold) and its title says "The boss's reward" or "The boss left a Legendary card" instead of "Pick a legendary card" (X1b). OK? | as built | RARITY.md "UI" |
| D25 | Rarity (RR): Rare cards are **blue** now (they were amber, too close to the Legendary gold); every card also says its tier in words | blue | RARITY.md "UI"; `rr_shots/` |
| D26 | Rarity (RR): a boss's **core** (stolen in the fight) no longer gives the ×2 triggers, only legendary stat cards, so every Legendary card goes through the odds. OK, or let cores give Legendary cards too (the odds then depend on how often you steal) | stats only | RARITY.md "What changed" |
| D27 | Rarity (RR): Split, Twin, Blade Storm and Riposte Chain are **Epic** (drawn about half as often at altars as a common card, 1.5× in chests). Other picks? | as built | RARITY.md "Every card's tier" |
| D28 | Rarity (RR): Chain Blast's blasts never merge (the pre-nerf rule). The PF frame budget was measured with Explosive's merging; a Chain Blast + Split + Spread build may lag like before PF (not measured) | as built | RARITY.md "Not measured" |
| D29 | Rarity (RR): how fast loops pile up Legendaries (each loop +5 % chance a boss altar and one more pick, up to 4 picks) | as built | RARITY.md "Loops" |

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

### 3.7 Textures to replace the code-made looks (P1–P3): [`art/requests/v0.8.0_textures.md`](art/requests/v0.8.0_textures.md)
Owner, 2026-10-15: real painted textures, like the player's attacks, for what v0.8.0 drew in code. Each row there
says what it replaces and gives the prompt.
- **P1 (most visible):** `fx_orb_cores`, `fx_orb_cores_2`, `fx_orb_cores_final`, `fx_trails`, `fx_beam`,
  `fx_beam_impact`, `fx_ground_cracks`, `fx_rock_burst`, `fx_lava_flow`, `tex_lava_crust`, `tex_menu_stone` (11)
- **P2:** `fx_dust_ring`, `fx_light_ring`, `fx_acid_splat`, `fx_steam_puffs`, `fx_rail_streak`, `fx_skid_marks`,
  `fx_aim_lines`, `fx_crystal_shatter`, `fx_cast_sigils`, `tex_menu_stone_wall`, `tex_mark_steel`, `tex_mark_hazard`,
  `tex_mark_acid`, `tex_mark_light`, `tex_stone_spike` (15)
- **P3:** `fx_ember_sparks`, `fx_star_motes`, `ui_element_glyphs`, `ui_element_glyphs_2` (4)

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

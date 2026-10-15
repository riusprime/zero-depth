# v0.8.0 — Fights and feel: the owner's v0.7.5 playtest (plan, owner-approved 2026-10-14)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

The owner, 2026-10-14, after playing the v0.7.5 build (the Playground included), verbatim:

> "Okay, so I'm just going to throw a lot of feedback from the game that I've been holding and experimenting while
> playing. So this is going to be V0.8, and I'm just throwing information. So I need you. What I need you to do is to
> organize it and write it down so we don't lose. Anything that I say, and then we start applying it like we always
> do, three, four agents max, if the four, if the tasks are not too big, three agents, and, first of all, the enemies
> are all red. I know I haven't provided models for all of them, but we could work in something that differentiates
> the different enemies, not only by what they do, but also color. And we could add some different models that add,
> you know, a bit more spice to the to the enemy mix and for most of them unless the things that are thrown from a
> distance we are gonna be deleting the red tray that they show when they aim like we already did with some of them
> before And for the new bosses, I do like the fights. That's like the direction, the right direction. But I tried all
> of them, and the fight seem, feels pretty similar. We just do the orbs in spirals and the ones crossing in line, and,
> and that's fine. But we should have something different, right? Something that actually stands out for each boss.
> Um, the animations they do are a shit, actually. So we have to work on animations from there, like we did with the
> actual attacks of the player. There are some... If we need to generate textures for that, so the the attacks look
> real. So, for example, when they do long distance stonekeeper, it should be like spikes coming out of the ground
> that actually look like spikes and not like. Just a red thingy that doesn't look good at all. And also the orbs that
> they throw, they're 2D shit looking. We could look up for some textures online and use them to create actual 3D
> objects in the game that look and feel like the game's art. Um, the combinations for gun are way better than the
> combinations for blade. Blade is way more difficult to get a good, you know, combination of items. And the, I
> haven't tried them yet, but... Feels like sometimes you're not getting that that many modifiers in the blade as you
> get in the gun, and with enough modifiers in the in the gun, for example, it happened multiple times. But this is
> the example I remember right now. You have a split and the other power that makes the attack divide when you hit an
> enemy. And they explode after it, and that causes hell of a lag. Like it goes, the game goes two, FPS. find a way of
> balancing with these animations so the game doesn't have lag a lot. And I feel like the the visuals are great with
> these images, but maybe we can stop applying some effects so it doesn't cause some lag. And with this kind of build,
> I tested the DPS on the new playground. And the DPS is above 50K of damage per second per enemy. So I spawned three
> enemies and I was doing over 150K of DPS. And ultra omega deleting bosses. So we have to find a way of balancing
> this. when you loop the game and you get to that point so it doesn't become boring and it keeps being difficult and
> not only like doing shit the stronger enemies deal more damage because that would one shot the the player so it
> needs to be a lot more HP growing than health because the player doesn't grow in health that much. We don't have
> those items yet. And that's it for now."

The owner, 2026-10-14 (second message, same day), verbatim:

> "I forgot to give you some feedback about how the game looks. So we just currently do templates with procedural
> generation. And I thought that we could design maybe two, three rooms of each size and have them like nicely looking
> like the image we use for reference, like a little bit more populated and feel more real. Like right now, they still
> feel a bit empty and not exactly what I want, so we can designed with new models, new rooms, and then we use
> procedural generation to place them as templates, but every floor and every loop in every game is different because
> of how they are placed. So we could like make a room that could be in different directions, that size has three
> variations and we place them randomly generating each floor with it and with this change we are gonna be creating
> this shop room that is gonna be designed in a way for each biome that will have like its own vendor like with a
> model and it will be like in a tent shop with some stuff I will give you a model for that we are also reworking the
> menu we're just throwing away the shard cards we're gonna be using a different style that matches more the game fine
> I found that that's not exactly aligned with the game so add that to the plan we are currently working on and work as
> far as you can without generating new models and give me the full list of things you need that I will be generating
> this afternoon after work"

The owner, 2026-10-15 (third message), verbatim:

> "So we have to modify and spice up the animation of the gun. We are gonna be adding some animations to it. So I want
> you to make it a little bit bigger, maybe like 25% bigger, and the gun should shoot less bullets per second, but do
> the enough more damage to be able to maintain the DPS. So we lower the speed a bit, we make it bigger, and then we
> transform the square that comes out into a pulse, like a fireball, but it will be blue. The main character needs to
> have like a casting animation, just spark of light and swirl that comes out of him every time a bullet comes out. And
> it should be very light, that like shooting animation, but it should have one. So then the enemies, when hit by a
> bullet, should have particles where it hit and coming behind, so we have an impact, a clear impact of it. And the
> enemy should flinch. That doesn't mean to move, so to flinch. And we keep the very short, just a couple of frames,
> that the enemy is highlighted in white every time an enemy is hit. And that's how the basic works. So we have to do
> the DP, the damage numbers, a little bit bigger, just a bit, and they should come out like they are thrown from the
> enemy in a curve that goes up and out. And the crit should be a number that spawns bigger, it has a little shake, and
> then it vanishes. So we make a real combat animation."

## Context
- **`main`** is v0.7.0 (`a20850f`, PR riusprime/zero-depth#5). **v0.7.5** is built and green on GitHub
  (`claude/v0.7.5-new-ground` at `f1a9ab5`, PR riusprime/zero-depth#6) and is what the owner played; it is not merged
  yet. v0.8.0 is built on top of it, on `claude/lucid-fermat-9wv2tf` (fast-forwarded to `f1a9ab5`), so it carries
  v0.7.5 with it. If #6 merges first, this branch merges `main` in.
- **The playtest rule (ROADMAP §0.3) is met:** this message is the owner's v0.7.5 playtest (pasted into
  [`../v0.7.5/PLAYTEST.md`](../v0.7.5/PLAYTEST.md) "Owner answers").
- **Owner rule:** anything that isn't a direct fix is decided before it's built. Direct fixes here: the lag (O9).
  Everything else waits on its gate (below).
- **Agents (O1):** three at once; four only when the tasks are small.
- **Live code audited 2026-10-14** (three read-only investigations; facts with `file:line` in the "Audit" section).

## Every owner line → where it lands
| # | Owner line (verbatim or close) | Decision | Step |
|---|---|---|---|
| O1 | "this is going to be V0.8 … organize it and write it down … three, four agents max, if … the tasks are not too big, three agents" | This is **v0.8.0**. The ROADMAP's old provisional v0.8.0 "Content Beta" row shifts one step, as v0.7.0 did. Agents: at most 3 at once, 4 only for small tasks (LOCKED_DECISIONS, supersedes the 2026-10-08 "at most 3") | — |
| O2 | "the enemies are all red … differentiates the different enemies, not only by what they do, but also color" | Each enemy kind gets **its own colour family** (body and glow), replacing the shared red #D8433A: the 14 kinds are all red + grey today. Hostile still reads as hostile through the eye glow and the outline. Q1: by role; then a G2 sheet of the shades | EC |
| O3 | "we could add some different models that add … a bit more spice to the enemy mix" | **Models for the enemies**: today 7 kinds share one code-made body (`HordeAvatar`) and none has an owner model. An art request with prompts per kind in the boss-model style (`docs/art/requests/v0.8.0_enemy_models.md`); the owner generates them and they go in as the bosses did. Q2: prompts only for the seven kinds with no owner design | EM |
| O4 | "for most of them unless the things that are thrown from a distance we are gonna be deleting the red tray that they show when they aim like we already did with some of them before" | Supersedes v0.7.5 N16's "the melee enemies keep the red thingy". The melee wind-up marks go (Charger / Hatchling / Swarmer lanes, Splitter disc, Shield Bearer bash lane, Warden slam): their wind-up is read from the body (crouch, glow, flash) instead. Q3: only the Arc Caster rune and the Mine Layer mines keep a ground mark; the Sniper line and Needle lanes go too | TG |
| O5 | "for the new bosses, I do like the fights. That's like the direction … But … the fight seem, feels pretty similar … the orbs in spirals and the ones crossing in line … Something that actually stands out for each boss" | Keep the dodge-first engine and patterns. Each boss gets **one signature mechanic no other boss has**, its fight built around it. Audit: RING patterns in 4 of 6 bosses, SPIRAL in 3, CROSS in 2; `marks`, `lanes`, `slam_ring` repeat. **Decide: G1** [`BOSS_SIGNATURES.md`](BOSS_SIGNATURES.md), row by row | BS |
| O6 | "the animations they do are a shit, actually. So we have to work on animations … like we did with the actual attacks of the player" | **Boss animation rework**: every attack gets a readable anticipation, strike and recovery, and a walk, hit and death that sell the weight. Today the six models carry no clips (`assets/models/bosses/*.glb`, no `animations`); they move by code (`BonePoser`, `BossRig`). Q4: code clips now, the owner's replace them later | BA |
| O7 | "If we need to generate textures for that, so … the attacks look real … long distance stonekeeper, it should be like spikes coming out of the ground that actually look like spikes and not … a red thingy" | Boss ground attacks become **3D effects** in the player-VFX style (textured sprites, meshes, lights, decals; `vfx_core.gd`), not flat red geometry (`telegraph_views.gd`). First: the Gatekeeper's (Stone Sentinel model) lanes erupt as rows of stone spikes. The tracked-then-locked marker stays readable before the strike | AV |
| O8 | "the orbs that they throw, they're 2D shit looking. We could look up for some textures online and use them to create actual 3D objects … that look and feel like the game's art" | Boss and enemy orbs (today two `SphereMesh` shells and a box trail per look, `fireball_views.gd`) become **3D shaded projectiles**: textured cores with a noise shader, a lit rim, a ribbon or particle trail, a small light for the big ones. Q5: CC0 now, the owner's generator can replace | AV |
| O9 | "a split and the other power that makes the attack divide when you hit an enemy. And they explode after it, and that causes hell of a lag … the game goes two, FPS. find a way of balancing with these animations … maybe we can stop applying some effects" | **Direct fix: a frame budget.** Spread (`gun_spread`) + Split (`split_shot`) + Explosive (`shared_explosive`): player shots have no alive cap and each explosion asks for blast, debris, smoke, sparks, a light and a decal (`vfx_layer.gd:310-371`). Measure the build in a repeatable probe first, then: merge and thin the effects past a budget (fewer sprites per explosion when many land together, no per-hit light past a few), and a sim cap only if the probe shows the sim is the cost. Target: 60 fps on the probe | PF |
| O10 | "the combinations for gun are way better than … blade. Blade is way more difficult to get a good … combination … not getting that that many modifiers in the blade as you get in the gun" | **G1** [`BLADE_AUDIT.md`](BLADE_AUDIT.md): every Blade and Gun card, what it does to the attack, and why Gun stacks (cards that multiply shots × hooks); the offer rates per weapon (today: 18 Blade-only cards vs 16 Gun-only, no weapon weighting). Proposals row by row (new Blade multipliers, buffs, rate) | BL |
| O11 | "the DPS is above 50K … per enemy … three enemies … over 150K … ultra omega deleting bosses … when you loop … it keeps being difficult … a lot more HP growing than health because the player doesn't grow in health that much" | **Ascension loop scaling**: enemy and boss HP grow much faster per loop, damage only a little (today per loop: enemy HP ×4, damage ×2; boss HP ×2, damage ×1.5; cap ×100). Q6: HP ×6, damage ×1.2 per loop, enemies and bosses. The 150K build itself: noted for BL/O10 (Gun stacking) | LS |
| O12 | "design maybe two, three rooms of each size and have them like nicely looking like the image we use for reference … more populated and feel more real … procedural generation to place them as templates … a room that could be in different directions, that size has three variations and we place them randomly" | **Designed rooms.** Today a room's inside is built by rules (`RoomInterior` cover templates + `RoomThemes` vignettes + `StageDresser`), and reads empty next to [`../../art/look_reference.webp`](../../art/look_reference.webp). New: **3 hand-designed layouts per room size** (1×1, 2×1, 3×1, 2×2, 3×2, 3×3, 4×3, 4×4 cells: 8 sizes, 24 layouts; a size's long side turns with the room), each an authored data file of cover, walls, props and lights, dense like the reference. The generator still builds every floor's map; it picks a layout for each room by its size, then turns it (4 ways) and mirrors it, so floors, loops and runs all differ. Each biome swaps the pieces (Ruins wrecks and crates, Night Rocks boulders and trees, Red Canyon mesas, Frozen Shore ice, Starfall crystals). Doorways stay clear wherever the map puts them. Built first with the kit we have; the owner's new pieces (ART_LIST) slot in. **G2:** shots of the first 3 layouts before the other 21 | RT |
| O13 | "this shop room that is gonna be designed in a way for each biome that will have like its own vendor like with a model and it will be like in a tent shop with some stuff I will give you a model for that" | **The shop room**: a designed room per biome (5), a tent stall with goods and a vendor character instead of today's terminal (`shop_terminal_view.gd`); the vendor idles, turns to you and reacts to a sale or a refusal. Code-made stand-ins until the owner's models arrive (tent, vendor per biome, goods; ART_LIST §1). Buying works as today | SR |
| O14 | "we are also reworking the menu we're just throwing away the shard cards we're gonna be using a different style that matches more the game … I found that that's not exactly aligned with the game" | **The crystal-shard card look goes** (the pick cards, Build page, wand pips, Codex tiles, plaques: `crystal_card.gd`, `card_frames.gd`, `plaques.gd`), and the menus get a style that matches the world: the weathered kit, warm fire light, dark stone and metal. **G2:** 3 mockup directions (menu + a pick card + the Build page) before building | MU |
| O15 | "work as far as you can without generating new models and give me the full list of things you need that I will be generating this afternoon" | Every step is built with code-made stand-ins where art is missing (L15); the full list of art is [`../../art/requests/v0.8.0_ART_LIST.md`](../../art/requests/v0.8.0_ART_LIST.md) | — |
| O16 | "a final boss right before choosing loop or ending, if ending is chosen then you fight the final boss, this would have 3 phases, with different combat in each one, I have a glb file that contain the three models … can you split it into three different models … a "plaeholder" that will be replace with actual cool animations I'll work … I want this final battle to be epic" | The owner's file split into three models by their separate pieces (no piece cut; [`FINAL_BOSS.md`](FINAL_BOSS.md) "The models"). **G1** [`FINAL_BOSS.md`](FINAL_BOSS.md) rows F1–F9 | FB |
| O17 | "One has a big stone hands … a fast moving pace fight … melee attacks, jumps … the spikes that come out of the floor … throw big rocks … the second phase … a ranged fight … rays that go in a cross and turn with her in the middle … a lot of small balls … quick, fast attacks … the third model, the small black one … the nemesis of the main character … mimics some of the movements of the main character … a mix of both a melee and range fight" (verbatim in FINAL_BOSS.md) | Phase 1 the Colossus (fists), phase 2 the Prism (shards), phase 3 the Nemesis (the small dark one); the lead's proposal per phase in FINAL_BOSS.md F4–F6 | FB |
| O18 | "make it a little bit bigger, maybe like 25% bigger, and the gun should shoot less bullets per second, but do the enough more damage to be able to maintain the DPS. So we lower the speed a bit" | The Gun's basic shot: **25 % bigger**; fire rate **×0.75** (lead's reading of "less bullets per second … lower the speed a bit"), damage **×1.333** so its DPS is unchanged; its flight speed **×0.9** ("a bit"). Starting values in data (F10). Gun cards that scale size, rate or damage keep their own multipliers on top | GF1 |
| O19 | "transform the square that comes out into a pulse, like a fireball, but it will be blue. The main character needs to have like a casting animation, just spark of light and swirl … every time a bullet comes out … very light" | The Gun's bolt becomes a **blue pulse fireball** (a lit 3D orb with a trail, in the hero's blue, off every hostile colour); the hero gets a **light cast flourish** on every shot: a spark of light at the hand and a small swirl, a quick arm/body accent; reduced motion keeps only the spark | GF1 |
| O20 | "the enemies, when hit by a bullet, should have particles where it hit and coming behind … a clear impact … the enemy should flinch. That doesn't mean to move … we keep the very short, just a couple of frames, that the enemy is highlighted in white" | Every bolt hit: **impact particles** at the hit point and a spray out the far side along the shot's direction; the enemy **flinches** (a quick pose recoil, no movement in the sim); the white hit flash stays (a couple of frames). Bosses flinch through their clip system | GF2 |
| O21 | "the damage numbers, a little bit bigger, just a bit, and they should come out like they are thrown from the enemy in a curve that goes up and out. And the crit should be a number that spawns bigger, it has a little shake, and then it vanishes" | Damage numbers **~15 % bigger**, **thrown** from the enemy in an up-and-out arc (alternating sides); crits spawn **bigger**, **shake** briefly, then vanish. For every hit (Gun and Blade) | GF2 |

## Design questions (owner, 2026-10-14)
- **Q1 (O2) Enemy colours:** each kind its own hue / by role (melee, ranged, support) / by floor.
- **Q2 (O3) Enemy models:** prompts for today's 14 kinds / also new enemy kinds.
- **Q3 (O4) Which ground marks stay:** only things that land at range (Arc Caster rune, Mine Layer mines) / also the
  Sniper line and Needle lanes.
- **Q4 (O6) Boss animation clips:** code-made keyframe clips by the lead / the owner makes clips (an AI animation
  tool or Mixamo) and the lead wires them / both.
- **Q5 (O8) Texture source:** free CC0 libraries (ambientCG, Poly Haven, Kenney; licence in the manifest) / the
  owner's generator with the VFX prompt prefix / both.
- **Q6 (O11) Loop scaling.**

Answers go into the "Owner decisions" table below the same day.

## Owner decisions
| Q | Answer (the owner's pick, verbatim) | What it means | Date |
|---|---|---|---|
| Q1 | "By role (Recommended)" | One colour family per role, shades differ inside a role: melee rushers red/orange (Charger, Hatchling, Swarmer, Splitter, Splitling), ranged casters blue/violet (Needle, Arc Caster, Sniper, Lens Drone), bombers and mines yellow (Bomb Drone, Mine Layer), support green (Mender), tanks bronze (Warden, Shield Bearer). Every hostile keeps a glowing eye and the enemy outline. A G2 sheet of the shades follows | 2026-10-14 |
| Q2 | "There are some enemies that have my model set those a side and prompt me for the ones that don't have" | The kinds built from the owner's designs stay as they are (Charger and Hatchling, Warden, Needle from `docs/art/enemies_visual_reference.png`; Arc Caster and Bomb Drone from F5/F6). Prompts for the kinds with no owner design: Swarmer, Splitter, Splitling, Shield Bearer, Mender, Mine Layer, Sniper (the `HordeAvatar` seven); the Lens Drone's prompt already stands in `../../art/requests/v0.7.5_bosses_2_models.md` | 2026-10-14 |
| Q3 | "Only things landing at range (Recommended)" | Ground marks stay only on the Arc Caster's rune and the Mine Layer's armed mines. Gone: Charger / Hatchling / Swarmer lanes, Splitter / Splitling disc, Shield Bearer lane, Warden disc, Sniper line, Needle lanes. Bosses keep their tracked-then-locked markers | 2026-10-14 |
| Q4 | "Code first, yours replace (Recommended)" | The lead builds keyframed clips per boss in code now; clips the owner makes later replace them | 2026-10-14 |
| Q5 | "Both (Recommended)" | Start with free CC0 textures (ambientCG, Poly Haven, Kenney; licence and source in the manifest) shaped to the palette; prompts for the owner's generator written alongside, and the owner's PNGs replace any of them | 2026-10-14 |
| Q6 | "HP ×6, dmg ×1.2 (Recommended)" | Per Ascension loop, enemies and bosses alike: HP ×6, damage ×1.2 (loop 2: ×6 / ×1.2; loop 3: ×36 / ×1.44; the ×100 cap stays). Starting values | 2026-10-14 |
| G2 EC | "Color palette A" | Enemies use palette A (saturated role colours, `EnemyPalettes.SHIPPED`) | 2026-10-14 |
| G2 MU | "menu style B" | The menus, pick cards, Build page and plaques take direction B, "Ember stone" (`evidence/MENU_G2.md`); the shard cards go | 2026-10-14 |
| G1 BOSS_SIGNATURES | "boss OK" | Rows S1–S6 approved as proposed (the main column, not the alternatives) | 2026-10-14 |
| G1 BLADE_AUDIT | "blade audit … OK" | Rows B1–B7 approved as proposed | 2026-10-14 |
| Loop cap | "keep de x100 loop" | The ×100 per-stat cap stays: loop HP stops growing at loop 4 (×100) while damage keeps ×1.2 a loop | 2026-10-14 |
| G2 RT | "New rooms are fine in density don't need anything else, follow the line of those to create the rest" | The 3 RT1 layouts are the model; the other 21 (3 per size for 1×1, 2×1, 3×1, 4×3, 4×4, and 2 more each for 2×2, 3×2, 3×3) follow their density and style | 2026-10-14 |

## Steps
| Step | Scope | Rows | Gate | Kind | Status |
|---|---|---|---|---|---|
| LS | Loop scaling: HP much faster than damage per Ascension loop | O11 | Q6 | sim + tests (data) | Done |
| TG | Wind-up without red ground marks for melee enemies; their bodies show the wind-up | O4 | Q3 | sim (telegraph `ground`) + presentation | Done |
| PF | Frame budget: a repeatable probe of Spread + Split + Explosive, then effect merging/thinning and caps until it holds 60 fps | O9 | none (direct fix) | presentation (+ sim cap only if measured) || Done (avg in budget, p95 not: [`evidence/PERF.md`](evidence/PERF.md)) |
| EC | Enemy colours per kind | O2 | Q1, then G2 | Done (palette A) |
| EM | Enemy model prompts, then the owner's models in game | O3 | Q2, then the owner's files | art + presentation | Waiting for the owner's models (prompts in `docs/art/requests/v0.8.0_enemy_models.md`) |
| BS | One signature mechanic per boss | O5 | G1 BOSS_SIGNATURES | sim + tests | Done: part 1 (`v080-bs1`: S1 Gatekeeper pillars, S2 Warlord shield + recalled javelins, S3 Brood Mother eggs; [`evidence/BOSS_SIGNATURES_1.md`](evidence/BOSS_SIGNATURES_1.md)); part 2 (`v080-bs2`: S4 Hive Lens Gaze, S5 Siege Engine ricochets, S6 Foundry lava + meltdown; [`evidence/BOSS_SIGNATURES_2.md`](evidence/BOSS_SIGNATURES_2.md)) |
| BA | Boss animation rework | O6 | Q4 | presentation (+ assets) | Done (`v080-ba`: keyframed clips per boss, timed by the sim's attack phase; [`evidence/BOSS_ANIMATIONS.md`](evidence/BOSS_ANIMATIONS.md)) |
| AV | Attack visuals in 3D: stone spikes, 3D orbs, textured boss ground attacks | O7, O8 | Q5 | presentation + assets | Done (AV1 `v080-av`: 3D orbs, the Gatekeeper's spikes; AV2 `v080-av2`: every boss ground attack; evidence ATTACK_VISUALS.md) |
| BL | Blade combinations | O10 | G1 BLADE_AUDIT | sim + data + tests | Done (`v080-bl`: B1–B7; Gun build −40-46 % DPS in the probe, Blade combo ×5.5; Blade Storm build over the frame budget, reported: [`evidence/BLADE.md`](evidence/BLADE.md)) |
| RT | Designed rooms: 3 layouts per size, turned and mirrored by the generator, per-biome pieces | O12 | G2 on the first 3 | sim (map) + data + presentation | Done (RT1 `v080-rt`: system + 3 layouts, G2 answered "follow the line of those"; RT2 `v080-rt2`: the other 21, every size, floor rules 5; [`evidence/ROOMS.md`](evidence/ROOMS.md)) |
| SR | The shop room per biome: a tent stall and a vendor | O13 | none (the owner's direction); the vendor's look follows the owner's models | presentation + data (+ sim map: the shop room's blockers) | Done (`v080-sr`: the owner's desert stall in every biome, code stand-ins for the rest; [`evidence/SHOP.md`](evidence/SHOP.md)) |
| MU | Menu and card style rework: the shard cards go | O14 | G2 (3 directions) | presentation only | Done (direction B "Ember stone" shipped on `v080-mu2`; [`evidence/MENU.md`](evidence/MENU.md)) |
| FB | The final boss: three phases (the Colossus, the Prism, the Nemesis) after "End the run" | O16, O17 | G1 FINAL_BOSS | sim + data + presentation + assets || Done (FB1 `v080-fb1`: the flow, the arena, the bar, the Colossus; FB2 `v080-fb2`: the Prism; FB3 `v080-fb3`: the Nemesis and the true ending; evidence FINAL_BOSS_1..3.md) |
| GF1 | The Gun: bigger, slower, harder-hitting blue pulse; the hero casts each shot | O18, O19 | none (owner direction) | sim (data) + presentation | Done (`v080-gf1`: 0.2 m, 9 ticks, 5, 16.2 m/s; DPS −2.9 % in whole ticks; the blue pulse and the cast; stacks' DPS up and the PF frame worse, reported: [`evidence/GUN_FEEL.md`](evidence/GUN_FEEL.md)) |
| GF2 | Hit feel: impact particles, flinch, white flash, thrown damage numbers, shaking crits | O20, O21 | none (owner direction) | presentation | |

**Waves (3 agents; 4 when small):** wave 1 PF + LS + TG; wave 2 RT (system + 3 layouts for G2) + AV + EC; then SR,
MU (after its G2), BS and BL (after their G1s), BA, EM (when the models arrive). The lead writes the G1s and G2s
while agents run.

### RT (designed rooms; the agent's reading, 2026-10-14)
- **Sizes.** A layout is drawn for a size class with its long side first (`RoomLayouts.key`): 1×1, 2×1, 3×1, 2×2, 3×2,
  3×3, 4×3, 4×4, 3 each (24). A long room (2×3, 3×2 …) takes its class's layouts turned so the layout's long side runs
  along the room's long side (two of the four turns); a square room takes any of the four. Every layout may be
  mirrored. So a 2×2 layout has 8 ways round, a 3×2 layout 4 per orientation of the room.
- **Data.** `RoomLayoutDefinition` (`src/content/defs`, category `room_layout`, `data/room_layouts/<x>x<y>_<n>.tres`,
  validated, found by `ContentScanner`): groups of pieces, each group at an anchor that is a fraction of the room (so
  the groups spread with the room's size: a 2×2 room is 18.6-33 m a side) and its pieces in metres from it. A piece
  is a sim blocker (`solid`: an axis-aligned footprint, drawn filling it with its kit piece at the layout's height) or
  drawn only (decoration anywhere; anything taller standing inside one of its group's blockers: "looks solid = is
  solid", validated). Lights are pieces too (a fire barrel blocker carries its light). `keep_clear` names the open
  fighting lanes (checked by a test). The `.tres` files are written by `scripts/content/room_layouts.py` from prefab
  clusters (corner, wall and free-standing clusters in metres); the three first layouts are built from them.
- **Doorways.** Doorways can be anywhere on an edge, so no band is reserved: at generation each group is kept whole or
  dropped whole. Dropped when a blocker would stand in a doorway's box (its width plus 1 m either side, 3 m deep), or
  when it fails the checks the themed vignettes already pass (doorways, start and gate clear; flush with a wall or the
  2.2 m slab gap from walls and other groups; the room one region at an enemy's clearance holding every doorway
  approach). Before that, of the turns and mirrors the room allows, the one putting the fewest blockers in doorway
  boxes is taken (the drawn one first, no extra draw). Over 40 run floors 78 % of the layouts' blockers stand (the
  rest give way to doorways); every floor stays whole (`tests/unit/sim/test_room_layouts.gd`).
- **Placement.** After the room templates are drawn, each room (in order) whose size has layouts draws a layout, a
  turn and a mirror from the `map` stream (no new sub-stream, so no EI-05 question). The start hall and the portal
  room keep their rules; so does the boss room (its own builder). The shop, the arenas and the Overrun room are chosen
  afterwards, from the floor as generated, exactly as before: "keep their existing rules" read as their selection
  rules, so such a room may hold a designed interior (SR redesigns the shop room). Rooms of a size with no layout yet
  keep today's `RoomInterior` + `RoomThemes` interiors, so the game works throughout (RT2: every size has three, so
  only a floor resumed from an older save keeps them).
- **Biomes.** Layouts name kit pieces; the dresser restyles a designed room's square cover (crate stacks, rocks) with
  the biome's `square_cover` (Frozen Shore, Starfall) or Night Rocks' rocks and dead trees, and its decoration with the
  biome's `decor_swap`. Car wrecks, slabs, broken walls and pillars stay the kit's in every biome until the owner's
  biome pieces arrive (ART_LIST).
- **Determinism and saves.** Same seed, same floor. Floors change on purpose: `RunState.FLOOR_RULES` 4; a floor saved
  under rules 1-3 is rebuilt without layouts (`RunState.designed_rooms`, `RunSaver.floor_tables`) and makes no layout
  draw, so it is the floor that was saved. Nothing new is hashed or saved (`WorldSnapshot.ADDED_SINCE_V05` unchanged).
  RT2: `FLOOR_RULES` 5 (every size draws a layout, so the map stream's draws and every new floor change again); a floor
  saved under rules 4 (RT1) is rebuilt with RT1's three layouts only (`RunState.rt1_rooms`, `RunSaver.RT1_LAYOUTS`),
  which gives RT1's floors draw for draw (checked against RT1's own code, evidence ROOMS.md RT2).
- **Density (starting values).** In a typical room (the middle cell size and wall halves) the three layouts block
  14.7-16.5 % of the floor; with their own grass, rubble and debris (counted as 1 m² a piece) about 27-31 % is dressed,
  before the dresser's own grass along the walls and rubble. A central lane is kept open in each.
- **G2.** Shots of the three (Ruins, and two other biomes) in [`evidence/ROOMS.md`](evidence/ROOMS.md). After the
  owner's pick, the other 21 follow the chosen direction.
- **RT2 (the other 21, after G2 RT).** Each size's three read differently: the 1×1s a three-corner nook, a centre
  block with lanes either side, two broken walls jutting on a diagonal; the 2×1s and 3×1s corners and wall clusters, a
  centre island or a line of islands with lanes along both long walls, a slalom of broken walls jutting from alternate
  walls (small rooms keep fewer, smaller groups: 10.9-14.8 % blocked in a typical room); the 2×2 to 4×4 add a ruined
  block centre, diagonal bands of blocks round an open middle, ruined building outlines (pillars and broken walls with
  2.4-3 m gaps) and wreck convoys, 11.8-15.7 % blocked (two 4×4s below RT1's 14.7-16.5 %, reported). New prefabs in
  `scripts/content/room_layouts.py` (small corners, wall spurs, the building outline and its broken corner, a central
  block, a diagonal band); RT1's prefabs and three layouts unchanged. The 4×4 layouts furnish ordinary 4×4 rooms only;
  the boss room keeps `BossRoomBuilder`.

### SR (the shop room; the agent's reading, 2026-10-14)
- **Room.** ShopPlacement's rule is unchanged (the same room, so arenas, routes and the Overrun room don't move);
  that room's interior is then replaced by the biome's shop room (`data/shop_rooms/<biome>.tres`, `ShopRoom`): a
  tent stall (the owner's desert stall's footprint, 4.0 × 3.4 m: a 0.9 m counter in front of the tent) facing the
  room's first doorway, a clear 6 × 3 m approach in front of the counter, and dressing groups (crates and goods, sacks, lantern
  posts, braziers, rocks; the dresser restyles kit pieces per biome). The interaction point is the counter (Shop.pos).
  No draw; a room where the stall finds no spot keeps the terminal (none over the test's 120 floors, bounded at 3 %).
- **Saves.** `RunState.FLOOR_RULES` 5; a floor saved under rules 1-4 rebuilds with its terminal
  (`RunState.shop_rooms`, `RunSaver.floor_tables`). Nothing new hashed or saved.
- **Look.** The owner's desert stall (`assets/models/shop/shop_tent.glb`, delivered during SR) in every biome until
  their own; its vendor is fused into the mesh, so the code vendor is hidden over it and the lantern shows a sale
  (brighter) or a refusal (red). Code stand-ins in the faceted style (`ShopStallView`, `ShopVendor`: a tent and a vendor
  per biome that idles, turns to you, nods, shakes; reduced motion: a glow instead of movement) draw whatever has no
  model (`ShopModels`; sizes and facing in ART_LIST §1). The look is OWNER ONLY.

### GF1 (the Gun's shot and the cast; the agent's reading, 2026-10-15)
- **Numbers** (`data/player/runner.tres`; the kernel `PlayerTable` and `PrimaryDefinition` defaults match): hit radius
  0.16 → 0.2 m (×1.25), interval 0.12 → 0.15 s (7 → 9 ticks: ×1/0.75 = 9.33 in whole ticks), damage 4 → 5 (×4/3 = 5.33
  in whole points), speed 18 → 16.2 m/s (×0.9). DPS 34.29 → 33.33 computed (−2.8 %), 34.2 → 33.2 measured: the closest
  whole pair (10 ticks / 6 is +5 %). Starting values (F10).
- **Range kept:** life 0.6 → 0.667 s (36 → 40 ticks), so the slower shot still reaches 10.8 m ("lower the speed a bit"
  read as the shot's speed, not its reach).
- **Heat kept a second:** `gain_bolt` 0.9 → 1.157 (×9/7; heat counts landed shots, and the Gun shoots 7/9 as often):
  Hot at 5.13 s, Overclock 9.63 s (5.17 / 9.72 before).
- **Cards:** their own multipliers on top, data unchanged; Split's shards keep the card's 0.08 m (not grown with the
  bolt); Rapid Fire's "+60 %" is +50 % in whole ticks now (+75 % before).
- **The pulse:** every hero shot that is not a hostile fireball or a shrapnel shard (HeroPulseViews, three MultiMeshes a
  look): the boss orbs' lit core shader with a pale cyan centre, the hero's cyan leaned 35 % to blue (hue 202°, normal
  colour mode only), a swelling additive glow, a short trail; no dark edge (the hostile mark). Not bluer: the Arc
  Caster's hostile plasma is periwinkle `#6E9CFF`.
- **The cast:** a spark at the casting hand (right of the aim, a little above the shot) and a small swirl round the aim
  on each shot (`WorldReader.shot_fired`), pooled (4), merged within 6 ticks; a 0.13 s body accent (kick back, head
  turn, hood flick, visor flare). Reduced motion: the spark only.
- **Reported, not tuned:** the Spread + Split + Explosive stack's DPS +12 % (+44 % with Twin: the bigger bolt lands
  more of a fan and a twin pair), and the PF probe's avg frame +0.5 to +2.6 ms (the pulse's draw; every avg but one
  noisy run within 12 ms). Owner questions in GUN_FEEL.

## Audit (live code, 2026-10-14)
- **Enemies:** 14 kinds (`data/enemies/*.tres`), all code-made avatars (`actor_views.gd:343-452`); 7 share
  `HordeAvatar` (Swarmer, Splitter, Splitling, Shield Bearer, Mender, Mine Layer, Sniper). Colours are constants per
  avatar, all red #D8433A-ish + grey #5F5551 + eye #FF2A22 (e.g. `charger_avatar.gd:37-46`, `horde_avatar.gd:17-25`);
  the Mender alone has green. Biomes tint only the greys (`actor_views.gd:245-253`).
- **Telegraphs:** decided by `EnemyAi.telegraph()` (`src/sim/ai/enemy_ai.gd:664-712`); `"ground": false` hides one
  (`telegraph_views.gd:96`). Ground marks today: Charger / Hatchling / Swarmer lanes, Splitter / Splitling disc,
  Shield Bearer lane, Warden disc, Sniper line, Needle lanes, Arc Caster rune, Mine Layer mines. The Bomb Drone's lob
  has no landing mark since v0.7.5 EF.
- **Bosses:** pattern kinds RING / SPIRAL / CROSS / WALL / FAN / FLOWER / BURST; RING in Gatekeeper, Brood Mother,
  Hive Lens, Foundry; SPIRAL in Brood Mother, Hive Lens, Siege Engine; CROSS in Gatekeeper, Siege Engine; all shots
  3-5 m/s. No `.glb` has animation clips; Warlord (41 bones) and Hive Lens (23) are skinned; the rest are rigged in
  code (`boss_rig.gd`). Boss ground attacks are flat unshaded triangles (`telegraph_views.gd:34-70`). Orbs are two
  sphere shells and a box trail per look (`fireball_views.gd:351-361`). The player's VFX: owner PNG atlases on pooled
  camera-facing quads with a noise shader, pooled lights (10) and decals (64) (`vfx_core.gd`).
- **Cards:** offerable Blade-only 18, Gun-only 16, shared 24; no weapon weighting (`item_pool.gd:22-71`). Split is
  `split_shot` (on hit, 3 at half size, +1/level); Spread is `gun_spread` (+2 shots); Explosive is `shared_explosive`
  (on end, 1.4 m, 60 %).
- **Caps:** hook depth 2, 256 launches a tick (`attacks.gd:25-26`), watchdog 512 events a tick; player projectiles
  have no alive cap. Per explosion: 3 blast + 4×density debris + 5× smoke + 10× sparks + a light + a decal
  (`vfx_layer.gd:310-371`); pools cap sprites at 2,000 a frame (`vfx_core.gd:37-41`).
- **Loop scaling** (`data/run/three_floors.tres`, `run_state.gd:100-175`): per loop enemy HP ×4, damage ×2; boss HP
  ×2, damage ×1.5; cap ×100; threat +2. Floors: enemy HP 1000 / 1900 / 3610 ‰, damage 1000 / 1400 / 1960 ‰. Stat
  cards stack multiplicatively (`stats.gd:4-9`).

## Open items
- v0.7.5 is not in `main` yet (PR riusprime/zero-depth#6): the owner merges it.
- v0.7.5's open questions still stand (Siege Engine and Foundry gap-closers, EI-05 sub-streams, the credit line, the
  AI generator's terms).

## Verification
- Agents: lint + the folders they touched + their e2e. The lead: `scripts/ci/seams.sh` after each merge. The PR into
  `main`: the full suite once on GitHub.
- PF: the probe's frame times before and after, pasted raw in `evidence/PERF.md` (headless frame time is the CPU
  side; the owner's fps on their PC is **OWNER ONLY**).
- Balance numbers are starting values; feel is **OWNER ONLY** (no bot sims, LOCKED 2026-10-08).

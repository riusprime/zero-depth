# v0.8.0 — Fights and feel: the owner's v0.7.5 playtest (plan, owner-approved 2026-10-14; G1s pending)

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

## Steps
| Step | Scope | Rows | Gate | Kind | Status |
|---|---|---|---|---|---|
| PF | Frame budget: a repeatable probe of Spread + Split + Explosive, then effect merging/thinning and caps until it holds 60 fps | O9 | none (direct fix) | presentation (+ sim cap only if measured) | |
| LS | Loop scaling: HP much faster than damage per Ascension loop | O11 | Q6 | sim + tests (data) | |
| TG | Wind-up without red ground marks for melee enemies; their bodies show the wind-up | O4 | Q3 | sim (telegraph `ground`) + presentation | Done |
| EC | Enemy colours per kind | O2 | Q1, then G2 | presentation only | |
| EM | Enemy model prompts, then the owner's models in game | O3 | Q2, then the owner's files | art + presentation | |
| BS | One signature mechanic per boss | O5 | G1 BOSS_SIGNATURES | sim + tests | |
| BA | Boss animation rework | O6 | Q4 | presentation (+ assets) | |
| AV | Attack visuals in 3D: stone spikes, 3D orbs, textured boss ground attacks | O7, O8 | Q5 | presentation + assets | |
| BL | Blade combinations | O10 | G1 BLADE_AUDIT | sim + data + tests | |

**Waves (3 agents; 4 when small):** wave 1 PF + LS + TG (as their gates clear); wave 2 EC + AV + BS; wave 3 BA + BL
+ EM. The lead writes the G1 audits while wave 1 runs.

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

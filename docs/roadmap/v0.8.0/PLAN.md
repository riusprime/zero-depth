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
| O22 | "we have to do the exact same exercise to the blade, animations, hit enemy, flinch, hit animation, what we did to the gun but applied to the blade, also for the blade and flinch we add a 2 frame or so freeze to make the hit feel better" | **The Blade gets the Gun's treatment**: a richer swing (wind-up, swing, follow-through on the hero, a bright slash trail in the hero's colours), a blade **impact** on every slash hit (a cut flash and sparks along the slash's direction, bigger than GF2's 0.6 share), a stronger **flinch** on the struck enemy, and a **hit-stop**: on a Blade hit the hero's swing and the struck enemy freeze for about 2 frames (~33 ms) with a tiny camera kick. Lead's reading: the freeze is in presentation (the sim keeps its 60 Hz clock, EI-03), so timing, saves and replays don't change; the Blade's numbers don't change (the owner asked for its look and feel) | GF3 |
| O23 | Playtest 2 (2026-10-16): "Enemies don't consistently find the shortest valid path toward the player, sometimes getting stuck behind walls or in adjacent rooms instead of pursuing" | **Direct fix**: one shared distance-to-the-hero field over the floor's walkable cells, recomputed when the hero changes cell; every chasing enemy steps down it (cheaper than per-enemy steering) | P1 |
| O24 | "The Void spell is buggy, and its current enemy-pulling mechanic is unsatisfying. Change Void so shots have a chance to spawn a small black hole lasting 2 seconds, attracting nearby enemies and dealing damage" | **Change**: Void's pull is removed; each shot has a chance (starting value 8 % at level 1, rising with level) to spawn a black hole (2 s, pulls and damages nearby enemies; at most 3 alive) | P2 |
| O25 | "The large ground-smashing enemy no longer displays its red circular attack warning. The large enemy also needs a visible ground-smash animation" | **Fix**: the Smasher joins the Arc Caster rune and the Mine Layer mines as the third exception to O3's no-red-ground-marks rule (the owner's line supersedes O3 for this enemy); a full overhead slam with a dust ring | P1 |
| O26 | "Some other enemies have unclear attack animations. Their arm movements don't communicate attacks properly, making it difficult to understand why the player was hit" | **Fix**: every melee enemy raises and holds its strike pose through the wind-up, then strikes with a clear motion | P1 |
| O27 | "Bosses animations should be a bit faster … you should rely on dashing as a mechanic … the throwing javelins should come and go faster or some jumps … difficulty should be increased and more skill … not making them unkillable by the blade … bosses should also kill you in 3-4 strikes … small balls 4-5 big attacks 2" | **Design, next version** (owner, 2026-10-16: the design items go into the next version's PLAN). Lead's proposal: faster javelins and some jumps, each boss keeps one or two slow readable attacks, a punish window after big attacks for the Blade, damage set by hits-to-kill | next version |
| O28 | "I could not fight the last boss, could only choose between ascension ending or looping"; then (2026-10-16) "Final boss should not be at the end the run … it should be a continue flow, and you can pick a small different device than the ascension to loop we separate it into two different actions from now on, not a menu, two different visual elements the ascension to go fight final boss or the loop element, separated" | **Change**: the loop's last floor shows **two separate devices**, no menu: the **Ascension** portal (walk in: on to the final arena and the final boss) and a smaller **Loop** device (walk in: the next loop's first floor). "End the run" as a choice goes; the run ends by beating the final boss (or dying) | P2 |
| O29 | "The Star biome runs smoothly, but the Red, Blue, and Original biomes experience lag … possibly related to lighting. Compare the affected biomes against the Star biome" | **Direct fix**: measure each biome against Star on the same probe, fix the largest costs; numbers in evidence | P3 |
| O30 | "Lighting sometimes changes abruptly as the player moves through rooms, appearing to switch on and off" | **Fix**: lights fade in and out by distance and budget instead of switching | P3 |
| O31 | "Glow intensity is still excessive across all biomes, particularly on barrels, torches, and the main character. Keep the atmospheric illumination but reduce the glow so it doesn't obstruct visibility" | **Fix**: glow down (barrels, torches, the hero first), ambient light kept; before/after shots per biome | P3 |
| O32 | "Look for ways to make the game more efficient, not changing graphic or animations itself but making less calculations improving the code" | **Fix**: a pass that cuts repeated work (queries, lookups, per-frame rebuilds); nothing visible changes | P3 (and P1's field) |
| O33 | Items, rarity and builds: broken builds still possible, "approximately once every 10–15 runs"; "item rarity levels, similar to the existing spell levels"; legendaries from bosses; "Infinite loops should eventually allow players to accumulate extremely powerful combinations" | **Design, next version.** Lead's proposal: Common/Rare/Epic/Legendary; the build-breaking cards (with a Legendary pre-nerf explosion) drop mostly from bosses, odds set by the balance sim to ~7–10 % of runs; more boss drops per loop | next version |
| O34 | Health: early game leans on healing; first-loop healing out-heals damage; "Consider replacing numerical HP with approximately 4–6 hearts … red crystal shards"; then (2026-10-16) "Let's just pause the hearts for now" | **Paused** by the owner. The early-game and healing points stay open for the next version | paused |
| O35 | "After completing the first loop and entering a Purple Portal, the combined difficulty increase is very significant … The increased challenge is enjoyable and should remain. Reduce the difficulty of this specific combination (second loop + Purple Portal) by approximately 10%" | **Change**: only that combination gets about 10 % easier; loop 2 alone and the Purple Portal alone are unchanged | P3 |
| O36 | Utility items: "more miscellaneous and utility items that introduce different gameplay mechanics" (closer = more damage, a second dash, more bleed, a stronger or bigger L1 secondary, and more) | **Design, next version**: a G1 list of about 20 mechanic cards, approved row by row | next version |
| O37 | Weapon combinations: "make the order of the attacks be more important … a modifier of the basic attack makes the attack … a circle of lightning, and then 3 attacks make a triple circle … a swirl card that makes the circle go out randomly making it a 'storm' … Not every single mod should have an impact on the order but they should have it" | **Design, next version.** Lead's proposal: shape, count and motion cards each change what is left of them; stat cards stay order-free; prototype the Ring → Triple → Swirl chain first | next version |
| O38 | (2026-10-16, on the part 2 question) "I'll playtest this while you build the second part of this update" | **Part 2 joins v0.8.0** (not the next version): O27 → BP, O33 → RR, O37 → AO, built from the lead's proposals in O27/O33/O37; O36 → UC, whose card list is a G1 the owner approves row by row before it is built. Hearts (O34) stay paused | BP, RR, AO, UC |
| O39 | Playtest 3 (2026-10-16, in OWNER_TODO): "colors are still a bit to dimmed so yellow orange and red are close because of the room lighning" | **Fix**: the role colours stay apart under every biome's lighting (palette A brighter / less tinted by room light) | next |
| O40 | "if I play a floor long enough the bosses become too easy still"; "the hardest is always first if floors are played for long enough"; "got broken build if I played floors for long enough more often than expected" | **Design**: time spent on a floor makes the hero outgrow its boss; bosses (and the odds of a broken build) must not depend on farming a floor. Lead's proposal to agree: the boss scales with the hero's power (or the floor's time), not only the floor index | next (proposal) |
| O41 | Final boss: "it was one of the easiest fights of the run because I was too OP … most spells were easy to dodge, we have to have the really hard to dodge spells, and a pretty intense fight that each phase takes 1-2 minutes 1 minute being the most op and longer if you are not op, oneshoting (killing a phase in seconds should never happen)" (also the answer to D1) | **Change**: each phase lasts 1–2 min (about 1 min at the strongest build, longer if weaker), never killed in seconds; harder-to-dodge attacks | next |
| O42 | D3/D36: "it should mimic and nerf you into what he has so the match is even and it is more difficult and makes you less broken"; D4: "change nemesis for The Fallen" | **Change**: the third body is renamed **The Fallen**; while it fights it mimics your build and pulls you down to its level (an even duel) | next |
| O43 | "blade is worth taking damage wise but we have to balance damage reduction for blade it is way easier to die since you have to be closer to kill" | **Change**: the Blade gets damage reduction (it fights close) | next |
| O44 | "we will work on a final menu with a 3d animation 'gif' with the main character and a chest being opened … the blade and gun need to look professional they don't yet, some arts might be needed" | **Later / art**: a 3D main-menu scene (the hero opening a chest); professional Gun and Blade models (OWNER_TODO §3) | art |
| O45 | "we have to add loading screens so the game does not freeze when you start the game and take a portal, these could be fades into black and a little loading symbol on a corner, and the load between floors in portal an animation that covers the screen with the color and animation style of the portal you cross and then unveils it back at the new floor" | **Change**: a fade to black with a small loading mark in a corner (game start, loads); portal travel covers the screen in that portal's colour and style, then unveils the new floor | next |
| O46 | "We still have a bug with some fire drowings popping randomly in position and timing through the whole screen … I think it is the art for fire because it happens really fast" | **Fix (bug)**: fire sprites flashing at random spots on screen | next |
| O47 | D24/D25: "the circle should substitute the fireball not be a circle that spawns where you aim"; "it was quite broken, maybe substituting the fireball for a shooting ring is better balanced"; D26/D27 "we are gonna change this" | **Change**: Ring turns the shot itself into a travelling ring (no circle cast at the aim point); retune its power; caps and Swirl's stream follow the new shape | next |
| O48 | D18: "OK but we could make it a 20% more noticeable" | **Change**: the Blade's hit-stop about 20 % stronger (both freezes kept) | next |
| O49 | D21/devices: "yes the were side to side, we can work some 3D cool models for this" | **Art**: 3D models for the Ascension portal and the Loop device (OWNER_TODO §3) | art |
| O50 | D8: "dmg is OK but difficulty should be higher at some points"; D6: "this is fine only if the boss fight takes longer and it is more difficult" | Folded into O40/O41 (boss length and difficulty) | next (proposal) |
| O51 | (2026-10-16) "D38 for now let's keep it as is but noted so we can work in the future" | D38 stays open as a future item; N2 drops "bosses keep up with a farmed floor" | — |
| O52 | "the 'the Nemesis renamed The Fallen: it mimics your build and pulls you down to its level;' should only be at certain times not the whole fight, so on and off" | **Change**: The Fallen's mimic-and-nerf comes in timed windows during its phase, not all the time | N2 |
| O53 | "everytime I run a git pull it feels like I play the same run with same start, and same object … every run should run a random seed for it before the game starts so it never feels the same, even if the game takes longer to load" | **Bug, confirmed in code**: `main.gd` starts every launch at the fixed seed `STAGE_SEED` (20261006) and adds 1 per run, so the first run of every session is the same. Fix: a fresh random seed for every new run (drawn outside the sim, at run start); tests and the dev panel keep a fixed seed on purpose | N1 |
| O54 | "D42 yes to that" (the lead's chat proposal: the crossed blades for physical / Blade cards, the star burst for Legendary / cosmic cards) | **Change**: the two spare glyphs get those meanings | N1 |
| O55 | "also to this batch with the fire texture bug that appears a lot and dissapears give a check to lighting again so the game properly renders all the lightning" | **Fix**: the fire bug (O46) plus a lighting audit: every light and glow renders where and when it should (no popping, no missing lights) | N1 |

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
| D1, D3, D4, D36 | see O41, O42 | The Prism's 60 s is replaced by O41 (1–2 min a phase); the Nemesis becomes The Fallen and mimics and nerfs you | 2026-10-16 |
| D2 | "it is fine" | Blade Storm keeps its 36-blade cap | 2026-10-16 |
| D5, D6, D8, D37 | see O40, O50 | Kept for now; boss difficulty moves to O40/O41 | 2026-10-16 |
| D7, D10, D11, D14, D30 | "OK" / "OK for now" / "yes" | As built | 2026-10-16 |
| D9 | "delete the crystal card arts" | The old crystal card art stays deleted (not restored) | 2026-10-16 |
| D12 | "doesnt apply after boss updates" | Closed | 2026-10-16 |
| D15 | "waiting for last updates for this" | Merge to `main` after the next build | 2026-10-16 |
| D16, D17, D19 | "gun feels OK", "KEEP", "it is fine" | As built | 2026-10-16 |
| D18 | "OK but we could make it a 20% more noticeable" | O48 | 2026-10-16 |
| D21 | "yes we'll make 3d models for both later" | As built; models in O49 | 2026-10-16 |
| D24–D27 | see O47 | Ring becomes a travelling shot | 2026-10-16 |
| Credits | "Rius" | `CREDITS_OWNER` = Rius | 2026-10-16 |
| Tripo terms | "yes" | The owner confirms the AI 3D generator's terms allow shipping its models | 2026-10-16 |
| Windows | "it worked, will confirm in future builds" | The Windows export ran on the owner's PC | 2026-10-16 |
| D38 | "keep it as is but noted so we can work in the future" | Open, for a later version (bosses vs a farmed floor) | 2026-10-16 |
| D39 | "go for D39" | The Blade: −25 % damage taken while held | 2026-10-16 |
| D42 | "yes to that" | Crossed blades = physical / Blade cards; star burst = Legendary / cosmic cards | 2026-10-16 |
| N1–N3 | "n1 is OK … N3 is OK, add this to this batch's queue" | Built in v0.8.0 | 2026-10-16 |

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
| GF2 | Hit feel: impact particles, flinch, white flash, thrown damage numbers, shaking crits | O20, O21 | none (owner direction) | presentation | Done (`v080-gf2`: impacts, flinch, thrown numbers, shaking crits; [`evidence/HIT_FEEL.md`](evidence/HIT_FEEL.md)) |
| GF3 | The Blade: swing, slash trail, impact, flinch, a 2-frame hit-stop | O22 | none (owner direction) | presentation | Done (`v080-gf3`: the swing accent, slash edge and edge spark; the slash impact along the swing; a stronger flinch with a knock; the view's 2-frame hit-stop with its Accessibility option; the sim's own hit-stop found and reported: [`evidence/BLADE_FEEL.md`](evidence/BLADE_FEEL.md)) |
| P2 | Void's black holes; the Ascension portal and the Loop device as two separate things, the final boss reached through Ascension | O24, O28 | none (owner direction) | sim + data + presentation | Done (`v080-p2`: Void's pull on every hit replaced by black holes, 8 % a shot + 3 % a level, 2 s, at most 3, pull and damage over time; the choice panel gone, the Ascension portal walks on to the final boss and the green Loop device beside it starts the next loop; [`evidence/VOID_AND_PORTALS.md`](evidence/VOID_AND_PORTALS.md)) |
| P1 | Fights read and chase: shortest-path chasing (a shared field), the Smasher's red circle and slam, clear melee strike poses | O23, O25, O26, O32 | none (direct fixes) | sim (chase) + presentation | Done (`v080-p1`: the existing shared flow field (`NavField`) is now an octile shortest-path field (bucketed Dijkstra, integer 5/7 steps), seeds from the free cells next to a player standing against a wall or in a doorway (the old flood reached nothing there, so every enemy out of sight walked into the walls), and the world's flood stops 4 m past the farthest enemy and is skipped with no enemy alive (O32); the "Smasher" is the Warden: its red slam circle is back on the ground and its model does a full overhead slam with a dust ring the size of the circle; every melee kind raises its strike pose by 35 % of the windup's progress, holds it, and snaps the strike out at the hit tick. [`evidence/CHASE_AND_STRIKES.md`](evidence/CHASE_AND_STRIKES.md)) |
| P3 | Biome lag against Star, lights that fade instead of switching, less glow, a cheaper-code pass, loop 2 + Purple Portal 10 % easier | O29–O32, O35 | none (direct fixes) | presentation + data | Done (`v080-p3`: "Red, Blue, Original" read as Red Canyon, Night Rocks, Ruins; their lag was the kit's scattered grass, rubble and debris (~20.7 M triangles a floor in floor-wide MultiMeshes, never culled, drawn in every shadow pass; Starfall's and Frozen Shore's code-made pieces ~0.5 M): now chunked per 16 m and drawn from their coarsest level of detail, the look kept; on the software renderer the three went from ~4× Starfall's CPU per frame to ~1.35× (gap reported, not closed); the fire lights' shadows fade and hand over within a budget of 4, far lights fade out; glow down in every biome (most in Starfall and Frozen Shore), the barrels' and braziers' flames and the hero's visor dimmer, ambient kept; occlusion through a per-floor wall index (views' tick work −10-30 % on a floor); a Deep floor past loop 1 ×0.9 HP and damage (`loop_deep_ease_permille` 900); evidence [`evidence/BIOME_PERF_AND_LIGHT.md`](evidence/BIOME_PERF_AND_LIGHT.md)) |
| UC | Utility and mechanic cards (about 20) | O36, O38 | G1 ([`UTILITY_CARDS.md`](UTILITY_CARDS.md), row by row) | sim + data + presentation | G1 written, waiting for the owner |
| AO | Attack order prototype: shape, count and motion cards change what is left of them; Ring → Triple → Swirl (a lightning circle, three shocking circles, a storm); stat cards stay order-free | O37, O38 | none (prototype for the owner to try) | sim + data + presentation | Done (`v080-ao`: cards have an order kind; new rare Gun cards Ring (shape: a 2.5 m shocking lightning circle ahead; a count left of it becomes pulses, a Swirl left of it throws the group) and Swirl (motion: right of rings, each thrown to a random spot, the storm); Spread and Halo are the count cards (right of a Ring: more rings, 0.85 each); shock arcs and storm strikes; tiles show `n · ← shape/count/motion`, reorder as before; caps: 5 pulses, 48 rings, 64 ring shards; worst order (Ring · Spread · Split L5) 13.36 ms avg, over, reported; no golden moved; [`evidence/ATTACK_ORDER.md`](evidence/ATTACK_ORDER.md)) |
| RR | Rarity: Common / Rare / Epic / Legendary on cards; build-breaking cards (with a Legendary pre-nerf explosion) drop mostly from bosses; odds for a complete broken build in ~1 run of 10–15; more boss drops per loop | O33, O38 | none (owner direction, lead's proposal) | sim + data + presentation | Done (`v080-rr`: four tiers on every mod card (`EPIC` appended to `ItemDefinition.Rarity`), each tier's draw weight per source (altar 1 / 1 / 0.5 / 0.02, chest and shop 1 / 3 / 1.5 / 0.05; common and rare draw as before); Legendary: the three ×2 triggers and the new **Chain Blast** (the pre-nerf Explosive: its splits and casts explode, its blasts never merge); Epic: Split, Twin, Blade Storm, Riposte Chain; `data/legendary` (the boss's altar) folded in: its first card is a Legendary card at 12.5 % on loop 1, +5 % a loop, and each loop past the first gives one more pick (up to 4); a boss's core gives no Legendary card now. Odds by Monte Carlo over the game's own draw functions (`scripts/checks/rarity_odds.gd`, 3000 runs a weapon, an upper bound on access): broken by the end of loop 1 Gun **9.37 %**, Blade **6.10 % (under the 7–10 % band, reported)**, both 7.73 %; Legendaries held by loop 1–5 ≈ 0.41 / 1.50 / 3.12 / 3.92 / 4.0; 97.5 % of them from bosses. Tier words and colours on reward, shop, boss-altar and Codex cards (Rare now blue), en + es. Evidence [`evidence/RARITY.md`](evidence/RARITY.md); owner questions D29–D35) |
| BP | Boss pace: faster javelins and some jumps (each boss keeps one or two slow readable attacks), a punish window after big attacks for the Blade, boss damage by hits-to-kill (small orbs 4–5, big attacks 2) | O27, O38 | none (owner direction, lead's proposal) | sim (data + AI) + presentation | Done (`v080-bp`: every boss attack has a hit class (`hit_class` small / medium / big, `orb_damage` for the orbs beside a bigger hit); at the data's damage against the base hero's 100 HP: orbs, shots and eggs 22 (5 hits), javelins 25 (4), strikes, lanes, beams 30 (4) or 34 (3), leaps, charges, slams and single beams 50 (2); the floor and loop factors (×1.2 a loop, O11) scale on top. Faster: the Warlord's javelins (0.6 → 0.45 s wind-up, 4.5/5.0 → 6.5/7.0 m/s, stuck 1.0 → 0.5 s before they fly back) and lunge (1.4 → 1.0 s, 20 m/s), the Brood Mother's leaps and pounce, the Hive Lens's dive and focus beams, the Gatekeeper's fist slams, the Siege Engine's rails and shockwave, the Foundry's vent blast and bombs, the Colossus's leap slam and boulders; the 0.8 s lock (owner N15) and the Colossus's 0.5 s kept, so the dodge window is the same; each boss keeps its signature and one more slow attack. Every big attack ends in a still 0.6–0.9 s recovery with its weak point open (no follow-up skips it). Sim checks: every sped-up attack is dodged by a dash 0.3 s after its telegraph; a scripted Blade-only hero kills each boss in 70–137 s and beats the final boss in 156 s. The Nemesis is unchanged (its F7 cap of a fifth of your HP conflicts with 3-4 strikes: owner question). [`evidence/BOSS_PACE.md`](evidence/BOSS_PACE.md)) |
| TX | Install the owner's 29 textures and VFX (2026-10-16; `fx_rail_streak` still owed) in place of the code-made looks named in `docs/art/requests/v0.8.0_textures.md`: TX1 attacks (orbs, trails, beams, aim lines, cast sigils), TX2 ground and impacts (cracks, rock burst, lava, rings, splats, steam, skids, shatter, marks, stone spike), TX3 menus, glyphs, ambient motes | owner art (the 2026-10-15 texture request, OWNER_TODO §3.7) | none (the owner's art) | assets + presentation | In progress; TX3 done (`d4ee403`: menu stone, wall, sparks, element glyphs, star motes; [TEXTURES_3](evidence/TEXTURES_3.md)); TX1 done (`9daf98b`: 8 attack textures; [TEXTURES_1](evidence/TEXTURES_1.md)) |
| N1 | Playtest-3 fixes: role colours apart under room light, the fire sprites flashing across the screen and a lighting audit, the Blade's hit-stop +20 %, the Blade's damage reduction (D39: −25 % while held), a random seed for every new run, the two spare glyphs (D42), the credit line "Rius" | O39, O43, O46, O48, O53–O55 | D39 go | presentation + sim (data) + app | In progress |
| N2 | The final boss: 1–2 min a phase however strong you are, never killed in seconds, harder-to-dodge attacks; the Nemesis becomes The Fallen, which mimics and nerfs your build in timed windows (on and off) | O41, O42, O52 | none (owner go) | sim + data + presentation | Queued |
| N3 | Ring as a travelling shot (replacing the cast circle), retuned; loading fades with a corner mark; portal transitions in each portal's colour and style | O45, O47 | none (owner go) | sim + presentation | Queued |
| GF1 | The Gun: bigger, slower, harder-hitting blue pulse; the hero casts each shot | O18, O19 | none (owner direction) | sim (data) + presentation | Done (`v080-gf1`: 0.2 m, 9 ticks, 5, 16.2 m/s; DPS −2.9 % in whole ticks; the blue pulse and the cast; stacks' DPS up and the PF frame worse, reported: [`evidence/GUN_FEEL.md`](evidence/GUN_FEEL.md)) |

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

### GF3 (the Blade's swing, impact, flinch and hit-stop; the agent's reading, 2026-10-15)
- **Presentation only.** The Blade's numbers, `src/sim/` and the input are unchanged; the existing laser blade, its
  trail, the slash forms and BladeFormView are kept as they are (owner, v0.6: "sword animation stays as is for now I like
  it") and the new looks are layered on top.
- **Swing:** a per-step accent on the hero model timed from the sim's swing ticks (`swing_tick`, `swing_active_tick`,
  `swing_sweep_ticks`, `swing_ticks`, `is_finisher`): wind-up up to the hit tick (the sim's steps hit on tick 2-7, so
  the wind-up is 1-6 ticks long), the swing from the hit through the sweep, a follow-through over the recovery; the
  finisher ×1.6; reduced motion drops the follow-through (the overshoot). A bright slash edge in the hero's blue-white
  over the trail (the step's element tints it; the heat tier from Hot up) and a pooled spark on the blade's tip that
  flares on the hit tick.
- **Impact:** a slash's own impact: a cut along the swing's tangent and sparks thrown along it (a thrust's along its
  aim), strength 1.1 (a bolt's 1.0; GF2's 0.6 share is gone), the finisher ×1.3, drawn on the struck body's side
  toward the camera so the body doesn't hide it; the GF2 budget, merging and pools.
- **Flinch:** a slash's is ×1.35 a bolt's and knocks the pose up to 0.09 m away from the swing (the pose only).
- **Hit-stop:** in the view (EI-03; the lead's reading in O22): on a Blade hit the hero's model, the laser blade and
  its trail, each struck enemy's model (at its flinch's peak) and its white flash hold for 2 frames (2/60 s of frame
  time) with a 0.06 m camera kick (0.1 m on the finisher); one swing's hits share one freeze; a new one at least
  9 ticks (0.15 s) after the last began; Options → Accessibility "Hit-stop" (on by default) and reduced motion turn it
  off. **Found, for the lead and the owner:** the sim already has a Blade hit-stop: every landed swing adds the step's
  `hitstop_ticks` to `World.freeze_ticks` (3, 3, 4 and 7 ticks for the four steps, `data/player/runner.tres`;
  SIM_CONTRACTS §2), which holds the whole sim; PRESENTATION_CONTRACTS §6 says "Hit-stop is sim state … The view shows
  it; it never creates it." The view's hold is built as briefed and sits inside that sim freeze; whether to keep both,
  or to make the view show the sim's freeze instead, is an owner question (BLADE_FEEL.md).

### P2 (Void's black holes; the Ascension portal and the Loop device; the agent's reading, 2026-10-16)
- **Void (O24), what was there.** `gravity_well` (Void) put an `ON_HIT` hook on the spell: every landed hit set off a
  2.5 m burst at 20 % (+10 % a level) that moved each enemy it touched up to 0.8 m toward the hit in one tick, before
  the burst's own hits (`ModifierRuntime.pull`). "Buggy", read from the code (not reproduced in play, the owner's
  word stands for what they saw): every hit of every bolt of a Spread or Split volley teleported the enemies by up to
  0.8 m at once, so crowds jerked and stacked on the hit point, and a 0.8 m jump could carry one into or past a thin
  wall before the collision pass pushed it out (sometimes on the far side). The pull, its runtime and the `pull_m`
  card field are gone (the spec field stays for the hash order, never set).
- **New (starting values, F10).** Each shot carrying Void (a projectile of the spell where it ends: the hit that
  stopped it, a wall or the end of its flight; on the Blade, a slash where it first lands) leaves a black hole with
  a chance of **8 % at level 1, +3 % a level: 8 / 11 / 14 / 17 / 20 %** (`hole_chance_permille` 80 + 30, the card's
  data). One draw on the existing **`ability`** stream per shot or landing slash, only for a spec with a chance (a
  build without Void draws nothing; no new stream, so no EI-05 question). The hole stands **2 s** (120 ticks), **at
  most 3** (a new one replaces the oldest), draws every enemy within **3.5 m** toward its centre at **3 m/s**
  (0.05 m a tick: no jump through walls; not bosses, nor enemies still spawning in; it stops 0.3 m short of the
  centre) and every **0.2 s** pulses **30 % of the shot's damage** (rounded, at least 1) on each enemy within its
  **1.4 m** core, as damage over time (TAG_DOT, proc 0: it never sets off the spell's cards). Numbers in
  `data/wand/wand.tres` (`hole_*`) and the card (`data/modifiers/gravity_well.tres`).
- **Look.** A small dark swirling hole on the floor (violet arms spiralling in to a dark core with a thin rim, a
  black sphere over it), opening and closing with its life; pooled (6, made once); reduced motion slows the swirl.
- **The two devices (O28).** On a loop's last floor the Ascension choice panel (End the run / Ascend / Not yet) is gone
  and nothing waits on a pick. The boss's death opens two separate things in the boss room: the **Ascension portal**
  (the gate's place and look, now named "Ascension" over it): walking into its opening goes on to the final arena
  and the final boss; and the **Loop device**, smaller and green (a 0.9 m pad with a glowing rim and an upright ring
  facing the camera, two arrowheads chasing round it, named "Loop"), on the spot beside the portal where a Deep gate
  would stand (in front of it: nothing solid, so a saved floor rebuilds the same walls): stepping on it starts the
  next loop's floor 1 with the build, as Ascend did. A run ends by beating the final boss or dying (a run without a
  final boss in its content is won through the portal). The HUD names both. The Codex's Ascend counter and the two
  Ascension achievements count the Loop device (their text says so). Old saves: the saved choice keeps its number
  (End = the portal, Ascend = the Loop device); the retired choice's fields stay saved and hashed, always off.
- **Why the boss "could not" be reached** (O28's first line, read from the code): the only way in was the panel's
  first card, "End the run", whose name says the run ends; the path worked (the FB e2e walked it).

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
- Playtest 2 (2026-10-16) design items: moved into v0.8.0 by the owner (O38) as BP, RR, AO, UC; hearts paused (O34).
- v0.7.5 is not in `main` yet (PR riusprime/zero-depth#6): the owner merges it.
- v0.7.5's open questions still stand (Siege Engine and Foundry gap-closers, EI-05 sub-streams, the credit line, the
  AI generator's terms).

## Verification
- Agents: lint + the folders they touched + their e2e. The lead: `scripts/ci/seams.sh` after each merge. The PR into
  `main`: the full suite once on GitHub.
- PF: the probe's frame times before and after, pasted raw in `evidence/PERF.md` (headless frame time is the CPU
  side; the owner's fps on their PC is **OWNER ONLY**).
- Balance numbers are starting values; feel is **OWNER ONLY** (no bot sims, LOCKED 2026-10-08).

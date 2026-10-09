# v0.4.0 "Run Depth" + v0.5.0 "Roads Between": playtest build (owner)

Everything since the v0.3.0 finishing build: your feedback F1–F22 (v0.3.5), the build direction (v0.4.0) and the
roads between floors (v0.5.0), played together (owner: "skip the rule, keep going to v0.5.0"). Answers below are
**OWNER ONLY**: written by the owner or pasted verbatim from the owner's message.

## Get the build
1. When the PR into `main` is merged, the **Windows** workflow runs on `main`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>. Pick the newest green run on `main`.
2. Download `game_windows_x86_64` (kept 14 days), unzip `game_windows_x86_64.zip`, run `game.exe`.
3. If it crashes: send `%APPDATA%\Godot\app_userdata\{{TITLE}}\logs\godot.log`.

## What's new
- **Controls:** Vent on its own button (F / pad B); a second attack per weapon on Skill (Q / pad Y): Blade **Lunge
  Cleave**, Gun **Scatter Blast**; dash cooldown 1.4 s. The Gun no longer has −15 % damage.
- **Builds:** four ability slots (your weapon + Bomb Lobber, Drone Buddy, Orbit Blades, Arc Field, Frost Nova,
  Flame Trail, Blink, Aegis), levels 1–5, eight ability combos at level 3+; stat cards that multiply (HP, damage,
  crit…), 50 cards per build; blink is now a card, not a starting pick.
- **Enemies:** smarter, faster bosses and enemies; 12 enemy types introduced across the three floors; a second boss
  per floor (Warlord, Hive Lens, Foundry); hordes that grow with time.
- **Difficulty:** a calm first minute, then phases, peaking about a minute before you'd reach the boss; heal orbs
  (10 % of kills, +25 % HP); floor-1 bosses easier, with a full heal on entering the boss room.
- **Floors:** a shop (buy, heal, reroll, sell, salvage abilities), 1–2 event rooms, cursed chest cards (+threat),
  an optional red-door **Overrun** room, and after floors 1–2 a choice of the normal or the violet **Deep** portal.
  After the boss you can walk back out and keep exploring before taking a portal.
- **Look and sound:** calmer HUD (your pick B), square cards (your pick B), bigger cooldown icons, a straight heat
  bar, the minimap fixed (it was mirrored), quieter sword, portal entry and arrival animations in the visor's blue.
- **Saves:** quit any time; **Continue** resumes at the entry of the last room you walked into.

## Known, measured here (not felt)
- Test bots: floor-1 deaths 25 % (target < 30 %: met); deaths by floor 3 95 % (target 30–60 %: missed, all at the
  floor-2/3 bosses, which you chose to leave as is); time to kill rises over a floor (target: falls).
- Crowd performance: ~4.7–4.8 ms per tick for 120 enemies + 200 shots (target 4 ms: missed). Your frame rate in big
  fights matters most.
- Nobody here has listened to the new sounds.

## Questions
1. The first minutes: calm enough to explore and grow? Do the phases ramp at the right speed?
2. Is the peak too easy now (it's lower than the version you found too hard)?
3. Floor-2/3 bosses: fair or too hard?
4. Heal orbs: too rare, too common, right?
5. Builds: do four abilities + stat cards give the "god" feeling by floor 3? Which abilities or combos are dull?
6. Altars: too many ability cards early (about 4 in 10 altar cards while you have a free slot)?
7. Shop, events, curses, Overrun, Deep portals: worth using? Prices?
8. Exploring after the boss: do you use it?
9. Gun vs Blade now that the Gun has full damage.
10. Frame rate in the biggest fights on your PC.
11. Saves: did Continue put you back where you expected?
12. The Charger dodge you wanted to judge yourself.
13. Still open: Echoes, Core theft, Depth descent — still wanted, and where?
14. Still open: may EI-05 list the three new sub-streams (`map:event`, `loot:event`, `ai:elite`)?

## Owner answers
Pasted verbatim from the owner's message (2026-10-08, played the `main` build `8ce3de4`). The decisions are in
[`../v0.6.0/PLAN.md`](../v0.6.0/PLAN.md).

> Feedback v0.4.0-v0.5.0 - This is a really big update so plan and make a document with everysingle thing I said so
> we don't lose any of the feedback. Spawn 3 agents parallel at max at the same time
>
> From now on not run bot tests, because they do not represent reality
>
> **1.** The first minutes: calm enough to explore and grow? Do the phases ramp at the right speed?
> Very calm, that fits the first 30 seconds of the first floor then it should ramp a bit faster, we should add
> closing door to some rooms so you have to stay there until you kill X enemies before continuing, and also find a
> way of enemies also matching what you can do in terms of not super mega outgrowing them
>
> **2.** Is the peak too easy now (it's lower than the version you found too hard)?
> I cleared so easy, and highly outgrew the difficulty of each floor, I think a cool mechanic would be to
> recalculate difficulty for next floor based on your damage, but that'd make it same difficulty everytime even if
> your build is broken so not exactly scaling with you but maybe regular scaling + multiplier based on how much you
> grew
>
> **3.** Floor-2/3 bosses: fair or too hard?
> Really easy, but maybe because I got there clearly outscaling the difficulty
>
> **4.** Heal orbs: too rare, too common, right?
> Too common, we should add them as a card, so it is not perma enables only if you get it
>
> **5.** Builds: do four abilities + stat cards give the "god" feeling by floor 3? Which abilities or combos are dull?
> I was literally god after 1 run, unkillable and outscaled the difficulty, bosses felt just like an elite, we have
> to make bosses harder not only matching in some way the HP to our damage, but not fixed because it would be always
> hard even if I had the luckiest so that matching in difficulty should have a cap based on the floor and how far
> you took it, you know how in RoR2 sometimes you delete bosses but other runs the difficulty is hard but not
> impossible, we have to design a system that only super lucky broken builds allow you to kill with easy
> The difficulty balancing does not have to be about making the game extremely difficult, its to be a good balance
> between the difficulty curve and the growing path
>
> **6.** Altars: too many ability cards early (about 4 in 10 altar cards while you have a free slot)?
> I think too many and that's what made me so strong, we could add max 2 per floor and the rest should be chests
>
> **7.** Shop, events, curses, Overrun, Deep portals: worth using? Prices?
> Used deep portals but I felt like nothing changed tho, maybe because I was too strong, curse was fun, but also
> gave me the god feeling too fast,
> The shop is too broken, once you buy a slot refreshing it should now spawn again 4, the bought slots should stay
> bought and not be able to buy 16 upgrades at a time only 4 max per floor if gold gets it, I felt like I had enough
> shards to buy whatever I wanted and passing them onto the next floor also made next floor pretty easy, explored
> full of shards, bought everything and by the time the enemies started appearing I was super strong, curses are
> fun, we can add more variables into it, you lose dash but have a dodge % or attack speed lower but 4th hit
> increased X% on damage
>
> Overrun: should close the door and have between 3-5 waves of 4, 8 or 12 enemies spawning in them, not just
> killing what spawns outside
>
> **8.** Exploring after the boss: do you use it?
> Yeah I did, to go back to store or to the shrine
>
> **9.** Gun vs Blade now that the Gun has full damage.
> Blade i tried to took it a bit further, but extremely OP too, i was insta deleting everything, bosses, hordes,
> whatever was in front of me, I liked the playstyle but that's where the balancing I talked about previously comes
> in, I think a good way to distinct this game would be adding modifiers and merging attacks for example lighting,
> modifies the way bullets fo out, or grabbing something that shoots makes your sword shoot an echo of the slide
> whenever you attack, and all abilities have a combination between them so you can play a lot of different builds,
> some are stronger than others but players will have to discover those on their own, and then adding trinkets and
> stuff like binding of isaac that also modify how you interact, shorter shots but in a cicle, or weapon shots now
> are shock circles, there is infinite possibilities so I cant list them all but you have to help me come up with a
> list for this. Is it possible to create some kind of engine that makes creating this easier so when adding a new
> modifier you don't have to create every single interaction, or is it better to create each interaction
> individually?
>
> **10.** Frame rate in the biggest fights on your PC.
> Framerate was right
>
> **11.** Saves: did Continue put you back where you expected?
> Yes
>
> **12.** The Charger dodge you wanted to judge yourself.
> Yes, new bosses might need a render tho
>
> **13.** Still open: Echoes, Core theft, Depth descent — still wanted, and where?
> Let's discuss
>
> **14.** Still open: may EI-05 list the three new sub-streams (map:event, loot:event, ai:elite)?
> Let's discuss
>
> Additional feedback:
>
> * I am between two options help me choose and justify why can we make other rooms not visible from the one you
>   are in so you focus in the one that you are fighting, about 60% of the rooms should close the doors and unlock
>   their rewards after clearing them, more like Isaac, or leaving it as is where it is closer to RoR2 or to megabonk,
>   but those have "open world" and it is different, I think the kinda openworld thingy matches better with the
>   incremental part of the game, but then the world generation feels a bit off with the rooms, I need to decide on
>   how to guide the game, you could maybe help me asking some questions and then we decide the direction of the
>   gameplay
> * The ability for gun and blade should match the animation, and the color of the swrod/bullets the current hit
>   color as well, once reached the first threshold they turn orangem second one red
> * Some VFX need to match the new style of the game, I worked a full art rework and some don't match neither style
>   nor lighting
> * I attached two image for the new card select templates, one is the visual reference and the secord one is the
>   empty templates you'll have to crop to use them as real cards
>   (saved as [`../v0.6.0/refs/card_style_reference.webp`](../v0.6.0/refs/card_style_reference.webp) and
>   [`../v0.6.0/refs/card_templates_empty.webp`](../v0.6.0/refs/card_templates_empty.webp))
> * The UI should also match this new style, we can work with some mockups

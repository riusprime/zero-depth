# The wand: modifiers that rebuild your basic attack (design, v0.6.5 Step WD; status: approved by the owner 2026-10-12, "Approve all")

Owner (2026-10-12, PLAN v0.6.5 W3): "the point of the modifiers is to actually be a modifier of the basic attack …
like Binding of Isaac or Magic Craft … the splitting balls in Binding of Isaac, the shooting the bigger balls … or at
Magic Craft, the different ways that all items interact in the order that you put them in the wand … almost
everything that you take modifies how your basic attack looks and interacts and shoots and the idea is to be able
to have a lot of different combinations that destroy the enemies".
Owner picks: the order matters and you can rearrange it; Blade and Gun have their own pools, with a small shared pool
"like bleed or lightning"; for the Blade "the slash becomes a spell".

This replaces the build half of [`MODIFIER_ENGINE.md`](MODIFIER_ENGINE.md). The engine underneath stays: an attack
spec that the sim runs and the view draws.

## Why v0.6 didn't feel like this
- **The old abilities stayed side attacks.** The drone, the orbiting blades and the bomb every 4th attack fire next
  to your attack instead of changing it.
- **Slot order didn't matter.** The engine sorted every card into fixed stages, so the slot a card sat in changed
  nothing.
- **Most cards were riders.** "Hits chain", "kills explode" and the like add an effect on hit, but the shot itself
  looks and flies the same.

## The wand in one picture
```
[ weapon ] [ slot 1 ] [ slot 2 ] [ slot 3 ] [ slot 4 ] [ slot 5 ] [ slot 6 ]
   Bolt  →  Big    →  Split   →  Fire   →  ON HIT  →  Shock   →  Ring
           └────────── the shot you fire ──────────┘  └── cast where it hits ──┘
```
You fire a **big bolt that splits into 3 burning bolts**. Each one, when it hits, releases a **shock ring**.
Move ON HIT one slot to the left, and only the split bolts burn when they hit, not the main shot.

## Rules
1. **The spell is your basic attack.** For the Gun it's one bolt. For the Blade it's one slash, which the Blade's
   modifiers can make fly, split, spin or leave a trail. The weapon is slot 0.
2. **Read left to right.** Each modifier changes the spell built so far: its size, speed, count, path, element and
   what it does on contact. A later modifier changes what the earlier ones built. Split then Big gives three big
   shots; Big then Split gives one big shot that splits into three normal ones.
3. **Triggers cut the wand.** A trigger card (On hit, On kill, On end, On finisher) ends the shot you fire. Every
   card to its right builds a second spell, cast where the trigger fires. That second spell starts as a small copy
   of your basic attack. A second trigger nests once more, up to depth 2 (the engine's existing guard, with proc
   coefficients 1 → 0.5 → 0.25).
4. **You can rearrange.** Moving cards between slots is free and immediate:
   - in the pause menu's Build page;
   - on the Swap panel when you pick up a card.

   Keyboard, mouse and pad all work. The panel reads the wand back in plain words ("A big bolt that splits into 3
   burning bolts; each hit releases a shock ring").
5. **The wand grows** (owner: "Grows during the run"): 4 slots on floor 1, 6 after the first boss, 8 after the
   second. With every slot full, a new card opens Swap.
6. **A duplicate levels up.** Taking a card you already hold makes it stronger (levels 1–5) and uses no new slot.
7. **Every card is visible on the attack itself:** its size, number, path, colour, trail or burst. No card is only a
   number. Stat cards stay unlimited numbers outside the wand, as decided in v0.6.0.
8. **Two pools and a shared one.** Blade cards are offered only in Blade runs and Gun cards only in Gun runs. Shared
   cards (elements and statuses) appear in both.
9. **The difficulty catch-up reads the wand** through `CatchUp.power`. A strong wand raises the hidden scaling up to
   its cap, so a broken wand still melts the floor but a normal one meets a fair fight.

## The pools (G1: the owner keeps, cuts or edits rows)

### Gun pool: what the bolt does
| # | Card | Changes the spell | You see |
|---|---|---|---|
| G1 | Big Shot | ×2 size, ×1.6 damage, −25 % speed | a fat slow orb |
| G2 | Rapid Fire | ×0.6 size, +60 % fire rate, −30 % damage | a stream of small bolts |
| G3 | Twin | fires the spell twice, side by side | paired bolts |
| G4 | Spread | becomes a 3-shot fan (+2 per level) | a fan |
| G5 | Split | on its first hit, splits into 3 at half size | a burst of shards at the hit |
| G6 | Pierce | passes through 2 enemies (+1 per level) | a streak through the line |
| G7 | Ricochet | bounces off walls twice | angled bounces |
| G8 | Homing | curves toward the nearest enemy | curved trails |
| G9 | Boomerang | flies out, then comes back through you | a loop |
| G10 | Orbit | circles you once before it flies out | a ring of shots, then a volley |
| G11 | Spiral | travels in a corkscrew | a helix |
| G12 | Mine | stops at its range and waits 3 s, exploding on contact | a field of mines |
| G13 | Charge | hold to grow it, up to ×3 size and damage | it swells in the barrel |
| G14 | Echo | fires again 0.3 s later at 60 % | a trailing ghost volley |
| G15 | Backfire | also fires behind you | shots in both directions |
| G16 | Halo | the spell fires in a full ring, ×0.5 range | a ring of shots |

### Blade pool: what the slash does
| # | Card | Changes the spell | You see |
|---|---|---|---|
| B1 | Wide Arc | +60° arc, +30 % reach | a huge sweep |
| B2 | Wave | the slash flies on as a crescent (the shooting sword) | a flying crescent |
| B3 | Split Wave | needs a flying slash: on hit, splits into 3 small crescents | crescents fanning out |
| B4 | Whirl | every slash becomes a 360° spin | a full spin |
| B5 | Double Slash | every slash repeats, mirrored, 0.15 s later | a criss-cross |
| B6 | Thrust | narrow and long: reach ×2, arc ×0.4, +30 % damage | a long stab line |
| B7 | Heavy | ×1.7 damage and big knockback, −30 % swing speed | slow, crushing arcs |
| B8 | Flurry | +50 % swing speed, −25 % damage | a blur of slashes |
| B9 | Fissure | the slash cracks the ground ahead in a line that erupts | a crack line, then an eruption |
| B10 | Chain Cut | a hit leaps to the next enemy within 4 m (+1 per level) | the slash jumping between enemies |
| B11 | Parry Edge | the slash destroys enemy shots it touches | sparks off the bullets it cuts |
| B12 | Afterimage | dashing leaves a copy that repeats your last slash | a ghost slash |
| B13 | Lunge Step | each slash steps you 1 m forward | you drive into the crowd |
| B14 | Finisher+ | the 4th hit's shockwave doubles and carries every card | a big shockwave |
| B15 | Orbit Blades | each slash throws off a blade that circles you for 3 s | blades orbiting you |
| B16 | Counter | a slash within 0.5 s of a dash deals ×2 and is a flying wave | a dash-slash wave |

### Shared pool: works the same on both
| # | Card | Effect | You see |
|---|---|---|---|
| S1 | Fire | burns; burning kills burst into flame | orange core and sparks |
| S2 | Lightning | hits chain to 2 more enemies | a white-blue crackle and arcs |
| S3 | Frost | slows; the 3rd hit freezes for 1 s | pale shards and frost |
| S4 | Venom | poison stacks that spread on death | a green drip |
| S5 | Bleed | bleed stacks that tick faster when you move | red streaks |
| S6 | Void | hits pull nearby enemies in | a violet smear and a pull |
| S7 | Explosive | the spell explodes where it ends | a blast at the end |

### Triggers: they cut the wand, and both weapons get them
| # | Card | The cards to its right cast… |
|---|---|---|
| T1 | On Hit | …where each hit lands |
| T2 | On Kill | …where an enemy dies |
| T3 | On End | …where the spell ends (its range, a wall, or the end of the slash) |
| T4 | On Finisher (Blade) / On Crit (Gun) | …on the combo's 4th hit / on a critical hit |

## Combinations it makes (no hand-made pairs)
- **Gun:** Spread · Homing · ON HIT · Explosive. A fan of seeking bolts, each exploding on hit.
- **Gun:** Orbit · Big Shot · Lightning · ON END · Halo. Fat lightning orbs circle you, fly out, and burst into a
  ring of bolts at their range.
- **Blade:** Wave · Split Wave · Fire · ON KILL · Whirl. Flying burning crescents that split; every kill spins a
  slash where the enemy fell.
- **Blade:** Heavy · Fissure · Frost · ON FINISHER · Wave · Double Slash. Slow crushing frost slashes crack the
  ground; the 4th hit throws two mirrored waves.
- **Order matters:** Big · Split versus Split · Big; Fire · ON HIT · Shock versus ON HIT · Fire · Shock.

## What happens to the v0.6 cards
- The M1–M30 list and the six old abilities map onto these rows or retire.
  - Halo, Split Shot, Echo Slash (B2 Wave), Boomerang and Orbit Rounds map directly.
  - Bomb Lobber becomes S7 Explosive with G12 Mine.
  - The Drone retires: its side attack is what the owner doesn't want.
- Old saves load: each held card maps to its new card, in pick order. A card without a match is refunded as shards.
- The legendary tier offers level-5 versions and a few unique triggers (for example "On Hit ×2": the cast repeats
  twice).

## How it's built (after G1)
1. **The wand compiler.**
   - The fixed stage order is replaced by left-to-right slot order with triggers that cut the wand. It builds one
     spec for the shot you fire and child specs for each trigger.
   - Saves store the slot order.
   - The combinatorial smoke test runs every card × every slot position × both weapons (no bots).
2. **The Build page and Swap reorder,** with the plain-words read-back (en + es).
3. **The Gun pool.**
4. **The Blade pool,** with the slash as a spell (flying, splitting, spinning) and the Blade's forms.
5. **The shared pool and the triggers' visuals.**
6. **Migration of the old cards, the legendary tier and the offer pools.**

## Owner decisions
- Slots: "Grows during the run" (4 → 6 → 8).
- G1: "Approve all".

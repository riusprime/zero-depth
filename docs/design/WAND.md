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
| B2 | Wave | the slash flies on as a crescent (the shooting sword); v0.8.0 BL: +1 crescent a level | a flying crescent |
| B3 | Split Wave | needs a flying slash: on hit, splits into 3 small crescents (+1 a level) | crescents fanning out |
| B4 | Whirl | every slash becomes a 360° spin | a full spin |
| B5 | Double Slash | every slash repeats, mirrored, 0.15 s later; v0.8.0 BL: +1 repeat a level, each 70 % | a criss-cross |
| B6 | Thrust | narrow and long: reach ×2, arc ×0.4, +30 % damage; v0.8.0 BL: the arc widens from level 3 (×1 at 5) | a long stab line |
| B7 | Heavy | ×1.7 damage and big knockback, −30 % swing speed; v0.8.0 BL: 10 % less slow a level from level 3 (none at 5) | slow, crushing arcs |
| B8 | Flurry | +50 % swing speed, −25 % damage; v0.8.0 BL: the loss shrinks from level 3, none at 5 | a blur of slashes |
| B9 | Fissure | the slash cracks the ground ahead in a line that erupts | a crack line, then an eruption |
| B10 | Chain Cut | a hit leaps to the next enemy within 4 m (+1 per level) | the slash jumping between enemies |
| B11 | Parry Edge | the slash destroys enemy shots it touches | sparks off the bullets it cuts |
| B12 | Afterimage | dashing leaves a copy that repeats your last slash | a ghost slash |
| B13 | Lunge Step | each slash steps you 1 m forward | you drive into the crowd |
| B14 | Finisher+ | the 4th hit's shockwave doubles and carries every card | a big shockwave |
| B15 | Orbit Blades | each slash throws off a blade that circles you for 3 s | blades orbiting you |
| B16 | Counter | a slash within 0.5 s of a dash deals ×2 and is a flying wave | a dash-slash wave |
| B17 | Blade Storm (v0.8.0 BL) | each slash throws 2 spinning blades that fly out and back (+1 a level) | blades looping out and back |
| B18 | Riposte Chain (v0.8.0 BL) | a slash that kills slashes again at the next enemy within 4 m: 2 in a chain (+1 a level) | the cut leaping on from a kill |

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

**v0.8.0 BL** ([`../roadmap/v0.8.0/BLADE_AUDIT.md`](../roadmap/v0.8.0/BLADE_AUDIT.md), owner 2026-10-14): on a Blade run a
slash's hit triggers (On Hit, On Kill, On Finisher) cast twice; a wand-card offer weighs the run's own weapon's cards
×1.5 against the shared ones; Split's splits (and anything cast from Split or Explosive) neither split nor explode
again, and past 8 Explosive blasts in one tick an overlapping one merges into a blast already set off.

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

### The mapping (v0.6.5 WN5b)
The data is one table, [`data/wand/migration.tres`](../../data/wand/migration.tres) (CONTENT_SCHEMA "the wand"). A
retired card is never offered again (altars, chests, the shop, events, cores, the legendary tier, the overrun). It is
not deleted, so old saves still name it, and the dev panel can still grant it. A save that holds one maps it when it
loads, in its place in the wand: a target you already hold, or one that two old cards both map to, levels up instead
(the levels add: an ability's level, 5 for a legendary version, else 1). A card with no target, or whose target isn't
in the data yet, is refunded at the shop's salvage price for it on that floor (a mod: 40 % of its shop price by
rarity, 12 / 22 / 36 shards on floor 1; an ability: 10 shards a level). Blade-only and Gun-only targets apply only on
that weapon's run; "—" means a refund.

**Kept their ids** (WN3, WN4; nothing to map): Echo Slash → B2 Wave (`echo_slash`), Halo Shot → G16 Halo, Boomerang →
G9, Orbit Rounds → G10 Orbit, Split Shot → G5 Split, Wide Arc → B1, Long Shadow → B12 Afterimage, Blade Orbit → B15
Orbit Blades; and (WN5a, the shared pool) Ember Core → S1 Fire, Storm Core → S2 Lightning, Frost Core → S3 Frost,
Venom Core → S4 Venom, Gravity Well → S6 Void. The S targets below are those ids; S5 Bleed is `shared_bleed` and S7
Explosive `shared_explosive` (new cards of WN5a).

| Old card (id) | What it was | Blade run | Gun run |
|---|---|---|---|
| Long Edge (`long_edge`, v0.5) | +35 % blade reach | B1 Wide Arc | — |
| Twin Arc (`twin_arc`, v0.5) | swings echo 0.1 s later | B5 Double Slash | — |
| Ember Edge (`ember_edge`, v0.5) | melee burn | S1 Fire | S1 Fire |
| Splinter Shot (`splinter_shot`, v0.5) | a 3-bolt fan | — | G4 Spread |
| Rapid Coil (`rapid_coil`, v0.5) | +40 % fire rate | — | G2 Rapid Fire |
| Ricochet Core (`ricochet_core`, v0.5) | bolts bounce once | — | G7 Ricochet |
| Overcharge (`overcharge`, v0.5) | the finisher hits double with a wave | B14 Finisher+ | — |
| Static Chain (`static_chain`, v0.5) | bolts shock and arc | S2 Lightning | S2 Lightning |
| Cinder Shot (`cinder_shot`, v0.5) | bolt burn | S1 Fire | S1 Fire |
| Conductor (`conductor`, v0.5) | swings shock, jump to 2 | S2 Lightning | S2 Lightning |
| Serrated Edge (`serrated_edge`, v0.5) | swing bleed | S5 Bleed | S5 Bleed |
| Barbed Bolts (`barbed_bolts`, v0.5) | bolt bleed | S5 Bleed | S5 Bleed |
| Glacial Edge (`glacial_edge`, v0.5) | swing frost, freeze at 4 | S3 Frost | S3 Frost |
| Cluster Payload (`cluster_payload`, Bomb Lobber's mod) | bombs split | S7 Explosive | G12 Mine |
| Overclocked Drone (`overclocked_drone`, the Drone's mod) | drones fire faster with heat | — | — |
| Razor Orbit (`razor_orbit`, Orbit Blades' mod) | orbit touches bleed | S5 Bleed | S5 Bleed |
| Blink Echo (`afterimage`, Blink's mod; was "Afterimage") | a blink leaves a bursting echo | — | — |
| Edge Rounds (`edge_rounds`, M6) | shots slash where they hit | — | — |
| Shock Circles (`shock_circles`, M7) | shots become shock rings | — | — |
| Twin Cast (`twin_cast`, M12) | every attack repeats at 50 % | B5 Double Slash | G14 Echo |
| Rearguard (`rearguard`, M13) | also fires backwards | — | G15 Backfire |
| Shatter (`shatter`, M16) | kills burst into shards | — | — |
| Aftershock (`aftershock`, M17) | a blast where an attack ends | S7 Explosive | S7 Explosive |
| Seeker (`seeker`, M18) | shots home; arcs snap | — | G8 Homing |
| Phase Dash (`phase_dash`, M20) | intangible dash, shard burst | — | — |
| Ember Trail (`ember_trail`, M21) | walking leaves fire | — | — |
| Aether Shell (`aether_shell`, M22) | a barrier out of combat | — | — |
| Ascension (`ascension`, M23) | after 3 s idle, the next attack ×3 | — | G13 Charge |
| Resonance (`resonance_core`, M24) | +15 % per status | — | — |
| Heat Sink Rounds (`heat_sink_rounds`, M25) | an extra shot at Overclock | — | — |
| Meltdown Edge (`meltdown_edge`, M26) | venting fires a full circle | — | — |
| Mirror Drone (`mirror_drone`, M27) | the drone copies your attack | — | — |
| Bomb Rounds (`bomb_rounds`, M28) | every 5th shot a bomb | S7 Explosive | G12 Mine |
| Short Fuse (`short_fuse`, M30) | ranges ×0.6, damage ×1.4 | — | — |
| Tempest Core (`tempest_core`, legendary M1) | lightning to 4 more | S2 Lightning, level 5 | S2 Lightning, level 5 |
| Inferno Core (`inferno_core`, legendary M2) | double burn, big bursts | S1 Fire, level 5 | S1 Fire, level 5 |
| Echo Storm (`echo_storm`, legendary M5) | every slash flies as 3 crescents | B2 Wave, level 5 | — |
| Bomb Lobber (ability) | every 4th attack lobs a bomb | S7 Explosive | G12 Mine |
| Drone Buddy (ability) | a drone fires copies (a side attack) | — | — |
| Orbiting Copies (ability `orbit_blades`; was "Orbit Blades") | copies of your attack orbit you | B15 Orbit Blades | G10 Orbit |
| Arc Field (ability) | a shock field where attacks end | S2 Lightning | S2 Lightning |
| Frost Nova (ability) | frost element, a nova on a kill streak | S3 Frost | S3 Frost |
| Flame Trail (ability) | dash and shots leave fire | S1 Fire | S1 Fire |

- **43 retired:** 13 v0.5 attack items, 4 ability mods, 17 M-list cards, 3 legendary versions, 6 abilities. 20 have
  no row at all (refunded on both weapons); a few more have a row on one weapon only.
- **S5 and S7 are pending on the WN5b branch alone:** `shared_bleed` and `shared_explosive` come with WN5a's merge
  (the table lists them in `pending`); until then a held card mapped to one is refunded. The five other S cards are
  the v0.6 cards WN5a kept (lead, 2026-10-12), so they exist on both branches.
- **Bomb Lobber** "becomes S7 Explosive with G12 Mine": S7 on the Blade, G12 Mine on the Gun (its bombs become the
  Gun's mine field); its two merges follow it.
- **Name clashes:** B12 is "Afterimage" (`long_shadow`); the old Blink card (`afterimage`) is renamed "Blink Echo" /
  "Eco del Salto". B15 is "Orbit Blades" (`blade_orbit`); the old ability (`orbit_blades`) is renamed "Orbiting
  Copies" / "Copias orbitales" (and Razor Orbit's text with it). Both old cards are retired; the names only show in
  the dev panel.
- **Not in the table:** the 13 v0.5 items that take no wand slot (Bulwark, Cold Snap, Executioner, Heat Sink, Kinetic
  Dash, Meltdown, Momentum, Phase Strike, Swift Feet, Thermal Edge, Thorn Mantle, Vampiric Core, Wildfire). They are
  passives outside the wand, like stat cards, and stay offered: WAND.md says nothing about them, and pruning them is the
  owner's call (PROGRESS v0.6.5 "Gates").

### The legendary tier (v0.6.5 WN5b)
- **Level-5 versions:** the boss's legendary altar offers every wand card of the run's pool (Gun runs G1–G16, Blade
  runs B1–B16; S1–S7 once merged) besides the legendary stat cards. A wand card picked there is taken at level 5 (a
  held one rises to 5). Its card reads "Mod · Level 5 · Legendary".
- **Unique triggers:** On Hit ×2, On Kill ×2, On End ×2 (`trigger_on_*_twice`). They cut the wand like T1–T3, and the
  cards to their right cast twice each time, the second cast 0.15 s after the first. They are legendary only (the
  boss's altar, a boss's core).
- The pick stays one of three, 60 % stat cards / 40 % mods by weight (data `data/legendary/boss.tres`).

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

# ZeroDepth — v0.11 Feedback & Ideas Brief

**Current version:** v0.10.5  
**Target:** v0.11, with some additional items to discuss for upcoming versions  
**Status:** Working feedback notes, not a final feature specification  
**Audience:** Development agent working on ZeroDepth

## Purpose of this document

This document consolidates gameplay feedback, observed bugs, feature ideas, and areas that need further discussion. It describes **what is happening now**, **what the intended player experience could be**, and **which ideas are still open**.

It is **not an implementation plan**. No specific technical solutions, architecture, code changes, or invented mechanics are prescribed here. The examples below come from the current feedback session; details will be discussed with the development agent, which has the context of the existing game.

## 1. Current gameplay bugs and feedback — v0.10.5

### Twin + Void + Split

- Combinations involving **Twin**, **Void**, and multiple Void instances created by **Split** still have occasional visual bugs.
- Some Void instances appear to **teleport or jump unexpectedly** when several are active at once.
- This has been observed in gameplay and remains unresolved.

### Lantern boss darkness

- The Lantern boss's darkness effect **used to conceal its attacks**.
- That behavior appears to have regressed: the boss's attacks are now visible during the darkness effect.
- This is separate from the broader Lantern encounter ideas below.

### Siege Machine / large cannon boss

- The existing attack with **two successive patterns of circles on the ground** is a mechanic worth keeping.
- **Smoke obscures the second pattern**, including the safe spaces the player needs to recognize.
- The second pattern also happens too quickly, leaving insufficient time to identify and reach a safe spot.
- The issue is readability and reaction time, not the basic concept of the attack.

## 2. Laser redesign — proposed gameplay change

The Laser should no longer be a fully continuous, sustained beam. The intended direction is a **charged-feeling, lance-style attack**, fired with a deliberate button press approximately every **2–3 seconds** (an initial idea, not final timing).

With **Homing + Pierce**, a shot should be able to connect multiple enemies through a **single smooth, curved trajectory**. The desired visual is a flowing line that traces a clean path through targets rather than a rigid or visibly segmented chain of beams. I will be attacking an image of a drawing so you cna understand, this attack doesnt need a release of the trigger to shot it just has a 3 second cooldown, we need to adapt the damage to the new form, so it needs to do the same damage it'd do in 3 seconds of continous beam

A sketch will be attached separately to communicate the intended shape and feeling of this trajectory. The exact gameplay details are still open.

## 3. Boss fights — major v0.11 design direction

### Overall feedback

The current bosses rely too heavily on **invulnerability phases while the player dodges attacks**. Some encounters feel passive or repetitive because the player has little influence over the mechanic beyond surviving it.

The desired direction is toward **recognizable, learnable boss mechanics**, somewhat closer to the feeling of *World of Warcraft* boss encounters, adapted to ZeroDepth's faster combat. Bosses should feel different from one another, and players should sometimes interact with the **arena, objects, or boss behavior**, rather than only dodging projectiles.

Possible mechanics should be understandable through play. Small contextual hints—such as a pointing arrow when something important happens—are an idea, but the game should not fully explain the fight through long instructions.

The specific concepts below are **examples to develop and discuss**, not finalized specifications. The remaining bosses also need to be reviewed for stronger individual encounter identities.

### Rock boss — earthquake pillar idea

**Current behavior:** The boss marks a cross beneath the player, then spikes erupt from the marked ground.

**Proposed encounter concept:** The boss could place **two or three pillars** in the arena that repeatedly create earthquake-like pulses and deal small amounts of ongoing damage. The player could use the boss's existing cross/spike attack against those pillars by positioning its marker over them. The boss would then destroy its own pillars, ending the damage they cause.

**Why this is interesting:** The existing attack becomes something the player can deliberately use, making the encounter more interactive than just avoiding the cross.

### Lantern boss — darkness and arena lights

**Current behavior:** The boss introduces darkness and becomes invulnerable while the player dodges. There are arena lights that switch on when stepped on, but they currently have no meaningful gameplay role.

**Proposed encounter concept:** The player could step onto the lights to restore illumination. Instead of the boss being completely invulnerable in darkness, it could **take less damage while dark** and **more damage when lit**. Light and darkness could alternate throughout the fight, with players choosing whether to engage with the lights.

**Why this is interesting:** The arena objects would finally matter, and the player could influence the encounter's damage opportunities.

**Separate existing bug:** Darkness no longer hides attacks as it used to (§1).

### Twin Wardens / twin brothers — different roles and phases

**Existing characteristic:** The twins share one health pool.

**Proposed encounter concept:** Give them differentiated combat identities: the **yellow twin** focuses more on physical attacks; the **purple twin** focuses on magic and projectiles.

An example progression discussed:

1. **First phase:** One twin is the main opponent. The other is invulnerable or less directly involved, but occasionally interferes with simpler, dodgeable attacks.
2. **Second phase:** Their roles reverse, so the player faces a different primary moveset.
3. **Third phase:** Both fight together, but their more demanding attacks can alternate rather than overlapping chaotically. Damage opportunities could periodically favor one twin and then the other, encouraging target switching.

**Why this is interesting:** A shared-health boss fight would still require adapting to distinct enemies and changing phases.

This phase structure is an idea, not a locked design.

### Siege Machine — existing mechanic feedback

The two-pattern circle attack is a **good foundation** and should not lose what makes it interesting. The current problems are the smoke that hides the second wave and how quickly the player is expected to react (§1).

### Warlord — existing foundation

The Warlord's mechanics currently feel **reasonably good**. There may be room for adjustments and upgrades, but the encounter is a better starting point than some of the others.

### Other bosses

The rest of the boss roster has **not yet been individually discussed**. The broader feedback applies to them as well: each encounter should be reviewed for opportunities to become more distinct, interactive, and learnable, rather than leaning mainly on dodging and invulnerability.

No additional boss mechanics are specified in this brief.

## 4. Small horde enemies — proposed addition

A previously discussed idea was to introduce **groups of small, simple enemies** that primarily **follow the player** and **deal damage on contact** rather than having complex individual attack patterns.

The appeal is to create occasional moments with large numbers of enemies, making the game feel more intense and giving area attacks and crowd-control abilities a meaningful role.

**Still to discuss:** What these horde enemies actually are, how they look, how they fit the world, and when they should appear. Their designs are **not defined** in this brief.

## 5. Elemental automatic spells — major v0.11 idea

### Basic concept

Unlocking an element would open access to **different automatic spells associated with that element**. The initial idea is approximately **three spells per element**, chosen and improved through the card system.

- Spells would trigger **automatically**, alongside the player's main attack.
- The player could have **up to four automatic spells**.
- The four slots could mix elements freely: for example, **3 Frost + 1 Fire** or **2 Fire + 2 Lightning**.
- Later cards could upgrade a spell's **radius, duration, damage**, or other relevant characteristics.
- These abilities should make different elemental combinations and horde-control playstyles feel more varied.

### Spell examples raised in this session

| Element | Example idea | Intended effect |
|---|---|---|
| Frost | Blizzard / falling ice | Ice raining in an area slows enemies passing through |
| Frost | Frost Nova | Briefly freezes enemies around the player, roughly one second as an initial idea |
| Fire | Large automatic fireball | A fireball periodically fires from the player |
| Fire | Burning ground | An area of fire deals a small amount of damage to enemies standing in it |
| Lightning | Lightning strike from the sky | A strike hits an enemy and affects an area |
| Venom | Venom orb | An orb creates a pool that applies Venom stacks to enemies in it |

These are **examples only**. The complete list of spells, including the remaining ideas for each element, is still open. These spells are always automatic and have a cooldown, 12s for example and player does not need to manually throw them.

### Balance concern

Introducing several automatic damage sources could make builds too powerful. Their damage needs to be considered alongside existing attacks, and **enemy health/balance may also need reviewing** in light of the increased damage output. No numerical balance changes are proposed here.

## 6. Regular enemies — models, animation, and variety

These are additional **open feedback items** for v0.11 or subsequent versions; their precise scope has not yet been agreed.

### Older enemy models and animation

- Some enemies still use **older/generated models** and have not yet been updated to the newer visual standard.
- The desired reference is the **Charger-style enemy design**, but **not in red**.
- These enemies still need **animation**, including the **VIT texture animation** work mentioned in the feedback.
- Which specific enemies are affected and their final looks remain to be discussed with the development agent.

### Increase the regular enemy pool

- The current regular enemy pool feels **too small**.
- Encounters repeatedly feature the same types of enemies, creating familiar combat patterns and making runs feel repetitive.
- More regular enemy types are needed to bring variety to the moment-to-moment gameplay.

### Biome identity and enemy selection

- Right now, **the same enemies appear across essentially all biomes**.
- Enemies should feel more connected to the biome they appear in, so different biomes offer more distinct encounters.
- Ideas to discuss include **biome-specific enemy types** and **biome-appropriate variations of some existing enemies**.
- The overall **enemy spawning/selection structure** also needs discussion, with biome identity and encounter variety in mind.

These are desired directions, **not instructions about how spawning should be implemented**.

### Horde enemy identity remains open

- In addition to expanding regular enemies, the new small horde enemies from §4 still need their own identity and design discussion.
- No visuals, roster, or implementation rules have been established for them.

## 7. Room messages and lore Easter egg — open idea

The game now has **room messages**, but they do not currently seem connected to anything meaningful.

There is interest in turning them into an **Easter egg or discoverable in-game connection**, so they contribute to the world and introduce a little lore. The goal is for the messages to feel like they matter rather than being isolated text.

**No specific Easter egg, storyline, interaction, or reward has been chosen.** This is a topic to brainstorm with the development agent rather than a feature specification.

## 8. Procedural rooms — environmental structure and coherence

Some procedurally generated rooms currently feel like **random collections of placed assets**, without a recognizable structure or a clear reason for the environment to be arranged that way.

- The **store rooms** are a positive example: their layout feels intentional and has a recognizable structure.
- The goal is for **some procedural rooms, especially the larger ones**, to feel similarly deliberate and coherent rather than randomly assembled.
- Room layouts and environmental objects should feel like they **belong together and make sense as a space**.
- This does **not** mean every room needs the same fixed structure. The concern is the lack of meaningful layout in some of the current rooms.
- Discuss with the development agent how to improve this aspect of procedural room generation, using the store rooms as an example of the desired level of organization.

**Open feedback only:** No room-generation method, placement rules, layouts, or implementation solution is prescribed here.

## 9. Open discussions with the development agent

The following topics are intentionally unresolved:

- Exact details of the Laser redesign and its curved Homing + Pierce behavior.
- Final boss mechanics, additional ideas for bosses not discussed, and the overall encounter balance.
- The full elemental automatic-spell roster, how spells are obtained/upgraded, and their impact on game balance.
- The identity and role of the new small horde enemies.
- Which older enemy models need replacing, their Charger-style visual direction, animation, and VIT texture-animation work.
- Additional regular enemy types, potential variants, biome identity, and more varied enemy spawning.
- A meaningful Easter egg or lore connection for room messages.
- Improving the sense of structure and environmental logic in procedural rooms, particularly large rooms, without losing procedural variety.
- Which of the additional enemy-art and enemy-variety items belong in v0.11 versus later updates.

## 10. Reference material still to be provided

- **Laser sketch:** A drawing showing the intended smooth curved path through multiple enemies when Homing and Pierce are combined.

---

**Scope note:** This is a record of feedback and ideas, not a technical task breakdown. Implementation choices and further design exploration are to be handled in conversation with the development agent.

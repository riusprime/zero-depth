# The modifier engine (design, v0.5.5 Step MX; status: build model decided by the owner 2026-10-08)

Owner (2026-10-08): "Help me with the modifiers engine the idea is that based on what you have what you do also
changes visually not only damage wise as I describe with the shooting swords, that was just an example, but we
need all of them to be a modifier that adds to your build". Earlier: "Is it possible to create some kind of engine
that makes creating this easier so when adding a new modifier you don't have to create every single interaction".
Rows B2–B6 in [`../roadmap/v0.5.5/PLAN.md`](../roadmap/v0.5.5/PLAN.md).

## The build (owner decisions, 2026-10-08)
- **The weapon is the build.** "we are no longer having 4 abilities weapons, every build turns around the main
  weapon, and the rest are modifiers". The run starts with the Blade or the Gun (plus its Skill, dash and Vent);
  the four ability slots of v0.4.0 (F8) are gone.
- **Modifiers layer onto the weapon in order.** "The base should be sword or shooting, and modifiers apply to that,
  we said for example shooting sword, adding the third modifier would be for example fire, shooting a sword that
  applies fire, and the forth one could be a shooting fire sword that divides when you hit an enemy". Each modifier
  adds to what the weapon already does; nothing you hold stops working.
- **6 modifier slots and a swap.** "it makes sense to be able to swap modifiers, if you don't like one you have a
  swap button for the next you get and you can decide which one to swap so you can have a build and modify it on
  the run". With 6 slots full, a new modifier offers **Swap**: you pick which held modifier it replaces (or skip).
  Owner pick: "6 slots".
- **The old abilities become weapon modifiers** (owner pick): Bomb Lobber → every Nth attack also lobs a bomb;
  Drone Buddy → a drone that fires a copy of your weapon's attack; Orbit Blades → copies of your attack orbit you;
  Arc Field → your attacks leave a shock field; Frost Nova → the frost element plus a nova on a kill streak;
  Flame Trail → your dash and your projectiles leave fire. Each carries your other modifiers.
- **The utility button stays** (owner pick: "Keep the utility button"): Blink and Aegis are a separate pick, outside
  the 6 slots.
- **Stat cards stay numbers that show, and don't take a slot** (owner picks: "Visible numbers", "No, unlimited").
- **Colours:** the element owns the attack's core, heat owns the trail's edge (owner pick: "Element core, heat
  edge").

## The goal in one line
**Every card you pick changes what your attacks are, and you can see it.** Not "+12 % damage" on a sheet: your
sword, your shots, your skill and your abilities change shape, number, colour and behaviour as the build grows. By
floor 3 the screen shows your build.

## Today vs the engine
Today each item is hand-wired to one attack: `ricochet_core.tres` sets `bounces = 1` and only the Gun's bolt reads
it; `cluster_payload` only touches Bomb Lobber; stat cards only change numbers. A new item means new code in the
attack that uses it, and nothing else benefits.

With the engine:
1. Every attack is one data record, the **attack spec**.
2. Every card is a **modifier**: a small rule that rewrites specs.
3. The view draws every attack **from its final spec**, so a change in the spec is a change on screen, for free.

```
cards you hold ──► modifiers (sorted by stage) ──► rewrite each attack's spec ──► sim runs the spec
                                                                              └─► view draws the spec
```

## 1. The attack spec (sim data, pure, hashed)
Every attack the player makes is a spec: the Blade's four steps, the Gun's bolt, both Skills, the vent blast, and
every attack a modifier spawns (a lobbed bomb, the drone's copy, an orbiting copy, a shock field, a nova, a fire
patch), plus Blink's landing shock and Aegis's guard burst.

| Field | What it is | Examples |
|---|---|---|
| **form** | What the attack physically is | arc (slash), bolt, ring (expanding circle), beam, zone (lingering patch), orbiter, lob (bomb), burst (instant circle) |
| **pattern** | How many and where | count, spread angle, directions (forward / back / circle), repeat (again after N ticks) |
| **size / speed / reach** | Scale numbers | arc width and reach, bolt speed and range, radius |
| **payload** | What a hit does | damage, crit, knockback, element(s), statuses |
| **behaviour** | How it moves after launch | pierce N, bounce N, home, return, split on hit, orbit first |
| **hooks** | Attacks it spawns | on hit / on kill / on end / on crit → *another attack spec* |
| **tags** | What it is, for filters | melee, projectile, ability, weapon, skill, auto |

A hook spawns a full attack spec, which the modifiers also rewrite. That's where merges come from (§3).

## 2. A modifier (one `.tres` per card)
```
id, family (frame colour), rarity
target:  which specs it rewrites (a tag filter: all · weapon · melee · projectile · ability:drone · dash · vent)
stage:   form | pattern | behaviour | payload | hook | scale
ops:     a short list, e.g.  set_form(ring) · add_count(+2) · set_directions(circle) · add_element(storm)
         · add_hook(on_end, burst r=1.5) · mul(reach, 0.6) · mul(damage, 1.4)
visual:  optional overlay (only if the spec change alone isn't readable): an aura, a trail, a sound layer
```

Modifiers apply in a **fixed stage order**: form → pattern → behaviour → payload → hooks → scale. Inside a stage,
in pick order. So the result never depends on luck in ordering, and a seed replays exactly (EI-05: no new
randomness; procs keep their `combat` rolls).

### The rules that make every combination defined (no hand-made pairs)
- **Layers add, in the order you took them (owner).** The weapon gives the base form (arc or bolt). The first
  form modifier changes what the attack does next, and the following ones layer on top: Blade → *Echo Slash* (a
  shooting sword) → *Ember Core* (the shot sword burns) → *Split Shot* (the burning crescent splits on hit). A
  second form modifier never replaces the first; it fires where the first one ends (a crescent that ends in a
  shock ring). Every combination is defined by this one rule.
- **Patterns multiply.** *Halo* (circle) × *Twin Cast* (repeat) = a circle of shots, then the circle again.
- **Elements stack and mix.** Each element adds its status. Two or more on one attack add the *Resonance* bonus and
  draw as a two-colour attack (§4).
- **Hooks recurse with a guard.** A hook's attack can carry hooks, up to depth 2. Each level has a lower proc
  coefficient (1 → 0.5 → 0.25), and the existing ancestry guard stops loops. Caps on attacks per tick stay.
- **Filters make cards specific without code.** *Mirror Drone* targets `ability:drone`: "copy the weapon's form and
  hooks". *Bomb Rounds* targets `projectile`: "every 5th → form lob".

## 3. Merges: one attack lends its form to another
The owner's example: "grabbing something that shoots makes your sword shoot an echo of the slide whenever you attack".
That is a hook that spawns a copy of the attack in another form:

| Card | Spec rewrite | What you see |
|---|---|---|
| Echo Slash (M5) | melee: on swing → spawn `bolt` with the arc's width as a crescent | Each slash flies on as a glowing crescent |
| Edge Rounds (M6) | projectile: on hit → spawn a small `arc` at the hit point | Bullets that land as tiny slashes |
| Mirror Drone (M27) | ability:drone: copy the weapon's form, pattern and hooks | A Blade drone throws mini crescents; a Gun drone fires your exact shot pattern |
| Blade Orbit (M29) | ability:orbit: take the weapon's elements and hooks | Orbit blades burn, chain and echo like your sword |
| Bomb Rounds (M28) | projectile: every 5th → form `lob` (Bomb Lobber's bomb) | Every fifth shot arcs as a bomb |
| Meltdown Edge (M26) | vent: spawn the weapon's attack with directions = circle | Venting throws your attack all around you |

Because merges copy *specs*, they carry everything else you hold: if your sword already burns and chains, the
crescent from Echo Slash burns and chains too.

## 4. How the view draws a spec (presentation reads, EI-07)
The view never asks "which cards do you have". It reads the final spec and composes the visual from layers:

| Spec field | Visual layer |
|---|---|
| form | the base mesh / effect: arc trail, bolt, ring, beam, zone decal, orbiter, lob with ground circle |
| size, reach, count, directions | the mesh's scale and count; patterns read at a glance (a halo of 12 shots looks like a halo) |
| element(s) | core colour + particles: storm = white-blue crackle, ember = orange sparks, frost = pale shards, venom = green drip, void = violet smear. Two elements: core of one, rim of the other |
| behaviour | motion cues: pierce = streak, bounce = flash at the bounce, home = curved trail, return = a tether line |
| hooks | their own spawned attack, drawn by the same rules (so a hook is visible because it *is* an attack) |
| damage / crit multipliers | weight: thicker trails, brighter cores, heavier sound, bigger hit sparks; crit = a white-hot flash |
| heat tier | the trail's **edge** turns orange at Hot, red at Overclock (A2), over the element core |

The art cost is per **form** (8) and per **element** (5), not per card or per pair: 30 cards and any combination
draw without new art. A card adds an overlay only when the spec change alone isn't readable (e.g. a passive like
Aether Shell's barrier).

Readability rules: player attacks keep a cool-to-warm palette that enemy telegraphs (red/magenta ground marks)
never use; a per-frame budget caps particles and attack meshes (multimesh pools per form); an Options slider lowers
effect density.

## 5. Stat cards become modifiers too ("all of them")
The owner: "we need all of them to be a modifier that adds to your build". Every stat card gets a visible effect
through the scale stage, so no card is invisible:

| Old stat card | As a modifier | What you see |
|---|---|---|
| Damage % | mul(damage) | thicker, brighter attacks; heavier hit sound |
| Attack speed % | mul(rate) | faster swings, shorter trails |
| Crit chance / damage | payload crit | crit flashes and sparks |
| Area % | mul(size, reach, radius) | wider arcs, bigger rings and bombs |
| Projectile speed | mul(speed) | longer streaks |
| Cooldown % | mul(cooldown) | abilities fire more often |
| Max HP, armour | player stats | the hero's crystal plating grows (a body layer, not an attack) |

Numbers still compound multiplicatively (F9's exponential growth), so the god feeling stays; it just shows.

## 6. What a run looks like
Blade start: four plain slashes (slots 0/6).
- Floor 1 arena: **Echo Slash** → every slash throws a crescent: a shooting sword (1/6).
- Chest: **Ember Core** → the crescents and the slashes burn, orange cores (2/6).
- Altar: **Bomb Lobber** → every 4th swing also lobs a bomb, which burns too (3/6).
- Floor 2 shop: **Split Shot** → the burning crescent splits in 3 on its first hit (4/6).
- Arena: **Halo** → the crescents fly out in a ring around you (5/6).
- Boss legendary: **Drone** → a drone throws its own ring of splitting, burning crescents (6/6).
- Floor 3: **Storm Core** is offered with the slots full → **Swap**: you drop Bomb Lobber; now everything burns and
  chains, drawn orange with a blue-white rim.

Nobody wrote "Echo Slash + Ember + Split + Halo + Drone + Storm" anywhere. The rules produced it.

## 7. How it's built (sim and code)
- `AttackSpec` (sim, a typed record), `ModifierDefinition` (`.tres`, ContentScanner) and `ModifierStage` order.
- `Modifiers.compile(build) -> {attack_id: AttackSpec}` runs **on pick** and on load, not every tick. It's cached
  in the build state and hashed.
- Every attack site (weapon steps, bolts, skills, vent, dash, utility) launches from its compiled spec through one
  `Attacks.launch(spec)` instead of its own code. The existing items migrate into modifiers one by one; the 27
  items, the 4 ability mods and the six old abilities become the first modifier set.
- The build state holds the weapon, the utility pick, up to 6 modifier ids in pick order (the layer order), and
  the stat cards. A pick with 6 held opens the Swap choice (keyboard, mouse and pad; an e2e through `main.tscn`).
- One `AttackView` composes visuals from the spec (§4); per-form scenes, per-element materials.
- **Tests without bots (P1):** a combinatorial smoke test compiles every modifier against every attack (and every
  pair of modifiers), runs a fixed scripted fight for a few seconds and asserts no crash, a bounded number of
  attacks, the caps holding and a stable replay hash. It proves that combinations work, not that they're balanced.
  Balance is the owner's play.
- Saves: the build stores card ids. The spec is recompiled on load, so saves stay small and old saves keep working
  as long as the ids exist.

## 8. Order of work (proposed)
1. Spec + compile + `launch` for the Gun bolt and the Blade arc; the view composes them. The current items move
   over; same feel, no new cards (prove nothing broke).
2. The build model: weapon + utility + 6 modifier slots with Swap; the six old abilities become modifiers; the
   skills, vent and dash launch from specs. Saves migrate (old ability ids map to their modifiers).
3. The form / element art layers (8 forms, 5 elements), the edge heat tint.
4. The first new cards from the approved M-list, stat cards as modifiers, the smoke test. **Built in v0.6.0 Step MX4
   (M1–M30, three legendary versions, the smoke test over the cards; stat cards as modifiers not yet):
   [`../roadmap/v0.5.5/evidence/MODIFIER_ENGINE_4.md`](../roadmap/v0.5.5/evidence/MODIFIER_ENGINE_4.md).**
5. The legendary tier for the boss reward (X1b) from the same engine. **MX4: the boss tier offers legendary modifiers
   (three stronger versions and the five trinkets) and the legendary stat cards.**

## Open questions for the owner
- None for the build model. The M-list was approved in full ("keep all M1–M30", 2026-10-08).

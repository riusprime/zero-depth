# ZeroDepth — Gameplay, Combat & Visual Overhaul

**Development brief — October 22, 2026**  
**Status:** Planned changes, not yet implemented.

## 1. Floor transition portals

Replace the existing squar portals that appear after defeating a floor boss.

### New appearance

- Two separate, narrow portals with vertically stretched, elongated shapes, kinda like rick and morty shape.
- Retain the existing animated swirling interior rather than recreating the effect.
- They should materialize through a proper spawning animation after the boss dies, rather than appearing instantly.


The new portals should remain visually readable from ZeroDepth's isometric camera.

## 2. First-floor spawn altar

Replace the current starting portal/platform with a substantially larger, fully modeled 3D altar.

### Visual design

- Circular stone platform, approximately 3 times larger than the current structure.
- Three or four stone steps leading to the central platform.
- Ancient stone, consistent with the game's existing low-poly, faceted art direction.
- Floating or carved arcane runes arranged around the altar.
- Glowing blue symbols, with optional small crystals or jewels around the sides.
- The symbols do not need a real language or meaning; their primary purpose is visual.
- We need a new prompt for this model


### Spawn animation sequence

1. **Idle:** The player initially sees an empty stone altar.
2. **Activation:** Blue runes and jewels begin illuminating, possibly in sequence.
3. **Rotation:** The glowing symbols begin orbiting the altar, gradually increasing speed.
4. **Energy buildup:** Blue particles, glow, magical noise, and swirling energy intensify around the center.
5. **Spawn:** The existing player-spawn effect plays, synchronized with the main audio cue.
6. **Release:** The runes slow down, energy dissipates, and control returns to the player.

### Camera improvement

The current camera shake moves diagonally and feels too directional.

Replace it with a short, subtle vibration that conveys magical energy or a heavy impact without visibly pulling the camera across the screen.

The shaking should increase slightly during the buildup and peak at the spawn, then fade out naturally.

**Technical direction:** Prefer a reusable altar scene with configurable colors, rune objects, animation timing, sound, and activation triggers. The runes can use custom textures, emissive materials, or independently animated 3D objects.

## 3. Final boss entrance redesign

The player should no longer teleport directly into the final boss arena.

Instead, reaching the final boss should initiate a short transition to a dedicated approach floor.

### New sequence

1. Player completes the necessary floor and enters the final boss transition.
2. Player arrives on a separate, quieter environment.
3. The environment features stairs and a clear path leading toward a large altar (new platform where the boss will appear).
4. The altar resembles the starting altar but has a more ominous purple appearance.
5. The player must activate a small number of mechanisms, approximately two, around the altar.
6. Once activated, the purple runes illuminate and begin spinning.
7. A buildup animation begins, using a modified version of the starting altar sequence.
8. The final boss encounter is initiated.

This is intended to add anticipation and a sense of progression before the final encounter.

**Design requirements**

- Reuse the starting altar's models, animations, and scripts where practical.
- Purple replaces blue as the main magical color.
- Activation mechanisms must provide obvious visual feedback.
- The boss sequence must only trigger once the required activations are complete.
- The environment should build tension without adding a long or tedious gameplay section.

The exact stairs, layout, and mechanism design can be decided during implementation.

## 4. Regular boss door audio synchronization

The large impact or boom effect currently associated with the regular boss door opening is slightly late.

Move the sound earlier so its strongest transient aligns with the moment the heavy door hits the ground.

Do not change the entire animation unnecessarily. Inspect the existing timeline and adjust the sound trigger first. just move it a bit earlier like 0.5s aprox


## 5. Combat system restructuring

This is the main gameplay change.

The current modifier system makes it possible to stack powerful upgrades until the player's basic attack becomes excessively strong, particularly with attack speed, multiple projectiles, and overlapping attack modifiers.

We want a more deliberate system that still allows creative, powerful builds.

### Proposed architecture

Split the attack system into three independent categories.

| Category | Purpose | Examples |
|---|---|---|
| **Attack Form** | Determines what the player actually fires | Orbs, laser, bombs, void projectiles |
| **Attack Pattern** | Changes projectile quantity, arrangement, or movement | Twin, spread, ring, spiral, swirl |
| **Elemental Effects** | Adds damage types and status effects | Fire, venom, electricity, other existing elements |

These categories should interact, but should not all be freely stackable.

### Slot structure

The intended design includes a small number of dedicated attack-related slots, rather than allowing every modifier to stack infinitely.

**Attack Form — one active**

The player selects or obtains one primary weapon/attack form. Equipping another replaces it.

**Attack Pattern — one primary pattern active**

Twin, spread, ring, spiral, and similar modifiers should compete for the primary pattern position instead of combining without restrictions.

The broader target is approximately two or three attack-shaping upgrade slots, but only one mutually exclusive primary pattern should be active. Remaining slots, if used, can support compatible secondary behavior upgrades.

**Elemental Effects — independent**

Retain the existing elemental modifier system, with effects applying to compatible attack forms.

There are approximately six existing effect types to account for. Confirm their exact names and behavior from the current project before changing them.

The final number of available element slots must be established after reviewing the current implementation.

**Important:** The exact slot counts are not finalized. Build the system so these limits can be adjusted through data/configuration without rewriting the combat scripts.

## 6. New attack forms

### 6.1 Standard orb projectiles

Keep the existing normal ranged attack as the default.

This provides the baseline against which other attack forms are balanced.

Compatible with existing elemental effects and standard projectile patterns, subject to their new compatibility rules.

Now he have some examples of new attack forms, we should have around 8-10 total attack replacements. so there are multiple builds possible with the modifiers like twin or swirl

### 6.2 Continuous laser

Introduce a new attack that replaces standard projectile firing with a sustained beam.

**Behavior**

- Holding the attack button continuously fires a laser in the aiming direction.
- Damage is applied through frequent ticks rather than individual large projectile impacts.
- Individual ticks deal substantially less damage than an orb hit.
- Sustained contact should provide competitive, potentially higher single-target damage than standard projectiles, without making the laser objectively superior in every situation.
- The laser follows the player's aim as they move.

**Element interactions**

The beam's color, particles, impact effects, and potentially behavior should reflect the equipped element.

Examples:

- **Default:** Original energy color, consistent with the normal projectile.
- **Fire:** A layered beam incorporating the established fire palette, with multiple warm tones.
- **Venom:** Green or toxic-colored energy, with corresponding impact particles.
- **Electricity:** Blue-white or electrical arcs around the beam.

Other existing elements should receive equivalent treatment.

The color change alone is not sufficient: ideally the impact effect and beam texture also reflect the element.

**Balancing**

Consider range, tick frequency, sustained aiming, target penetration, and exposure time.

Avoid giving the beam the entire benefit of projectile count or attack-speed bonuses without restrictions.

It must be mechanically distinct from simply firing orbs extremely quickly.

### 6.3 Bomb launcher

Introduce an attack form that replaces regular projectiles with aimed bombs.

**Behavior**

- The player launches bombs toward the aiming direction.
- Initial proposed cadence: approximately one bomb per second.
- Bombs explode on impact or according to a consistent, short detonation rule.
- Explosions damage enemies within a defined area.
- Elemental effects apply to the explosion where appropriate.

**Compatibility**

Allowed:

- Bomb + Twin: Two bombs launched per attack, with appropriate damage balancing.
- Bomb + elemental effects.

Not allowed:

- Bomb + Ring.
- Bomb + another primary attack form such as Laser.

Spread or other patterns require an explicit compatibility decision rather than automatic support.

**Balancing**

Bombs should deliver larger damage per individual attack, with lower frequency than orbs.

Account for AoE damage, multiple enemies hit, explosion overlap, and interactions with attack speed.

Twin bombs should be effective but not automatically double overall damage efficiency without a tradeoff.

### 6.4 Void projectile / miniature black holes

Remove the previously planned effect that randomly creates a gravity point on the floor and attracts enemies.

**That specific ground-spawning gravity modifier should be deleted from the item pool and associated attack behavior.**

Replace the concept with a true projectile attack form.

**New behavior**

- The player fires miniature black-hole projectiles.
- These projectiles travel in the aiming direction, similarly to other attacks.
- As a projectile travels, nearby enemies experience a weak gravitational pull toward its trajectory.
- The projectile causes damage in a small area around itself.
- The gravitational effect is subtle, not a strong crowd-control ability that completely immobilizes enemies.
- Enemies can still pursue and attack normally.

The visual should communicate a moving gravitational anomaly, not a stationary vortex.

**Balancing**

- Limit the pull strength and radius.
- Avoid infinitely dragging enemies or permanently interrupting their movement.
- Consider reduced effectiveness against bosses or large enemies.
- Avoid multiple void projectiles creating extreme enemy displacement or performance issues.

This form may work with certain projectile patterns, but compatibility should be tested before enabling combinations.

## 7. Attack pattern modifiers

The existing and newly planned patterns need clear rules.

| Pattern | Intended behavior |
|---|---|
| Twin | Fires an additional attack/projectile alongside the original |
| Spread | Distributes projectiles across different angles |
| Ring | Creates attacks that orbit or arrange themselves around the player |
| Spiral | Projectiles follow or launch in a rotating spiral arrangement |
| Swirl | A distinct swirling trajectory or arrangement, preserving existing behavior if already implemented |

Review the game's existing patterns first. Do not create duplicates of mechanics already present.

### Compatibility rules

Create a centralized compatibility system instead of special-casing every item separately.

| Attack Form | Twin | Spread | Ring | Spiral / Swirl | Elements |
|---|---|---|---|---|---|
| Standard Orbs | Yes | Yes | Yes | Yes, if supported | Yes |
| Laser | Requires tailored behavior | Requires tailored behavior | No by default | No by default | Yes |
| Bomb | Yes | To decide | No | No by default | Yes |
| Void Projectiles | Test and balance | Test and balance | No by default | Test and balance | Yes, if supported |

"No by default" and "test and balance" are proposed initial restrictions, not confirmed design decisions. Do not silently introduce unapproved interactions.

**Core rule:** Different attack forms cannot coexist as simultaneous primary weapons unless a future system explicitly introduces dual weapons.

For example:

- Laser + Bomb: Not allowed.
- Bomb + Twin: Allowed.
- Bomb + Ring: Not allowed.
- Orb + Twin: Allowed.
- Twin + Ring: Not simultaneously active as competing primary patterns.

This should prevent the system from generating combinations that are impossible to represent cleanly or impossible to balance.

### Implementation guidance

Use reusable attack and modifier definitions, preferably compatible with the project's existing Godot architecture.

Each attack form should define its supported patterns and supported effects.

The card/loot selection system must respect these rules. An incompatible modifier should not be offered as an upgrade that the player cannot actually use.

If replacing an equipped form or pattern is supported, the UI must make the replacement obvious.

## 8. Elemental effects

Preserve the elemental identities already established in ZeroDepth rather than inventing a separate element system.

Known examples include:

- Fire
- Venom
- Electricity / Shock
- Void, where applicable - void becomes a new attack modifier where you throw the black holes as a gun, lower frequency and the enemies get pulled towards the attack, but a subtle pull they should never move really fast 10 enemies at the same point very strong, so just a subtle pull that changes slightly the trajectory of enemies. the elemental effect of void is replaced by the other one

Confirm the remaining existing effects from the game's current definitions.

Elements should modify the chosen attack form, rather than behave as completely separate weapons.

Examples:

- **Fire + Laser:** A layered flame-colored energy beam with burning impact effects.
- **Venom + Bomb:** Bombs detonate into toxic-looking explosions and apply the relevant venom behavior.
- **Shock + Orbs:** Standard projectiles retain their movement but gain electrical visuals and the appropriate status effect.


Do not assume every effect must work identically on every attack.

The aim is to make different forms and elements create genuinely interesting combinations without requiring entirely separate combat implementations for each.

## 9. Damage and attack-speed balancing

Two legendary cards currently grant approximately +40% bonuses associated with damage and attack speed.

These need a moderate nerf.

Review their current exact values and formulas, then reduce them slightly without making them undesirable legendary rewards.

The final values should be selected through playtesting rather than changed arbitrarily.

### Broader balancing review

Pay particular attention to:

- Attack-speed stacking with Twin, Spread, and other projectile multipliers.
- High projectile counts causing extreme damage and visual clutter.
- Whether attack speed scales lasers by increasing tick damage too aggressively.
- Whether bombs become disproportionately powerful when fired faster.
- Multiple elemental effects scaling damage multiplicatively.
- Whether special patterns can bypass normal attack limitations.

The previous problem of builds producing dozens of projectiles per second should be treated as a regression to prevent.

**Balance targets**

1. A build should gradually become powerful across floors, rather than immediately reaching extreme damage.
2. Different attack forms should have recognizable strengths and weaknesses.
3. Rare, extremely powerful combinations can still exist, but should require appropriate progression and investment.
4. Legendary rewards should feel meaningful without trivializing the game.
5. The system should support future attacks and modifiers without requiring another complete rebalance.

Review loot weights and progression only where necessary to support the new slot and compatibility system.

## 10. New visual effects

Several recently added items and attack modifiers are still missing proper VFX.

Audit the full list of existing modifiers and identify which currently have placeholder, missing, or visually weak effects.

Then implement a consistent set of effects for:

- Projectile launch and travel.
- Projectile impact.
- Elemental application.
- Attack-specific effects, including laser, bomb, and void.
- Special patterns such as Twin, Ring, Spiral, and Swirl where needed.
- New modifiers that already exist in code but do not have their intended visual representation.

### Visual direction

Maintain the game's existing visual identity:

- Stylized low-poly/faceted aesthetic.
- Clear shapes and readable silhouettes.
- Bold elemental colors.
- Cel-shaded or deliberately stylized energy effects.
- Avoid excessive realistic particles, muddy glows, or effects that obscure combat.

The developer should use Godot's native capabilities where appropriate, but not feel restricted to weak-looking native primitives when shaders, meshes, custom textures, or sprite sheets would look better.

**Asset workflow**

Some custom textures, elemental sprites, glyphs, and other VFX assets can be created externally and supplied later.

Implement the effects in a modular way so those assets can replace initial placeholders without major code changes.

Prioritize visual quality and gameplay readability from the actual isometric game camera, not only in isolated previews.

## 11. Text and description overhaul

Review and rewrite all item, modifier, upgrade, and attack descriptions.

Current text should be improved to sound professional, consistent, and appropriate for a finished game.

**Requirements**

- Consistent naming across the entire game.
- Clear explanation of gameplay effects.
- Consistent terminology for damage, status effects, cooldowns, and attack patterns.
- Correct numerical descriptions matching actual implemented values.
- No awkward, overly technical, or placeholder copy.
- No claims about stacking or compatibility that contradict the mechanics.

For instance, if an attack modifier replaces another rather than stacking with it, the player should understand that before selecting it.

Preserve both English and Spanish localization wherever currently supported.

Separate gameplay values from hardcoded description strings wherever possible, so future balancing changes do not leave inaccurate text.


## 14. Decisions to finalize during implementation

Some details were intentionally left flexible and should not be presented as already finalized:

1. Exact number of attack-form, attack-pattern, and elemental slots.
2. Whether the two or three proposed attack-shaping slots contain secondary compatible upgrades, or whether a stricter single-pattern system is better.
3. Final compatibility of Laser and Void with advanced patterns.
4. Final six-element list and any special elemental interactions.
5. Exact laser tick frequency, bomb cadence, damage coefficients, and void attraction strength.
6. New numerical values for the legendary cards.
7. Layout and interaction mechanics of the final boss approach floor.

These decisions should be made with reference to the current codebase, existing gameplay mechanics, and practical playtesting.

---



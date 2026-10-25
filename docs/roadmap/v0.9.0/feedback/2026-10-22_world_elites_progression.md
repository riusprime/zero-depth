# ZeroDepth 2.0 — World Interaction, Elite Enemies & Progression Expansion

**Game design report — October 22, 2026**  
**Status:** Planned expansion. Features described here are design requirements or proposals, not completed implementations.

## 1. Overall objective

Expand ZeroDepth beyond its current combat-focused roguelike loop with interactive environments, short puzzles, secret discoveries, special enemy encounters, a persistent hub, and progression between runs.

The game should alternate between intense combat, exploration, discovery, and smaller environmental challenges.

### Core design principles — Mandatory

**1. Combat remains the priority.**

ZeroDepth must not become a puzzle game. Puzzles and interactions should be short, intuitive, and usually understandable within a few seconds.

Timed doors, rune switches, breakable walls, and surprise encounters are more appropriate than elaborate puzzles that interrupt the flow.

**2. The hub should be a mystery worth exploring.**

The hub must be more than a shop or a place to start runs. It should gradually change as players progress.

Previously dark runes might illuminate, new corridors might become accessible, and unusual structures could react to discoveries made during runs.

Players should have reasons to explore the hub and notice changes beyond simply purchasing upgrades.

**3. Permanent progression should unlock variety, not raw power.**

Avoid permanent upgrades that continuously increase damage, attack speed, or maximum health.

Progression should primarily unlock new ways to play, cosmetic options, secrets, additional content, and limited utility.

The player's skill, choices, and builds within each run should remain the main determinants of success.

These three principles should guide all development decisions in this report.

---

## 2. Timed secret doors

Create optional rooms containing a closed door controlled by two separate interactive mechanisms.

### Gameplay sequence

1. The player discovers the closed door.
2. Two interactive switches, runes, or mechanisms must be activated.
3. Activating both opens the door, playing the existing broken-door opening sound.
4. A rhythmic beeping sound starts.
5. The beeping progressively accelerates, indicating the door is about to close.
6. The player must reach the entrance before the timer expires.
7. If the player fails, the door closes and the mechanisms reset.

### Presentation

The opening should feel mechanical and impactful.

The countdown should communicate urgency primarily through sound:

- Slow beeps at first.
- Increasing frequency as time passes.
- Very fast beeping immediately before closure.
- A heavy impact when the door shuts.

Include visual feedback, such as flashing runes, for accessibility.

### Technical requirements

- Suggested starting timer: 12–18 seconds, adjustable after testing.
- Ensure completion is possible at normal movement speed.
- No permanent penalty for failure.
- Reset safely without trapping the player.
- Allow variations in switch placement and layout.
- Make rewards or secret areas optional.

## 3. Combat lockdown rooms

Introduce occasional rooms that close their doors when the player enters.

The player must defeat a contained encounter before leaving.

These should differ from the existing overrun mechanic.

### Encounter sequence

1. Player enters.
2. Doors close with a noticeable audio and visual effect.
3. A small encounter begins.
4. Enemies spawn in a controlled arrangement.
5. Defeating them reopens the exits.
6. The player receives the appropriate reward.

### Variations

**Normal Lockdown:** A short encounter involving familiar enemies.

**Elite Lockdown:** A rarer encounter featuring a stronger, unique enemy, respecting the elite spawn restrictions described later.

**Hazard Lockdown:** A short fight with environmental dangers.

Lockdowns should create a change of pace rather than another long combat mode.

Target approximately 20–40 seconds for ordinary encounters, depending on difficulty.

Ensure exits reopen reliably even if an enemy fails to spawn, gets stuck, or otherwise becomes inaccessible.

## 4. Environmental puzzles and interactions

Introduce a selection of short, reusable mechanics.

These should be optional in most cases.

### Puzzle A — Rune Alignment

Several rune pillars can be rotated.

The player aligns symbols according to a visual clue to unlock a reward.

### Puzzle B — Energy Relay

The player activates several crystal nodes in a particular order.

Connecting the nodes powers a door, chest, or portal.

### Puzzle C — Destructible Secrets

Certain walls, statues, or props contain subtle visual clues indicating that they can be destroyed.

Breaking them reveals hidden spaces, resources, or collectibles.

### Puzzle D — Pressure Plates

The player moves a small object onto a pressure plate to open a nearby gate.

Keep the interaction simple. Avoid complex physics puzzles.

### Puzzle E — Unstable Rune Portal

An inactive portal can be activated, beginning a short challenge.

Completing it stabilizes the portal and opens an optional reward area.

### Puzzle F — Hidden Sequence

Several statues or symbols must be activated in the correct order.

The solution should be discoverable through environmental clues.

### Development priority

Do not implement every puzzle immediately.

Start with:

- Timed doors.
- Rune alignment.
- Destructible secrets.

Evaluate their effect on the game's pacing before adding the other systems.

Build reusable Godot components so the same interaction logic can support different visual models and room layouts.

## 5. Additional environmental interactions

Add small interactive objects that make rooms more interesting without requiring full puzzles.

| Interaction | Function |
|---|---|
| Destructible containers | Small resource or reward chance |
| Ancient shrines | Optional short-term benefit |
| Healing fountains | Limited healing opportunities |
| Cursed altars | Reward in exchange for a disadvantage |
| Explosive objects | Environmental combat interactions |
| Hidden rune markings | Clues to secrets |
| Interactive statues | Lore or hidden events |

### Risk/reward shrines

Introduce optional shrine encounters.

Examples:

**Blood Shrine:** Sacrifice current health for an immediate reward.

**Chaos Shrine:** Trigger a short challenge to earn an additional upgrade.

**Fortune Shrine:** Exchange an appropriate resource for a randomized reward.

Shrines should communicate their costs clearly before activation.

Avoid introducing unnecessary new currencies or complicated interaction menus.

## 6. Easter eggs and collectibles

Create a system that rewards players for exploring and paying attention.

### Secret types

**Collectibles:** Discoverable artifacts, rune fragments, or unusual items.

**Hidden rooms:** Rare spaces containing rewards or mysterious objects.

**Environmental Easter eggs:** Strange statues, references, unusual scenes, or hidden interactions.

**Lore fragments:** Small pieces of information that gradually explain ZeroDepth's world.

**Special discoveries:** Rare interactions that unlock additional hub content.

### Collectible archive

Once collected, discoveries should be permanently recorded.

Store:

- Unique identifier.
- Name and description.
- Associated biome or discovery condition.
- Collected/uncollected status.
- Optional visual preview.

Suggested initial scope: 12–20 distinctive collectibles spread across existing environments.

These should feel like discoveries rather than a repetitive checklist.

## 7. Persistent starting hub

Create a more detailed, explorable hub that players visit between runs.

Use ZeroDepth's ancient rune aesthetic, stone structures, magical machinery, and mysterious atmosphere.

### Main hub areas

**Central Portal Machine**

The main structure used to initiate a run.

It connects to the previously planned first-floor spawn altar.

The hub portal sends the player into the run; the blue altar is their arrival point.

**Rune Archive**

A collection area where discovered artifacts, lore fragments, and secrets can be inspected.

**Wardrobe**

A location for selecting unlocked robe colors and cosmetic variations.

**Progression Station**

A place for unlocking additional gameplay variety and small utility options.

**Trophy Area**

Displays major accomplishments, defeated bosses, special challenges, and discoveries.

### The evolving hub — Mandatory

The hub should change as players progress.

Examples:

- Previously inactive runes begin glowing.
- A sealed corridor opens after a particular discovery.
- An ancient machine becomes interactive.
- New symbols appear after defeating specific bosses.
- Secret rooms become accessible.
- Collected artifacts physically appear on pedestals.
- Small environmental details change after important milestones.

Not every change needs an explicit notification.

Some should be subtle enough that attentive players notice them naturally.

The hub should contain its own mysteries and optional discoveries, making it feel like part of the world rather than a functional menu.

### Returning after runs

After death or completion, the player returns to the hub.

Display a short run summary and preserve unlocked content.

Restarting another run must remain fast and convenient.

## 8. Persistent currency and progression

Introduce one main currency earned throughout runs.

Working name: **Rune Fragments**.

### Sources

- Floor completion.
- Boss defeats.
- Optional challenges.
- Hidden room discoveries.
- Run completion.
- Special milestones.

Earning should be gradual, without making early unlocks excessively grindy.

### Unlock categories

**Cosmetics**

- Robe colors.
- Visual variations.
- Different rune effects.
- Alternative spawn animations.

**Gameplay variety**

- Additional attack forms.
- Unlockable modifiers.
- Alternative starting choices.
- Special challenge content.

**Utility**

- Limited convenience improvements.
- Optional exploration-related abilities.
- Small nonessential progression benefits.

### Balance requirement

Do not implement permanent, repeatedly purchasable increases to damage, attack speed, or health.

These could undermine the roguelike balancing changes already planned.

The progression system should reward continued play by expanding possibilities rather than making the player automatically stronger.

## 9. Robe customization and rune affinities

Introduce unlockable robe colors and possible cosmetic variations.

Robe appearance can be paired with a small gameplay effect, but appearance should not determine power.

### Recommended structure

Separate **Robe Appearance** from **Rune Affinity**.

The player chooses their appearance independently from any minor gameplay-affecting affinity.

### Example affinities

| Affinity | Possible effect |
|---|---|
| Ember | Small interaction with burn effects |
| Storm | Minor electrical utility |
| Venom | Small poison-related utility |
| Astral | Helps discover nearby rune secrets |
| Guardian | Minor defensive utility |

Exact effects require balancing.

Affinities should be sidegrades, not compulsory upgrades.

No individual affinity should become the universally strongest choice.

## 10. Elite Enemy Redesign — Major addition

The current concept of elites as ordinary enemies with increased health should be replaced.

**Elites must become distinct enemy archetypes with unique 3D models, dedicated abilities, and a miniboss-like presentation.**

Their purpose is to create a controlled spike in intensity toward the end of a run, particularly as the player approaches the final floors or prepares to enter the purple portal.

They should be threatening and memorable without becoming excessively punishing.

### 10.1 Visual identity

Elite enemies should be visually distinct from regular enemies.

Each elite archetype should have:

- A unique 3D model or meaningfully unique silhouette.
- A larger, more imposing appearance where appropriate.
- Distinctive armor, color accents, or visual details.
- Unique attack animations.
- Clear anticipation and telegraph effects for its special ability.

Reusing normal enemy models with different colors or larger health values is not sufficient.

Their design should remain consistent with the game's stylized, low-poly, faceted visual identity.

### 10.2 Elite health bar

Replace the current presentation with a more prominent overhead health bar.

Requirements:

- Larger than the normal enemy health bar.
- Positioned above the elite.
- Visually distinct through color, framing, or decoration.
- Clearly readable from the isometric camera.
- Scales correctly with camera distance and enemy size.
- Does not obscure important combat information.

The bar should communicate that this is a more significant encounter without requiring a full-screen boss health UI.

Consider adding a small elite name above the bar if this improves recognition.

### 10.3 Combat characteristics

An elite should be stronger than a normal enemy, but not comparable to a full boss.

Each elite archetype should feature:

**Higher health:** Enough to survive longer than a regular enemy, without creating an excessively long encounter.

**Slightly higher damage:** A noticeable increase, but not enough to punish the player with unavoidable burst damage.

**One distinctive special ability:** Similar in presentation to a simplified boss mechanic.

**Clear telegraphing:** Important attacks must be understandable and avoidable.

**Recognizable behavior:** An elite should feel meaningfully different from ordinary enemies.

Avoid simply stacking multiple special attacks, extremely high movement speed, and large damage bonuses.

The objective is more interesting combat, not inflated difficulty.

### 10.4 Proposed elite archetypes

These are initial concepts, not confirmed final enemies.

**The Breaker**

A heavily armored enemy with a slow, powerful area attack.

- Large, imposing stone-and-metal model.
- Performs a ground slam with a visible warning area.
- Slow movement and clear recovery window.
- Threat comes from positioning rather than constant damage.

**The Rift Hunter**

A mobile elite that briefly repositions before attacking.

- Distinctive angular silhouette.
- Short-range dash or teleport-like movement.
- Signals its landing point or attack direction.
- Requires the player to adapt their movement.

**The Conduit**

An arcane enemy with a dangerous but avoidable ranged ability.

- Unique rune-covered model.
- Charges a beam or line attack.
- Clearly telegraphs the attack before firing.
- Vulnerable during its recovery period.

These examples should be evaluated against the enemy roster to avoid duplicating existing bosses or abilities.

Begin with a small number of high-quality elites rather than a large collection of weak variations.

### 10.5 Elite spawning rules

**Elites should appear primarily during the final two floors of a standard run.**

They should not become common enemies appearing constantly throughout the entire game.

Spawn rules:

1. Normal elite spawning is restricted mainly to the final two floors.
2. Earlier floors should generally not contain elites during normal room generation.
3. Special events may spawn an elite earlier.
4. Earlier elite appearances should be clearly framed as unusual encounters.
5. Elite frequency should increase tension toward the end without making every room an elite fight.
6. Avoid unfair combinations involving several elites and large normal enemy groups.

### Special event exceptions

An elite may appear earlier when triggered by:

- A rare special room.
- A shrine challenge.
- An optional event.
- A particular secret encounter.
- Another explicitly designed event.

These exceptions must be intentional rather than random elite placement throughout the entire run.

### 10.6 Purple portal difficulty escalation

Entering the purple portal or approaching that stage of progression should create a noticeable increase in intensity.

Elites can contribute to this escalation.

The goal is to signal that the player has entered a more dangerous stage of the game.

However, difficulty should not jump so sharply that a previously viable build immediately becomes ineffective.

The purple portal must remain challenging but reasonable.

Avoid combining excessive elite health scaling, increased enemy density, high damage, and additional special abilities all at once.

Consider a controlled increase in elite frequency or encounter difficulty rather than simply multiplying all enemy statistics.

### 10.7 Elite encounter presentation

When an elite appears:

- Use a recognizable visual introduction or short spawn effect.
- Ensure its larger overhead health bar becomes visible.
- Give its special ability distinctive audio and visual cues.
- Allow the player to identify and react to its behavior.
- Avoid lengthy cinematic introductions that interrupt every fight.

Elites should feel important because of their design and abilities, not because the game repeatedly stops to announce them.

### 10.8 Elite rewards

Defeating an elite should feel worthwhile.

Possible rewards include:

- A better-than-normal upgrade opportunity.
- Additional run-specific resources.
- A small chance of rare rewards.
- Special event completion rewards.

Do not automatically guarantee legendary items unless explicitly balanced around that reward.

Reward quality should reflect encounter difficulty.

### 10.9 Elite balancing

Review the existing enemy and boss scaling before deciding numerical values.

Suggested initial principles:

- More HP than a regular enemy, but substantially less than a boss.
- Slightly increased damage.
- One main special ability with clear counterplay.
- Limited simultaneous elite encounters.
- No extreme movement speed or unavoidable attacks.
- No excessive crowd-control combinations.

Pay particular attention to second-loop scaling and purple portal difficulty, which have previously been areas of concern.

Elites should create short periods of increased tension and demand greater attention from the player.

**The target experience is a controlled miniboss encounter, not an unavoidable difficulty wall.**

### 10.10 Elite encounter pacing safeguard

Use an elite encounter budget or spacing rule rather than relying entirely on random spawning. Avoid stacking several miniboss-like encounters in consecutive rooms unless a special event explicitly calls for it. This is especially important after entering the purple portal.

## 11. Biome-specific environmental variety

Use existing environments to create distinct interactions without rebuilding the puzzle system for each biome.

| Biome | Suggested interactions |
|---|---|
| Ruins | Ancient machinery, destructible walls, pressure plates |
| Night Rocks | Hidden paths, glowing switches, unusual statues |
| Red Canyon | Heat vents, unstable structures, explosive hazards |
| Frozen Shore | Frozen mechanisms, ice-covered runes |
| Starfall | Cosmic relays, floating runes, unstable portals |

Interactions can share scripts and mechanics while using different models, sounds, and visual effects.

## 12. Room pacing and procedural generation

The normal combat loop must remain dominant.

An initial pacing target:

- 70–80% normal combat and traversal.
- 10–15% special combat encounters, including lockdowns.
- 10–15% optional puzzles, secrets, and interactive rooms.

These percentages are starting estimates, not mandatory generation probabilities.

Elite frequency should be controlled separately according to floor progression.

### Generation requirements

Each special room should define:

- Room category.
- Eligible biomes.
- Minimum or eligible floors.
- Required interactions.
- Enemy and elite eligibility.
- Entry and exit configuration.
- Rewards.
- Difficulty.
- Whether the room is optional.

Not every floor needs every interaction.

Special encounters should feel surprising, rather than predictable or repetitive.

## 13. Technical implementation

Build the expansion using reusable systems compatible with the existing Godot architecture.

### Proposed components

**Interactable Controller**

Common player interaction logic for switches, altars, machines, and other objects.

**Puzzle Controller**

Tracks puzzle conditions, activation order, resets, and rewards.

**Timed Door Controller**

Manages unlocking, audio countdown, closure, and reset.

**Room Encounter Controller**

Locks doors, spawns enemy groups, and detects encounter completion.

**Elite Enemy Framework**

Supports unique elite models, abilities, health presentation, telegraphs, scaling, and encounter rules.

**Secret and Collectible Manager**

Tracks persistent discoveries and prevents duplicate rewards.

**Hub Controller**

Manages run initiation, return transitions, and persistent environmental changes.

**Persistent Progress Manager**

Stores currency, unlocks, cosmetics, achievements, and discoveries.

These are architectural responsibilities rather than mandatory script names.

Reuse current systems where appropriate.

Ensure all new features work with procedural room generation and existing save data.

## 14. Development roadmap

### Phase 1 — Interactions and room variety

- Implement the two-switch timed door.
- Add accelerating countdown audio.
- Implement basic combat lockdown rooms.
- Create a reusable interaction framework.
- Add one simple rune puzzle.
- Add destructible environmental secrets.

### Phase 2 — Elite redesign

- Audit the current elite implementation.
- Replace stat-enhanced normal enemies with dedicated elite archetypes.
- Create the first unique elite model.
- Implement a special ability and readable telegraph.
- Create the larger overhead elite health bar.
- Restrict normal elite spawns mainly to the last two floors.
- Support intentional special-event exceptions.
- Balance elite encounters around end-of-run progression and the purple portal.

### Phase 3 — Hub and persistent progression

- Create the detailed starting hub.
- Integrate the portal machine.
- Implement the return-to-hub flow.
- Add persistent currency and saving.
- Add robe customization.
- Create the collectible archive.
- Implement initial hub changes based on player discoveries.

### Phase 4 — Secrets and world expansion

- Add more collectibles and Easter eggs.
- Expand biome-specific interactions.
- Add hidden hub corridors and mysteries.
- Implement optional shrine encounters.
- Add more elite archetypes.
- Introduce additional puzzles only if earlier implementations prove enjoyable.

### Phase 5 — Balancing and polish

- Tune room and elite frequencies.
- Review difficulty spikes.
- Validate puzzle duration and clarity.
- Improve audiovisual feedback.
- Test procedural generation for softlocks.
- Verify persistent progression and save compatibility.
- Check performance in combat-intensive rooms.

## 15. Acceptance criteria

### Core gameplay

- Combat remains the dominant experience.
- Optional puzzles do not create tedious interruptions.
- Interactive doors and lockdown rooms function reliably.
- Environmental interactions are understandable without extensive instructions.

### Elites

- Elites have unique visual identities and models.
- Each elite has at least one clearly telegraphed special ability.
- The overhead health bar is noticeably larger and distinct.
- Normal elite spawns occur predominantly in the final two floors.
- Earlier appearances only occur through designed exceptions.
- Elites remain challenging without becoming excessively tanky or lethal.
- Purple portal progression feels more intense without an unreasonable difficulty spike.

### Hub and progression

- Players can explore a persistent hub.
- New areas or environmental changes become discoverable over time.
- Collectibles remain saved between runs.
- Currency and cosmetic unlocks persist.
- Permanent progression does not depend on repeatedly increasing raw damage or health.
- Players can begin another run quickly.

### Technical quality

- New mechanics do not introduce room softlocks.
- Elite deaths and encounter completion trigger correctly.
- Existing saves remain functional or migrate safely.
- Special-room generation respects floor restrictions.
- Visual effects remain readable from the isometric perspective.
- Performance remains acceptable during complex encounters.

---

## Final development objective

ZeroDepth 2.0 should evolve from a primarily combat-focused roguelike into a more complete action roguelike with exploration, mysteries, varied encounters, and meaningful persistent progression.

The combat should remain the strongest part of the experience.

Puzzles provide brief changes of pace. Secrets reward curiosity. The hub gives players a world to return to. Persistent unlocks increase gameplay variety without undermining balance.

Elite enemies become memorable miniature boss encounters that introduce a controlled escalation toward the end of the run.

The desired result is a game that feels richer and more unpredictable, while preserving ZeroDepth's fast-paced combat, randomized builds, and satisfying progression.

**For the developer:** Inspect the existing project before implementation. Preserve working systems, distinguish confirmed requirements from proposed mechanics, and prioritize reusable architecture, visual clarity, and balanced gameplay. Do not introduce unrelated features or treat suggested numbers as finalized values.

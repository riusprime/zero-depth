# v0.9.0 RB: robes and affinities (G1, waiting for the owner)

Drafted by the lead's agent while the owner was away (2026-10-23). Answer per row: approve, change: …, drop.
**Nothing is built until approved.**

The owner's decision (PLAN "Owner decisions" Q29b, 2026-10-22): *(robes) "Robes + 5 affinities (Recommended)"*:
robe colours are cosmetic; one of five affinities (Ember, Storm, Venom, Astral, Guardian) or none is picked at the
Wardrobe; **G1 sets each so none is always best**. The feedback: "sidegrades, not compulsory upgrades … No individual
affinity should become the universally strongest choice", and "Separate Robe Appearance from Rune Affinity" (W53, W54).

## The PD-06 check

PD-06 (`LOCKED_DECISIONS.md:50`): *"Meta-progression is sideways. Meta unlocks add alternatives, information and
cosmetics. There are no permanent stat increases."* The blueprint repeats it (GAME_BLUEPRINT §I). So this draft:
- gives **no flat stat** (no +damage, +attack speed or +max HP, the three W8 and W52 name);
- makes every affinity a **choice with a cost**, picked again freely before each run, never bought in levels or
  stacked;
- makes each gain **conditional** on a status, a secret or a hit, so it only pays off for builds that lean that way.

If the owner reads an affinity as a stat increase anyway, that row is the one to change.

## Today's hooks the drafts lean on (checked in code)

- Statuses `burn, shock, bleed, frost, slow, poison` (`src/sim/combat/attacks.gd:43`, applied at `:684-697`).
  Burn adds capped, refreshed stacks that tick (`src/sim/items/engines.gd:217-218`). Shock adds stacks up to a
  threshold, then the enemy discharges (`engines.gd:231-233`). Poison goes through `Venom.add` (`attacks.gd:697`).
- Card offers are weighted per card in `ItemPool.card_weight` (`src/sim/items/item_pool.gd:44-57`) with per-mille
  multipliers (the run's own weapon cards use `own_weapon_card_permille`). An affinity's offer bias would be one more
  per-mille factor there.
- The dash: 4 m, cooldown 1.4 s (`src/content/defs/dash_definition.gd:5`, `data/player/runner.tres`).
- The forms are the ten of `ATTACK_FORMS.md` (Orbs, Laser, Bomb, Void, Lance, Scatter, Glaive, Seekers, Wave, Wisps).

Every number below is a **starting value** (a tuning default, not a measurement).

## The affinities

| # | Affinity | What it does | Its trade-off | Favours | Why it doesn't dominate | Approve? |
|---|---|---|---|---|---|---|
| A1 | **Ember** | Burns you apply last 50 % longer. Ember cards are offered a little more often (× 1.3 weight). | Frost cards are offered less (× 0.7). | Forms that hit often or wide, so burn stacks: Laser (ticks), Scatter, Wave, Bomb. Ember builds. | Worth nothing without ember on the wand; pushes frost builds away. | ☐ |
| A2 | **Storm** | Your dash leaves a crackle: enemies you dash through or past (within 1 m) gain one shock stack. Storm cards × 1.3. | Dash cooldown 1.4 → 1.7 s. Venom cards × 0.7. | Many small hits that reach the shock threshold: Seekers, Wisps, Orbs. Players who dash through packs. | The slower dash is a real cost when dodging bosses; the gain needs shock on the wand to finish the discharge. | ☐ |
| A3 | **Venom** | When a poisoned enemy dies, its poison jumps to the nearest enemy within 3 m. Venom cards × 1.3. | Ember cards × 0.7. | Piercing and returning forms that tag many enemies: Glaive, Wave, Lance. Rooms with packs. | Does nothing against one target (bosses, elites alone); needs poison on the wand. | ☐ |
| A4 | **Astral** | Hidden rune markings, cracked walls and hidden rooms within 8 m pulse faintly; the minimap marks the room that holds a secret once you enter it. Void cards × 1.3. | No combat effect at all. | Exploring and collectibles (COLLECTIBLES.md); the Void form. | Pure information: it helps find secrets, never wins a fight. If secrets give Rune Fragments (COLLECTIBLES P2), it is also the slow farming pick, so the fragment reward stays small. | ☐ |
| A5 | **Guardian** | A thin ward blocks the next hit that would damage you; it refills at the start of each floor. | Run shards picked up − 20 % (fewer shop buys). No offer bias. | Close-range forms that take hits: Scatter, Wave; new players; the final boss's long fight. | One blocked hit a floor; the shard loss shows up in every shop. It's the safe pick, never the strong one. | ☐ |
| A0 | **None** | Nothing. Offers unweighted. | Nothing. | Players who want the plain game; challenges. | It is the baseline the others are measured against. | ☐ |

## How "none is always best" is checked (proposal, for the RB step)

| # | Check | Approve? |
|---|---|---|
| K1 | With BR's bot over a fixed seed set, run every form × every affinity (10 × 6) and record floor reached and clear rate into `build/`; the evidence pastes the command and the raw table. | ☐ |
| K2 | Pass when no affinity is the best for more than 4 of the 10 forms, and every affinity averages within 5 points of None's clear rate. Starting values; if a target is missed the numbers are reported and the owner decides, nothing is retuned blind. | ☐ |
| K3 | Astral is judged by the owner in play (finding secrets is not something the bot measures). | ☐ |

## Other affinity questions

| # | Question | Draft answer | Approve? |
|---|---|---|---|
| Q-a | Are the five free from the start, or unlocks (UNLOCKS.md, MP)? | Free from the start: the choice is the sidegrade; unlocking them would make them read as power | ☐ |
| Q-b | Can you change it between runs? | Yes, at the Wardrobe, any time in the hub; it locks when the run starts | ☐ |
| Q-c | Is it visible on the hero? | A small rune on the robe's back in the element's colour (ember `#FFAA33`, storm `#7FB2FF`, venom `#5FE03C`, astral in the void violet `#8B55FF`, guardian gold `#E8C870`; ART_DIRECTION §4), none for None | ☐ |
| Q-d | Shown in the run summary? | Yes, one line | ☐ |

## Robe colours (cosmetic only)

Today the hero's cloak and hood are a hard-coded cream `#EBDCCB` (`src/presentation/world_view/player_avatar.gd:100-101`;
the underside `#C9B8A6`, `:103`). The cloak becomes a palette choice; the hero's blue core stays the same on every
robe (it is how the player reads as "the player", ART_DIRECTION §3). Robes never use the enemy red (`#E25A4C`) or the
hostile yellow (`#FBD07A`), so the hero never reads as a threat. Colour and affinity are picked separately (W53).

| # | Robe | Cloak / underside | How it is got | Approve? |
|---|---|---|---|---|
| R1 | Cream (today's) | `#EBDCCB` / `#C9B8A6` | Default | ☐ |
| R2 | Ash | `#9A9AA0` / `#7C7C82` | Default | ☐ |
| R3 | Night | `#46608C` / `#344A6E` | Rune Fragments (UNLOCKS.md) | ☐ |
| R4 | Canyon | `#9C5444` / `#7A3D36` | Rune Fragments | ☐ |
| R5 | Frost | `#DCE4EE` / `#B5C2D2` | Rune Fragments | ☐ |
| R6 | Moss | `#6F7F4E` / `#55633B` | Rune Fragments | ☐ |
| R7 | Star | `#6B4FA0` / `#4F3A78` | The first Purple Portal | ☐ |
| R8 | Crown Black | `#2A2830` / `#1E1D24` | Beating the Hollow Crown | ☐ |

R8's dark cloak must be checked against the Night Rocks ground (`#486796`) and the Starfall void for the hero's
outline contrast before it ships (a shot per biome, ART_DIRECTION §2's rule for the outline).

## Decisions (owner, date)

| # | Answer | Built in |
|---|---|---|
| | | |

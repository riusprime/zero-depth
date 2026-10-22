# Build and loot balance pass (v0.8.0 O91; the lead's reading, 2026-10-20)

Branch `claude/balance-pass-v080`, cut from `claude/perf-graphics-v080` at `ae4f136` (which carries
`claude/lucid-fermat-9wv2tf` and the graphics work). The owner's request is O91 in [`PLAN.md`](PLAN.md), quoted in
full at the bottom of this file. The owner set the goals, the five areas, the first batch of cards and the starting
values. This file fixes the rest as **starting values** (CLAUDE.md glossary): tuning defaults the owner can change,
not measurements. Every number below lives in data and shows on the dev panel. The open calls are D64–D68 in
[`../../OWNER_TODO.md`](../../OWNER_TODO.md).

**Goal (owner):** most runs develop useful synergies. Exceptional builds need several complementary modifiers and
investment. Twin, Echo and attack speed stay viable without dominating most runs. Kept: the Blade and Gun pools,
ordered modifiers, triggers, separate stat power-ups, and slots growing 4 → 6 → 8.

**Order (owner):** stats and multiplication first (SG, MR), new interactions second (RM), floor loot third (FL),
then validation (BV).

## Today (live code, 2026-10-20)
- **Stat cards compound.** `Stats.stepped` (`src/sim/abilities/stats.gd:146`) multiplies every MULT card: five
  rare +15 % damage cards give ×2.01, not ×1.75. `damage_permille` (:244) multiplies Damage × Glass Cannon ×
  (1 + Onrush + Hoarder), so Onrush and Hoarder already add with each other, but not with Damage.
- **Attack speed has two separate paths.** The stat runs through `Stats.period` (:326) and `Stats.swing_end` (:334;
  the Blade's recovery only). The wand's `rate_bonus_permille` (Rapid Fire +600, Flurry +500, Heavy −300) is a
  second factor:
  - Gun: `item_effects.gd:30-36`; a negative bonus is ignored;
  - Blade: `blade_forms.gd:72-95`; it scales the whole swing.

  The two multiply, so no cap or curve covers them together.
- **Extra projectiles are full copies.** Twin lanes, Spread bolts and Halo bolts each deal full damage at full proc
  (`attacks.gd:265-298`). Twin · Spread · Halo is 2 × 3 × 3 = 18 full bolts.
- **Repeats.** Echo's repeat can't repeat (`attacks.gd:70`), and Double Slash's echoes don't re-echo
  (`player_kit.gd:164-180`). Echo, Double Slash and Charge right of a trigger silently do nothing: only depth-0
  attacks repeat, and only the root bolt reads `hold_ticks`. Nothing in the wand says so (`Wand.describe`,
  `wand.gd:228-250`).
- **Loot ignores the floor.** No source reads `floor_index` or `loop` for eligibility or weights. A card levels
  freely to 5 on floor 1. The boss altar grants level 5 to any wand card (`BossReward.on_pick`,
  `boss_reward.gd:40-47`). There is no card category (form, element, advanced, mutation).
- **The hidden catch-up** (`CatchUp.power`, `src/sim/world/catch_up.gd:24-52`) multiplies Damage × Glass Cannon ×
  (1 + Onrush) × crit × attack speed × the wand's levels. It ignores the wand's rate bonus and the card shares.

## SG: stat growth
1. **One additive damage bucket.** Damage cards add their amounts (+8 / +15 / +25 %), the gamble shrine's damage
   wins add into the same stat, and Onrush (while moving) and Hoarder's active bonus add into the same sum:
   `bucket = 1000 + Σ damage + Onrush + Hoarder`.
2. **Glass Cannon stays an explicit multiplier.** The owner's "genuine risk/reward multipliers": it trades max HP.
   Its own cards add with each other (×1.15, ×1.40, ×1.55 …, cap ×3), and the total multiplies the bucket.
   Curses (Blood Price, Glass Heart, Heavy Hands) stay explicit multipliers too.
3. **Attack speed: one sum, one curve.** The raw bonus is the attack-speed stat's sum (its cards now add) plus the
   wand's `rate_bonus_permille` for that attack (Rapid Fire, Flurry, Heavy …). `AttackRate.curve` turns it into
   the effective bonus:
   - up to **+50 %** (`attack_speed_knee_permille` 500), it counts in full;
   - from +50 % to +150 % (`attack_speed_knee2_permille` 1500), at **50 %** (`attack_speed_slope_permille` 500);
   - above +150 %, at **25 %** (`attack_speed_slope2_permille` 250).

   A negative raw bonus counts in full (the slow floor stays `rate_min`). Heavy Hands then multiplies the rate.
   - **Gun:** the period is `base × 1000 / (1000 + effective)`, rounded half up, at least 2 ticks.
   - **Blade:** the whole swing (hit tick, sweep, recovery) scales by the same rate. The stat's old recovery-only
     path (`swing_end`) folds into it, so the Blade has one rule too.
   - **The drone** (retired, still in old saves) reads the same curve with the stat alone.

   The four values live in `data/tuning/sim.tres`, so the dev panel shows them. Raw +100 % → effective +75 %. Raw
   +200 % → +112.5 %. A specialised interaction can still go past that: Flurry's burst (MR) and the projectile
   multipliers raise **projectiles a second**, not **casts a second**.
4. **Crit keeps its structure** (cards add; caps 75 % and ×4). Pickups come down:
   - chance 4 / 8 / 12 → **3 / 5 / 8** points, weight 10 → 8;
   - damage +15 / +30 / +50 → **+10 / +20 / +35** points, weight 8 → 7.
5. **The same rule everywhere.** Every source reaches the stats through `Stats.add_card` / `add_amount`: altars,
   chests, the shop, events, the gamble shrine, stolen cores, salvage (`Shop.rebuild_stats` replays the cards) and
   the legendary tier.
   - **Saves:** a save made before SG rebuilds Damage, Attack speed and Glass Cannon from its stat cards and gamble
     stacks on load. That path needs a new snapshot field `stat_rules`, read as 0 on an older save. The other stats
     keep their stored values.
   - **Cards show the real marginal gain:** a damage card reads the bucket before → after (for example "Damage
     +45 % → +60 %"); an attack-speed card reads the effective rate after the curve, with the wand's own bonus
     counted.
6. **The catch-up is audited** with the new rules:
   - `CatchUp.power` reads the bucket (Onrush always counted, as today; Hoarder excluded, as today), Glass Cannon,
     the effective attack speed of the weapon's attack (stat + wand bonus, after the curve), and MR's shares
     through the projectile count it already counts as levels;
   - BV compares P and the multiplier before and after on fixed builds;
   - the expected values (`data/scaling/catch_up.tres`) change only if those numbers show that hidden scaling now
     cancels earned synergy. Otherwise they are reported, not retuned.

**Built (SG, 2026-10-20, branch `v080-sg`; evidence [`evidence/BALANCE_SG.md`](evidence/BALANCE_SG.md)).** As above,
with these readings of what the spec left open:
- the flag is data: `additive = true` on `data/stat_cards/{damage,attack_speed,glass_cannon}.tres`
  (`StatCardDefinition.additive` → `StatTable.additive`; only multiplier stats may set it). The other multiplier
  stats still compound (D64);
- `AttackRate` (`src/sim/abilities/attack_rate.gd`) is the one function: the Gun (`ItemEffects.shot_period_ticks`),
  the Blade (`BladeForms.step`: hit tick, sweep and recovery; `Stats.swing_end` is gone), the drone
  (`Stats.period`), the HUD (`WorldReader`), the cards (`CardForecast`) and the catch-up read it. The Gun's 2-tick
  floor applies once the period changed (a base period under 2 stays as it is);
- the attack-speed card's sentence ("+X % attack speed") now names the real gain after the curve, with the weapon's
  wand bonus and Heavy Hands counted (`CardForecast.gain` → `Offers.info` "amount"); its gain line shows the rate
  before → after. A damage card's sentence keeps its amount (it adds exactly that); its gain line shows the bucket
  without Onrush's movement but with Hoarder's bonus now;
- `CatchUp.rate_permille` leaves Heavy Hands out (P never read the curses), and reads the wand's rate bonus as the
  sum of the held cards' own rate ops at their levels, whatever their order (`CatchUp.wand_rate_bonus`), not the
  compiled weapon attack's: SIM_CONTRACTS' "a reorder never changes P" (`test_wand.gd`) outranks the plan's
  wording. The two agree while the rate cards sit before any trigger;
- an old save's Glass Cannon max HP cut is not replayed (MAX_HP keeps its stored value, like every other stat).

## MR: existing modifiers
1. **Shared damage and secondary proc.** An attack's extra projectiles are **secondary**:
   - Twin's second lane;
   - Spread's and Halo's bolts beyond the centre one;
   - Echo's repeat.

   Each card sets a per-projectile share, and a secondary projectile runs at **50 % proc**
   (`secondary_proc_permille` 500, `data/wand/wand.tres`): its status stacks, a hook's status and its trigger
   casts' damage are halved. Starting shares:

   | Card | Damage today | New |
   |---|---|---|
   | Twin | 2 full lanes | each lane **60 %** (+5 % a level): 1.2× focused at level 1, 1.6× at level 5 |
   | Spread | 3 full bolts (+2 a level) | each bolt **55 %** (+3 % a level); +2 bolts at level 1, **+1** a level after |
   | Halo | ring ×3 full (+1 a level) | each ring bolt **40 %** (+5 % a level) |
   | Echo | repeat at 60 % (+10 %) | repeat at **50 %** (+5 %), secondary proc |
   | Double Slash | repeats at 70 % | repeats at **60 %**, the repeats at secondary proc |

   Shares multiply down the wand, so Twin · Spread · Halo still grows, but each bolt is a share, not a copy.
2. **A repeat never repeats.** An attack launched as a repeat (Echo, Double Slash's echoes, the second cast of a
   ×2 trigger) never queues a repeat or a second cast of any kind. The guards stay: lineage, `once_per_line`,
   depth ≤ 2, 256 launches a tick.
3. **Rapid Fire (Gun) is sustained fire.**
   - Base: +30 % rate; size ×0.7; damage ×0.85.
   - Holding fire ramps a further +10 % per shot, up to +60 % (+15 % a level), all through the curve.
   - The ramp resets after 0.4 s without a shot.

   **Flurry (Blade) is a burst.**
   - The first 3 swings after a 0.6 s pause come +80 % faster (through the curve), then the rest of the combo runs
     at the base rate.
   - Damage ×0.85 (no loss from level 3), +1 burst swing at levels 3 and 5.

   Both rates are counted as the attack's raw bonus, so the curve covers them.
4. **Finisher+ becomes Fracture Bank** (same id `finisher_plus`, so saves keep it).
   - Combo hits (not the finisher) lodge a **fragment** in the enemy hit: at most 4 per enemy (+1 a level), each
     lasting 4 s.
   - The finisher's hit extracts every fragment in the enemies it hits, each fragment a hit of **40 %** of the
     finisher's damage (+5 % a level), as one burst.
   - The cards right of it shape that burst, as the old child spec did. The fragments are RM's remnants (an
     enemy-attached kind), so Fracture Bank lands with RM.
5. **Split Wave works without Wave.** With a flying slash it splits the crescents as today. Without one, each
   slash hit throws 2 small crescents outward (+1 a level) at 40 % (+5 %).
6. **Placements that do nothing are flagged.** `Wand.describe` and the wand tiles mark a card that can't act where
   it sits, "Does nothing after a trigger" (en/es):
   - Echo, Double Slash and Charge right of a trigger (Charge reads the hold of the shot you fire);
   - any card past the third trigger (the old "Too deep to cast").

   The read-back skips such a card's effect, and the dimmed tile shows the reason.
7. **Retired cards stay out.** Reworks keep their ids; nothing new joins `migration.tres`.

## RM: remnants (reusable, not card pairs)
A **remnant** is a small sim object that a modifier leaves behind and that a later attack (or time) activates. One
store and one set of rules serve every card (`src/sim/combat/remnants.gd`, state on `ModifierState`, snapshotted
and hashed):

| Field | Meaning |
|---|---|
| `kind` | SEGMENT (a line between two points), ANCHOR (a point with a pull), MARK (on an enemy, with a direction), FRAGMENT (on an enemy, a count) |
| `card` / `slot` / `section` | the card that made it, its wand slot, its trigger section (the slots between two triggers) |
| `spec` | the child spec its activation casts: the remnant card is a HOOK, so the cards to its right shape that cast, the same way a trigger's child is built (WAND rule 2) |
| `depth`, `proc`, `lineage` | inherited from the attack that made it; an activation is a child (depth + 1, proc halved), and the lineage guard stops a remnant's cast from making the same remnant |
| `born`, `life` | ticks |
| `hit_gap` | the least ticks between two hits on one enemy |
| `charges` | activations left before it's spent |

**Limits** (data, dev panel):
- 96 alive in all, plus a per-kind cap; the oldest is replaced.
- 64 activations a tick; past that, one LIMIT event.
- An activation's cast counts toward the 256 launches a tick.

**Events:** `REMNANT_SPAWN`, `REMNANT_ACTIVATE`, `REMNANT_END`, for the view and the tests. The view draws
segments, anchors and marks; it reads, never writes.

**First batch** (starting values):

| Card | Pool | Rarity | What it does |
|---|---|---|---|
| Threadline | Gun | rare | Consecutive projectiles of one volley, or of two shots 0.4 s apart, connect for 0.5 s with a thread. An enemy crossing it takes 25 % of a bolt's damage, at most once each 0.25 s per thread. Up to 6 threads (+2 a level). |
| Faultline | shared | rare | A slash's contact or a projectile's impact leaves a 1.6 m crack along the attack for 3 s (6 at most, +1 a level). A later attack crossing a crack erupts it: a 1.2 m burst at 80 % of the crossing hit (+10 % a level); the crack is spent. |
| Gravity Stitch | shared | rare | A hit leaves an anchor for 1.2 s (4 at most). It pulls enemies within 2.5 m gently toward it and bends your projectiles passing within 3 m toward it. A level: +0.3 s, +1 anchor. |
| Stress Mark | shared | common | A hit marks the enemy with the hit's direction for 3 s. A later hit from 90° or more away breaks the mark: +100 % of that hit (+20 % a level) and a short stagger. One mark per enemy. |
| Dodge Imprint | Blade (rework of Afterimage, id `long_shadow`) | common | For 1.5 s after a dash, your next attack is cast from where the dash began, +10 % damage a level. |
| Fracture Bank | Blade (rework of Finisher+, id `finisher_plus`) | rare | MR 4. |
| **Double Exposure** (mutation) | shared | mutation | 0.6 s after an attack, its path (a bolt's flown line, a slash's arc) becomes damaging once more at 40 %. Its own replay never replays. |
| **Grand Finale** (mutation) | shared | mutation | Every 4 s, it consumes the remnants made by the cards to its left in its own trigger section, each releasing a 1.5 m burst at 60 % of the hit that made it. At most 12 a release. |

- **Thermal Break** is an elemental reaction, not a card. An enemy that is both burning and chilled or frozen
  breaks: its burn stacks and its frost are consumed into one hit of 6 + 4 per burn stack, × the damage stat, plus
  a short shatter. It is one rule in the status engine (`engines.gd`), so Fire + Frost from any source react.
- **Mutation** is a new card category: a `mutation` tag and its own rarity weight. The loot rules (FL) keep it
  exceptionally rare early.
- **Follow-up, after this batch is validated:** the owner's other proposed cards and mutations.

## FL: floor-paced loot
**Categories.** Every wand card gets a `category` in its item data. Stat cards are their own category. Triggers
cover T1–T4, plus the legendary ×2 triggers as `advanced`.

| Category | Cards |
|---|---|
| `form` | Big Shot, Spread, Pierce, Wave, Wide Arc, Thrust, Heavy … |
| `element` | the shared S1–S7 |
| `advanced` | Split, Echo, Halo, Charge, Twin, Double Slash, Fracture Bank, the remnant cards … |
| `trigger` | T1–T4 |
| `mutation` | Double Exposure, Grand Finale |

**One pacing table** for every source, in a new `data/rewards/pacing.tres` (dev panel). It holds per stage:
- a weight multiplier per category;
- a level ceiling;
- the guarantees.

`LootPacing` applies it inside `ItemPool.available` / `card_weight` and in the level-up checks. Every card source
goes through them:
- altars and chests;
- the shop, its restock and its rerolls;
- events;
- stolen cores;
- the boss altar;
- the Overrun;
- the Deep epic altar.

| Stage | Ceiling | Weights (×) | Guarantees |
|---|---|---|---|
| Floor 1 (4 slots) | level 2 | form 1.4, element 1.4, advanced 0.4, trigger 0.6, mutation 0.02 | Each of the run's first two regular altars shows at least one modifier compatible with the wand (one that changes the attack you have; not a trigger, not one that would do nothing) |
| Floor 2 (6 slots) | level 3 | form 1, element 1, advanced 1, trigger 1.2, mutation 0.1 | — |
| Floor 3 (8 slots) | level 5 | form 0.9, element 0.9, advanced 1.2, trigger 1.2, mutation 0.3 | — |
| Deep floors and loops | level 5 | form 0.8, element 0.8, advanced 1.3, trigger 1.2, mutation 0.6 | — |

- **A held card at the floor's ceiling isn't offered as a duplicate.** Higher duplicates come on later floors.
- **No source bypasses the rules.** Shops, rerolls, events and cores draw through the same check, and a stolen core
  drawn at spawn is re-checked at the drop.
- **The rare early jackpot is explicit:** `jackpot_permille` 15 per regular offer. A jackpot card ignores the
  ceiling by one level, or lets one mutation in, and it reads "Jackpot" on the card.
- **Boss rewards.** The automatic level-5 grant goes. The boss altar offers three choices:
  - an **upgrade**: a held wand card +1 level, up to the next floor's ceiling;
  - an **advanced or trigger card**;
  - a legendary stat card.

  The legendary ×2 triggers stay boss-only.
- **The economy stays** for now: the number of rewards, prices and shards are unchanged.

## BV: validation
- **Seeded reward sampling** (`scripts/checks/loot_sample.gd`, output to `build/`). It walks real runs' reward
  sources floor by floor (altars, chests, shop with purchases and rerolls, events, cores, boss) with a scripted
  build-seeking pick and measures:
  - offers, purchases and rerolls;
  - the build each run ends with.
- **Exceptional build** (measured, not judged): the final wand's DPS in the reference fight is ≥ 2.5× the median of
  the sampled builds at the same point. Reported per floor; the share among completed normal-route runs is set
  against the **10–20 % playtest target**, and the early jackpots are counted.
- **Scripted fights** (`scripts/checks/build_fights.gd`) for five archetypes:
  - multiplication (Twin · Spread · Halo);
  - charged-hit (Charge · Big Shot · Heavy);
  - remnant control (Faultline / Gravity Stitch / Grand Finale);
  - returning attack (Boomerang / Blade Storm);
  - status (Fire · Frost · Venom).

  Each reports damage, **projectiles a second** and **casts a second** apart, procs a second, time to kill a fixed
  pack and a boss dummy, and CatchUp P and the multiplier before and after SG.
- **Determinism, migration, eligibility, combinations and cost:** the replay goldens, the old-save fixtures, the
  every-card × every-slot smoke with the new cards, the launch caps, and one horde perf probe run as a gross-stall
  check (no timing claims on the cloud machine).
- **What only the owner can say** (OWNER ONLY): whether builds feel like they develop, whether Twin, Echo and
  attack speed still feel good, and the jackpot's rarity in play.

## The owner's request (O91, 2026-10-20, verbatim)
> New branch from this one, the latest changes that carry lucid Fermat and graphic updates, read claudemd to
> understand workflow,
>
> Implement a ZeroDepth build and loot balance pass. Read AGENTS.md and current design/contracts first, especially
> docs/design/WAND.md.
>
> Goal: most runs develop useful synergies; exceptional builds require several complementary modifiers and
> investment. Twin/Echo/attack speed should remain viable without dominating most runs. Preserve Blade/Gun pools,
> ordered modifiers, triggers, separate stat power-ups, and slots growing 4→6→8.
>
> 1. Rebalance stat growth
> * Relevant code/data: src/sim/abilities/stats.gd, data/stat_cards/, modifier attack-rate handling.
> * Ordinary damage pickups should add bonuses rather than compound multiplicatively. Add movement damage/Onrush and
>   Hoarder's active bonus into that same ordinary damage bucket. Keep genuine risk/reward multipliers explicit.
> * Make attack-speed bonuses additive before a configurable diminishing-return curve. Include ordinary speed
>   modifiers in that calculation so they cannot bypass it. Start with diminished gains above +50%; reserve extreme
>   rates for specialised modifier interactions.
> * Crit chance/damage already add and cap at 75%/×4; retain that structure and tune pickup amounts/weights downward
>   where necessary.
> * Apply identical rules across rewards, shops, events, gambling, salvage/rebuild and saves. Show actual marginal
>   gains on cards.
>
> 2. Rebalance existing modifiers
> * Give Twin/Spread/Halo/Echo partial damage sharing and appropriate secondary proc effectiveness. Extra projectiles
>   must not each duplicate full damage and full-strength effects.
> * Prevent repeats repeating themselves; preserve recursion/ancestry guards and simulation limits.
> * Rework Rapid Fire/Flurry into distinct sustained-fire/burst rhythms. Rework Finisher+ into Fracture Bank: combo
>   hits lodge fragments; the finisher extracts them.
> * Make Split Wave useful without Wave. Clearly flag incompatible placements, including input-dependent Charge after
>   triggers.
> * Keep retired cards out of rewards and preserve migration IDs.
>
> 3. Expand interactions through reusable mechanics
> First batch:
> * Threadline: consecutive projectiles connect briefly with damaging threads.
> * Faultline: blade contact/projectile impacts leave cracks; subsequent attacks crossing them cause eruptions.
> * Gravity Stitch: hits leave short-lived anchors that bend projectiles and pull enemies.
> * Stress Mark: hits mark enemies; a later hit from a different direction breaks the mark.
> * Dodge Imprint: rework existing Afterimage so the next attack after dashing originates at the dash's starting
>   position.
>
> Rare mutations:
> * Double Exposure: attack paths briefly become damaging again after a delay.
> * Grand Finale: periodically consumes eligible remnants created by modifiers to its left in the same trigger
>   section, releasing defined bursts.
>
> Build reusable remnants, connections and events—not hardcoded modifier-pair scripts. Define inheritance,
> lifetimes, hit intervals and activation limits. Later modifiers should affect child attacks consistently. Make
> Fire+Frost's Thermal Break a natural elemental reaction. Keep other proposed cards/mutations as follow-up work
> after this batch is validated.
>
> 4. Pace rewards by floor
> Extend data/rewards/floor.tres, Offers/ItemPool, boss reward configuration and all other reward sources with
> shared floor-aware eligibility and weights.
>
> | Stage | Intended progression | Initial loot rules |
> |---|---|---|
> | Floor 1, 4 slots | Establish identity; useful two-piece synergy | Favour standalone forms/elements. Guarantee a compatible modifier option in the first two regular rewards. Advanced cards possible at low weight; mutations exceptionally rare. |
> | First boss / Floor 2, 6 slots | Develop interactions | Increase advanced/trigger availability. Boss offers an upgrade or advanced choice; remove automatic level-5 grants. |
> | Second boss / Floor 3, 8 slots | Complete a build; occasional exceptional combination | Increase mutation access and investment opportunities without guaranteeing a matching finisher. |
> | Deep/loops | Greater extremes and experimentation | Allow high-level rewards and stronger mutations; ordinary stat stacking alone must not trivialise progression. |
>
> Use modifier level ceilings of 2/3/5 on floors 1/2/3 as initial tuning values; higher duplicates remain available
> later. Keep reward quantity/economy initially stable. Ensure shops, rerolls, events and stolen cores cannot bypass
> progression. Rare early jackpots should remain possible through explicit exceptional rewards.
>
> 5. Validate and tune
> * Measure actual offers, purchases and rerolls; weights are not run-completion probabilities.
> * Initial target: exceptional builds in roughly 10–20% of representative completed normal-route runs, usually
>   assembled late; early jackpots much rarer. Treat this as a playtest target.
> * Compare multiplication, charged-hit, remnant-control, returning-attack and status builds using reproducible
>   combat scenarios.
> * Track damage, projectile rate, proc rate and time-to-kill; distinguish 60 projectiles/sec from 60 weapon
>   casts/sec.
> * Audit CatchUp.power after changing stat semantics; hidden enemy scaling must not cancel earned synergy.
> * Verify deterministic replay, migration, loot eligibility, combinations and performance. Use seeded reward
>   sampling plus scripted fights, then report what still requires human playtesting.
>
> Expose tuning values in the existing dev panel. Implement stats/multiplication first, new interactions second,
> floor loot third; update descriptions and design docs.

Notes on the request:
- The repo has no `AGENTS.md`. `CLAUDE.md` and the docs it names were read instead.
- `ItemPool` exists (`src/sim/items/item_pool.gd`).

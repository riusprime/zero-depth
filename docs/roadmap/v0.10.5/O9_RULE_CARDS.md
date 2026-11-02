# v0.10.5 O9: the 22 utility cards, re-reviewed as rule cards (G1)

Owner (2026-11-01), theory audit P2: "very nice idea, let's use the pending cards as this" (the 22 utility cards of
[`../v0.8.0/UTILITY_CARDS.md`](../v0.8.0/UTILITY_CARDS.md), D23: "we should go over them again with game theory audit
taken into account"). P2 ([`THEORY_AUDIT.md`](THEORY_AUDIT.md)): rewrite 6–8 flat stat cards as Trigger → Condition →
Payoff, keep 3–4 plain stats as filler. Overnight mode ("Pick and build"): the lead's picks below are built as
starting values; the owner keeps or changes each row.

**How a row is scored.**
- **Decision in motion** (0–3): does owning the card change what you do in a fight? 0 = nothing (a number goes up);
  1 = a build choice only; 2 = you lean into it now and then; 3 = it changes where you stand or when you press.
- **Learning cost**: Low (one sentence, the HUD already shows the state), Medium (a state you must track),
  High (a hidden window, a new view, or a rule that fights another).
- **Fit**: a stat-track card takes no wand slot (GAME_BLUEPRINT §D); a card that adds an attack, an element or an
  L1 move belongs to the wand pools or the utility's level-ups ([`../../design/WAND.md`](../../design/WAND.md)), not
  here.

## Table 1: the 22 utility cards

| # | Card | What it does | Decision | Learning | Could replace | Verdict | Reason |
|---|---|---|---|---|---|---|---|
| 1 | Close Quarters | More damage the closer the enemy is | 3 | Low | Crit damage | **Keep (Change)** | Rewards standing in; a 2 m line instead of a fade, so it reads. Built |
| 2 | Second Wind | A second dash charge | 1 | Low | Cooldowns | **Change → Reflex** | Two charges is a flat cooldown (and P5 is an owner decision); a kill while the dash recharges cuts its wait instead. Built |
| 3 | Deep Cuts | Bleed ticks harder, lasts longer | 1 | Low | — | Cut | An element level-up; the wand's bleed cards already do it |
| 4 | Heavy L1 | The L1 move hits hard | 1 | Medium | — | Cut | The utility's level-ups, not the stat track |
| 5 | Wide L1 | The L1 move covers more | 0 | Low | — | Cut | Flat radius on the utility; same place as row 4 |
| 6 | Afterburn | Dashing leaves a burning trail | 1 | Low | — | Cut | A fire element source (Flame Trail was retired for this); wand pool |
| 7 | Adrenaline | A kill gives a burst of speed | 2 | Low | Move speed | **Keep (Change)** | Needs a condition: only a kill within 3 m, so it pays the risky kill. Built |
| 8 | Perfect Dodge | A last-moment dash slows time, next hit crits | 3 | High | — | Cut (for O9) | Slowing the world fights the one clock and the telegraphs; O11 (feel per verb) owns the dash window |
| 9 | Fifth Strike | Every 5th hit is a heavy hit | 2 | Low | Area | **Change → Third Strike** | The audit's "every third hit in a row": a rhythm you keep, and lose if you pause. Built |
| 10 | Wind Up | Standing still charges your next attack | 2 | Low | — | Cut | Onrush's mirror; two opposite rules in one pool dilute both, and standing still in bullet rooms isn't a choice |
| 11 | Last Stand | More damage at low HP | 1 | Low | — | Cut | You don't choose to be low; Glass Cannon already sells risk for damage |
| 12 | Magnet | Pickups fly in from further | 0 | Low | Pickup range | **Change → Scavenger** | Shards are paid on the kill, so reach is convenience; its economy half becomes "a crit kill pays more shards". Built |
| 13 | Rebound | A kill bounces to one more enemy | 1 | Low | — | Cut | Overkill already splashes a kill onto the nearest enemy |
| 14 | Volatile | Kills explode | 1 | Low | — | Cut | Overkill and the explosive wand cards (Chain Blast) cover it; noise budget (P9) |
| 15 | Hunter's Mark | The first enemy hit each room takes more | 2 | Medium | — | Defer | A real target choice, but it needs a room hook and a mark view: next batch |
| 16 | Ghost Step | Longer dash iframes, pass through | 1 | Medium | — | Cut | Invisible numbers on the dash; Kinetic Dash is the dash item |
| 17 | Backstab | Hits from behind deal more | 2 | High | — | Cut | Chasers face you; facing is hard to read in iso; bosses' rear armour already does this |
| 18 | Crowd Control | More damage per enemy near you | 3 | Medium | — | Defer | Good, but Close Quarters is the proximity card of this batch; one at a time |
| 19 | Echo Dash | Each dash swings or fires once | 1 | Low | — | Cut | A free attack copy: a wand trigger (on dash), not a stat card |
| 20 | Gravity Boots | The dash pulls enemies in | 2 | Medium | — | Cut | Crowd control on the dash: the utility or the wand |
| 21 | Overflow | Excess kill damage carries to the next hit | 1 | Medium | — | Cut | Overkill is the excess-damage card |
| 22 | Time Shard | Every 10th kill freezes the screen | 0 | Low | — | Cut | Erases bullet patterns (pillar 2); a legendary-only toy |

Two more rule cards come from the audit's own P2 examples (not in the 22), because Regen and Armour had no
utility card to take their place:

| Card | Trigger → Condition → Payoff | Decision | Learning | Replaces | Verdict | Reason |
|---|---|---|---|---|---|---|
| Vent Mend | You Vent → an enemy is in the blast → heal a share of max HP | 3 | Low | Regen | **Build** | Turns passive regen into "vent into the crowd"; the Vent's 6 s cooldown is its sustain window |
| Heat Shield | You are hit → you are Hot or hotter (overheat included) → the hit is cut | 3 | Low | Armour | **Build (Change)** | The audit said "while overheated"; overheat is a stall nobody chooses, so Hot is the line: keep the heat up, or vent and lose the shield |

## Table 2: the flat stat cards

| Flat card | Stays plain? | Replaced by | Why |
|---|---|---|---|
| Damage | **Plain filler** | — | The baseline every build reads; the additive bucket Onrush and Hoarder join |
| Attack speed | **Plain filler** | — | Runs through one curve with the wand's rate cards (v0.8.0 SG) |
| Max HP | **Plain filler** | — | The only plain survival stat left; Glass Cannon trades against it |
| Crit chance | **Plain filler** | — | Feeds Scavenger and the ON_CRIT wand triggers |
| Crit damage | Retired | Close Quarters | Same role (spiky damage), now earned by standing close |
| Area | Retired | Third Strike | "Bigger hits" earned by a rhythm (the payoff is damage, not radius: one number, one rule) |
| Cooldowns | Retired | Reflex | Earned by kills while the dash recharges |
| Move speed | Retired | Adrenaline | Speed after a close kill |
| Regen | Retired | Vent Mend | Heal on a Vent that hits |
| Armour | Retired | Heat Shield | Damage cut while Hot |
| Pickup range | Retired | Scavenger | Shards on crit kills |
| Shard gain | Retired | Hoarder (existing) | Hoarder already raises shard gain, with a decision (spend or keep) |

Rule cards already in the pool stay as they are: Glass Cannon, Onrush, Overkill, Hoarder, Fast Hands, Lifesprout.

**Retired** means weight 0 (never offered by an altar, chest, shop, event, core or Echo Mirror; the legendary list
swaps them for their rule cards). Their data and tables stay, so an old save holding them keeps its effect, and the
gamble shrine's wins that pay into them (move speed, dash cooldown, regen, shard gain) still do.

**Count:** 7 rule cards built; 8 flat cards retired; 4 plain. Stat kinds offered: 18 → 17 (−1 per build pool).

## The seven built (starting values)

| Card | Trigger | Condition | Payoff (common / rare / epic) | Cap | Loop rules |
|---|---|---|---|---|---|
| Close Quarters | Your direct hit | The enemy's edge is within 2 m of you | +15 / 25 / 40 % damage | +80 % | Never a DoT tick or an Overkill splash |
| Third Strike | You land an attack (a swing, a bolt, a form's blast: once per attack) | The third in a row, each within 1 s of the last | That attack hits +30 / 50 / 75 % | +150 % | Counts once per root; the count restarts after a pause or the third |
| Reflex | You kill | Your dash is recharging | −10 / 15 / 25 % of the dash's full cooldown | 50 % | Once per attack (root), however many it kills |
| Adrenaline | You kill | The enemy was within 3 m | +15 / 25 / 40 % move speed for 1.5 s | +60 % | Refreshes, never stacks; The Fallen's mimic cap still applies |
| Vent Mend | You Vent | An enemy is in the blast | Heal 2 / 3.5 / 5 % of max HP | 10 % | Once per Vent (6 s cooldown) |
| Heat Shield | You are hit | You are Hot or hotter | −15 / 25 / 35 % damage taken | 50 % taken at least | A cut per mille (no flat reduction, §D) |
| Scavenger | You kill | The killing hit crit | +25 / 50 / 80 % of that kill's shards | +150 % | Once per kill |

Rarity weights: the stat cards' own `weight` (Close Quarters 8, Third Strike 8, Reflex 7, Adrenaline 7, Vent Mend 6,
Heat Shield 7, Scavenger 5), and the sources' usual rarity odds. Legendary amounts follow the boss tier's ×1.6 of
the epic, inside each cap.

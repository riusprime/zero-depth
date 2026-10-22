# v0.9.0 UC: utility and mechanic cards (G1, carried over from v0.8.0)

Carried from [`../v0.8.0/UTILITY_CARDS.md`](../v0.8.0/UTILITY_CARDS.md) (v0.8.0 D23, never answered; owner
2026-10-22: "UC, the utility cards … I haven't answered it yet"). The rows, numbers and rarities are unchanged. The new
**Live code** column is from the 2026-10-22 audit: whether the card already exists under another name, and what the
sim needs for it.

Owner line O36 (v0.8.0 playtest 2, 2026-10-16): "The current item pool focuses too heavily on healing, DPS, critical
chance, and similar numerical improvements. Add more miscellaneous and utility items that introduce different gameplay
mechanics rather than simply increasing stats."

**How to answer:** mark each row **Yes**, **No** or **Change: …**. Only Yes rows get built. Numbers are starting
values. Rarity is Common / Rare / Epic / Legendary. "L1 move" means your L1 button's move (Blink or Guard).

**The new attack rules (PLAN Q2–Q4):** rows marked ⚔ shape the attack, so they would sit under the new slot rules
(a Secondary, or a card that works only with some forms). The others are player or dash mechanics and stay outside
the wand, like today's utility cards.

| # | Card | What it does (in play) | Starting values | Rarity | Live code (2026-10-22) | Owner |
|---|---|---|---|---|---|---|
| 1 | Close Quarters | More damage the closer the enemy is | +40 % at 1 m, fading to 0 at 5 m | Rare | New. A distance factor in the damage chain (`src/sim/combat/damage.gd:72-79`) | |
| 2 | Second Wind | A second dash charge | 2 charges, same recharge each | Epic | New. The dash has one cooldown today (`world.gd:40, 1434-1450`); it becomes a charge count | |
| 3 | Deep Cuts | Bleed ticks harder and lasts longer | bleed +50 % damage, +1 s | Common | New. Bleed is the Bleed card's status (`data/modifiers/shared_bleed.tres`); the retired Serrated Edge's `bleed_*` fields can be reused | |
| 4 | Heavy L1 | Your L1 move hits hard: Blink leaves a blast where you land, Guard's block hits back | 30 damage, 2 m | Rare | **Near-duplicate of Phase Strike** (live: blinking or blocking hurts enemies around you; `item_procs.gd:219-245`). Could be Phase Strike's level-up instead | |
| 5 | Wide L1 | Your L1 move covers more: Blink's blast and Guard's block area grow | +60 % radius | Common | New. Widens `phase_radius_m` (`item_procs.gd:245`) and the guard arc (`damage.gd:15`); without Phase Strike it only widens the guard | |
| 6 ⚔ | Afterburn | Dashing leaves a burning trail behind you | trail 1.5 s, 6 damage / 0.25 s | Rare | New. The retired Ember Trail's trail code (`modifier_runtime.gd:187`) on the dash (`item_procs.gd:128`). Fire outside the element slot | |
| 7 | Adrenaline | A kill gives a short burst of speed | +30 % move speed for 1.5 s | Common | New, small: the kill hook exists (`item_procs.gd:19`) | |
| 8 | Perfect Dodge | Dashing through an attack at the last moment slows time around you briefly and your next hit crits | window 0.15 s before the hit, slow 0.6 s | Epic | New, large: there is no enemy-only slow (`world.gd:705` is a global freeze); needs a near-miss check | |
| 9 ⚔ | Fifth Strike | Every 5th hit is a heavy hit: double damage and a knockback | ×2, 1.5 m knockback | Rare | Partial overlap: the Blade's combo finisher (Finisher+), knockback exists (`attack_spec.gd:285`). Needs a hit counter | |
| 10 | Wind Up | Standing still charges your next attack | +15 % per 0.5 s, up to +60 % | Common | **Close to Flurry** (live: "After a pause …") and Gun Charge | |
| 11 | Last Stand | More damage the lower your health | up to +50 % below 25 % HP | Rare | New, small: an HP factor in the damage chain (the mirror of Executioner) | |
| 12 | Magnet | Shards and pickups fly to you from further away | ×3 pickup range | Common | **Duplicate**: the live Pickup Range stat card (`data/stat_cards/pickup_range.tres`) | |
| 13 ⚔ | Rebound | Shots and slashes that kill bounce to one more enemy | 1 bounce, 70 % damage | Rare | **Duplicate for the Blade** (Riposte Chain, Chain Cut); for the Gun, On Kill + a card already does it | |
| 14 ⚔ | Volatile | Enemies you kill explode | 40 % of their max HP, 1.5 m | Epic | Overlaps Overkill's splash; the %-of-max-HP blast is new. **Note:** your Q11 answer (2026-10-22: "I don't want to have the enemies exploding after they die that's broken") deleted Fire's kill blast and the Explosive card, so this row probably goes the same way | |
| 15 | Hunter's Mark | The first enemy you hit in each room is marked and takes more damage from everything | +50 %, until it dies | Common | New: a mark per enemy and a reset per room | |
| 16 | Ghost Step | Dashing makes you untouchable a little longer and you pass through enemies | +0.15 s invulnerable | Rare | **The retired Phase Dash**: its pass-through code is still there (`world.gd:1122-1128, 1560`); this re-enables it | |
| 17 | Backstab | Hits from behind an enemy deal more | +60 % | Rare | New, small: enemy facing and the rear-arc test exist (`damage.gd:11-29`) | |
| 18 | Crowd Control | More damage for every enemy near you | +6 % per enemy within 4 m, up to +48 % | Rare | New: a nearby count, cached once a tick | |
| 19 ⚔ | Echo Dash | Each dash also swings or fires once where you started | one free attack, 60 % damage | Epic | **Close to Long Shadow** (live: after a dash, your next attack comes from where it began). Undefined for Laser and Bomb | |
| 20 | Gravity Boots | Your dash pulls nearby enemies into your path | 2.5 m pull | Rare | New: a pull on the dash (the pull code exists) | |
| 21 | Overflow | Damage beyond what kills an enemy carries into the next hit you land | carry up to 100 % | Rare | Overlaps Overkill (the excess splashes onto a nearby enemy, `stats.gd:19, 285`) | |
| 22 ⚔ | Time Shard | Every 10th kill freezes all enemies on screen for a moment | 1 s freeze, 8 s cooldown | Legendary | New: the kill counter exists (`world.gd:91`); the freeze reuses Frost's (`engines.gd:306`), which bosses ignore | |

If you want any other mechanic, add a row at the bottom with just its name and what it does in play.

## Decisions (owner, date)
| Row | Answer | Built in |
|---|---|---|
| — | | |

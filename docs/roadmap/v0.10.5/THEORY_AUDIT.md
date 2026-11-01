# G1 audit: improving Zero Depth from game-design theory

**Status: waiting on the owner.** Nothing here is built before the answers arrive (OWNER_GATES §2).

## The owner's request (2026-11-01)

"I am gonna attach a research on game designed, oriented to make zerodepth better the idea is that you take this
information and contrast it against the game and the current mechanics, pointing out what we have and what we can
upgrade, dont change anything the idea is to develop a plan to make zerodepth better based on theory, propose a plan"
Then: "i'd leave out P11, and save as G1 list".

The research is the owner's *Game-design principles relevant to ZeroDepth* (not in the repo). It summarizes six books:
- Sylvester, *Designing Games*;
- Schell, *The Art of Game Design*;
- Swink, *Game Feel*;
- Adams & Dormans, *Game Mechanics*;
- Koster, *A Theory of Fun*;
- Schreiber & Romero, *Game Balance*.

## What we already have

| Principle | Where Zero Depth does it |
|---|---|
| Emergence from simple rules (Sylvester, Adams) | The wand: read left to right, triggers cut the shot ([`../../design/WAND.md`](../../design/WAND.md) "Rules") |
| Feedback loops with speed and strength (Adams) | Overclock heat: a fast positive loop with a cliff, Vent as the skill ([`../../design/SIGNATURE.md`](../../design/SIGNATURE.md)) |
| Costs beyond price (Schreiber) | Glass Cannon, Onrush, Hoarder, curses for +T, the Swap at 6 slots, salvage (GAME_BLUEPRINT §D) |
| Interest curve (Schell) | Each floor: Calm → The hunt → The swarm → peak about 1 min before the boss (`data/curves/floor_N.tres`) |
| Learnable patterns (Koster) | Telegraphs ≥ 0.4 s, enemy kinds introduced over three floors with "New: …", a signature mechanic per boss |
| Meaningful choice (Schell) | Fork doors show cost and reward, events have "Leave it", the Deep portal or the normal one |
| Skill grows, not stats (Schreiber) | Meta is cosmetic or alternatives only (PD-06) |

## Gaps the theory points at

1. **Comprehension burden (Sylvester).** The wand, heat, 18 stat cards, 17 combos, 12 curses, 8 events,
   12 special room types (`data/special_rooms/`), core theft, elites, the catch-up, Deep and Ascension. No one has
   weighed each one's value against its learning cost.
2. **Flat stats against our own pillar 1.** Most reward cards are still flat stats (`data/stat_cards/`: damage,
   attack speed, area, max HP, regen, armour, pickup range, shard gain).
3. **The hidden catch-up cancels growth out of sight** (`src/sim/world/catch_up.gd:13`, m = √(P ÷ E)). The
   player can neither see it nor play against it.
4. **The 10 s dash** (`data/player/runner.tres:10`, v0.9.5 G10). The smallest unit of control is now rare.
5. **Ascension loops repeat mastered patterns with bigger numbers** (×6 HP a loop, `src/sim/run/ascension.gd:14`).
6. **The stress matrix is still empty** (GAME_BLUEPRINT §E: "from GA" in every cell).
7. **Order vs. chaos at the top end:** up to 120 enemies plus stacked wand effects risk noise (Koster) and
   unreadable hits (pillar 2).
8. **Farming pressure:** the danger tier every 30 s pays more shards, so staying longer always pays (§H).

## The list

Real impact is `—` throughout: nothing has been measured for this audit. P11 (the death-recap replay) was left
out by the owner, 2026-11-01. The other IDs keep their numbers.

| ID | Area | Today | Proposal | Source | Needs |
|---|---|---|---|---|---|
| **P1** | Elegance audit | Every system stays once built | Score every system 1–5 on "experience it creates" and "what it takes to learn"; merge or cut the bottom ones. Candidates: the 12 special room types into ~7; the fountain, shrine and gamble wins into one "pact" room | Sylvester | Owner, then a G1 per cut |
| **P2** | Rule cards | Most reward cards are flat stats | Rewrite 6–8 flat stat cards as Trigger → Condition → Payoff. Regen → "heal 2 % on a Vent"; Armour → "hits taken while overheated are halved"; Pickup range → "a crit kill pulls shards in a short burst"; Area → "every third hit in a row is bigger". Keep 3–4 plain stats as filler | Framework P1, Schreiber | A card-by-card G1 |
| **P3** | Stress matrix | §E's matrix is empty | Fill it as rock-paper-scissors: each enemy kind is weak to one form or element and resists another (Shield Bearer resists Orbs and is pierced by Laser; Swarmer packs punish single-target; Mender punishes damage over time). Mix rooms so the matchup changes which choice is best | Schreiber (intransitive, situational) | Owner picks per row |
| **P4** | The catch-up | Hidden (owner D4: "Yes, but hidden") | Show it ("the depths answer your power ×1.4"), or move the scaling onto Deep and curses so it's opt-in. **Changes an owner decision** | Sylvester, Adams | Owner decision |
| **P5** | Dash | One dash, 10 s cooldown (G10) | Two charges of about 5 s each, or a dash refund on a perfect Vent. **Changes an owner decision** | Swink | Owner decision |
| **P6** | Shards and time | Shards follow the floor's 30 s tier with no limit | Shard gain flattens after the floor's peak minute. Exploring still pays through chests, events and altars, not the clock | Sylvester, Schreiber | Owner, then sims |
| **P7** | Feel per verb | Hit-stop, buffering, VFX pack | Tune start-up, active and recovery frames per combo hit and per Gun shot; dash-cancel windows; a small knockback or flinch on normal enemies; check against Swink's six variables (input, response, context, polish, metaphor, rules) | Swink | Owner feel test |
| **P8** | Room density | Floors grew to 20 bigger rooms | Measure open space against cover per room template; flag rooms too cramped or too empty at 120 enemies | Swink (spatial context) | Lead measures, owner picks |
| **P9** | Noise budget | Every effect draws at full strength | Cap the effect layers per screen at the top end; dim the player's own effects past N so hostile telegraphs always win the contrast | Koster, pillar 2 | G2 shots |
| **P10** | Wand forecast | The Build and Swap pages list cards | A live preview of the shot ("big bolt → 3 burning bolts → shock ring on hit") from the same sim function (EI-07) | Koster, Adams | G2 mockups |
| **P12** | Floor shapes | All three floors share one curve shape | Give floor 2 a midpoint set piece (a lockdown or elite duel); give floor 3 a calmer stretch before the boss | Schell (interest curves at several scales) | Owner |
| **P13** | Ascension remix | Loops add ×6 HP | Each loop adds one rule mutation (enemies inherit an element, elites pair up, a boss borrows another boss's phase) and lowers the HP step | Koster | Owner, then a G1 of mutations |
| **P14** | Enemy pairings | Kinds spawn by floor phase | Author 6–8 deliberate duos (Mender + Shield Bearer, Mine Layer + Charger, Sniper + Swarmer pack): new problems from the enemies we have | Adams (emergence), Koster | Owner picks the duos |
| **P15** | Economy map | No diagram of the economy | A Machinations-style map of shards, HP, power and threat, then the bot sims to find runaway or dead loops (Hoarder, rerolls, heal orbs, the catch-up) | Adams, Schreiber | Lead (docs + sims) |
| **P16** | Three curves | Bands per metric (SCORECARD) | Plot player power, enemy challenge and a skill proxy (damage avoided) per floor from the bots; find plateaus and spikes | Schreiber, framework §3 | Lead (sims) |
| **P17** | Training room | The Playground is dev-only (F10) | A wand sandbox in the hub with a dummy and spawnable enemies | Sylvester, Koster | G2 mockups |
| **P18** | Light fiction | Little lore | One line of lore per system (why heat, why go deeper, who the Hollow Crown is), in the Codex | Schell (tetrad) | Owner writes or approves |

## Suggested order

1. **First (cheap, the biggest gaps):** P1 → P2 → P3 → P6.
2. **Owner decisions:** P4, P5.
3. **The next feel pass (fits v0.10.5):** P7, P9, P10.
4. **Later versions:** P12–P18, with P15 and P16 first so the measurements aim the rest.

## Decisions (owner, date)

| ID | Answer | Built in |
|---|---|---|
| P11 | **Left out** (owner, 2026-11-01) | — |

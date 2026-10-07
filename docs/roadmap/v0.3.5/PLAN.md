# v0.3.5 — Feedback pass: the owner's notes on the v0.3.0 finishing build (plan, owner-directed 2026-10-07)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **On the branch:** v0.3.0 "Three Floors" with its finishing workstreams (PROGRESS of v0.3.0, last `08f7295`).
  `main` still doesn't exist (O3). No formal release of v0.1.0–v0.3.0 has been cut (only v0.0.1 has patch notes);
  a consolidated release goes with the PR that creates `main`, when the owner asks for it.
- **The owner played the finishing build** and sent one message (2026-10-07, verbatim in
  [`../v0.3.0/PLAYTEST_RUN_2.md`](../v0.3.0/PLAYTEST_RUN_2.md) "Owner answers"). It closes v0.3.0 as played.
- ROADMAP §4: "A `.5` pass takes priority whenever owner feedback arrives." This version takes the fixes, the
  polish and the combat notes. The owner's new build direction (four damage abilities, stat cards, exponential
  growth, hordes, blink found later, more items) is v0.4.0 scope, planned in [`../v0.4.0/PLAN.md`](../v0.4.0/PLAN.md),
  because it replaces the item model and PD-01 / PD-08.
- **Owner process rule (2026-10-07):** "spawning 4 agents max at the time, then continue after they are done with
  the assigned tasks" (replaces the earlier 2–3). Waves of at most 4 workstreams; each wave is merged before the
  next starts.
- Every number below is a **starting value** the owner tunes after playing.

## The owner's feedback, as a list (2026-10-07)
| # | Owner line (verbatim) | Decision | Where |
|---|---|---|---|
| F1 | "dashing or blinking while hot vents a blast - this should be an different action button" | A **Vent** action on its own button (F / pad B, remappable): vents the heat as a blast when Hot or above; dash and blink no longer vent | v0.3.5 K |
| F2 | "the overclock heat should be an straight bar, way more minimalistic" | The arc meter becomes a thin straight bar with two small ticks (Hot, Overclock) and the overheat end; no frame, no segments, colour only | v0.3.5 UI |
| F3 | "the bosses should have better AI and faster movements, some times is impossible to get hit by them and the fight are extremely easy" | Bosses move faster (+30 %), keep tracking through most of a wind-up and commit late, lead the player and punish a dash with a follow-up aimed at the landing spot, chain attacks without idle gaps; their fights get shorter windows to hide in | v0.3.5 AI |
| F4 | "same for regular enemies, way too predictable and avoidable by dashing or blinking" | Normal enemies: varied wind-up lengths (still ≥ the 24-tick minimum), predictive aim, a Charger that can re-steer mid-charge (limited turn rate), Needle spreads and bursts, enemies that flank and spread out; attacks that cover the dash escape lanes | v0.3.5 AI |
| F5 | "we should add new ones that have faster very hard to dodge spells" | New enemy **Arc Caster**: fast spells (a lightning bolt at high speed, a 3-bolt spread, a rune that erupts under you); every spell still has a readable telegraph ≥ 24 ticks | v0.3.5 AI |
| F6 | "some kind of floating enemy that throws bombs (hittable from the ground level tho, and the circle appears" | New enemy **Bomb Drone**: hovers above the ground (drawn up high with a ground shadow) but melee and shots hit it; lobs bombs at you, each with a ground circle that fills until it lands | v0.3.5 AI |
| F7 | "I kinda orient this into an incremental feeling that you can kill a lot of enemies as you grow on" | Hordes: many more enemies as you grow | v0.4.0 |
| F8 | "each build showld focus on 4 items that have combo sword maybe auto throuwing bombos, a robot that follows you, like actual abilities than make damage" | **Four ability slots**: damage abilities (the combo sword, auto-thrown bombs, a robot that follows you, …) | v0.4.0 |
| F9 | "the rest of the upgrades and cards you get should be oriented into +%hp dmg crit and that kind of stats you you grow exponentially" | Every other card is a stat card (+% HP, damage, crit chance/damage, speed, area, cooldown…) that stacks multiplicatively | v0.4.0 |
| F10 | "the enemies must have an scaling system on damage and health that usually goes just a bit below of what you are growing, and spawning more enemies each floor and time, so it becomes this crazy hard huge battle but you feel like you are a "god" feeling" | Enemy HP and damage scale with floor and time, tuned to stay just below the player's expected growth; spawn counts grow per floor and over time | v0.4.0 |
| F11 | "blinking should be a later on spell you get" | Blink leaves the starting kit; it becomes an ability found during the run | v0.4.0 |
| F12 | "dashing should have a higher cooldown" | Dash cooldown 0.8 s → 1.4 s | v0.3.5 K |
| F13 | "we need more objects or upgrades and combos to add variety" | More abilities, stat cards and combos | v0.4.0 |
| F14 | "the map is bugged and is not oriented the same way as the actual map it is inverted" | Fix the minimap orientation so up/left/right match the screen exactly (a test compares a known room layout drawn on the minimap with its screen projection) | v0.3.5 UI |
| F15 | "the HUD is fine but no so cyberpunk let's make it a bit more minimalistic" | A calmer HUD: drop the glitch/echo treatment and heavy frames; thin lines, plain type, fewer elements (G2: mockups, default ships) | v0.3.5 UI |
| F16 | "the card select from chests and altars are way too AI slop, we should not have the rounded card with the color shadow at the left, change it to match the style of the game" | Pick cards restyled: square corners, no coloured side shadow, the game's low-poly faceted look (flat dark panel, thin outline, rarity as a small mark) (G2: mockups, default ships) | v0.3.5 UI |
| F17 | "sounds from sword are too overwhelming" | Sword sounds quieter (−8 dB starting value), shorter tails, one layer per slash, a limit on overlapping swing voices | v0.3.5 UI |
| F18 | "we need to add a second ability to guns and blades, so you have variety of attacking movements and it is not just spamming the same attack all the time" | A **Skill** button (Q / pad Y, remappable): Blade **Lunge Cleave**, Gun **Scatter Blast** (below) | v0.3.5 K |
| F19 | "there should be an animation of the character entering a portal (make it lighter blue matching his eye color)" | Entering the portal plays an animation (the hero is drawn in, dissolves into light-blue light matching the visor); the portal turns that light blue | v0.3.5 PT |
| F20 | "and an animation getting to one of the new rooms" | Arriving on the next floor plays an arrival animation (the hero materialises from the same light); lead's reading: "new rooms" = the next floor's start room | v0.3.5 PT |
| F21 | "continue onto v0.4.0 if not done then v0.50 … after keep developing the roadmap" | v0.3.5, then v0.4.0. **v0.5.0 needs the owner's playtest of v0.4.0 first** (ROADMAP §0.3, a hard rule in CLAUDE.md): raised with the owner, not resolved quietly | process |
| F22 | "do this spawning 4 agents max at the time, then continue after they are done with the assigned tasks" | Waves of at most 4 agents | process |

## Design (starting values)
**Vent (F1, K).** `InputFrame.VENT` (a new bit, appended). Pressing Vent when heat ≥ Hot fires the existing vent
blast (same shape and damage as today) and drops heat to 0; below Hot it does nothing (a small "cold" click). Dash
and blink stop venting. HUD hint next to the heat bar shows the key.

**Dash (F12, K).** `cooldown_seconds` 0.8 → 1.4. The gamble dash-cooldown stat and Swift Feet still cut it.

**Second abilities (F18, K).** One new action `skill` (Q / pad Y). Data in the build `.tres` (one ability per
build), shapes from the existing attack-shape functions, forecasts from the same function (EI-07).
- **Blade — Lunge Cleave:** a 3.5 m forward lunge toward the facing, then a 180° cleave (reach 2.2 m, damage 28,
  stagger like the finisher); cooldown 4 s; can be cancelled into nothing (commits once pressed).
- **Gun — Scatter Blast:** a 60° cone of 7 pellets toward the aim (range 4 m, 6 damage each, knockback 1.5 m, the
  user steps back 0.8 m); cooldown 3.5 s.
- Both build heat, can crit nothing yet (crit is v0.4.0), show a cooldown pip on the HUD and have a sound.

**Enemy and boss AI (F3–F6, AI).** Keep MIN_TELEGRAPH_TICKS (24) and "no damage without a readable cause".
- Bosses: move speed +30 %, wind-ups track the player until their last 12 ticks, then commit; after the player
  dashes, the next attack aims at the dash landing point; recovery gaps −25 % more; a gap-closer when the player
  is out of reach for 2 s.
- Normal enemies: wind-up 24–40 ticks drawn per attack (enemy stream), shots lead the target (by its velocity),
  Charger turn rate during a charge 60°/s, Needle bursts of 3 with a 10° spread, enemies spread around the player
  instead of stacking.
- **Arc Caster** (new, from danger tier 1): keeps 6–9 m away, casts (a) a fast bolt (22 m/s, 30-tick telegraph:
  a line on the ground), (b) a 3-bolt spread, (c) a rune under the player (circle, erupts after 36 ticks).
  HP 40, damage 12, 4 shards. Code-built low-poly model in the enemy style.
- **Bomb Drone** (new, from danger tier 2): hovers (drawn ~1.8 m up with a shadow and a soft bob; the sim treats it
  as a ground-plane body so melee and shots hit it), keeps 5–8 m away, lobs a bomb to the player's position: a
  ground circle (radius 1.8 m) that fills over 48 ticks, then explodes (damage 16). HP 30, 4 shards.
- The bots' boss fight-length bands are re-measured; numbers reported, bands not widened without the owner.

**UI (F2, F14–F17, UI).** A straight heat bar (F2); a calmer HUD (F15) and pick cards in the game's style (F16)
each with 2–3 mockups (`evidence/hud_mockups.png`, `evidence/card_mockups.png`), the lead's default ships; the
minimap orientation fix with a test (F14); sword sounds −8 dB, shorter, one layer, voice limit 2 (F17; the
generator stays byte-reproducible).

**Portal and arrival (F19, F20, PT).** Portal colour → the visor's light blue. Entering: the sim already owns the
floor transition; the animation length is read from sim ticks (EI-03): the hero is pulled to the portal centre,
spins and shrinks into light-blue particles with a flash (≈ 1.0 s). Arrival: the next floor opens on a light-blue
column where the hero materialises (≈ 0.8 s) before control returns. Reduced motion shortens both to a fade.

## Steps (wave 1: four agents)
| Step | Agent scope | Owner lines |
|---|---|---|
| K | Kit: Vent button, dash cooldown, Skill button + Lunge Cleave + Scatter Blast (sim, data, input, HUD pip, sound, e2e) | F1, F12, F18 |
| AI | Smarter, faster bosses and enemies; Arc Caster and Bomb Drone (sim, data, spawn tables, models, telegraphs, sounds, bots) | F3–F6 |
| UI | Straight heat bar, calmer HUD, restyled pick cards, minimap orientation fix, quieter sword | F2, F14–F17 |
| PT | Portal entry and floor arrival animations, light-blue portal | F19, F20 |

Each step: tests (unit + the e2e through `main.tscn` with real input where it's player-facing), evidence file in
`evidence/`, docs touched (SIM_CONTRACTS / CONTENT_SCHEMA / strings en + es), full suite green before the merge.

## Open items (what they block)
- **v0.5.0 start** needs the owner's v0.4.0 playtest (F21) — asked.
- G2 picks for the HUD and the pick cards (defaults ship meanwhile).
- O3 `main` (a PR, when the owner asks), O4 credit line (Tripo licence).
- From the v0.3.0 sheet, unanswered: crash on hit confirmed gone? Blade vs Gun balance, shrine prices, frame rate.

## Verification
- Full suite + lint + export smoke before every merge push; goldens changed only on purpose and named in PROGRESS;
  CI (Verify, Windows, Shots) green; then the owner's Windows playtest together with v0.4.0.

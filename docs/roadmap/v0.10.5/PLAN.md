# v0.10.5 — Feedback pass: the v0.9.5 + v0.10.0 playtest and the theory audit (plan, owner-approved 2026-11-01)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md) (opened with the
first build step).

## Context
- **Base:** `claude/v0100-cleanup` at `ea152e1b` (v0.9.5 + v0.10.0 + FX). Not yet merged into `main`; v0.10.0's
  release step is still open.
- **The owner played v0.9.5 and v0.10.0 together** and answered OWNER_TODO's open playtest items and decisions, plus
  the G1 theory audit ([`THEORY_AUDIT.md`](THEORY_AUDIT.md)), on 2026-11-01. Clarifications came through three batches of
  questions on the same day (recorded as the "Asked" column below).
- **How work runs (owner, 2026-11-01):** "for small direct fixes or easy tasks deploy sonnet subagents, with a very
  precise and concise task to do so they don't have to think too much, if there is a more complex task deploy a opus
  5.5 agent", then "max 3 sonnet agents and 1 opus at the same time". Each step below names its agent: **S** = Sonnet (a precise brief, no design), **O** = Opus 5.5 (design
  or several systems). At most three Sonnet agents and one Opus run at once, or one Sonnet and two Opus (owner, 2026-11-01); each works in its own worktree, removed after the
  merge.
- **Gates:** every **O** step that adds something new drafts a G1 list or G2 mockups first and stops for the owner.
  Nothing new is built before the owner's answer (OWNER_GATES).

## Overnight mode (owner, 2026-11-01)

"Keep going until you complete all of them, if you have any questions write them down and we go over them at the end";
asked about the gates: **"Pick and build"** and **"Don't push"**. So every G1/G2 gate below is passed by the lead's recommended
pick, built as starting values, and listed in [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md) for the owner to keep or change.
Nothing is pushed until the owner says so.

## Every owner line → where it lands

### The playtest items and the open decisions

| # | Owner line (verbatim or close) | Asked (2026-11-01) | Decision | Step |
|---|---|---|---|---|
| L1 | "Void black holes feel good" (and "D20 - ok") | — | D20 closed, as built | — |
| L2 | "For now loop difficulty is fine but we are actually missing something to make the player want to go further" | Loop-only rewards; records and depth; more fragments a loop; and P13 | D22 closed as built (loop 2 and later). Loops get reasons to go on | O5a, O5b |
| L3 | "Faster bosses: still feel easy most of the times, but some of them are invulnerable for too long, almost unhittable" | Lantern Shade, Clockwork Judge | Shorten those two bosses' invulnerable windows; harder bosses come through L16 | O2a, O2b |
| L4 | "Rarity: fine for now" (and D31, D33, D35 OK) | — | Closed, as built | — |
| L5 | "the default pulse gun was better than new one, ring also doesnt look good" | "keep pulse default, the element ones are good, just the default and redo the ring … the ring it currently has is a good base but the parks should go around it and be way smaller" | The plain (no-element) Pulse Gun bolt goes back to its pre-pack look; the element bolts keep the pack. The Ring keeps its current base; its sparks orbit round it and are much smaller | S10 |
| L6 | "The prism feels better, we still have to work on the last phase" | "Needs something cooler while he's down and not on the dodging pattern"; "Boring pattern" | D60 closed. The last phase gets a new pattern and a cooler moment while she is down (outside the dodge pattern) | O3 |
| L7 | "thorch and embers feel good" | — | GX closed, as built | — |
| L8 | "HR switches if fine" | — | All four HR switches stay on | — |
| L9 | "D13 - ok" | — | The listed streams (and D45 (3)'s `wand:swirl`) join EI-05's locked list | S11 |
| L10 | "D23 - we should go over them again with game theory audit taken into account" | P2: yes, the 22 utility cards | A new G1 of the 22 utility cards against the theory audit; the kept ones replace the flat stat cards (P2) | O9 |
| L11 | "D32 - double legendary card is broken, we should nerf that a bit so you don't always get double" | The core and the boss altar both give a Legendary | The boss's stolen core gives a Legendary at 35 % (a starting value), otherwise an Epic | S6 |
| L12 | "D38 - bosses be oneshoted on very very rare ocassions … but fights should last 1-2 minutes" | — | D38 = (a): a floor boss reads your power when its fight starts and is paced to 1–2 minutes; a one-shot stays possible only past an extreme cap | O2b |
| L13 | "D43 - blade is still pause" | — | The Blade's hit-stop is cut (N1's +20 % undone and 25 % less again, a starting value). D43 (2) and (3) stay as built | S1 |
| L14 | "D41 - previous ring was cooler" | — | The Warden's slam goes back to the old near-white band | S2 |
| L15 | "D45 - OK", "D47 OK", "D49 OK", "D51 ok", "D54 OK", "D58 ok for now", "D60 - ok", "D62 - OK for now", "D65 feels better now", "D66 OK" | — | Closed, as built | — |
| L16 | "D46 - sometimes it feels like it is not working and on some occasions it feels overcrowded if you are weak, could we also adjust it to not make it unfair based on the strength?" | Read your state live | The intensity director reads your HP and kill rate live: a hurting or slow-killing hero gets an earlier, longer quiet and smaller packs; a strong one gets the full build-up | O4 |
| L17 | "D52 - still has no height you appear half body inside of it" | — | The arrival receiver sits flush with the floor (or the hero stands on its top), never half sunk | S4 |
| L18 | "D56 - ok but could be polished a little bit more" | Night Rocks, Frozen Shore | One more calmer-walls pass on those two biomes | S9 |
| L19 | "D59 - curse room is too dark, you cant even see the model for the altar … looks like all the light is being absorbed, also there is no transition between the floor colors so a straight line is weird" | — | Keep the mood; light the altar so its model reads; blend the floor colour at the room's edge instead of a hard line | S5 |
| L20 | "D63, sure we can even make it 5 ticks or equivalent to 0.2 seconds" | Refresh every 0.2 s | The path refresh runs every 12 ticks (was 10), still spread over 3 ticks | S3 |
| L21 | "D64 - needs more testing", "D68 ok need testing after new card arrive" | — | Stay open | — |
| L22 | "D67 we could add just 10 to 15% more loot to make it more fun and test it" | More chests and altars | ~12 % more chests and altars a floor (a starting value) | S7 |
| L23 | "D69 card pool needs to be reduce to what we actually is available in the game we have over 60 cards not used, remove them from the game to have a cleaner code" | — | Every card file that no run can offer is removed, with its code paths; old saves still load | O1 |
| L24 | "D70" (no answer) | — | Stays open | — |
| L25 | "Remove from the to do all the 3d assets already provided and leave only the ones that are left" | — | OWNER_TODO §3–§4 keep only the art still owed | S8 |

### The theory audit (G1, [`THEORY_AUDIT.md`](THEORY_AUDIT.md))

| # | Owner line | Decision | Step |
|---|---|---|---|
| P1 | "let's go through this one together" | The lead prepares a scoring worksheet; owner and lead go through it together | P1 (lead) |
| P2 | "very nice idea, let's use the pending cards as this" | The 22 utility cards (D23) are re-reviewed as the rule cards that replace the flat stats | O9 |
| P3 | "yes" | Stress matrix as rock-paper-scissors | O10 |
| P4 | "let's try to show it, also modify the triangles at the top to be a line filling up as a danger hazard texture, small kinda shaped like hp but green to red blinking when full" | The danger triangles become a thin bar like the HP bar, filled with a hazard-stripe texture, green → red, blinking when full. The catch-up shows as a separate small tag beside it ("the depths answer ×1.4") | O6 |
| P5 | "dash refund on a perfect vent" | A Vent in the top band before overheat refunds the dash | S12 |
| P6 | "OK … can we also make the shards stay on the floor instead of flying around" | Shard gain flattens after the floor's peak minute; shards lie still where they drop until you walk into pickup range | O7 |
| P7 | "OK" | Feel pass per verb | O11 |
| P8 | "OK" | Room-density measurement | S13 |
| P9 | "yes cap it it will also help fps" | The effect noise budget | O12 |
| P10 | "ok" | The wand forecast | O13 |
| P11 | (left out, 2026-11-01) | — | — |
| P12 | "OK" | Floor shapes | O14 |
| P13 | "go for it" | Loops remix rules instead of only inflating | O5b |
| P14 | "OK" | Enemy pairings | O15 |
| P15 | "we can try sure" | The economy map | O16 |
| P16 | "sure" | Three progression curves | O16 |
| P17 | "let's add a new room at the hub that serves this purpose, at the bottom that is empty, make it a bit smaller" | A training room in the hub's empty bottom area, smaller than the other hub rooms | O17 |
| P18 | "yes" | One lore line per system in the Codex | O18 |

## Steps

Every number marked *starting value* goes on the dev panel and the owner tunes it. Every step's tests: lint, the
touched test folders and the e2e that reach it (CLAUDE.md "Testing before a push"). A golden that changes is named
in PROGRESS "Goldens changed on purpose".

### Wave 1: direct fixes (Sonnet, two at a time)

#### S1. A snappier Blade (L13)
- **Files:** `data/player/runner.tres` (the four-slash combo, Blade-only melee) and `PlayerTable.default_combo`; the
  view's `HitStop`. (Corrected by the lead, 2026-11-01: the pause is the combo's hit-stop, which N1 raised; Lunge
  Cleave's 7 ticks in `data/builds/blade.tres` were never raised and stay.)
- **Task:** combo hit-stop 4,4,5,8 → 3,3,3,5 ticks (N1 undone, then 25 % less, rounded; starting values); the
  view's hold 2.4 → 2 frames and camera kick 0.072 → 0.06 m (N1 undone). The modifier-equivalence golden moves on
  purpose.
- **Done when:** the combo, player-kit, hit-feel and content tests pass; the golden is named in PROGRESS.

#### S2. The Warden's slam band back (L14)
- **Files:** the Warden slam view that installed `fx_dust_ring` (TX2, `TEXTURES_2.md`).
- **Task:** restore the pre-TX2 near-white band for the Warden's slam. Leave `fx_dust_ring` installed for anything
  else that uses it.
- **Done when:** one shot of the slam in the Playground; presentation tests pass.

#### S3. The path refresh every 0.2 s (L20)
- **Files:** `src/sim/ai/nav_field.gd:17` (`PERIOD := 10`).
- **Task:** `PERIOD` 10 → 12; the 3-tick spread (NF) stays. Update the comments that say "one tick in ten".
- **Done when:** the AI tests, the goldens (any that change are named) and the hitch probe pass.

#### S4. Standing on the receiver (L17)
- **Files:** `src/presentation/world_view/floor_receiver.gd`.
- **Task:** sink the receiver model so its top is level with the floor (the hero's feet at y = 0 stand on it), or,
  if the model can't sink, lift the hero's visual by the receiver's top height while on it. Presentation only.
- **Done when:** one shot of a floor arrival shows the hero's whole body above the receiver.

#### S5. A curse room you can see in (L19)
- **Files:** `src/presentation/world_view/curse_room_view.gd`; the room's floor material.
- **Task:** keep the dark veil and the violet sigils; add a cold key light on the altar so its model reads (starting
  value), and lower the veil's absorption. Blend the curse room's floor colour into the neighbouring floor over
  about 1.5 m instead of a hard line.
- **Done when:** one shot of the curse room shows the altar model and a soft floor edge.

#### S6. The stolen core is Legendary only sometimes (L11)
- **Files:** `src/sim/…/core_theft.gd` (`CoreTheft.grant`), `data/event_rules/floor.tres` or `data/legendary/boss.tres`.
- **Task:** a boss's core gives its Legendary stat card at 35 % (a new data field, starting value), otherwise an
  Epic card from the same pool, drawn on the core's existing stream. The boss's altar is unchanged.
- **Done when:** a unit test over seeds shows both outcomes; the core-theft tests pass.

#### S7. More chests and altars (L22)
- **Files:** `data/event_rules/floor.tres` (the per-floor counts), `docs/design/GAME_BLUEPRINT.md` §D.
- **Task:** about 12 % more chests and altars a floor (starting value; with integer counts, one more on a share of
  floors). Rewards per card are unchanged.
- **Done when:** the generation tests pass; one line in the blueprint.

#### S8. OWNER_TODO cleaned (L25, and the answers above)
- **Files:** `docs/OWNER_TODO.md` only.
- **Task:** (1) §2: remove every decision this PLAN closes (D13, D20, D22, D31, D32, D33, D35, D38, D41, D43, D45,
  D46, D47, D49, D51, D52, D54, D56, D58, D59, D60, D62, D63, D65, D66, D67, D69, D71); D23 says "being re-reviewed
  (v0.10.5 O9)". (2) §1: remove the playtest items the owner answered (Void, loops, faster bosses, rarity, Prism,
  torch and embers, HR switches). (3) §3–§4: remove every art item whose file is already in `assets/` (check each id
  against the asset manifests), keep only what is still owed. Add a "Being built (v0.10.5)" line linking this PLAN.
- **Done when:** the diff touches only that file.

#### S9. Calmer walls, second pass (L18)
- **Files:** `data/biomes/night_rocks*.tres`, `data/biomes/frozen_shore*.tres` (`wall_detail`, `wall_face_contrast`,
  `wall_top_contrast`, `wall_stone_scale`, `wall_breakage`).
- **Task:** another ~20 % calmer on those two biomes (starting values). Others untouched.
- **Done when:** one shot each; the biome content tests pass.

#### S10. The plain Pulse Gun bolt and a better Ring (L5)
- **Files:** the bolt and Ring views from VX2 / N3 (`data/vfx/`, `src/presentation/…`).
- **Task:** (1) the plain Pulse Gun bolt (no element) uses its pre-pack look again; the element bolts keep the pack.
  (2) The Ring keeps its current base; its sparks orbit round the ring and are far smaller (about a third).
- **Done when:** one shot of each; the VFX tests pass.

#### S11. Streams locked (L9)
- **Files:** `docs/architecture/LOCKED_DECISIONS.md` EI-05.
- **Task:** add `map:ice`, `map:starglow`, `map:overrun`, `map:shrine`, `loot:shrine:<use>`, `map:curse_room`,
  `wand:swirl` to EI-05's list. Docs only.

#### S12. A perfect Vent refunds the dash (P5)
- **Files:** `src/sim/…/heat.gd` (Vent), the dash cooldown, `data/heat/overclock.tres`.
- **Task:** a Vent at heat ≥ 90 of 100 (a new field `perfect_vent_from`, starting value) ends the dash cooldown at
  once. A sound and a short flash on the dash icon when it happens. Each heat item still behaves as before.
- **Done when:** a unit test (vent at 95 refunds, at 80 doesn't); the heat e2e passes.

#### S13. Room density measured (P8)
- **Files:** a new `scripts/checks/room_density.gd` (writes to `build/`).
- **Task:** for each room template, the open area vs. cover area at the player's radius, and the largest open
  circle. Paste the output into `evidence/ROOM_DENSITY.md` with the command and the SHA. No room changes.
- **Done when:** the evidence file; the owner picks the rooms to change.

#### S14. No rune puzzle room for now (P1, owner 2026-11-01: "let's remove the puzzle for now")
- **Files:** `data/special_rooms/rune_puzzle.tres` (`chance_permille`).
- **Task:** set its chance to 0 so no floor places it; keep the code and the room for later. A saved floor that
  already holds one still loads and works.
- **Done when:** the generation tests pass (fix any that expect a rune room); a test that 200 seeds place none.

#### S15. Do cracked walls spawn, and can you see them? (P1, owner: "i've never seen in game a cracked wall are you sure they spawn and are visible? we should keep them tho")
- **Files:** `data/special_rooms/cracked_wall.tres` (25 % of floors), `CrackedRooms.mark`, its view.
- **Task:** count over 200 seeds how many floors place a cracked wall and where; take one shot of one from the game
  camera. Report the count, the shot, and any cause it can't be seen (hidden behind a wall, same texture as the
  others, culled). No fix in this step.
- **Done when:** the count and the shot reach the lead; the fix (if any) becomes its own step.

#### S15b. Cracked walls you can find (owner 2026-11-01, after S15: "Clear cracks + faint glow", "About 1 floor in 3")
- **Why:** [`evidence/S15_CRACKED_WALLS.md`](evidence/S15_CRACKED_WALLS.md): 3 % / 20 % / 7.5 % of floors 1/2/3, and the
  cracks are 2 cm bars at alpha 0.12 on two faces only.
- **Task:** the chance set so each floor lands near 30 %; cracks ~6 × 8 cm at alpha 0.85 on all four faces; a faint
  pulsing seam glow; the slab joins the wall cutaway. Starting values.
- **Done when:** the re-measured rates, the cracked-room and view tests pass, one shot shows the cracks.

#### S5b. The curse altar shows its details (owner 2026-11-01, after S5: "it is like white weird … like whited out")
- **Task:** no self-glow on the altar model; its albedo brightened (×2.4, starting value) instead; the altar light
  4.0 → 2.5. A close-up for the owner.

### Wave 2: the complex work (Opus)

Each O step lists its gate. A step whose gate is a G1 or G2 stops at the draft; its build half runs after the owner
answers.

#### O1. Only the cards the game uses (L23)
- **Task:** list every card resource (`data/items`, `data/modifiers`, `data/stat_cards`, `data/abilities`,
  `data/combos`, `data/legendary`) that no run can offer today (not in a pool, a pacing table, a shop, a core, an
  event, a combo, a test fixture the game needs). Present the list to the lead, then remove them with their code
  paths, strings and tests. Old saves that name a removed card load without it (a migration, with a test).
- **Also removed here (P1, owner 2026-11-01: "The combos can go away yeah, that's old"; then, told 4 still form, "Keep those 4"):** the 12 combos that can no longer form, and the
  combo code only they use. **Blood Harvest, Shatter Dash, Slipstream and Spiked Phase stay** (they still form), with their badges; the element pairs stay. The
  5 flat curses (Leaky Core, Price Gouge, Swarm Call, Swift Foes, Withering) go in the same step (owner: "Yes, cut the 5").
- **Gate:** the removal list goes to the owner as one table before deleting.
- **Done when:** the content, arch, old-save and every-card soak tests pass; D69's pool test ceiling matches.

#### O2a. Hittable Lantern Shade and Clockwork Judge (L3)
- **Task:** measure each boss's share of fight time spent invulnerable (fades, shielded patterns, gates). Cut it to
  at most ~15 % (starting value) by shortening those windows or opening a hittable spot during them. Bring the
  numbers before and after.
- **Done when:** a measured table in evidence; the boss tests pass.

#### O2b. Boss fights of 1–2 minutes (L12, D38 (a))
- **Task:** a floor boss reads your power when its door opens (the BH1 read) and sets its HP so the fight lasts
  60–120 s at that power (the final boss's N2 pace rule, adapted), with the phase gates kept. An extreme build past
  a high cap can still one-shot a phase: very rare by design.
- **Gate:** the rule and its numbers to the owner before building.
- **Done when:** sims at three power levels show 60–120 s fights; the boss tests pass.

#### O3. The Prism's last phase (L6)
- **Task:** design 2–3 options for (1) a new last-phase pattern and (2) a cooler moment while she is down, outside
  the dodge pattern (a punish spectacle, a breakable, a counter-hit).
- **Gate:** the owner picks one option per question; then it is built.

#### O4. A fair intensity director (L16)
- **Task:** the director (N5) reads the hero's live state (HP share, kills per 10 s): low HP or a slow kill rate
  brings the quiet sooner and longer and caps the pack size; a strong hero gets the full build-up. All thresholds
  are starting values. Fix the "not working" cases: find when the director never enters quiet and report them.
- **Done when:** sims with a weak and a strong scripted hero show the alive count and quiet lengths diverge as
  described; the director tests pass.

#### O5a. Reasons to loop (L2)
- **Task:** design a G1 list of: loop-only rewards (cards, robes or relics earned only on loop 2+), records (best
  loop, best time) in the hub and the recap plus loop achievements, and rune fragments that grow per loop.
- **Gate:** G1 (row by row).

#### O5b. Loops remix rules (P13)
- **Task:** a G1 list of loop mutations (enemies inherit an element, elites pair up, a boss borrows a phase from
  another boss…), one added per loop, with a lower HP step per loop to match. Built together with O5a's approved rows.
- **Gate:** G1.

#### O6. The danger bar and the catch-up tag (P4)
- **Task:** 2–3 G2 mockups of the top plate: the triangles replaced by a thin bar shaped like the HP bar, filled
  with a hazard-stripe texture, green → red as danger rises, blinking when full; the catch-up shown beside it as a
  small tag ("the depths answer ×1.4"; hidden at ×1.0). en + es, 1920×1080.
- **Files:** `src/presentation/hud/danger_meter.gd`, the catch-up value (`World.catch_up`, read only).
- **Gate:** G2; the owner picks one, then it is built (and D4's "hidden" is recorded as flipped in LOCKED_DECISIONS).

#### O7. Shards that pay less after the peak and stay put (P6)
- **Task:** (1) after a floor's peak minute, shard gain per kill flattens (starting value: holds at the peak's
  rate instead of following the 30 s tier). (2) Shards lie where they drop and are taken only inside pickup range
  (no pull across the room); pickup range keeps its stat. Check the shop economy against the bot sims and report.
- **Done when:** the economy tests and a bot-sim table of shards per floor (before/after).

#### O8. (spare)

#### O9. The 22 utility cards, as rule cards (L10, P2)
- **Task:** re-review [`UTILITY_CARDS.md`](../v0.8.0/UTILITY_CARDS.md) against the theory audit (decisions in motion,
  learning cost, stress-matrix fit), and map which flat stat cards each kept card replaces.
- **Gate:** G1 (row by row), then built in steps of a few cards.

#### O10. The stress matrix (P3)
- **Task:** a G1 table: for each enemy kind, the form or element it is weak to and the one it resists, with the
  numbers, plus which room mixes would change the best pick.
- **Gate:** G1; then built (sim) and measured with the bots.

#### O11. Feel per verb (P7)
- **Task:** for each Blade combo hit, the Gun shot, the dash and Vent: list start-up / active / recovery ticks, the
  cancel windows and enemy hit reactions today; propose changes with numbers (dash-cancel windows, a small flinch on
  normal enemies).
- **Gate:** G1; the owner's feel test after building.

#### O12. The effect budget (P9)
- **Task:** cap the hero's own effect layers on screen (count and alpha, starting values); past the cap the oldest
  or weakest dim first, so hostile telegraphs always win the contrast. Measure fps with the heaviest scripted build.
- **Done when:** a perf probe before/after (timing marked as this machine's), the readability test passes.

#### O13. The wand forecast (P10)
- **Task:** G2 mockups of a live shot preview on the Build and Swap pages ("big bolt → 3 burning bolts → shock ring
  on hit"), computed by the same sim function (EI-07).
- **Gate:** G2, then built.

#### O14. Floor shapes (P12)
- **Task:** a proposal: floor 2 gets a midpoint set piece (a lockdown or an elite duel); floor 3 a calmer stretch
  before the boss; with the curve changes in `data/curves/`.
- **Gate:** the owner approves, then built.

#### O15. Enemy pairings (P14)
- **Task:** a G1 of 6–8 authored duos (Mender + Shield Bearer, Mine Layer + Charger, Sniper + Swarmer pack…), each
  with the problem it poses and the floors it appears on.
- **Gate:** G1, then built.

#### O16. The economy map and three curves (P15, P16)
- **Task:** a Machinations-style diagram (shards, HP, power, threat) in `docs/balance/ECONOMY_MAP.md`, then bot sims
  plotting player power, enemy challenge and damage avoided per floor; flag runaway or dead loops and plateaus.
  Evidence only, no tuning.

#### O17. The training room (P17)
- **Task:** a room in the hub's empty bottom area, smaller than the other hub rooms: a dummy, a panel to spawn any
  enemy kind, and the Build page to try wand orders. Nothing there counts toward records or unlocks.
- **Gate:** a G2 of its layout, then built with an e2e that walks there from the hub.

#### O18. Lore lines (P18)
- **Task:** one line of lore per system (heat, the depths, the wand, the Hollow Crown, curses, the portals…) in en
  and es, for the Codex.
- **Gate:** the owner approves the lines, then they go into `locale/strings.csv` and the Codex.

### P1. The elegance worksheet (lead, with the owner)
- The lead prepares a table of every system with two scores (experience 1–5, learning cost 1–5) and a one-line
  reason, and the owner and lead go through it together. Cuts or merges become their own steps.

### Perf wave 2: fights with many enemies (owner, 2026-11-02)
From [`evidence/PERF_PLAYLOG_2.md`](evidence/PERF_PLAYLOG_2.md). The owner: "the opening cards or shop dont bother me
actually what feels worse is fights with a lot of enemies". Their answers to the lead's ten options:

| # | Option | Owner | Step |
|---|---|---|---|
| 1 | Enemies in fewer pieces | "instead of making a so detailed shadow add something the shape of it that doesnt have that many parts, just 1 but shaped like it" | PA: each enemy's parts cast no shadow; one shadow-only mesh shaped like it casts it |
| 2 | Blob shadows | "let's try sure" | PA: a blob option beside the shape proxy, shots of both |
| 3 | Particles without shadows | "yes particles should not draw shadows" | PB |
| 4 | Fewer torch shadows | "go for it" | PB |
| 5 | Warmup pools out of the scene | "let's try it" | PC |
| 6 | Crowds animated at half rate | "no" | — |
| 7 | Interpolation only near the hero and camera | "let's try it" | PA |
| 8 | Cheaper sun shadows | "let's try before and after" | PB: shots before/after for the owner to pick |
| 9 | Enemy thinking spread over more ticks | "let's do it" | PD: changes play; goldens change on purpose |
| 10 | Merged walls | "would it look different?" | answered, not built |

### Wave 3: the v0.10.5 playtest (owner, 2026-11-04)
The owner played the v0.10.5 build and sent a consolidated feedback list (hub, VFX and performance, attack forms,
progression, bosses, shop). It lands here, not in a new version: v0.10.5 is not released yet, and its one release PR
carries it. **How work runs (owner, 2026-11-04):** "max at the same time 2 sonnet sub agents 2 opus subagents, sonnet
should be for lighter tasks easy direct fixes and very specific specs … opus can handle more heavy tasks." Replaces
the 3 + 1 rule above for this wave.

| # | Owner line (close) | Decision | Step |
|---|---|---|---|
| F1 | Black gaps between the hub's inner circular floor and the walls; gaps between wall pieces | Direct fix: close both | W3-O5 |
| F2 | "The hub currently lacks a proper background" | Asked: a sky from the packs, or a dark void + fog. Owner, 2026-11-04: **"Dark void + fog"** | W3-O5 |
| F3 | Pressing L2 still doesn't open the secret room after finding it (thought fixed) | Bug: reproduce through the owner's path, fix. First cause found (a pad's old stick aim sticks) rejected by the owner: "I shot at the wall, actually seeing the blast hit it and it did not break or open"; the aim change is not merged. **No hint** (owner: "the idea is that it is hidden and unclear, so the player should not know how to open it in the beginning") | W3-O1 |
| F4 | Fireballs look and feel excellent | Kept; the reference look for other bolts | — |
| F5 | Ground fire pools (Fire + Bleed) too large, bright, frequent; hide enemies | Direct fix: smaller, dimmer, fewer at once | W3-S4 |
| F6 | The purple enemy bolts are underwhelming next to the fireballs | VFX pass from the `newVFX/` packs, G2 shots | W3-O7 |
| F7 | Some animations and attacks far less polished than others | Folded into W3-O7 / W3-O8 | — |
| F8 | Chain Blast explosions too big for their damage; 5–6 a second with Seekers/Split hide the fight | Direct fix: the blast's look scales with the hit's damage (big for slow heavy shots) | W3-S4 |
| F9 | The boss red border seems to drop the frame rate | Perf: measure, then a cheaper border | W3-O6 |
| F10 | Attack particles linger for seconds after impact; ~0.2 s | Direct fix: impact particles gone within ~0.2 s | W3-S4 |
| F11 | Void: visual bugs with Split and Mine; S-tier on purpose | Bug: fix the look only, power kept | W3-O8 |
| F12 | Wave: barely visible attacking forward/up (mostly the ground circle shows) | VFX fix | W3-O8 |
| F13 | Seekers slightly weak, "only a small buff" | +11 % (share 450 → 500 ‰), a starting value | W3-S2 |
| F14 | Laser doesn't feel powerful or impactful | +15 % damage (a starting value) now; its impact look in W3-O8 | W3-S2, W3-O8 |
| F15 | Glaive feels excellent but lacks damage without elements | +15 % damage (a starting value) | W3-S2 |
| F16 | The Lance's ball looks generic; the packs have better | VFX from `newVFX/`, G2 shots | W3-O7 |
| F17 | Holding the Lance charge can overheat without firing | Bug fix | W3-O3 |
| F18 | Forms don't always feel like an upgrade over the default; front-loaded power (Wave + Fire + Venom strong by floor 2), a plateau later, a few cards dominate, elements too strong; ideas (not solutions): more scaling, misc cards, Attack Speed back | **G1 first:** a measured progression audit with proposals, no code until the owner picks | W3-O4 |
| F19 | Foundry: floor hazard lines overlap incoming projectiles, practically undodgeable | Fix: a hazard line and a volley never close the same space at once | W3-O2 |
| F20 | Hive Lens: the rotating laser can start facing away; arbitrary, not threatening | Fix: it starts near the hero and sweeps through them | W3-O2 |
| F21 | The Warlord on floor 1 practically every run | Measured fair (154 / 146 of 300). Owner, 2026-11-04: "Add a third boss", **"Share one, scaled"**, **"Brood Mother"**: she joins floor 1's pool at floor-1 strength; a run never meets her twice | W3-S1, W3-O11 |
| F22 | Boss durability feels good | Kept | — |
| F23 | The Warlord ~5 % overtuned | Its attacks' damage −5 % (a starting value; O2b already paces its HP) | W3-S1 |
| F24 | Shop: cards too big, crowded past 10, can't see cards and elements together, reroll cost unclear, no cohesive layout | Owner, 2026-11-04: "we are gonna be removing the lift curse and the sell, it should only show the heal, reroll and the 4 cards, lifting the curse and selling is too broken". Then **G2:** layout mockups of that smaller shop | W3-O9 |
| F29 | (owner, 2026-11-04, on the shop G2) "I like mock up A, in shape, but colors and how it shows still ugly, the brown background, buttons are not visible, it doesn't quite match the rune ethereal kind of theme of the game, we need to work on a UI rework … 3 new mockups that would also apply to the rest of UI elements … the brown background is not the way to go … differ in style so we have real options" | Shop layout A kept. **G2:** three far-apart UI styles (shop, HUD, pause, card pick) | W3-O13 |
| F31 | (owner, on the W3-O13 G2) "the new UIs you built are ugly … discard all these childish rounded gradient boxes … attaching some mock up UI references … the objective is to achieve something layered, structured, polished … the hp bar should be a continuous bar not split in parts, it should be like the fourth picture \"runic observatory\". make 4 new mock ups" | References in [ui_refs/](ui_refs/) (style only, not their text). Cinzel (OFL) added for titles (owner: "Cinzel"); body text stays Atkinson. **G2 round 2:** four mockups in that line | W3-O13b |
| F32 | (owner, on round 2) "Astral I like the most but the shape of the cards is odd, that pointy top is bad" | **Astral** is the UI style. Its card shape is redone (no pointed top): 3 card-shape variants in Astral to pick from, then the UI rework | W3-O13c |
| F33 | (owner, 2026-11-04) O11 bolt knockback: "Smaller push"; PD and elites: "Elites plan every 4" | Bolt push halved (0.06 → 0.03 m, crit 0.12 → 0.06); elites plan every 4 ticks, normal enemies stay at 8 | W3-S10 |
| F34 | (owner, 2026-11-04) the generated card icons (6 sheets) and 8 carved card frames (4 normal + 4 focused): "make sure to not lose the burn effect when picking one, we should modify it into a glare kind of particle effect more than a burn, but burn like with a noise texture dissolve as the one I attached" | The Astral cards use the owner's frames and icons; the pick burn becomes a noise dissolve with a glare edge and a particle burst | W3-O15 |
| F35 | (owner, 2026-11-04) "and what about the rest of the UI? it should match the new style" | The whole UI goes Astral: the HUD, then the menus, then the Build page, Codex, events and hub prompts | W3-O17, W3-O18, W3-O19 |
| F30 | (owner) "the minimap … should match where the character is looking but walking in a direction does not change it … match it to the player's direction always not just aiming" | The arrow follows the walk; standing, it keeps the last direction | W3-S8 |
| F27 | (owner, later 2026-11-04) "swap Lance name to fireball if it gonna look like a fireball" | Display names only (en + es), ids unchanged | W3-S7 |
| F28 | (owner) "i'd like to see which assets from the pack we did not use that could be used, could there be a repository of how all of the current effects look in the game for the premade pack and the already used or original from the game enemies, and effects from all abilities and enemies so I can compare" | An in-game VFX gallery (dev): every effect in use (abilities, forms, elements, enemies, bosses) and every unused pack effect, live and as labelled contact sheets | W3-O12 |
| F26 | (owner, later on 2026-11-04) "when you are close to a wall the transparency effect so you can see through has a shit ton of grain, very ugly" | The fade is alpha hash (per-pixel on/off); a smooth 0.3 alpha blend instead | W3-S5 |
| F25 | The purple portal on floor 4 of loop 1 to test; longer multi-loop runs | Owner playtest items (OWNER_TODO) | — |

Steps (S = Sonnet, O = Opus; at most 2 + 2 at once):
- **W3-S1** the Warlord: a 300-seed table of floor 1's boss draw (fix any bias in the draw, the owner's ids stay); its
  attacks' damage × 0.95.
- **W3-S2** form tuning: Seekers share 450 → 500 ‰ (per level 22 → 24); Glaive 1600 → 1840 ‰ (80 → 92); Laser beam
  800 → 920 ‰ (40 → 46).
- **W3-S4** (Opus: the effects come from the packs' scenes, an investigation) effects: impact particles ~0.2 s; ground fire pools smaller and dimmer; Chain Blast's look scaled by damage.
- **W3-O1** the secret room through L2, as the owner plays it.
- **W3-O2** Foundry lines vs volleys; the Hive Lens sweep.
- **W3-O3** the Lance charge heat; and the two stale bands found by W3-S2 (test_lance AF1 1.34×, test_gun_feel 0.70).
- **W3-O4** G1: the progression audit (measured with the bots; proposals for front-loading, the plateau, diversity).
- **W3-O5** the hub: the floor/wall and wall/wall gaps closed; a dark void with fog around it (F2).
- **W3-O6** the boss border's cost.
- **W3-O7** G2: the purple enemy bolt and the Lance ball from `newVFX/`.
- **W3-O8** Void with Split/Mine, Wave's forward look, the Laser's impact.
- **W3-O9** the shop sells only: heal, reroll and its 4 cards (the curse lift and selling removed; old saves load); then G2 mockups of the layout (reroll cost visible, cards smaller).
- **W3-S5** see-through walls blend smoothly (no alpha-hash grain).
- **W3-P (owner, 2026-11-04: "Approve the set"; loops stay a wall)** the progression build from W3_O4_PROGRESSION_G1.md: W3-P9 + W3-P6 probes first (stat cards reading × 1.00; Blade Storm on a moving boss, Ring on the Orbs), then W3-P1 + W3-P2 (front-loading), W3-P5 + W3-P7 (forms, dead pairs), W3-P3 (overlevels: the way through the loops), then the audit re-run.
- **W3-S6** the Lance ball is look A (owner). **W3-S7** the Lance is named Fireball (en, es).
- **W3-S8** the minimap arrow follows the walk (F30). Agents from now: at most 2 Sonnet + 3 Opus (owner, 2026-11-04: "let's elevate max opus agents to 3").
- **W3-O13** G2: three UI styles for the whole UI (F29); the shop then rebuilt in layout A with the picked style.
- **W3-O12** the VFX gallery (F28): a dev scene that plays every effect in the game and every unused pack effect, grouped and labelled, plus contact sheets.
- **W3-O17** the in-run HUD in Astral (continuous HP bar with a medallion). **W3-O18** the menus (main, pause, options, recap, loading, credits). **W3-O19** the Build page, Codex, event panels, hub prompts and the remaining panels. **W3-S13** the owner's 8 carved card backs (4 + 4 focused) on every face-down card. Owner, 2026-11-04 night: "remake every single UI element into this new style even the main menu, all UI style components have to be remade": W3-O20 audits every Control-based screen and component left after O17–O19 and restyles it; the dev panel is the only exception (dev only).
- **W3-O11** the Brood Mother joins floor 1's pool (Gatekeeper, Warlord, Brood Mother) at floor-1 strength; floor 2 never draws a boss the run already met; old saves keep their bosses.

- **W3-P10 (owner, 2026-11-05, W7: "A + B + C but don't get crazy with visuals for explosions")** loop power: overflow past the caps (A), stackable loop-only Starbound cards (B: Arc Jump, Rising Edge, Echo Cast, Fervour, Detonation, with plain explosions), and one Constellation pick a loop (C). G1 first: [`W3_W7_LOOP_POWER_G1.md`](W3_W7_LOOP_POWER_G1.md), approved row by row before any code.
  Approved 2026-11-05 (the G1's Q1–Q5). Six agents (owner: "go with the same 6 agents structur 3 sonnet 3 opus"):
  W3-P10a overflow (A), W3-P10b Starbound cards (B), W3-P10c the Constellation pick + Prism, Twin Star, Glass Sky,
  Hunter's Sky, W3-P10d Deep Wounds, W3-P10e Starfall + Meteor, W3-P10f strings, Codex and the icon prompt row.
  **Old saves** (owner, 2026-11-05: "older saves don't matter we are in development phase nobody will play old
  saves"): new run data needs no migration for saves made before it; a new field is listed where the snapshot asks,
  and an old-save test the change breaks may be updated rather than worked around.

- **W3-S18 (owner playtest, 2026-11-05: "homing + halo is weird because the back attacks are too short in reach and do
  the curve but do not reach the enemy, we should increase the reach of halo a bit so attacks can get to hit front
  enemies if homing is active")**: with Homing held, Halo's bolts reach far enough to turn and hit enemies in front.
  Also reported: "visual bugs with fireball default attack" (details asked). **W3-P10k:** the review's findings on the
  loop-power code (jumps/stars carry no target's bonus, one Arc Jump chain a root, Rising Edge out of the boss's HP,
  Echo Cast repeats merge under ShotCap, Exsanguinate takes Deep Wounds, repeats keep their Lance/Blade context).

- **W3-P10l (owner, 2026-11-05: "for the meteor we could use some of the new vfx premade pack"; "same with starfall,
  let's rely on those that look better")**: the meteor and Starfall's star take their look from the owner's new packs
  (`newVFX/`), plain (no shake, no flash, nothing lingering). **W3-Q7** fixed the bolt's "appears at some spots and
  flickers" (a shot drawn a tick behind on multi-tick frames, since Q5); **W3-Q8** the same lag for the hero and
  enemies. Agents: at most 3 Sonnet + 5 Opus (owner, 2026-11-05: "increase limit on opus agents +2").

- **W3-S19 (owner playtest, 2026-11-05: "wisps orbiting VFX is very bad too it also leaves like a trail of replicas of
  the attack when you move on the spot that is pretty bad … usually there are 4-5")**: find and fix the left-behind
  copies, and give the Wisps a small bright orb look (from the owner's packs).

### Perf wave 3: enemy VAT (owner, 2026-11-06)
The owner: "Can you start working on that while I play the run and then we check the logs and the increase from VAT?"
(OWNER_QUESTIONS "Enemy VAT"; the elites and bosses stay as they are). The lead's estimate before any build: +25–40 %
fps in big hordes (PERF_Q5 §3: the enemy bodies' draw calls and pose code go; the sim, telegraphs, effects and
lights stay). A starting estimate, not a measurement.

- **W3-V1 (Opus): the VAT pilot on one horde kind.** Bake that kind's current pose code (the avatar's own functions,
  run offline over a grid of its inputs: walk phase and amount, windup progress, the strike's timeline, idle) into
  textures, and draw every enemy of that kind as one MultiMesh with a shader that reads them; per-instance data carries
  what the avatar shows now (facing, flinch and knock, hit flash, biome tint, role glow, status looks, death). The
  attach points effects read (status FX, sockets) come from the bake too. A switch (dev / ViewPrefs) turns VAT on and
  off, so the old path stays until the owner signs off. Proved by: side-by-side shots of each state VAT off / on (the
  owner judges the tolerance, G2), the pose difference measured in the bake (max vertex error in metres), and
  `frame_probe` at 20 / 60 / 100 of that kind VAT off / on **on the owner's PC while it is otherwise idle**. Goldens
  don't change (presentation only, EI-07). **While the owner plays the logged run, the agent reads, designs, writes
  code and lints only: no Godot runs** (they would disturb the owner's timing).
- Then, only if the owner keeps it: the other horde kinds and the stand-alone enemies, a few per step.

### R. Release
- Version bump, patch notes en + es, What's New, ROADMAP row + History, PROGRESS final; one PR into `main` with
  v0.10.0 (the full suite runs there).

## Order
1. **Wave 1** (S1–S13), up to three Sonnet agents at a time (S1, S3, S2, then S4, S5, S6, S7, S9, S10, S12,
   S8, S11, S13), while one Opus agent works through wave 2.
2. **Drafts for the owner** (no code): O1's removal list, O2b's rule, O3, O5a/O5b, O6, O9, O10, O11, O13–O15,
   O17, O18, and the P1 worksheet.
3. **Builds without a gate:** O2a, O4, O7, O12, O16.
4. **Builds after the owner's answers,** each its own step.

## Open items (what they block)
- D28, D34, D44, D61, D64, D68, D70: still open on OWNER_TODO.
- Every gated O step blocks only its own build half.

## Verification
- Tests per step, sims and benches as evidence, goldens changed only on purpose, `scripts/ci/seams.sh` by the lead
  after merging, then the owner's playtest of v0.10.5.

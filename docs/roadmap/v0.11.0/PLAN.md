# v0.11.0 — Fights worth learning: bosses, elemental spells, hordes and the v0.10.5 feedback (plan, DRAFT 2026-11-07)

Recorded so these decisions never depend on chat context. The owner's brief is kept verbatim in
[`feedback/ZeroDepth_v0.11_Feedback_and_Design_Brief.md`](feedback/ZeroDepth_v0.11_Feedback_and_Design_Brief.md).
Questions for the owner: [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md). Progress: `PROGRESS.md` (opened with the first
build step).

## Context
- **Base:** `origin/main` at `0cb5a079` (PR riusprime/zero-depth#10 merged: v0.9.5 + v0.10.0 + v0.10.5). Branch
  `claude/v0110`.
- **The playtest rule (ROADMAP §0.3) is met:** the brief is the owner's feedback from playing v0.10.5.
- **Phase 0:** five read-only audits traced every brief line to the live code (2026-11-07). Their findings are folded
  into the table and the steps below, with `file:line`.
- **How work runs (owner, 2026-11-07):** "You can use up to 5 simultaneous subagents, 3 sonnet 2 opus, the sonnet
  agents should only handle light tasks, very well specified and with clear instructions so they don't think much".
  Each step names its agent: **S** = Sonnet (a precise brief, no design), **O** = Opus (design, or several systems).
  At most 3 S and 2 O at once. Each works in its own worktree cut from the lead's SHA, removed after the merge.
- **Gates:** the brief says it "is not an implementation plan", and most of it is marked open for discussion. So every
  step except the direct fixes (Wave 1) waits for the owner's answers in [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md) or
  a G1/G2 gate. **Nothing in Waves 2–4 is built before those answers.**

## Every owner line → where it lands

| # | Owner line (brief §) | Phase 0 finding | Decision | Step |
|---|---|---|---|---|
| B1 | §1 "Twin, Void, and multiple Void instances created by Split still have occasional visual bugs … Some Void instances appear to teleport or jump" | A sim bug, not the view. The 10-void cap (`attack_slots.tres:94`) culls the **oldest** void mid-flight through `on_projectile_end` (`void_mods.gd:596-610`), so its Split minis still spawn 3 m away and 1.5× larger. They push the count over again, and the next void is culled. Earlier fixes (W3-O8 `40faf0d8`) were view-only. Also: Twin's Mine stop point ignores the lane offset (`void_mods.gd:361`) | Direct fix: a cap end is quiet (no follow-ups), minis are culled before main voids, pending spawns count toward the cap; the Mine point uses the lane | S1 |
| B2 | §1 "The Lantern boss's darkness effect used to conceal its attacks … now visible" | The dark is a multiply quad at render priority −20 (`shade_views.gd:238`) that by design leaves telegraphs bright (NB4). The wisps were the attacks meant to hide. `63ca49d6` (v0.10.0 VX4) turned the wisp into a transparent pack scene drawn after the dark | Direct fix: the wisp is hidden in the dark again (outside lights; the 4 m outline stays). Whether telegraphs hide too: **Q2** | S2 |
| B3 | §1, §3 Siege Machine: "Smoke obscures the second pattern … happens too quickly" | Mortar Grid: volley 2 shows only for its 0.6 s lock and strikes 1.0 s after volley 1, with nothing shown for 0.4 s between (`boss_dodge.gd:341-351`). Phase 3: 3 volleys, later ones shown 0.3 s. Each struck cell spawns a pack explosion whose Smoke lives 0.8 s (`vfx_explosion_01.tscn:492`) and sorts over the telegraph discs at Y 0.035 m | Keep the two-pattern attack. The smoke never covers a live telegraph (no smoke on Mortar Grid bursts, or drawn under the discs); volley 2's timing: **Q3** | S3 |
| L1 | §2 Laser: "a charged-feeling, lance-style attack … approximately every 2–3 seconds … doesn't need a release of the trigger … a 3 second cooldown … needs to do the same damage it'd do in 3 seconds of continuous beam" | Today: 10 ticks a second, DPS ≈ 10 × shot damage × beam‰ (`laser.gd:131-136`). Statuses feed on 2 ticks in 3 (`laser.gd:63-73`), so 3 s of beam feeds about 20 status hits. Auto-fire on `shot_cd` already exists (`player_kit.gd:120`) | A shot every 3 s that fires while held, dealing 3 s of today's beam damage (≈ 30 × shot damage × beam‰ at Lv 1). How statuses, crit, attack speed, Rapid Fire and the other cards convert: **Q4–Q7** | O1 |
| L2 | §2 "With Homing + Pierce, a shot should connect multiple enemies through a single smooth, curved trajectory … a flowing line … not a rigid or visibly segmented chain" | Homing today is a polyline of 0.75 m legs, 12° bend each, max 24 legs, re-traced every tick (`laser_mods.gd:278-328`). It misses tight chains. The view smooths it with 2 Chaikin passes (`laser_view.gd:360`). The pack beam was turned off because it drew as 7–8 straight segments | The sim plans one smooth path through the chosen targets (short legs, the bend chosen to reach each target); the view lays one curved strip through the sim's points (EI-07). The look waits for the **sketch** (§10): **Q8** | O1 |
| L3 | §3 "bosses rely too heavily on invulnerability phases … recognizable, learnable boss mechanics … closer to World of Warcraft … interact with the arena, objects, or boss behavior" | Every boss has shielded windows of 1–6 s. Worst: Tidecaller (Pull shielded ≈6 s every 8 s), Lantern Shade (unhittable ≈9 of 12 s unless lit), Prism (shielded most of the fight), Fallen (two 15 s untargetable interphases), Brood Mother (burrow 2.4 s). Best: Warlord (no immunity, a shield arc you circle), Judge (0.8 s per 10 s) | G1 [`BOSS_AUDIT.md`](BOSS_AUDIT.md): one row per boss with its windows and a proposed signature interaction. Built one boss per step after the owner's row-by-row answers | O2–O8 |
| L4 | §3 "Small contextual hints—such as a pointing arrow when something important happens" | No such hint exists | One shared hint piece (an arrow or ping at the object that matters, shown the first few times a mechanic is met), used by every reworked boss: **Q12** | O2 |
| L5 | §3 Rock boss: "two or three pillars … earthquake-like pulses and small ongoing damage … use the boss's existing cross/spike attack against those pillars … the boss would then destroy its own pillars" | The Gatekeeper's Shock Lanes: the cross tracks you 0.8 s, locks 0.55 s, strikes 24 × 1.2 m lanes (`boss_dodge.gd:18-24,110-119`). The strike tests only the player (`boss_dodge.gd:259`), and its stone pillars skip any spot a body stands on (`boss_signatures.gd:66-74`) | The Gatekeeper places 2–3 quake pillars; a Shock Lanes strike through a pillar breaks it. Details: **Q9** | O3 |
| L6 | §3 Lantern: "step onto the lights to restore illumination … less damage while dark and more when lit … light and darkness could alternate" | 4 lanterns relight when you walk within 1.2 m (`boss_shade.gd:83`); their only role is the "lit" rule for hitting the Shade (`boss_shade.gd:137-158`) | The Shade is never fully immune: it takes reduced damage in the dark and bonus damage when lit; the lanterns are the player's lever. Numbers: **Q10** | O4 |
| L7 | §3 Twin Wardens: "yellow twin … physical attacks; purple twin … magic and projectiles … phase 1 one twin is the main opponent … phase 2 roles reverse … phase 3 both fight together … attacks alternate … damage opportunities favor one twin then the other" | One HP pool (`boss_twin.gd:104-110`). Today the twins differ only in colour; the twin copies the lead's attack (`boss_twin.gd:204-213`) | Two movesets and the three-phase structure the owner described, as a starting design: **Q11** | O5 |
| L8 | §3 Siege Machine "a good foundation and should not lose what makes it interesting" | See B3 | B3's fix only; the attack stays | S3 |
| L9 | §3 Warlord "reasonably good … room for adjustments and upgrades" | No immunity; a front shield arc you circle; javelins that fly back (`warlord.tres:218-223`) | No change unless the owner picks an upgrade from the G1 row: **Q13** | BOSS_AUDIT |
| L10 | §3 "The rest of the boss roster has not yet been individually discussed … each encounter should be reviewed" | Brood Mother, Hive Lens, Foundry, Tidecaller, Clockwork Judge, and the final three (Colossus, Prism, Fallen) | Each gets a G1 row with the lead's proposal for the owner to approve, change or defer | BOSS_AUDIT, O6–O8 |
| H1 | §4 "groups of small, simple enemies that primarily follow the player and deal damage on contact … large numbers … giving area attacks and crowd-control abilities a meaningful role" | The Swarmer is the nearest thing (8 HP, packs of 8, a lunge-bite, `enemy_ai.gd:13,89`). No enemy deals pure contact damage. Crowd cap 14–50 by floor, hard max 120 (`spawn_table.gd:103`, `floor_1.tres:82-84`). v0.10.5 measured 18 fps at 60 enemies before its fix (v0.10.5 Q5) | A horde kind: contact damage, low HP, big packs, cheap to draw. What it is, how it looks, when it appears: **Q14–Q16**. A crowd performance probe gates it | O9 |
| E1 | §5 "Unlocking an element would open access to different automatic spells … approximately three spells per element … chosen and improved through the card system" | Five elements, each an item card in 2 Element slots, Lv 1–3 (`attack_slots.gd:27-31`, `card_levels.gd`). There is no "unlock an element" step. Frost Nova, Arc Field and Flame Trail were auto abilities removed in v0.10.5 O1; their enum entries and fire-patch code remain (`element_abilities.gd:6-9`, `ability_table.gd:8-19`) | A new card family: elemental spells, offered once you hold that element. How "unlocking" works: **Q17** | O10, O11 |
| E2 | §5 "up to four automatic spells … mix elements freely … always automatic and have a cooldown, 12s for example" | Nothing today is a timed auto-cast spell | 4 spell slots, separate from the wand; each spell fires on its own cooldown (12 s a starting value). HUD: **Q19** | O10 |
| E3 | §5 "Later cards could upgrade a spell's radius, duration, damage" | Card levels exist (Lv 1–5, `card_levels.gd:11`) | Taking a held spell again levels it; what each level adds: **Q18** | O11 |
| E4 | §5 the spell examples (Blizzard, Frost Nova, fireball, burning ground, sky lightning, venom orb) "examples only … the complete list is still open" | — | G1 [`SPELLS.md`](SPELLS.md): 3 spells for each element (the owner's 6 plus the lead's proposals; whether Bleed gets spells: **Q20**) | O10 |
| E5 | §5 "Introducing several automatic damage sources could make builds too powerful … enemy health/balance may also need reviewing. No numerical balance changes are proposed here" | `scripts/balance/forms_dps.gd` and the affinity bots measure form DPS | Each spell gets a damage budget as a share of the expected wand DPS; a seeded sim pass measures builds with 0–4 spells before any enemy HP change. A missed band is reported and stops for the owner | O12 |
| M1 | §6 "Some enemies still use older/generated models … the Charger-style enemy design, but not in red … still need animation, including the VIT texture animation" | All regular enemies except the Lens Drone already draw through VAT (`vat_crowd.gd:27-41`). Nine are code-made bodies (Charger, Hatchling, Needle, Warden, Arc Caster, Bomb Drone, Swarmer, Mine Layer, Sniper); four are the owner's `.glb` (Lens Drone, Mender, Shield Bearer, Splitter). OWNER_TODO §3.2 still owes Swarmer, Mine Layer and Sniper models. The Charger itself is code-made | Which enemies get new models and in what style: **Q21**. The Lens Drone joins VAT | S4, art list |
| M2 | §6 "The current regular enemy pool feels too small … More regular enemy types are needed" | 11 kinds spawn on their own; Hatchling, Splitling and Lens Drone come only from bosses or splits | G1 [`ENEMIES.md`](ENEMIES.md): new regular enemies (behaviour, role, biome). How many in v0.11: **Q22** | O13 |
| M3 | §6 "the same enemies appear across essentially all biomes … biome-specific enemy types and biome-appropriate variations … the overall enemy spawning/selection structure" | Confirmed: biomes have no enemy list; the roster unlocks by floor depth and time phase only (`spawn_director.gd:8,122`, `data/curves/floor_N.tres`). Biome order is shuffled per run (`run_state.gd:3`) | Each biome gets its own roster (a shared core plus its signature enemies and a variant or two). The structure: **Q23** | O13 |
| M4 | §6 "the new small horde enemies from §4 still need their own identity" | — | With H1 | O9 |
| R1 | §7 "The game now has room messages, but they do not currently seem connected to anything … an Easter egg or discoverable in-game connection … a little lore" | **No room message exists in the code or data.** Nearest: the collectible lore lines (`COLLECTIBLE_*_LORE`, `archive_page.gd:128`), event descriptions, the TIP hints, the Codex Lore page (v0.10.5 O18, `codex_store.gd:26-43`) | Find out what the owner saw first: **Q24**. Then brainstorm the Easter egg: **Q25** | O14 |
| P1 | §8 "Some procedurally generated rooms currently feel like random collections of placed assets … the store rooms are a positive example … especially the larger ones" | Shops: one authored composition per biome around a stall facing the door (`shop_room.gd`). Regular rooms: 3 layouts per size of generic cover clusters at fixed anchors (`room_layouts.gd:35`, `floor_generator.gd:623-640`), or themed vignettes (`room_themes.gd:95-120`). No room has a purpose or focal point | Large rooms (3x3 and up) get a **purpose**: a focal piece plus dressing that belongs to it, like the shop. G2 shots of 2–3 approaches: **Q26** | O15 |
| X1 | §9 "Which of the additional enemy-art and enemy-variety items belong in v0.11 versus later updates" | — | **Q1** (scope) | — |
| X2 | §10 "Laser sketch … to be provided" | Not attached yet | O1's look waits on it | O1 |
| X3 | (not in the brief) The v0.10.5 PLAYTEST checklist ([`../v0.10.5/PLAYTEST.md`](../v0.10.5/PLAYTEST.md)) has no answers yet | — | **Q27** | S5 |

## Steps

### Wave 1: direct fixes (now; Sonnet unless noted)

#### S1. Voids stop jumping (B1) — sim + tests
- `VoidMods.cull` ends its victims **quietly** (no Split, Echo or Ring follow-ups) and picks F_NOFOLLOW voids (minis,
  echoes) first, oldest first, before any main void.
- `_open` counts pending K_SPAWN rows toward `live_max` and drops extra minis instead of culling a flying void.
- Mine's stop point uses each lane's own offset.
- Test in `tests/unit/sim/test_void_mods.gd`: Void + Twin Lv 5 + Split Lv 4, held 6 s; no void moves more than its
  speed between ticks, no main void ends early, live voids ≤ 10, mini spawns = `mini_count` × natural ends.
- Agent: **O** (a sim seam with Echo/Ring/Mine; three files). Goldens: none expected.

#### S2. The Shade's wisps hide in the dark again (B2) — presentation only
- `shot_shade_wisp` (and the Fallen's dark interphase wisp) leaves the pack path (`PACK_SKIP`) or the dark pass covers
  the pack layer; outside a light it is hidden, inside a light and within 4 m it shows, as before VX4.
- A presentation test pins it. One shot.
- Agent: **S**.

#### S3. The Siege Engine's second pattern stays readable (B3, L8) — presentation (+ timing after Q3)
- Mortar Grid bursts spawn no pack Smoke over the board (or the smoke draws under the telegraph discs); the crater and
  flash stay.
- Volley 2's timing per **Q3** (sim data in `siege_engine.tres` / `boss_hard.gd`).
- Agent: **S**.

#### S4. The Lens Drone draws through VAT (M1) — presentation only
- Add the Lens Drone to `VatCrowd.KINDS` like the other `.glb` horde kinds. Agent: **S**.

#### S5. The v0.10.5 checklist answers recorded (X3) — docs
- From the owner's answer to Q27, close or carry each PLAYTEST row in OWNER_TODO. Agent: lead.

### Wave 2: bosses (after BOSS_AUDIT's answers; Opus)

- **O2. The hint arrow (L4)** and the boss rework toolkit: a sim "objective" marker (an entity id + a reason) the
  view points at; shown the first N meetings (Codex-tracked).
- **O3. The Gatekeeper's quake pillars (L5).**
- **O4. The Lantern Shade: light and dark (L6, + S2).**
- **O5. The Twin Wardens: two roles, three phases (L7).**
- **O6–O8.** The other bosses, in the order the owner approves their BOSS_AUDIT rows (Tidecaller and the Prism first:
  the longest immunity).
- Each boss step: sim + tests (a scripted bot beats it two ways, TEST_MATRIX), the boss's e2e, one shot.
  Goldens that pin boss fights change on purpose and are named in PROGRESS.

### Wave 3: Laser, spells, hordes (after their questions; Opus)

- **O1. The Lance-Laser (L1, L2, X2):** the per-shot sim, the smooth homing path, the card conversions, strings
  (`FORMCARD_LASER_*`, en/es), `forms_dps.gd`, the ~30 laser tests updated on purpose, the view through one curved
  strip. The look after the sketch.
- **O9. The horde kind (H1, M4):** sim kind with contact damage, VAT body, spawn rule; a crowd probe at the cap on the
  owner's PC before it ships.
- **O10. Spell slots and the first spells (E1, E2, E4):** 4 slots, the timed runner in `abilities.gd`, the offer rule
  (Q17), HUD squares (Q19).
- **O11. The full spell roster and levels (E3, E4).**
- **O12. The spell balance pass (E5):** seeded sims, evidence file, no blind retune.

### Wave 4: enemies, rooms, lore (after their gates)

- **O13. New regular enemies and biome rosters (M2, M3):** `data/biomes` gains a roster, `SpawnDirector` reads floor ×
  biome, the new kinds from ENEMIES.md. Generation property tests over 1,000 seeds.
- **Art list:** new enemy models (M1, Q21) go into OWNER_TODO §3.2 with prompts.
- **O14. Room messages and the Easter egg (R1)** after Q24–Q25.
- **O15. Rooms with a purpose (P1):** G2 shots first, then the picked approach in `floor_generator.gd` /
  `room_layouts.gd`. Generation property tests over 1,000 seeds.

### R. Release
ROADMAP §0.4: version 0.11.0, patch notes en/es, What's New, tour en/es, PLAYTEST.md, seams, then the PR's full suite.

## Open items (what they block)
- **Q1–Q27** in [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md) block Waves 2–4.
- **The Laser sketch** blocks O1's look (the sim can start after Q4–Q7).
- **G1 BOSS_AUDIT, SPELLS, ENEMIES** and **G2 rooms** are written after the first answers.

## Verification
- Per step: lint, the touched test folders and the e2e that reach the change (CLAUDE.md). The lead runs
  `scripts/ci/seams.sh` after merging; the PR runs the full suite.
- Boss reworks: each boss beatable by two scripted builds (test). Spells: the O12 sim evidence. Hordes: the crowd probe
  on the owner's PC (`NOT YET RUN` until then).
- Owner playtest of v0.11.0 (**owner**).

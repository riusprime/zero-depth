# v0.9.5 — The v0.9.0 feedback pass: harder bosses, a cleaner Gun, a calmer world (plan, owner-approved 2026-10-25)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

**Owner-approved 2026-10-25:** Q1–Q19 and the five G1s answered ("Owner decisions" below). The G2 HUD pick (HM) is the
only gate left.

## Context
- **`main`** is v0.9.0 at `d33bc82a` (PR riusprime/zero-depth#9, merged 2026-10-25).
- **Its last CI run** was 3292 tests: e2e 198, presentation 1010, rest 326, sim_a 905, sim_b 814, sim_c 39. One test
  was red, the owner's accepted `test_final_pace`, `strong blade body 2`: 146.7 < 147.8. `tests/MIN_TEST_COUNT` goes
  2676 → 3292 in this branch's first commit.
- **The playtest rule (ROADMAP §0.3) is met:** the owner played v0.9.0, and
  [`feedback/2026-10-25_v090_playtest.md`](feedback/2026-10-25_v090_playtest.md) is the feedback, as sent. Lines
  1–21 are the fixes list; G1–G11 are the Gun, combat and gameplay bullets.
- **Branch:** `claude/v095-feedback`, cut from `origin/main` at `d33bc82a`. It runs on the owner's PC.
- **How work runs (owner, 2026-10-25):** the lead thinks, designs and writes detailed prompts, and **Sonnet agents
  build, at most 2 at a time** ("you orchestrate they just take action"). This replaces v0.9.0's up-to-3.
- **Line 21 (performance) is the last step** by the owner's order: "make this performance changes the last on the plan
  so we adjust after all changes, even after the gun rework."
- **Gates:**
  - G1 [`FORM_COMBOS.md`](FORM_COMBOS.md), with Rune Explosion;
  - G1 [`ELEMENTS.md`](ELEMENTS.md);
  - G1 [`CARD_LEVELS.md`](CARD_LEVELS.md), with the Pulse Gun;
  - G1 [`BOSSES_HARD.md`](BOSSES_HARD.md);
  - G1 [`RUNIC_STONE.md`](RUNIC_STONE.md);
  - G2 the HUD (mockups, step HM);
  - design questions Q1–Q19 below.

## Every owner line → where it lands
| # | Owner line (close; verbatim in the feedback file) | Decision | Step |
|---|---|---|---|
| L1 | The credits stone becomes a locked Runic Stone that shows runes after easter eggs | **Decide:** G1 RUNIC_STONE | RS1, RS2 |
| L2 | Bosses: no stagger, HP scaled to power when the door opens (capped, varied), one hard-to-dodge spell each; Tidecaller: stronger tides, balls all fight, small crossing waves all fight | **Decide:** G1 BOSSES_HARD (H0–H2, B1–B10, T1–T4), Q2, Q3 | BH1–BH4 |
| L3 | Hollow Crown: faster phase-1 attacks; phase 2 balls more spaced and a wider hit window; phase 3 interphases (15 s of rays, balls, ground eruptions; darkness reused), 6/10 difficulty | **Decide:** G1 BOSSES_HARD (HC1–HC7) | BH5, BH6 |
| L4 | A lit square around some effects (portals, the laser tip) in some biomes | **Direct fix:** fog off on additive shaders, edge masks, soft dots on bare particle quads, lossless VFX textures | SQ |
| L5 | Models you can walk through (the arrival portal, the last boss, any other) | **Direct fix:** colliders for portals, devices, pylons, altars, chests, pedestals, rune props; the Colossus's body radius. Breakables wait on Q17 | SB |
| L6 | Refresh the list of assets without an owner 3D model | **Direct (doc):** [`../../art/requests/v0.9.5_MODEL_LIST.md`](../../art/requests/v0.9.5_MODEL_LIST.md) | AL |
| L7 | Zoom the hub in about 15 % | **Direct:** hub `VIEW_SIZE` 22.5 → 19.1 m | HZ |
| L8 | Backgrounds for the biomes (e.g. a universe in the astral one) | **Decide:** Q5 | BG |
| L9 | The gun sound needs a random pitch | **Direct:** pitch jitter ±5 % → ±12 % on every Gun firing cue | AP |
| L10 | A form card from a chest can't be refused | **Direct fix:** Esc / B on a dealt chest closes it unpaid, the card left waiting (Q18 FYI) | CD |
| L11 | Some locked doors show a red glow instead of falling bars; only two locked kinds: locked rooms (no rounds) and Overrun (waves, extra reward) | **Decide:** Q6 | DR |
| L12 | Too many altars besides the curse room | **Decide:** Q8 | AQ |
| L13 | Ability UI: HP 15 % bigger; Blink, Dash, Attack and the L2 shot as big cooldown squares on the right; the small blue trackers go (Risk of Rain style) | **G2** (mockups), Q9 | HM, HU |
| L14 | Timed-door switches spread over the map; open the door from inside | **Decide:** Q7 | TS |
| L15 | Short prompts ("Press X", with a cost only when needed), 3–5 cm under the hero, controller button sprites | **Decide:** Q10 | PR |
| L16 | An in-game mouse cursor | **Direct (lead's call, owner asked "can you create a cool one?"):** a code-drawn rune reticle in runs and a rune-tipped arrow in menus; replaceable by an owner image | MC |
| L17 | The shrine: clearer fail animation with a sound, the reward shown over it as an icon | **Direct:** see step SS | SS |
| L18 | Room difficulty stops rising after level 4 (minute 5); aim at 10 minutes a floor, too hard past 10 | **Direct fix (owner: "fix that one"):** see step DC (starting values) | DC |
| L19 | No reason to loop; the final boss too strong regardless; easier after 3 loops | **Decide:** Q11 | LP |
| L20 | Heat fills too fast, Vent is spammed, and only the Pulse Gun uses it | **Decide:** Q12 | HT |
| L21 | Performance with 10–20 enemies, multi-hit effects and particles; the Frozen Shore floor; stop drawing enemies behind walls and floors | **Direct, last:** see step PF | PF |
| G1 | More form × card combinations (Homing + Laser curves; with Pierce, through the 5 closest) | **Decide:** G1 FORM_COMBOS | FC1–FC9 |
| G2 | Scatter goes; Rune Explosion (a violet shield-like nova from the hero) | **Decide:** G1 FORM_COMBOS R0–R9 | FC0 |
| G3 | Elements: 3 levels, each with a reward; something special for two Lv 3 elements | **Decide:** G1 ELEMENTS | EE1–EE3 |
| G4 | Gravity Stitch, "double trail" and the mutations go | **Direct:** Gravity Stitch, Double Exposure and Grand Finale retired. **Decide:** Q16 (which card is "double trail") | RC |
| G5 | Wisps: damage too low next to Bomb, Lance and Void | **Decide:** Q13 | WB |
| G6 | Remove levels from cards where they make no sense (Pierce, Swirl, Homing …) | **Decide:** G1 CARD_LEVELS | CLV |
| G7 | No Pulse Gun offers once you change form; no levels on forms; damage from stat cards | **Decide:** G1 CARD_LEVELS C18, C19 | CLV |
| G8 | Remove every On End, On Finisher, On Hit and On Kill card | **Direct:** the 7 trigger cards and the 3 legendary ×2 variants retired | RC |
| G9 | Stress Mark rebuilt: an orange arc marks one side of nearby enemies; a hit from that side deals ×2 once; 8 s cooldown (like Fiora) | **Decide:** Q14 | SM |
| G10 | Dash cooldown 10 s, Blink 15 s | **Direct:** see step CB | CB |
| G11 | The sword (Blade) locked from the start, unlocked by a challenge (hard mode); its forms wait for v0.10.0 | **Decide:** Q15 | SL |

## Design questions (asked 2026-10-25)
Answer by number, e.g. "Q2 a, Q5 b with …". ← marks the lead's recommendation.

**Q1. The Runic Stone.** See [`RUNIC_STONE.md`](RUNIC_STONE.md) rows S1–S6 and R1–R10. (Where the credits go, what wakes
the stone, the hidden-cipher idea, the 10 eggs, the robe.)

**Q2. Boss HP from your power** (BOSSES_HARD H2).
- (a) Read at the door, caps ×2.5 / 3.0 / 3.5 / 4.0 / 4.5 by floor, ±8 % per boss. ← recommended: today's caps (×2/3/4)
  were tuned when stagger existed; stagger's removal (H0) already makes bosses much harder, so the caps rise only a
  little.
- (b) Keep today's caps (×2/3/4), just read at the door and add ±8 %.
- (c) Higher: ×3 / 4 / 5 / 6 / 7.

**Q3. Without stagger, when can a boss's core be stolen?**
- (a) A 3 s window at each phase change (the boss kneels 1 s). ← recommended
- (b) Only after the boss dies (the core drops; no steal mid-fight).
- (c) Remove the boss core steal.

**Q4. The harder bosses.** See [`BOSSES_HARD.md`](BOSSES_HARD.md): B1–B10, T1–T4, HC1–HC7.

**Q5. Biome backgrounds.**
- **Fact:** the camera is orthographic, so every pixel looks in the same direction. A skybox would draw as one flat
  colour, which is why there's no sky today. A background has to be real geometry under and around the floor (what
  Starfall's star field already is).
- (a) **Layered "abyss" planes**, one set per biome: 2–3 big textured planes under the floor at different depths that
  drift slowly, so they parallax when the camera moves. The owner generates the textures, one seamless 2048² image per
  layer, from prompts the lead writes:
  - Ruins: a dusty abyss with ruined columns falling away;
  - Night Rocks: mist and moonlit floating islands;
  - Red Canyon: a far lava river and embers;
  - Frozen Shore: the dark sea and an aurora reflection;
  - Starfall: a nebula, a galaxy band and star dust.

  The lead builds the layers with code stand-ins first. ← recommended: an image made for the purpose looks far better
  than a procedural shader, and the planes cost almost nothing.
- (b) Procedural shaders only: noise nebulae, lava and mist, no images. It is faster to ship but looks generic.
- (c) Starfall only for now (a nebula plane), the rest later.

**Q6. Locked rooms and Overrun** (owner: "only locked rooms, where enemies spawn, no rounds … and overrun").
- **Today** there are three sealed kinds:
  - Lockdown: 3 formations, a free altar;
  - Arena: 2–3 waves;
  - Overrun: 3–5 waves, ×1.5 enemies, ×2 shards and an altar.

  Lockdown has falling bars; Arena and Overrun draw a red or amber glowing barrier.
- (a) **Two kinds:**
  - **Locked room** (Lockdown and Arena merged): every enemy spawns in one burst, in 2 formations 1 s apart; a free
    altar when cleared.
  - **Overrun** keeps its waves and its reward.

  Both seal with the falling bars. Overrun's doorway keeps a small red rune on the floor as its warning, instead of
  the glowing frame. ← recommended
- (b) The same, but the locked room spawns all of its enemies in one formation, at once.
- (c) The same, but enemies keep trickling in until a count is killed (no visible rounds, constant pressure).

**Q7. Timed-door switches and leaving from inside.**
- **Today:** 2 switches in the room next to the door, 2.5 m from doorways, 4 m apart; 15 s to reach the door.
- (a) The 2 switches go 1–2 rooms away from the door, on different sides of the map, and the timer grows to 20 s (the
  walk from the 2nd switch still fits in 60 % of it at base speed). Inside the room a lever opens the door again for
  5 s. ← recommended
- (b) Switches 1 room away (the next room over), 15 s, the inside lever.
- (c) One switch far away (2–3 rooms), 25 s, the inside lever.

**Q8. Fewer altars.**
- **Today, per floor:**
  - free card altars: 2–3;
  - lockdown altars: 1–2;
  - the Overrun altar;
  - the shrine: 40 % of floors (Fortune, Blood or Chaos);
  - the fountain: 25 % from floor 2;
  - the curse room: 40 %.
- (a) Free card altars 2–3 → 1–2, and the locked room's altar becomes a chest. Shrine 40 % → 25 % of floors, at most
  2 a run; fountain 25 % → 15 %. ← recommended: altars become an event.
- (b) Only the shrine and fountain chances drop (shrine 20 %, fountain 15 %); card altars unchanged.
- (c) Tell me which altar you meant and I'll cut that one.

**Q9. The new ability squares** (G2 mockups follow).
- **Fact:** on a pad today, the Attack and the "shoot" binding are both the right trigger, and nothing is on L2.
- (a) The four squares bottom-right: **Attack** (RT), **Skill** (the Gun's Scatter Blast, moved to **L2 / LT**),
  **Dash** (RB), **Blink** (LB). Vent's button sits beside the heat meter, as now. ← recommended, if "L2 shot" means
  the Skill.
- (b) "L2 shot" is something else (say which); the Skill stays on Y / Q.

**Q10. Short prompts and button sprites.**
- (a) The prompt sits under the hero (about 40 px below the feet at 1080p), reads "[button] Open" or just the button.
  A cost shows only when there is one ("[X] −30 % HP", "[X] 40 ◆"). The sprites are drawn in code to match the pad
  in use, chosen from its name: Xbox-style coloured A/B/X/Y, or PlayStation ✕ ○ □ △. The keyboard shows a key cap.
  ← recommended
- (b) The same, but the owner generates a button sprite sheet (Xbox, PlayStation, keyboard) and I install it.
- (c) The button only, never a word (costs still shown).

**Q11. Ascension loops and the final boss** (owner: "a bit easier if you completed 3 loops").
- **Today:** the Hollow Crown is paced by your DPS (120 s × √(30 / dps), held to 60–180 s), so getting stronger
  barely shortens it, and loops only add Threat.
- (a) Each finished loop (up to 3) takes 12 % off the final fight's target time and 8 % off its damage: −36 % and
  −24 % at 3 loops. A "Looped ×3" mark on the run summary. ← recommended
- (b) Only after 3 loops: −30 % time and −20 % damage at once.
- (c) Loops leave the fight alone but add a reward (an extra legendary pick before the portal).

**Q12. Heat** (owner: "ease down and scaled to the players context … only the pulse gun uses it").
- **Today:** heat goes up 1.157 per projectile hit, so attack speed and multi-hit fill it fast. Bomb, Void and the
  area forms add nothing. Vent works any time you're Hot.
- (a) **Heat per second of firing, not per hit:** holding the attack fills heat at the same rate for every form
  (100 heat in about 14 s of continuous fire), whatever your attack speed or hit count. It cools 1.0 s after you stop
  at 25 per second. Vent needs ≥ 40 heat and has a 6 s cooldown. Hot and Overclock keep their bonuses. ← recommended:
  it is fair across forms and can't be spammed.
- (b) Remove heat from the Gun; it stays the Blade's resource.
- (c) Per-form heat per shot, tuned to the same fill time (more data, the same feel as (a) but harder to keep fair).

**Q13. Wisps' damage** (the DPS sheet: Wisps ×1.3 the orbs on one target and ×1.3 in a pack; Void ×4.6, Wave ×5.0,
Lance ×5.2 in a line).
- (a) Each wisp shot 40 % → 80 % of an orb, and it pierces 1. That's about ×1.9 single-target and ×3.0 in a pack.
  ← recommended
- (b) 40 % → 100 %, no pierce (×2.3 single, ×2.3 pack).
- (c) The wisps also explode on contact (they become kamikaze orbiters that respawn every 2 s).

**Q14. The new Stress Mark** (owner: "one of their sides with a small orange arc … hitting them from that side deals
for 1 attack x2 damage, and it has an 8 second cooldown, kinda like fiora").
- (a) Enemies within 6 m get a mark on one side, chosen at random from the 4 screen sides and changing each time it
  comes back. A hit landing from within 45° of that side deals ×2 once. The mark then goes for **8 s on that enemy**.
  Bosses too, with 4 marks at once on a boss. No levels. ← recommended
- (b) The same, but the 8 s cooldown is global: one mark in the world at a time, on the nearest enemy.
- (c) The same as (a), but not on bosses.

**Q15. Unlocking the sword (Blade).**
- (a) **Beat the Hollow Crown with the Gun** (the "Sword Unbound" achievement): the hard mode opens after the game
  is beaten once. ← recommended
- (b) Reach floor 5 with the Gun.
- (c) Find the sword in a secret room on floor 3 or later (a one-time pickup).

  In every case the Blade is locked for every profile, the owner's too (like the Void). The build picker shows a padlock
  with the condition.

**Q16. Which card is "double trail"?**
- (a) Threadline ("shots fired close together are linked by a cutting thread"). ← most likely
- (b) Double Exposure (a mutation, already going).
- (c) Flame Trail or Ember Trail (fire left behind).

**Q17. Breakable containers and barrels** are walk-through by design today ("they never block a path").
- (a) Solid until broken. A barrel or crate in a corridor then has to be shot first. Generation keeps them 1.5 m from
  doorways. ← recommended (the owner's "any other 3D objects").
- (b) Keep them walk-through.

**Q18. (FYI, direct fix L10)** Esc or B on a chest's dealt card closes the panel without taking it. Nothing is paid,
the chest stays with that same card, and you can come back for it. Say if you'd rather the card be lost.

**Q19. (FYI, direct fix L18) The new difficulty-over-time curve** (starting values):
- the early phases are unchanged;
- after the peak (0:30), the danger tier keeps climbing: 4 at 1:30, 5 at 2:30, 6 at 4:00, 7 at 5:30, 8 at 7:00, 9 at
  8:30, 10 at 10:00;
- then +1 every 30 s up to 20;
- each tier above 3 also adds +8 % to the room's enemy cap and −4 % to the spawn interval (at least 0.8 s);
- the HUD shows the tier as a number past 4 chevrons.

## Owner decisions (2026-10-25)
Answered in chat on 2026-10-25, one batch at a time. They win over the decision column above where the two differ.

| Q | Answer |
|---|---|
| Q1 | RUNIC_STONE approved as written (S1–S6, R1–R10) |
| Q2 | (a) Boss HP read when the door starts to open; caps ×2.5 / 3.0 / 3.5 / 4.0 / 4.5 by floor; ±8 % per boss |
| Q3 | (a) The core steal opens for 3 s at each phase change (the boss kneels 1 s) |
| Q4 | BOSSES_HARD approved as written (H0–H2, B1–B10, T1–T4, HC1–HC7) |
| Q5 | (a) Layered parallax planes under each biome; the owner generates one seamless 2048² image per layer from the lead's prompts; code stand-ins first |
| Q6 | (a) Two sealed kinds. **Locked room** (Lockdown and Arena merged): one burst in 2 formations 1 s apart, a free reward when cleared. **Overrun** keeps its waves. Falling bars on every seal; Overrun's doorway has a small red floor rune instead of the glowing frame |
| Q7 | (a) Timed-door switches 1–2 rooms from the door, on different sides; 20 s timer; a lever inside reopens the door for 5 s |
| Q8 | **The owner meant the event altars** ("the ones that usually give you 2 options and a curse comes with them they have a name, not the cursed room and not the free cards or shrines"): Unstable Core, Echo Mirror, Scrap Heap, Overclock Vent, Blood Price, Wandering Drone, Cleansing Font, Whispering Deep. Today 1–2 every floor → 30 % of floors, at most 2 a run, never the same event twice in a run. Card altars, shrines and fountains unchanged |
| Q9 | (a) Four squares bottom-right: Attack (RT), Skill (the Gun's Scatter Blast, moved from Y to **L2 / LT**), Dash (RB), Blink (LB); Vent beside the heat meter |
| Q10 | (a) The prompt under the hero, the button drawn in code to match the pad in use (Xbox / PlayStation by name; a key cap on keyboard); a cost only when there is one |
| Q11 | (a) Each finished loop (up to 3): final fight target time −12 %, its damage −8 %; "Looped ×3" mark on the run summary |
| Q12 | (a) Heat per second of firing, the same for every form (~14 s to full); cools 1.0 s after you stop at 25/s; Vent needs ≥ 40 heat, 6 s cooldown |
| Q13 | (a) Wisp shots 40 % → 80 % of an orb, pierce 1 |
| Q14 | (a) Stress Mark per enemy within 6 m, a random screen side, ×2 once from within 45°, 8 s per enemy, bosses carry 4 marks; no levels |
| Q15 | (a) The Blade locked for every profile; "Sword Unbound": beat the Hollow Crown with the Gun |
| Q16 | **"Double trail" is Double Exposure** (owner: "the card that makes a line out of your shot's trajectory and then makes damage on that line"), already removed in RC. Threadline stays |
| Q17 | (a) Breakables solid until broken; kept 1.5 m from doorways |
| Q18 | FYI, built as written (CD) |
| Q19 | FYI, built as written (DC) |
| G1 | ELEMENTS, CARD_LEVELS (C19: the Pulse Gun leaves the offers) and FORM_COMBOS (all forms, every row) approved as written |

## Steps
Every step is one commit, `v0.9.5 Step <ID>: <player-facing outcome>`. At most 2 agents at a time. Each step is
tested as CLAUDE.md "Testing before a push" says.

### 0. Setup
- Branch `claude/v095-feedback` from `origin/main` at `d33bc82a`; `MIN_TEST_COUNT` 3292; the feedback file, this PLAN,
  PROGRESS and the five G1 docs.

### Wave A: direct fixes (building now)
- **AP: the gun sounds vary** (data). Pitch jitter 0.05 → 0.12 on `bolt_fire`, `bomb_throw`, `void_hum`, `wave_fire`,
  `skill_scatter_blast`, `glaive_throw`, `seekers_fire`, `lance_release`, `wisp_fire` (lead).
- **HZ: the hub camera 15 % closer** (presentation). `HubView.VIEW_SIZE` 22.5 → 19.1 (lead).
- **AL: the model list refreshed** (doc, lead).
- **SQ: no lit squares** (presentation, agent):
  - `fog_disabled` on every additive shader;
  - edge masks on the procedural billboards (the laser tip);
  - soft dots on the bare particle quads;
  - VFX textures lossless.
- **SB: solid bodies** (sim + tests, agent): portals and devices; pylons; reward altars, chests, pedestals and rune
  props; the Colossus's and other bosses' body radii.

### Wave B: direct fixes (next)
- **CD: refuse a chest's card** (sim + tests): `Rewards.choose` treats `PICK_CANCEL` on a dealt chest as leave,
  unpaid.
- **CB: dash 10 s, blink 15 s** (data + tests): `runner.tres` dash 1.4 → 10.0 s; Blink's `level_cooldown` (2.5, 2.3,
  2.1, 1.9, 1.7) → (15, 14, 13, 12, 11). The `modifier_equivalence` digests move on purpose.
- **RC: retired cards** (data + migration):
  - Gravity Stitch, Double Exposure, Grand Finale;
  - On Hit, On Kill, On End, On Finisher, their ×2 variants and the On Crit mapping;
  - old saves drop them.
- **SS: the shrine says what happened** (presentation + a cue): a fail cracks the shrine's core, which gutters red with
  a dedicated fail sound; a win floats the won stat's icon over the shrine for 2 s, with a chime.
- **DC: difficulty keeps rising to minute 10** (data + sim + HUD): the Q19 curve.
- **MC: the mouse cursor** (presentation): a code-drawn rune reticle in runs, an arrow in menus, the hardware cursor
  API (no per-frame cost).
  - **Owner, 2026-10-26, on MC's first cursor:** "the cursor you made is not valid, use this image as reference, ignore
    the position for click moving we dont use that". The reference is
    [`../../art/reference/v0.9.5_cursor_sheet.png`](../../art/reference/v0.9.5_cursor_sheet.png): a faceted silver
    arrowhead with a red crystal; states Default, Hover, Click, Disabled, Aim/Target, Interact, Invalid (Move Target not
    used). Rebuilt in step MC2.
- **HM: the HUD mockups** (G2): three mockups of the bottom-right ability squares and the bigger HP plate,
  `scripts/shots/mock_hud.gd`, en + es, 1920×1080.

### Waves C–E: the answered features (rewritten from the owner's answers, 2026-10-25)
The two agent slots run **one Gun step and one non-Gun step** at a time, because the Gun steps share files (the wand,
offers, `attack_slots.tres`, the forms). The order inside each list is the build order.

**Wave C: the Gun** (in order; each one after the last merges)
1. **CLV:** card levels (CARD_LEVELS C1–C21), the Pulse Gun out of offers (C19), forms without levels. After RC.
2. **FC0:** Rune Explosion replaces Scatter (R0, migration).
3. **HT:** heat per second of firing (Q12).
4. **WB:** Wisps 80 % with pierce 1 (Q13).
5. **SM:** the new Stress Mark (Q14).
6. **EE1–EE3:** element levels (Venom and Bleed; Fire, Lightning and Frost), then the 10 pairs.
7. **FC1–FC9:** the combinations, one form per step, in this order: Laser, Bomb, Void, Lance, Rune Explosion, Glaive,
   Seekers, Wave, Wisps.

**Wave D: the bosses** (in order)
1. **BH1:** no stagger (H0), the core window at phase changes (H1, Q3), HP read at the door with the new caps and
   ±8 % (H2, Q2), and the loop ease (LP, Q11).
2. **BH2:** B1–B5.
3. **BH3:** B6, B8–B10.
4. **BH4:** the Tidecaller (T1–T4).
5. **BH5:** the Hollow Crown, phases 1–2 (HC1–HC3).
6. **BH6:** the Hollow Crown, phase 3's interphases and movement (HC4–HC6).

**Wave E: the world** (fills the non-Gun slot between boss steps)
1. **DR:** locked rooms vs Overrun and the bars on every seal (Q6).
2. **AQ:** event altars to 30 % of floors, at most 2 a run (Q8).
3. **TS:** the timed-door switches spread, a 20 s timer, the inside lever (Q7).
4. **BK:** breakables solid until broken (Q17).
5. **PR:** short prompts under the hero with code-drawn buttons (Q10).
6. **SL:** the Blade locked, "Sword Unbound" (Q15).
7. **RS1, RS2:** the Runic Stone.
8. **HU:** the HUD, from the picked HM mockup, with the Skill on L2 (Q9).
9. **BG:** the biome background layers (code stand-ins), plus the owner's image prompts in
   `docs/art/requests/v0.9.5_BACKGROUNDS.md` (Q5).

### PF. Performance (last, owner's order)
- **Target (owner, 2026-10-26):** "i think thet my pc should run this game 144fps constant, because it doesnt have that
  good gaphics". So: a steady 144 fps on the owner's PC (i7-10700K, RTX 3060) at 1080p with the default settings,
  in the heaviest fights too: every frame under 6.9 ms, judged on the 1 % lows, not the average. Cut until it holds;
  if a cut would change the look, ask the owner first.
- No enemy is drawn behind walls or floors: the X-ray silhouette pass goes (`ActorViews.technique = &"xray"`, a
  second mesh per body piece).
- Profile a 20-enemy fight with a multi-hit, two-element build on the owner's PC: Frozen Shore and one other biome.
- Then cut what the profile shows: the Frozen Shore floor (triplanar → planar UV; SSIL off there if it shows up);
  per-hit VFX thinning; status-effect particle caps.
- Frame times are measured on the owner's PC, so they're real evidence.

### R. Release
- Version 0.9.5, patch notes en + es, What's New, the ROADMAP row and History, the README status line, CLAUDE.md
  re-checked, PROGRESS final, PLAYTEST.md, the full suite on the PR into `main`.

## Open items (what they block)
- Q1–Q17 and the five G1s block their steps (the table above).
- Q9 blocks HU, but not HM's mockups.

## Verification
- Tests per step: lint, the touched folders and their e2e.
- After merges: `seams.sh` from the merge worktree.
- Goldens move only on purpose, each named in PROGRESS.
- The full suite on the PR into `main`; then the owner's playtest of the Windows export.

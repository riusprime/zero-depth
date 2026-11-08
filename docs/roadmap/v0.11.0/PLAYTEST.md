# v0.11.0: playtest build (owner)

What was built from your v0.11 brief ([`feedback/ZeroDepth_v0.11_Feedback_and_Design_Brief.md`](feedback/ZeroDepth_v0.11_Feedback_and_Design_Brief.md))
and your answers Q1–Q30 ([`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md)). Everything is in [`PROGRESS.md`](PROGRESS.md)'s
Done table. Answers below are **OWNER ONLY**.

**Not released yet.** The version in `project.godot` is still 0.10.5 and there is no PR into `main` until you answer
§J N11 (release with O6–O8 and the Laser's look open, or wait for them).

## Get the build
- Branch `claude/v0110`: `git fetch origin && git switch claude/v0110 && git pull`, open in Godot 4.7.2, let it
  import, Play. (No CI export yet: that comes with the PR.)
- What's New in game, and the patch notes: [`../../patch-notes/v0.11.0.md`](../../patch-notes/v0.11.0.md)
  ([es](../../patch-notes/v0.11.0.es.md)).
- Fast ways in:
  - **F10** (dev panel) → Tools: Spawn boss / Next boss, Spawn enemy / Next enemy, Grant attack mod / Next mod (an
    element card or the Laser), go to an arena or Overrun door.
  - **Playground** (main menu): the Boss and Enemy tools, the Biome tab (to see each biome's enemies), the Build tab
    (the Laser, Homing, Rapid Fire, Echo, Big Shot), the DPS meter.
  - The hub's **Training Room** (south door): the terminal spawns any enemy you have met.
- To log a run for fps: `godot --path . -- --perf-log` ([`../../process/PERF_LOG.md`](../../process/PERF_LOG.md)).

## What's new (30 seconds)
Three bosses now have a mechanic to learn instead of a shield to wait out (the Gatekeeper's pillars, the Lantern
Shade's light and dark, the Twin Wardens' three phases), with a hint arrow the first two times. The Laser fires a lance
every 3 s through everything in its line. Element cards unlock 15 auto-cast spells in 4 slots. Once or twice a floor a
horde of small contact critters surges in. Every biome has its own enemy roster (10 new enemies, 5 variants, 5
critters). Large rooms are camps, stone-ring halls or quarries. The Void, Shade wisp, Siege volley and Pierce fixes.

## What to try
Tick each when you have looked.

### Fixes from your brief (§1)
- [ ] **B1** Void + Twin + Split (F10 → Grant attack mod, or Playground → Build): no void jumps or vanishes mid-flight.
- [ ] **B2, Q2** The Lantern Shade's wisps are hidden in the dark again (outside a light, beyond 4 m), and Wisp Bloom
  leaves room to dodge.
- [ ] **B3, Q3** The Siege Engine's Mortar Grid: volley 2 hidden until volley 1 lands, then 1.2 s to read it; no
  smoke over it.
- [ ] **S6** A Pierce card held with a form that doesn't use it says "Does nothing with this form" on the wand screen.

### Bosses (§3)
- [ ] **Gatekeeper (Q9)** From phase 2: three quake pillars pulsing every 3 s. Lure Shock Lanes through one: it
  shatters, the boss is stunned 2 s at ×1.5 ("STUNNED · VULNERABLE"), at most twice a phase. Phase 3's pillars rise
  in new spots (N9).
- [ ] **Lantern Shade (Q10)** Never immune: weak damage in the dark, big inside a lit pool (the bar tag and the number
  colours tell you). Lanterns stay lit 6 s; the Lights Out telegraph shield is back.
- [ ] **Twin Wardens (Q11, Q29)** P1 yellow (physical), P2 purple (magic), P3 both on a shared bar, the exposed twin
  swapping every 10 s. The resting twin takes 0 with a spark. Is it paced to 1–2 minutes?
- [ ] **Hints (Q12)** The arrow and ping the first 2 meetings; Options → Accessibility → Boss hints turns them off.
- [ ] **Animation (Q11, Q30)** The Twins, then every other boss: less stiff (wind-up dip, recoil, sway)?

### The Laser (§2)
- [ ] **Q4–Q8, Q28, L-a–L-d** A lance every 3 s while held, through every enemy, 15 % less per enemy after the first;
  full speed while held. With Homing: one smooth curve through up to 8 targets (with Twin each ray takes its own; on one enemy the rays bow out and meet), then on to the wall. Rapid Fire, Echo,
  Big Shot. No Pierce or Mine cards offered with it.
- [ ] Its look is a minimal stand-in until your sketch (open item below).

### Elemental spells (§5)
- [ ] **Q17–Q20** Take an element card (F10 → Grant attack mod), then look for spell cards at altars and picks; the
  element of your Wardrobe rune shows up more. Up to 4 spells, each casting by itself; the HUD squares above the
  ability bar sweep and flash.
- [ ] Levelling a spell (take it again): does each level look different?
- [ ] **E5** Measured, not felt: 4-spell builds +55…67 % over the wand alone ([`evidence/SPELLS_DPS.md`](evidence/SPELLS_DPS.md)).
  Too strong, too weak?
- [ ] **N9** Meteor's mark (a pale swirl and a falling rock): ever mistaken for a boss telegraph? The Spitter Vine as a
  poison bubble.

### Hordes (§4)
- [ ] **Q14, Q15** Play a floor: once or twice "A horde is coming!" and 30–60 critters over 10 s, never in Overrun,
  arena, Lockdown or a boss room. One critter per biome (mite, bat, flea, crab, mote).
- [ ] **Q16, N6** Does a full surge (cap 120) stay smooth on your PC? Critters no longer flinch when hit (N9).

### Enemies and rosters (§6)
- [ ] **Q22, Q23** Each biome's own enemies (Playground → Biome, then Enemy; or a run): Wire Weaver, Scrap Hound,
  Rock Lurker, Stone Thrower, Kiln Beetle, Cinder Priest, Frost Spitter, Glacier Turtle, Star Warper, Gravity Node.
  Does each one's tell read, and its answer?
- [ ] The variants: Rubble Warden, Dim Needle, Ember Charger, Frost Charger, Split Sniper.
- [ ] **N7** The Glacier Turtle's new look (pale ice shell, amber gem): easy to see now? The Swarmer's crimson (N9).
- [ ] The Lens Drone now drawn like the other regular enemies (baked animation).

### Rooms (§8) and the Runic Stone (§7)
- [ ] **Q26, G2** Large rooms with a purpose: camp, stone-ring hall, quarry. They are rare on floor 1 (N10); floors 2–4
  show more. Do they read as places?
- [ ] **Q25** The Runic Stone in the hub: try following its lines.

## Open owner items
- **The boss brief (Q13):** the other bosses' fights (PLAN O6–O8) and the remembered Hollow Crown fight wait for it.
- **The Laser sketch (§10):** the lance's final look waits for it.
- **OWNER_QUESTIONS §J:** N1–N11 (each has a default that is built until you answer). N11 decides whether v0.11.0
  ships with the two items above open.

## Your answers (OWNER ONLY)

| Question | Answer |
|---|---|
| Fun overall? | OWNER ONLY |
| The three reworked bosses: did you know what to do, and did learning it feel good? | OWNER ONLY |
| Which fight felt longest? | OWNER ONLY |
| The Laser lance: does it feel like a charged lance? | OWNER ONLY |
| Spells: could you explain what your 4 spells were doing? Too strong, too weak? | OWNER ONLY |
| Surges: fun, too many, too few? fps on your PC during one | OWNER ONLY |
| The new enemies: did each biome feel different? | OWNER ONLY |
| Purpose rooms: do they feel like places, not random props? | OWNER ONLY |
| Anything that broke | OWNER ONLY |

## Free notes (OWNER ONLY)
OWNER ONLY

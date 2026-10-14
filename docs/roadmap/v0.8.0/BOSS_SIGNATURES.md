# G1: one signature mechanic per boss (v0.8.0 O5; status: approved by the owner 2026-10-14)

Owner, 2026-10-14: "for the new bosses, I do like the fights. That's like the direction, the right direction. But I
tried all of them, and the fight seem, feels pretty similar. We just do the orbs in spirals and the ones crossing in
line, and, and that's fine. But we should have something different, right? Something that actually stands out for
each boss."

## How it works today (live code, 2026-10-14)
- One engine for all six (v0.7.5 BF, [`../../design/BOSS_FIGHTS.md`](../../design/BOSS_FIGHTS.md)): slow fireball
  patterns (`data/bullet_patterns`, kinds RING / SPIRAL / FAN / CROSS / WALL / FLOWER / BURST), ground markers that
  track then lock 0.8 s, a shield during the signature pattern.
- **Why they feel the same:** RING is in 4 of 6 fights (Gatekeeper, Brood Mother, Hive Lens, Foundry), SPIRAL in 3
  (Brood Mother, Hive Lens, Siege Engine), CROSS in 2 (Gatekeeper, Siege Engine); `marks`, `lanes` and `slam_ring`
  repeat; all shots fly 3–5 m/s; every "signature" is another pattern behind a shield. Nothing changes *how you move*
  from one boss to the next.

## The proposal
Keep the engine and the rules (track-then-lock, slow fireballs, shielded moments, fair gaps). Give each boss **one
mechanic no other boss has**, one that changes how you play its room, and build its fight around it. Duplicated
patterns are trimmed so each fight keeps at most one plain ring or spiral. The look of each mechanic follows AV (3D
spikes, 3D orbs; v0.8.0 O7, O8).

| Row | Boss | Signature mechanic (new) | How you play it | Trimmed to make room | Alternative |
|---|---|---|---|---|---|
| **S1** | **Gatekeeper** (stone golem) | **Stone Spikes that stay.** Its Shock Lanes erupt as rows of real stone spikes (O7); the spikes then stand as **pillars for ~6 s**, walls the sim treats as walls. Its Rock Rings break on them | The arena changes every cycle: you take cover behind its own pillars from the rings, and get boxed in if you stand still | Cross Quake (the Siege Engine owns the cross) | Pillars that shatter into a small burst when it slams |
| **S2** | **Warlord** (knight) | **Shield facing + recalled javelins.** Its tower shield blocks every hit from the front (sparks); hits land from the sides and back. Its javelins stick in the floor where they land, then **all fly back to it at once** along the same lines | You circle it instead of standing in front; you dodge each javelin twice, out and back | Javelin Rain (barrage) | Only the shield facing (no recall) |
| **S3** | **Brood Mother** (spider) | **Eggs to pop.** Egg Storm eggs land and **sit for 3 s** as targets with little HP; an egg you break is gone, an egg you leave hatches Hatchlings (or bursts into its acid star in phase 3) | Choose each cycle: dodge, or turn and burst eggs before they hatch | Web Spiral's fast variant | Webs on the floor that slow you for a few seconds |
| **S4** | **Hive Lens** (eye) | **The Gaze.** A continuous beam from its eye that **sweeps round the room slowly** (a quarter turn every few seconds, reversing); you keep ahead of it while its orbs fly | You run circles round it ahead of the beam, weaving orbs as you go (the Isaac "Mom's eye" kind of fight) | Glare Ring | The eye reflects your shots back while its lens is open |
| **S5** | **Siege Engine** (cannon) | **Ricochet shells.** Its Turret Cross embers **bounce off the walls once**, so the pattern comes back at you from behind; in phase 3 its turrets' shots bounce too | You watch the walls behind you, not just the cannon; room shape matters | Turret Cross Reversing (the bounce replaces the reversal) | Overheat: after each cross its vents glow and take ×3 damage for 2 s |
| **S6** | **Foundry** (furnace) | **The floor is lava.** Molten Flood lanes leave **molten floor that burns for ~5 s** where they struck; in phase 3 the room's outer ring melts for good, so the arena shrinks | Safe ground keeps moving; late in the fight you fight close to the furnace | Furnace Waves' fast ring | Cooling vents: standing on a vent marks safe ground during the flood |

### What every row also gets
- **Its own animation set** (O6, Q4: code clips first): the mechanic's wind-up, strike and recovery, readable from
  the iso camera.
- **Starting values**, tunable in F10 (pillar time, egg HP, beam turn speed, bounces, lava time).
- **Fairness:** a pillar never spawns on you; a beam never starts on you; lava never covers every exit; a ricochet
  never comes back inside 0.5 s.

## Decisions (owner, date)
| Row | Answer | Built in |
|---|---|---|
| S1 | Yes, as proposed (owner, 2026-10-14: "boss OK") | |
| S2 | Yes, as proposed (owner, 2026-10-14: "boss OK") | |
| S3 | Yes, as proposed (owner, 2026-10-14: "boss OK") | |
| S4 | Yes, as proposed (owner, 2026-10-14: "boss OK") | |
| S5 | Yes, as proposed (owner, 2026-10-14: "boss OK") | |
| S6 | Yes, as proposed (owner, 2026-10-14: "boss OK") | |

# Boss fights and enemy shots: dodge-first (design, v0.7.5 BF; status: approved by the owner 2026-10-13, "Approve all")

Owner, 2026-10-13 (verbatim): "let's also change how boss fights are, they will have more HP, and their attacks will
be most oriented in dodging, the circles on the ground and the attacks they proyect should now follow exact position
of the player until hit, they should have at least enough time from when it is marked on the ground to get out of it,
and the shooting should shoot small balls, high cuantity, that are in dodgeable patterns with different geometrical
shapes, spirals, in different directions and more like binding of isaacs bosses, the fight should be a bit longer and
more oriented to dodge attacks, having sometimes invulnerabilities so you can't attack all the time, tdlr: slower
fights, centered around dodging spells, and make each fight different for each boss".

Owner picks (2026-10-13):
- Fight length: "About 1.5×".
- Markers: "Track, then lock 0.8 s".
- Invulnerable: "Shielded during big patterns".
- Scope: "All normal enemies, besides the turrets and snipers should change into this kind of attacks, not bullets
  going fast but slower attacks, make them look like fireballs, but different for each enemy/boss, and the ones that
  change don't have the trayectory drawn in the ground anymore, only the turrets, the melee enemies keep the red
  thingy".

## Rules for every boss
1. **Ground markers track you, then lock.** A circle, line or lane follows your exact position while it charges. It
   then locks in place and flashes for **0.8 s** before it strikes. If you move after the lock, you're out. The lock
   flash is the cue: the colour turns from a dull red outline to a bright filled flash.
2. **Shots are slow fireballs in patterns.** Small, many, slow (about 3–5 m/s against the hero's run). They come in
   shapes you read and weave through: rings with gaps, spirals, fans, crosses, flowers and walls. Each boss has its
   own fireball look (colour, size, trail) and its own patterns. Shots draw no line on the ground.
3. **Shielded during the big pattern.** While a boss fires its signature pattern it is shielded: a clear crystal
   shell in the boss's colour, and your hits spark off it. Between patterns it opens up, and that's when you hit. The
   existing phase gates (66 % and 33 %) stay.
4. **About 1.5× longer.** Boss HP ×1.25 (a starting value), plus the shielded time. Each phase adds a pattern or speeds
   one up; phase 3 is the hardest mix.
5. **Fair:**
   - every pattern has a gap you can find;
   - no shot spawns on top of you;
   - fireballs never pass through walls;
   - a pattern never starts while a marker is locking on you, unless it's that boss's named combo.
6. **Readable:**
   - hostile fireballs never use the hero's attack colours;
   - their core is bright and their edge dark;
   - with Effects density on Low, trails thin out but the balls stay.

## Each boss (one fight each)

| Boss | Floor | Signature (shielded) | Other patterns | Markers that track you |
|---|---|---|---|---|
| **Gatekeeper** (stone) | 1 | **Rock Rings:** 3 slow rings of 16 ember-stones in a row, each ring's gap turning a step | ~~Cross Quake~~ (trimmed in v0.8.0 BS1) | **Fist Slam** circle (2 in phase 2, 3 in phase 3); **Shock Lanes** that track your row and column, then lock, strike as stone spikes and **leave stone pillars** (v0.8.0 BS1) |
| **Warlord** (knight) | 1 | **Shield Wall:** a wall of fireballs marching across the room with one gap (two walls crossing in phase 3) | **Javelin Fan:** 3 waves of 7, offset each wave; the javelins **stick, then fly back** (v0.8.0 BS1) | **Spear Lines** that track you, then lock; **Lunge** along a tracked lane; ~~Javelin Rain~~ (trimmed in v0.8.0 BS1) |
| **Brood Mother** (spider) | 2 | **Egg Storm:** eggs land on tracked circles and **sit 3 s as targets**: broken they are gone, left they hatch Hatchlings, in phase 3 they burst into an 8-point star of acid globs (v0.8.0 BS1) | **Web Spiral:** 2 arms of slow globs, then reversed (its fast variant trimmed in v0.8.0 BS1) | **Leap** circle; **Burrow:** a tracked eruption ring |
| **Hive Lens** (eye) | 2 | **Prism Spiral:** 3 arms of prism orbs that reverse direction halfway; the eye is closed (shielded) | **Petal Bloom:** a 5-petal flower of orbs opening out; **The Gaze:** a beam that sweeps round the room while its orbs fly (v0.8.0 BS2; ~~Glare Ring~~ trimmed) | **Focus Beam:** a line that tracks you, then locks; its Lens Drones fire small rings |
| **Siege Engine** (cannon) | 3 | **Turret Cross:** a rotating 4-arm cross of cannon embers while it braces (shielded); the embers **bounce off the walls once** (v0.8.0 BS2; ~~Turret Cross Reversing~~ trimmed) | **Mortar Grid:** a checkerboard of tracked circles, alternating twice | **Barrage:** 3 circles that track you in turn; **Rail** lane that tracks you; phase 3's turrets' shots bounce too |
| **Foundry** (furnace) | 3 | **Slag Fountain:** molten balls arc up and rain down in a flower around it, door shut (shielded) | **Furnace Waves:** alternating rings, the gaps shifting (its fast ring trimmed in v0.8.0 BS2) | **Molten Flood** lanes that track your row, then lock, and **stay molten for 5 s** (v0.8.0 BS2); phase 3 opens with the **meltdown**; its Bomb Drones lob small fireball X-bursts |

### v0.8.0 BS1: one signature mechanic per boss (owner O5; [`BOSS_SIGNATURES.md`](../roadmap/v0.8.0/BOSS_SIGNATURES.md), approved 2026-10-14)

Owner, 2026-10-14: "the fight seem, feels pretty similar … Something that actually stands out for each boss." Each
boss keeps the rules above and gains one mechanic no other boss has (rows S1-S3 built in v0.8.0 BS1, S4-S6 in BS2):

| Boss | Signature mechanic | How you play it | Trimmed | Starting values (F10, Bosses page) |
|---|---|---|---|---|
| **Gatekeeper** | **Stone Spikes that stay.** Its Shock Lanes strike as stone spikes, and pillars stay standing along the lanes, walls for everything (bodies, sight, its Rock Rings break on them; enemies path round them). Fair: never on a body, always a hero's width plus a margin from any wall or other pillar, so never a sealed pocket | Take cover behind its own pillars from the rings; don't get boxed in | Cross Quake (the Siege Engine owns the cross) | pillar 1.0 m, every 2.2 m, 6.0 s; cracks pulse their last 1 s and they sink |
| **Warlord** | **Shield facing + recalled javelins.** Its tower shield blocks every hit from its front 120° (sparks, no damage); sides take full damage, the back ×1.25; the shield drops while its weak point is open. Its Javelin Fan's javelins stick in the floor where they stop, then all fly back to it at once along the same lines | Circle it; dodge each javelin twice, out and back | Javelin Rain (its punish is now the Spear Lines) | front arc 120°, ×0; turn 90°/s (was 130); fan range 9 m (10 fast), recall 1.0 s after the last could land |
| **Hive Lens** | **The Gaze.** A continuous beam from its eye that sweeps round the room: it starts straight away from you (re-aimed through its windup: the eye brightens, a thin aim line shows), turns a quarter turn every few seconds and reverses, is stopped by walls (hide behind cover), burns what it touches, while its Petal Bloom orbs fly. The eye is open meanwhile: not shielded | Run round it ahead of the beam, weaving its orbs | Glare Ring | quarter turn 2.0 s, reversing every 8.0 s, 12 s long, 30 m, 0.9 m wide, a burn every 0.5 s, orbs every 3.0 s; phase 3 `gaze_fast` 1.6 s / 6.4 s / 2.6 s |
| **Siege Engine** | **Ricochet shells.** Its Turret Cross embers bounce off the walls once (reflected on the wall's face), so the cross comes back at you from behind; phase 3 opens by deploying turrets whose shots bounce once too. Fair: a shot never bounces when its way back would reach you within 0.5 s (it breaks on the wall) | Watch the walls behind you, not just the cannon; room shape matters | Turret Cross Reversing (the bounce replaces the reversal) | 1 bounce; embers' range 26 m (was 20); turrets bounce from phase 3 |
| **Foundry** | **The floor is lava.** Molten Flood lanes stay molten where they struck: standing in it burns; enemies path round it; every lane keeps fords (at the Foundry and on the way to the door) and lava that would close every way to the boss or the exit isn't laid. Phase 3 opens with a meltdown: a roar while the room's outer ring glows, then it melts for good and creeps in step by step, never closer than a minimum radius round the room's centre, a cool bridge to the door kept; the Foundry keeps to the cool ground | Safe ground keeps moving; late in the fight you fight close to the furnace | Furnace Waves' fast ring | lava 5.0 s, 6 every 0.5 s, fords 2.0 m; melt: the outer 4 m, 2 m closer every 8 s (each step glows 2 s first), never under 7 m, 8 every 0.5 s, a 2.0 m bridge |
| **Brood Mother** | **Eggs to pop.** Egg Storm eggs land and sit 3 s as targets with little HP; a broken egg is gone (a kill), an egg left hatches a Hatchling, and from phase 3 it bursts into its acid star instead | Each cycle: dodge, or turn and break eggs before they hatch | Web Spiral's fast variant (phase 3 opens with the eggs) | egg 3.0 s, 20 HP at the Hatchling's base 12 (scaled with it), at most 8 Hatchlings and eggs, bursting from phase 3 |

Deaths name the new parts: "The Warlord's javelins flew back through you." and "An egg the Brood Mother left burst
into acid over you."; BS2: "The Hive Lens's gaze swept over you.", "The Hive Lens's orbs caught you while you ran
from its gaze.", "A Siege Engine shell bounced off the wall and hit you from behind.", "A turret's shot bounced off
the wall into you.", "You stood in the lava the Foundry left behind." and "The Foundry melted the floor out from
under you." (en + es). Old saves have none of the new pieces. Numbers are starting values; the feel is OWNER ONLY.

Fireball looks:
- **Gatekeeper:** grey-orange ember stones.
- **Warlord:** red spear-tipped embers.
- **Brood Mother:** sickly green acid globs.
- **Hive Lens:** magenta-red prism orbs.
- **Siege Engine:** orange cannon embers with a smoke trail.
- **Foundry:** white-yellow molten drops.

## Normal enemies

| Enemy | Today | Changes to |
|---|---|---|
| Arc Caster | a fast bolt, shown on the ground | **3 slow blue-white plasma balls in a fan**; no ground line |
| Lens Drone | short bursts | **a ring of 6 small red orbs**; no ground line |
| Bomb Drone | lobs bombs onto a ground circle | **lobs a fireball that bursts into an X of 4 small ones**; no ground circle |
| Needle (turret) | a burst down a locked line | **unchanged** (owner: "besides the turrets") |
| Sniper | a long line, then a fast shot | **unchanged** (owner: "besides the … snipers") |
| Melee enemies (Charger, Warden, Splitter, Splitling, Shield Bearer, Swarmer, Hatchling) | red telegraphs | **unchanged**: they keep the red markings (owner: "the melee enemies keep the red thingy") |
| Mine Layer, Mender | mines, heals | unchanged |

**v0.8.0 (owner O4, Q3 "only things landing at range", 2026-10-14) supersedes the Needle, Sniper and melee rows'
ground marks:** they keep their attacks but draw nothing on the ground; their bodies show the windup (a crouch, a
glow that flashes just before the strike). Only the Arc Caster's rune and the Mine Layer's mines keep a ground mark.

## The models (same change)
- **Warlord and Hive Lens:** the owner's rigged models (41 and 23 bones, no animations). They are animated in code
  from their bones: idle sway, walk, the attack wind-ups and the shield pose for the Warlord; the eye opening and
  closing for the Hive Lens.
- **Foundry:** the owner's model is a single mesh. Its legs are cut into separate parts in code, as BossRig does for
  the other bosses, so they can step.

## Not decided here
- Numbers (speeds, counts, timings, HP) are starting values for the owner to tune in F10.
- Elites keep their current attacks.

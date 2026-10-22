# G1: the final boss (v0.8.0 O16–O17; status: approved by the owner 2026-10-14, with the changes below; flow changed 2026-10-16, O28)

Owner, 2026-10-14, verbatim:

> "I am thinking about a final boss right before choosing loop or ending, if ending is chosen then you fight the final
> boss, this would have 3 phases, with different combat in each one, I have a glb file that contain the three models
> … these would be a "plaeholder" that will be replace with actual cool animations I'll work, because I want this
> final battle to be epic"

> "So we actually have three models. One has a big stone hands and that part of the face would be like a fast moving
> pace fight. He would do melee attacks, jumps, uh, maybe reuse, but in a more badass way, the spikes that come out of
> the floor from some bosses, throw big rocks, and and you know a more fast-paced then the second phase is the one
> that he doesn't have big arms and that would be a ranged fight where you are entitled to uh, dodge like we have a lot
> of mechanics of dodging we would have rays that go in a in a cross and turn with her in the middle around the room
> so you have to move away Uh, she would have the, a lot of uh, small balls like we did with other bosses that um, that
> you have to dodge. She, she would also shoot uh, uh, quick, fast attacks that you also have to dodge. And then it has
> the third model, the small black one. That's supposed to be the nemesis of the main character, and it would be like
> a fight where he mimics some of the movements of the main character and uh, has a mix of both a melee and range
> fight."

## The models (split 2026-10-14)
The owner's Tripo file (one mesh, no skeleton, no clips) holds three figures that don't touch; the lead split it into
three models by their separate pieces, with no cut through any piece (preview rendered in Godot, sent to the owner):

| Phase | Model file | What it is | Triangles |
|---|---|---|---|
| 1 | `final_boss_colossus.glb` | the figure with the big stone/crystal fists and the halo | 12,249 |
| 2 | `final_boss_prism.glb` | the torn figure with floating red crystal shards, no big arms | 11,716 |
| 3 | `final_boss_nemesis.glb` | the small dark hooded figure, the hero's nemesis | 2,540 |

Placeholders: code-made clips over bones built in code (as the Foundry). The fists (phase 1) and the shards (phase
2) are separate pieces, so they move on their own. The owner's animated models replace them by the same names.

## Rows (the lead's proposal; numbers are starting values, tunable in F10)
| Row | What | Proposal |
|---|---|---|
| **F1** | When it happens | On the run's last floor, the Ascension portal's **End the run** no longer ends at once: it opens the way to the final boss. **Ascend** loops as today and skips it. Win → the victory recap (a new "true ending" line); die → the normal death recap. **Not yet** stays |
| **F2** | Where | Its own arena, the 4×4 room size, in a look of its own (a broken crystal throne hall over the Starfall void, red crystal light), no cover at the start, walled so nothing leaves. Walking in seals it |
| **F3** | One fight, three bodies | One boss bar split in three segments with the phase names. At each segment's end the body shatters in a burst (1.5 s, invulnerable, every shot on the floor cleared) and the next rises from the shards. Saves resume at the start of the current phase |
| **F4** | **Phase 1, the Colossus** (fast, melee) | Short fair windups (0.5 s locks, half the usual 0.8 s) and constant pressure: **fist combos** (2–3 swings that follow you, then a ground slam), **leap slams** that track you, lock and land with a shockwave ring, **spike waves**: the Gatekeeper's stone spikes, bigger, in lines that **chase you** across the room and radial bursts around it, and **boulder throws**: big rocks lobbed at a tracked circle that shatter into a small ring of shards. It moves fast between attacks. No shield phases |
| **F5** | **Phase 2, the Prism** (ranged, dodge) | She floats at the room's centre and doesn't move much. **The Cross**: four beams in a plus from her body to the walls that **turn round the room** (reversing, speeding up as her HP drops), so you keep moving round her. **Orb patterns**: dense slow rings, spirals and flowers like the other bosses, woven between the beams. **Fast shots**: quick aimed bolts with a short aim line (0.4 s) you sidestep. Her shards orbit her and are what fires. Shielded while the Cross turns at full speed |
| **F6** | **Phase 3, the Nemesis** (mimic, melee + ranged) | Your mirror. **It mimics you**: it uses your run's weapon (Blade slashes or Gun shots) and dashes when you dash; it copies your last few moves a short delay later (an echo of your path), and sometimes stands mirrored across the room from you. Mixed kit: it closes in with your weapon's combo, backs off and shoots, and **casts a few of your own wand cards** (the strongest 2–3 of your build, as its own attacks). Small and quick, lower HP than phases 1–2 but harder to pin down |
| **F7** | Length and strength | About 1.5× a floor-3 boss in total (phase 1 ~35 %, phase 2 ~40 %, phase 3 ~25 % of the HP). After an Ascension loop it scales with the loop like the other bosses (HP ×6 per loop, damage ×1.2, the ×100 cap) |
| **F8** | Names and text | Working names: **the Colossus**, **the Prism**, **the Nemesis**, as one boss called **"the Hollow Crown"** (strings, en + es; the owner names them). Codex entries, deaths named in the recap, 3 achievements (beat it; beat it without being hit in a phase; beat it after an Ascension loop) |
| **F9** | Music and sound | Uses the existing boss sounds until audio is made; a request for a final-boss track goes in the art/audio list |

## Questions the rows leave open
- **F1:** should the final boss also appear when you End the run on a later loop? The proposal says yes (scaled).
- **F6:** should the Nemesis copy your wand cards (strong, very personal) or only your weapon and dash (simpler)?

## Decisions (owner, date)
| Row | Answer | Built in |
|---|---|---|
| F1 | Approved, changed: End the run on **any loop** leads to the final boss; the fight **ends the run** (no loop after it). Owner: "Yes, the boss should have some mechanics, that make it difficult even when you are super ultra omega OP, so it'd would calculate the scaling with the players power, maybe nor the full fight, some of it can be easier if earned through loops but other phases of the fight have to be as difficult as a "fresh" player where winning does not only take power but also skill from the player. The final boss fight ends the run, you can't loop after it, it would teleport you to a new, not yet designed biome, exclusive to this fight, wih unique looking, rounded big room like a gladiator arena, but cosmic like" (2026-10-14) || FB1: End the run (any loop) leads to the final arena; Ascend unchanged; a win shows the victory recap with the true ending line; no loop after. **P2 (O28, 2026-10-16): the menu is gone; see "The flow since P2" below** |
| F2 | Changed: walking in **teleports you to a new biome exclusive to this fight**: a big **round** room like a **gladiator arena, but cosmic** (its look designed in FB; an art request for its pieces). Replaces the "throne hall in a 4×4 room" proposal (2026-10-14) || FB1: the round cosmic arena (code-made pieces; owner model hooks by the art list §7 ids) |
| F3 | Approve all (2026-10-14) || FB1: one bar in three named segments; the 1.5 s shatter (invulnerable, hostile shots cleared); the next body rises from the shards; a save at each phase start |
| F4 | Approve all (2026-10-14) || FB1: the Colossus (fist combos, tracked leap slams and their shockwave ring, chasing spike lines, radial bursts, boulders; 0.5 s locks; no shield) |
| F5 | Approve all (2026-10-14) || FB2: the Prism floats home to the arena's centre; the Cross (four beams in a plus from her body to the walls, never opening on you, turning a quarter every 2.4 s at full HP down to 1.2 s at none, reversing every 3.0 s and the other way each Cross); orb rings, spirals and flowers in her own crystal look from her six orbiting shards between the beams; fast bolts down a 0.4 s aim line from a shard; shielded through the spin-up and the spin, open in the 2.5 s window after; her shards cut from the model and orbiting, flaring as they fire ([evidence](evidence/FINAL_BOSS_2.md)) |
| F6 | "Weapon + dash + 2-3 cards (Recommended)": it uses your weapon and dash, echoes your moves and casts the strongest 2–3 cards of your wand (2026-10-14) || FB3: the Nemesis mimics you. It reads your build as it rises: your run's weapon (a Blade run: it swings your own combo steps, each its arc and reach as your wand made them, then backs off and throws crescents; a Gun run: your own shot with every card on it, at range and point-blank), your dash (it dashes 0.25 s after you, your distance and i-frames, your way; the other way when mirrored; never out of an attack), your path (it walks where you stood 0.5 s before) and a mirror stance across the arena; it casts the strongest 3 cards of your wand (by level, then rarity, then slot), each compiled alone by the wand compiler into a hostile copy (its swing, its volley, its blast; capped; never splitting, exploding or casting again) in its own violet-black looks, its name over its head and a sigil at its feet through a 1.0 s windup locked for its last 0.5 s ([evidence](evidence/FINAL_BOSS_3.md)) |
| F7 | Changed (owner pick "Phase-by-phase mix"): **Colossus** HP scales with loops like other bosses (power earned by looping shortens it); **Prism** is a skill phase: hittable only in short windows between beam rotations, and her HP is set from your measured damage per second so she always lasts about 60 s however strong you are; **Nemesis** takes its HP and damage from your own build, an even duel (2026-10-14) || FB1 partial: the Colossus scales with loops like the other bosses. FB2: the Prism is hittable only in the window after each Cross's spin; her HP is set as she rises from the damage per second the fight measured (the last 20 measured seconds, at least 5): HP = DPS × 60 s × the window share (2.5 / 8.5), clamped to 600..250,000 (her own 1,400 when under 5 s were measured), so at your measured DPS in every window she lasts about 60 s ([formula](evidence/FINAL_BOSS_2.md)). FB3: the Nemesis's HP as it rises = your max HP × 2.5 + your measured DPS × 12 s (with at least 5 of the last 20 seconds measured), clamped to 400..150,000; its hit = your weapon damage × 1.5, at least 8, at most a fifth of your max HP (never a one-shot), each attack a share of it; loops and the catch-up don't scale it (your build carries them) ([formula](evidence/FINAL_BOSS_3.md)) |
| F8 | Approve all (2026-10-14) || FB1 partial: names en + es, Codex entries, causes of death, the 3 achievements; the owner's final names still open. FB2: the Prism's death lines (the Cross, the orbs, the bolts) and her Codex line rewritten (en + es). FB3: the Nemesis's death lines (your combo, your slash thrown back, your gun, your own card) and its Codex line rewritten (en + es); the three achievements fire end to end (a win on loop 2 unlocks Crown Breaker, Untouched and Beyond the Loop: [e2e](evidence/FINAL_BOSS_3.md)); the owner's final names still open |
| F9 | Approve all (2026-10-14) || FB1 partial: the existing boss sounds (Colossus as the Gatekeeper, Prism as the Hive Lens, Nemesis as the Warlord); the track request not yet written. FB2: the Cross opens on the laser cue. FB3: the Nemesis dashes on the hero's dash cue, lower |

## The flow since P2 (owner O28, 2026-10-16)
Owner, verbatim (PLAN O28): "I could not fight the last boss, could only choose between ascension ending or looping";
then "Final boss should not be at the end the run, there was end the run but you should not chose like that, it should
be a continue flow, and you can pick a small different device than the ascension to loop we separate it into two
different actions from now on, not a menu, two different visual elements the ascension to go fight final boss or the
loop element, separated".

Built in P2 (`v080-p2`; evidence [`evidence/VOID_AND_PORTALS.md`](evidence/VOID_AND_PORTALS.md)):
- **No menu.** The Ascension choice panel (End the run / Ascend / Not yet) is gone, and so is "End the run" as a
  choice. Nothing waits on a pick on the last floor.
- **Two separate devices** open together with the loop's last boss's death, in the boss room:
  - the **Ascension portal** (the gate's place, its gold-white column; named "Ascension" over it): walking into its
    opening takes the hero on to the final arena and the final boss (any loop; F1's rule otherwise unchanged);
  - the **Loop device**, smaller (a low round pad, 0.9 m, with an upright green ring turning on it and two arrowheads
    chasing round it; named "Loop"), beside the portal on the back wall where the Deep gate stands on earlier floors
    (in front of that spot; nothing solid, so a saved floor rebuilds the same walls): stepping onto it starts the next
    loop's floor 1 with the build, as Ascend did.
- **The run ends** by beating the final boss (the victory recap, the true ending line) or by dying; a run with no final
  boss in its content is won through the portal.
- The HUD names both once open ("The Ascension portal is open: walk into its light to face the final boss." / "Or step
  onto the Loop device to start loop N with everything you carry.").
- Saves: the device taken keeps its saved number (v0.7.5's End = the portal, Ascend = the Loop device); the retired
  choice's fields stay in the snapshot, always off, so older saves load. The Codex's Ascend counter and the Ascension
  achievements count the Loop device.
- Why the owner could not reach the boss (read from the code, not reproduced): the only way to it was the panel's
  first card, "End the run", whose name says the run ends; the e2e test reached the arena through it, so the path
  worked, but it read as the end of the run.

## N2: a fight that lasts, harder dodges, The Fallen (owner O41, O42, O52, 2026-10-16)
Owner, playtest 3, verbatim (PLAN O41): "got to last boss and what shouldn't happen happened, it was one of the easiest
fights of the run because I was too OP, even if I am OP the boss should not that that quick and most spells were easy
to dodge, we have to have the really hard to dodge spells, and a pretty intense fight that each phase takes 1-2
minutes 1 minute being the most op and longer if you are not op, oneshoting (killing a phase in seconds should never
happen)". O42: "it should mimic and nerf you into what he has so the match is even and it is more difficult and makes
you less broken"; "change nemesis for The Fallen". O52: "should only be at certain times not the whole fight, so on
and off".

Built in N2 (`v080-n2`; evidence [`evidence/FINAL_BOSS_N2.md`](evidence/FINAL_BOSS_N2.md)). Supersedes F7's three
rules (the Colossus's loop scaling, the Prism's flat 60 s, the Nemesis's max HP × 2.5 + DPS × 12 s) and FB3's "a fifth
of your max HP" cap (D36):
- **One pace for every body** (`FinalPace`, `BossTable.pace`; all three bodies). Its HP is set from your measured
  damage per second (the fight's meter, the last 20 measured seconds, at least 5) so that at that rate it lasts
  **120 s × √(30 / your dps)**, never under **60 s** nor over **180 s** (× the Prism's window share). 30 dps is the
  base Blade hero's (measured: 28–29 dps on the Colossus); 4× stronger is about a minute, a quarter as strong three.
  The Prism and The Fallen rise with it (the meter holds the Colossus's seconds); the Colossus rises with its own HP
  and takes the paced HP once 5 s are measured, keeping its bar's fill. Why a square root: a stronger build is still
  quicker (owner: "longer if you are not op"), but never quick.
- **The rate cap: no body is killed in under a minute.** Each tick a paced body is in the fight (risen, not
  shattering) it can take max HP / 60 s more damage, banked up to 10 s; your hit takes at most what is banked. So
  even a build whose measured rate understates it (chains, procs, splits, a late Overclock) cannot take a body in
  under 60 s of fighting. The dev panel's Kill boss (the world's own hit) is not capped.
- **Harder-to-dodge attacks**, each with a telegraph and a dash path (sim tests):
  - the Colossus, at half HP: **leap_slam_3**, a leap whose landing throws two quake rings 0.45 s apart, 28 stones,
    two 2-stone gaps turned 90° between the rings (weave through one gap, then turn; the second ring flies in
    its recovery, `BossColossus.leap_late_waves`, and like every ring leaves out stones within 1.6 m of you, so a
    hero punishing in melee is never hit by it); **spike_chase_3**, two chasing
    spike lines 30° apart, laid every 0.15 s (was 0.2), 14 spikes long;
  - the Prism: **cross_weave**, a Cross whose orbs are six spiral arms that reverse 0.7 s in (the streams cross), its
    shards firing **prism_bolt_fan** (three fast bolts 30° apart, twice, 0.2 s apart, after the 0.4 s aim line) every
    0.8 s instead of a single bolt every 1.1 s;
  - The Fallen (its own kit): **fallen_storm**, three volleys of seven crescents 20° apart (narrow gaps) locked 0.4 s
    before the first, 0.3 s apart; **fallen_rush**, a four-swing rush that steps in and locks each swing 0.4 s before
    it lands.
- **The Fallen** (was the Nemesis; ids stay `nemesis`; en "The Fallen", es "El Caído", its death lines and Codex text
  rewritten). Its **mimic windows** (`FinalPace.window`): one every **20 s**, **7 s** long, the first 12 s after its
  rise, each warned **1.5 s** ahead. The warning: a violet ring pulses at your feet and at its feet, and the boss bar
  says "The Fallen reaches for your power…"; the window: both rings burn, a violet thread joins them, the bar says
  "The Fallen mirrors you: … (N s)". In a window it copies your build (your weapon's moves, your combo's arcs, your
  shot, your dash, your echo and mirror stances, your three strongest cards; an attack begun in the window keeps the
  copy to its end) and pulls you to its level: your damage on it × 30 / the dps its HP was set from (at least 10 %),
  your move speed at most the base. Outside a window it fights with its own kit (every non-card move whatever your
  weapon, its own storm and rush, close-in and back-off stances; no dash answer, no card).
- **Its hits by O27** (D36 superseded): outside a window each attack hits for its class's share of your max HP
  (crescents and shots 22 %: 5 hits; slashes 30 %: 4; point-blank 34 %: 3; the cards, only in a window, 50 %: 2, each
  followed by a 0.7 s punish window); in a window your build's hit (weapon × 1.5 × the card's weight) when that is
  more, at most half your max HP.
- **Saves:** the pace (`paced`, `pace_dps`, `pace_budget`) and the window copy (`copying`) are saved and hashed with
  the fight (`FinalFight`; `WorldSnapshot.ADDED_SINCE_V05`); the window itself is a function of the tick and the
  body's rise, so a save mid-window resumes mid-window. An older save loads with a fresh pace, set again from the
  meter.

## PR: the Prism's second phase is fair (owner O84, 2026-10-18)
Owner, verbatim (PLAN O84): "Second phase of Hollow Crown last boss is almost impossible the lasers on a cross should be
15% slower, the all small balls he shoots should be shooted on a predictable pattern we should have 3 different
patters with enough space to be dodged but not easy to dodge and he shouldnt have all 3 spells at the same time, we
should rotate,and never make small balls and lasers at the same time"

What the phase did before (FB2 + N2, read from the code): every attack was a Cross (`cross_ring`, `cross_spiral`,
`cross_flower`, `cross_weave`, picked at random), and each Cross ran **all three spells at once**: the four beams
turned for 5.0 s while her shards fired an orb pattern **aimed at you** every 1.6 s (1.4 s for the weave) and a fast
bolt every 1.1 s (the weave: three-bolt fans every 0.8 s), and the bolts went on through the 2.5 s window. **The three
spells** are the Cross (the lasers), the orbs (the small balls: `crown_orb`, 0.2 m crystal gems at 2.6-3.0 m/s) and
the fast bolts (`crown_bolt`, a long crystal spear at 22 m/s down a 0.4 s aim line). The lead read the bolts as the
owner's "quick, fast attacks" (O17), not as small balls, so they keep their aim line.

Built in PR (`v080-pr`; evidence [`evidence/FINAL_BOSS_PR.md`](evidence/FINAL_BOSS_PR.md)). Supersedes N2's
`cross_weave` and `prism_bolt_fan` (gone) and FB2's orbs inside the Cross:
- **The Cross turns 15 % slower.** A quarter turn every 2.824 s at full HP (was 2.4) down to 1.412 s at none (was
  1.2), reversing every 3.529 s (was 3.0): every turn takes 1 / 0.85 as long (169, 85 and 212 ticks; 0.85 to the
  tick). The 1.0 s aim lines, the 5.0 s spin, the 0.5 s burn and the 2.5 s window are unchanged.
- **One spell at a time, in a fixed rotation** (no random pick): Cross → ring → Cross → spiral → Cross → flower, again.
  The bolts fire only in each Cross's window, once the beams are out (0.3 s in, then 1.1 s later: two a window).
  Every spell waits until every shot she fired is gone, so **no orb or bolt is in the air while a beam is aimed or
  burning**, and orbs never fly with bolts. Each orb spell lasts until its last orb has left (she stays shielded).
- **Three predictable orb patterns**, each fired from her centre at a fixed angle (not at you), the same every time:
  - **Ring** (`crown_ring`): 4 rings, 0.8 s apart, of 32 orbs less 4 gaps of 2; every other ring turned 33.75°, so
    the gaps zigzag and you step left, right, left.
  - **Spiral** (`crown_spiral`): 10 solid arms turning 45°/s, reversing after 1.2 s; walk round her with the arms (or
    out with the orbs).
  - **Flower** (`crown_flower`): 4 petals of orbs (fast at the tips, slower at the edges), 4 waves 0.9 s apart, each
    turned 33.75° further: you walk round her one gap at a time.
  - The numbers, at 4 m from her (the patterns' check distance; the hero is 0.7 m wide, runs 6 m/s): every gap is a
    clear corridor of **1.92-2.07 m (2.75-2.96 hero widths)**; between the gaps the orbs stand too close to slip
    through; the ring's and the flower's next wave moves its gaps 1.10 m from the last one's, with 0.41-0.43 s to
    step (2.55-2.66 m/s, under half the run); the spiral's arms sweep 3.14 m/s at 4 m. All 3.0 m/s, 0.2 m, 13 m (to
    the wall), 22 damage.
- **One rotation is 50.0 s**; she is open 18.0 % of it (three 2.5 s windows and the 0.5 s breaths after each orb
  spell), and her paced HP is set from that share (was 29.4 %), so the phase's length at your damage stays the
  pace's. Measured (`test_final_pace`, the same four builds): the Prism took 98.5 / 73.4 / 71.1 / 81.8 s (base,
  strong, absurd gun, absurd blade), was 89.4 / 76.4 / 73.0 / 76.6 s.

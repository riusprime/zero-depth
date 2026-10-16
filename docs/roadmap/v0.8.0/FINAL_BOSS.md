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

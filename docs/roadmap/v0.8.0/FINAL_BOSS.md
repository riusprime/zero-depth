# G1: the final boss (v0.8.0 O16–O17; status: waiting for the owner, row by row)

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
| F1 | | |
| F2 | | |
| F3 | | |
| F4 | | |
| F5 | | |
| F6 | | |
| F7 | | |
| F8 | | |
| F9 | | |

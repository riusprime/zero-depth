# v0.7.5 — New Ground and the small things (plan, owner-directed 2026-10-12)

The owner, while the v0.7.0 suite ran (2026-10-12), verbatim:

> "Okay, so after IP 0.7.0 is done, you push it and merge the PR into main, and then I'll keep balancing the game
> while playing with the menu. You're gonna, after that, create a new branch. And start from there and create the new
> ground, the fourth biome, the frozen shore, and then a fifth one. That's gonna be kind of like a cosmic or universe
> feel with different stars and things like that. You get the feeling content beta so we are gonna not create a
> second character yet but you're gonna do the journal of codex cards and you're gonna work also on the local
> achievements and that's it like go for the small things that are left like you don't need my any of my
> intervention I'm pushing the 0.7.5 and let's just try to leave the the game for almost ready right like just the
> things that need my feedback are gonna be left basically the gameplay and on this fourth and five biome you know,
> what you're gonna do is you're gonna add a feature like the blue portal but a new one something that fits the word
> ascension and you're gonna add that the function of it is gonna be to end the run or you can choose to start over
> the biome so that's where we add the infinity loop where you can play and for this and the feedback you're gonna
> make maps bigger the rooms maybe we could add maybe even bigger rooms at some point and we will add up to 20 rooms
> the curse appear too often we're gonna have one every two floors and we're gonna reduce the amount of challenge
> rooms not so many we we can have like 20% less but and then the shop is also gonna be there every two runs two
> floors sorry and let's go for that so after this is pushed and merged into main I'll try that and you can work
> while sleeping in the 7.5 version with all these changes"

The owner asked for no interventions: where a line leaves a choice, the lead decides and writes the reading here
(column "Decision"); the owner corrects it at the playtest. Progress: [`PROGRESS.md`](PROGRESS.md).

## Owner lines
| # | Owner line | Decision (lead's reading where open) | Status | Step |
|---|---|---|---|---|
| N1 | "after IP 0.7.0 is done, you push it and merge the PR into main … then … create a new branch" | v0.7.0 goes into `main` through its PR once GitHub's verify is green, merged by the lead. v0.7.5 is built on a new branch cut from that `main` | Decided | — |
| N2 | "create the new ground, the fourth biome, the frozen shore" | Biome 4, **Frozen Shore**: water edges and ice props (ROADMAP's New Ground row), its own lighting mood, ground, wall dressing, an enemy tint set and hazards that fit (ice that slides, cold water edges). Built from the existing kit and code-made props first; art requests for anything the kit lacks | Decided | NB1 |
| N3 | "and then a fifth one … kind of like a cosmic or universe feel with different stars and things like that" | Biome 5, **a cosmic one** (working name "Starfall"; the name is a string, the owner may rename): a star field sky, floating rock and crystal islands over a void edge, nebula-coloured light. Same build rules as N2 | Decided | NB2 |
| N4 | "on this fourth and five biome … add a feature like the blue portal but a new one something that fits the word ascension … end the run or you can choose to start over the biome … the infinity loop" | **The Ascension portal**: a new portal after the run's last boss. Choosing it offers **End the run** (a victory, the recap) or **Ascend** (start over: a new loop of floors with your build, harder each loop: threat and the catch-up cap go up per loop; endless). Reading of "start over the biome": the loop starts again at floor 1 with new biomes drawn from all five. Biomes 4 and 5 enter the run's biome draw | Decided (lead's reading) | AP |
| N5 | "we are gonna not create a second character yet" | No second character in v0.7.5 | Decided | — |
| N6 | "you're gonna do the journal of codex cards" | **The Codex**: a journal of every card, enemy, boss and biome; an entry unlocks the first time you meet it and shows its art, text and your counts (taken, kills, deaths to). Reachable from the main menu and the pause menu. Kept in the profile, not the run | Decided | CX |
| N7 | "you're gonna work also on the local achievements" | **Local achievements**: a list in the profile (no platform API yet), a toast when one unlocks, a page in the Codex/menu. Starting set drawn from the run (clear a floor, beat each boss, win, Ascend N times, a wand of 8, a level-5 card, each biome, no-hit room…) | Decided | AC |
| N8 | "go for the small things that are left … let's just try to leave the game for almost ready … just the things that need my feedback are gonna be left basically the gameplay" | Also in v0.7.5 (ROADMAP v0.8.0/v0.9.x items that need no owner taste): onboarding (first-run hints for move, attack, dash, the wand and the Build page), the card level on pick cards and wand pips, credits and licences filled from the manifests, an accessibility pass of the options already there. Not in v0.7.5: a second character, the final audio, Steam, trailers, balance | Decided | SM |
| N9 | "you're gonna make maps bigger the rooms maybe we could add maybe even bigger rooms at some point and we will add up to 20 rooms" | Floors grow to **up to 20 rooms** (from today's count), with larger room sizes in the generator's mix, including a new extra-large room size. MG: 15-19 rooms plus the boss room (16-20; was 11-13), more weight on big footprints, new 4×3, 3×4 and the extra-large 4×4, span 11 cells; all in `data/map/floor.tres` (F10) | Done (MG) | MG |
| N10 | "the curse appear too often we're gonna have one every two floors" | Cursed chests: **at most one every two floors**. MG (lead's reading): chests roll the curse (25 %, unchanged) only on floors 1, 3, 5 … and at most once a floor (`data/event_rules`: first floor 1, every 2, per floor 1). Counted by the run's floor number, so an endless loop keeps the rhythm | Done (MG) | MG |
| N11 | "we're gonna reduce the amount of challenge rooms … like 20% less" | Challenge rooms (the sealed arenas and Overrun rooms): **20 % fewer**. MG: counted per floor; arena share 0.33 → 0.11; 3.23 → 2.42 a floor (−25 %) on the bigger floors | Done (MG) | MG |
| N12 | "the shop is also gonna be there every two … floors" | **The shop appears every two floors**. MG (lead's reading): floors 1, 3, 5 … (a 3-floor run has two), by the run's floor number (`data/shop`: first floor 1, every 2) | Done (MG) | MG |
| N13 | "I'll keep balancing the game while playing with the menu" | The owner balances v0.7.0 with the F10 dev panel; v0.7.5 doesn't retune numbers the owner is tuning. Values the owner sends ("Copy changes") are applied as data when they arrive | Decided | — |

## Steps
| Step | Scope | Rows | Status |
|---|---|---|---|
| MG | Map generation: up to 20 rooms, bigger rooms; curse, challenge-room and shop frequencies | N9–N12 | Done ([`evidence/MAPS.md`](evidence/MAPS.md)) |
| NB1 | Biome 4: Frozen Shore | N2 | |
| NB2 | Biome 5: the cosmic biome | N3 | |
| AP | The Ascension portal and the endless loop | N4 | |
| CX | The Codex | N6 | |
| AC | Local achievements | N7 | |
| SM | Small things: onboarding, card levels shown, credits and licences, accessibility pass | N8 | |

At most 3 agents at once; one full suite per wave by the lead (CLAUDE.md). The PR into `main` with a version bump and
a playtest sheet when every step is Done.

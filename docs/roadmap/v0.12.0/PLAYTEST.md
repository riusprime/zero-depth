# v0.12.0 — playtest sheet: bosses you learn

Written by the lead for the owner. The owner's answers go under "Owner answers", in their own words (`OWNER ONLY`).

## The build

Nothing is on GitHub (owner, 2026-11-14: "push it locally, i'll test all the bosses at the same time, then after
playtest we decide if they are ready for main at github"). Play from the owner's folder on branch `claude/v0120`:

```bash
bash scripts/native/build.sh all
godot --headless --path . --editor --import --quit
```

Then open the game. Every boss is reachable from the dev panel (F10); the Playground works too. A run saved before
this version is refused (the run now records which bosses it beat).

## What is new, in 30 seconds

Every reworked boss has one mechanic per phase and one signature set piece. Nothing explains them in words: arrows
(your first two runs), glows and colour only. A missed signature costs about 40 % of your health, never a kill from
full.

| Boss | What to look for |
|---|---|
| Clockwork Judge | A golden Time Wave slows your attacks; three hour orbs win the speed back, behind gear walls from phase 2; fields that slow your shots; a pale copy of you 4 s behind: the Bell throws you back onto it, under a Verdict |
| Tidecaller | One thing at a time now: a stronger Pull; the four-strip Riptide; in phase 3 the Maelstrom, with the High Tide's dry circle |
| Twin Wardens | No chain. A fast Amber whose charge bursts where it ends; Violet's Mirror Ward sends shots back; in phase 3 only Amber's charge breaks Violet's ward |
| Siege Engine | Its Target Lock leaves boulders; in phase 3 the Shockwave is only survived behind one; an ammo cart you can blow up next to it |
| Foundry | A plate only its own bombs blow off; lava that cools into slabs you stand on for Overpressure; a scald gauge by your health in phase 3 |
| Warlord | A faster, bursting charge; a War Banner (inside it both of you hit harder or faster); a javelin cage where its shield is down |
| Hive Lens | Drones feed it (it takes less damage); its own beam can cut them; the Lattice of light you open a gap in |
| The Fallen (Hollow Crown, third body) | It no longer vanishes. It casts a mechanic of a boss you killed this run. (Its card theft is built on branch `v0120-h7b` but **not in this build**: it breaks the final boss's pace rule, see "Known before you play") |

Unchanged: Gatekeeper, Brood Mother, Lantern Shade, the Colossus and the Prism.

## Questions

1. **Per boss: did you die at least once, and by the second or third try did you know why and what to do?** (the
   target: "you would have to die maybe once", not "40 tries").
2. **Per boss: was there ever too much at once to follow?** After the Tidecaller's rhythm pass, the busiest by
   measurement are The Fallen (a mechanic or a copy window about 37 s of each minute), the Warlord's phase 2 (the
   banner stands 20 s at a time) and the Hive Lens (Gaze or Lattice 25–29 s of each minute).
3. **Without any text, which mechanics did you work out by yourself, and which did you never understand?**
4. **With the Blade: which fights felt wrong?** The bots say playing the mechanics pays less with the Blade than
   with the Gun on the Tidecaller (the Maelstrom's eye), the Siege Engine, the Foundry and the Hive Lens.
5. **Which signature was the most memorable, and which would you throw out?**
6. **The Fallen: is "it turns your run against you" what phase 3 was missing?** Too little, too much, the wrong
   mechanics?

## Known before you play (the lead's notes, not results)

- **Bot targets missed, nothing retuned** (numbers in `evidence/*_BOTS.md`): Tidecaller (both weapons), Twin Wardens
  (Blade), Siege Engine (Blade), Foundry (Blade), Warlord (Gun), Hive Lens (both: ignoring its drones is faster),
  The Fallen (both: its mechanics are a small share of the fight). The bots take every ordinary attack without
  dodging, which hides part of what a mechanic costs a player.
- **The Fallen's card theft is held back** (step 7b, commit `fdfe2661`, unmerged). With it, `test_final_pace.gd`
  fails: the strong Blade build's Fallen lasts 229.4 s and 225.6 s (seeds 21, 22) against the 185 s ceiling, and
  213.3 s on the mean against the base build's 140.0 s, because the scripted hero never wins its cards back. That
  breaks the owner's rule that a stronger build is no slower on the final boss. Waiting on the owner.
- **Stand-ins:** the Judge's clock and cogs, the Siege Engine's cart and boulders, the Foundry's slab and plate, the
  Warlord's banner, The Fallen's emblems and shade, the Hive Lens's glass; borrowed sounds everywhere. Several new
  attacks reuse an old animation clip or none (OWNER_TODO §3.5, §3.7).
- **Nobody has watched any of it move.** Everything was checked by tests, bots and stills.
- **Not measured:** any boss at its floor's scaling (the bots fight unscaled bosses), frame time in the new fights.

## Owner answers

`OWNER ONLY` —

## Free notes

`OWNER ONLY` —

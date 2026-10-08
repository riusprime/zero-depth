# v0.4.0 "Run Depth" + v0.5.0 "Roads Between": playtest build (owner)

Everything since the v0.3.0 finishing build: your feedback F1–F22 (v0.3.5), the build direction (v0.4.0) and the
roads between floors (v0.5.0), played together (owner: "skip the rule, keep going to v0.5.0"). Answers below are
**OWNER ONLY**: written by the owner or pasted verbatim from the owner's message.

## Get the build
1. When the PR into `main` is merged, the **Windows** workflow runs on `main`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>. Pick the newest green run on `main`.
2. Download `game_windows_x86_64` (kept 14 days), unzip `game_windows_x86_64.zip`, run `game.exe`.
3. If it crashes: send `%APPDATA%\Godot\app_userdata\{{TITLE}}\logs\godot.log`.

## What's new
- **Controls:** Vent on its own button (F / pad B); a second attack per weapon on Skill (Q / pad Y): Blade **Lunge
  Cleave**, Gun **Scatter Blast**; dash cooldown 1.4 s. The Gun no longer has −15 % damage.
- **Builds:** four ability slots (your weapon + Bomb Lobber, Drone Buddy, Orbit Blades, Arc Field, Frost Nova,
  Flame Trail, Blink, Aegis), levels 1–5, eight ability combos at level 3+; stat cards that multiply (HP, damage,
  crit…), 50 cards per build; blink is now a card, not a starting pick.
- **Enemies:** smarter, faster bosses and enemies; 12 enemy types introduced across the three floors; a second boss
  per floor (Warlord, Hive Lens, Foundry); hordes that grow with time.
- **Difficulty:** a calm first minute, then phases, peaking about a minute before you'd reach the boss; heal orbs
  (10 % of kills, +25 % HP); floor-1 bosses easier, with a full heal on entering the boss room.
- **Floors:** a shop (buy, heal, reroll, sell, salvage abilities), 1–2 event rooms, cursed chest cards (+threat),
  an optional red-door **Overrun** room, and after floors 1–2 a choice of the normal or the violet **Deep** portal.
  After the boss you can walk back out and keep exploring before taking a portal.
- **Look and sound:** calmer HUD (your pick B), square cards (your pick B), bigger cooldown icons, a straight heat
  bar, the minimap fixed (it was mirrored), quieter sword, portal entry and arrival animations in the visor's blue.
- **Saves:** quit any time; **Continue** resumes at the entry of the last room you walked into.

## Known, measured here (not felt)
- Test bots: floor-1 deaths 25 % (target < 30 %: met); deaths by floor 3 95 % (target 30–60 %: missed, all at the
  floor-2/3 bosses, which you chose to leave as is); time to kill rises over a floor (target: falls).
- Crowd performance: ~4.7–4.8 ms per tick for 120 enemies + 200 shots (target 4 ms: missed). Your frame rate in big
  fights matters most.
- Nobody here has listened to the new sounds.

## Questions
1. The first minutes: calm enough to explore and grow? Do the phases ramp at the right speed?
2. Is the peak too easy now (it's lower than the version you found too hard)?
3. Floor-2/3 bosses: fair or too hard?
4. Heal orbs: too rare, too common, right?
5. Builds: do four abilities + stat cards give the "god" feeling by floor 3? Which abilities or combos are dull?
6. Altars: too many ability cards early (about 4 in 10 altar cards while you have a free slot)?
7. Shop, events, curses, Overrun, Deep portals: worth using? Prices?
8. Exploring after the boss: do you use it?
9. Gun vs Blade now that the Gun has full damage.
10. Frame rate in the biggest fights on your PC.
11. Saves: did Continue put you back where you expected?
12. The Charger dodge you wanted to judge yourself.
13. Still open: Echoes, Core theft, Depth descent — still wanted, and where?
14. Still open: may EI-05 list the three new sub-streams (`map:event`, `loot:event`, `ai:elite`)?

## Owner answers
OWNER ONLY

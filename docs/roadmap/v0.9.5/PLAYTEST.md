# v0.9.5: playtest build (owner)

Your v0.9.0 feedback (21 lines plus 11 Gun and gameplay bullets, verbatim in [`PLAN.md`](PLAN.md), "Every owner line")
and what was built for each. Answers below are **OWNER ONLY**.

## Get the build
- Branch `claude/v095-feedback` (v0.9.5; its PR into `main` carries this build to you):
  `git fetch origin && git switch claude/v095-feedback && git pull`, open in Godot 4.7.2, let it import, Play.
  Or the Windows export from the PR's CI artifact.
- Fastest way to any fight: **F10** → **Playground** (top bar) → **F1** (spawn any boss, any card at any level, god
  mode, the DPS meter). F10 for every number.
- What's New in game and the patch notes: [`../../patch-notes/v0.9.5.md`](../../patch-notes/v0.9.5.md).

## What to try
Your lines, in your order. Tick each when you have looked.

### Your 21 lines
- [ ] **L1** Check that the Credits are in the main menu and the hub's stone is now the Runic Stone: it sleeps at
  first, wakes after the first purple-rune room, and speaks in runes (the hub, north of the ring).
- [ ] **L2** Check that no boss can be staggered, that its HP is set when the door opens, that each has one hard
  spell, and that the Tidecaller's tides, rings and crossing waves all fight (floors 1–5 bosses; F10 Playground).
- [ ] **L3** Check the Hollow Crown: faster phase 1, more spaced balls and a wider hit window in phase 2, and the
  Fallen's 15 s interphases at 66 % and 33 % (the final fight).
- [ ] **L4** Check that no lit square shows around portals or the laser tip in the foggy biomes (every biome, a
  Laser build).
- [ ] **L5** Check that you can't walk through the arrival portal's altar, the Colossus, pylons, chests, altars,
  pedestals, rune pillars, crates, urns or barrels (floor 1 arrival, the final approach, any room).
- [ ] **L6** Check the list of models still drawn by code: [`../../art/requests/v0.9.5_MODEL_LIST.md`](../../art/requests/v0.9.5_MODEL_LIST.md).
- [ ] **L7** Check that the hub camera is about 15 % closer (the hub).
- [ ] **L8** Check the backgrounds in all five biomes (a galaxy under Starfall, a sea under the Frozen Shore).
- [ ] **L9** Check that the Gun's firing sound changes pitch shot to shot (any form).
- [ ] **L10** Check that Esc / B on a chest's dealt card closes it unpaid and the card waits (any chest).
- [ ] **L11** Check that there are only two sealed kinds: a locked room (one burst, free altar) and the Overrun
  (waves, bigger reward), and that the Overrun's doorway shows a red floor rune, not a red glow (floors 1–5).
- [ ] **L12** Check that event altars are rarer (about one floor in three, twice a run at most).
- [ ] **L13** Check the four ability squares bottom-right (Attack, Skill, Dash, Blink), the bigger HP plate and that
  the blue trackers are gone (any run).
- [ ] **L14** Check that the timed door's two switches are in different rooms, and the lever inside the secret room
  (a floor 2+ timed door).
- [ ] **L15** Check the short prompts under the hero: key cap or pad button, a verb, a cost only when there is one
  (altars, shrines, chests; try with a pad).
- [ ] **L16** Check the mouse cursor: the rune reticle in runs, the rune arrow in menus, hidden with a pad.
- [ ] **L17** Check the shrine: a failed gamble flashes, cracks and has a sound; a win shows the stat over it (a
  Fortune shrine).
- [ ] **L18** Check that danger keeps rising past minute 5 and is hard but fair around minute 10 (stay on one floor
  and watch the tier chevrons).
- [ ] **L19** Check the Hollow Crown after a loop (a run summary says "Looped x N"): is it easier, and is there a
  reason to loop? (Q11)
- [ ] **L20** Check that Gun heat fills with time spent firing, that Vent is no longer spammable (40 heat, 6 s) and
  that it works on every form (any form, the heat bar).
- [ ] **L21** Check performance with 10–20 enemies, multi-hit effects and the Frozen Shore, and that enemies
  aren't drawn behind walls (the Frozen Shore, a big Overrun). Performance numbers: **NOT YET RUN (owner
  hardware)**, see the patch notes.

### Your Gun and gameplay bullets
- [ ] **G1** Check the new card combinations on every form (Homing + Laser curves; Homing + Pierce threads the 5
  nearest) (F10 Playground, grant cards).
- [ ] **G2** Check that Scatter is gone and Rune Explosion (a violet dome from the hero) takes its place (the
  Portal Machine's form picker).
- [ ] **G3** Check the three element levels and their rewards, and the named pair when two elements reach level 3
  (the combo card with both icons).
- [ ] **G4** Check that Gravity Stitch, Double Exposure and Grand Finale are never offered.
- [ ] **G5** Check that the Wisps feel strong enough next to Bomb, Lance and Void (the Wisps form). (N7)
- [ ] **G6** Check that cards without a use for levels (Pierce, Swirl, Homing ...) show no levels (a reward screen).
- [ ] **G7** Check that the Pulse Gun is never offered once you hold a form, that form cards have no levels, and
  that damage comes from stat cards. (N4)
- [ ] **G8** Check that On Hit, On Kill, On End and On Finisher cards are gone.
- [ ] **G9** Check the new Stress Mark: an orange arc on one side, double damage from that side once, back after
  8 s (a room of enemies).
- [ ] **G10** Check that Dash recharges in 10 s and Blink in 15 s (the ability squares).
- [ ] **G11** Check that the Blade is locked at the start, shows its condition in the picker, and "Sword Unbound"
  (beat the Hollow Crown with the Gun) unlocks it (the Portal Machine).

## Questions to answer while you play
From [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md) (none block; "as built" is a fine answer):
- **N1** Are the backgrounds dim enough (about 25 % dimmer than before)?
- **N2** Is the Fortune shrine's prize glyph bright and big enough?
- **N3** Do the synthesized shrine sounds (`gamble_fail`, `gamble_win`) stay, or will you give files?
- **N4** The Pulse Gun's lost damage: nothing (a), plain Orbs' base damage 5 → 6 (b), or Damage stat cards weighted
  more while you hold no form (c)?
- **N5** Is Rune Explosion strong enough (×3.75 damage), or raise it to ×4.5?
- **N6** The Brood Mother's body: keep 1.55 m (legs clip a little) or widen to 2.09 m and retune Leap and Burrow?
- **N7** The Wisps still weak: wisp shots to 120 % (a), a small blast on hit (b), or play first (c)?
- **N8** Your Godot editor settings file was emptied when C: filled: does the editor open fine, or delete that file?
- **N9** Is the Tidecaller too much now (116 damage a minute on the bot, up from 54)?
- **N10** Did a timed door actually shut on you while you were inside, and where?
- **N11** Void + Big Shot in a pack (×7.93): shrink the pull to 3.5 m, or accept it?

## Owner answers
OWNER ONLY

## Free notes
OWNER ONLY

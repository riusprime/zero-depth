# v0.10.5: playtest build (owner)

Your v0.10.5 playtest feedback (F1–F35, verbatim in [`PLAN.md`](PLAN.md) "Wave 3") and what was built for each, plus
the loop power (W3-P10) and the performance work (perf waves 2 and 3). The PR into `main` carries v0.9.5, v0.10.0
and v0.10.5 together. Answers below are **OWNER ONLY**.

## Get the build
- Branch `claude/v0100-cleanup` (then its PR into `main`): `git fetch origin && git switch claude/v0100-cleanup &&
  git pull`, open in Godot 4.7.2, let it import, Play. Or the Windows export from the PR's CI artifact.
- Fastest way to any fight: **F10** → **Playground**; the hub's **Training Room** (south door) for a dummy and any
  enemy.
- What's New in game and the patch notes: [`../../patch-notes/v0.10.5.md`](../../patch-notes/v0.10.5.md),
  [`../../patch-notes/v0.10.0.md`](../../patch-notes/v0.10.0.md).
- To log a run for the fps audit: `godot --path . -- --perf-log` (the CSV lands in
  `%APPDATA%\Godot\app_userdata\Zero Depth\perf\`; [`../../process/PERF_LOG.md`](../../process/PERF_LOG.md)).

## What to try
Tick each when you have looked.

### Hub and world
- [ ] **F1, F2** The hub: no black gaps between the inner floor and the walls or between wall pieces; a dark void
  with fog around it.
- [ ] **F3** The secret room opens with L2 after you find it (your pad path).
- [ ] **F26** Walking near a wall: the see-through fade is smooth, not grainy.
- [ ] **F30** The minimap arrow follows where you walk; standing still, it keeps the last direction.

### Attacks and effects
- [ ] **F5, F8, F10** Fire + Bleed ground pools smaller, dimmer and fewer; Chain Blast's size follows the hit's damage;
  impact particles gone within about 0.2 s.
- [ ] **F6, F16, F27** The purple enemy bolts and the Lance's ball from the new packs; the Lance is named Fireball.
- [ ] **F11, F12, F14** Void with Split and Mine looks right; Wave reads when attacking forward/up; the Laser's impact.
- [ ] **F13, F14, F15** Seekers +11 %, Laser +15 %, Glaive +15 % (starting values): do they feel right?
- [ ] **F17** Holding the Lance charge no longer overheats without firing.
- [ ] **F33** Smaller bolt push; elites react a little faster.

### Bosses
- [ ] **F19** Foundry: a hazard line and a volley never close the same space at once.
- [ ] **F20** Hive Lens: the laser starts near you and sweeps through you.
- [ ] **F21, F23** Floor 1's pool has the Brood Mother too (at floor-1 strength); the Warlord hits 5 % softer.
- [ ] **F9** The boss red border no longer drops the frame rate.

### Progression and loops
- [ ] **F18** The progression set (attack forms feel like upgrades, later scaling, Attack Speed back).
- [ ] **W7 / W3-P10** Loops 2 and 3: Starbound cards, overflow past the caps and the rule-breaker pick. Do loops feel
  "broken builds, wow"? (A strong Gun build measured at about loop-1 power at loop 3's floor 5; the Blade against one
  target is lower, W10, left for a future version.)
- [ ] **F25** The purple portal on floor 4 of loop 1; a longer multi-loop run.

### UI (Astral)
- [ ] **F24, F29** The shop: heal, reroll and the 4 cards; the reroll cost clear.
- [ ] **F31, F32, F34, F35** Every screen in the Astral style: menus, HUD, shop, card picks, Build page, Codex, events,
  hub prompts; the card shape without the pointed top; the card icons and frames, the glare on picking a card.
- [ ] **W8** The Astral cursors (until your cursor sheet arrives).

### Performance
- [ ] Long runs: does the slowdown over a run feel smaller? (The corner minimap now draws about 51 objects instead of
  up to ~6,700 at a floor's end.)
- [ ] Hordes: regular enemies are drawn from baked animations (13 kinds; F10 → "Enemy VAT" switches it off to
  compare). Do they look and move the same? Does a big horde run smoother?
- [ ] Enemies cast their shadow on the floor again (V3).

## Your answers (OWNER ONLY)

| Question | Answer |
|---|---|
| Fun overall? | OWNER ONLY |
| Loop power: wow enough, too much, too little? | OWNER ONLY |
| The Astral UI: anything still off? | OWNER ONLY |
| fps on your PC in a long run (a `--perf-log` CSV is enough) | OWNER ONLY |
| Anything that broke | OWNER ONLY |

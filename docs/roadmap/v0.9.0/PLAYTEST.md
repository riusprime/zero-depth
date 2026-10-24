# v0.9.0: playtest build (owner)

Your two v0.8.0 documents and your answers (verbatim in [`PLAN.md`](PLAN.md), "Every owner line" and "Owner
decisions"). Answers below are **OWNER ONLY**.

## Get the build
- Branch `claude/world-combat-v090` (v0.9.0; its PR into `main` carries this build to you):
  `git fetch origin && git switch claude/world-combat-v090 && git pull`, open in Godot 4.7.2, let it import, Play.
  Or the Windows export from the PR's CI artifact.
- Fastest way to any fight: **F10** → **Playground** (top bar) → **F1** (spawn any boss, any card at any
  level, god mode, the DPS meter). F10 for every number.
- What's New in game and the patch notes: [`../../patch-notes/v0.9.0.md`](../../patch-notes/v0.9.0.md).

## What's new (30 seconds)
- **Five floors** (about 10 to 19 rooms), every biome once; +15 max HP a floor, 60 % heal between floors.
- **Four new bosses** on floors 4–5: the Tidecaller, the Twin Wardens, the Clockwork Judge, the Lantern Shade.
- **Ten Gun forms:** Orbs, Laser, Bomb, Void, Lance, Scatter, Glaive, Seekers, Wave, Wisps; wand slots (Form 1,
  Pattern 1, Secondary 2, Element 2), "Replaces" and the burn; Twin and Spread merged; no death explosions.
- **The world:** Lockdowns, elites (Breaker, Rift Hunter, Conduit) on floors 4–5, Fortune / Blood / Chaos shrines,
  healing fountains, secrets (timed doors, rune pillars, cracked walls, hidden rooms; from floor 2), the earned
  purple Deep portal, 16 collectibles.
- **The arrival:** the floor-1 altar, the oval portals, the stair causeway and pylons before the Colossus, the
  vibration instead of the shake.
- **The hub (the Rune Ring):** the small menu; the Portal Machine, Rune Archive, Wardrobe, Progression Station, Trophy
  Area, Credits Stone; Rune Fragments; robes (75–150) and the two epic robes (250); five affinities.
- **The hub editor** (`tools/hub_editor/`, in Godot only): drag the hub's pieces and save them back.

## What to try
- [ ] A full run, all five floors, to the Hollow Crown. Which floor felt longest? Did you outgrow the enemies, or fall
  behind?
- [ ] Each of the four new bosses: does its trick read, and is it fair? Too easy / right / too hard, and how long.
- [ ] Each of the ten Gun forms, alone and with a pattern: which feel good, which feel weak or broken?
- [ ] Lockdowns on floors 1–5: how long each took with your build (target 20–40 s).
- [ ] The three elites: can you read and punish each? Is the bar with its name clear?
- [ ] Shrines and fountains: did you use them, and was the price worth it?
- [ ] Secrets: did you find timed doors, rune pillars, cracked walls and hidden rooms without being told?
- [ ] The hub: the walk to the portal, the stations, the run summary and Restart.
- [ ] Rune Fragments: how many a run gave you, and whether the robe prices feel right.
- [ ] The robes, the two epic ones (The Fallen's Regalia, Divine Hollow Crown) and the affinities.
- [ ] Collectibles in runs and in the Rune Archive.
- [ ] The hub editor: move a piece, save, and check it in game.

## Questions
1. Five floors: does a run's length and its difficulty curve feel right, start to end?
2. The four new bosses and the three elites: did you always know why you took damage?
3. The ten forms: could you explain your build by floor 3? Which form would you never pick?
4. The world (Lockdowns, shrines, secrets, the Deep portal): which made a floor more fun, and which got in the way?
5. The hub and Rune Fragments: do you want to come back for the next robe or affinity?

## Open judgement calls (kept as built until you play)
From [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md):
- **Q2 Lockdown length:** 3 formations of 5, 5, 5, 6, 6 enemies; the bot with no cards clears floors 3–5 past
  40 s. Keep, or shrink floors 3–5?
- **Q4 Gun pool ceiling** raised to fit the approved forms (FYI); prune the pool instead?
- **Q10 Shrines and fountains:** Fortune 40 % / Blood 30 % / Chaos 30 %, Blood 30 % of current HP, Chaos 5–7
  enemies, fountains on a quarter of floors from floor 2, 40 % heal.
- **Q11 (b, c) Wisps** don't improve from level 1 to 5; **Twin** lowers one-target damage on narrow forms and raises
  it on wide ones: intended?
- **Q12 Biome looks** of the Wave 4 interactions (FYI): anything wrong in a biome?
- **Q13 Arenas** can hold most of a small floor's loot: keep, or one reward an arena?

Also:
- **The black robe's violet** (The Fallen's Regalia): its attack reads pink-violet, chosen to stay clear of a hostile
  trail colour. Bluer?
- **The Blood Coin gem** (collectible 10) may be too small to see.
- **`test_final_pace`** stays red on five floors as you said (strong Blade's Fallen 148.8 s vs base 146.7 s).

## Owner answers
OWNER ONLY

## Free notes
OWNER ONLY

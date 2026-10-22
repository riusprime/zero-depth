# Playground (creative mode for testing builds, bosses and biomes)

Status: **built 2026-10-13** (PG1-PG5; [evidence](../roadmap/v0.7.5/evidence/PLAYGROUND.md)), owner line N20 in [`../roadmap/v0.7.5/PLAN.md`](../roadmap/v0.7.5/PLAN.md), built on
branch `claude/playground` (cut from `claude/v0.7.5-new-ground` at `d5a5602`, after BM; before BF).

## Owner line (2026-10-13, verbatim)

> "So what I need for this game now is playtest like a playground where I have the creative mode as in Minecraft
> where I can choose whatever powers I want to test test all the builds and the thing is that I want dummies I can
> spawn and delete dummies in the position I want so I can try build have a DPS meter and I can choose to spawn the
> bosses that I want and so just basically try everything the boss fights the dummies the DPS the builds the biomes
> so I can change it I have a big 4x4 room and I can change between biomes spawn bosses if I want try different
> builds just like a creative mode in Minecraft there is a build actually right now rebuilding the the the boss fight
> so you would have to build on top of that one to have the latest changes but if we spawn the boss and the the boss
> mechanics change it's okay right you just spawn the unit the entity"

| # | Point | Decision | Step |
|---|---|---|---|
| P1 | "choose whatever powers I want … test all the builds" | Every wand card (Gun, Blade, shared, triggers, legendary), ability, stat card and item the game can offer, at any level (1–5 where it levels), added or removed at will; the wand's slots open to its maximum | PG3 |
| P2 | "dummies I can spawn and delete … in the position I want" | Click on the floor to place a dummy, click a dummy (or anything spawned) to delete it; Clear all | PG1, PG3 |
| P3 | "have a DPS meter" | Owner pick (below): total + per source | PG4 |
| P4 | "choose to spawn the bosses that I want" | Any boss (and any enemy) at a clicked point, as many as wanted. A boss is spawned as the entity: whatever BF changes in its fight comes with it ("you just spawn the unit") | PG1, PG3 |
| P5 | "a big 4x4 room" | One room of the generator's extra-large 4 × 4 cells (v0.7.5 MG), the start hall's open interior, walled, no doors, portal, rewards or spawns | PG1, PG2 |
| P6 | "I can change between biomes" | Five biome buttons; the room is redrawn in that biome (look, light, its ice or starglow) and the build, dummies and spawns stay | PG5 |
| P7 | "there is a build … rebuilding the boss fight so you would have to build on top of that one" | Branch cut from `claude/v0.7.5-new-ground` (BM done, BF not started); merged back into it, so BF's bosses appear in the playground | — |

## Owner decisions (2026-10-13, asked in chat)

| Question | Answer |
|---|---|
| How do you get into the playground? | **A main-menu row** "Playground", in every build that has the dev panel (locked with it for a public release, `DevGate`). **Superseded** v0.8.0 N6 (owner O60, 2026-10-17): the F10 panel's Playground button, off a run |
| How do training dummies behave? | **Never die by default** (HP refills) **plus an optional HP** per spawn (it dies, to time a kill). They stand still |
| What does the DPS meter show? | **Total + per source**: DPS over the last 5 s, total damage, time since the first hit, a breakdown by source (basic attack, each child spell / trigger, each ability, bleed / burn / poison ticks), Reset |
| What does the panel look like? | **Dev-tool style, no mockups** (the F10 panel's plain look; G2 waived by the owner for this tool) |

## Lead's readings (2026-10-13; the owner corrects them in use)

- **Entering:** Playground → the weapon picker (Gun / Blade, as a new run) → the room. The panel's "Change weapon"
  goes back to the picker and rebuilds the room with the new weapon (the pools are per weapon).
- **The panel:** **F1** opens and closes it (not bound by the game). While it is open the sim is paused (like F10),
  and a left click on the floor does the selected tool: place a dummy (∞ or the chosen HP), place the chosen enemy
  or boss, or delete what is under the cursor. Mouse + keyboard only (a dev tool; the game keeps its pad parity).
- **Dummies** are the sim's existing `DUMMY` actor (enemy team: hits, procs, statuses and on-kill triggers land on
  it as on an enemy), still (`dummy_speed` 0) and silent (no shots). "∞" is a dummy whose HP is refilled between
  ticks by the playground's command layer (the sim is untouched); its HP pool is large enough that no single tick
  empties it. They give no shards or heal orbs and don't count as kills for the Codex or achievements.
- **Enemies and bosses** fight as in a run (their AI, attacks and phases). A spawned boss doesn't clear the room (a
  run's summoned boss does). The sealed boss room's closing band needs the sealed room, so it's absent here.
- **Player tools:** God mode, Full heal, Clear enemies, Clear all.
- **Records nothing:** no save, no Codex, no achievements, no first-run hints (as a tweaked run).
- **The DPS meter** reads the sim's DAMAGE events (the player's, `amount_applied`), drawn top right while in the
  playground.

## Steps

| Step | Scope | Kind |
|---|---|---|
| PG1 | A one-room floor (`FloorGenerator.one_room`) and the playground's commands (`PlaygroundApi`: place / delete at a point, ∞ dummies, grant / remove / level any card, god, heal, clear) | sim + application, unit tests |
| PG2 | The main-menu row, the weapon pick and the room (`PlaygroundScenario`, `Main.start_playground`), the pause menu's Quit, nothing recorded | app, e2e |
| PG3 | The F1 panel: Build, Spawn, Biome, Player tabs; click to place and delete | debug UI, e2e |
| PG4 | The DPS meter (total, 5 s window, per source, Reset) | presentation, unit + e2e |
| PG5 | Biome switching (redraw the room, lay the biome's surface) | app + presentation, e2e |

## How to use it

1. Main menu → **F10** (the master dev panel) → **Playground** (top bar) → pick the weapon (Gun / Blade, ←/→ and
   Enter). v0.8.0 N6 (owner O60, "nah playground will be hidden as a dev option"): it is no longer a main-menu row;
   the button shows only off a run (on the main menu), locked with F10 for a public release (`DevGate`).
2. You're in one big 4×4 room. A **DPS meter** sits on the right; **F1** opens the panel (bottom-left reminder).
3. While the panel is open the game waits:
   - **Build:** set the **Level** (1–5), search, select a card and press **Add at level** (or double-click it). A card
     you hold shows its level; adding it again at another level re-levels it. **Your build** lists what you hold;
     double-click a row (or **Remove**) to take it out. **Change weapon** goes back to the weapon pick. The wand has
     all 8 slots; a 9th card is refused (remove one first). Ability mods appear once you hold their ability.
   - **Spawn:** pick a tool (Dummy that never dies, Dummy with HP, an Enemy, a Boss, Delete), then **left-click the
     floor**. **Right-click** anything to delete it. **Clear enemies and bosses** keeps the dummies; **Clear
     everything** removes them too.
   - **Biome:** redraws the room in that biome (its look, light, sounds, and its ice or starglow patches). The build,
     the dummies and the spawns stay.
   - **Player:** God mode, Full heal, Reset DPS meter, Show DPS meter.
4. **F1** (or **Esc**, or Close) shuts the panel and the game runs. Esc then pauses as in a run (Restart rebuilds the
   room with the same weapon and biome; Main menu leaves). If you die you're back at once at full HP.

**The DPS meter:** DPS over the last 5 s, the average since the first hit, the total and the time, and the sources by
damage (basic attack, each card's child spell or trigger, each ability, bleed / shock / frost / poison ticks, combos
and engines by their card's name). It counts the HP the target really lost, from the sim's DAMAGE events.

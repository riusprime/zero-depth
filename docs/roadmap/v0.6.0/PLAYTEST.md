# v0.6.0: playtest build (owner)

Your v0.4.0/v0.5.0 feedback (every line in [`PLAN.md`](PLAN.md)), the UI you picked and the v0.5.9 "Embers" visual
rework, together (owner: "this new version will be v0.6.0 with all the Ui and gameplay feedback together"; "v0.6.0
should also include the visual rework"). Answers below are **OWNER ONLY**: written by the owner or pasted verbatim
from the owner's message.

## Get the build
1. When the PR into `main` is merged, the **Windows** workflow runs on `main`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>. Pick the newest green run on `main`.
2. Download `game_windows_x86_64` (kept 14 days), unzip `game_windows_x86_64.zip`, run `game.exe`.
3. If it crashes: send `%APPDATA%\Godot\app_userdata\{{TITLE}}\logs\godot.log`.
4. Old saves load: a v0.5 build's abilities become modifiers in your six slots (the first six).

## What's new
- **Your build is your weapon.**
  - The Blade or the Gun, plus one utility (Blink or Aegis).
  - **Six modifier slots**, in the order you pick them. Each modifier changes what your attacks *are*: shape, count,
    element, what they trigger. Taking one you hold again levels it up and uses no slot.
  - With all six full, a new modifier offers **Swap**: pick the slot it replaces, or skip.
  - Stat cards take no slot and still multiply.
- **The old abilities are weapon modifiers.**
  - Bomb Lobber: every 4th attack also lobs a bomb.
  - Drone: copies your attack.
  - Orbit Blades: copies of your attack circle you.
  - Arc Field: shock fields where your attacks end.
  - Frost Nova: frost, plus a ring on a kill streak.
  - Flame Trail: dash and shots leave fire.
  - Each carries your other modifiers.
- **All 30 modifiers M1–M30**, plus 3 legendary ones from bosses.
  - Echo Slash (the shooting sword), Halo Shot, Shock Circles, Split Shot, Mirror Drone and the rest of the list.
  - Dash, Vent and Blink take modifiers too.
  - Every attack is drawn from what it is: shape, element colour in the core, heat (orange, then red) on the edge.
  - **Options > Display > Effects density:** Low / Medium / High.
- **Difficulty that follows you (hidden).**
  - At each floor start, enemies scale toward your build's power, up to a cap per floor, raised by threat. A normal
    build stays strong but challenged; only a lucky one past the cap melts the floor.
  - Bosses: 3 phases. At 66 % and 33 % a short invulnerable shift with adds, so a burst can't skip a phase. Phase 3
    is faster.
- **Pacing.** Floor 1 is calm for 30 s, then ramps faster. Floors 2–3 start warm.
- **Sealed arenas.**
  - About a third of the rooms lock when you enter. Waves spawn inside, the rest of the floor goes dark, and the
    floor's chests and altars there unlock on the clear.
  - **Overrun:** 3–5 waves of 4/8/12 inside.
- **Boss reward:** a legendary altar, pick 1 of 3.
- **Core theft.** Elites and bosses carry a glowing core. Stagger them, then kill them within 2 s to steal it as a
  free pick.
- **Curses.** Cursed chests offer a trade-off curse instead of a free epic card: Rooted, Heavy Hands, Glass Heart,
  Blood Price, Fevered, Tunnel Vision, Brittle, Marked.
- **Deep floors.** A violet haze, an elite in every room, more threat, an epic altar by the boss door, and a
  Deep-only event.
- **Economy.**
  - Heal orbs only with the **Lifesprout** card.
  - At most 2 altars a floor; the rest are chests.
  - The shop: bought slots stay sold, rerolls redraw the rest, 4 buys a floor.
  - Shards −30 %, floor 2–3 prices ×1.5, and the portal keeps half your unspent shards.
- **Look.**
  - Your crystal card frames on every pick.
  - The UI you picked: Ember-stone HUD, floating minimap, Cold-glass menus.
  - Your shrine model.
  - Lunge Cleave and Scatter Blast animations.
  - Effects restyled to sit in your lighting.
  - All of v0.5.9: lighting moods, your kit, themed rooms, the chest, the hero light.
- **No bot tests.** Balance is your call by play (owner: "From now on not run bot tests").

## Known, measured here (not felt)
- Every screenshot came from software rendering in a cloud container. **How it looks and runs on your PC is not
  known**, especially big fights with many modifiers (Effects density exists for that).
- Every number is a starting value: catch-up caps, boss gates, arena waves, curse sizes, modifier numbers.
- The card pool is now 80 (Blade) / 77 (Gun) cards (target 40–50): your call.
- The new modifiers show a generic gem icon; no art per card yet.
- Ground zones and rings look pale under the new lighting; bolts, rims and particles carry the colour better.
- Nobody here has listened to the game.

## Questions
1. Difficulty: does the catch-up keep you challenged without feeling like a rubber band? Bosses with phase gates?
2. Arenas: about a third of rooms sealing, waves inside, rewards locked: right amount? The dark floor while sealed?
3. Modifiers: do builds look and feel different? Which combos surprised you? Which are dull or broken?
4. Six slots and Swap: right number? Does Swap feel good?
5. The old abilities as weapon modifiers: right?
6. Economy: shop limits, fewer shards, half carried, Lifesprout heal orbs.
7. Curses and Core theft: worth taking? Is the steal window readable?
8. Deep floors: do they feel different now?
9. The UI (Ember HUD, floating minimap, Cold-glass menus) and the crystal cards in play.
10. Attack colours (orange at Hot, red at Overclock) and the effects under your lighting.
11. Frame rate in the biggest fights on High, and with Effects density.
12. The pending confirmations in [`PROGRESS.md`](PROGRESS.md) "Gates" (card pool size, the Resonance name, the
    curse readings, the Deep altar, the Overclock red, the shrine model's height and light).

## Owner answers
OWNER ONLY

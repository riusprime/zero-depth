# v0.6.0 Step CU — trade-off curses and core theft (evidence)

Rows: S6, S7 (C1–C8, G1 approved 2026-10-08: "curses look good too"), X2 Core theft ("yes to all three"). Build SHA:
`949b32f1e1db87ca26d0cb6124dd6fe1f2e54b47` (branch `worktree-agent-a7b7e2907573ce9e7`: Step CU on top of
`claude/lucid-fermat-9wv2tf`, merged with it at `28e152a`/`96def1b`). Godot `4.7.2.stable.official.ed1daf0bf`, Linux
cloud container, headless. Every number is a starting value the owner tunes by play. No bot balance sims were run
(owner P1); the tests prove mechanics.

## What was built
| Piece | Where |
|---|---|
| S6: a cursed chest's cursed card is now a **trade-off curse card** (`Offers.CURSE`, code 3000 + curse): the curse's name, its upside on the face, "Curse · Rare", the curse frame, its drawback on the line under it. The epic stat card is gone. It draws among the trade-off curses you don't hold (`loot:event`); event choices' random curses draw plain curses only | `src/sim/events/curses.gd`, `src/sim/abilities/offers.gd`, `src/presentation/hud/pick_panel.gd`, `curse_look.gd` |
| S7: C1 Rooted (no dash; 25 % dodge on `combat`, the hurt i-frames, a "DODGE" cue), C2 Heavy Hands (attack speed −20 %; the 4th Blade combo step and every 4th Gun shot +60 %), C3 Glass Heart (max HP −30 %; crit +15 %), C4 Blood Price (each Skill or Blink costs 2 % max HP, never lethal; skill and ability hits +35 %), C5 Fevered (heat decays 50 % slower; Overclock +40 %), C6 Tunnel Vision (minimap off; +25 % shards), C7 Brittle (an enemy hit stuns 0.2 s: no move/attack/dash/skill/blink, "STUNNED" cue; +20 % move speed), C8 Marked (elites within 16 m move +30 % toward you and 12 % of spawns are elites; a slain elite drops a free rare card). Each +1 T; the cleanse lifts drawback and upside together | `data/curses/*.tres`, `src/sim/events/curses.gd` (one hook each), hooks in `stats.gd`, `damage.gd`, `player_kit.gd`, `player_skill.gd`, `heat.gd`, `enemy_ai.gd`, `world.gd` |
| The existing six: **Marked Hunt duplicated C8's "more elites"**, so it *became* C8 Marked (same file and id `marked_hunt`, same 12 % elite chance, now as its second drawback, plus the hunt and the rare card). The other five (Leaky Core, Price Gouge, Swarm Call, Swift Foes, Withering) stay as plain curses for event choices. Leaky Core and Fevered pull heat decay opposite ways; both kept (they sum) | `data/curses/marked_hunt.tres` |
| X2 core theft: every elite and boss carries a core (`ai:elite`; elite: a pool mod or a rare stat card; boss: the legendary tier). An elite staggers after 30 % of its max HP in direct damage (stands 0.75 s, attack cancelled); a boss by its own meter (BossAi read, not changed; DS phase gates untouched). A stagger opens a 2 s window; a kill inside it drops the core as a free one-card pick (`RewardStore.Kind.DROP`, opened like an altar, "Stolen core"; a boss core shows legendary). Outside the window: normal drops. All grants go through `CoreTheft.grant` (for Step MX's Swap) | `src/sim/events/core_theft.gd`, `core_state.gd`, `data/event_rules/floor.tres` |
| Views: a crystal over each carrier in its card family's frame colour (`CardFrames`), flaring while staggered; a shrinking ring while the window is open; a burst on a steal; the drop as a turning crystal; DODGE / STUNNED over the hero; the minimap hidden under Tunnel Vision; the HUD prompt "Take the card" | `src/presentation/world_view/core_views.gd`, `reward_views.gd`, `world_view_root.gd`, `hud/minimap.gd`, `hud/hud.gd` |
| Saves: `CurseState`, `CoreState` in `WorldSnapshot.STATE_CLASSES`, hashed in the event block once touched | `src/sim/core/world_snapshot.gd`, `src/sim/events/events.gd` |
| Dev panel TEST HELPER: "Spawn elite (core)" | `src/application/debug_api.gd`, `src/debug/dev_panel.gd` |
| Strings en + es (CURSE_* names, drawbacks, upsides; HUD_DODGE, HUD_STUNNED, PICK_TITLE_CORE, PICK_TITLE_ELITE_DROP, REWARD_OPEN_DROP, UI_CARD_CURSE, UI_CURSE_UPSIDE, UI_DEV_SPAWN_ELITE); CURSE_MARKED_HUNT* replaced by CURSE_MARKED* | `locale/strings.csv` |

Not touched: the v0.5.9 lighting, kit and rooms; boss AI. MX1-facing hooks are one line each (`Curses.swing_damage` in
`PlayerKit._resolve_swing`, `Curses.shot_damage` in `_fire_bolt`, `Curses.attack_speed` inside `Stats.period` /
`swing_end`).

## Tests
- `tests/unit/sim/test_trade_off_curses.gd` (11): each trade-off +1 T and lifted whole; one test per curse proving
  drawback and upside.
- `tests/unit/sim/test_core_theft.gd` (5): deterministic elite core; stagger opens the window and the elite stands;
  kill inside → the core as a free pick, taken; kill outside → normal drop; the boss core is legendary and its own
  stagger opens the window.
- `tests/unit/sim/test_world_snapshot.gd`: `test_round_trip_with_trade_off_curses_and_core_theft` (equal hashes after
  restore and after 600 more ticks).
- `tests/e2e/test_e2e_curses.gd` (2, `main.tscn`, input only; dev panel God, Curse next chest and the TEST HELPER
  Spawn elite clicked with the mouse; shards set directly, labelled): take a cursed chest card with the pad and feel
  its effect; spawn an elite, swing until it staggers, kill it inside the window, walk to the core, E, Enter.
- Changed on purpose: `test_curses.gd` (13 curses; the cursed card is a curse card), `test_event_views.gd`,
  `test_event_validation.gd` (counts and line shapes), `tests/support/event_lab.gd` (legendary tier, as Main).
  `tests/MIN_TEST_COUNT` 1159 → 1178.

## Commands
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash /tmp/claude-0/vd.sh <worktree> cu        # import + lint + bash scripts/verify.sh
cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh
```

## Raw output
Lint (part of vd.sh; it exits on a lint failure before the suite):
```
557 files would be left unchanged
Success: no problems found
```

Full suite at `949b32f` (`/tmp/claude-0/vd_cu.clean.log`, tail):
```
verify exit 0
Totals
------
Scripts             189
Tests              1178
Passing Tests      1178
Asserts           1240684
Time              2040.867s

---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (1178 passing, minimum 1178)
```

The previous run, at the merge `f426b53` (before the test fixes), failed 3 of 1178, all from this step's own
changes, then fixed in `949b32f`:
```
res://tests/content/test_event_validation.gd
- test_the_shipped_events_curses_and_rules_compile
    [Failed]:  [13] expected to equal [6]:  six curses
res://tests/unit/presentation/test_event_views.gd
- test_a_cursed_chest_card_is_marked_and_the_others_are_clean
    [Failed]:  ["Tunnel Vision: The minimap is off"] expected to equal ["Tunnel Vision: The minimap is off · +25 % shards"]:
- test_every_event_and_curse_string_is_in_both_languages
    [Failed]:  [58] expected to equal [44]:
```

Lines this step's tests print (same run):
```
    cursed card: heavy_hands / Heavy Hands: Attack speed −20 %
    the elite's core: serrated_edge
    stolen at tick 228
    cursed card: Heavy Hands: Attack speed −20 %
    a Warden walks 0.267 m in 10 ticks, 0.307 m cursed
    Rooted dodged 217 of 800 hits
    Blade hits plain [11, 12, 13, 28, 11, 12, 14, 27], cursed [11, 12, 13, 45, 11, 12, 14, 43]
    a kill pays 2 shards, 3 under Tunnel Vision
    top speed 0.1000 m/tick, 0.1200 under Brittle
    an elite Warden walks 0.267 m in 10 ticks, 0.347 m Marked
```

Export smoke (`cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh`, exit 0, tail):
```
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content validates inside the pack (0 errors)
  ok    manifest hash d514292f9b37 matches the project's
  ok    Spanish translation is loaded
  ok    audio cues: 87
  ok    tests are not shipped
0 miss(es)
```

Screenshots: NOT YET RUN (no renderer pass in this step).

## Owner-only
- Feel of each curse, and whether the trade-offs read as rare-level: OWNER ONLY.
- Core theft numbers (30 % stagger, 0.75 s, 2 s window), and whether a boss's core should replace or add to its
  legendary altar (built: it adds): OWNER ONLY.

## The builder's readings (reversible, flagged for the owner)
- "Abilities" in C4 = the Skill button and Blink (the uses a player triggers); its +35 % also covers auto-ability hits.
- "Elites hunt you" = elites within 16 m move 30 % faster toward you (all enemies already target only the player).
- A stagger by the killing blow opens no window; a core whose card no longer applies is redrawn when it drops.
- A drop inside an uncleared arena is locked until the clear, like every reward there.

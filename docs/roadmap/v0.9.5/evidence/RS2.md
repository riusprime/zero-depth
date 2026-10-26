# v0.9.5 Step RS2: the Runic Stone's other seven lines and the full stone (RUNIC_STONE.md R4-R10, S6)

Machine: owner PC (i7-10700K, RTX 3060), Windows, Godot 4.7.2, headless tests with `--language en`, one `APPDATA` folder per job.

## Triggers (each learns its line once; `RunicStone.sync_from` runs at the hub entry, so a profile that already meets one learns it on load)
| Line | Condition | Stat / source | New stat? |
|---|---|---|---|
| r4 | a floor boss beaten from its door shutting with no HP lost by the hero | `bosses:no_hit` (AchievementTracker: armed when `boss_door_sealed()` turns true, spoiled by a DAMAGE on the hero, counted at `BOSS_DEFEATED` when no boss is left alive) | yes |
| r5 | 60 s (3600 hub ticks) with no input at all | `HubRunic.idle_ticks`; any `InputEvent` (`_input`) resets; a menu, the pause or the portal walk over the hub (`held`, `overlay`, `walking`) resets | no (hub only) |
| r6 | 8 collectibles found | count of the profile's `collectibles` section (read only) | no |
| r7 | the Hollow Crown (final boss) beaten, any weapon | existing `final:won` | no |
| r8 | 3 Ascension loops in one run | existing Codex counter `runs/loop/best` >= 4 (`Main._record_ascension` raises it to the run's loop number, which is 1 + loops taken) | no |
| r9 | a cracked wall broken on 5 different runs | `secrets:crack_runs` (AchievementTracker: `crack_broken()` seen once per run; a new run is detected when the attached run floor is lower than the last, or run floor 1 at tick 0) | yes |
| r10 | the language switched while the hub runs with the stone awake | `HubRunic._notification(NOTIFICATION_TRANSLATION_CHANGED)` (locale differs from the last seen); the bubble shows it at once if open | no (hub only) |

R5 and R10 call `HubRunic.announce()`: profile saved, the stone pulses at once, the ring appears if the stone is full, an open bubble shows the new line. Lines learned by the run stats pulse once on hub entry (RS1's pending_pulse).

## S6: the full stone
- **Ring:** `RuneRingView` (`src/presentation/world_view/rune_ring_view.gd`): the 24 glyphs of `RunicGlyphs` as thin ribbons in one unshaded violet emissive mesh on the floor around the stone, turning about 0.12 rad/s. `HubView.set_runic_full(bool)` adds or removes it (node `RuneRing` under the stone's root). No art file, no texture.
- **Robe:** `data/wardrobe/robe_runic.tres` (id `runic`, order 8): a colour robe with a near-black cloak (#16131F) and a violet underside (#8C60DE); no new model or texture. `RobeDefinition` got `unlock_hint_key` (a robe earned, not bought: needs no price; `MetaProgress.wares` skips it so the Progression Station doesn't sell it). The Wardrobe panel shows the robe's hint as its lock note while locked. Strings appended to `locale/strings.csv`: `ROBE_RUNIC` Runic / Rúnica, `ROBE_RUNIC_HINT` "Learn every line of the Runic Stone" / "Aprende todas las líneas de la Piedra rúnica".
- **Unlock:** `RunicStone.learn` calls `ensure_robe` once every line the content lists is learned (`unlocks.robes` gets `runic`, the same list as the bought robes, so it persists in the profile). A profile already full gets it on the next sync.
- The robe's "black stone with violet veins" is a cloak/underside palette only; there are no vein lines on the cloak.

## Tests
- New `tests/unit/application/test_runic_triggers.gd` (12 tests): the seven lines' English; stored stats grant r4/r6/r7/r8/r9 on load, once, with the boundaries (7 vs 8 collectibles, loop 3 vs 4, 4 vs 5 cracked runs); r4 clean vs hurt in a real boss fight (`FightLab.floor_world`); r9 once per run across three real `CrackLab` floors (second floor of the same run does not count, a new run does); r5 (one tick short, input resets, a menu resets, once); r10 (sleeping stone ignores it, no change no line, open bubble shows it); the robe locked, not on sale, listed, names en/es; the tenth line unlocks it and it survives save/load and can be worn; a profile already full gets it on load; an old profile syncs without creating sections.
- Changed `test_runic_stone.gd`: the line count is 10.
- New e2e `tests/e2e/test_e2e_runic_stone_full.gd`: 9 lines granted, hub, bubble open, Esc, Options (pause menu), click Language: the stone learns r10, pulses, the `RuneRing` exists and turns, the robe unlocks, the Wardrobe cycles to Runic, it is not locked and is worn.
- Shot script `scripts/shots/rs2_shots.gd`.

## Commands and raw totals
Lint: `gdformat` then `gdlint` on every touched and new .gd file: `Success: no problems found` (hub_view.gd stays at 20 public methods).
Import: `godot --headless --language en --path . --editor --import --quit` (regenerated `locale/strings.*.translation`, committed).

Run 1 `-gtest=res://tests/unit/application/test_runic_triggers.gd,res://tests/unit/application/test_runic_stone.gd`: `Tests 24, Passing Tests 24`.
Run 2 `-gtest=` test_e2e_runic_stone_full: `Tests 1, Passing 1`.
Run 3 `-gtest=` test_e2e_credits, test_e2e_hub, test_e2e_rune_fragments, test_e2e_runic_stone, test_e2e_runic_stone_full, test_e2e_wardrobe, test_hub_view, test_progression_panel, test_epic_robes: `Scripts 9, Tests 44, Passing Tests 44`.
Run 4 `-gdir=res://tests/unit/application,res://tests/content,res://tests/arch -ginclude_subdirs`: `Scripts 53, Tests 335, Passing 334, Failing 1`: `tests/content/test_wardrobe_content.gd::test_the_six_robes` listed the eight robes (the Runic robe is a ninth). Fixed the expected list; re-run of that file alone: `Tests 6, Passing Tests 6`. The rest of that run passed (not re-run as a whole).

Shot: `godot --path . --language en --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/rs2_shots.gd` -> `build/shots/v0.9.5/rs2/en.png` (not committed). Looked at it: the 24 violet glyphs ring the stone's base, the bubble shows the newest line; the stone's model is small in the framing because the hero stands beside it.
No seed-loop tests and no `seams.sh` were run.

## Deviations
- r8 reads the Codex's best loop (>= 4) instead of a new stat: it is the highest loop reached in any run, which is "3 loops in one run".
- r4 counts floor bosses only (not the final arena's bodies); a boss fight resumed from a save does not count; a twin boss counts when the last one falls.
- r9's run boundary is inferred from the attached floor (lower run floor than last, or floor 1 at tick 0), since the tracker has no run object.
- R5's idle counts hub ticks, so it only advances while the hub steps; the Esc/pause menu, any panel and the portal walk reset it. A joypad stick's drift event resets it too (any InputEvent).
- The robe has no vein pattern, only a palette.

## OWNER ONLY
- Do the ring (size, thickness, turn speed) and the Runic robe's look read as "black stone with violet veins"?
- Are the thresholds (60 s still, 8 collectibles, 5 runs) right to play?

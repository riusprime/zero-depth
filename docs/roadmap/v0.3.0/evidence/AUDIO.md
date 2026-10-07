# AUDIO: does every event have its own synthesised sound, does each biome loop, and do captions work?

- **Status:** RUN (generator, asset and unit tests, e2e). **Nobody has listened to these sounds:** this container
  has no audio output, and headless Godot runs on the Dummy driver. Whether they sound good, fit the style and
  are balanced is **OWNER ONLY**.
- **Build:** the commit `v0.3.0 Step AU`, parent `5e24bf7`, on the workstream branch
  `worktree-agent-a0498ff3d3a5b2059`; Godot `4.7.2.stable.official.ed1daf0bf`; Python `3.13.16`, numpy `2.5.3`;
  OS `Linux 6.18.44-fc-v77` (cloud container)
- **Date:** 2026-10-07
- **Who ran it:** agent

Owner line L27 (v0.3.0 PLAN): "how far can you take the sounds on your own?" + (Q) "I synthesise SFX now".
How it works, how to regenerate and how to replace a sound: [`docs/audio/README.md`](../../../audio/README.md).

## What was built

- `scripts/audio/generate_sfx.py` (generator v1, numpy): 46 sound effects and 3 biome loops, all original —
  oscillators, two-operator FM, noise through swept band-pass/low-pass/high-pass filters, pitch sweeps, bitcrush
  with sample-and-hold, and a darkening feedback echo on almost every sound (the "slightly echoey" tail). Mono
  44.1 kHz 16-bit WAV; SFX peak at −1 dBFS with a DC block, a 9 kHz low-pass, a 1.5 ms fade-in and a 5 ms
  fade-out; ambience peak at −6 dBFS, 10 s seamless loops (whole-cycle partials and LFOs, noise shaped in the
  frequency domain, wrap-around echo) carrying a `smpl` loop chunk.
- `assets/audio/manifest.json`: id, kind, path, sha256, length, peak, RMS, loop, generator and version, licence.
- `data/audio/cues/<id>.tres` (`AudioCueDefinition`, validated through `ContentRepository`): bus, volume, pitch
  jitter, max voices, cooldown, duck, caption key (SFX_NEEDS "cue data").
- `src/presentation/audio/`: `AudioEvents` (which cues one tick asks for, read through `WorldReader` only),
  `SfxMixer` (voice limit and cooldown), `AudioDirector` (playback, pitch jitter from its own RNG seeded 7,
  `AudioStreamPlayer3D` panning for world sounds, ducking, ambience crossfade, menu sounds, the caption line,
  overrides). Main owns one director for the whole session, so the ambience crossfades between floors.
- Buses: `Master` ← `Music`, `Effects`, `Ambience`; `Effects` ← `SFX`, `UI`. Settings: `volume_ambience` (70) and
  `captions` (`off`) join the existing `volume_master` / `volume_music` / `volume_effects`. The Options screen
  (workstream O) exposes them; `UI_VOLUME_AMBIENCE` and `UI_CAPTIONS` are in `strings.csv` for it.

## The event table (starting values)

Lengths and RMS from the manifest. "Duck": the sfx bus drops −9 dB (60 dB/s) while it plays. Every play is
pitched by ×(1 ± jitter). World sounds on the sfx bus are panned by where they happen; ui-bus sounds are not.

| Cue | Plays when | Bus | dB | Voices | Cooldown s | Duck | Caption | Length s | RMS dBFS |
|---|---|---|---|---|---|---|---|---|---|
| `blade_slash_1` | a swing starts: first slash (right to left) | sfx | -4.0 | 2 | 0.03 |  | — | 0.42 | -20.36 |
| `blade_slash_2` | a swing starts: the backhand (left to right) | sfx | -4.0 | 2 | 0.03 |  | — | 0.42 | -19.86 |
| `blade_slash_3` | Twin Arc's echo swing (echo_tick() changes), or a slash past step 2 | sfx | -4.0 | 2 | 0.03 |  | — | 0.5 | -19.18 |
| `blade_thrust` | a swing starts: the thrust | sfx | -4.0 | 2 | 0.03 |  | — | 0.372 | -18.5 |
| `blade_spin` | a swing starts: the spinning finisher | sfx | -2.0 | 1 | 0.1 |  | — | 1.03 | -19.8 |
| `bolt_fire` | a new player projectile (not a Shrapnel shard) | sfx | -8.0 | 3 | 0.05 |  | — | 0.38 | -18.15 |
| `bolt_hit` | DAMAGE with TAG_PROJECTILE on an enemy | sfx | -9.0 | 3 | 0.04 |  | — | 0.22 | -17.77 |
| `enemy_fire` | a new enemy projectile | sfx | -9.0 | 3 | 0.05 |  | — | 0.42 | -17.04 |
| `hit_taken` | DAMAGE on the player | sfx | -1.0 | 1 | 0.12 |  | — | 0.55 | -14.32 |
| `enemy_hit` | DAMAGE (not DOT, not projectile) on an enemy; bosses pitched 0.8 | sfx | -10.0 | 4 | 0.03 |  | — | 0.2 | -19.06 |
| `guard_block` | HIT with TAG_GUARDED/TAG_BLOCKED | sfx | -5.0 | 2 | 0.05 |  | — | 0.65 | -24.57 |
| `enemy_death_charger` | KILL of a Charger | sfx | -6.0 | 3 | 0.04 |  | — | 0.8 | -16.76 |
| `enemy_death_warden` | KILL of a Warden | sfx | -5.0 | 3 | 0.04 |  | — | 0.95 | -16.3 |
| `enemy_death_needle` | KILL of a Needle | sfx | -6.0 | 3 | 0.04 |  | — | 0.7 | -16.35 |
| `enemy_death_hatchling` | KILL of a hatchling | sfx | -9.0 | 3 | 0.04 |  | — | 0.33 | -20.4 |
| `enemy_windup` | an enemy enters WINDUP | sfx | -10.0 | 2 | 0.15 |  | — | 0.5 | -13.34 |
| `player_death` | KILL of the player | ui | -2.0 | 1 | 1.0 |  | CAPTION_PLAYER_DEATH | 1.9 | -19.89 |
| `dash` | is_dashing() rises | sfx | -8.0 | 1 | 0.1 |  | — | 0.35 | -18.81 |
| `blink_out` | blink_tick() changes (at blink_from) | sfx | -6.0 | 1 | 0.1 |  | — | 0.54 | -16.04 |
| `blink_in` | blink_tick() changes (at the player) | sfx | -6.0 | 1 | 0.1 |  | — | 0.52 | -20.56 |
| `item_pickup` | PICKUP | ui | -5.0 | 1 | 0.1 |  | — | 0.635 | -14.52 |
| `altar_open` | choosing() rises on an altar | ui | -6.0 | 1 | 0.3 |  | — | 1.3 | -18.81 |
| `chest_open` | choosing() rises on a chest | ui | -5.0 | 1 | 0.3 |  | — | 1.05 | -23.39 |
| `chest_refuse` | reward_denied_tick() changes | ui | -6.0 | 1 | 0.25 |  | — | 0.36 | -11.54 |
| `shard_collect` | SHARDS | sfx | -16.0 | 4 | 0.03 |  | — | 0.14 | -16.54 |
| `combo_unlock` | COMBO_UNLOCKED | ui | -3.0 | 1 | 0.5 |  | CAPTION_COMBO_UNLOCK | 1.65 | -15.39 |
| `heat_threshold` | not wired yet (H names the event) | sfx | -6.0 | 1 | 0.2 |  | — | 0.4 | -12.7 |
| `heat_overheat` | not wired yet (H names the event) | ui | -3.0 | 1 | 0.5 |  | CAPTION_OVERHEAT | 1.0 | -14.82 |
| `heat_vent` | not wired yet (H names the event) | sfx | -4.0 | 1 | 0.2 |  | — | 0.8 | -18.72 |
| `boss_telegraph` | a boss enters WINDUP (generic warning) | ui | -4.0 | 1 | 0.3 | yes | — | 0.88 | -15.27 |
| `boss_telegraph_gatekeeper` | the Gatekeeper enters WINDUP | ui | -5.0 | 1 | 0.3 | yes | CAPTION_TELEGRAPH_GATEKEEPER | 1.15 | -15.39 |
| `boss_telegraph_brood_mother` | the Brood Mother enters WINDUP | ui | -5.0 | 1 | 0.3 | yes | CAPTION_TELEGRAPH_BROOD_MOTHER | 1.1 | -22.53 |
| `boss_telegraph_siege_engine` | the Siege Engine enters WINDUP | ui | -5.0 | 1 | 0.3 | yes | CAPTION_TELEGRAPH_SIEGE_ENGINE | 1.15 | -14.86 |
| `boss_slam` | a boss enters ACTIVE: slam ring, leap, burrow, charge | sfx | -2.0 | 2 | 0.1 |  | — | 1.3 | -13.38 |
| `boss_laser` | a boss enters ACTIVE: sweep, rail, lanes | sfx | -4.0 | 2 | 0.1 |  | — | 1.25 | -16.03 |
| `boss_mortar` | a boss enters ACTIVE: barrage, bolt fan, deploy, brood | sfx | -5.0 | 3 | 0.08 |  | — | 0.9 | -18.46 |
| `boss_stagger` | a boss enters STAGGERED | ui | -3.0 | 1 | 0.5 |  | CAPTION_BOSS_STAGGER | 1.0 | -18.11 |
| `boss_phase` | boss_phase() rises | ui | -3.0 | 1 | 0.5 |  | CAPTION_BOSS_PHASE | 1.4 | -14.94 |
| `boss_death` | BOSS_DEFEATED | sfx | 0.0 | 1 | 1.0 |  | CAPTION_BOSS_DEATH | 2.6 | -13.36 |
| `boss_door_seal` | BOSS_ROOM_SEALED | sfx | -3.0 | 1 | 1.0 |  | CAPTION_DOOR_SEAL | 1.02 | -18.0 |
| `portal_open` | PORTAL_OPENED | ui | -3.0 | 1 | 1.0 |  | CAPTION_PORTAL_OPEN | 2.0 | -19.21 |
| `floor_enter` | a floor starts (AudioDirector.attach) | ui | -4.0 | 1 | 1.0 |  | — | 1.85 | -18.39 |
| `ui_move` | menu focus moves (not within 0.12 s of a confirm/back) | ui | -14.0 | 2 | 0.03 |  | — | 0.085 | -15.95 |
| `ui_confirm` | any button pressed | ui | -9.0 | 1 | 0.05 |  | — | 0.25 | -12.58 |
| `ui_back` | a button named Back, or ui_cancel with a menu focused | ui | -9.0 | 1 | 0.05 |  | — | 0.22 | -12.11 |
| `low_hp_heartbeat` | HP under 30 % of max: every 54 ticks | ui | -4.0 | 1 | 0.5 |  | CAPTION_LOW_HP | 0.43 | -14.66 |
| `ruins` | a floor in Ruins (1.5 s crossfade) | ambience | -8.0 | 1 | 0.0 |  | — | 10.0 | -15.23 |
| `night_rocks` | a floor in Night Rocks (1.5 s crossfade) | ambience | -8.0 | 1 | 0.0 |  | — | 10.0 | -13.94 |
| `red_canyon` | a floor in Red Canyon (1.5 s crossfade) | ambience | -8.0 | 1 | 0.0 |  | — | 10.0 | -16.69 |

## Generator

```
$ python3 scripts/audio/generate_sfx.py
sfx       blade_slash_1                 0.420 s    37088 bytes
sfx       blade_slash_2                 0.420 s    37088 bytes
sfx       blade_slash_3                 0.500 s    44144 bytes
sfx       blade_thrust                  0.372 s    32854 bytes
sfx       blade_spin                    1.030 s    90890 bytes
sfx       bolt_fire                     0.380 s    33560 bytes
sfx       bolt_hit                      0.220 s    19448 bytes
sfx       enemy_fire                    0.420 s    37088 bytes
sfx       hit_taken                     0.550 s    48554 bytes
sfx       enemy_hit                     0.200 s    17684 bytes
sfx       guard_block                   0.650 s    57374 bytes
sfx       enemy_death_charger           0.800 s    70604 bytes
sfx       enemy_death_warden            0.950 s    83834 bytes
sfx       enemy_death_needle            0.700 s    61784 bytes
sfx       enemy_death_hatchling         0.330 s    29150 bytes
sfx       enemy_windup                  0.500 s    44144 bytes
sfx       player_death                  1.900 s   167624 bytes
sfx       dash                          0.350 s    30914 bytes
sfx       blink_out                     0.540 s    47672 bytes
sfx       blink_in                      0.520 s    45908 bytes
sfx       item_pickup                   0.635 s    56050 bytes
sfx       altar_open                    1.300 s   114704 bytes
sfx       chest_open                    1.050 s    92654 bytes
sfx       chest_refuse                  0.360 s    31796 bytes
sfx       shard_collect                 0.140 s    12392 bytes
sfx       combo_unlock                  1.650 s   145574 bytes
sfx       heat_threshold                0.400 s    35324 bytes
sfx       heat_overheat                 1.000 s    88244 bytes
sfx       heat_vent                     0.800 s    70604 bytes
sfx       boss_telegraph                0.880 s    77660 bytes
sfx       boss_telegraph_gatekeeper     1.150 s   101474 bytes
sfx       boss_telegraph_brood_mother   1.100 s    97064 bytes
sfx       boss_telegraph_siege_engine   1.150 s   101474 bytes
sfx       boss_slam                     1.300 s   114704 bytes
sfx       boss_laser                    1.250 s   110294 bytes
sfx       boss_mortar                   0.900 s    79424 bytes
sfx       boss_stagger                  1.000 s    88244 bytes
sfx       boss_phase                    1.400 s   123524 bytes
sfx       boss_death                    2.600 s   229364 bytes
sfx       boss_door_seal                1.020 s    90008 bytes
sfx       portal_open                   2.000 s   176444 bytes
sfx       floor_enter                   1.850 s   163214 bytes
sfx       ui_move                       0.085 s     7542 bytes
sfx       ui_confirm                    0.250 s    22094 bytes
sfx       ui_back                       0.220 s    19448 bytes
sfx       low_hp_heartbeat              0.430 s    37970 bytes
ambience  ruins                        10.000 s   882112 bytes
ambience  night_rocks                  10.000 s   882112 bytes
ambience  red_canyon                   10.000 s   882112 bytes
49 files, 5971030 bytes, generator v1
```

Determinism: a second render compared byte for byte with the files on disk.

```
$ python3 scripts/audio/generate_sfx.py --check
  same  assets/audio/sfx/blade_slash_1.wav
  same  assets/audio/sfx/blade_slash_2.wav
  same  assets/audio/sfx/blade_slash_3.wav
  same  assets/audio/sfx/blade_thrust.wav
  same  assets/audio/sfx/blade_spin.wav
  same  assets/audio/sfx/bolt_fire.wav
  same  assets/audio/sfx/bolt_hit.wav
  same  assets/audio/sfx/enemy_fire.wav
  same  assets/audio/sfx/hit_taken.wav
  same  assets/audio/sfx/enemy_hit.wav
  same  assets/audio/sfx/guard_block.wav
  same  assets/audio/sfx/enemy_death_charger.wav
  same  assets/audio/sfx/enemy_death_warden.wav
  same  assets/audio/sfx/enemy_death_needle.wav
  same  assets/audio/sfx/enemy_death_hatchling.wav
  same  assets/audio/sfx/enemy_windup.wav
  same  assets/audio/sfx/player_death.wav
  same  assets/audio/sfx/dash.wav
  same  assets/audio/sfx/blink_out.wav
  same  assets/audio/sfx/blink_in.wav
  same  assets/audio/sfx/item_pickup.wav
  same  assets/audio/sfx/altar_open.wav
  same  assets/audio/sfx/chest_open.wav
  same  assets/audio/sfx/chest_refuse.wav
  same  assets/audio/sfx/shard_collect.wav
  same  assets/audio/sfx/combo_unlock.wav
  same  assets/audio/sfx/heat_threshold.wav
  same  assets/audio/sfx/heat_overheat.wav
  same  assets/audio/sfx/heat_vent.wav
  same  assets/audio/sfx/boss_telegraph.wav
  same  assets/audio/sfx/boss_telegraph_gatekeeper.wav
  same  assets/audio/sfx/boss_telegraph_brood_mother.wav
  same  assets/audio/sfx/boss_telegraph_siege_engine.wav
  same  assets/audio/sfx/boss_slam.wav
  same  assets/audio/sfx/boss_laser.wav
  same  assets/audio/sfx/boss_mortar.wav
  same  assets/audio/sfx/boss_stagger.wav
  same  assets/audio/sfx/boss_phase.wav
  same  assets/audio/sfx/boss_death.wav
  same  assets/audio/sfx/boss_door_seal.wav
  same  assets/audio/sfx/portal_open.wav
  same  assets/audio/sfx/floor_enter.wav
  same  assets/audio/sfx/ui_move.wav
  same  assets/audio/sfx/ui_confirm.wav
  same  assets/audio/sfx/ui_back.wav
  same  assets/audio/sfx/low_hp_heartbeat.wav
  same  assets/audio/ambience/ruins.wav
  same  assets/audio/ambience/night_rocks.wav
  same  assets/audio/ambience/red_canyon.wav
  same  assets/audio/manifest.json
0 difference(s)
```

Loop seams (a check run from a scratch script, not shipped): the jump from each loop's last sample to its first is
smaller than the loop's own 99th-percentile sample-to-sample step — ruins 0.0056 vs 0.0142, night_rocks 0.0046
vs 0.0168, red_canyon 0.0001 vs 0.0046 (full scale = 1). No file has a sample at full scale.

## Tests

`tests/content/test_audio_assets.gd` (7: manifest both ways with sha256, durations, imported lengths, cue ↔
file ↔ biome, caption keys en+es, a bad cue refused), `tests/unit/presentation/test_audio_director.gd` (12: event
→ cue mapping for damage/kill/guard, one slash per swing, boss windup → warning + flavour + slam, heartbeat,
voice limit, captions toggle, ducking, ambience loop and crossfade, an override file), `tests/e2e/test_e2e_audio.gd`
(2, `main.tscn` through `Input.parse_input_event`: menu confirm, floor enter, the biome's loop and a slash sound;
with captions on in the profile, a dev-panel boss's telegraph shows its caption on screen). The export smoke gains
"every cue's sound loads from the pack".

Results of the full suite and the export smoke for this commit: see "Results" below.

## Results

NOT YET RUN at the time of this commit (the full suite and the export smoke run from a clean worktree of it; the
numbers are added by hand in the next commit).

## Owner checks (OWNER ONLY)

- Do the sounds fit the game (robotic, synthy, slightly echoey)? Which ones to redo or replace? — OWNER ONLY
- Balance between cues, and of the ambience under the action? — OWNER ONLY
- Is the heartbeat helpful or annoying? Captions readable? — OWNER ONLY

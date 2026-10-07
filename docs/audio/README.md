# Audio: how the sounds are made, played and replaced

PLAN v0.3.0 L27 (owner: "I synthesise SFX now"). Every sound in the game is original and synthesised by a script
in this repo. Nothing is sampled or downloaded. The rules for which sounds exist are in
[`SFX_NEEDS.md`](SFX_NEEDS.md). The evidence (event table, commands, raw output) is in
[`../roadmap/v0.3.0/evidence/AUDIO.md`](../roadmap/v0.3.0/evidence/AUDIO.md).

## Where things are

| What | Where |
|---|---|
| The generator (numpy) | `scripts/audio/generate_sfx.py` |
| Sound effects | `assets/audio/sfx/<id>.wav` (mono, 44.1 kHz, 16-bit, peak −1 dBFS) |
| Biome ambience (seamless loops) | `assets/audio/ambience/<biome id>.wav` (10 s, peak −6 dBFS) |
| The manifest (id, path, sha256, length, peak, generator version, licence) | `assets/audio/manifest.json` |
| One cue per sound: bus, volume, pitch jitter, voices, cooldown, ducking, caption | `data/audio/cues/<id>.tres` (`AudioCueDefinition`) |
| Playback | `src/presentation/audio/` (`AudioDirector`, `AudioEvents`, `SfxMixer`) |

## Regenerate

```bash
pip install numpy                                   # once
python3 scripts/audio/generate_sfx.py               # rewrites every .wav and manifest.json
python3 scripts/audio/generate_sfx.py --check       # renders in memory; exits 1 if any file differs
godot --headless --path . --editor --import --quit  # re-import
```

The render is deterministic: the same `GENERATOR_VERSION` writes the same bytes (checked with Python 3.13 and
numpy 2.5 on Linux; another numpy or CPU could round a sample differently, which `--check` would show; the
committed files and their manifest hashes are the reference). Change a recipe → bump
`GENERATOR_VERSION`, regenerate, commit the script, the files and the manifest together. The asset test
(`tests/content/test_audio_assets.gd`) checks the files against the manifest both ways.

## Replace a sound with your own file

Drop a file named like the cue id (`.wav` or `.ogg`) in either folder:

- `user://audio_override/<id>.wav` — no rebuild needed; on Windows that's
  `%APPDATA%\Godot\app_userdata\<game name>\audio_override\`. The game reads it the next time it starts.
- `res://assets/audio/override/<id>.wav` — inside the project, so it ships with the build.

Example: `audio_override/boss_slam.ogg` replaces the slam. Ambience overrides are named by biome
(`ruins`, `night_rocks`, `red_canyon`) and are looped over their whole length. To make a replacement permanent,
put the file in `assets/audio/sfx/` (or `ambience/`) under the same name and add its row to the manifest (or
delete the synthesised one from the generator's list).

## Buses and settings

`Master` ← `Music`, `Effects`, `Ambience`; `Effects` ← `SFX` (world sounds, ducked −9 dB under boss telegraphs),
`UI` (menus and alerts, never ducked). Settings keys in the profile: `volume_master`, `volume_effects`,
`volume_ambience` (0–100) and `captions` (`on`/`off`, default off).

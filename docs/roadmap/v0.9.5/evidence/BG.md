# v0.9.5 Step BG: every biome has a deep drifting background under its floor

Owner line 8 ("We are missing something for the background of the different biomes ..."), Q5 (layered parallax
planes, owner-made images). Machine: owner's PC (i7-10700K, RTX 3060, Windows 11), Godot 4.7.2. Build: worktree off
`d33bc82a` plus the BG commit (this file is in it). Presentation and assets only; no sim change.

## What was built
- `src/presentation/world_view/biome_backdrop.gd` (`BiomeBackdrop`): Deep (y -14, opaque) and Mid (y -6, blend_mix,
  depth_draw_never) 160 m QuadMesh planes, unshaded, `fog_disabled`, following the camera's view ray at each plane's
  height; UV scrolled by `parallax` of the camera's movement plus a slow drift; fade to `void_color` 45-75 m from the
  focus; reduced motion sets the drift to 0; a missing image becomes a dark gradient in `void_color`.
- Frozen Shore: no Deep plane; its Deep image is painted on BiomeEdge's sea (uniforms `bd_*`, the shimmer and
  specular stay) and one Mid plane sits at y -0.40, alpha 0.5.
- Night Rocks: Mid at y -8 (its islands reach -7), not -6.
- Starfall: StarVoid's nebula clouds are off behind `BiomeEdge.NEBULA_CLOUDS := false` (they are still drawn from the
  rng so the islands keep their places); the star quads stay.
- Hooked in `StageView` (`BiomeBackdrop.attach`, after the edge job and in `build_lighting_only` for the hub, which
  takes Ruins'). The final arena draws its own void and has none.
- 10 images in `assets/textures/backgrounds/` (VRAM compressed, mipmaps on), listed in `assets/models/manifest.json`
  with sha256; `data/credits/licences.tres` rebuilt with `scripts/content/build_credits.gd`.

## Commands and raw totals
Each run with its own `APPDATA`, `--headless --fixed-fps 60`, GUT `-gtest=`:

| Files | Result |
|---|---|
| unit/presentation: test_biome_backdrop, test_starfall, test_frozen_shore, test_stage_mood, test_stage_ground, test_stage_dresser, test_stage_atmosphere, test_hub_view | 55 tests, 53 pass, 2 fail: the biome-name asserts (`tr()` returned "Caída Estelar" / "Costa Helada": this PC's OS locale is Spanish; not the change) |
| test_starfall and test_frozen_shore again, `--language en`, with the 4 content files below | pass |
| content: test_assets, test_credits_licences, test_model_manifest, test_content_valid | first run 21/22 (credits list stale; rebuilt as above); after the rebuild, together with starfall and frozen_shore: 6 scripts, 39 tests, 39 pass, 225294 asserts |
| e2e: test_e2e_starfall, test_e2e_frozen_shore, test_e2e_lighting, test_e2e_hub | 12 tests, 12 pass, 146 asserts |
| tests/arch | 4 tests, 4 pass |
| lint: gdformat + gdlint on the touched files | clean (stage_view.gd is at 999 of 1000 lines) |

The contrast checks (palette ground vs outline >= 3:1) run in test_stage_mood, test_starfall and test_frozen_shore:
pass. The new test_biome_backdrop.gd: 9 tests pass.

## Shots (`build/shots/v0.9.5/bg/<biome>.png`, 1280x720, view 20 m, at the outer corner of a floor)
Script: scratchpad `bg_shots.gd` (a variant of scripts/shots/biome_looks_bv.gd; not committed).
- ruins: reads as depth (dust nebula, broken columns, floating stone below the wall); floor still clearly readable;
  no tiling or plane edge seen.
- night_rocks: reads as a sea of clouds with the moss islands above it; floor readable; the cloud layer is the
  brightest of the five (owner to judge); no edge seen.
- red_canyon: reads as a lava river and embers far below; floor and wall stay readable (dark-red floor and wall, as
  before this step); no edge seen.
- frozen_shore: the sea shows the aurora-tinted water with the old floes on top and the Mid fog; floor clear; no
  edge seen.
- starfall: a nebula and star field with the code stars and islands above it; the strongest of the five; floor clear.

## Known limits
- The Deep plane (y -14) reaches the camera's 100 m far plane at the top of the screen when the view is larger than
  about 22 m (the game's view is 17 m). A first shot at 30 m showed the plane cut off there. A zoom-out option or a
  larger `view_size` would need a larger `far` or a higher Deep plane.
- OWNER ONLY: whether the layers look right, the drift speed, the brightness, and the frame cost on their hardware
  (`NOT YET RUN`; no timing taken).

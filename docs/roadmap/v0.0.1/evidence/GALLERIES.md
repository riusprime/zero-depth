# GALLERIES: renderer, camera pitch and occlusion: the shots for the owner's Step 7 picks

- **Status:** RUN (shots rendered). **Picks: OWNER ONLY**, pending.
- **Build:** working tree on `e92ad27` + Step 7 changes; Godot `4.7.2.stable.official.ed1daf0bf`
- **Machine:** cloud container, Xvfb, Mesa software rendering (device `llvmpipe (LLVM 20.1.2, 256 bits)`): Forward+ through lavapipe Vulkan, Compatibility through llvmpipe GL. **Not a GPU**: performance and some effects (glow, MSAA) can differ on real hardware.
- **Date:** 2026-10-06
- **Who ran it:** agent

## Command
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/galleries.gd
# and again with --rendering-method gl_compatibility
```
22 PNGs: 11 shots × 2 renderers, written to `build/shots/v0.0.1/en/`. CI's `shots` workflow renders the same set as
an artifact. The scene is `Gallery.showcase_world(4)`: the player, three enemies, slabs, the first volley in flight.

## Raw output (both runs)
```
galleries: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
galleries: renderer=gl_compatibility device=llvmpipe (LLVM 20.1.2, 256 bits)
```

## The shots (committed copies in `shots/`)
| Gate | File | What it shows |
|---|---|---|
| Camera pitch | `shots/pitch_strip.png` (30° / 35.26° / 45°), plus the three full shots | Same room. Lower pitch = longer view, slabs hide more; higher = flatter, less occlusion |
| Occlusion technique | `shots/occ_strip.png` (none / X-ray / fade) | Left: the slab hides an enemy (only its bar shows). Middle: X-ray silhouette (`BaseMaterial3D` stencil X-Ray) through the slab. Right: the slab fades to 30% |
| Renderer | `shots/renderer_strip.png` (Forward+ / Compatibility) | Compatibility renders the same lights and ambient much brighter and washed out: it would need its own light/ambient values |
| Biome readability | `shots/biomes_strip.png` | All four palettes from ART_DIRECTION §2 with the per-biome outline; red enemies stay readable on Red Canyon through the outline and team ring |

## Result
| Gate | Agent's observation | Owner's pick |
|---|---|---|
| Renderer | Forward+ matches the reference's look as tuned; Compatibility needs retuning. Real-GPU check still needed | OWNER ONLY |
| Camera pitch | All three work; 35.26° is the default | OWNER ONLY |
| Occlusion | Fade (selected walls) and X-ray both work; they can combine (X-ray when not faded) | OWNER ONLY |
| Lowest-spec PC to judge on | — | OWNER ONLY |

## Interpretation
The proof scenes exist and render. The picks are the owner's, ideally on the Windows debug gallery build from CI
(GALLERIES button, `run_compatibility.bat`; Step 8 adds the button). Until then the defaults hold: Forward+,
35.26°, fade + X-ray.

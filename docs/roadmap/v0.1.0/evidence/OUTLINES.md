# OUTLINES: the sketch-stroke styles for the owner's pick (PLAN v0.1.0 Step 7c)

- **Status:** RUN (shots rendered). **Pick: OWNER ONLY**, pending (in the next build: Options → Outline style).
- **Build:** working tree on `abfdf2e` + Step 7c changes; Godot `4.7.2.stable.official.ed1daf0bf`
- **Machine:** cloud container, Xvfb, Forward+ through lavapipe (software Vulkan). Not a GPU.
- **Date:** 2026-10-07
- **Who ran it:** agent

## The owner's ask (2026-10-07, verbatim)
> For the visuals could we ahh a light and thin black stroke to borders of things, i'd like to see how that is
> seen in game, i like the art but it is not exact exact thing I want, i want it to be closer to a hand draw
> sketch but not so much that just the feeling that's where the black stroke comes from, like the image
> attached, but that's too much, just for the feeling

## Command
```
for s in off ink sketch paper; do
  VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/outlines.gd -- style=$s
done
```
The script plays the real game (Play → Guard → walk right) and shoots 260 physics ticks in. The strip
`outlines_strip.png` crops the centre (800×450 of 1600×900) of each.

## Raw output
```
outlines: res://build/shots/v0.1.0-dev/outlines/off.png
outlines: res://build/shots/v0.1.0-dev/outlines/ink.png
outlines: res://build/shots/v0.1.0-dev/outlines/sketch.png
outlines: res://build/shots/v0.1.0-dev/outlines/paper.png
```
The same script under `--rendering-method gl_compatibility` also rendered with no shader errors (depth-only edges:
that renderer has no normal buffer).

## The styles (`outlines_strip.png`: off, ink / sketch, paper)
| Style | What it is |
|---|---|
| Off | v0.1.0 as built so far: only actors have rims |
| Ink | A thin (1 px at 1600×900) near-black line on every silhouette and crease: walls, slabs, rocks, actors |
| Sketch (default) | Ink, plus a slight wobble and small gaps, so lines read as drawn by hand |
| Sketch + paper | Sketch, plus a faint paper grain over everything |

## Interpretation
- The lines come from a full-screen pass over the depth and normal buffers (`InkPass`), blended under the
  telegraphs and bars, so warnings are never covered.
- Thickness, wobble, gaps and grain are single numbers in `ink_pass.gd`; any can be pushed further toward the
  reference image or pulled back.
- Whether it gives "just the feeling" is the owner's call: `OWNER ONLY`.

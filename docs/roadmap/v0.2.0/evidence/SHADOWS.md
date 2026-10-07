# v0.2.0 L2: smooth shadow edges, before and after

Owner line L2: "fix … the saw effect, shadows should be a straight line to be smooth".

- **Build:** workstream A branch; parent commit `39d7b35`. The "after" image comes from the commit that adds this
  file.
- **Machine:** cloud container, Godot 4.7.2.stable.official.ed1daf0bf, Forward+ on lavapipe (the Mesa software
  Vulkan driver) under xvfb. **Not** the owner's GPU.
- **Image:** [`shadows_before_after.png`](shadows_before_after.png). Each row has three 2x nearest-neighbour crops
  of the same 1600x900 frame (outer wall, centre slab, east slab), then a 4x crop of the outer wall's shadow edge.

## Command

```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 \
  -s scripts/shots/shadows.gd -- tag=after
```

Raw output of the "after" run (log lines only):

```
shadows: res://build/shadows/after2.png
atlas=8192 soft_quality=4 blur=0.5 mode=0 camera_far=100.0
```

(That run used `tag=after2`. Its PNG is pixel-identical to the `after.png` in the comparison: `ImageChops.difference`
bounding box `None`.) The "before" frame came from the same scene and tick, rendered with a scratch copy of this
script before any shadow setting changed. The shadow settings then were the ones at `39d7b35`: atlas 4096, soft
quality 2, blur 0.0, camera far 200. The before/after crops were put together with PIL from `build/shadows/`.

## What changed

| Setting | Before | After | Where |
|---|---|---|---|
| `rendering/lights_and_shadows/directional_shadow/size` | 4096 (engine default) | 8192 | `project.godot` |
| `rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality` | 2 (engine default, low) | 4 (high) | `project.godot` |
| `DirectionalLight3D.shadow_blur` | 0.0 | 0.5 | `stage_view.gd` |
| `Camera3D.far` (iso camera) | 200 | 100 | `iso_rig.gd` |
| Shadow mode / max distance / bias | orthogonal, 80, defaults | unchanged | `stage_view.gd` |

## What I tried, and what I saw

These are scratch renders under `build/shadows/` and are not tracked. Each line is what I saw in the crops:

- **`directional_shadow_max_distance` at 40, 72, 80 or 200:** I saw no difference in step size. Shadows still
  reached ground about 60 m from the camera with max distance 40. With this orthographic camera, the shadow fit
  doesn't follow this setting.
- **Camera `far` from 200 to 100:** the steps were about half as long. With an orthographic camera, the directional
  shadow seems to cover the camera's whole near-to-far range. That's my reading of the renders, not something I
  checked in the engine source. Setting `near` to 30 gave no further visible gain.
- **Atlas from 4096 to 8192:** the steps were about half as long again. Atlas 4096 with far 100, quality 4 and blur
  0.5 still showed a faint ripple on the 4x crop. Atlas 8192 didn't.
- **PSSM with 2 splits (split 1 at 0.6):** the steps were no better, and I saw stripes on the wall tops (shadow
  acne). I rejected it.
- **Blur 1.0 or 2.0 (quality 3 to 4):** the edges were smooth, but the small rubble and grass props lost most of
  their shadows, and the walls' shadows went soft. Blur 0.5 kept the prop shadows and a crisp edge. Quality 5
  (ultra) at blur 0.5 looked the same to me as quality 4.

## Interpretation

In the "after" row, the long wall and slab shadows have straight edges at 2x and 4x zoom. The stair-steps in the
"before" row, about 6 screen pixels per step on the outer wall, are gone. The edge is a little softer than before,
about one to two pixels, and the shadow still keeps the long, crisp shape of the art direction. Prop shadows are
still there.

What these renders don't show:

- The cost. An 8192 directional atlas is roughly 128 MB of VRAM at 16-bit depth (my arithmetic, not a
  measurement), and quality 4 takes more shadow samples. I didn't measure frame time on any GPU. lavapipe timings
  mean nothing here.
- Moving shadows. Shimmer while the camera follows the player wasn't checked; these are still frames.
- Other zoom levels and pitches than the default (`view_size` 17, pitch 35.26).
- Results on the owner's hardware: **OWNER ONLY**.

Camera `far` at 100 still leaves room past the farthest visible ground. By my estimate that ground is at 48 to 72 m
at the default zoom and pitch, but I didn't measure it. A much larger zoom-out, or a lower pitch, would need `far`
checked again.

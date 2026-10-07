# Portal gate renders (v0.2.0 PLAN step D, owner line L8)

**What this proves:** what `PortalGate` (`src/presentation/world_view/portal_gate.gd`) looks like through the real
iso camera (`IsoRig`, yaw 45°, pitch 35.26°, ortho size 9 m) on Ruins ground. The real `WorldViewRoot` draws the
room: the stage, the light, the sketch ink pass and the player. The gate sits at sim (3, 3).
**What it doesn't prove:** whether it looks right to the owner. Feel and taste are `OWNER ONLY`.

- **Build:** the renders ran on a working tree based on `39d7b35`, with this step's files uncommitted (the step-D
  commit). The gate code and the shot script were the same as the committed ones; only the evidence docs changed
  after the run.
- **Machine:** a cloud container, software Vulkan (llvmpipe), under xvfb. This is not the owner's hardware.

## Command

```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/portal.gd
```

## Raw output (complete, exit code appended by `; echo exit=$?`)

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)

portal: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
portal: res://build/shots/v0.2.0/portal/facing_camera_sealed.png
portal: res://build/shots/v0.2.0/portal/facing_camera_open.png
portal: res://build/shots/v0.2.0/portal/facing_0_sealed.png
portal: res://build/shots/v0.2.0/portal/facing_3072_sealed.png
portal: res://build/shots/v0.2.0/portal/facing_512_edge_on_sealed.png
portal: res://build/shots/v0.2.0/portal/facing_1536_back_sealed.png
portal: res://build/shots/v0.2.0/portal/portal_gate_sheet.png 2400x900
exit=0
```

The contact sheet was copied by hand from `build/shots/v0.2.0/portal/portal_gate_sheet.png` to
[`portal_gate.png`](portal_gate.png).

## The sheet

Each panel is a 1600×900 shot at half size. Facing angles are in 1/4096 turn on the sim plane. The camera sits
toward sim angle 3584 (−45°).

| | column 1 | column 2 | column 3 |
|---|---|---|---|
| **Top** | 3584, faces the camera, sealed | 3584, faces the camera, **open** | 0, 45° off, sealed |
| **Bottom** | 3072, 45° off the other way, sealed | 512, edge-on (the worst case), sealed | 1536, from behind, sealed |

## What the renders show (my reading, not the owner's)

- **The stone gate:** two stacked-block pillars and a lintel with a raised keystone. Small offsets and rotations
  make the stones read as piled, not as one box. The sketch ink pass outlines the blocks, and they cast the
  long hard shadow like the room's slabs. The stone (`#6F6A66`) is a warm grey a little darker than the Ruins
  slabs.
- **The portal:** a bright green rectangle filling the opening, with a clear spiral vortex around a lighter
  core and a brighter rim against the stone. It glows (the HDR glow is on), and a soft green pool of light lies
  on the floor in front.
- **Sealed against open (top left against top middle):** sealed is visibly darker and greyer under the veil.
  Open is brighter and the floor glow is stronger. The slower swirl when sealed is an animation and can't be
  seen in a still.
- **Angles:** at ±45° (0 and 3072) the portal still reads well. Edge-on (512), only the pillar and the floor
  glow show, as expected for a flat door; the integrator should avoid placing the gate edge-on to the camera.
  From behind (1536), the gate looks the same as from the front, because the portal is double-sided.
- **A problem found and fixed:** on the first run the portal drew with `depth_draw_never`. The ink pass then
  outlined the grass and rubble *behind* the portal on top of it, as small dark marks inside the green. The
  shader now uses `depth_prepass_alpha`, so the opaque interior hides what's behind it. The first run's portal
  also read muddy and dark; the colours, the spiral weighting and the rim were brightened before this sheet.
- **Not checked:** the Compatibility renderer, real GPUs and the owner's screen. Not run.
- **Does it read as "a Rick and Morty portal in a door shape"?** `OWNER ONLY`.

## Re-render: the portal turns blue (v0.2.0 K, owner line L12)

The owner asked: "the portal should be blue, not green". `PortalGate` now sets the swirl to a deep electric
blue (`SWIRL_DEEP` 0.03/0.08/0.52, `SWIRL_MID` 0.13/0.36/1.0) with cyan-white highlights (`SWIRL_LIGHT`
0.74/0.9/1.0), a blue floor glow (`GLOW` 0.16/0.36/1.0) and a blue light (`PORTAL_BLUE` `#2E62FF`). The unit
test checks every swirl colour is blue-dominant and that the mid tone, the light and the glow sit at a hue more
than 0.07 past the player's cyan (`player_core` `#2BC4E2`). [`portal_gate.png`](portal_gate.png) was replaced
by hand with the new sheet from `build/shots/v0.2.0/portal/portal_gate_sheet.png`; the panel layout is the same
as above.

- **Build:** a working tree based on `1a02ecb` with the step-K changes uncommitted (they are in the K commit).
- **Machine:** the same cloud container, llvmpipe under xvfb.

Command (same as above), raw output:

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)

portal: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
portal: res://build/shots/v0.2.0/portal/facing_camera_sealed.png
portal: res://build/shots/v0.2.0/portal/facing_camera_open.png
portal: res://build/shots/v0.2.0/portal/facing_0_sealed.png
portal: res://build/shots/v0.2.0/portal/facing_3072_sealed.png
portal: res://build/shots/v0.2.0/portal/facing_512_edge_on_sealed.png
portal: res://build/shots/v0.2.0/portal/facing_1536_back_sealed.png
portal: res://build/shots/v0.2.0/portal/portal_gate_sheet.png 2400x900
exit=0
```

What I saw (my reading, not the owner's): the opening is now a saturated royal/electric blue with a lighter
swirl core and pale cyan-white streaks; it no longer reads green anywhere, and it is clearly deeper than the
player's cyan visor and ring next to it. Sealed (top left) is darker than open (top middle). The floor glow in
front reads **lavender/violet** rather than pure blue on the orange Ruins sand (an additive blue over orange),
the same for the light pool; that may want a tweak if the owner dislikes it. Whether it's the blue the owner
meant: `OWNER ONLY`.

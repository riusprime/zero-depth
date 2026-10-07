# Dash trail, blink flash and item cards (v0.2.0 K, owner lines L12-L13)

**What this proves:** what the new movement effects and the item card look like in the real game
(`main.tscn`, driven by input events), through the real iso camera on the first floor:

- the white trail every dash leaves (`DashTrail`, `src/presentation/world_view/dash_trail.gd`);
- the blue flash at both ends of a blink (`BlinkFlash`, `src/presentation/world_view/blink_flash.gd`);
- the compact item card previewing a pedestal and after a pickup, with the carried-items icon row
  (`ItemCard`, `ItemIconView`, `ItemIcons` in `src/presentation/hud/`);
- all 16 item icons plus the fallback gem, and four cards with this build's real strings.

The blue portal is in [`PORTAL.md`](PORTAL.md) (re-render section) and [`portal_gate.png`](portal_gate.png).

**What it doesn't prove:** feel, readability in motion, or whether these match what the owner pictured. Those are
`OWNER ONLY`. Stills can't show the fades or the spark motion.

- **Build:** a working tree based on `1a02ecb` with the step-K changes uncommitted (they are in the K commit).
  After this run, two files changed only in formatting/comments: `gdformat` reflowed `scripts/shots/vfx_cards.gd`
  and a doc comment in `blink_flash.gd` was rewrapped. No logic changed.
- **Machine:** a cloud container, software Vulkan (llvmpipe) under xvfb. Not the owner's hardware. On this
  renderer several sim ticks pass per rendered frame, so the script grabs frames in `_process` when an effect
  is on screen (two frames after the trigger, so the image shows that state).

## Command

```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/vfx_cards.gd
```

## Raw output (complete; `exit=` appended by the shell)

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)

vfx_cards: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
vfx_cards: dash trail points=10 ghosts=3
vfx_cards: res://build/shots/v0.2.0/vfx_cards/dash_trail.png (frame 56, tick 164)
vfx_cards: blink from (19.37548, -8.224525) to (14.99152, -12.60849), flash progress 0.19
vfx_cards: res://build/shots/v0.2.0/vfx_cards/blink_both_ends.png (frame 93, tick 312)
vfx_cards: preview card 'Twin Arc' / 'Each swing echoes 0.1 s later, at half damage.'
vfx_cards: res://build/shots/v0.2.0/vfx_cards/card_preview.png (frame 130, tick 460)
vfx_cards: pickup card 'Twin Arc' / 'Each swing echoes 0.1 s later, at half damage.' caption 'Picked up'; icon row 1
vfx_cards: res://build/shots/v0.2.0/vfx_cards/card_pickup.png (frame 135, tick 480)
vfx_cards: res://build/shots/v0.2.0/vfx_cards/icons_and_cards.png (frame 141, tick 480)
vfx_cards: res://build/shots/v0.2.0/vfx_cards/vfx_cards_sheet.png 2400x900 ["dash_trail", "blink_both_ends", "card_preview", "card_pickup", "icons_and_cards"]
exit=0
```

The contact sheet was copied by hand from `build/shots/v0.2.0/vfx_cards/vfx_cards_sheet.png` to
[`vfx_cards.png`](vfx_cards.png).

## The sheet

Each panel is a 1600×900 shot at half size.

| | column 1 | column 2 | column 3 |
|---|---|---|---|
| **Top** | dash trail, just after a dash right | a blink to the left, both ends | the card previewing a pedestal (2 m away) |
| **Bottom** | the card after the pickup, icon row bottom right | the 16 icons + the gem, four cards | (empty) |

## What the renders show (my reading, not the owner's)

- **Dash:** a soft white band runs along the dash path at body height, with three white afterimages of the
  wanderer's silhouette (cloak cone + hood) spaced along it. It reads as white on the orange Ruins sand, partly
  because the colour is over 1.0 and the glow catches it. The first run (before raising the brightness) looked
  greyer; the sheet is the brighter version. Kinetic Dash's cyan afterimages were not in this shot (no item
  owned); the unit test checks they draw at a higher render priority than the white trail.
- **Blink:** a blue column of light stands at each end, brightest at the foot and fading upward, with a blue
  pool on the ground and the blue light tinting the nearby wall face. The first attempt used additive blending
  and read **white/lavender** on the light sand; it now uses alpha blending with an HDR blue and reads clearly
  blue. The sparks are small and hard to see in a still (a few blue specks at the foot of the columns).
- **Card (preview, pickup):** a small dark rounded card at the bottom centre with a lilac left edge, the Twin
  Arc symbol (two arcs), the name in the item colour and its sentence (here wrapping to two lines). After the
  pickup a small "Picked up" note sits right of the name, the pedestal is gone, and one icon tile (Twin Arc)
  sits in the bottom-right corner. At 1600×900 the card is about 275 px wide.
- **Icons:** all 16 symbols are distinct and readable at 96 px: blade, two arcs, flame, three darts, double
  chevron, bouncing arrow, speed lines + ball, bolt, blood drop, chain links, sword + arrow, snowflake, spiky
  ring, downward blade, winged boot, ring with a burst; an unknown id gets the gem. At the 40 px row size they
  still read in the pickup shot, but small. The momentum symbol is the weakest (it reads as two arrows).
- **Card sentences:** this build's descriptions are still the long ones (Ember Edge and Overcharge wrap to
  three lines and the panel's cards overlap a little because the holder is 100 px tall); another step is
  shortening them to one sentence. The eight new items have no strings or content in this build, so the
  sheet's cards use existing items only.
- **Portal:** see [`PORTAL.md`](PORTAL.md).
- **Not checked:** Spanish card layout, the Compatibility renderer, real GPUs, the owner's screen. Not run.

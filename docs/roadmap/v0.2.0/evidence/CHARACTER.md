# The player's hooded wanderer (v0.2.0 G, owner request 2026-10-07)

**What this proves:** what `PlayerAvatar` (`src/presentation/world_view/player_avatar.gd`) looks like under the real
iso camera (`IsoRig`: yaw 45°, pitch 35.26°), next to the owner's reference
(`docs/art/main_character_visual_reference.png`, committed on `main`), and how it moves in the real game when it's
driven by key and mouse events.
**What it doesn't prove:** whether it looks right or feels good to the owner. Feel and taste are `OWNER ONLY`.

- **Build:** the renders ran on a working tree based on `088a852` with this step's files uncommitted. The code and
  the shot script were the same as the committed ones; only this doc and the copied PNGs were added after the run.
- **Machine:** a cloud container, software Vulkan (llvmpipe), under xvfb. This is not the owner's hardware. On this
  renderer several physics ticks run per rendered frame (about 4), so the frames are far apart in time.

## Commands

```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/character.gd \
  -- mode=turnaround ref=/home/user/zero-depth/docs/art/main_character_visual_reference.png
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/character.gd -- mode=motion
```

(`ref=` points at the reference in the main checkout; the worktree had no copy of it.)

## Raw output (complete; the exit code wasn't printed, and the shell reported no failure)

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)

character: res://build/shots/v0.1.0-dev/character/turnaround.png reference=/home/user/zero-depth/docs/art/main_character_visual_reference.png
```

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)

character: res://build/shots/v0.1.0-dev/character/motion.png frames=21 full=res://build/shots/v0.1.0-dev/character/motion_full.png
character: cells (row-major) = idle t24, walk t36, walk t48, walk t60, walk t72, dash t80, dash t84, dash t88, dash t92, dash t96, dash t100, stop t120, stop t132, stop t144, stop t156, swing t172, swing t176, swing t180, swing t184, swing t188, swing t192
```

(The build folder says `v0.1.0-dev` because that's what `GameVersion.label()` returns on this branch.) The sheets were
copied by hand: `turnaround.png` → [`character_turnaround.png`](character_turnaround.png), `motion.png` →
[`character_motion.png`](character_motion.png).

## Turnaround sheet ([`character_turnaround.png`](character_turnaround.png))

- **Left, top row:** five avatars on Ruins-coloured ground under the game's light. They face front, 3/4, side, 3/4
  back and back. The camera is the real `IsoRig`, with its view zoomed to 3.4 m so the figure fills the cell. There's
  no team ring here, because the ring belongs to `ActorViews`. The motion sheet shows it.
- **Left, bottom row:** poses driven through `PlayerAvatar.apply_state` with made-up sim state, not from the game. In
  order: idle; walking in place at 6 m/s; dashing at about 27 m/s; swinging (tick 6 of 14); guarding; dead.
- **Right:** the owner's reference, scaled to the sheet's height.

**What I see that matches the reference:**
- The figure is a big, boxy, off-white hood over a wide, faceted, tent-shaped cloak, with two short dark legs under
  it.
- The front of the hood is a dark face plate inside a light rim, with a small glowing cyan rectangle in it.
- The back views show only cloak and hood, and the hood rises to a peak.
- It's flat-shaded, with lighter and darker facets, and its shading sits close to the reference's beige.

**What still differs (honestly):**
- Every body piece has the game's black stencil rim outline (PRESENTATION §3). The reference has no outlines, so mine
  looks heavier and more "inked" at this zoom.
- The reference hood is a rounder, chamfered box whose top reads as a flat face from the front. Mine is a box under a
  four-faced roof. From the front views a low pointed roof shows above the face, where the reference shows a flat top.
- The reference visor is a small rectangle placed a bit off-centre. Mine is centred and somewhat larger relative to
  the face plate.
- The reference cloak is a smoother pyramid with fewer, larger facets and a slightly concave hem. Mine is an 8-cornered
  diamond (four long corners and four short ones), and in the side views it reads as more star-shaped and pointier at
  the hem.
- The reference legs read longer and more clearly as two separate legs. In my front views the two legs often merge
  into one dark block under the hem.
- The dead pose reads as a pale lump. It's recognisable as collapsed but not as a body.

## Motion sheet ([`character_motion.png`](character_motion.png))

The script boots `main.tscn`, presses Enter twice (Play, then the default utility), and drives the floor with
`Input.parse_input_event` only:
- tick 30: mouse to the lower left (aim toward the camera) and hold A;
- tick 80: Space (dash);
- tick 110: release A;
- tick 170: left click aiming lower left (a swing).

The cells are 220 px crops around the player, scaled ×2. They're grabbed in `_process` and labelled by sim tick in
the output line above (row-major, 6 per row). The crop centre comes from the player node's interpolated position.

**What the frames show:**
- **idle t24:** the wanderer from behind (the starting aim points away), with its cyan ring.
- **walk t36–t72:** the hood turns toward the lower-left aim, the cyan visor shows, the legs are visibly apart in
  stride, and the cloak's trailing edge swings out behind the motion.
- **dash t80–t100:**
  - In t80 and t84 the player is at the right edge of the crop. The camera and the crop lag the dash, so these two
    cells are badly framed.
  - From t88 to t96 the figure leans hard into the dash, its cloak streams far back (to the right) and the legs trail.
  - By t100 the cloak is coming back in.
- **stop t120–t156:** the figure stands still by a wall (which the occlusion fade has made see-through). The cloak
  is back to its rest shape, with no visible jitter between these four frames.
- **swing t172–t192:** the slash fan draws toward the lower left and the visor faces it. **I can't see a clear body
  twist in these frames:** the twist is quick, and about 4 ticks pass between grabs. The unit tests don't check the
  twist either.

**Not shown in the game frames:** guard and death. They appear only as synthetic poses in the turnaround sheet's
bottom row and in the unit tests. How smooth it is at 30–144 fps on real hardware: `NOT YET RUN` (`OWNER ONLY` for
feel).

## Tests

`tests/unit/presentation/test_player_avatar.gd` (8 tests) covers:
- the parts (hood, visor, face, cloak, two legs);
- X-ray twins only with the `xray` technique;
- the visor facing four aim angles through a real `World` and `WorldReader`;
- the cloak lagging during motion and a turn, then settling (offset < 5 mm after 3 s still);
- the cloak staying within its clamp at 30, 60 and 144 fps steps through dashes;
- a dash flaring the cloak more than a walk;
- a dead player slumping (the hood drops more than 15 cm and the visor dims);
- the legs striding in opposition and coming together at rest.

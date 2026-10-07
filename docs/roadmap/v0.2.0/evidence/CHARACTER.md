# The player's hooded wanderer (v0.2.0 G, owner request 2026-10-07)

**What this proves:** what `PlayerAvatar` (`src/presentation/world_view/player_avatar.gd`) looks like under the real
iso camera (`IsoRig`: yaw 45°, pitch 35.26°), next to the owner's reference
(`docs/art/main_character_visual_reference.png`, committed on `main`), and how it moves in the real game when it's
driven by key and mouse events.
**What it doesn't prove:** whether it looks right or feels good to the owner. Feel and taste are `OWNER ONLY`.

- **Build:** the renders ran on a working tree based on `701302f` (the first pass) with this refinement round's
  changes uncommitted. The code and the shot script were the same as the committed ones; only this doc and the
  copied PNGs were added after the run.
- **Machine:** a cloud container, software Vulkan (llvmpipe), under xvfb. This is not the owner's hardware. On this
  renderer about 4 physics ticks run per rendered frame.

## Round 2 (coordinator's refinement list, 2026-10-07)

The coordinator asked for one refinement round toward the reference. I compared each render side by side with the
reference turnaround while iterating. Changes:
1. **Cloak:** a square tent (frustum) with its corners on the diagonals, as the reference shows in its 3/4 views. Its
   four large faces each have a soft vertical fold down the middle. There are no star points. The hem is nearly level
   (a few cm uneven) at 0.40 m, so the legs show. Face-on, the hem is about 1.7× the hood's width (0.62 m vs 0.37 m).
   It is now one ring of 8 spring points; the second, lower ring is gone.
2. **Hood:** a taller box whose lower sides and back taper in, under a low roof that peaks toward the back. The front
   is open, with the dark face set 3 cm back. The hood sits slightly forward and tips forward about 15°, as in the
   reference. It is about 0.38 m of the figure's roughly 1.15 m, a third rather than the 40% the coordinator asked for.
3. **Visor:** smaller relative to the face (about 7 × 9 cm on a 36 cm face, after the hood's 0.92 scale) and set off-centre.
4. **Legs:** longer (0.41 m), a lighter charcoal (`#4A4C56`) with darker boots, and a gap between them about one leg
   wide.
5. **Outline:** the avatar's rim is 0.018 m, about half the other actors' 0.035. The X-ray twins on the hood and the
   cloak are unchanged.
6. **Dead pose:** the hips sit down, the cloak pools wider and lower, the hood droops and rolls on top with a dimmed
   visor, and the boots stick out at the front.
7. **Swing and dash capture:** around the dash and the swing, the shot script now lets the sim step only once per
   rendered frame (it toggles `SimDriver.paused`, in the shot script only). The frames land 2 ticks apart. I tried
   `Engine.time_scale` first, and it didn't change the ticks per frame here.

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

character: res://build/shots/v0.1.0-dev/character/motion.png frames=25 full=res://build/shots/v0.1.0-dev/character/motion_full.png
character: cells (row-major) = idle t24, walk t36, walk t48, walk t60, walk t72, dash t80, dash t82, dash t84, dash t86, dash t88, dash t90, dash t92, dash t94, stop t111, stop t123, stop t135, stop t147, swing t171, swing t173, swing t175, swing t177, swing t179, swing t181, swing t183, swing t185
```

(The build folder says `v0.1.0-dev` because that's what `GameVersion.label()` returns on this branch.) The sheets were
copied by hand: `turnaround.png` → [`character_turnaround.png`](character_turnaround.png), `motion.png` →
[`character_motion.png`](character_motion.png).

## Turnaround sheet ([`character_turnaround.png`](character_turnaround.png))

- **Left, top row:** five avatars on Ruins-coloured ground under the game's light. They face front, 3/4, side, 3/4
  back and back. The camera is the real `IsoRig`, with its view zoomed to 3.4 m. There's no team ring here, because
  the ring belongs to `ActorViews`. The motion sheet shows it.
- **Left, bottom row:** poses driven through `PlayerAvatar.apply_state` with made-up sim state, not from the game. In
  order: idle; walking in place at 6 m/s; dashing at about 27 m/s; swinging (tick 6 of 14); guarding; dead.
- **Right:** the owner's reference, scaled to the sheet's height.

**What I see that matches the reference now:**
- **3/4 views:** in the 3/4 front and 3/4 back views (top row, cells 2 and 4), the cloak reads as the reference's
  tent. A corner points at the viewer, there are big flat facets, and the hem makes a V toward the viewer with
  corners out to the sides.
- **Hood:** a forward-tipped box with a dark recessed face and a small off-centre cyan visor.
- **Legs:** two dark legs with boots, visibly separate in the 3/4 and walking views.
- **Back:** the back views show only the cloak and the hood.
- **Outline:** the rim is noticeably lighter than in round 1.

**What still differs (honestly):**
- **Face-on views:** the front, side and back views (cells 1, 3 and 5) see a flat side of the square cloak, so the
  figure reads boxy, almost a rectangle, rather than a tent. The reference shows no face-on views; all five of its
  views look roughly 3/4. In-game, the camera is fixed at 45° yaw, so face-on happens whenever you aim or walk along
  a screen diagonal.
- **Roof:** from the back, the reference hood rises to a clear centred peak. My roof is low with its peak toward the
  back, so from behind it reads as a slanted top more than a point. From the front it reads closer to the
  reference's flat top.
- **Hood seam:** in the 3/4-back view (cell 4) a small dark notch shows between the hood and the cloak's shoulders,
  because the hood sits slightly forward. The reference has no gap.
- **Legs face-on:** in the face-on front view the two legs still read as nearly one dark block.
- **Shape and shading:** the reference is softer, with rounded-looking edges and gentle shading. Mine is hard-faceted,
  with the game's ink rim.
- **Dead pose:** it now shows the cloak pooled with the hood lying on top and the boots out in front. It reads as the
  character collapsed, but the hood looks a little detached from the cloak.
- **Dash pose:** the cloak streams back into a large flat sheet. That's stronger than "a bit"; tuning it is the
  owner's call (`OWNER ONLY` for feel).

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
- **walk t36–t72:** the hood turns toward the lower-left aim, the cyan visor shows, the legs are apart in stride, and
  the cloak's trailing edge swings out behind the motion.
- **dash t80–t94 (2 ticks apart):** the figure leans into the dash and the cloak streams back into a flat sheet. At
  t88 it passes a wall edge, and a small cyan triangle shows at its feet. I believe that's another view's dash effect,
  not the avatar, but I didn't check. By t92–t94 the cloak is coming back in.
- **stop t111–t147:** the figure stands still by a wall (made see-through by the occlusion fade). The cloak is back to
  its tent shape, with no visible jitter between these four frames.
- **swing t171–t185 (2 ticks apart):** at t171 the hood is turned away from the slash (the wind-back). At t173 it is
  turning. From t175 on, the visor faces the slash toward the lower left. This is the body twist, visible now. The
  slash fan sweeps across the cells.

**Not shown in the game frames:** guard and death. They appear only as synthetic poses in the turnaround sheet's
bottom row and in the unit tests. How smooth it is at 30–144 fps on real hardware: `NOT YET RUN` (`OWNER ONLY` for
feel).

## Tests

`tests/unit/presentation/test_player_avatar.gd` (8 tests, unchanged in round 2, all passing) covers:
- the parts (hood, visor, face, cloak, two legs);
- X-ray twins only with the `xray` technique;
- the visor facing four aim angles through a real `World` and `WorldReader`;
- the cloak lagging during motion and a turn, then settling (offset < 5 mm after 3 s still);
- the cloak staying within its clamp at 30, 60 and 144 fps steps through dashes;
- a dash flaring the cloak more than a walk;
- a dead player slumping (the hood drops more than 15 cm and the visor dims);
- the legs striding in opposition and coming together at rest.

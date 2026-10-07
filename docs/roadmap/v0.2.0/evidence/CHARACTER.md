# The player's hooded wanderer (v0.2.0 G / G2, owner requests 2026-10-07)

**What this proves:** what `PlayerAvatar` (`src/presentation/world_view/player_avatar.gd`) looks like next to the
owner's detailed character sheet ([`docs/art/main-character-sheet.png`](../../../art/main-character-sheet.png), the
primary reference), from a sheet-like camera and from the real iso camera (`IsoRig`: yaw 45°, pitch 35.26°), and
how it moves in the real game when it's driven by key and mouse events.
**What it doesn't prove:** whether it looks right or feels good to the owner. Feel and taste are `OWNER ONLY`.

- **Build:** the renders and the suite ran on a working tree based on `dbd4f7d` with this round's changes
  uncommitted; the committed code and shot script are the ones that ran. Only this doc and the copied PNGs were
  written after the runs.
- **Machine:** a cloud container, software Vulkan (llvmpipe), under xvfb. This is not the owner's hardware. On this
  renderer about 4 physics ticks run per rendered frame.

## Round 3 (G2): rebuilt to the character sheet

The owner (2026-10-07): "a more detailed view of the character, we should keep working on matching it as much as we
can". I rebuilt the model; the API (`setup`/`sync`/`apply_state`/`advance`), the animation set (idle, walk, dash,
swing, guard, death), the poncho's spring simulation and the X-ray twins are unchanged in kind.

1. **Hood:** a six-sided box: a narrow flat top, sides flaring out to a belt a little below the middle, bevelled in
   under it, and a slight taper toward the open front (every side is flat). It tips forward 0.1 rad. Under the face
   its bottom is cut back so the face's point hangs clear.
2. **Face:** a near-black (`#15161A`) shield set 2 cm back in the opening: a flat top, sides down to the belt, then
   a point at the chin that hangs below the hood, with a small dark wedge behind it so the chin has depth from the
   side.
3. **Visor:** the player cyan (`player_core`, emissive), a landscape rectangle 13 × 8.5 cm, centred, in the face's
   upper half; about 40% of the face's width (a unit test checks 30–50%).
4. **Poncho:** a diamond. Its hem corners point front, right, back and left; a fold point between each pair makes
   every side two big flat facets with a ridge down each corner. The front corner hangs lowest (0.29 m), the back
   next (0.30 m), the side corners highest and widest (0.42 m, 0.47 m out). The neck ring dips to a V-neck notch
   under the chin and rises under the hood's rim at the shoulders and back. The span is about 2.1× the hood's width.
   The underside is a second, inward-facing layer 1 cm inside, in the shaded cream (`#C9B8A6`); the outside is
   `#EBDCCB`. The poncho's frame now turns with the body's facing (plus a third of the swing twist), so the front
   corner and the V-neck stay under the face. Before, it turned with the legs.
5. **Legs:** two 13 cm square charcoal legs (`#3A3D44`), centres 23 cm apart (a gap about one leg wide), with
   lighter (`#50535B`) boot blocks 15.5 × 15 cm and a low toe block stepping forward.
6. **Size:** about 1.11 m from the soles to the top of the hood (hood origin at 0.93 m).
7. **Outline:** the rim is 0.014 m (it was 0.018), against the other actors' 0.035.
8. **Springs:** the 8 hem points are still the damped springs (same constants), so the hem sways, lags, flares on a
   dash and settles.

### The shot script

`scripts/shots/character.gd -- mode=turnaround` now renders into a 1774 × 887 viewport (the sheet's size) on a
dark background (`#252931`, the sheet's), with the four figures at the sheet's x positions, its feet line and its
scale (1.12 m ≈ 490 px):
- **Row A (sheet camera):** orthographic, pitch 20°, lit by a soft key from above and in front (in this row only).
  I picked the pitch by eye; the sheet doesn't give it. Its views don't look like a single consistent camera
  either: the front view looks nearly level, and the back-right view shows a lot of hood top.
- **Row B (in-game camera):** the same figures from `IsoRig`'s pitch 35.26°, under the game's light (StageView's).
- **Row C:** six poses driven through `PlayerAvatar.apply_state` under the iso camera (idle, walking, dashing,
  swinging, guarding, dead), as before.

**The views' angles.** The sheet's views aren't at even 45° steps. From how much of the hood's side and face each
one shows, I estimated them at about 0° (front), 60° (right-front), 75° (right) and 155° (back-right) from the
front. The renders use 0°, 60°, 75° and 155° (sim aims −45°, 15°, 30°, 110° under the iso yaw). That's my
estimate, not a measurement.

`compare.png` stacks the owner's sheet, row A and row B at the same scale, then shrinks the whole image to 3/4.

## Commands

```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/character.gd \
  -- mode=turnaround ref=res://docs/art/main-character-sheet.png
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/character.gd -- mode=motion
```

## Raw output (complete; both runs printed `exit=0` from `echo exit=$?`)

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)

character: res://build/shots/v0.2.0-dev/character/turnaround.png views=front, right-front, right, back-right; rows: sheet camera, iso camera, poses
character: res://build/shots/v0.2.0-dev/character/compare.png reference=res://docs/art/main-character-sheet.png
exit=0
```

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)

character: res://build/shots/v0.2.0-dev/character/motion.png frames=25 full=res://build/shots/v0.2.0-dev/character/motion_full.png
character: cells (row-major) = idle t24, walk t36, walk t48, walk t60, walk t72, dash t80, dash t82, dash t84, dash t86, dash t88, dash t90, dash t92, dash t94, stop t111, stop t123, stop t135, stop t147, swing t171, swing t173, swing t175, swing t177, swing t179, swing t181, swing t183, swing t185
exit=0
```

I copied the sheets by hand: `compare.png` → [`character_sheet_compare.png`](character_sheet_compare.png),
`turnaround.png` → [`character_turnaround.png`](character_turnaround.png), `motion.png` →
[`character_motion.png`](character_motion.png).

## Sheet vs render, view by view ([`character_sheet_compare.png`](character_sheet_compare.png))

Top: the owner's sheet. Middle: row A (the sheet-like camera). Bottom: row B (the in-game iso camera). I compared
the silhouettes view by view while iterating, over several render passes.

**Front**
- *Matches:* a shield-shaped hood with a flat top and sides that flare out, then slant in toward the chin. A black
  shield face with a centred, landscape cyan visor. The V-neck under the chin. The poncho flares to wide side
  corners, with a downward V at the front and darker underside facets showing below the side corners. Two separate
  legs with lighter boots.
- *Differs:* more of my hood's top face shows above the face. On the sheet, the face starts about 15% down from the
  top; on mine it's about 20%. My face fills more of the hood's front, so there's less cream rim beside it. The
  front V and the side corners sit a few percent lower than the sheet's. My boots are a little shorter.

**Right-front**
- *Matches:* the hood reads as a forward box, with the black face plane and visor on its right. The poncho is a
  pyramid with a ridge toward the viewer. The hood sits on the cloak with a dark seam. The boots with toes show
  under the hem.
- *Differs:* my hood is slightly smaller relative to the poncho. The sheet's far (left) corner flares a little
  wider and lower. My figure is turned about 60° by my estimate.

**Right**
- *Matches:* the hood box in profile with the face plane at its front edge, the visor showing slightly, and the
  dark chin below the box. The poncho's near side corner makes the lowest point in the middle (the V), with front
  and back corners at either end. The legs and boots show under the hem.
- *Differs:* the sheet's hood box looks a little longer and lower. My poncho's front corner (right end) hangs a bit
  lower than its back corner; the sheet has them level.

**Back-right**
- *Matches:* the hood from behind is a box with a narrower top that flares out, sitting on a pyramid poncho with a
  ridge down the middle. The boots show under the hem.
- *Differs:* the sheet shows more of the hood's top (it looks from higher up in this view). My poncho's back corner
  hangs a bit lower than the sheet's, so less leg shows.

**All views**
- My render is hard-faceted with the game's ink rim. The sheet is softer, with gentle edge highlights.
- Row A's lighting is a stand-in I chose. The tones differ from the sheet in places: my right-side hood faces are
  greyer.

**In-game camera (row B)**
- From the game's pitch, the hood's top face is large in every view, and the poncho covers most of the legs from
  the front.
- Under the game's light, the faces turned away from the light (back-right, and the hood sides) are flat grey.
- A light sliver of the poncho's underside shows at the neck in the 3/4 views.
- Jagged shadow edges from the hood fall on the poncho. I take these to be shadow-map aliasing on this software
  renderer, but I didn't check further.

## Motion sheet ([`character_motion.png`](character_motion.png))

The script boots `main.tscn`, presses Enter twice (Play, then the default utility), and drives the floor with
`Input.parse_input_event` only:
- tick 30: mouse to the lower left (aim toward the camera) and hold A;
- tick 80: Space (dash);
- tick 110: release A;
- tick 170: left click aiming lower left (a swing).

The cells are 220 px crops around the player, scaled ×2, at the game's own camera distance.

**What the frames show:**
- **idle t24:** the wanderer from behind (the starting aim points away), with its cyan ring.
- **walk t36–t72:** the hood turns to the lower-left aim, and the visor and the black face show. The poncho trails
  behind the motion.
- **dash t80–t94:** the figure leans in and the poncho streams back into a flat sheet behind it. At t86 a small cyan
  triangle shows at its feet. It was also there last round, and I believe it's another view's dash effect, but I
  didn't check.
- **stop t111–t147:** the figure stands by a wall (faded by occlusion). I saw no jitter between these four frames.
- **swing t171–t185:** at t171 the hood is turned away (the wind-back); from t173 on the visor faces the slash.
- At this distance, the wanderer reads as a cream hooded figure with a dark face and a cyan visor. Of the diamond,
  only the front V and the trailing points are readable; the V-neck isn't.

**Not shown in the game frames:** guard and death. They appear only as synthetic poses in the turnaround's row C
and in the unit tests. Smoothness at 30–144 fps on real hardware: `NOT YET RUN` (`OWNER ONLY` for feel).

## Tests

`tests/unit/presentation/test_player_avatar.gd`: 10 tests, all passing in the suite run below. The 8 earlier tests
are unchanged; 2 are new:
- **The poncho is a diamond pointing where the wanderer faces** (three aims). The front hem corner points along
  the aim and hangs lower than every other hem point. The side-to-side span is 1.8–2.4× the hood mesh's width. The
  side corners reach further out than the front corner.
- **The visor is centred and landscape in the upper face:** wider than tall, centred, above the face's mid-height,
  and 30–50% of the face's width.

New read-only accessor for the first test: `PlayerAvatar.cloak_hem()`, which returns a copy of the hem points.

Suite: `bash scripts/verify.sh` exited 0. Its last lines:

```
Scripts              55
Tests               210
Passing Tests       210
Asserts           54619
Time              31.986s

---- All tests passed! ----
Results saved to build/gut.xml
check_gut_log: ok (210 passing, minimum 208)
```

Lint: `gdformat --check src scripts tests` printed "176 files would be left unchanged" (exit 0). `gdlint src scripts
tests` printed "Success: no problems found" (exit 0).

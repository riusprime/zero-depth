# Boss skeletons and animations (Blender)

These scripts turn a boss's delivered model into a skinned model that carries its own animations, the file the game
loads from `assets/models/bosses/`. They run inside Blender (5.2 was used) in background mode; nothing here runs in
Godot. The game plays an animation in the file in place of its code clip of the same name, or of the clips the
avatar's `_owner_plays()` table gives it (`BossAnimator.bind_owner`).

## The Twin Wardens

```bash
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
S=scripts/assets/boss_anim
export ZD_ANIM_DIR=build/anim/twin_warden            # the work folder: src.blend, rig.blend, anim.blend, out/
# 1. the delivered model (the file as it was before it was skinned: `git show <sha>:assets/models/bosses/<id>.glb`)
"$B" -b --python $S/import_src.py -- path/to/delivered/boss_twin_warden_amber.glb
# 2. the skeleton and the skin            (the violet: warden_violet_rig.py, with its own ZD_ANIM_DIR)
"$B" -b "$ZD_ANIM_DIR/src.blend" --python $S/warden_amber_rig.py
# 3. the animations: idle, walk, cast, swipe (the violet is animated as the amber's mirror image)
"$B" -b "$ZD_ANIM_DIR/rig.blend" --python $S/warden_anim.py
# 4. look at it: frame strips and a video per clip, or four views of one frame
"$B" -b "$ZD_ANIM_DIR/anim.blend" --python $S/preview.py -- swipe 0,6,10,12,14,16,18,30 video
"$B" -b "$ZD_ANIM_DIR/anim.blend" --python $S/closeup.py -- swipe 11 1.3 3.0
# 5. the file for the game; copy it over assets/models/bosses/<id>.glb and update the hash in assets/models/manifest.json
"$B" -b "$ZD_ANIM_DIR/anim.blend" --python $S/export.py
```

## How it is put together

- `poser.py`: a pose is a table of bone operations in the figure's own space (a rotation on top of the parent, a
  rotation from rest, an aim, a two-bone reach for a leg or an arm). It solves the table into bone rotations and keys
  them. No constraints: what is keyed is what the game gets.
- `warden_*_rig.py`: the bones (measured on renders of the model), automatic weights on a welded copy, then the
  rules that make armour rigid: the sword, the shield and the helm each on one bone; cloth beside an arm back to the
  cloak's bones.
- `plates.py`: the shoulder plates are cut out of the fused shell into their own closed pieces, each on its own bone,
  and the hole left in the body is closed. A plate follows the chest and a third of the collarbone's swing.
- `warden_anim.py`: every clip is a function from time to a pose. A loop's terms all repeat over the loop; an attack
  is built from a few eased ramps (the wind, the strike, the carry past, the return) that each joint reads a little
  later than the one above it.

## Adding a move

A new move that should reuse an animation needs only a row in the avatar's `OWNER_PLAYS` (the clip's name, the
animation, the seconds of its strike pose and of the end of its active part). A new animation is a new pose function
in `warden_anim.py`, keyed like the others; the bones are already there for it.

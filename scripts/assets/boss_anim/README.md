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

## The other bosses

Each has its own folder here: `clockwork_judge/`, `tidecaller/`, `warlord/`, `lantern_shade/`. A folder is the set of scripts its model was built with, kept as it was run: its own copies of `zdlib.py`, `poser.py`, `preview.py`, `closeup.py` and `export.py` (they differ from the ones above: other camera sizes, extra pose operations) beside its `<boss>_rig.py` and `<boss>_anim.py`. They take the folder above `scripts/` as the work folder, so to rebuild a model copy its folder to `build/anim/<boss>/scripts/`, put the delivered model's `src.blend` beside it (see `import_src.py`) and run the rig, then the animation, then the export, as for the Wardens.

What they add to the method: hard-surface pieces picked by flooding the welded mesh inside boxes and cut free with their own seam vertices (the Judge); a model skinned as one fused surface with rigid pieces picked by position and texture colour (the Tidecaller); a delivered skeleton kept, its names and rests unchanged, with bones added (the Warlord); everything that hangs simulated as springs and pendulums over the frames and baked to keys (the Lantern Shade, the Tidecaller's bell).

In the game a file's animation writes the bones it keys and the code clips that still play (flinch, stagger, roar, a shield lift) are added on top (`BonePoser.lay_over`), so an animation needs no track for what the code should own.

## The final boss

`final_colossus/`, `final_prism/` and `final_nemesis/` hold the three bodies' scripts, kept as they were run, like the
other bosses' folders. Each works at ten times the delivered size facing -Y and its `export.py` turns and scales the
result back to the delivered frame. The bodies hand over in the game through two matched pairs: the Colossus's `break`
and the Prism's `form`, the Prism's `break` and the Nemesis's `form`; a pair is authored against the other's described
pose, so when one end changes, re-measure both in the game (`FinalBodyAvatar` plays a `break` through the shatter and a
rise in place). A crystal's bone has its Y along the crystal's long axis, so a turn about Y leaves its tip still: the
Prism's turn is baked (one turn per 10 s loop, every clip starting and ending on the idle's first angles), the
Colossus's is added by its avatar in frame time.

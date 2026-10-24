# Hub editor

Open `tools/hub_editor/hub_editor.tscn` in the Godot editor. It draws the hub the way the game does: the floor, the
walls, the gate and the Portal Machine stay put, and every piece with a place in `data/hub/rune_ring.tres` gets a
handle you can drag (`Station_archive`, `Pillar_2`, `Prop_3_hub_crystal_planter`, `Spawn`, `Alcove`). Click a piece in
the 3D view, or pick it in the Scene dock, and move it with the move gizmo; it stays on the floor and turns to face
the middle like it does in game. When you're happy, select the `HubEditor` root and press **Save to data** in the
Inspector: the new places are written to the hub file (3 decimals). **Reload from data** throws away moves you haven't
saved. The Output panel warns when a piece overlaps another piece or the machine, or sits past the wall. You don't
need to save the scene itself. Saving changes only the numbers of the pieces you moved and leaves the rest of the file
exactly as it was, so the diff shows just your moves; if the file doesn't have a line the editor expects, it saves
nothing and says why in the Output panel. The scene is never in the game export.

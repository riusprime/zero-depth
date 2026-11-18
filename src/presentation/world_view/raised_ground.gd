class_name RaisedGround
extends Node3D
## A part of the view with a top an actor can stand on (an altar's stone, a Foundry slab's plinth). The sim is a flat
## plane (ROADMAP §6), so ActorViews and CritterCrowd lift whoever stands over one to its top instead of drawing them
## sunk into it (presentation only, EI-07).


## The height (m) of the top under the floor point `at` (this node's parent's frame), 0 off it.
func height_at(_at: Vector3) -> float:
	return 0.0

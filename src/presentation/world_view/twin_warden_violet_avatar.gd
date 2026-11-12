class_name TwinWardenVioletAvatar
extends TwinWardenAvatar
## The Twin Wardens' violet body, the boss's twin: the same figure mirrored (its shield on its right arm),
## violet cracks and visor, the owner's violet file, skinned like the amber one and carrying the same animations
## mirrored. It plays the same clips and the same OWNER_PLAYS, so the two keep time.


func glow_color() -> Color:
	return Color("#B98CFF")


func shield_side() -> float:
	return -1.0


func model_id() -> StringName:
	return &"boss_twin_warden_violet"

class_name TwinWardenVioletAvatar
extends TwinWardenAvatar
## v0.9.0 NB2: the Twin Wardens' violet body, the boss's twin: the same figure mirrored (its shield on its right arm),
## violet cracks and visor, the owner's violet file (cut into Body, Helm, Shield, Sword; BossModels `parts`). It plays
## the same clips as the amber one (TwinWardenClips), so the two keep time.


func glow_color() -> Color:
	return Color("#B98CFF")


func shield_side() -> float:
	return -1.0


func model_id() -> StringName:
	return &"boss_twin_warden_violet"

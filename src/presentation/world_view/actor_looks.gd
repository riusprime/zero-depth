class_name ActorLooks
extends RefCounted
## v0.9.5 PF4 (owner, 2026-10-26: "We can try removing the outlines and see how it looks I don't think they are
## necessary"): the one switch for the stencil outline every actor body piece used to draw as a second pass.
## false: no outline material and no stencil write is created anywhere (enemies, elites, bosses, drones, the hero).
## true: the pre-PF4 look. Presentation only (EI-07).
const OUTLINES := false


## Gives `mat` the stencil outline (`color`, `thickness` thick) when OUTLINES is on; otherwise leaves it plain.
static func outline(mat: StandardMaterial3D, color: Color, thickness: float) -> void:
	if not OUTLINES:
		return
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = color
	mat.stencil_outline_thickness = thickness


## The stencil mode an actor body material has: the outline's while OUTLINES is on, none otherwise (tests).
static func outline_mode() -> int:
	return BaseMaterial3D.STENCIL_MODE_OUTLINE if OUTLINES else BaseMaterial3D.STENCIL_MODE_DISABLED

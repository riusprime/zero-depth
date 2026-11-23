class_name BossKeyLight
extends DirectionalLight3D
## A soft key light from the camera's side that lights only the bosses' bodies. Every biome's sun stands low on the
## far side of the room as the iso camera sees it, so the side of a boss turned to the camera got the ambient light
## only and its dark model read as a black silhouette, while the hero carries its own light (StageKit.hero_light).
## The bodies' meshes carry LAYER (mark) and the light's cull mask is LAYER alone, so the floor, the walls and every
## other actor keep the room's light. No shadow and no specular: it lifts the matte body's own colours, never a shine.

## The render layer (11) the bosses' bodies carry beside their own.
const LAYER := 1 << 10
const ENERGY := 0.75
const COLOR := Color(1.0, 0.95, 0.88)
## Its angle: above the camera's view and turned a little to its side, so the body keeps its shaded side.
const PITCH_DEG := -48.0
const YAW_OFF_DEG := 28.0


func _init() -> void:
	name = "BossKeyLight"
	rotation_degrees = Vector3(PITCH_DEG, IsoRig.YAW_DEG + YAW_OFF_DEG, 0.0)
	light_color = COLOR
	light_energy = ENERGY
	light_specular = 0.0
	light_cull_mask = LAYER
	light_volumetric_fog_energy = 0.0
	sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	shadow_enabled = false


## Puts every mesh under `body` on LAYER too (it keeps its own layers, so the sun and the camera still see it).
static func mark(body: Node) -> void:
	for g: Node in body.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers |= LAYER

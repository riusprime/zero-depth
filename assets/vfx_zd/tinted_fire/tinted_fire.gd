extends Node3D
## v0.10.5 W3-O7 (owner F6, F16): a fire ball from the Binbun fire pack (fire_ball_04: the amber Twin Warden's, beside
## the owner's reference fireballs) whose colours come from PackFx (primary_color, secondary_color, tertiary_color),
## as the pack's VFXController scenes take theirs. Each part's colours are its material_override's shader parameters
## (PackFx gives each instance its own copy). Cosmetic only.

@export var primary_color := Color(1.0, 0.9, 0.8):
	set(value):
		primary_color = value
		_apply(&"primary_color", value)
@export var secondary_color := Color(1.0, 0.3, 0.0):
	set(value):
		secondary_color = value
		_apply(&"secondary_color", value)
@export var tertiary_color := Color(0.0, 0.0, 0.0):
	set(value):
		tertiary_color = value
		_apply(&"tertiary_color", value)


func _ready() -> void:
	_apply(&"primary_color", primary_color)
	_apply(&"secondary_color", secondary_color)
	_apply(&"tertiary_color", tertiary_color)


func _apply(param: StringName, value: Color) -> void:
	for c in get_children():
		var g := c as GeometryInstance3D
		if g != null and g.material_override is ShaderMaterial:
			(g.material_override as ShaderMaterial).set_shader_parameter(param, value)

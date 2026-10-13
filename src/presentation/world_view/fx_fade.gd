class_name FxFade
extends RefCounted
## Short-lived effect meshes that fade out with their life and then go (audit P-5): the ability, element and skill
## views' flashes, rings and lines. Each effect's material is a copy of its view's template in the effect's colour.
## Presentation only: lives are counted in the caller's steps (frames or sim ticks).

## Each live effect: [node, material, steps left, steps in all, kind, alpha].
var list: Array = []


## Puts `n` under `parent` as an effect of `kind` in colour `c` at `alpha`, fading over `steps`.
func add(
	parent: Node,
	n: MeshInstance3D,
	template: StandardMaterial3D,
	c: Color,
	alpha: float,
	kind: StringName,
	steps: int
) -> void:
	var m := template.duplicate() as StandardMaterial3D
	m.albedo_color = Color(c, alpha)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(n)
	list.append([n, m, steps, steps, kind, alpha])


## Ages every effect by `steps`: it fades with its life and goes when the life is out.
func step(steps: int) -> void:
	for k in range(list.size() - 1, -1, -1):
		var fx: Array = list[k]
		fx[2] -= steps
		(fx[1] as StandardMaterial3D).albedo_color.a = fx[5] * maxf(0.0, float(fx[2])) / fx[3]
		if fx[2] <= 0:
			(fx[0] as Node).queue_free()
			list.remove_at(k)


func count_of(kind: StringName) -> int:
	return list.filter(func(f: Array) -> bool: return f[4] == kind).size()

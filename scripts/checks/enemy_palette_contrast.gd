extends SceneTree
## v0.8.0 EC: contrast numbers for the enemy palettes (EnemyPalettes), for the G2 evidence. For each palette and each
## vision (normal, and the three deficiencies simulated as tests/unit/presentation/test_colour_modes.gd does: Machado,
## Oliveira and Fernandes 2009, severity 1.0, in linear RGB; CIE76 ΔE in Lab), it prints:
## - the closest pair of kinds inside one role and across two roles, on the kind's identity colour (the body for
##   current / A / B, the trim for C);
## - the closest any enemy colour comes to a reserved colour (normal vision);
## - each identity colour's luminance contrast against the Ruins and Frozen Shore `ground` tokens.
## Run: godot --headless --path . -s scripts/checks/enemy_palette_contrast.gd
## Writes build/checks/enemy_palette_contrast.txt as well as printing. Quits on every path.

const SIM := {
	&"normal": [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
	&"protanopia":
	[
		[0.152286, 1.052583, -0.204868],
		[0.114503, 0.786281, 0.099216],
		[-0.003882, -0.048116, 1.051998]
	],
	&"deuteranopia":
	[
		[0.367322, 0.860646, -0.227968],
		[0.280085, 0.672501, 0.047413],
		[-0.011820, 0.042940, 0.968881]
	],
	&"tritanopia":
	[
		[1.255528, -0.076749, -0.178779],
		[-0.078411, 0.930809, 0.147602],
		[0.004733, 0.691367, 0.303900]
	],
}
const RESERVED := {
	"player_core": Color("#2BC4E2"),
	"proj_hostile": Color("#FBD07A"),
	"telegraph_hostile": Color("#FF6A3D"),
	"hazard": Color("#E0892B"),
	"heal": Color("#7CF29A"),
	"heat_hot": Color("#FFA63A"),
	"heat_overclock": Color("#FF4A1A"),
}


static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _lab(c: Color, m: Array) -> Vector3:
	var l := [_lin(c.r), _lin(c.g), _lin(c.b)]
	var s := []
	for r in 3:
		s.append(clampf(m[r][0] * l[0] + m[r][1] * l[1] + m[r][2] * l[2], 0.0, 1.0))
	var x: float = (0.4124 * s[0] + 0.3576 * s[1] + 0.1805 * s[2]) / 0.95047
	var y: float = 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2]
	var z: float = (0.0193 * s[0] + 0.1192 * s[1] + 0.9505 * s[2]) / 1.08883
	var f := func(t: float) -> float:
		return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	return Vector3(
		116.0 * f.call(y) - 16.0, 500.0 * (f.call(x) - f.call(y)), 200.0 * (f.call(y) - f.call(z))
	)


static func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _ratio(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _initialize() -> void:
	var out := PackedStringArray()
	var repo := ContentRepository.load_all()
	var grounds := {}
	for b: StringName in [&"ruins", &"frozen_shore"]:
		var def: BiomeDefinition = repo.get_def(&"biomes", b)
		grounds[b] = def.palette.get(&"ground", def.palette.get("ground", Color.BLACK))
	var palettes: Array[StringName] = [EnemyPalettes.CURRENT]
	palettes.append_array(EnemyPalettes.CANDIDATES)
	var ids: Array = EnemyPalettes.ROLES.keys()
	for p in palettes:
		var slot := &"trim" if p == &"c" else &"body"
		out.append("== palette %s (identity slot: %s)" % [p, slot])
		for vision: StringName in SIM:
			var m: Array = SIM[vision]
			var inside := [1e9, ""]
			var across := [1e9, ""]
			for a in ids.size():
				for b in range(a + 1, ids.size()):
					var ia: StringName = ids[a]
					var ib: StringName = ids[b]
					var d := _lab(EnemyPalettes.color_of(ia, slot, p), m).distance_to(
						_lab(EnemyPalettes.color_of(ib, slot, p), m)
					)
					var same: bool = EnemyPalettes.ROLES[ia] == EnemyPalettes.ROLES[ib]
					var best: Array = inside if same else across
					if d < best[0]:
						best[0] = d
						best[1] = "%s/%s" % [ia, ib]
			out.append(
				(
					"  %-12s closest in a role %5.1f (%s); across roles %5.1f (%s)"
					% [vision, inside[0], inside[1], across[0], across[1]]
				)
			)
		var near := [1e9, ""]
		for id: StringName in ids:
			for s in EnemyPalettes.SLOTS:
				for r: String in RESERVED:
					var d := _lab(EnemyPalettes.color_of(id, s, p), SIM[&"normal"]).distance_to(
						_lab(RESERVED[r], SIM[&"normal"])
					)
					if d < near[0]:
						near = [d, "%s %s vs %s" % [id, s, r]]
		out.append("  nearest reserved colour: %.1f (%s)" % near)
		for b: StringName in grounds:
			var lo := [1e9, ""]
			var hi := 0.0
			for id: StringName in ids:
				var r := _ratio(EnemyPalettes.color_of(id, slot, p), grounds[b])
				hi = maxf(hi, r)
				if r < lo[0]:
					lo = [r, id]
			out.append(
				(
					"  vs %s ground %s: luminance contrast %.2f:1 (%s) .. %.2f:1"
					% [b, (grounds[b] as Color).to_html(false), lo[0], lo[1], hi]
				)
			)
	var text := "\n".join(out)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/checks"))
	var f := FileAccess.open("res://build/checks/enemy_palette_contrast.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	quit(0)

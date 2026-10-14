class_name BossShieldView
extends Node3D
## v0.7.5 BF1 (owner N15, "Shielded during big patterns"; BOSS_FIGHTS.md rule 3): while a boss fires its signature
## pattern (WorldReader.boss_shielded) a clear crystal shell in the boss's colour stands round it: low-poly facets that
## turn slowly, a brighter rim, rising in over SHOW_S as the shield comes up and gone when it opens. The player's hits
## spark off it (HitFeel already bursts on TAG_BLOCKED). Also the shell a burst pattern lobs (its telegraph's "lob",
## from the boss to its locked landing circle; v0.7.5 BF2: an egg onto each locked circle of a marks attack with a
## pattern, the Brood Mother's Egg Storm). v0.8.0 FB1 (FINAL_BOSS.md F4): the Colossus's boulders, a code-made 3D
## boulder (faceted dark violet stone with glowing red cracks, BOULDER_M across) tumbling on its arc.
## Looks only (EI-07).

## The shell's colour by boss kind (each boss its own; a test pins that it is never the hero's cyan).
const COLORS := {
	WorldReader.KIND_GATEKEEPER: Color("#FFB45A"),
	WorldReader.KIND_WARLORD: Color("#FF4A5E"),
	WorldReader.KIND_BROOD_MOTHER: Color("#9BE05A"),
	WorldReader.KIND_HIVE_LENS: Color("#FF4AA8"),
	WorldReader.KIND_SIEGE_ENGINE: Color("#FF9A3A"),
	WorldReader.KIND_FOUNDRY: Color("#FFE08A"),
	WorldReader.KIND_COLOSSUS: Color("#C060FF"),  # v0.8.0 FB1: the final boss's violet
	WorldReader.KIND_PRISM: Color("#FF4A6A"),
	WorldReader.KIND_NEMESIS: Color("#B070FF"),
}
const DEFAULT_COLOR := Color("#E6E0FF")
const SHOW_S := 0.15
const SPIN := 0.5
## v0.7.5 BF2: lobbed shells are keyed boss id × LOB_KEYS (a burst's), + 1 + k (marker k's egg).
const LOB_KEYS := 16
## v0.8.0 FB1: the Colossus's boulder: its size (m) and its tumble (radians a second; none with reduced motion).
const BOULDER_M := 1.1
const BOULDER_SPIN := 4.0

## Boss id -> {"shell", "rim": MeshInstance3D, "shown": 0..1, "at", "radius"}.
var _shells := {}
## Boss id -> the lobbed shell's node.
var _lobs := {}
var _lob_mat := StandardMaterial3D.new()
## v0.7.5 BF2: the Brood Mother's eggs: a pale shell glowing acid green.
var _egg_mat := StandardMaterial3D.new()
var _boulder_mat := StandardMaterial3D.new()
## v0.8.0 FB1: the lobs that are boulders (their keys).
var _boulders := {}
var _t := 0.0


func _init() -> void:
	name = "BossShieldView"
	_lob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lob_mat.albedo_color = Color("#2A2422")
	_lob_mat.emission_enabled = true
	_lob_mat.emission = Color("#FF8A4A")
	_lob_mat.emission_energy_multiplier = 0.8
	_egg_mat.albedo_color = Color("#E6E2B8")
	_egg_mat.emission_enabled = true
	_egg_mat.emission = Color("#9BE05A")
	_egg_mat.emission_energy_multiplier = 0.9
	_boulder_mat.albedo_color = Color("#3A3046")
	_boulder_mat.roughness = 0.95
	_boulder_mat.emission_enabled = true
	_boulder_mat.emission = Color("#FF3048")
	_boulder_mat.emission_energy_multiplier = 0.35


func sync(reader: WorldReader) -> void:
	var seen := {}
	var lobs := {}
	var boulders := {}
	for i in reader.actor_count():
		if not WorldReader.is_boss_kind(reader.actor_kind(i)):
			continue
		var id := reader.actor_id(i)
		if reader.boss_shielded(i):
			seen[id] = true
			if not _shells.has(id):
				_shells[id] = _make_shell(COLORS.get(reader.actor_kind(i), DEFAULT_COLOR))
			_shells[id]["at"] = SimPlane.to_3d(reader.actor_pos(i))
			_shells[id]["radius"] = reader.actor_radius(i)
		var tg := reader.telegraph(i)
		if not tg.is_empty() and tg.has("lob"):
			lobs[id * LOB_KEYS] = tg["lob"]
		if not tg.is_empty() and tg.has("items"):  # v0.7.5 BF2: an egg per locked circle
			var items: Array = tg["items"]
			for k in items.size():
				if (items[k] as Dictionary).has("lob"):
					lobs[id * LOB_KEYS + 1 + k] = items[k]["lob"]
					if reader.actor_kind(i) == WorldReader.KIND_COLOSSUS:  # v0.8.0 FB1: a boulder
						boulders[id * LOB_KEYS + 1 + k] = true
	for id in _shells.keys():
		if not seen.has(id):
			(_shells[id]["shell"] as Node).queue_free()
			_shells.erase(id)
	for id in _lobs.keys():
		if not lobs.has(id):
			(_lobs[id] as Node).queue_free()
			_lobs.erase(id)
			_boulders.erase(id)
	for id in lobs:
		if not _lobs.has(id) and boulders.has(id):  # v0.8.0 FB1
			var b := MeshInstance3D.new()
			b.name = "Boulder"
			b.mesh = BossParts.rock(Vector3.ONE * BOULDER_M, 70 + id % 7)
			b.material_override = _boulder_mat
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(b)
			_lobs[id] = b
			_boulders[id] = true
		if not _lobs.has(id):
			var n := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.28
			s.height = 0.56
			s.radial_segments = 8
			s.rings = 4
			n.mesh = s
			n.material_override = _lob_mat if id % LOB_KEYS == 0 else _egg_mat
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(n)
			_lobs[id] = n
		var lob: Dictionary = lobs[id]
		var p := float(lob["progress"]) / 1000.0
		var from: Vector2 = lob["from"]
		var to: Vector2 = lob["to"]
		(_lobs[id] as Node3D).position = SimPlane.to_3d(from.lerp(to, p), 0.8 + 3.2 * p * (1.0 - p))


## How many shells stand now (tests and the tour).
func count() -> int:
	return _shells.size()


func lob_count() -> int:
	return _lobs.size()


## v0.8.0 FB1: the boulders in the air now (tests and the tour).
func boulder_count() -> int:
	return _boulders.size()


func _process(delta: float) -> void:
	_t += delta
	if not ViewPrefs.reduced_motion:  # v0.8.0 FB1: the boulders tumble
		for id in _boulders:
			(_lobs[id] as Node3D).rotation = Vector3(_t * BOULDER_SPIN, _t * 0.7, id * 0.9)
	for id in _shells:
		var s: Dictionary = _shells[id]
		s["shown"] = minf(1.0, float(s["shown"]) + delta / SHOW_S)
		var shell: Node3D = s["shell"]
		var r: float = (float(s["radius"]) + 0.45) * (0.6 + 0.4 * float(s["shown"]))
		shell.position = (s["at"] as Vector3) + Vector3(0, float(s["radius"]) * 0.9, 0)
		shell.scale = Vector3(r, r * 1.15, r)
		shell.rotation = Vector3(0, _t * SPIN, 0)


func _make_shell(c: Color) -> Dictionary:
	var root := Node3D.new()
	root.name = "BossShield"
	var facets := SphereMesh.new()
	facets.radius = 1.0
	facets.height = 2.0
	facets.radial_segments = 7  # few facets: a cut crystal, not a bubble
	facets.rings = 3
	var shell := MeshInstance3D.new()
	shell.mesh = facets
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c, 0.24)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.6
	shell.material_override = m
	var rim := MeshInstance3D.new()
	rim.mesh = facets
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.cull_mode = BaseMaterial3D.CULL_FRONT  # the far side, brighter: the rim reads round the boss
	rm.albedo_color = Color(c.lightened(0.35), 0.4)
	rim.material_override = rm
	rim.scale = Vector3.ONE * 1.04
	for mi: MeshInstance3D in [shell, rim]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	add_child(root)
	return {"shell": root, "shown": 0.0, "at": Vector3.ZERO, "radius": 1.0}

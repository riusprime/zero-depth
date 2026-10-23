class_name AstralSenseView
extends Node3D
## v0.9.0 RB (AFFINITIES.md A4 Astral: "Hidden rune markings, cracked walls and hidden rooms within 8 m pulse
## faintly"): with the Astral affinity, every secret not yet found (WorldReader.secret_spots: the timed door's, the
## rune puzzle's and the cracked wall's doorway, which is also the hidden room's way in) and its scratched rune marking
## (RuneMarkingsView.spots, same order) pulse faintly in the void violet while the hero is within the sense's reach
## (WorldReader.affinity_sense_m). Layered like the hero's runes (AffinityRunes' shader): a soft ground glow, a thin
## rune circle with the astral star, and from Medium up a few motes. Faint on purpose: at most PEAK, fading to nothing
## at the reach's edge. Presentation only: it reads positions and the sense's reach, decides nothing.

const COLOR := Color("#8B55FF")
const PEAK := 0.55
const GLOW_M := 2.4
const CIRCLE_M := 1.1
const MOTES := 5

## One entry per pulse: {node, mats, secret (its index in secret_spots), at (sim plane)}.
var pulses: Array[Dictionary] = []
## Each pulse's strength at the last sync (tests read it; 0 = dark).
var shown := PackedFloat32Array()
var _reach := 8.0
var _t := 0.0


func setup(reader: WorldReader, marking_spots: PackedVector2Array) -> void:
	name = "AstralSense"
	_reach = reader.affinity_sense_m()
	var spots := reader.secret_spots()
	for k in spots.size():
		_add(k, spots[k]["pos"])
		if k < marking_spots.size():
			_add(k, marking_spots[k])
	shown.resize(pulses.size())


func _add(secret: int, at: Vector2) -> void:
	var n := Node3D.new()
	n.name = "Pulse%d" % pulses.size()
	n.position = SimPlane.to_3d(at, 0.0)
	add_child(n)
	var glow := AffinityRunes.quad("Glow", GLOW_M, 2)
	glow.position.y = 0.015
	var circle := AffinityRunes.quad("Circle", CIRCLE_M, 0)
	circle.position.y = 0.035
	var mats: Array[ShaderMaterial] = []
	for q: MeshInstance3D in [glow, circle]:
		var m := q.material_override as ShaderMaterial
		m.set_shader_parameter(&"tint", COLOR)
		m.set_shader_parameter(&"glyph", 4)
		m.set_shader_parameter(&"strength", 0.0)
		mats.append(m)
		n.add_child(q)
	var motes: CPUParticles3D = null
	if ViewPrefs.effects_density != "low":
		motes = AffinityRunes.motes_of(COLOR, CIRCLE_M * 0.4, MOTES)
		motes.emitting = false
		n.add_child(motes)
	n.visible = false
	pulses.append({"node": n, "mats": mats, "secret": secret, "at": at, "motes": motes})


## After every tick: each pulse's strength from the hero's distance (full within half the reach) and the breath.
func sync(reader: WorldReader) -> void:
	var spots := reader.secret_spots()
	var hero := reader.player_pos()
	for k in pulses.size():
		var p: Dictionary = pulses[k]
		var found := int(p["secret"]) >= spots.size() or bool(spots[int(p["secret"])]["found"])
		var d := (Vector2(p["at"]) - hero).length()
		var near := 0.0 if found or d > _reach else clampf((_reach - d) / (_reach * 0.5), 0.0, 1.0)
		shown[k] = near * PEAK
		(p["node"] as Node3D).visible = shown[k] > 0.0
		if p["motes"] != null:
			(p["motes"] as CPUParticles3D).emitting = shown[k] > 0.2


func _process(delta: float) -> void:
	_t += delta
	var breath := 1.0 if ViewPrefs.reduced_motion else 0.6 + 0.4 * sin(_t * 2.6)
	var spin := 0.0 if ViewPrefs.reduced_motion else _t * 0.3
	for k in pulses.size():
		if not (pulses[k]["node"] as Node3D).visible:
			continue
		for m: ShaderMaterial in pulses[k]["mats"]:
			m.set_shader_parameter(&"strength", shown[k] * breath)
			m.set_shader_parameter(&"spin", spin)

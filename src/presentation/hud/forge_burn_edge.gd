class_name ForgeBurnEdge
extends LowHpVignette
## The screen's edge burning while the Foundry's Overpressure burns the floor and the hero stands off every slab: the
## same pulsing edge glow the High Tide's water gives (LowHpVignette), in fire's orange instead of the low-HP red, no
## word. Reads only (EI-07).

const FIRE := Color("#FF6A1F")


func _init() -> void:
	super()
	name = "ForgeBurnEdge"


## True while the floor burns and the hero stands off every slab.
static func burning(reader: WorldReader) -> bool:
	var over: Dictionary = reader.boss_forge().get("overpressure", {})
	return not over.is_empty() and int(over["burn"]) >= 0 and not bool(over["on_slab"])


func _draw() -> void:
	var w := size.x
	var h := size.y
	var d := minf(w, h) * DEPTH
	var edge := Color(FIRE, 1.0)
	var clear := Color(FIRE, 0.0)
	var o := [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
	var i := [Vector2(d, d), Vector2(w - d, d), Vector2(w - d, h - d), Vector2(d, h - d)]
	for k in 4:
		var n := (k + 1) % 4
		draw_polygon(
			PackedVector2Array([o[k], o[n], i[n], i[k]]),
			PackedColorArray([edge, edge, clear, clear])
		)

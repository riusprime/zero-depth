class_name GlareBurst
extends Node2D
## v0.10.5 W3-O15 (owner 2026-11-04: "a glare kind of particle effect more than a burn"): the sparkles and streaks of
## light that fly off a card as it dissolves (CardFx.set_burn). A small particle system drawn by hand and driven by the
## dissolve's own progress (`progress` 0..1, set from the pick panel's outro clock), not by a clock of its own: the
## same progress always draws the same frame, and it never decides anything (EI-07). Additive, moon-blue and silver;
## each particle fades in fast and out over about 0.4–0.6 s of the 0.75 s outro. Fewer particles at a lower effects
## density (ViewPrefs.effects_density); the pick panel shows none under reduced motion (it fades the cards instead).

## Particles per card by effects density.
const COUNT := {"low": 14, "medium": 24, "high": 36}
## When they start (share of the dissolve) and how long they live (share of it: 0.53..0.8 of 0.75 s is 0.4..0.6 s).
const SPAWN_END := 0.45
const LIFE_MIN := 0.53
const LIFE_MAX := 0.8
## One in STREAK_EVERY is a fast streak; the rest are drifting four-point sparkles.
const STREAK_EVERY := 3

var progress := 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()
## The card's size (px, at its centre: this node sits at the card's centre, CardFx).
var card_size := Vector2(275, 450)
var _parts: Array[Dictionary] = []


## A burst for a card of `size` px; `seed_id` makes each card's burst its own (the same every time).
func _init(size: Vector2, seed_id: StringName, density: String) -> void:
	name = "GlareBurst"
	card_size = size
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 1
	var state := absi(String(seed_id).hash()) + 7
	for i in int(COUNT.get(density, COUNT["high"])):
		var streak := i % STREAK_EVERY == 0
		state = _next(state)
		var x := (_unit(state) - 0.5) * size.x * 0.9
		state = _next(state)
		var y := (_unit(state) - 0.35) * size.y * 0.8
		state = _next(state)
		var ang := -PI * 0.5 + (_unit(state) - 0.5) * (2.4 if streak else 1.6)
		state = _next(state)
		var speed := (300.0 + 200.0 * _unit(state)) if streak else (50.0 + 110.0 * _unit(state))
		state = _next(state)
		var life := lerpf(LIFE_MIN, LIFE_MAX, _unit(state))
		state = _next(state)
		var born := _unit(state) * minf(SPAWN_END, 1.0 - life)  # gone by the dissolve's end
		state = _next(state)
		var r := (6.0 + 8.0 * _unit(state)) if not streak else 1.6
		var part := {
			"at": Vector2(x, y),
			"vel": Vector2(cos(ang), sin(ang)) * speed,
			"born": born,
			"life": life,
			"r": r,
			"streak": streak,
			"blue": i % 2 == 0,
		}
		_parts.append(part)


func count() -> int:
	return _parts.size()


## How many particles show at the current progress (tests).
func alive() -> int:
	var n := 0
	for p in _parts:
		var age: float = (progress - float(p["born"])) / float(p["life"])
		if age > 0.0 and age < 1.0:
			n += 1
	return n


func _draw() -> void:
	var secs := PickPanel.OUTRO_S
	for p in _parts:
		var age: float = (progress - float(p["born"])) / float(p["life"])
		if age <= 0.0 or age >= 1.0:
			continue
		var a := minf(1.0, age * 8.0) * pow(1.0 - age, 1.5)
		var t := age * float(p["life"]) * secs
		var vel: Vector2 = p["vel"]
		var pos: Vector2 = p["at"] + vel * t + Vector2(0, -20.0) * t * t
		var col: Color = AstralCardArt.GLARE_BLUE if p["blue"] else AstralCardArt.GLARE
		if p["streak"]:
			draw_line(pos - vel * 0.07, pos, Color(col, 0.0), 2.4)
			draw_line(pos - vel * 0.035, pos, Color(col, a * 0.9), 1.6)
			continue
		var r: float = p["r"] * (0.6 + 0.4 * a)
		draw_circle(pos, r * 0.6, Color(col, a * 0.22))
		_star(pos, r, Color(col, a))
		if r > 10.0:  # the big ones flare: a long thin glare line across them
			draw_line(
				pos - Vector2(r * 2.4, 0), pos + Vector2(r * 2.4, 0), Color(col, a * 0.45), 1.0
			)


func _star(p: Vector2, r: float, col: Color) -> void:
	var w := r * 0.16
	draw_colored_polygon(
		PackedVector2Array(
			[
				p + Vector2(0, -r),
				p + Vector2(w, -w),
				p + Vector2(r * 0.7, 0),
				p + Vector2(w, w),
				p + Vector2(0, r),
				p + Vector2(-w, w),
				p + Vector2(-r * 0.7, 0),
				p + Vector2(-w, -w),
			]
		),
		col
	)


static func _next(s: int) -> int:
	return (s * 1103515245 + 12345) % 2147483648


static func _unit(s: int) -> float:
	return float(s % 100000) / 100000.0

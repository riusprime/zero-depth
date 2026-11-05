class_name StatusBadges
extends RefCounted
## v0.10.0 FX (owner, 2026-10-31: "replace the current pixel-like indicators above enemy heads ... a small, recognizable
## status icon or mark, a compact stack counter alongside it: x1, x2, x3"): one badge per stacking status over an
## enemy's health bar, an icon and its count, in a row that faces the camera. They replace the shock pips and the
## poison and bleed dots (v0.9.5 EE1). The icons are drawn here once, in code (a flame, a drop, bubbles, a bolt, a
## snowflake on a dark disc), in each status's own colour. Presentation only (EI-07): StatusVisuals hands the stacks.

## The statuses with a badge, in the row's order.
const ORDER: Array[StringName] = [&"burn", &"bleed", &"poison", &"shock", &"frost"]
const ICON_PX := 32
## Sizes (m): the icon, the gap to its count, a badge's width (icon and count), and the row's height over the bar.
const ICON_M := 0.3
const GAP_M := 0.02
const BADGE_M := 0.66
const RISE_M := 0.3
const FONT_SIZE := 32
const PIXEL_M := 0.0075
const POISON := Color("#7BE04A")

static var _icons := {}

## One actor's badges: status -> {icon: Sprite3D, label: Label3D, n: the count shown}.
var badges := {}
var _root: Node3D
var _bar_y := 1.3
## v0.10.5 W3-Q6: the row last laid out (its statuses in order, each one's count, and the right it was laid along): an
## update that would lay out the same row writes nothing.
var _shown_key := PackedInt32Array()
var _shown_right := Vector3.INF


func _init(root: Node3D, bar_y: float) -> void:
	_root = root
	_bar_y = bar_y


## Shows `stacks` (status -> count) laid along `right` (the camera's right, in world space). Built when first shown.
func update(stacks: Dictionary, right: Vector3) -> void:
	var on: Array[StringName] = []
	for s in ORDER:
		if int(stacks.get(s, 0)) > 0:
			on.append(s)
	var local_right := right
	if _root.is_inside_tree():
		local_right = (_root.global_transform.basis.inverse() * right).normalized()
	var key := PackedInt32Array()
	for s in on:
		key.append(ORDER.find(s))
		key.append(int(stacks[s]))
	if key == _shown_key and local_right == _shown_right:
		return
	_shown_key = key
	_shown_right = local_right
	var left0 := -(on.size() - 1) * 0.5 * BADGE_M
	for s: StringName in badges:
		if not on.has(s):
			(badges[s]["icon"] as Node3D).visible = false
			(badges[s]["label"] as Node3D).visible = false
	for k in on.size():
		var s := on[k]
		var b: Dictionary = badges.get(s, {})
		if b.is_empty():
			b = _build(s)
			badges[s] = b
		var n := int(stacks[s])
		if int(b["n"]) != n:  # (the text only when the count changes)
			b["n"] = n
			(b["label"] as Label3D).text = TranslationServer.translate(&"STATUS_STACK_COUNT") % n
		var centre := Vector3(0, _bar_y + RISE_M, 0) + local_right * (left0 + k * BADGE_M)
		var icon := b["icon"] as Sprite3D
		icon.visible = true
		icon.position = centre - local_right * (BADGE_M * 0.5 - ICON_M * 0.5)
		var label := b["label"] as Label3D
		label.visible = true
		label.position = icon.position + local_right * (ICON_M * 0.5 + GAP_M)


## The count badge `status` shows (0: hidden).
func shown(status: StringName) -> int:
	var b: Dictionary = badges.get(status, {})
	if b.is_empty() or not (b["icon"] as Node3D).visible:
		return 0
	return int(b["n"])


func _build(s: StringName) -> Dictionary:
	var icon := Sprite3D.new()
	icon.texture = icon_texture(s)
	icon.pixel_size = ICON_M / ICON_PX
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.shaded = false
	icon.render_priority = 2
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(icon)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = PIXEL_M
	label.font_size = FONT_SIZE
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.modulate = colour(s).lerp(Color.WHITE, 0.45)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.render_priority = 2
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (set translated: STATUS_STACK_COUNT)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(label)
	return {"icon": icon, "label": label, "n": -1}


static func colour(s: StringName) -> Color:
	return POISON if s == &"poison" else ItemLooks.status_color(s)


## The status's icon (drawn once a session): its shape in its colour on a dark disc, smoothed over 4 samples a pixel.
static func icon_texture(s: StringName) -> Texture2D:
	if _icons.has(s):
		return _icons[s]
	var img := Image.create(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	var c := colour(s)
	var hot := c.lerp(Color.WHITE, 0.55)
	for y in ICON_PX:
		for x in ICON_PX:
			var disc := 0.0
			var body := 0.0
			var core := 0.0
			for sy in 2:
				for sx in 2:
					var p := Vector2(x + 0.25 + 0.5 * sx, y + 0.25 + 0.5 * sy)
					disc += 0.25 if p.distance_to(Vector2(16, 16)) <= 15.5 else 0.0
					var v := _shape(s, p)
					body += 0.25 if v > 0.0 else 0.0
					core += 0.25 if v > 0.5 else 0.0
			var out := Color(0.04, 0.05, 0.08, 0.78 * disc)
			out = out.blend(Color(c, body))
			out = out.blend(Color(hot, core * 0.8))
			img.set_pixel(x, y, out)
	var tex := ImageTexture.create_from_image(img)
	_icons[s] = tex
	return tex


## Inside the shape at `p` (pixels, 32 x 32): > 0 inside, > 0.5 its bright core.
static func _shape(s: StringName, p: Vector2) -> float:
	match s:
		&"burn":  # a flame: a round base, three tongues rising from it
			var base := 1.0 - p.distance_to(Vector2(16, 21)) / 7.5
			var t := 0.0
			for tip: Vector2 in [Vector2(16, 4), Vector2(10, 10), Vector2(22, 10)]:
				t = maxf(t, _cone(p, Vector2(tip.x, 20), tip, 5.0 if tip.x == 16 else 3.5))
			if base <= 0.0 and t <= 0.0:
				return -1.0
			return 1.0 if p.distance_to(Vector2(16, 22)) <= 4.0 else 0.4
		&"bleed":  # a drop
			var disc := 1.0 - p.distance_to(Vector2(16, 20)) / 7.5
			var top := _cone(p, Vector2(16, 19), Vector2(16, 4), 7.0)
			var shine := 1.0 - p.distance_to(Vector2(13, 18)) / 2.2
			if disc <= 0.0 and top <= 0.0:
				return -1.0
			return 1.0 if shine > 0.0 else 0.4
		&"poison":  # three bubbles
			var b := -1.0
			for d: Array in [[Vector2(14, 19), 7.0], [Vector2(22, 11), 4.0], [Vector2(10, 9), 2.8]]:
				var r := float(d[1])
				var q := p.distance_to(d[0] as Vector2)
				if q <= r:
					b = maxf(b, 0.4)
					if q <= r * 0.35 and r > 3.0:
						b = 1.0
			return b
		&"shock":  # a lightning bolt
			var bolt := PackedVector2Array(
				[
					Vector2(19, 3),
					Vector2(8, 18),
					Vector2(15, 18),
					Vector2(12, 29),
					Vector2(24, 13),
					Vector2(17, 13),
					Vector2(22, 3)
				]
			)
			return 0.4 if Geometry2D.is_point_in_polygon(p, bolt) else -1.0
		&"frost":  # a snowflake: three bars through the centre
			var best := -1.0
			for a: Vector2 in [Vector2(1, 0), Vector2(0.5, 0.866), Vector2(-0.5, 0.866)]:
				var d := p - Vector2(16, 16)
				var along := absf(d.dot(a))
				var off := absf(d.dot(Vector2(-a.y, a.x)))
				if along <= 11.0 and off <= 1.6:
					best = 0.4
			if p.distance_to(Vector2(16, 16)) <= 3.0:
				best = 1.0
			return best
	return -1.0


## Inside a cone from a wide `base` point to a `tip`, `w` px wide at its base: 0..1 (1 on its axis).
static func _cone(p: Vector2, base: Vector2, tip: Vector2, w: float) -> float:
	var axis := tip - base
	var len := axis.length()
	var t := (p - base).dot(axis) / (len * len)
	if t < 0.0 or t > 1.0:
		return -1.0
	var half := w * (1.0 - t)
	var off := absf((p - base).cross(axis.normalized()))
	return 1.0 - off / half if off < half else -1.0

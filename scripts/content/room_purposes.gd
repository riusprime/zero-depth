extends SceneTree
## v0.11.0 O15 (PLAN P1): writes the large rooms' purposes, data/rooms/purposes/{camp,hall,quarry}.tres
## (RoomPurposeDefinition), from the G2 mockups' templates (scripts/shots/o15_purpose_rooms.gd, G2_ROOMS.md) that the
## owner picked (Q-O15a: all three; Q-O15b: authored templates with seeded variation). The mockups' random picks
## become authored choices (RoomPurposeChoice), chances and the seed's shifts and turns; their room-size rules become
## anchors (fractions of the half-size) plus metres. Positions that the mockup scattered at random are authored here
## once from a fixed authoring seed (AUTHOR_SEED), so the data is the same on every run of this tool.
## Run: godot --headless --path . -s scripts/content/room_purposes.gd
## Stand-in pieces: the kit's (OWNER_TODO §3.6 lists the purpose-room models to come); each palette row names its
## piece, so a new model swaps in by changing that row's `piece` (and its `size`), nothing else.

const OUT := "res://data/rooms/purposes/"
const AUTHOR_SEED := 20261107
## The G2 room's half-size (42.7 x 34.2 m), for the yaws that face a ring's pieces to its centre.
const REF_HALF := Vector2(21.35, 17.1)

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = AUTHOR_SEED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok := true
	for def: RoomPurposeDefinition in [_camp(), _hall(), _quarry()]:
		var issues := def.validate()
		for i in issues:
			print("room_purposes: %s: %s" % [def.id, i.message])
		ok = ok and issues.is_empty()
		var path := OUT + "%s.tres" % def.id
		if ResourceSaver.save(def, path) != OK:
			print("room_purposes: could not save ", path)
			ok = false
		else:
			print("room_purposes: wrote ", path)
	quit(0 if ok else 1)


static func _part(
	token: StringName, at: Vector2, yaw := 0.0, side := 0, chance := 1000, h := 1.0, spread := 0.0
) -> RoomPurposePart:
	var p := RoomPurposePart.new()
	p.token = token
	p.at = at
	p.yaw = yaw
	p.side = side
	p.chance_permille = chance
	p.height_scale = h
	p.height_spread = spread
	return p


static func _group(
	anchor: Vector2,
	offset: Vector2,
	parts: Array,
	yaw := 0.0,
	focal := false,
	choice := &"",
	options := PackedInt32Array(),
	chance := 1000
) -> RoomPurposeGroup:
	var g := RoomPurposeGroup.new()
	g.anchor = anchor
	g.offset = offset
	g.yaw = yaw
	g.focal = focal
	g.choice = choice
	g.options = options
	g.chance_permille = chance
	for p: RoomPurposePart in parts:
		g.parts.append(p)
	return g


static func _choice(id: StringName, weights: PackedInt32Array) -> RoomPurposeChoice:
	var c := RoomPurposeChoice.new()
	c.id = id
	c.weights = weights
	return c


## A palette from {token: [piece, length, depth, height, solid, lift (optional)]}.
static func _palette(biome: StringName, rows: Dictionary) -> RoomPurposePalette:
	var pal := RoomPurposePalette.new()
	pal.biome = biome
	var tokens: Array = rows.keys()
	tokens.sort()
	for t: StringName in tokens:
		var r: Array = rows[t]
		var q := RoomPurposePiece.new()
		q.token = t
		q.piece = r[0]
		q.size = Vector2(r[1], r[2])
		q.height = r[3]
		q.solid = r[4]
		q.lift = r[5] if r.size() > 5 else 0.0
		pal.pieces.append(q)
	return pal


static func _all_but(k: int, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in n:
		if i != k:
			out.append(i)
	return out


## Decoration scattered over an ellipse of the half-size (fractions rad_lo..rad_hi), authored once.
func _scatter(token: StringName, n: int, rad_lo: float, rad_hi: float) -> RoomPurposeGroup:
	var parts: Array = []
	for s in n:
		var a := _rng.randf_range(0.0, TAU)
		var rad := _rng.randf_range(rad_lo, rad_hi)
		parts.append(
			_part(token, Vector2(cos(a), sin(a)) * rad * REF_HALF, _rng.randf_range(0, 360))
		)
	return _group(Vector2.ZERO, Vector2.ZERO, parts)


## 1. Camp: a fire pit (the fire barrel, a ring of stones, two drying racks) and its seats in the middle; five shelters
## on a ring at 60 % of the room, each turned to face the fire with its lean-to on one side and its crates on the
## other, maybe a brazier, a worn path of stones toward the fire; supply piles in two opposite corners.
func _camp() -> RoomPurposeDefinition:
	var d := RoomPurposeDefinition.new()
	d.id = &"camp"
	d.biomes = [&"ruins", &"frozen_shore", &"red_canyon"]
	d.shift_m = 0.6
	d.turn_deg = 10.0
	d.choices = [
		_choice(&"seats", PackedInt32Array([1, 1])),
		_choice(&"gap", PackedInt32Array([1, 1, 1, 1, 1, 1])),
		_choice(&"corners", PackedInt32Array([1, 1])),
	]
	var fire: Array = [_part(&"fire", Vector2.ZERO)]
	for k in 9:
		var a := deg_to_rad(k * 40.0 + _rng.randf_range(-8.0, 8.0))
		fire.append(_part(&"stone", Vector2(cos(a), sin(a)) * 1.2, rad_to_deg(a)))
	for k in 2:
		var ar := deg_to_rad(36.0 + k * 180.0)
		fire.append(_part(&"rack", Vector2(cos(ar), sin(ar)) * 4.8, rad_to_deg(ar) + 90.0))
	d.groups.append(_group(Vector2.ZERO, Vector2.ZERO, fire, 0.0, true))
	for opt in 2:
		var seats := 4 + opt
		var parts: Array = []
		for k in seats:
			var a := deg_to_rad(20.0 + k * 360.0 / seats)
			parts.append(_part(&"seat", Vector2(cos(a), sin(a)) * 3.0, rad_to_deg(a)))
		d.groups.append(
			_group(Vector2.ZERO, Vector2.ZERO, parts, 0.0, false, &"seats", PackedInt32Array([opt]))
		)
	for k in 6:
		var a := deg_to_rad(30.0 + k * 60.0)
		var anchor := Vector2(cos(a), sin(a)) * 0.6
		var p := anchor * REF_HALF
		var inward := -p.normalized()
		var t := Vector2(-inward.y, inward.x)
		# The group's frame: +x along the shelter (t), -y toward the fire (inward).
		var parts: Array = [_part(&"shelter", Vector2.ZERO)]
		for side in [1, 2]:
			var flip := 1.0 if side == 1 else -1.0
			parts.append(_part(&"lean", Vector2(flip * 3.9, -0.2), flip * 25.0, side))
			parts.append(_part(&"pile", Vector2(-flip * 3.4, 0.2), 0.0, side, 1000, 1.0, 0.1))
			parts.append(_part(&"pile", Vector2(-flip * 3.4, 1.7), 0.0, side, 1000, 1.7, 0.1))
			parts.append(_part(&"post", Vector2(-flip * 1.5, -2.2), 0.0, side, 600))
		for x in [-1.8, 0.2, 2.0]:
			parts.append(_part(&"debris", Vector2(x, 1.9), _rng.randf_range(0, 360)))
		for s in 3:
			parts.append(
				_part(&"rubble", Vector2(0.0, -3.4 - s * 1.6), _rng.randf_range(0, 360), 0, 700)
			)
		d.groups.append(
			_group(
				anchor, Vector2.ZERO, parts, rad_to_deg(t.angle()), false, &"gap", _all_but(k, 6)
			)
		)
	for opt in 2:
		var corners: Array = (
			[Vector2(-1, 1), Vector2(1, -1)] if opt == 0 else [Vector2(1, 1), Vector2(-1, -1)]
		)
		for corner: Vector2 in corners:
			var parts: Array = []
			for q: Vector2 in [
				Vector2(0, 0), Vector2(-1.45, 0), Vector2(0, -1.45), Vector2(-1.45, -1.45)
			]:
				parts.append(_part(&"pile", q * corner, 0.0, 0, 850, 1.35, 0.4))
			d.groups.append(
				_group(
					corner, -corner * 2.4, parts, 0.0, false, &"corners", PackedInt32Array([opt])
				)
			)
	d.groups.append(_scatter(&"grass", 14, 0.3, 0.95))
	d.palettes = [
		_palette(
			&"ruins",
			{
				&"fire": [&"fire_barrel", 1.0, 1.0, 1.0, true],
				&"stone": [&"boulder_small", 0.6, 0.5, 0.0, false],
				&"seat": [&"tire_stack", 1.0, 1.0, 0.55, true],
				&"shelter": [&"car_wreck", 5.0, 2.3, 1.5, true],
				&"lean": [&"barricade", 2.6, 0.6, 0.0, true],
				&"rack": [&"ladder_frame", 1.2, 0.5, 0.0, true],
				&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
				&"pile": [&"crate_stack", 1.4, 1.4, 1.3, true],
				&"grass": [&"grass_tuft", 0.6, 0.6, 0.0, false],
				&"debris": [&"debris_low", 1.0, 0.5, 0.0, false],
				&"rubble": [&"rubble_small", 0.6, 0.6, 0.0, false],
			}
		),
		_palette(
			&"frozen_shore",
			{
				&"fire": [&"fire_barrel", 1.0, 1.0, 1.0, true],
				&"stone": [&"ice_shard", 0.5, 0.5, 0.0, false],
				&"seat": [&"crate_stack", 1.0, 1.0, 0.55, true],
				&"shelter": [&"boat_wreck", 4.6, 2.2, 0.0, true],
				&"lean": [&"fish_rack", 1.6, 0.7, 0.0, true],
				&"rack": [&"fish_rack", 1.6, 0.7, 0.0, true],
				&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
				&"pile": [&"crate_stack", 1.4, 1.4, 1.3, true],
				&"grass": [&"snow_drift", 0.9, 0.6, 0.0, false],
				&"debris": [&"debris_low", 1.0, 0.5, 0.0, false],
				&"rubble": [&"ice_shard", 0.5, 0.5, 0.0, false],
			}
		),
		# Red Canyon (an extension of G2, so every biome has two purposes but Frozen Shore and Starfall): a wagon camp.
		_palette(
			&"red_canyon",
			{
				&"fire": [&"fire_barrel", 1.0, 1.0, 1.0, true],
				&"stone": [&"rubble_small", 0.6, 0.6, 0.0, false],
				&"seat": [&"crate_stack", 1.0, 1.0, 0.55, true],
				&"shelter": [&"wagon_wreck", 3.4, 2.0, 0.0, true],
				&"lean": [&"rock_large", 2.4, 0.9, 0.8, true],
				&"rack": [&"cattle_skull_post", 0.4, 0.4, 0.0, true],
				&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
				&"pile": [&"crate_stack", 1.4, 1.4, 1.3, true],
				&"grass": [&"dry_shrub", 0.5, 0.5, 0.0, false],
				&"debris": [&"debris_low", 1.0, 0.5, 0.0, false],
				&"rubble": [&"rubble_small", 0.6, 0.6, 0.0, false],
			}
		),
	]
	return d


## 2. Collapsed hall, a ring of standing stones (owner 2026-11-07, after G2: "The hall ruins have the pillars way too
## organized, can we shape them kinda in a way as Stonehenge, not exactly like that but the vibe"): the focal ruin (an
## arch or the observatory) in the middle between two towers, lit by two braziers; round it a loose ring of standing
## stones at irregular spacing, each with its own turn: three trilithons (two uprights and a lintel across them, or
## the pair without its lintel, or one fallen), the rest single stones standing, broken to stumps, fallen outward or
## gone (a wider gap: the ring's gaps are the lanes in and out); a few stray outliers beyond the ring.
func _hall() -> RoomPurposeDefinition:
	var d := RoomPurposeDefinition.new()
	d.id = &"hall"
	d.biomes = [&"ruins", &"starfall", &"night_rocks"]
	d.shift_m = 0.5
	d.turn_deg = 10.0
	var focal: Array = [_part(&"focal", Vector2.ZERO, 90.0)]
	for side: float in [-1.0, 1.0]:
		focal.append(_part(&"tower", Vector2(0.0, side * 4.0), _rng.randf_range(-8, 8)))
		focal.append(_part(&"post", Vector2(-3.2, side * 2.4)))
	for s in 8:
		focal.append(
			_part(&"rubble", Vector2(-_rng.randf_range(1.0, 2.6), _rng.randf_range(-3.6, 3.6)))
		)
	d.groups.append(_group(Vector2.ZERO, Vector2.ZERO, focal, 0.0, true))
	# The ring: 14 places on an ellipse of the half-size at irregular angles (authored); places 1, 5 and 10 are
	# trilithons. Each group's frame: +x outward from the centre, y along the ring.
	var steps := [22, 30, 18, 34, 24, 20, 36, 26, 19, 31, 23, 28, 21, 28]
	var a_deg := 8.0
	for i in steps.size():
		var a := deg_to_rad(a_deg)
		var anchor := Vector2(cos(a) * 0.56, sin(a) * 0.64)
		var out := (anchor * REF_HALF).normalized()
		var yaw := rad_to_deg(out.angle())
		var id := StringName("stone_%d" % i)
		if i in [1, 5, 10]:  # a trilithon: with its lintel (50), the pair bare (30), one upright fallen (20)
			d.choices.append(_choice(id, PackedInt32Array([50, 30, 20])))
			d.groups.append(
				_group(
					anchor,
					Vector2.ZERO,
					[
						_part(&"upright", Vector2(0.0, -1.4), _rng.randf_range(-6, 6)),
						_part(&"upright", Vector2(0.0, 1.4), _rng.randf_range(-6, 6)),
						_part(&"lintel", Vector2.ZERO, 90.0 + _rng.randf_range(-4, 4))
					],
					yaw,
					false,
					id,
					PackedInt32Array([0])
				)
			)
			d.groups.append(
				_group(
					anchor,
					Vector2.ZERO,
					[
						_part(&"upright", Vector2(0.0, -1.4), _rng.randf_range(-8, 8)),
						_part(&"upright", Vector2(0.0, 1.4), _rng.randf_range(-8, 8))
					],
					yaw,
					false,
					id,
					PackedInt32Array([1])
				)
			)
			var fall: Array = [
				_part(&"upright", Vector2(0.0, -1.4), _rng.randf_range(-8, 8)),
				_part(&"stump", Vector2(0.0, 1.4), _rng.randf_range(-20, 20)),
				_part(&"fallen", Vector2(2.9, 1.8), _rng.randf_range(-20, 20)),
			]
			for s in 3:
				fall.append(
					_part(
						&"rubble", Vector2(_rng.randf_range(1.0, 4.5), _rng.randf_range(0.2, 3.0))
					)
				)
			d.groups.append(
				_group(anchor, Vector2.ZERO, fall, yaw, false, id, PackedInt32Array([2]))
			)
		else:  # a single stone: standing (55), a stump (15), fallen outward (12) or gone (18)
			d.choices.append(_choice(id, PackedInt32Array([55, 15, 12, 18])))
			d.groups.append(
				_group(
					anchor,
					Vector2.ZERO,
					[
						_part(
							&"column",
							Vector2.ZERO,
							90.0 + _rng.randf_range(-14, 14),
							0,
							1000,
							1.0,
							0.2
						)
					],
					yaw,
					false,
					id,
					PackedInt32Array([0])
				)
			)
			d.groups.append(
				_group(
					anchor,
					Vector2.ZERO,
					[
						_part(&"stump", Vector2.ZERO, _rng.randf_range(-20, 20)),
						_part(&"rubble", Vector2(0.9, _rng.randf_range(-0.9, 0.9)))
					],
					yaw,
					false,
					id,
					PackedInt32Array([1])
				)
			)
			var fallen: Array = [
				_part(&"stump", Vector2.ZERO, _rng.randf_range(-20, 20)),
				_part(
					&"fallen", Vector2(2.9, _rng.randf_range(-0.6, 0.6)), _rng.randf_range(-20, 20)
				),
			]
			for s in 3:
				fallen.append(_part(&"rubble", Vector2(2.4 + s * 0.8, _rng.randf_range(-1.6, 1.6))))
			d.groups.append(
				_group(anchor, Vector2.ZERO, fallen, yaw, false, id, PackedInt32Array([2]))
			)
		a_deg += steps[i]
	# The outliers: stray stones beyond the ring.
	for a_out: float in [64.0, 151.0, 232.0, 318.0]:
		var a := deg_to_rad(a_out)
		d.groups.append(
			_group(
				Vector2(cos(a) * 0.82, sin(a) * 0.8),
				Vector2.ZERO,
				[_part(&"column", Vector2.ZERO, _rng.randf_range(0, 180), 0, 1000, 0.75, 0.2)],
				0.0,
				false,
				&"",
				PackedInt32Array(),
				600
			)
		)
	var scatter: Array = []
	for s in 18:
		var gu := _rng.randf_range(-REF_HALF.x + 1.5, REF_HALF.x - 1.5)
		var gv := _rng.randf_range(-REF_HALF.y + 1.0, REF_HALF.y - 1.0)
		var tok := &"grass" if _rng.randf() < 0.6 else &"debris"
		scatter.append(_part(tok, Vector2(gu, gv), _rng.randf_range(0, 360)))
	d.groups.append(_group(Vector2.ZERO, Vector2.ZERO, scatter))
	d.palettes = [
		_palette(
			&"ruins",
			{
				&"focal": [&"stone_arch", 3.0, 1.0, 0.0, true],
				&"tower": [&"wall_pillar", 1.6, 1.6, 3.4, true],
				&"column": [&"wall_pillar", 1.3, 1.3, 3.0, true],
				&"upright": [&"wall_pillar", 1.2, 1.2, 3.0, true],
				&"lintel": [&"slab_wide", 4.0, 1.0, 0.6, false, 2.9],
				&"stump": [&"column_broken", 1.1, 1.1, 0.0, true],
				&"fallen": [&"slab_wide", 3.6, 1.2, 0.8, true],
				&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
				&"grass": [&"grass_tuft", 0.6, 0.6, 0.0, false],
				&"debris": [&"debris_low", 1.0, 0.5, 0.0, false],
				&"rubble": [&"rubble_small", 0.6, 0.6, 0.0, false],
			}
		),
		_palette(
			&"starfall",
			{
				&"focal": [&"ruined_observatory", 2.6, 2.6, 0.0, true],
				&"tower": [&"star_monolith", 1.4, 1.4, 0.0, true],
				&"column": [&"star_monolith", 1.2, 1.2, 0.0, true],
				&"upright": [&"rock_large", 1.2, 1.2, 2.8, true],
				&"lintel": [&"rock_large", 4.0, 1.0, 0.6, false, 2.7],
				&"stump": [&"rock_large", 1.2, 1.2, 0.9, true],
				&"fallen": [&"rock_large", 3.6, 1.2, 0.8, true],
				&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
				&"grass": [&"star_crystal", 0.5, 0.5, 0.0, false],
				&"debris": [&"meteorite", 0.6, 0.5, 0.0, false],
				&"rubble": [&"meteorite", 0.6, 0.5, 0.0, false],
			}
		),
		# Night Rocks (an extension of G2): the arch is its own piece; spires for the single stones.
		_palette(
			&"night_rocks",
			{
				&"focal": [&"stone_arch", 3.0, 1.0, 0.0, true],
				&"tower": [&"rock_spire", 1.4, 1.4, 0.0, true],
				&"column": [&"rock_spire", 1.1, 1.1, 0.0, true],
				&"upright": [&"rock_large", 1.2, 1.2, 2.6, true],
				&"lintel": [&"rock_large", 4.0, 1.0, 0.6, false, 2.5],
				&"stump": [&"rock_large", 1.1, 1.1, 0.8, true],
				&"fallen": [&"rock_large", 3.6, 1.2, 0.7, true],
				&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
				&"grass": [&"mushroom_cluster", 0.6, 0.6, 0.0, false],
				&"debris": [&"bone_pile", 0.8, 0.6, 0.0, false],
				&"rubble": [&"boulder_small", 0.5, 0.45, 0.0, false],
			}
		),
	]
	return d


## 3. Quarry: the cut rock face against a long wall (seven masses, the middle three focal, the middle one the tallest),
## scaffolds and lights at its foot; the cart where the stone is loaded, on one side; a haul road edged with rubble
## from the cart to the far wall, two markers at its end; a yard of cut-block stacks (stepped heights) with lanes.
## The face prefers a far wall from the camera (G2_ROOMS.md: "the far wall reads better").
func _quarry() -> RoomPurposeDefinition:
	var d := RoomPurposeDefinition.new()
	d.id = &"quarry"
	d.biomes = [&"red_canyon", &"night_rocks"]
	d.far_wall = true
	d.shift_m = 0.4
	d.turn_deg = 10.0
	d.choices = [
		_choice(&"cart", PackedInt32Array([1, 1])),
		_choice(&"scaffolds", PackedInt32Array([1, 1])),
		_choice(&"yard_gap", PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])),
	]
	var n := 7
	for k in n:
		var x := -0.62 + k * 1.24 / (n - 1)
		var mid := k == n / 2
		var focal := absi(k - n / 2) <= 1
		var rot := _rng.randf_range(-10, 10)
		if k % 2 == 1 or mid:
			var hs := 1.35 if mid else 1.0
			d.groups.append(
				_group(
					Vector2(x, 1.0),
					Vector2(0.0, -2.0),
					[_part(&"face", Vector2.ZERO, rot, 0, 1000, hs, 0.0 if mid else 0.15)],
					0.0,
					focal
				)
			)
		else:  # a big mass (35) or a small one (65)
			var id := StringName("mass_%d" % k)
			d.choices.append(_choice(id, PackedInt32Array([35, 65])))
			d.groups.append(
				_group(
					Vector2(x, 1.0),
					Vector2(0.0, -2.0),
					[_part(&"face", Vector2.ZERO, rot, 0, 1000, 0.95, 0.15)],
					0.0,
					false,
					id,
					PackedInt32Array([0])
				)
			)
			d.groups.append(
				_group(
					Vector2(x, 1.0),
					Vector2(0.0, -2.6),
					[_part(&"face_small", Vector2.ZERO, rot)],
					0.0,
					false,
					id,
					PackedInt32Array([1])
				)
			)
	var rubble: Array = []
	for s in 16:
		var gx := _rng.randf_range(-0.62, 0.62) * REF_HALF.x
		rubble.append(_part(&"rubble", Vector2(gx, -_rng.randf_range(2.2, 3.6))))
	d.groups.append(_group(Vector2(0.0, 1.0), Vector2(0.0, -2.0), rubble))
	for opt in 2:  # two scaffolds or three
		var ks := [0, 1] if opt == 0 else [0, 1, 2]
		var parts: Array = []
		for k: int in ks:
			var sx := (-0.45 + k * 0.45) * 0.62 * REF_HALF.x
			parts.append(_part(&"scaffold", Vector2(sx, 0.0)))
		d.groups.append(
			_group(
				Vector2(0.0, 1.0),
				Vector2(0.0, -4.4),
				parts,
				0.0,
				false,
				&"scaffolds",
				PackedInt32Array([opt])
			)
		)
	for side: float in [-1.0, 1.0]:
		d.groups.append(
			_group(
				Vector2(side * 0.62, 1.0), Vector2(side * 2.6, -3.2), [_part(&"post", Vector2.ZERO)]
			)
		)
	for opt in 2:  # the cart's side, and the road and its markers with it
		var cs := 1.0 if opt == 0 else -1.0
		var cart := Vector2(cs * 4.0, -7.6)
		d.groups.append(
			_group(
				Vector2(0.0, 1.0),
				Vector2.ZERO,
				[
					_part(&"cart", cart, _rng.randf_range(-15, 15)),
					_part(&"block", cart + Vector2(cs * 2.3, 0.4), 0.0, 0, 1000, 0.8)
				],
				0.0,
				false,
				&"cart",
				PackedInt32Array([opt])
			)
		)
		var road := cs * 2.0
		var rows: Array = []
		for i in 16:
			var fy := 0.4 - i * 0.085
			for edge: float in [-2.3, 2.3]:
				rows.append(_part(&"rubble", Vector2(road + edge, fy * REF_HALF.y), 0.0, 0, 750))
		d.groups.append(
			_group(Vector2.ZERO, Vector2.ZERO, rows, 0.0, false, &"cart", PackedInt32Array([opt]))
		)
		d.groups.append(
			_group(
				Vector2(0.0, -1.0),
				Vector2(0.0, 2.2),
				[
					_part(&"marker", Vector2(road - 3.0, 0.0)),
					_part(&"marker", Vector2(road + 3.0, 0.0))
				],
				0.0,
				false,
				&"cart",
				PackedInt32Array([opt])
			)
		)
	var yard := [
		Vector2(-0.72, -0.05),
		Vector2(-0.6, -0.62),
		Vector2(-0.34, -0.25),
		Vector2(0.34, -0.25),
		Vector2(0.6, -0.62),
		Vector2(0.72, -0.05),
	]
	var cells := [
		Vector2(-0.78, -0.78), Vector2(0.78, -0.78), Vector2(-0.78, 0.78), Vector2(0.78, 0.78)
	]
	for k in yard.size():  # the stacks: one left out (options 6, 7: none)
		var parts: Array = []
		for c in 4:
			var hs: float = [1.0, 1.8, 1.0, 2.5][c]
			parts.append(_part(&"block", cells[c], 0.0, 0, 500 if c == 3 else 1000, hs, 0.1))
		parts.append(
			_part(&"debris", Vector2(2.3, _rng.randf_range(-1.0, 1.0)), _rng.randf_range(0, 360))
		)
		d.groups.append(
			_group(yard[k], Vector2.ZERO, parts, 0.0, false, &"yard_gap", _all_but(k, 8))
		)
	var grass: Array = []
	for s in 12:
		var gu := _rng.randf_range(-REF_HALF.x + 1.5, REF_HALF.x - 1.5)
		var gv := _rng.randf_range(-REF_HALF.y + 1.0, REF_HALF.y * 0.3)
		grass.append(_part(&"grass", Vector2(gu, gv), _rng.randf_range(0, 360)))
	d.groups.append(_group(Vector2.ZERO, Vector2.ZERO, grass))
	d.palettes = [
		_palette(
			&"red_canyon",
			{
				&"face": [&"rock_large", 3.6, 3.0, 3.2, true],
				&"face_small": [&"mesa_chunk", 2.2, 2.2, 0.0, true],
				&"block": [&"slab_concrete", 1.5, 1.5, 1.0, true],
				&"cart": [&"wagon_wreck", 2.4, 1.4, 0.0, true],
				&"scaffold": [&"ladder_frame", 1.2, 0.5, 0.0, true],
				&"marker": [&"cattle_skull_post", 0.4, 0.4, 0.0, true],
				&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
				&"grass": [&"dry_shrub", 0.5, 0.5, 0.0, false],
				&"debris": [&"debris_low", 1.0, 0.5, 0.0, false],
				&"rubble": [&"rubble_small", 0.6, 0.6, 0.0, false],
			}
		),
		_palette(
			&"night_rocks",
			{
				&"face": [&"rock_large", 3.6, 3.0, 3.2, true],
				&"face_small": [&"rock_spire", 1.3, 1.3, 0.0, true],
				&"block": [&"slab_concrete", 1.5, 1.5, 1.0, true],
				&"cart": [&"wagon_wreck", 2.4, 1.4, 0.0, true],
				&"scaffold": [&"ladder_frame", 1.2, 0.5, 0.0, true],
				&"marker": [&"brazier_pole", 0.7, 0.7, 0.0, true],
				&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
				&"grass": [&"mushroom_cluster", 0.6, 0.6, 0.0, false],
				&"debris": [&"bone_pile", 0.8, 0.6, 0.0, false],
				&"rubble": [&"boulder_small", 0.5, 0.45, 0.0, false],
			}
		),
	]
	return d

extends GutTest
## v0.8.0 EC (owner O2, Q1 "By role"): one palette table for the 14 normal enemy kinds (EnemyPalettes), with today's
## red as the shipped default and three G2 candidates (A saturated, B muted, C grey bodies with role trims and eyes).
## Checks: the table covers every kind and slot in every palette; `current` is today's look; the candidates keep each
## role in its family and off the reserved colours; role colours stay out of the biome's grey cast; the avatars build
## from the active palette (ActorViews, the real path); a colour-blind mode still recolours the ring and the X-ray
## twin and leaves the palette alone.

const KINDS: Array[int] = [
	WorldReader.KIND_CHARGER,
	WorldReader.KIND_HATCHLING,
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_NEEDLE,
	WorldReader.KIND_ARC_CASTER,
	WorldReader.KIND_SNIPER,
	WorldReader.KIND_LENS_DRONE,
	WorldReader.KIND_BOMB_DRONE,
	WorldReader.KIND_MINE_LAYER,
	WorldReader.KIND_MENDER,
	WorldReader.KIND_WARDEN,
	WorldReader.KIND_SHIELD_BEARER,
]
## The kinds with no eye slit on today's models (their glow is the seam or the heal crystal).
const NO_EYE: Array[int] = [
	WorldReader.KIND_SPLITTER, WorldReader.KIND_SPLITLING, WorldReader.KIND_MENDER
]
## Hue windows per role (degrees; a window may wrap past 360). Bronze is an orange hue, told apart from the melee
## oranges by being darker.
const HUES := {
	&"melee": [340.0, 30.0],
	&"ranged": [210.0, 300.0],
	&"bomber": [38.0, 60.0],
	&"support": [100.0, 160.0],
	&"tank": [20.0, 40.0],
}
## The colours no enemy may come near (CIE76 in Lab, normal vision): the hero's core and attack heat colours, the
## hostile shot, the telegraph, the hazard and the heal green.
const RESERVED := {
	"player_core": Color("#2BC4E2"),
	"proj_hostile": Color("#FBD07A"),
	"telegraph_hostile": Color("#FF6A3D"),
	"hazard": Color("#E0892B"),
	"heal": Color("#7CF29A"),
	"heat_hot": Color("#FFA63A"),
	"heat_overclock": Color("#FF4A1A"),
}
## Floors (starting values from the measured candidates): ΔE from a reserved colour, between two kinds of a role,
## and between two roles' identity colours.
const MIN_RESERVED_DE := 10.0
const MIN_KIND_DE := 5.0
const MIN_ROLE_DE := 15.0


func after_each() -> void:
	EnemyPalettes.active = EnemyPalettes.SHIPPED
	ThemePalette.mode = &"off"


static func _lab(c: Color) -> Vector3:
	var lin := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var f := func(t: float) -> float:
		return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	return Vector3(
		116.0 * f.call(y) - 16.0, 500.0 * (f.call(x) - f.call(y)), 200.0 * (f.call(y) - f.call(z))
	)


static func _de(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))


## The slots that carry a candidate's role colour: the plates for A and B, the trim and the eye for C.
static func _role_slots(palette: StringName) -> Array[StringName]:
	if palette == &"c":
		return [&"trim", &"eye"]
	return [&"body", &"trim"]


## The slot that tells a kind apart in a candidate (its biggest role-coloured part).
static func _identity_slot(palette: StringName) -> StringName:
	return &"trim" if palette == &"c" else &"body"


func test_the_table_covers_every_normal_kind_and_slot_in_every_palette() -> void:
	var ids := {}
	for f in DirAccess.get_files_at("res://data/enemies"):
		if f.ends_with(".tres"):
			ids[StringName(f.get_basename())] = true
	assert_eq(ids.size(), 14, "14 normal kinds in data/enemies")
	assert_eq(EnemyPalettes.ROLES.size(), 14)
	assert_eq(EnemyPalettes.KIND_IDS.size(), 14)
	for id: StringName in ids:
		assert_true(EnemyPalettes.ROLES.has(id), "%s has a role" % id)
	for kind in KINDS:
		assert_true(ids.has(EnemyPalettes.KIND_IDS[kind]), "kind %d maps to a data id" % kind)
	var palettes: Array[StringName] = [EnemyPalettes.CURRENT]
	palettes.append_array(EnemyPalettes.CANDIDATES)
	assert_eq(palettes, [&"current", &"a", &"b", &"c"])
	for p in palettes:
		var rows: Dictionary = EnemyPalettes.TABLE[p]["kinds"]
		assert_eq(rows.size(), 14, "%s: every kind" % p)
		for id: StringName in ids:
			var row: Array = rows.get(id, [])
			assert_eq(row.size(), EnemyPalettes.SLOTS.size(), "%s/%s: four slots" % [p, id])
			for hex: String in row:
				assert_true(Color.html_is_valid(hex), "%s/%s: %s" % [p, id, hex])
	assert_eq(
		EnemyPalettes.color(WorldReader.KIND_GATEKEEPER, &"body"),
		ThemePalette.UNKNOWN,
		"bosses are not in the table (they keep their own colours)"
	)


func test_the_shipped_default_is_the_owners_pick() -> void:
	assert_eq(EnemyPalettes.active, &"a", "the owner's G2 pick, 2026-10-14: palette A")
	assert_true(EnemyPalettes.eyes_on_all(), "palette A gives every kind an eye slit")


func test_current_keeps_the_old_red_and_grey() -> void:
	EnemyPalettes.active = EnemyPalettes.CURRENT
	assert_false(EnemyPalettes.eyes_on_all(), "no new eye slits on the old look")
	# The colours the avatars held as constants before v0.8.0 EC.
	var c := func(kind: int, slot: StringName) -> Color: return EnemyPalettes.color(kind, slot)
	assert_eq(c.call(WorldReader.KIND_CHARGER, &"body"), Color("#D8433A"))
	assert_eq(c.call(WorldReader.KIND_CHARGER, &"trim"), Color("#C63B34"))
	assert_eq(c.call(WorldReader.KIND_CHARGER, &"grey"), Color("#6E605D"))
	assert_eq(c.call(WorldReader.KIND_WARDEN, &"body"), Color("#DA4036"))
	assert_eq(c.call(WorldReader.KIND_WARDEN, &"trim"), Color("#2E2B2E"))
	assert_eq(c.call(WorldReader.KIND_WARDEN, &"grey"), Color("#6E5B53"))
	assert_eq(c.call(WorldReader.KIND_WARDEN, &"eye"), Color("#FC2824"))
	assert_eq(c.call(WorldReader.KIND_NEEDLE, &"body"), Color("#E03C30"))
	assert_eq(c.call(WorldReader.KIND_SNIPER, &"trim"), Color("#24272D"))
	for kind in KINDS:
		if kind != WorldReader.KIND_WARDEN:
			assert_eq(c.call(kind, &"eye"), Color("#FF2A22"), "kind %d: the hostile red eye" % kind)


func test_each_candidate_keeps_each_role_in_its_colour_family() -> void:
	for p in EnemyPalettes.CANDIDATES:
		assert_true(EnemyPalettes.eyes_on_all(p), "%s: every kind shows an eye" % p)
		for id: StringName in EnemyPalettes.ROLES:
			var role: StringName = EnemyPalettes.ROLES[id]
			var win: Array = HUES[role]
			for slot in _role_slots(p):
				if slot == &"eye" and p != &"c":
					continue
				var col := EnemyPalettes.color_of(id, slot, p)
				var h := col.h * 360.0
				var inside: bool = (
					(h >= win[0] and h <= win[1])
					if win[0] < win[1]
					else (h >= win[0] or h <= win[1])
				)
				assert_true(inside, "%s/%s %s: hue %.0f in %s %s" % [p, id, slot, h, role, win])
		# Tanks read darker than the melee oranges they share hues with.
		var s := _identity_slot(p)
		for tank: StringName in [&"warden", &"shield_bearer"]:
			assert_lt(
				EnemyPalettes.color_of(tank, s, p).v,
				EnemyPalettes.color_of(&"splitter", s, p).v,
				"%s: %s darker than the Splitter" % [p, tank]
			)


func test_kinds_differ_inside_a_role_and_roles_differ_more() -> void:
	for p in EnemyPalettes.CANDIDATES:
		var s := _identity_slot(p)
		var ids: Array = EnemyPalettes.ROLES.keys()
		for a in ids.size():
			for b in range(a + 1, ids.size()):
				var ia: StringName = ids[a]
				var ib: StringName = ids[b]
				var d := _de(EnemyPalettes.color_of(ia, s, p), EnemyPalettes.color_of(ib, s, p))
				var same: bool = EnemyPalettes.ROLES[ia] == EnemyPalettes.ROLES[ib]
				var floor_de := MIN_KIND_DE if same else MIN_ROLE_DE
				assert_gte(d, floor_de, "%s: %s / %s at %.1f" % [p, ia, ib, d])


func test_no_enemy_colour_comes_near_a_reserved_colour() -> void:
	for p: StringName in EnemyPalettes.TABLE:
		for id: StringName in EnemyPalettes.ROLES:
			for slot in EnemyPalettes.SLOTS:
				var col := EnemyPalettes.color_of(id, slot, p)
				for r: String in RESERVED:
					var d := _de(col, RESERVED[r])
					assert_gte(d, MIN_RESERVED_DE, "%s/%s %s vs %s: %.1f" % [p, id, slot, r, d])


func test_role_colours_stay_out_of_the_biome_grey_cast() -> void:
	for p in EnemyPalettes.CANDIDATES:
		for id: StringName in EnemyPalettes.ROLES:
			for slot in _role_slots(p):
				var col := EnemyPalettes.color_of(id, slot, p)
				assert_gte(
					col.s, ActorViews.GREY_SATURATION, "%s/%s %s keeps its colour" % [p, id, slot]
				)
			assert_lt(
				EnemyPalettes.color_of(id, &"grey", p).s,
				ActorViews.GREY_SATURATION,
				"%s/%s: the frame takes the biome's cast" % [p, id]
			)
		if p == &"c":
			for id: StringName in EnemyPalettes.ROLES:
				assert_lt(
					EnemyPalettes.color_of(id, &"body", p).s,
					ActorViews.GREY_SATURATION,
					"c/%s: a grey body" % id
				)


## v0.8.0 MI: true when kind `kind` draws the owner's model (its frame and trims are his texture's).
static func _owner_model(kind: int) -> bool:
	var id := HordeAvatar.model_id(kind)
	if kind == WorldReader.KIND_LENS_DRONE:
		id = &"lens_drone"
	return id != &"" and EnemyModels.has_model(id)


## Every material colour under `node`: body materials (meta "mats") and glowing overrides (eyes, visors).
static func _colours(node: Node) -> Dictionary:
	var out := {}
	for m: StandardMaterial3D in node.get_meta(&"mats", []):
		out[m.albedo_color.to_html(false)] = true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D:
			var mo := (n as MeshInstance3D).material_override as StandardMaterial3D
			if mo != null and mo.emission_enabled:
				out[mo.albedo_color.to_html(false)] = true
	return out


func _build_all() -> Array:
	var w := CombatLab.world()
	for k in KINDS.size():
		w.add_enemy(KINDS[k], Vector2(3 + k * 2, 2))
	var views := ActorViews.new()
	add_child_autofree(views)
	views.sync(WorldReader.new(w))
	return [w, views]


func test_the_avatars_build_from_the_active_palette() -> void:
	for p: StringName in [EnemyPalettes.CURRENT, &"a", &"b", &"c"]:
		EnemyPalettes.active = p
		var built := _build_all()
		var w: World = built[0]
		var views: ActorViews = built[1]
		for k in KINDS.size():
			var node := views.actor_node(w.actors.ids[k + 1])
			var got := _colours(node)
			for slot in EnemyPalettes.SLOTS:
				if slot == &"eye" and not EnemyPalettes.eyes_on_all() and NO_EYE.has(KINDS[k]):
					continue  # today's Splitter glows at its seam, the Mender at its crystal
				if slot != &"body" and _owner_model(KINDS[k]):
					continue  # v0.8.0 MI: an owner's model takes the role colour on its plates only

				var want := EnemyPalettes.color(KINDS[k], slot).to_html(false)
				assert_true(
					got.has(want), "%s: kind %d draws its %s %s" % [p, KINDS[k], slot, want]
				)
		views.free()


func test_the_splitter_and_mender_get_an_eye_only_in_the_candidates() -> void:
	for p: StringName in [EnemyPalettes.CURRENT, &"a"]:
		EnemyPalettes.active = p
		for kind in [WorldReader.KIND_SPLITTER, WorldReader.KIND_MENDER]:
			if _owner_model(kind):  # v0.8.0 MI: the owner's model brings its own glowing eyes
				assert_true(EnemyModels.has_model(HordeAvatar.model_id(kind)), "kind %d" % kind)
				continue
			var a := HordeAvatar.new()
			a.setup(kind, Color.BLACK)
			var eyes := a.find_children("Eye", "MeshInstance3D", true, false)
			if p == EnemyPalettes.CURRENT:
				assert_eq(eyes.size(), 0, "kind %d: today's model" % kind)
			else:
				assert_gt(eyes.size(), 0, "%s: kind %d shows an eye" % [p, kind])
			a.free()


func test_a_colour_blind_mode_still_recolours_the_ring_and_xray_not_the_palette() -> void:
	EnemyPalettes.active = &"a"
	ThemePalette.mode = &"deuteranopia"
	var built := _build_all()
	var w: World = built[0]
	var views: ActorViews = built[1]
	var team := ThemePalette.color(&"enemy_body")
	assert_eq(team, ThemePalette.RED_GREEN[&"enemy_body"])
	for k in KINDS.size():
		var node := views.actor_node(w.actors.ids[k + 1])
		var ring_ok := false
		var xray_ok := false
		var stack: Array[Node] = [node]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if not n is MeshInstance3D:
				continue
			var mi := n as MeshInstance3D
			var mo := mi.material_override as StandardMaterial3D
			if mi.mesh is TorusMesh and mi.get_parent() == node and mo != null:
				ring_ok = ring_ok or mo.albedo_color == team
			if mo != null and mo.stencil_mode == BaseMaterial3D.STENCIL_MODE_XRAY:
				xray_ok = xray_ok or Color(mo.stencil_color, 1.0) == team
		assert_true(ring_ok, "kind %d: the team ring takes the mode's enemy colour" % KINDS[k])
		assert_true(xray_ok, "kind %d: the X-ray twin too" % KINDS[k])
		var got := _colours(node)
		var body := EnemyPalettes.color(KINDS[k], &"body").to_html(false)
		assert_true(got.has(body), "kind %d: the palette body is unchanged" % KINDS[k])

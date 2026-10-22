extends GutTest
## v0.9.0 PT (owner: "portals a bit separate from walls pls … there should be an space between the wall and the
## portals"): over SEEDS floors, no placed portal's oval comes within FloorLayout.GATE_WALL_CLEAR of any wall (the
## room's walls and its interior pieces): the gate, the Deep gate (two gates still GATE_GAP apart), and a later
## floor's arrival portal (PortalTransitView: STEP_BACK behind the hero's start, facing the camera).

const SEEDS := 200
## The oval's edge is sampled every this many metres.
const STEP := 0.1

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


## The nearest any point of the oval at `pos` (OVAL_HALF_W either side of it, across `n`) comes to a wall of `f`
## is at least `clear`: every sample keeps a circle of that radius off every wall.
func _oval_clear(f: FloorLayout, pos: Vector2, n: Vector2, clear: float) -> bool:
	var t := Vector2(-n.y, n.x)
	var k := -FloorLayout.OVAL_HALF_W
	while k <= FloorLayout.OVAL_HALF_W + 1e-6:
		var q := pos + t * k
		for w in f.walls:
			if Collide.circle_vs_obb(q, clear, w) != Vector2.ZERO:
				return false
		k += STEP
	return true


func test_the_sims_oval_is_the_views() -> void:
	assert_almost_eq(FloorLayout.OVAL_HALF_W * 2.0, PortalGate.OVAL_W, 1e-5)
	assert_almost_eq(FloorLayout.GATE_WALL_CLEAR, 1.5, 1e-5, "the starting value")


func test_no_portal_stands_within_the_clearance_of_a_wall() -> void:
	var bosses := ContentCompiler.compile_bosses(_repo)
	var clear := FloorLayout.GATE_WALL_CLEAR - 0.01
	var yaw := deg_to_rad(IsoRig.YAW_DEG)
	var out := SimPlane.to_sim(Vector3(sin(yaw), 0.0, cos(yaw))).normalized()
	var arrival_ok := 0
	var deep_seen := 0
	for s in SEEDS:
		var seed_value := 5000 + s
		var f := FloorGenerator.generate(seed_value)
		assert_true(
			_oval_clear(f, f.portal_pos, f.portal_facing(), clear),
			"seed %d: the floor's gate clear of the walls" % seed_value
		)
		var at := f.start_pos - out * PortalTransitView.STEP_BACK
		if _oval_clear(f, at, out, clear):
			arrival_ok += 1
		else:
			assert_true(
				false, "seed %d: the arrival portal at %s clear of the walls" % [seed_value, at]
			)
		var b := s % bosses.size()
		var spec := BossArenaSpec.make(bosses[b].arena_cells, bosses[b].arena_template, b)
		BossRoomBuilder.attach(f, spec)
		assert_true(
			_oval_clear(f, f.portal_pos, f.portal_facing(), clear),
			"seed %d boss %d: the boss room's gate clear of the walls" % [seed_value, b]
		)
		if Routes.place_deep_gate(f):
			deep_seen += 1
			assert_true(
				_oval_clear(f, f.deep_portal_pos, Kin.dir(f.deep_portal_angle), clear),
				"seed %d boss %d: the Deep gate clear of the walls" % [seed_value, b]
			)
			assert_gte(
				Kin.length(f.deep_portal_pos - f.portal_pos),
				Routes.GATE_GAP - 1e-4,
				"seed %d: the gates still apart" % seed_value
			)
		else:
			assert_true(false, "seed %d boss %d: the Deep gate still fits" % [seed_value, b])
	assert_eq(arrival_ok, SEEDS, "every arrival portal clear")
	assert_eq(deep_seen, SEEDS)

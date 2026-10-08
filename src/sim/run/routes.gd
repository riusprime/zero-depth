class_name Routes
extends RefCounted
## Optional routes (v0.5.0 PLAN R5, step RT). After the boss of a run's floor before the last, the boss room opens
## two portals: the normal gate and a Deep gate beside it (Routes.place_deep_gate). Walking into one takes that
## route (BossFlow.route_taken); the other closes. The next floor is then normal or Deep (RunState.routes):
## - Deep scaling: enemies' and bosses' HP and damage × RunTable.deep_scale_permille, composed into the floor's own
##   factors (RunState.scale_enemies / scale_bosses: one multiplication per table, never applied twice; the danger
##   tier's power still comes on top as each enemy arrives);
## - one extra chest (RunTable.deep_extra_chests) and a curse-free epic altar (Offers.roll_epic: epic stat cards and
##   ability level-ups only), on item spots the floor's own rewards left free.
## TODO(v0.5.0 EV): +1 threat T per Deep floor taken, once the run tracks T (read Routes.is_deep / RunState.routes).
## Pure sim code: no stream is drawn here (placement is a pure function of the layout), so a Deep floor's loot and
## enemies come from the same streams as a normal one.

## Appended, never inserted: routes are stored and hashed.
enum Route { NORMAL, DEEP }

## The two gates stand at least this far apart (centre to centre, m) on the boss room's back wall.
const GATE_GAP := 4.8
## Further candidates step this far (m) along a wall.
const STEP := 0.5
## Side margin (m) of a gate's kept-clear zone, and its depth margin past the front square.
const ZONE_SIDE := 1.0
const ZONE_DEPTH := 1.0
## The Deep gate keeps this clear of where the boss appears (m), and of the boss door's passage.
const SPAWN_CLEAR := 2.6
const DOOR_CLEAR := 1.5
## Extra rewards keep this far (m) from any reward already on the floor.
const REWARD_CLEAR := 2.0
const _SIDE_ANGLES := [2048, 3072, 0, 1024]


## Whether world `w` is a Deep floor (the hook for threat, curses and the views).
static func is_deep(w: World) -> bool:
	return w.boss_flow != null and w.boss_flow.deep


## Whether the run's current floor offers the choice: every floor before the last (the last floor's portal wins).
static func offers_choice(run: RunState) -> bool:
	return run != null and run.floor_index < run.table.floors


## Places the Deep gate in f's boss room: on the back wall beside the gate (each side, nearest first), else on a side
## wall from the back corner toward the door. A spot fits when the gate and its clear front lie inside the room, its
## zone keeps clear of the gate's zone, the interior pieces, the boss's spawn and the door, and its front is reached
## from the door. Returns false (and leaves has_deep_portal false) if no spot fits.
static func place_deep_gate(f: FloorLayout, params: FloorParams = null) -> bool:
	f.has_deep_portal = false
	if f.boss_room < 0:
		return false
	var p := params if params != null else FloorParams.defaults()
	var r := f.rooms[f.boss_room]
	for c: Array in candidates(f):
		if fits(f, p, r, c[0], c[1]):
			f.deep_portal_pos = c[0]
			f.deep_portal_angle = c[1]
			f.has_deep_portal = true
			return true
	return false


## Candidate [centre, facing] pairs in order of preference.
static func candidates(f: FloorLayout) -> Array:
	var r := f.rooms[f.boss_room]
	var back := (f.boss_door_angle / 1024) % 4  # the gate's wall: the door's far side
	var out := []
	var along_y := back % 2 == 0
	var g := f.portal_pos.y if along_y else f.portal_pos.x
	var lo := r.position.y if along_y else r.position.x
	var hi := r.end.y if along_y else r.end.x
	var off := GATE_GAP
	while g - off > lo or g + off < hi:
		for u in [g + off, g - off]:
			out.append([_on_wall(r, back, u), _SIDE_ANGLES[back]])
		off += STEP
	# Side walls: from the back face toward the door.
	var b := _face(r, back)
	var toward := -1.0 if back < 2 else 1.0
	var depth := r.size.x if along_y else r.size.y
	var d := FloorLayout.GATE_WIDTH * 0.5 + ZONE_SIDE + 0.2
	while d < depth:
		for s in [(back + 1) % 4, (back + 3) % 4]:
			out.append([_on_wall(r, s, b + toward * d), _SIDE_ANGLES[s]])
		d += STEP
	return out


static func fits(f: FloorLayout, p: FloorParams, r: Rect2, pos: Vector2, angle: int) -> bool:
	var room := r.grow(0.001)
	var box := collider_at(pos, angle)
	if not room.encloses(box.bounds()) or not room.encloses(_front(pos, angle)):
		return false
	var z := zone(pos, angle)
	if z.intersects(zone(f.portal_pos, f.portal_angle)):
		return false
	if z.intersects(f.door_rect(f.boss_door_index).grow(DOOR_CLEAR)):
		return false
	if Collide.circle_vs_obb(f.boss_spawn, SPAWN_CLEAR, box) != Vector2.ZERO:
		return false
	var walls: Array[Obb] = []
	for i in f.walls.size():
		var w := f.walls[i]
		if i >= f.slab_first and w.bounds().intersects(z):
			return false
		if w.bounds().intersects(r.grow(1.0)):
			walls.append(w)
	walls.append(collider_at(f.portal_pos, f.portal_angle))
	walls.append(box)
	var reach := FloorReach.new()
	reach.build(r, walls, p.nav_clearance)
	var into := Kin.dir(f.boss_door_angle)
	var approach := f.boss_door_center + into * (f.door_depths[f.boss_door_index] * 0.5 + 1.4)
	var region := reach.region_at(approach)
	return (
		region >= 0
		and reach.region_at(_front(pos, angle).get_center()) == region
		and reach.region_at(f.portal_front_point()) == region
	)


## A gate's stone footprint (FloorScenario.gate_collider's shape) at `pos` facing `angle`.
static func collider_at(pos: Vector2, angle: int) -> Obb:
	var half := Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5 + 0.35)
	return Obb.make(pos, half, angle)


## The Deep gate's footprint (a wall, like the gate's).
static func deep_gate_collider(f: FloorLayout) -> Obb:
	return collider_at(f.deep_portal_pos, f.deep_portal_angle)


## A gate's footprint, its clear front and a margin (axis-aligned: gates face a grid axis).
static func zone(pos: Vector2, angle: int) -> Rect2:
	var n := Kin.dir(angle)
	var t := Vector2(-n.y, n.x)
	var face := pos - n * FloorLayout.GATE_HALF_DEPTH
	var half_w := FloorLayout.GATE_WIDTH * 0.5 + ZONE_SIDE
	var depth := FloorLayout.GATE_HALF_DEPTH * 2.0 + FloorLayout.GATE_FRONT + ZONE_DEPTH
	return Rect2(face + t * half_w, Vector2.ZERO).expand(face - t * half_w + n * depth)


## The clear square in front of a gate (FloorLayout.portal_front's shape).
static func _front(pos: Vector2, angle: int) -> Rect2:
	var c := pos + Kin.dir(angle) * (FloorLayout.GATE_HALF_DEPTH + FloorLayout.GATE_FRONT * 0.5)
	var h := FloorLayout.GATE_FRONT * 0.5
	return Rect2(c - Vector2(h, h), Vector2(FloorLayout.GATE_FRONT, FloorLayout.GATE_FRONT))


## The clear square in front of the Deep gate.
static func deep_front(f: FloorLayout) -> Rect2:
	return _front(f.deep_portal_pos, f.deep_portal_angle)


## The face coordinate of side s of r (0 +X, 1 +Y, 2 -X, 3 -Y).
static func _face(r: Rect2, s: int) -> float:
	match s:
		0:
			return r.end.x
		1:
			return r.end.y
		2:
			return r.position.x
	return r.position.y


## A gate's centre on side s of r at coordinate u along that side.
static func _on_wall(r: Rect2, s: int, u: float) -> Vector2:
	var face := Vector2(_face(r, s), u) if s % 2 == 0 else Vector2(u, _face(r, s))
	return face + Kin.dir(_SIDE_ANGLES[s]) * FloorLayout.GATE_HALF_DEPTH


## A Deep floor's extras (setup, after Rewards.place): the epic altar, then the extra chests, on the item spots the
## floor's rewards left free (in spot order), else on the open spawn spots of rooms other than the start hall and the
## boss room. No stream is drawn. The epic altar is an altar (free) whose id BossFlow.epic_altar_id names.
static func place_deep_rewards(w: World, layout: FloorLayout, extra_chests: int) -> void:
	var spots := free_spots(w, layout)
	var chests := 0
	for i in w.rewards.size():
		if w.rewards.kind[i] == RewardStore.Kind.CHEST:
			chests += 1
	for k in mini(spots.size(), 1 + extra_chests):
		if k == 0:
			w.boss_flow.epic_altar_id = w.add_reward(RewardStore.Kind.ALTAR, spots[k], 0)
		else:
			var price := w.reward_table.chest_price(chests, w.floor_index)
			chests += 1
			w.add_reward(RewardStore.Kind.CHEST, spots[k], price)


## Spots free for an extra reward: unused item spots in spot order, then open spawn spots (rooms in order, never the
## start hall or the boss room), each REWARD_CLEAR from every reward and from each other.
static func free_spots(w: World, layout: FloorLayout) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pool := PackedVector2Array()
	for idx in Rewards.spot_order(layout):
		pool.append(layout.item_spots[idx])
	for room in layout.spawn_points.size():
		if room != layout.start_room and room != layout.boss_room:
			pool.append_array(layout.spawn_points[room])
	for q in pool:
		var ok := true
		for i in w.rewards.size():
			ok = ok and Kin.length(w.rewards.pos(i) - q) >= REWARD_CLEAR
		for o in out:
			ok = ok and Kin.length(o - q) >= REWARD_CLEAR
		if w.gamble_id >= 0:
			ok = ok and Kin.length(w.gamble_pos - q) >= REWARD_CLEAR
		if ok:
			out.append(q)
	return out


## Whether reward i is the floor's epic altar.
static func is_epic_altar(w: World, i: int) -> bool:
	return w.boss_flow != null and w.boss_flow.epic_altar_id >= 0 and w.rewards.ids[i] == w.boss_flow.epic_altar_id

class_name ObjectiveMarkers
extends RefCounted
## v0.11.0 O2 (owner L4, Q12 a): the objective markers, "what matters right now" (World.objectives). Boss code points
## at the thing the player should use (a pillar, a lantern, the twin that can be hit); the view draws an arrow at the
## screen edge while it is off screen and a soft ping on it while on screen, with a short line per reason
## (ObjectiveHints), only the first 2 runs a player meets that reason (MechanicHints, the Codex) and only while
## Options "Boss hints" is on. A marker is a hint only: no gameplay outcome reads it. Snapshotted (WorldSnapshot
## STATE_CLASSES) and hashed once a marker was ever set (touched), so worlds that never point hash as before.
##
## The API for boss code (O3-O5), called inside the tick:
## - `w.objectives.point(reason, pos)`: a fixed point (a Vector2 on the sim plane, m);
## - `w.objectives.follow(reason, entity_id)`: an actor, followed by its id while it lives (WorldReader.objectives
##   drops a marker whose actor is gone);
## - `w.objectives.clear(reason)`: every marker of that reason; `clear_all()`: every marker.
## A reason may hold several markers (each lantern), at most CAP in all (a point past the cap is ignored, so the
## outcome is the same every run). Pointing again at the same place or the same actor for the same reason changes
## nothing. The reasons O3-O5 use are the constants below (their lines: ObjectiveHints.LABELS).

const GATEKEEPER_PILLAR := &"gatekeeper_pillar"
const SHADE_LANTERN := &"shade_lantern"
const TWINS_ACTIVE := &"twins_active"
const CAP := 8
## A fixed point's entity id.
const NO_ENTITY := -1

var reasons := PackedStringArray()
var entity := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var touched := false


func size() -> int:
	return reasons.size()


## Points `reason` at a fixed point on the sim plane.
func point(reason: StringName, at: Vector2) -> void:
	for k in reasons.size():
		if reasons[k] == String(reason) and entity[k] == NO_ENTITY and pos(k) == at:
			return
	_add(reason, NO_ENTITY, at)


## Points `reason` at actor `entity_id` (followed while it lives).
func follow(reason: StringName, entity_id: int) -> void:
	for k in reasons.size():
		if reasons[k] == String(reason) and entity[k] == entity_id:
			return
	_add(reason, entity_id, Vector2.ZERO)


## Clears every marker of `reason`.
func clear(reason: StringName) -> void:
	for k in range(reasons.size() - 1, -1, -1):
		if reasons[k] == String(reason):
			reasons.remove_at(k)
			entity.remove_at(k)
			pos_x.remove_at(k)
			pos_y.remove_at(k)


func clear_all() -> void:
	reasons = PackedStringArray()
	entity = PackedInt32Array()
	pos_x = PackedFloat32Array()
	pos_y = PackedFloat32Array()


func reason_at(k: int) -> StringName:
	return StringName(reasons[k])


func pos(k: int) -> Vector2:
	return Vector2(pos_x[k], pos_y[k])


func has(reason_id: StringName) -> bool:
	return reasons.has(String(reason_id))


func _add(reason_id: StringName, entity_id: int, at: Vector2) -> void:
	if reasons.size() >= CAP or reason_id == &"":
		return
	touched = true
	reasons.append(String(reason_id))
	entity.append(entity_id)
	pos_x.append(at.x)
	pos_y.append(at.y)


func hash_into(h: StateHasher) -> void:
	h.add_int(reasons.size())
	for r in reasons:
		h.add_string(r)
	h.add_ints(entity)
	h.add_f32s(pos_x)
	h.add_f32s(pos_y)

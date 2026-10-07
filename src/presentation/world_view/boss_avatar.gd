class_name BossAvatar
extends Node3D
## The base of the three boss models (v0.3.0 C; docs/art/first-three-bosses-concept.png). It turns the sim state
## read through WorldReader into smoothed animation inputs (walk speed and phase, the windup of the attack in
## progress and its move, the hit of its active frame, a stagger, a leap's arc, burrowing, the rise-in) and each
## model poses itself from them in _pose(). Presentation only (EI-07): sync() reads once per tick, advance() animates
## in frame time, and nothing here feeds back into the sim. +X is the front and +Z the right; the node sits at the
## actor's feet under ActorViews' facing node.

## Faster than this between two ticks is a teleport, not motion.
const TELEPORT_SPEED := 40.0
## Seconds to rise out of the ground once the intro ends; seconds to sink when burrowing.
const RISE_SECONDS := 0.8
const SINK_SECONDS := 0.3
## A leap's peak height (metres).
const LEAP_HEIGHT := 2.6

## Parts and materials, read by tests and by ActorViews (the hit flash).
var body_materials: Array[StandardMaterial3D] = []
var parts: BossParts
## The model's root (moved for the rise, a leap, a burrow and a stagger's slump).
var model := Node3D.new()

# Sim state from the last sync.
var _fresh := true
var _last_tick := -1
var _last_pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _state := WorldReader.STATE_MOVE
var _move := -1
var _state_ticks := 0
var _windup := 0.0
var _leap := 0.0
var _airborne := false
var _hidden := false
# Smoothed animation state.
var _t := 0.0
var _speed := 0.0
var _walk := 0.0
var _phase := 0.0
var _wind := 0.0
var _hit := 0.0
var _rise := 1.0
var _stagger := 0.0
var _sink := 0.0


## Builds the model. technique "xray" adds a team-coloured silhouette twin to every body piece.
func setup(outline_color: Color, technique: StringName = &"xray") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parts = BossParts.new(outline_color, technique)
	model.name = "Model"
	add_child(model)
	_build()
	body_materials = parts.body_materials
	_pose(0.0)


## Reads boss i's state after a sim tick.
func sync(reader: WorldReader, i: int) -> void:
	var tg := reader.telegraph(i)
	var leap := reader.boss_leap(i)
	apply_state(
		{
			"tick": reader.tick(),
			"pos": reader.actor_pos(i),
			"state": reader.actor_state(i),
			"move": reader.boss_move(i),
			"windup": float(tg.get("progress", 0)) / 1000.0,
			"state_ticks": reader.actor_state_ticks(i),
			"airborne": leap[0],
			"leap": leap[1],
			"hidden": reader.boss_hidden(i),
		}
	)


## The same as sync(), from plain values (tests and the render scripts drive the model with this): tick, pos,
## state (a WorldReader STATE_*), and optionally move (MOVE_*, -1 none), windup (0..1), state_ticks, airborne, leap
## (0..1), hidden.
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var pos: Vector2 = s["pos"]
	var state: int = s["state"]
	var dt_ticks := tick - _last_tick
	if not _fresh and dt_ticks > 0:
		var v := (pos - _last_pos) * (60.0 / float(dt_ticks))
		_vel = v if v.length() <= TELEPORT_SPEED and dt_ticks <= 30 else Vector2.ZERO
	elif dt_ticks < 0:
		_vel = Vector2.ZERO
	_last_tick = tick
	_last_pos = pos
	if state == WorldReader.STATE_ACTIVE and _state != WorldReader.STATE_ACTIVE:
		_hit = 1.0
	_state = state
	_move = s.get("move", -1)
	_state_ticks = s.get("state_ticks", 0)
	_windup = clampf(s.get("windup", 0.0), 0.0, 1.0)
	_airborne = s.get("airborne", false)
	_leap = s.get("leap", 0.0)
	_hidden = s.get("hidden", false)
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose(0.0)


func _process(delta: float) -> void:
	advance(delta)


## Advances the animation by `delta` seconds of frame time.
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or parts == null:
		return
	_t += dt
	var moving := _state == WorldReader.STATE_MOVE
	_speed = lerpf(_speed, _vel.length() if moving or _airborne else 0.0, _rate(8.0, dt))
	_rise = move_toward(_rise, 0.0 if _state == WorldReader.STATE_SPAWN else 1.0, dt / RISE_SECONDS)
	_sink = move_toward(_sink, 1.0 if _hidden else 0.0, dt / SINK_SECONDS)
	var wind_target := 0.0
	if _state == WorldReader.STATE_WINDUP:
		wind_target = smoothstep(0.0, 0.8, _windup)
	_wind = lerpf(_wind, wind_target, _rate(10.0 if wind_target > _wind else 6.0, dt))
	_hit = move_toward(_hit, 0.0, dt * 2.2)
	var stag := 1.0 if _state == WorldReader.STATE_STAGGERED else 0.0
	_stagger = lerpf(_stagger, stag, _rate(7.0, dt))
	_pose(dt)
	# The rise from the ground, a leap's arc, the burrow's sink, the stagger's slump.
	var rise := 1.0 - _rise
	rise = rise * rise * (3.0 - 2.0 * rise)
	var lift := 0.0
	if _airborne:
		lift = 4.0 * _leap * (1.0 - _leap) * LEAP_HEIGHT
	model.position = Vector3(0, -3.2 * rise - 3.0 * _sink * _sink + lift - 0.12 * _stagger, 0)
	model.visible = _sink < 0.98


## 0..1: the attack's windup pose.
func windup_amount() -> float:
	return _wind


## 0..1: the stagger slump.
func stagger_amount() -> float:
	return _stagger


func _rate(per_second: float, dt: float) -> float:
	return 1.0 - exp(-per_second * dt)


## Walk cycle: phase advanced by speed over the stride; returns the walk blend 0..1.
func _gait(dt: float, walk_speed: float, stride: float) -> float:
	var busy := maxf(_wind, _stagger)
	_walk = lerpf(
		_walk, 0.0 if busy > 0.3 else clampf(_speed / walk_speed, 0.0, 1.0), _rate(6.0, dt)
	)
	_phase += _speed * dt * TAU / stride * (1.0 - busy)
	return _walk


## Subclasses build their parts with `parts` under `model`.
func _build() -> void:
	pass


## Subclasses pose their parts.
func _pose(_dt: float) -> void:
	pass

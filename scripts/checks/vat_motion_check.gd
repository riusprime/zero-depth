extends SceneTree
## v0.10.5 W3-V1 (the enemy VAT pilot): does a VAT instance sit where the engine draws its actor on this frame? An
## actor node is moved 3 m/s on physics ticks (60 Hz, physics interpolation on, as the game), with a VAT Swarmer under
## it (VatCrowd); every rendered frame, after the crowd has written, the instance's x is compared with the actor's
## interpolated place for this frame, lerp(previous tick, this tick, Engine.get_physics_interpolation_fraction()), and
## with the last tick's place (what a one-frame-stale read would give). Needs a renderer, vsync off:
##   APPDATA=<temp> godot --path . --position -10000,-10000 -s scripts/checks/vat_motion_check.gd
## Prints the result; writes build/vat/motion_check.txt.
## v0.10.5 W3-V4a: `-- --kind=charger` checks a VAT Charger instead (its twelve drives), into
## build/vat/motion_check_charger.txt.
## v0.10.5 W3-V4b: without --kind, one avatar of every VatCrowd kind, each under its own actor (all moved alike), every
## one checked (and the worst per kind printed).

const SPEED := 3.0
const FRAMES := 600


class Checker:
	extends Node
	var crowd: VatCrowd
	var avatars: Array[Node3D] = []
	var worst := {}
	var prev := 0.0
	var cur := 0.0
	var err_interp := PackedFloat64Array()
	var err_tick := PackedFloat64Array()
	var fractions := {}

	func _init() -> void:
		process_priority = VatCrowd.PROCESS_PRIORITY + 1

	func _process(_delta: float) -> void:
		var f := Engine.get_physics_interpolation_fraction()
		for avatar in avatars:
			var inst := crowd.instance_of(avatar)
			if inst.is_empty():
				continue
			var x: float = (inst["xf"] as Transform3D).origin.x
			fractions[snappedf(f, 0.1)] = true
			var e := absf(x - lerpf(prev, cur, f))
			err_interp.append(e)
			err_tick.append(absf(x - cur))
			var kind: int = avatar.get(&"kind")
			worst[kind] = maxf(float(worst.get(kind, 0.0)), e)


class Mover:
	extends Node
	var actors: Array[Node3D] = []
	var checker: Checker

	func _physics_process(_delta: float) -> void:
		checker.prev = actors[0].position.x
		for actor in actors:
			actor.position.x += SPEED / 60.0
		checker.cur = actors[0].position.x


var _checker: Checker
var _frame := 0
var _suffix := ""


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene := Node3D.new()
	root.add_child(scene)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.position = Vector3(0, 5, 8)
	var charger := OS.get_cmdline_user_args().has("--kind=charger")
	_suffix = "_charger" if charger else ""
	var crowd := VatCrowd.new()
	scene.add_child(crowd)
	_checker = Checker.new()
	_checker.crowd = crowd
	var mover := Mover.new()
	mover.checker = _checker
	var kinds: Array[int] = [WorldReader.KIND_CHARGER] if charger else VatCrowd.KINDS
	for kind in kinds:
		if not VatCrowd.supports(kind):
			continue
		var actor := Node3D.new()
		actor.position.z = -1.5 * mover.actors.size()
		scene.add_child(actor)
		var facing := Node3D.new()
		actor.add_child(facing)
		var a := VatBake.vat_avatar_of(kind)
		facing.add_child(a)
		a.call(&"apply_state", {"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE})
		crowd.add(actor, facing, a, Color.BLACK, false)
		_checker.avatars.append(a)
		mover.actors.append(actor)
	scene.add_child(_checker)
	scene.add_child(mover)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < FRAMES:
		return false
	var lines: PackedStringArray = []
	(
		lines
		. append(
			(
				"physics interpolation: %s  kinds: %d  instances compared: %d  fps ~%d  fraction buckets seen: %d"
				% [
					is_physics_interpolation_enabled(),
					_checker.avatars.size(),
					_checker.err_interp.size(),
					Engine.get_frames_per_second(),
					_checker.fractions.size()
				]
			)
		)
	)
	lines.append(
		(
			"instance x vs this frame's interpolated place: max %.5f m, mean %.5f m"
			% _stats(_checker.err_interp)
		)
	)
	lines.append(
		"instance x vs the last tick's place: max %.5f m, mean %.5f m" % _stats(_checker.err_tick)
	)
	lines.append("worst per kind (m, vs the interpolated place): %s" % [_checker.worst])
	var text := "\n".join(lines) + "\n"
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/vat/"))
	var f := FileAccess.open(
		ProjectSettings.globalize_path("res://build/vat/motion_check%s.txt" % _suffix),
		FileAccess.WRITE
	)
	if f != null:
		f.store_string(text)
		f.close()
	return true


static func _stats(v: PackedFloat64Array) -> Array:
	var mx := 0.0
	var sum := 0.0
	for e in v:
		mx = maxf(mx, e)
		sum += e
	return [mx, sum / maxf(1.0, v.size())]

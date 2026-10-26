extends GutTest
## v0.8.0 BA (owner O6: "the animations they do are a shit … we have to work on animations"; Q4: code clips now,
## the owner's replace them): the boss models' keyframed clips. A clip samples its keys with their eases, wraps when
## it loops, and drops its overshoots under reduced motion; an attack's clip time is driven by the sim's attack phase,
## so the strike pose is the pose on the attack's first active tick (and on each later marker's tick), read from a
## real world through WorldReader; every boss has a clip for each move its data uses (data/bosses/*.tres), the
## shielded hold for its shielded ones, and the common ones (idle, walk, flinch, stagger, roar, rise, death), and its
## clips only move bones its model has; each attack changes the silhouette; attacks crossfade; the owner's own
## AnimationPlayer clip replaces the code clip of the same name; the outline and X-ray twin are unchanged and no shader
## changes; reduced motion keeps the poses but no tremble or overshoot. Presentation only: nothing is written back.

const DT := 1.0 / 60.0
## Clips that end on a held pose rather than at rest.
## v0.8.0 BS1: the Warlord's recall holds its pull while the javelins fly back (BossAvatar._recall).
const HELD_ENDS: Array[StringName] = [&"shielded", &"stagger", &"death", &"recall"]

var classes := {
	&"gatekeeper": GatekeeperAvatar,
	&"warlord": WarlordAvatar,
	&"brood_mother": BroodMotherAvatar,
	&"hive_lens": HiveLensAvatar,
	&"siege_engine": SiegeEngineAvatar,
	&"foundry": FoundryAvatar,
}


func after_each() -> void:
	BossModels.dir = BossModels.DIR
	ViewPrefs.reduced_motion = false


func _avatar(cls: Variant, technique: StringName = &"xray") -> BossAvatar:
	var a: BossAvatar = cls.new()
	a.setup(Color("#1A1A22"), technique)
	add_child_autofree(a)
	a.set_process(false)
	return a


func _drive(a: BossAvatar, s: Dictionary, frames: int, t0: int = 0) -> void:
	for t in frames:
		var d := s.duplicate()
		d["tick"] = t0 + t + 1
		if not d.has("pos"):
			d["pos"] = Vector2.ZERO
		if s.has("count_ticks"):
			d["state_ticks"] = t
		a.apply_state(d)
		a.advance(DT)


func _defs() -> Dictionary:
	var out := {}
	for id: StringName in classes:
		out[id] = load("res://data/bosses/%s.tres" % id)
	return out


func test_a_clip_samples_its_keys_with_their_eases_and_loops_wrap() -> void:
	var c := BossClip.new(&"t")
	c.turn(&"a", Vector3.BACK, [[0, 0], [0.5, 1.0, BossClip.LINEAR], [1, 0, BossClip.IN_OUT]])
	assert_almost_eq(c.value(0, 0.0), 0.0, 1e-5)
	assert_almost_eq(c.value(0, 0.25), 0.5, 1e-5, "linear between keys")
	assert_almost_eq(c.value(0, 0.5), 1.0, 1e-5, "on the key")
	assert_almost_eq(c.value(0, 0.75), 0.5, 1e-5, "smoothstep at its middle")
	assert_almost_eq(c.value(0, 0.6), 1.0 - BossClip.ease_of(BossClip.IN_OUT, 0.2), 1e-5)
	assert_almost_eq(c.value(0, 2.0), 0.0, 1e-5, "a clip that doesn't loop clamps")
	var l := BossClip.new(&"l", true)
	l.param(&"p", [[0, 0], [0.5, 2.0, BossClip.LINEAR], [1, 0, BossClip.LINEAR]])
	assert_almost_eq(l.value(0, 1.25), 1.0, 1e-5, "a loop wraps")
	assert_almost_eq(l.value(0, -0.25), 1.0, 1e-5)
	assert_gt(BossClip.ease_of(BossClip.BACK, 0.8), 1.0, "BACK overshoots")
	assert_lt(
		BossClip.ease_of(BossClip.IN3, 0.5), BossClip.ease_of(BossClip.IN, 0.5), "IN3 is later"
	)


func test_reduced_motion_skips_overshoot_keys_and_back_eases() -> void:
	var c := BossClip.new(&"t")
	c.turn(
		&"a",
		Vector3.BACK,
		[[0, 0], [0.5, 1.0, BossClip.IN3], [0.6, 1.4, BossClip.OUT3, BossClip.SETTLE], [1, 1.0]]
	)
	assert_almost_eq(c.value(0, 0.6), 1.4, 1e-5, "the overshoot plays")
	assert_almost_eq(c.value(0, 0.6, true), 1.0, 1e-5, "reduced motion: no overshoot")
	assert_almost_eq(c.value(0, 0.5, true), 1.0, 1e-5, "the strike pose itself is kept")
	assert_lte(BossClip.ease_of(BossClip.BACK, 0.8, true), 1.0, "BACK settles without overshooting")


func test_every_boss_has_every_clip_its_moves_need() -> void:
	var defs := _defs()
	for id: StringName in classes:
		var def: Resource = defs[id]
		var a := _avatar(classes[id])
		var lib := a.animator.clips
		for name: StringName in BossAnimator.COMMON:
			assert_true(lib.has(name), "%s has its %s clip" % [id, name])
		var moves := 0
		for atk: Resource in def.get("attacks"):
			var move := StringName(atk.get("move"))
			if move == &"interphase":
				continue  # v0.9.5 BH6: a carrier of the Fallen's interphase hits, never picked: no clip
			moves += 1
			assert_true(lib.has(move), "%s: %s (%s) has its clip" % [id, atk.get("id"), move])
			if atk.get("shielded"):
				var v := StringName(String(move) + BossAnimator.SHIELDED_SUFFIX)
				assert_true(
					lib.has(v) or lib.has(&"shielded"), "%s: %s has a shielded pose" % [id, move]
				)
			# The sim's move number plays that same clip.
			var by_number := BossAnimator.MOVE_CLIPS.values().has(move)
			assert_true(by_number, "%s: %s is a sim move" % [id, move])
		assert_gt(moves, 4, "%s: its attacks were read" % id)


func test_the_clips_only_move_bones_the_model_has_and_attack_clips_end_at_rest() -> void:
	for id: StringName in classes:
		var a := _avatar(classes[id])
		for c: BossClip in a.animator.clips.values():
			for k in c.track_count():
				var target := c.targets[k]
				if target == BossClip.BODY or c.channels[k] == BossClip.PARAM:
					continue
				assert_true(a.poser.has_bone(target), "%s %s: bone %s" % [id, c.name, target])
			if c.loop or HELD_ENDS.has(c.name):
				continue
			for k in c.track_count():
				assert_almost_eq(
					c.value(k, 1.0),
					0.0,
					0.001,
					"%s %s %s ends at rest" % [id, c.name, c.targets[k]]
				)


## The pose's distance from rest: the most any bone turned (radians), plus how far the body moved (metres) and
## its squash, plus the largest parameter.
func _pose_size(a: BossAvatar) -> float:
	var most := 0.0
	for k in a.skeleton.get_bone_count():
		var rest := a.skeleton.get_bone_rest(k)
		var q := a.skeleton.get_bone_pose_rotation(k)
		most = maxf(most, q.angle_to(rest.basis.get_rotation_quaternion()))
		most = maxf(most, a.skeleton.get_bone_pose_position(k).distance_to(rest.origin) * 2.0)
	most = maxf(most, a.pivot.position.length() * 2.0)
	most = maxf(most, a.pivot.rotation.length())
	for v: float in a.animator.params.values():
		most = maxf(most, absf(v) * 0.6)
	return most


func test_each_attack_reads_as_a_big_change_at_its_anticipation_and_its_strike() -> void:
	ViewPrefs.reduced_motion = true  # no tremble: what is measured is the pose
	var defs := _defs()
	for id: StringName in classes:
		var seen := {}
		for atk: Resource in defs[id].get("attacks"):
			var move := StringName(atk.get("move"))
			if seen.has(move):
				continue
			seen[move] = true
			var number: int = BossAnimator.MOVE_CLIPS.find_key(move)
			for st: Array in [[WorldReader.STATE_WINDUP, 0.9], [WorldReader.STATE_ACTIVE, 0.0]]:
				var a := _avatar(classes[id])
				var s := {"state": WorldReader.STATE_WINDUP, "move": number, "windup": 0.9}
				_drive(a, s, 12)
				if st[0] == WorldReader.STATE_ACTIVE:
					_drive(a, {"state": WorldReader.STATE_ACTIVE, "move": number}, 1, 12)
				assert_gt(_pose_size(a), 0.3, "%s %s: a big pose (state %d)" % [id, move, st[0]])


## Steps a real world with boss `id` running attack `attack_id` against a still player, syncing the avatar every tick
## (as ActorViews does), and returns per tick [state, state ticks, the clip time, the clip's strike, its hold].
func _run_attack(id: StringName, attack_id: StringName, ticks: int) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, w.player_pos() + Vector2(4, 0))
	var reader := WorldReader.new(w)
	var a := _avatar(classes[id])
	a.sync(reader, i)
	a.advance(DT)
	BossLab.start(w, i, attack_id)
	var out := []
	for t in ticks:
		w.step(InputFrame.new())
		a.sync(reader, i)
		a.advance(DT)
		var c := a.animator.action_clip()
		(
			out
			. append(
				[
					reader.actor_state(i),
					reader.actor_state_ticks(i),
					a.animator.action_time(),
					c.strike if c != null else -1.0,
					c.hold if c != null else -1.0,
					reader.boss_attack_ticks(i),
				]
			)
		)
	return out


func test_the_strike_pose_lands_on_the_first_active_tick_read_from_the_sim() -> void:
	for pick: Array in [
		[&"gatekeeper", &"fist_slam"],
		[&"warlord", &"shield_bash"],
		[&"brood_mother", &"brood"],
		[&"hive_lens", &"lens_flare"],
		[&"siege_engine", &"shockwave"],
		[&"foundry", &"vent_blast"],
	]:
		var rows := _run_attack(pick[0], pick[1], 200)
		var last_windup := -1.0
		var struck := false
		for r: Array in rows:
			if r[0] == WorldReader.STATE_WINDUP:
				last_windup = r[2]
				assert_lt(r[2], r[3], "%s: the windup stays before the strike" % pick[1])
			elif r[0] == WorldReader.STATE_ACTIVE and r[1] == 0 and not struck:
				struck = true
				assert_almost_eq(
					r[2], r[3], 1e-5, "%s: the strike pose on the active tick" % pick[1]
				)
				assert_gt(
					last_windup, r[3] * 0.97, "%s: the anticipation filled the windup" % pick[1]
				)
				var tk: Vector4i = r[5]
				assert_gt(tk.x, 0, "the reader gives the windup ticks")
			elif r[0] == WorldReader.STATE_RECOVER and struck:
				assert_gte(r[2], r[4] - 1e-5, "%s: the recovery follows the hold" % pick[1])
		assert_true(struck, "%s %s struck" % pick)


## v0.8.0 BP (owner O27): the sped-up attacks animate on the sim's faster ticks: the reader gives the new windup and
## the strike pose lands on its first active tick (no view timer of its own).
func test_the_sped_up_attacks_animate_on_the_sims_faster_ticks() -> void:
	for pick: Array in [
		[&"warlord", &"javelin_fan", 36],  # v0.9.5 BH2: 0.6 s
		[&"warlord", &"lunge_dash", 60],
		[&"brood_mother", &"leap", 60],
		[&"hive_lens", &"dive", 60],
		[&"siege_engine", &"rail", 66],
		[&"foundry", &"bomb_launch", 42],
		[&"gatekeeper", &"fist_slam", 66],
	]:
		var struck := false
		for r: Array in _run_attack(pick[0], pick[1], 200):
			if r[0] == WorldReader.STATE_ACTIVE and r[1] == 0 and not struck:
				struck = true
				assert_eq((r[5] as Vector4i).x, int(pick[2]), "%s: the sim's new windup" % pick[1])
				assert_almost_eq(r[2], r[3], 1e-5, "%s: the strike pose on its tick" % pick[1])
		assert_true(struck, "%s %s struck" % [pick[0], pick[1]])


func test_each_marker_of_a_marks_attack_strikes_on_its_own_tick() -> void:
	var rows := _run_attack(&"gatekeeper", &"fist_slam_3", 200)
	var strikes := 0
	var gap := 0
	var struck_at := {}
	for r: Array in rows:
		if r[0] == WorldReader.STATE_RECOVER:
			break  # the first attack only
		if r[0] != WorldReader.STATE_ACTIVE:
			continue
		var tk: Vector4i = r[5]
		gap = tk.w
		if gap > 0 and r[1] % gap == 0:
			# A hit on the player holds the sim a few ticks (hitstop): count each marker's tick once.
			if not struck_at.has(r[1]):
				struck_at[r[1]] = true
				strikes += 1
			assert_almost_eq(r[2], r[3], 1e-5, "marker %d: the slam lands on its tick" % strikes)
		elif gap > 0 and r[1] % gap == gap / 2:
			assert_gt(r[2], r[3], "between markers it heaves up again")
	assert_gt(gap, 0, "three markers are a gap apart")
	assert_eq(strikes, 3, "one slam per marker")


func test_a_new_attack_crossfades_from_the_last() -> void:
	var a := _avatar(GatekeeperAvatar)
	_drive(
		a, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_MARKS, "windup": 0.9}, 20
	)
	assert_eq(a.animator.action_clip().name, &"marks")
	assert_almost_eq(a.animator.action_weight(), 1.0, 0.001)
	_drive(
		a, {"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_SWEEP, "windup": 0.1}, 2, 20
	)
	assert_eq(a.animator.action_clip().name, &"sweep", "the new attack's clip")
	assert_eq(a.animator.slot_clip[BossAnimator.PREV].name, &"marks", "the last one fading out")
	assert_between(a.animator.slot_w[BossAnimator.PREV], 0.1, 0.9)
	assert_between(a.animator.action_weight(), 0.1, 0.9, "the new one fading in")
	_drive(a, {"state": WorldReader.STATE_MOVE}, 30, 22)
	assert_lt(a.animator.action_weight(), 0.01, "and out when it is over")


func test_shielded_attacks_use_their_variant_or_the_shielded_hold() -> void:
	var g := _avatar(GatekeeperAvatar)
	_drive(
		g,
		{
			"state": WorldReader.STATE_WINDUP,
			"move": WorldReader.MOVE_PATTERN,
			"windup": 0.9,
			"shielded": true
		},
		30
	)
	assert_eq(g.animator.action_clip().name, &"pattern_shielded", "the Rock Rings curl it up")
	assert_eq(g.animator.slot_w[BossAnimator.SHIELD], 0.0, "no hold on top of its own variant")
	var w := _avatar(WarlordAvatar)
	_drive(
		w,
		{
			"state": WorldReader.STATE_WINDUP,
			"move": WorldReader.MOVE_PATTERN,
			"windup": 0.9,
			"shielded": true
		},
		30
	)
	assert_eq(w.animator.action_clip().name, &"pattern")
	assert_gt(
		w.animator.slot_w[BossAnimator.SHIELD], 0.9, "the Shield Wall braces behind its shield"
	)
	# The recovery keeps the attack's clip though the sim's shield is down by then.
	_drive(g, {"state": WorldReader.STATE_RECOVER, "move": WorldReader.MOVE_PATTERN}, 5, 30)
	assert_eq(g.animator.action_clip().name, &"pattern_shielded")


func test_the_gate_roars_the_intro_rises_with_the_bar_and_a_hit_flinches() -> void:
	for id: StringName in classes:
		var a := _avatar(classes[id])
		_drive(a, {"state": WorldReader.STATE_MOVE}, 5)
		_drive(a, {"state": WorldReader.STATE_GATE, "gate": 0.5}, 20, 5)
		assert_gt(a.animator.slot_w[BossAnimator.ROAR], 0.9, "%s roars at its phase gate" % id)
		assert_almost_eq(a.animator.slot_t[BossAnimator.ROAR], 0.5, 0.001, "with the gate")
		assert_gt(_pose_size(a), 0.3, "%s: a big roar" % id)
		var r := _avatar(classes[id])
		_drive(r, {"state": WorldReader.STATE_SPAWN, "intro": 0.5}, 60)
		assert_between(r.model.position.y, -2.4, -0.8, "%s rises with the boss bar" % id)
		assert_gt(r.animator.slot_w[BossAnimator.RISE], 0.9)
		_drive(r, {"state": WorldReader.STATE_MOVE}, 120, 60)
		assert_almost_eq(r.model.position.y, 0.0, 0.01, "%s up" % id)
		assert_eq(r.animator.slot_w[BossAnimator.RISE], 0.0, "%s: the flourish is over" % id)
		_drive(r, {"state": WorldReader.STATE_MOVE, "hp": 100}, 1, 180)
		_drive(r, {"state": WorldReader.STATE_MOVE, "hp": 90}, 3, 181)
		assert_gt(r.animator.slot_w[BossAnimator.FLINCH], 0.0, "%s flinches" % id)


func test_every_model_collapses_when_it_dies() -> void:
	for id: StringName in classes:
		var a := _avatar(classes[id])
		_drive(a, {"state": WorldReader.STATE_MOVE}, 5)
		var y := a.pivot.global_position.y
		assert_true(a.die(), "%s plays its death" % id)
		for t in int(BossAvatar.DEATH_SECONDS * 0.75 * 60.0) + 2:
			a.advance(DT)
		assert_almost_eq(a.death_amount(), 1.0, 0.01)
		assert_lt(a.pivot.global_position.y, y - 0.5, "%s has sunk away" % id)
	BossModels.dir = "res://tests/no_such_models/"
	assert_false(_avatar(GatekeeperAvatar).die(), "the code bodies still go at once")


func test_the_outline_and_xray_twin_are_unchanged_and_no_shader_changes() -> void:
	for id: StringName in classes:
		var a := _avatar(classes[id])
		var before := DamageFlashKeys.of(a)
		var m := a.body_materials[0]
		_drive(a, {"state": WorldReader.STATE_MOVE, "walk": true}, 10)
		for number: int in BossAnimator.MOVE_CLIPS:
			_drive(a, {"state": WorldReader.STATE_WINDUP, "move": number, "windup": 0.9}, 3)
			_drive(a, {"state": WorldReader.STATE_ACTIVE, "move": number}, 2)
		_drive(a, {"state": WorldReader.STATE_GATE, "gate": 0.4}, 5)
		_drive(a, {"state": WorldReader.STATE_STAGGERED, "hp": 5}, 5)
		a.die()
		for t in 30:
			a.advance(DT)
		assert_eq(DamageFlashKeys.of(a), before, "%s: no shader changed" % id)
		assert_eq(m.stencil_mode, BaseMaterial3D.STENCIL_MODE_OUTLINE, "%s keeps its stencil" % id)
		assert_eq(m.stencil_outline_thickness, 0.0, "%s: no drawn outline (owner, v0.7.5)" % id)
		var twins := a.find_children("XrayTwin", "MeshInstance3D", true, false)
		assert_eq(twins.size(), 1, "%s keeps its X-ray twin" % id)
		assert_same((twins[0] as MeshInstance3D).skin, a.imported.skin, "on the animated skeleton")
		var o := _avatar(classes[id], &"outline")
		assert_eq(o.find_children("XrayTwin", "MeshInstance3D", true, false).size(), 0)


func test_reduced_motion_keeps_the_poses_without_tremble_or_daze() -> void:
	var poses := {}
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var a := _avatar(GatekeeperAvatar)
		_drive(
			a,
			{"state": WorldReader.STATE_WINDUP, "move": WorldReader.MOVE_MARKS, "windup": 0.9},
			20
		)
		_drive(a, {"state": WorldReader.STATE_ACTIVE, "move": WorldReader.MOVE_MARKS}, 1, 20)
		var arm := a.skeleton.get_bone_pose_rotation(a.poser.index_of(&"arm_r"))
		poses[calm] = arm
		assert_gt(a.animator.param(&"tremble"), 0.5, "the strike trembles (calm: %s)" % calm)
		var off := a.pivot.position.distance_to(a.animator.body_shift)
		if calm:
			assert_almost_eq(off, 0.0, 1e-5, "reduced motion: no shake")
		_drive(a, {"state": WorldReader.STATE_STAGGERED}, 90, 21)
		if calm:
			assert_almost_eq(
				a.pivot.position.distance_to(a.animator.body_shift), 0.0, 1e-5, "no dazed sway"
			)
	assert_almost_eq(poses[true].angle_to(poses[false]), 0.0, 0.01, "the same strike pose")


func test_the_owners_clip_replaces_the_code_clip_of_the_same_name() -> void:
	var a := _avatar(WarlordAvatar)
	var head := a.poser.index_of(&"Head")
	var want := Quaternion(Vector3.UP, 0.8)
	var anim := Animation.new()
	anim.length = 2.0
	var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(tr, NodePath("Skeleton3D:Head"))
	anim.rotation_track_insert_key(tr, 0.0, want)
	anim.rotation_track_insert_key(tr, 2.0, want)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", anim)
	var player := AnimationPlayer.new()
	player.add_animation_library(&"", lib)
	add_child_autofree(player)
	assert_eq(a.animator.bind_owner(player, a.skeleton), 1, "the owner's idle is bound")
	assert_true(a.animator.owner_has(&"idle"))
	assert_false(player.active, "we sample it ourselves")
	_drive(a, {"state": WorldReader.STATE_MOVE}, 10)
	assert_almost_eq(
		a.skeleton.get_bone_pose_rotation(head).angle_to(want), 0.0, 0.01, "its pose, not ours"
	)
	# An attack's markers map the sim's phase onto the owner's timeline.
	var atk := Animation.new()
	atk.length = 3.0
	atk.add_marker(&"strike", 1.2)
	atk.add_marker(&"recover", 1.5)
	var c := BossClip.new(&"marks")
	assert_almost_eq(BossAnimator.owner_time(atk, c, c.strike * 0.5), 0.6, 1e-4, "windup half way")
	assert_almost_eq(BossAnimator.owner_time(atk, c, c.strike), 1.2, 1e-4, "the strike marker")
	assert_almost_eq(BossAnimator.owner_time(atk, c, c.hold), 1.5, 1e-4, "the recover marker")
	assert_almost_eq(BossAnimator.owner_time(atk, c, 1.0), 3.0, 1e-4, "the end")


func test_sync_reads_the_attack_timing_and_writes_nothing_back() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"warlord", Vector2(0, 0))
	var reader := WorldReader.new(w)
	assert_eq(reader.boss_attack_ticks(i), Vector4i.ZERO, "no attack, no timing")
	BossLab.start(w, i, &"spear_lines")
	var atk := BossAi.attack_of(w, i)
	var tk := reader.boss_attack_ticks(i)
	assert_eq(tk.x, atk.windup_ticks)
	assert_eq(tk.y, atk.active_ticks)
	assert_eq(tk.z, atk.recover_ticks)
	assert_eq(tk.w, 0, "one strike")
	var a := _avatar(WarlordAvatar)
	var hash_before := w.state_hash()
	a.sync(reader, i)
	a.advance(DT)
	assert_eq(w.state_hash(), hash_before, "the avatar wrote nothing back")
	assert_eq(a.animator.action_clip().name, &"flood")

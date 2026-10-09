class_name AttackFormView
extends AttackFormCanvas
## v0.6.0 MX3 (docs/design/MODIFIER_ENGINE.md §4): the eight attack forms drawn from their final specs, in MultiMesh
## pools per form layer and per particle kind, under one per-frame budget. Presentation only (EI-07): it reads the
## sim through WorldReader and never writes; an effect's timing is sim ticks (its start tick and life), drawn at the
## frame's tick plus the physics interpolation fraction, so no Timer or tween decides anything.
##
## What draws what (AttackFormLooks composes the look; this lays it out):
## - ARC: a crescent of segments swept across the arc at body height, its core in the element colour and its outer
##   edge in the heat edge (the laser blade itself stays KitView's);
## - BOLT: a dart per shot on the pattern, with a tail of segments along its own path (so a homing shot leaves a
##   curved trail, a piercing one a long streak), a tether back to the hero for a returning one;
## - RING: an expanding circle, its flat fill ground-safe, its raised front in the heat edge; count = staggered rings;
## - BEAM: a core line with a wider edge glow, from the origin to its end (a chain jump: to the enemy hit);
## - ZONE: a lingering patch (bright rim, soft centre) with its rim ring, held for its life;
## - ORBITER: `count` bodies evenly round the hero, turning, each with a short arc trail;
## - LOB: a lit bomb arcing to its target over its ground circle (filling as it falls), then a landing flash;
## - BURST: an instant disc flash with a rim and a raised front.
## Particles (per element): sparks, crackle, shards, drip, smear, emitted from the form's points. A crit adds a
## white-hot flash; a bounce a flash at the bounce.
##
## Budget (PRESENTATION §7): every layer pool and particle pool has a fixed size; at most mesh_cap() form meshes and
## particle_cap() particles are drawn a frame, the live attacks first, then the newest effects (the oldest drop).
## The Options "Effects density" (ViewPrefs.effects_density: low / medium / high) scales the particles and the caps;
## a pattern's own copies (a halo's 12 darts) are never thinned below the cap.
##
## Live wiring (what the sim emits, read each sync; AttackFormCanvas draws): the Blade's arc when its step spec has
## an element or a weight; each player bolt in its own spec's look (MX2: ProjectileStore.spec_key; element rim,
## particles and cues, a flash at each bounce); Overcharge's burst; a seeking beam's jump (Static Chain); crits; and
## MX2's runners: the RING form's rings at the sim's radius now, the spec patches (ZONE), the bombs (LOB) on their arc
## over their ground circle and their landings, the orbit blades' element glow (ORBITER). ElementVisuals and
## AbilityVisuals leave those to this view (forms_drawn) and keep drawing what has no spec (Napalm Drone's patches,
## the steel of the orbit blades, the drones).


# --- Live wiring ----------------------------------------------------------------------------------------------
func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	_tier = HeatLooks.tier_of(reader.heat_state())
	_player = reader.player_pos()
	set_density(ViewPrefs.effects_density)
	_sync_swing(reader)
	_sync_bolts(reader)
	_sync_burst(reader)
	_sync_chain(reader)
	_sync_crits(reader)
	_sync_mx2_forms(reader)


## A look adds something over the v0.5 blade or dart only with an element, a cue or a damage weight.
static func adds_layer(look: Dictionary) -> bool:
	return (
		not (look["particles"] as Array).is_empty()
		or not (look["cues"] as Array).is_empty()
		or absf(float(look["width"]) - 1.0) > 0.001
		or look["core"] != ThemePalette.color(&"player_core")
	)


func _sync_swing(reader: WorldReader) -> void:
	var t := reader.swing_tick()
	if t <= 0 or reader.player_dead():
		_last_swing = 0
		return
	var fresh := _last_swing == 0 or t < _last_swing
	_last_swing = t
	if not fresh:
		return
	var spec := reader.attack_spec(reader.step_attack_id())
	if spec.is_empty():
		return
	var look := AttackFormLooks.compose(spec, _tier)
	if not adds_layer(look):
		return
	var shape := reader.swing_shape()
	spawn(
		spec,
		_player,
		SimPlane.yaw_of(reader.swing_angle()),
		{
			"start": float(_tick - (t - 1)),
			"life": float(maxi(reader.swing_ticks(), 4)),
			"half_angle": TAU * float(shape[0]) / 4096.0,
			"reach": float(shape[1]),
			"own": float(shape[2]),
		}
	)


## The look of the spec a key names, cached per build digest and heat tier ({} for "" or an unknown key).
func _look_of(reader: WorldReader, key: String) -> Dictionary:
	if key == "":
		return {}
	var sig := "%s|%s|%d" % [reader.attack_digest(), key, _tier]
	if not _looks.has(sig):
		if _looks.size() > 64:
			_looks.clear()
		var spec := reader.attack_spec_at(key)
		_looks[sig] = AttackFormLooks.compose(spec, _tier) if not spec.is_empty() else {}
	return _looks[sig]


## A live player projectile's look: its own spec (MX2: ProjectileStore.spec_key), else the Gun bolt's (a projectile
## from before MX2's keys).
func _projectile_look(reader: WorldReader, i: int) -> Dictionary:
	var look := _look_of(reader, reader.projectile_spec_key(i))
	return look if not look.is_empty() else _look_of(reader, String(WorldReader.ATTACK_BOLT))


func _sync_bolts(reader: WorldReader) -> void:
	_live.clear()
	var seen := {}
	for i in reader.projectile_count():
		if reader.projectile_team(i) != 0 or reader.projectile_is_shard(i):
			continue
		var look := _projectile_look(reader, i)
		if look.is_empty() or not adds_layer(look):
			continue
		var id := reader.projectile_id(i)
		seen[id] = true
		var p := reader.projectile_pos(i)
		var trail: PackedVector2Array = _trails.get(id, PackedVector2Array())
		if trail.is_empty() or trail[trail.size() - 1] != p:
			trail.append(p)
		while trail.size() > STREAK_SEGMENTS + 1:
			trail.remove_at(0)
		_trails[id] = trail
		_live.append(
			{"id": id, "pos": p, "vel": reader.projectile_vel(i), "look": look, "trail": trail}
		)
		var bt := reader.projectile_bounce_tick(i)
		if bt >= 0 and _bounce_ticks.get(id, -1) != bt:
			flash(p, (look["edge"] as Color).lerp(Color.WHITE, 0.5), 0.55)
		_bounce_ticks[id] = bt
	for d: Dictionary in [_trails, _bounce_ticks]:
		for id in d.keys():
			if not seen.has(id):
				d.erase(id)


## A stable seed for a live attack from where it is (presentation only).
static func _seed_at(p: Vector2, k: int) -> int:
	return int(p.x * 97.0) * 31 + int(p.y * 131.0) + k * 7919


## MX2's lingering forms, drawn each frame from the sim's own numbers: the RING form's rings at their radius now,
## the patches (ZONE) that name a spec, the bombs in flight (LOB) and their landings, the orbit blades (ORBITER).
func _sync_mx2_forms(reader: WorldReader) -> void:
	_live_forms.clear()
	for r: Dictionary in reader.rings_live():
		var look := _look_of(reader, r["key"])
		if look.is_empty():
			look = AttackFormLooks.compose({"form": AttackFormLooks.RING}, _tier)
		var f := r.duplicate()
		f["kind"] = &"ring"
		f["look"] = look
		f["seed"] = _seed_at(r["pos"], int(r["start"]))
		_live_forms.append(f)
	var el := reader.element_fx()
	var fire_keys := reader.fire_spec_keys()
	var fire_pos: PackedVector2Array = el["fire_pos"]
	var fire_r: PackedFloat32Array = el["fire_r"]
	var fire_left: PackedInt32Array = el["fire_left"]
	for k in fire_pos.size():
		var look := _look_of(reader, fire_keys[k])
		if look.is_empty():
			continue  # Napalm Drone's patches have no spec: ElementVisuals draws them
		(
			_live_forms
			. append(
				{
					"kind": &"zone",
					"look": look,
					"pos": fire_pos[k],
					"radius": fire_r[k],
					"fade": clampf(fire_left[k] / 150.0, 0.0, 1.0),
					"seed": _seed_at(fire_pos[k], k),
				}
			)
		)
	var ab := reader.ability_fx()
	var bomb_keys := reader.bomb_spec_keys()
	var bomb_pos: PackedVector2Array = ab["bomb_pos"]
	for k in bomb_pos.size():
		var look := _look_of(reader, bomb_keys[k])
		if look.is_empty():
			look = AttackFormLooks.compose({"form": AttackFormLooks.LOB}, _tier)
		_bomb_looks[_pos_key(bomb_pos[k])] = look
		(
			_live_forms
			. append(
				{
					"kind": &"lob",
					"look": look,
					"pos": bomb_pos[k],
					"from": ab["bomb_from"][k],
					"throw": ab["bomb_throw"][k],
					"land": ab["bomb_land"][k],
					"radius": ab["bomb_r"][k],
					"seed": _seed_at(bomb_pos[k], k),
				}
			)
		)
	_sync_blasts(ab)
	_sync_orbit(reader, ab)


static func _pos_key(p: Vector2) -> String:
	return "%d,%d" % [roundi(p.x * 100.0), roundi(p.y * 100.0)]


## Each bomb that landed since the last sync flashes at its blast radius, in its bomb's look.
func _sync_blasts(ab: Dictionary) -> void:
	var bt: PackedInt32Array = ab["blast_tick"]
	var bp: PackedVector2Array = ab["blast_pos"]
	var br: PackedFloat32Array = ab["blast_r"]
	var newest := _last_blast
	for k in bt.size():
		if bt[k] <= _last_blast:
			continue
		newest = maxi(newest, bt[k])
		var look: Dictionary = _bomb_looks.get(_pos_key(bp[k]), {})
		if look.is_empty():
			look = AttackFormLooks.compose({"form": AttackFormLooks.LOB}, _tier)
		_push(
			{
				"kind": &"landing",
				"look": look,
				"origin": bp[k],
				"radius": br[k],
				"start": float(bt[k]),
				"life": float(LANDING_TICKS),
				"seed": _next_seed(),
			}
		)
	_last_blast = newest
	if _bomb_looks.size() > 64:
		_bomb_looks.clear()


## The orbit blades (AbilityVisuals draws their steel): the ORBITER spec's element glow and trail round each.
func _sync_orbit(reader: WorldReader, ab: Dictionary) -> void:
	var blades: PackedVector2Array = ab["blades"]
	if blades.is_empty():
		return
	if _orbit_sig != reader.attack_digest() + str(_tier):
		_orbit_sig = reader.attack_digest() + str(_tier)
		_orbit_look = {}
		for id in reader.attack_ids():
			var spec := reader.attack_spec(StringName(id))
			if int(spec.get("form", -1)) == AttackFormLooks.ORBITER:
				_orbit_look = AttackFormLooks.compose(spec, _tier)
				break
	if _orbit_look.is_empty() or not adds_layer(_orbit_look):
		return
	var angles := PackedFloat32Array()
	var orbit := 0.0
	for p in blades:
		angles.append((p - _player).angle())
		orbit = maxf(orbit, (p - _player).length())
	_live_forms.append(
		{
			"kind": &"orbit",
			"look": _orbit_look,
			"pos": _player,
			"angles": angles,
			"orbit": orbit,
			"seed": 4099
		}
	)


## Overcharge's shockwave: the charged step's ON_NTH burst, drawn at the sim's radius.
func _sync_burst(reader: WorldReader) -> void:
	var oc := reader.overcharge_tick()
	if oc == _last_burst:
		return
	_last_burst = oc
	if oc < 0:
		return
	var child := hook_child(
		reader.attack_spec(reader.step_attack_id()), TRIGGER_ON_NTH, WorldReader.FORM_BURST
	)
	if child.is_empty():
		child = {"form": WorldReader.FORM_BURST}
	spawn(child, _player, 0.0, {"start": float(oc), "radius": reader.shockwave_radius_m()})


## A seeking beam's jump (Static Chain): from where it fired to the enemy it hit.
func _sync_chain(reader: WorldReader) -> void:
	var ct := reader.chain_tick()
	if ct == _last_chain:
		return
	_last_chain = ct
	if ct < 0:
		return
	var child := hook_child(
		reader.attack_spec(WorldReader.ATTACK_BOLT), TRIGGER_ON_HIT, WorldReader.FORM_BEAM
	)
	if child.is_empty():
		child = {"form": WorldReader.FORM_BEAM}
	var from := reader.chain_from()
	var to := reader.chain_to()
	spawn(child, from, (to - from).angle(), {"start": float(ct), "to": to})


func _sync_crits(reader: WorldReader) -> void:
	var player_id := reader.actor_id(0)
	var n := 0
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.DAMAGE or e.owner_id != player_id or e.target_id == player_id:
			continue
		if e.tags & SimEvent.TAG_DOT or (e.tags & SimEvent.TAG_CRIT) == 0 or n >= 8:
			continue
		n += 1
		flash(e.pos, AttackFormLooks.CRIT_FLASH, 0.8)


## The child spec of `spec`'s first hook on `trigger` whose child has `form` ({} if none).
static func hook_child(spec: Dictionary, trigger: int, form: int) -> Dictionary:
	for h: Dictionary in spec.get("hooks", []):
		var c: Dictionary = h.get("child", {})
		if int(h.get("trigger", -1)) == trigger and int(c.get("form", -1)) == form:
			return c
	return {}

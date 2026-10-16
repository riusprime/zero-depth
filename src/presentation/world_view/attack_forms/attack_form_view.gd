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

## v0.8.0 AO: the order rule's lightning (_sync_ring_arcs): at most this many arcs and strikes a frame, and a thrown
## ring's strike from the hero lasts this long (ticks).
const RING_ARCS_MAX := 12
const RING_THROW_TICKS := 6.0

## v0.8.0 AO: the shock arcs and storm strikes laid since the view began, one per arc per sync (for the tests).
var ring_arcs_drawn := 0


# --- Live wiring ----------------------------------------------------------------------------------------------
func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	_tier = HeatLooks.tier_of(reader.heat_state())
	_looks_checked = false
	_player = reader.player_pos()
	set_density(ViewPrefs.effects_density)
	_sync_swing(reader)
	_sync_bolts(reader)
	_sync_charge(reader)  # v0.6.5 WN3: G13 Charge's orb
	_sync_burst(reader)
	_sync_chain(reader)
	_sync_crits(reader)
	_sync_mx2_forms(reader)
	_sync_casts(reader)  # v0.6.5 WN5a: the wand's small spells where they are cast


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
## v0.8.0 PF: the cache is keyed by the spec key alone and emptied when the digest or the tier changes (checked once a
## sync), so a crowd of bolts costs a lookup each, not a formatted string each.
func _look_of(reader: WorldReader, key: String) -> Dictionary:
	if key == "":
		return {}
	if not _looks_checked:
		_looks_checked = true
		var sig := "%s|%d" % [reader.attack_digest(), _tier]
		if sig != _looks_sig:
			_looks_sig = sig
			_looks.clear()
	if not _looks.has(key):
		if _looks.size() > 64:
			_looks.clear()
		var spec := reader.attack_spec_at(key)
		_looks[key] = AttackFormLooks.compose(spec, _tier) if not spec.is_empty() else {}
	return _looks[key]


## A live player projectile's look: its own spec (MX2: ProjectileStore.spec_key), else the Gun bolt's (a projectile
## from before MX2's keys).
func _projectile_look(reader: WorldReader, i: int) -> Dictionary:
	var look := _look_of(reader, reader.projectile_spec_key(i))
	return look if not look.is_empty() else _look_of(reader, String(WorldReader.ATTACK_BOLT))


func _sync_bolts(reader: WorldReader) -> void:
	_live.clear()
	var seen := {}
	for i in reader.projectile_count():
		if _live.size() >= LIVE_BOLTS_MAX:
			break  # v0.8.0 PF: the rest fly as their plain darts (draw_at's budget); their trails start when drawn
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
		var b := {"id": id, "pos": p, "vel": reader.projectile_vel(i), "look": look, "trail": trail}
		b["scale"] = live_scale(look, reader.projectile_radius(i))  # v0.6.5 WN3: a charged shot
		_live.append(b)
		var bt := reader.projectile_bounce_tick(i)
		if bt >= 0 and _bounce_ticks.get(id, -1) != bt:
			flash(p, (look["edge"] as Color).lerp(Color.WHITE, 0.5), 0.55)
		_bounce_ticks[id] = bt
	for d: Dictionary in [_trails, _bounce_ticks]:
		for id in d.keys():
			if not seen.has(id):
				d.erase(id)


## v0.6.5 WN3: a live bolt drawn bigger than its spec's look by its own radius (a charged shot, G13), 0.5–4×.
static func live_scale(look: Dictionary, radius: float) -> float:
	var r := float(look.get("radius", 0.0))
	return clampf(radius / r, 0.5, 4.0) if r > 0.0 else 1.0


## v0.6.5 WN3 (G13 Charge, WAND.md "it swells in the barrel"): while the Gun's shot charges, an orb at the muzzle
## grows from the bolt's size to its full charge (the sim's GunForms numbers, read; nothing decided here).
func _sync_charge(reader: WorldReader) -> void:
	var frac := reader.gun_charge()
	if frac <= 0.0 or reader.player_dead():
		return
	var spec := reader.attack_spec(WorldReader.ATTACK_BOLT)
	var look := _look_of(reader, String(WorldReader.ATTACK_BOLT))
	if look.is_empty():
		return
	var full := float(spec.get("hold_permille", 1000)) / 1000.0
	var dir := Kin.dir(reader.aim_angle())
	var at := _player + dir * 0.55
	var orb := {"id": -1, "pos": at, "vel": dir * 0.001, "look": look}
	orb["trail"] = PackedVector2Array([at])
	orb["scale"] = 1.0 + (full - 1.0) * frac
	_live.append(orb)


## A stable seed for a live attack from where it is (presentation only).
static func _seed_at(p: Vector2, k: int) -> int:
	return int(p.x * 97.0) * 31 + int(p.y * 131.0) + k * 7919


## MX2's lingering forms, drawn each frame from the sim's own numbers: the RING form's rings at their radius now,
## the patches (ZONE) that name a spec, the bombs in flight (LOB) and their landings, the orbit blades (ORBITER).
func _sync_mx2_forms(reader: WorldReader) -> void:
	_live_forms.clear()
	var order_rings: Array[Dictionary] = []
	for r: Dictionary in reader.rings_live():
		var look := _look_of(reader, r["key"])
		if look.is_empty():
			look = AttackFormLooks.compose({"form": AttackFormLooks.RING}, _tier)
		var f := r.duplicate()
		f["kind"] = &"ring"
		f["look"] = look
		f["seed"] = _seed_at(r["pos"], int(r["start"]))
		_live_forms.append(f)
		if int(look.get("ring_layout", 0)) > 0:
			order_rings.append(f)
	_sync_ring_arcs(order_rings)
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
					# By place only: a patch's index in the sim's list shifts when an older one goes out, and an
					# index seed made every later patch's flames jump (owner, 2026-10-12: "it goes buggy all around").
					"seed": _seed_at(fire_pos[k], 0),
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
		var bomb_key := _pos_key(bomb_pos[k])
		_bomb_looks.erase(bomb_key)  # P-19a: re-inserted last, so the cache's order is newest last
		_bomb_looks[bomb_key] = look
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
					"seed": _seed_at(bomb_pos[k], int(ab["bomb_throw"][k])),
				}
			)
		)
	_sync_blasts(ab)
	_sync_orbit(reader, ab)


## v0.8.0 AO (owner O37: the triple circle "shocks and hits with lighting", the swirl's "storm"): the order rule's rings
## (WandRings) get lightning between them, read from the sim's rings (their spec's look, their centres and start
## ticks; nothing decided here). The rings of one launch that started together (Ring · Spread's three) are joined by
## shock arcs round the group while they grow; a thrown ring (Swirl) gets a strike from the hero to where it lands as it
## starts. At most RING_ARCS_MAX a frame (the PF budget: each is a VfxLayer line).
func _sync_ring_arcs(rings: Array[Dictionary]) -> void:
	var groups := {}
	var arcs := 0
	for f in rings:
		var start := int(f["start"])
		var look: Dictionary = f["look"]
		var age := float(_tick - start)
		if age < 0.0:
			continue
		if bool(look.get("thrown", false)) and age < RING_THROW_TICKS and arcs < RING_ARCS_MAX:
			arcs += 1
			ring_arcs_drawn += 1
			_live_forms.append(
				_ring_arc(_player, f["pos"], start, RING_THROW_TICKS, look, f["seed"])
			)
		var gk := "%s@%d" % [f["key"], start]
		if not groups.has(gk):
			groups[gk] = []
		var g: Array = groups[gk]
		var p: Vector2 = f["pos"]
		if g.is_empty() or not (g[g.size() - 1]["pos"] as Vector2).is_equal_approx(p):
			g.append(f)
	for gk: String in groups:
		var g: Array = groups[gk]
		if g.size() < 2:
			continue
		var life := maxf(1.0, float(g[0]["end"]) - float(g[0]["start"]))
		for k in g.size():
			if arcs >= RING_ARCS_MAX:
				return
			var a: Dictionary = g[k]
			var b: Dictionary = g[(k + 1) % g.size()]
			if g.size() == 2 and k == 1:
				break  # two rings: one arc
			arcs += 1
			ring_arcs_drawn += 1
			_live_forms.append(
				_ring_arc(a["pos"], b["pos"], int(a["start"]), life, a["look"], int(a["seed"]) + k)
			)


## v0.8.0 AO: the arcs _sync_ring_arcs adds are drawn here; every other live form as the canvas draws it.
func _draw_live_form(f: Dictionary, now: float) -> void:
	if f["kind"] != &"arc":
		super(f, now)
		return
	var t := (now - float(f["start"])) / maxf(1.0, float(f["end"]) - float(f["start"]))
	if t < 0.0 or t > 1.0:
		return
	var look: Dictionary = f["look"]
	var fade := 1.0 - t * t
	var a := SimPlane.to_3d(f["pos"], BODY_H)
	var b := SimPlane.to_3d(f["to"], BODY_H)
	if vfx != null:
		vfx.line(&"storm", a, b, fade, now - float(f["start"]), int(f["seed"]))
		return
	_put(&"beam_core", segment(a, b, 0.08), lit_color(look["core"], fade, look["energy"]))
	_put(&"beam_edge", segment(a, b, 0.22), lit_color(look["edge"], 0.45 * fade, look["energy"]))
	var pts: Array[Vector3] = [a.lerp(b, 0.5)]
	_emit(f, look, pts, now, fade)


static func _ring_arc(
	from: Vector2, to: Vector2, start: int, life: float, look: Dictionary, sd: int
) -> Dictionary:
	return {
		"kind": &"arc",
		"look": look,
		"pos": from,
		"to": to,
		"start": start,
		"end": float(start) + life,
		"seed": sd,
	}


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
	if _bomb_looks.size() > 64:  # P-19a: drop the oldest, never a bomb still in flight (a flush lost its look)
		var old := _bomb_looks.keys()
		for i in old.size() - 64:
			_bomb_looks.erase(old[i])


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


# --- v0.6.5 WN5a: the wand's casts ----------------------------------------------------------------------------
## Each small spell the sim cast since the last sync (WorldReader.wand_casts, WandCasts), drawn once from its own
## spec: a trigger's cast flashes a sigil (CAST_SIGIL) and a small ring where it fires, then the child spell itself
## when it is a slash or a blast (a cast bolt flies as a live projectile, drawn by _sync_bolts with its &"cast" cue);
## a shared card's blast (Fire's kill burst, Void's pull, Explosive's blast) draws as its burst in its element.
func _sync_casts(reader: WorldReader) -> void:
	var marks := reader.wand_casts()
	if not marks.is_empty() and int(marks[marks.size() - 1]["tick"]) < _cast_tick:
		_cast_tick = -1  # a new floor's world: its ticks start again
		_cast_n = 0
	var at_tick := 0
	var last := -1
	for m: Dictionary in marks:
		var t := int(m["tick"])
		at_tick = at_tick + 1 if t == last else 1
		last = t
		if t < _cast_tick or (t == _cast_tick and at_tick <= _cast_n):
			continue
		_draw_cast(reader, m)
	if last >= 0:
		_cast_tick = last
		_cast_n = at_tick


func _draw_cast(reader: WorldReader, m: Dictionary) -> void:
	# v0.8.0 PF: the spec's look from the per-key cache (_look_of), not composed again for every blast.
	var look := _look_of(reader, String(m["key"]))
	if look.is_empty():
		return
	var pos: Vector2 = m["pos"]
	var start := float(m["tick"])
	if bool(m["cast"]):
		casts_drawn += 1
		flash(pos, AttackFormLooks.CAST_SIGIL, 0.75, start)
		spawn(
			{"form": AttackFormLooks.RING, "radius_m": CAST_RING_M, "elements": look["elements"]},
			pos,
			0.0,
			{"start": start, "life": float(CAST_RING_TICKS), "radius": CAST_RING_M}
		)
	var form := int(look["form"])
	if form == AttackFormLooks.ARC or form == AttackFormLooks.BURST:
		var name: StringName = AttackFormLooks.FORM_NAMES[form]
		cast_forms[name] = int(cast_forms.get(name, 0)) + 1
		spawn(
			{},
			pos,
			SimPlane.yaw_of(int(m["angle"])),
			{"start": start, "own": CAST_OWN_M, "look": look}
		)

class_name ActorViews
extends Node3D
## One node per live actor and projectile, keyed by entity id. Transforms are written right after each sim
## tick, and Godot's physics interpolation smooths them between ticks (PRESENTATION_CONTRACTS §2).
## Each enemy behaviour has its own silhouette, readable in greyscale (PRESENTATION §3), from the enemy sheet
## (docs/art/enemies_visual_reference.png): the Charger a red hooded crawler on four clawed legs, the Warden a
## hulking rock golem under a red shell (fists in front, a glowing weak spot on its back; no shield), the Needle a
## legged turret; v0.3.5 AI adds the Arc Caster (a robed caster with a staff) and the Bomb Drone (a hovering
## quad-rotor); v0.4.0 EN the six horde kinds (HordeAvatar).

const CUBE := 0.7
const BAR_W := 0.55
## v0.4.0 SC: projectile nodes kept for reuse per look, at most this many idle (hordes fire hundreds a second).
const PROJECTILE_POOL_MAX := 400
## v0.4.0 SC: enemy models farther than this from the hero (off screen) stop their frame-time animation. v0.8.0 HV:
## only without a camera (`cull` unset: a view built alone, as the unit tests do); the game uses the camera's view.
const ANIMATE_RADIUS_M := 24.0
## v0.9.0 VP (owner C56: "enemies in range lean into it"): an enemy a Void shot pulls tilts toward the pull, this much
## (radians) at the pull's top speed.
const LEAN_RAD := 0.35
## v0.7.5 NB1: body colours under this saturation count as grey (stone, metal, bone) for the biome's enemy cast.
const GREY_SATURATION := 0.3
## A body material's rest emission without a role glow: [colour, energy] (flashable's dark white).
const NO_GLOW := [Color.WHITE, 0.0]
## v0.8.0 N1 (owner O39: "colors are still a bit to dimmed so yellow orange and red are close because of the room
## lighning"): the normal kinds' role-coloured plates (EnemyPalettes' body and trim, saturation at or over
## GREY_SATURATION) glow a share of their own colour (emission = the albedo x ROLE_GLOW), so the hue still reads where
## the room's warm fire light and the biome's grade pull every surface toward orange; greys, eyes, bosses and the
## hero are untouched. The hit flash and the status tints still win while they last, then the glow comes back.
## Starting value (the measured line-up: docs/roadmap/v0.8.0/evidence/N1_FIXES.md).
const ROLE_GLOW := 0.45

## v0.8.0 N1: the role glow's energy the views build with (ROLE_GLOW; the line-up shot script sweeps it, 0 = none).
static var role_glow_energy := ROLE_GLOW

## Technique kept for callers: "outline" (rim only). The X-ray silhouette pass was removed in v0.9.5 PF1.
## v0.5.9: the floor's lighting mood; with one, the hero carries a small warm light (StageKit.hero_light).
var hero_mood: BiomeMood
var technique := &"outline"
## How many frames a hit flashes the actor white (PRESENTATION §6, starting value).
var flash_frames := 3
var outline_color := Color("#1A1A22")
## The look of new player bolts (ItemVisuals sets it from the items owned).
var bolt_look := {}
## v0.5.5 LK (owner A2): the heat tier (HeatLooks.TIER_*) read each sync; a new player bolt takes its colour
## (HeatLooks.attack_color: the bolt's own below Hot, orange at Hot, red at Overclock) and keeps it while it flies.
var heat_tier := HeatLooks.TIER_COOL
## v0.7.5 NB1: the biome's cast on enemies (BiomeLook.enemy_tint): their grey and bone parts pulled toward its colour
## by its alpha (0: none). Red parts (v0.8.0 EC: the role-coloured parts, EnemyPalettes, all at or over
## GREY_SATURATION), rings and bars keep their colours, so identity never changes (PRESENTATION §3).
var enemy_tint := Color(0, 0, 0, 0)
## v0.8.0 N4 (owner O57): the damage chunks on the bars over enemies and the hero (one MultiMesh for all).
var bar_chunks := BarChunks.new(BAR_W)
## v0.9.0 RB: the hero's robe and rune (a Wardrobe.look dictionary; {}: Cream, no rune), set before the hero shows.
var hero_look := {}
## v0.8.0 HV (owner O89): the camera's view (WorldViewRoot refreshes it each tick): an enemy model animates unless it
## is wholly out of the picture (ScreenCull.keeps, past its largest radius + the margin, with hysteresis).
var cull: ScreenCull
var _actors := {}
var _projectiles := {}
var _proj_last := {}
var _flash := {}
## v0.8.0 GF3 (owner O22, the Blade's hit-stop): frame seconds an actor's flash is held lit and uncounted, by id.
var _flash_hold := {}
## A steady glow per actor id (e.g. burning), shown when not flashing: [color, energy].
var _tint := {}
## v0.8.0 HV: the glow state last written to each actor's body materials, by id ([true] lit, [false] rest, or
## [false, colour, energy] a tint), so an unchanged one is not written again every tick (a burning horde's ~10
## materials each, every tick).
var _shown := {}
## v0.8.0 HV: whether each enemy model was animating at the last sync (the hysteresis's state), by id.
var _anim_on := {}
## Projectile materials by look (see _projectile_material), and one mesh per look.
var _proj_mats := {}
var _proj_meshes := {}
## v0.4.0 SC: idle projectile nodes by look key (hidden, kept as children), reused before building new ones.
var _proj_pool := {}
var _proj_pooled := 0
## P-6: the last look key per side (0 hostile, 1 player) and the [size, colour, energy] it was built from, so a shot of
## an unchanged look doesn't format its key again (a horde fires hundreds a second).
var _proj_key: Array[String] = ["", ""]
var _proj_key_of: Array = [[], []]


func sync(reader: WorldReader) -> void:
	heat_tier = reader.heat_tier()
	if bar_chunks.get_parent() == null:
		add_child(bar_chunks)
	var alive := {}
	var hero := reader.player_pos()
	var leans := reader.void_leans()  # v0.9.0 VP: empty unless a Void shot pulls someone
	for i in reader.actor_count():
		var id := reader.actor_id(i)
		alive[id] = true
		var node: Node3D = _actors.get(id)
		var fresh := node == null
		if fresh:
			node = _make_actor(
				reader.actor_kind(i), reader.actor_team(i) == 0, reader.actor_radius(i)
			)
			_actors[id] = node
			add_child(node)
			if node.has_meta(&"elite"):  # v0.9.0 EL: its own framed bar with its name (EliteBar)
				_add_elite_bar(node, tr(reader.elite_name_key(i)))
			if reader.actor_team(i) != 0:
				tint_greys(node, enemy_tint)
				role_glow(node, reader.actor_kind(i), role_glow_energy)  # v0.8.0 N1 (O39)
		node.position = SimPlane.to_3d(reader.actor_pos(i))
		var t_up := PerfMarks.start()
		_update_actor(node, reader, i)
		PerfMarks.add(&"actors.update", t_up)
		if not leans.is_empty() and leans.has(id):
			_lean(node, leans[id])
		if node.has_meta(&"enemy_avatar"):  # v0.4.0 SC: off-screen crowds don't animate
			var t_an := PerfMarks.start()
			_animate_if_seen(node, id, reader.actor_pos(i), hero)
			PerfMarks.add(&"actors.animate", t_an)
		if fresh:
			node.reset_physics_interpolation()
	_drop_missing(_actors, alive)
	bar_chunks.keep_only(alive)
	# A removed actor's flash and glow go with it (bounded).
	for d: Dictionary in [_flash, _tint, _flash_hold, _shown, _anim_on]:
		for id in d.keys():
			if not alive.has(id):
				d.erase(id)
	var live := {}
	for i in reader.projectile_count():
		if reader.projectile_look(i) != "":
			continue  # v0.7.5 BF1: a fireball (FireballViews draws them)
		if reader.projectile_team(i) == 0 and not reader.projectile_is_shard(i):
			continue  # v0.8.0 GF1: the hero's shots are blue pulses (HeroPulseViews draws them)
		var id := reader.projectile_id(i)
		live[id] = true
		var p := reader.projectile_pos(i)
		var node: Node3D = _projectiles.get(id)
		var fresh := node == null
		if fresh:
			node = _make_projectile(reader.projectile_team(i) == 0)
			_projectiles[id] = node
			if node.get_parent() == null:  # a pooled node is already here
				add_child(node)
		var last: Vector2 = _proj_last.get(id, p - reader.projectile_vel(i))
		var dir := p - last
		if dir.length() > 0.0001:
			node.rotation = Vector3(0, atan2(dir.y, dir.x), 0)
		node.position = SimPlane.to_3d(p, SimPlane.CORE_HEIGHT)
		_proj_last[id] = p
		if fresh:
			node.reset_physics_interpolation()
	_pool_missing(live)
	for id in _proj_last.keys():
		if not live.has(id):
			_proj_last.erase(id)


## v0.8.0 HV (owner O89: never skipped on screen): an enemy model animates while the camera could show it
## (ScreenCull.keeps: within its largest radius + the margin of the view, with hysteresis); without a camera, within
## ANIMATE_RADIUS_M of the hero as before. Turning back on, it runs a few short steps at once, so its smoothed pose has
## caught up before it can reach the screen (its own _process runs again before this frame is drawn).
func _animate_if_seen(node: Node3D, id: int, pos: Vector2, hero: Vector2) -> void:
	var avatar := node.get_meta(&"enemy_avatar") as Node
	var was: bool = _anim_on.get(id, false)
	var on := false
	if cull != null and cull.active:
		on = cull.keeps(SimPlane.to_3d(pos), ScreenCull.AVATAR_RADIUS_M, was)
	else:
		on = (pos - hero).length() <= ANIMATE_RADIUS_M
	_anim_on[id] = on
	avatar.set_process(on)
	if on and not was and avatar.has_method(&"advance"):
		for k in 4:
			avatar.call(&"advance", 0.05)


## v0.9.0 VP: tilts the body (its facing node, turned this frame by _update_actor) toward the Void's pull `step` (m a
## tick): LEAN_RAD at the top speed (1 m/s), less as it weakens.
func _lean(node: Node3D, step: Vector2) -> void:
	var d3 := SimPlane.to_3d(step)
	var axis := Vector3.UP.cross(d3)
	if axis.length_squared() <= 0.0:
		return
	var facing: Node3D = node.get_meta(&"facing")
	var amt := clampf(step.length() * SimTick.TICKS_PER_SECOND, 0.0, 1.0) * LEAN_RAD
	facing.basis = Basis(axis.normalized(), amt) * facing.basis


## Re-applies the mood to the hero's carried light (the dev panel's lighting page).
func retune_hero_light(mood: BiomeMood) -> void:
	hero_mood = mood
	for n in find_children("HeroLight", "OmniLight3D", true, false):
		var fresh := StageKit.hero_light(mood)
		if fresh == null:
			(n as OmniLight3D).light_energy = 0.0
			continue
		var l := n as OmniLight3D
		l.light_color = fresh.light_color
		l.light_energy = fresh.light_energy
		l.omni_range = fresh.omni_range
		fresh.free()


func actor_node(id: int) -> Node3D:
	return _actors.get(id)


func projectile_node(id: int) -> Node3D:
	return _projectiles.get(id)


## Flashes an actor white for a few frames (`frames` > 0: that many instead, e.g. a longer flash on a finisher).
func flash(id: int, frames: int = 0) -> void:
	if _actors.has(id):
		var lit := _flash.has(id)
		_flash[id] = maxi(frames if frames > 0 else flash_frames, _flash.get(id, 0))
		if not lit:  # v0.8.0 HV: already flashing, only its frames grow (the materials are lit already)
			_set_flash(_actors[id], true, id)


func is_flashing(id: int) -> bool:
	return _flash.has(id)


## v0.8.0 GF3: holds actor `id`'s flash (lit, its frames not counted down) for `seconds` of frame time.
func hold_flash(id: int, seconds: float) -> void:
	if _flash.has(id):
		_flash_hold[id] = maxf(seconds, float(_flash_hold.get(id, 0.0)))


func flash_held(id: int) -> bool:
	return _flash_hold.has(id)


func _process(delta: float) -> void:
	for id in _flash.keys():
		if _flash_hold.has(id):
			_flash_hold[id] = float(_flash_hold[id]) - delta
			if float(_flash_hold[id]) > 0.0:
				continue
			_flash_hold.erase(id)
		_flash[id] -= 1
		if _flash[id] <= 0:
			_flash.erase(id)
			if _actors.has(id):
				_set_flash(_actors[id], false, id)


## A steady glow on an actor (energy 0 clears it); a hit flash still wins while it lasts.
func set_tint(id: int, c: Color, energy: float) -> void:
	if energy <= 0.0:
		_tint.erase(id)
	else:
		var was: Array = _tint.get(id, [])
		if was.is_empty() or was[0] != c or was[1] != energy:  # v0.8.0 HV: kept when unchanged
			_tint[id] = [c, energy]
	if _actors.has(id) and not _flash.has(id):
		_set_flash(_actors[id], false, id)


## Only the emission colour and energy change here, never emission_enabled or another feature flag: those pick the
## material's shader, and switching it compiles a new shader variant (and frees it again when no material uses
## it), which stalled the frame on every hit (docs/roadmap/v0.2.0/evidence/DAMAGE_LAG.md). Flashable materials
## are built with emission on at energy 0 (flashable()).
## v0.8.0 HV: an actor's materials are written only when its glow state changes (_shown), whatever writes them.
func _set_flash(node: Node3D, on: bool, id: int = -1) -> void:
	var tint: Array = _tint.get(id, [])
	if id >= 0:
		var was: Array = _shown.get(id, [])
		if on:
			if was.size() == 1 and was[0]:
				return
			_shown[id] = [true]
		elif tint.is_empty():
			if was.size() == 1 and not was[0]:
				return
			_shown[id] = [false]
		else:
			if was.size() == 3 and was[1] == tint[0] and was[2] == tint[1]:
				return
			_shown[id] = [false, tint[0], tint[1]]
	for m: StandardMaterial3D in node.get_meta(&"mats", []):
		var rest: Array = tint if not tint.is_empty() else m.get_meta(&"rest", NO_GLOW)  # N1: the role glow
		m.emission = Color.WHITE if on else rest[0]
		m.emission_energy_multiplier = 1.6 if on else rest[1]
	if node.has_meta(&"hit_look"):  # v0.8.0 HR: an avatar on shared materials takes it per piece
		(node.get_meta(&"hit_look") as AvatarBase).show_hit(
			on or not tint.is_empty(),
			Color.WHITE if on else (tint[0] if not tint.is_empty() else Color.WHITE),
			1.6 if on else (float(tint[1]) if not tint.is_empty() else 0.0)
		)


func _update_actor(node: Node3D, reader: WorldReader, i: int) -> void:
	var facing: Node3D = node.get_meta(&"facing")
	facing.rotation = Vector3(0, SimPlane.yaw_of(reader.actor_facing(i)), 0)
	var spawning := reader.actor_spawning(i)
	# Enemy models play their own rise-in while spawning (v0.2.0 L17); the others stay hidden until they arrive.
	var show_facing := not spawning or node.has_meta(&"enemy_avatar")
	if facing.visible != show_facing:  # v0.9.5 PF3: write only what changed
		facing.visible = show_facing
	# v0.4.0 SC: an enemy's bar shows once it is hurt (a crowd at full health draws none); the hero's always.
	var bar: Node3D = node.get_meta(&"bar")
	var hurt := reader.actor_hp(i) < reader.actor_max_hp(i) or reader.actor_team(i) == 0
	var show_bar := not spawning and not node.has_meta(&"boss") and hurt
	if bar.visible != show_bar:
		bar.visible = show_bar
	if node.has_meta(&"elite_bar"):  # v0.9.0 EL: the elite's bar shows while it is out (gone while it has vanished)
		bar.visible = false
		var eb := node.get_meta(&"elite_bar") as EliteBar
		eb.visible = not spawning and not reader.elite_vanished(i)
		eb.set_fraction(float(reader.actor_hp(i)) / maxf(1.0, reader.actor_max_hp(i)))
	if bar.visible:  # v0.8.0 N4 (O57): its chunk and refill (BarChunks scales the bar to the trail's fill)
		var frac := clampf(float(reader.actor_hp(i)) / maxf(1.0, reader.actor_max_hp(i)), 0.0, 1.0)
		bar_chunks.feed(reader.actor_id(i), bar, frac, reader.actor_team(i) == 0)
	if node.has_meta(&"dazed"):
		var dz := node.get_meta(&"dazed") as Node3D
		var recovering := reader.actor_recovering(i)
		if dz.visible != recovering:
			dz.visible = recovering
	if reader.actor_egg_permille(i) >= 0:  # v0.8.0 BS1 (S3): still an egg (BossSignatureViews draws it)
		facing.visible = false
		bar.visible = false
	if node.has_meta(&"avatar"):
		var t_pa := PerfMarks.start()
		(node.get_meta(&"avatar") as PlayerAvatar).sync(reader)
		PerfMarks.add(&"actors.hero_sync", t_pa)
	# Enemy models (v0.2.0 L17): each kind's own node, animated in frame time from the sim state.
	if node.has_meta(&"enemy_avatar"):
		var t_en := PerfMarks.start()
		node.get_meta(&"enemy_avatar").sync(reader, i)
		PerfMarks.add(&"actors.enemy_sync", t_en)


## v0.4.0 SC: a projectile gone from the sim goes back to its look's pool (hidden) instead of being freed.
func _pool_missing(live: Dictionary) -> void:
	for id in _projectiles.keys():
		if live.has(id):
			continue
		var node: Node3D = _projectiles[id]
		_projectiles.erase(id)
		if _proj_pooled >= PROJECTILE_POOL_MAX:
			node.queue_free()
			continue
		node.visible = false
		var key: String = node.get_meta(&"look")
		if not _proj_pool.has(key):
			_proj_pool[key] = []
		(_proj_pool[key] as Array).append(node)
		_proj_pooled += 1


## Idle projectile nodes waiting for reuse (tests).
func pooled_projectiles() -> int:
	return _proj_pooled


func _drop_missing(nodes: Dictionary, alive: Dictionary) -> void:
	for id in nodes.keys():
		if not alive.has(id):
			var node: Node3D = nodes[id]
			nodes.erase(id)
			# v0.7.5 BM: a boss whose body falls when it dies keeps drawing its fall a moment, then goes.
			# (has_meta first: get_meta with a null default still reports a missing key, e.g. for a dummy)
			var boss: Variant = (
				node.get_meta(&"enemy_avatar") if node.has_meta(&"enemy_avatar") else null
			)
			if boss is BossAvatar and is_inside_tree() and (boss as BossAvatar).die():
				(boss as Node).set_process(true)
				get_tree().create_timer(BossAvatar.DEATH_SECONDS).timeout.connect(node.queue_free)
			elif boss is EliteAvatar and is_inside_tree() and (boss as EliteAvatar).die():
				# v0.9.0 EL: an elite topples a moment, its bars gone.
				(boss as Node).set_process(true)
				for m: StringName in [&"bar", &"elite_bar"]:
					if node.has_meta(m):
						(node.get_meta(m) as Node3D).visible = false
				get_tree().create_timer(EliteAvatar.DEATH_SECONDS).timeout.connect(node.queue_free)
			elif boss is HordeAvatar and is_inside_tree() and (boss as HordeAvatar).die():
				# v0.8.0 MI: an owner's enemy model falls (the Splitter's halves part) a moment, its bar gone.
				(boss as Node).set_process(true)
				if node.has_meta(&"bar"):
					(node.get_meta(&"bar") as Node3D).visible = false
				get_tree().create_timer(HordeAvatar.DEATH_SECONDS).timeout.connect(node.queue_free)
			else:
				node.queue_free()


func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## v0.7.5 NB1: pulls an actor's grey and bone body materials (saturation under GREY_SATURATION, untextured) toward
## `tint` by its alpha. Each avatar builds its own materials, so no other actor or biome is touched.
static func tint_greys(node: Node3D, tint: Color) -> void:
	if tint.a <= 0.0:
		return
	for m: StandardMaterial3D in node.get_meta(&"mats", []):
		if m.albedo_texture != null and not m.has_meta(&"enemy_tex"):
			continue
		m.albedo_color = grey_tinted(m.albedo_color, tint)


## v0.8.0 HR: a body colour under the biome's cast (tint_greys' rule: a grey, under GREY_SATURATION, is pulled toward
## `tint` by its alpha; any other colour, or no cast, comes back as it was). HordeAvatar picks its shared materials
## with it.
static func grey_tinted(c: Color, tint: Color) -> Color:
	if tint.a <= 0.0 or c.s >= GREY_SATURATION:
		return c
	var cold := Color(tint.r, tint.g, tint.b) * maxf(c.get_luminance() * 1.6, 0.25)
	return Color(c.lerp(cold, tint.a), c.a)


## v0.8.0 HR: whether a body colour takes the role glow (role_glow's rule: saturation at or over GREY_SATURATION).
static func role_glows(c: Color) -> bool:
	return c.s >= GREY_SATURATION


## v0.8.0 N1 (O39): a normal kind's role-coloured materials glow `energy` of their own colour (ROLE_GLOW) at rest;
## the rest state is kept on the material (meta "rest") for the flash to come back to. Kinds outside EnemyPalettes
## (bosses, the hero) and grey or textured materials keep none.
static func role_glow(node: Node3D, kind: int, energy: float) -> void:
	if energy <= 0.0 or not EnemyPalettes.KIND_IDS.has(kind):
		return
	for m: StandardMaterial3D in node.get_meta(&"mats", []):
		if (
			(m.albedo_texture != null and not m.has_meta(&"enemy_tex"))
			or not role_glows(m.albedo_color)
		):
			continue
		var c := Color(m.albedo_color, 1.0)
		m.emission = c
		m.emission_energy_multiplier = energy
		m.set_meta(&"rest", [c, energy])


## Makes a body material ready for the hit flash and tints: emission on, dark (energy 0), so a flash changes
## only shader parameters and never the shader (see _set_flash).
static func flashable(m: StandardMaterial3D) -> StandardMaterial3D:
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.0
	return m


func _body_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	ActorLooks.outline(mat, outline_color, 0.035)
	return flashable(mat)


## A box body piece: size, centre offset from the actor's feet (in the facing frame).
func _piece(parent: Node3D, size: Vector3, at: Vector3, c: Color, _team_c: Color) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	body.mesh = box
	body.material_override = _body_material(c)
	body.position = at
	parent.add_child(body)
	var root := parent.get_parent()
	var mats: Array = root.get_meta(&"mats", [])
	mats.append(body.material_override)
	root.set_meta(&"mats", mats)


func _make_actor(kind: int, is_player: bool, radius: float) -> Node3D:
	var root := Node3D.new()
	var body_color := ThemePalette.color(&"player_body" if is_player else &"enemy_body")
	var team_color := ThemePalette.color(&"player_core" if is_player else &"enemy_body")
	# Contact ring: a dark disc under the actor.
	var contact := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius + 0.1
	disc.bottom_radius = radius + 0.1
	disc.height = 0.01
	contact.mesh = disc
	var shadow := _unshaded(Color(outline_color, 0.55))
	shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	contact.material_override = shadow
	contact.position.y = 0.006
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(contact)
	# Team ring decal: identity never depends on body hue alone.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius + 0.16
	torus.outer_radius = radius + 0.24
	ring.mesh = torus
	ring.scale = Vector3(1, 0.08, 1)
	ring.material_override = _unshaded(team_color)
	ring.position.y = 0.02
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	# The body turns with the actor's facing (+X is the front).
	var facing := Node3D.new()
	root.add_child(facing)
	root.set_meta(&"facing", facing)
	var height := CUBE
	match kind:
		WorldReader.KIND_CHARGER:
			# The clawed hooded crawler (v0.2.0 L17): its own node under the facing, animated in frame time.
			var avatar := ChargerAvatar.new()
			avatar.enemy_tint = enemy_tint  # v0.8.0 HR: they pick its shared materials
			avatar.role_glow = role_glow_energy
			avatar.setup(outline_color, technique)
			root.set_meta(&"hit_look", avatar)
			facing.add_child(avatar)
			root.set_meta(&"enemy_avatar", avatar)
			root.set_meta(&"mats", avatar.body_materials.duplicate())
			height = ChargerAvatar.HEIGHT
			var dazed := MeshInstance3D.new()
			var dt := TorusMesh.new()
			dt.inner_radius = 0.22
			dt.outer_radius = 0.3
			dazed.mesh = dt
			dazed.material_override = _unshaded(ThemePalette.color(&"proj_hostile").lightened(0.3))
			dazed.position.y = height + 0.35
			dazed.scale = Vector3(1, 0.15, 1)
			dazed.visible = false
			dazed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(dazed)
			root.set_meta(&"dazed", dazed)
		WorldReader.KIND_WARDEN:
			# The rock golem (owner, v0.2.0 L17): its own node, animated in frame time.
			height = 1.25
			var warden := WardenAvatar.new()
			warden.setup(outline_color, technique)
			facing.add_child(warden)
			root.set_meta(&"enemy_avatar", warden)
			root.set_meta(&"mats", warden.body_materials.duplicate())
		WorldReader.KIND_NEEDLE:
			# The walking turret (v0.2.0 L17): its own node under the facing, animated in frame time.
			var needle := NeedleAvatar.new()
			needle.setup(outline_color, technique)
			facing.add_child(needle)
			height = NeedleAvatar.HEIGHT
			root.set_meta(&"enemy_avatar", needle)
			root.set_meta(&"mats", needle.body_materials.duplicate())
		WorldReader.KIND_ARC_CASTER:
			# The Arc Caster (v0.3.5 AI): a robed caster with a staff, its own node under the facing.
			var caster := ArcCasterAvatar.new()
			caster.setup(outline_color, technique)
			facing.add_child(caster)
			height = ArcCasterAvatar.HEIGHT
			root.set_meta(&"enemy_avatar", caster)
			root.set_meta(&"mats", caster.body_materials.duplicate())
		WorldReader.KIND_BOMB_DRONE:
			# The Bomb Drone (v0.3.5 AI): drawn hovering, its shadow on the ground where the sim has it.
			var drone := BombDroneAvatar.new()
			drone.setup(outline_color, technique)
			facing.add_child(drone)
			height = BombDroneAvatar.HEIGHT
			root.set_meta(&"enemy_avatar", drone)
			root.set_meta(&"mats", drone.body_materials.duplicate())
		WorldReader.KIND_LENS_DRONE:
			# The Hive Lens's drones (v0.4.0 BO): drawn hovering, their shadow where the sim has them.
			var lens := LensDroneAvatar.new()
			lens.setup(outline_color, technique)
			facing.add_child(lens)
			height = LensDroneAvatar.HEIGHT
			root.set_meta(&"enemy_avatar", lens)
			root.set_meta(&"mats", lens.body_materials.duplicate())
		WorldReader.KIND_HATCHLING:
			# The Brood Mother's hatchling (v0.3.0 C): a Charger crawler at two thirds of the size.
			var hatch := ChargerAvatar.new()
			hatch.enemy_tint = enemy_tint  # v0.8.0 HR: they pick its shared materials
			hatch.role_glow = role_glow_energy
			hatch.setup(outline_color, technique, WorldReader.KIND_HATCHLING)  # v0.8.0 EC: its colours
			root.set_meta(&"hit_look", hatch)
			hatch.scale = Vector3.ONE * 0.66
			facing.add_child(hatch)
			height = ChargerAvatar.HEIGHT * 0.66
			root.set_meta(&"enemy_avatar", hatch)
			root.set_meta(&"mats", hatch.body_materials.duplicate())
		_ when WorldReader.is_boss_kind(kind):
			# The bosses (v0.3.0 C): their own models; their HP shows in the HUD's boss bar, not over them.
			var boss: BossAvatar = (
				{
					WorldReader.KIND_GATEKEEPER: GatekeeperAvatar,
					WorldReader.KIND_BROOD_MOTHER: BroodMotherAvatar,
					WorldReader.KIND_SIEGE_ENGINE: SiegeEngineAvatar,
					WorldReader.KIND_WARLORD: WarlordAvatar,  # v0.4.0 BO
					WorldReader.KIND_HIVE_LENS: HiveLensAvatar,
					WorldReader.KIND_FOUNDRY: FoundryAvatar,
					WorldReader.KIND_COLOSSUS: ColossusAvatar,  # v0.8.0 FB1: the final boss's bodies
					WorldReader.KIND_PRISM: PrismAvatar,
					WorldReader.KIND_NEMESIS: NemesisAvatar,
					WorldReader.KIND_TIDECALLER: TidecallerAvatar,  # v0.9.0 NB1
					WorldReader.KIND_TWIN_WARDEN: TwinWardenAvatar,  # v0.9.0 NB2: the amber body
					WorldReader.KIND_TWIN_WARDEN_VIOLET: TwinWardenVioletAvatar,  # its twin
					WorldReader.KIND_CLOCKWORK_JUDGE: ClockworkJudgeAvatar,  # v0.9.0 NB3
					WorldReader.KIND_LANTERN_SHADE: LanternShadeAvatar,  # v0.9.0 NB4
				}[kind]
				. new()
			)
			boss.setup(outline_color, technique)
			facing.add_child(boss)
			height = 2.6 * BossModels.SIZE_SCALE
			root.set_meta(&"enemy_avatar", boss)
			root.set_meta(&"boss", true)
			root.set_meta(&"mats", boss.body_materials.duplicate())
		_ when EliteAvatar.is_elite_kind(kind):
			# v0.9.0 EL: the owner's elite models, posed in code; their own bar (EliteBar, added by sync()).
			var elite := EliteAvatar.new()
			elite.enemy_tint = enemy_tint  # they pick its shared materials
			elite.role_glow = role_glow_energy
			elite.setup(kind, outline_color, technique)
			facing.add_child(elite)
			height = elite.height
			root.set_meta(&"enemy_avatar", elite)
			root.set_meta(&"mats", elite.body_materials.duplicate())
			root.set_meta(&"hit_look", elite)
			root.set_meta(&"elite", true)
		_ when HordeAvatar.is_horde_kind(kind):
			# The horde kinds (v0.4.0 EN): one code-built model per kind.
			var horde := HordeAvatar.new()
			horde.enemy_tint = enemy_tint  # v0.8.0 HR: they pick its shared materials (tint_greys, role_glow)
			horde.role_glow = role_glow_energy
			horde.setup(kind, outline_color, technique)
			facing.add_child(horde)
			height = horde.height
			root.set_meta(&"enemy_avatar", horde)
			root.set_meta(&"mats", horde.body_materials.duplicate())
			root.set_meta(&"hit_look", horde)  # v0.8.0 HR: the flash and tints (_set_flash)
		_ when kind == WorldReader.KIND_PLAYER and is_player:
			# The hooded wanderer (owner, 2026-10-07): its own node, animated in frame time.
			height = 1.0
			var avatar := PlayerAvatar.new()
			avatar.setup(outline_color, technique)
			avatar.set_look(hero_look)  # v0.9.0 RB: the Wardrobe's robe and the run's rune
			root.add_child(avatar)
			root.set_meta(&"avatar", avatar)
			root.set_meta(&"mats", avatar.body_materials.duplicate())
			var glow := StageKit.hero_light(hero_mood)  # v0.5.9: the hero's warm light
			if glow != null:
				root.add_child(glow)
		_:  # kept deliberately: the grey-cube fallback draws a kind without its own model (a new enemy kind; P-18)
			var size := CUBE if is_player else CUBE * 0.85
			height = size
			_piece(
				facing, Vector3(size, size, size), Vector3(0, size * 0.5, 0), body_color, team_color
			)
			if is_player:
				_add_core_panels(facing, size)
	if not is_player:  # v0.9.5 PF4: only the largest rig pieces cast a shadow (the hero is unchanged)
		ShadowTrim.trim(
			facing, ShadowTrim.BOSS_KEEP if root.has_meta(&"boss") else ShadowTrim.ENEMY_KEEP
		)
	# Floating health bar, as in the reference; it shrinks toward its centre as HP drops.
	var bar_root := Node3D.new()
	bar_root.position = Vector3(0, height + 0.55, 0)
	root.add_child(bar_root)
	var bar := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(BAR_W, 0.07)
	bar.mesh = quad
	var bm := _unshaded(ThemePalette.color(&"player_bar" if is_player else &"enemy_bar"))
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.billboard_keep_scale = true
	bm.no_depth_test = true
	bar.material_override = bm
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pivot := Node3D.new()
	pivot.add_child(bar)
	bar_root.add_child(pivot)
	root.set_meta(&"bar", pivot)
	return root


## v0.9.0 EL: the elite's framed bar and name (EliteBar), above its head on the actor's root (it never turns with
## the facing).
func _add_elite_bar(root: Node3D, name_text: String) -> void:
	var eb := EliteBar.new()
	eb.name = "EliteBar"
	var bar: Node3D = root.get_meta(&"bar")
	eb.position = (bar.get_parent() as Node3D).position + Vector3(0, 0.25, 0)
	eb.setup(name_text)
	root.add_child(eb)
	root.set_meta(&"elite_bar", eb)


func _add_core_panels(root: Node3D, size: float) -> void:
	var core := StandardMaterial3D.new()
	core.albedo_color = ThemePalette.color(&"player_core")
	core.emission_enabled = true
	core.emission = ThemePalette.color(&"player_core")
	core.emission_energy_multiplier = 2.2
	var panel := BoxMesh.new()
	panel.size = Vector3(size * 0.5, size * 0.38, 0.02)
	for k in 4:
		var n := MeshInstance3D.new()
		n.mesh = panel
		n.material_override = core
		var yaw := k * PI * 0.5
		n.rotation = Vector3(0, yaw, 0)
		n.position = (
			Vector3(sin(yaw), 0, cos(yaw)) * (size * 0.5 + 0.045) + Vector3(0, size * 0.3, 0)
		)
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(n)


## The colour a player bolt fired now takes: the bolt look's own (ItemVisuals), or the heat tier's from Hot up.
func bolt_color() -> Color:
	return AttackView.edge_color(
		bolt_look.get("color", ThemePalette.color(&"player_core")), heat_tier
	)


## Hostile shots are yellow streaks; the player's bolts were short cyan darts (reserved colours, PRESENTATION §3).
## v0.8.0 GF1: only the hero's shrapnel shards are still drawn here as darts (HeroPulseViews draws the hero's shots).
## v0.4.0 SC: a node of the same look comes back from the pool when there is one; the mesh is shared per look.
func _make_projectile(is_player: bool = false) -> Node3D:
	var size := Vector3(0.55, 0.05, 0.08)
	if is_player:
		size = bolt_look.get("size", Vector3(0.38, 0.07, 0.07))
	var role := &"player_core" if is_player else &"proj_hostile"
	var c := ThemePalette.color(role)
	if is_player:
		c = bolt_color()
	var energy: float = bolt_look.get("energy", 2.5) if is_player else 2.5
	var side := 1 if is_player else 0
	var of := [size, c, energy]
	if of != _proj_key_of[side]:
		_proj_key_of[side] = of
		_proj_key[side] = "%s|%s|%s" % [size, c.to_html(), energy]
	var key := _proj_key[side]
	var idle: Array = _proj_pool.get(key, [])
	if not idle.is_empty():
		var reused: Node3D = idle.pop_back()
		_proj_pooled -= 1
		reused.visible = true
		return reused
	if not _proj_meshes.has(key):
		var box := BoxMesh.new()
		box.size = size
		_proj_meshes[key] = box
	var n := MeshInstance3D.new()
	n.mesh = _proj_meshes[key]
	n.material_override = _projectile_material(c, energy)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.set_meta(&"look", key)
	holder.add_child(n)
	return holder


## One shared material per bolt look, kept for the view's life. A fresh material per shot meant that whenever the
## last shot of a look was freed its shader variant went with it, and the next shot compiled it again (a stall).
func _projectile_material(c: Color, energy: float) -> StandardMaterial3D:
	var key := "%s|%s" % [c.to_html(), energy]
	if not _proj_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		_proj_mats[key] = m
	return _proj_mats[key]

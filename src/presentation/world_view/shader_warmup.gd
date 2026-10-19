class_name ShaderWarmup
extends Node3D
## v0.8.0 HR (owner O89: no fps drops "during the fun part of the game"; RenderSwitches.SHADER_WARMUP): the floor's
## effect, attack and enemy shaders drawn once behind the loading cover, so the first shot, spawn or effect of a floor
## never compiles a shader or a pipeline mid-fight. ViewWarmup reads the files on a worker; this is its drawing half,
## the view build's last job (WorldViewRoot.queue_setup):
## - every mesh and material the built view holds but does not draw yet (a hidden pool slot, a MultiMesh with no
##   instance shown: the hero's casts and swings, the effects layer's pools, the attack forms), one proxy each;
## - the materials made only on first use (the hero pulse's core, glow and trail, the fireball's shaders, the boss
##   strike marks, the impact flare and the cast sigil);
## - one enemy of each horde kind and a Charger and Hatchling, built as ActorViews builds them (their shared
##   EnemyLooks materials, this floor's tint).
## Every proxy sits in front of the camera (AT in its frame), scaled to TINY (well under a pixel): the draw is issued,
## nothing shows. A load builds the view hidden under the closed cover (Main), so the warm-up hangs beside the view
## (its parent), where it draws while the cover is still closed; without one (a tool's setup()) it hangs off the
## camera. It frees itself after FRAMES frames with its camera current (MAX_WAIT frames at most). Presentation only
## (EI-07); same pixels.

const AT := Vector3(0, 0, -1.5)
const TINY := 0.001
const FRAMES := 3
const MAX_WAIT := 600
## At most this many proxies from the view's hidden pieces (each a draw for FRAMES frames).
const MAX_PROXIES := 400
const HORDE_KINDS: Array[int] = [
	WorldReader.KIND_SWARMER,
	WorldReader.KIND_SPLITTER,
	WorldReader.KIND_SPLITLING,
	WorldReader.KIND_SHIELD_BEARER,
	WorldReader.KIND_MENDER,
	WorldReader.KIND_MINE_LAYER,
	WorldReader.KIND_SNIPER,
]

## The proxies made (tests): from the view's hidden pieces, from the first-use materials, and horde enemies.
var hidden_proxies := 0
var lazy_proxies := 0
var enemies := 0
var _frames := 0
var _waited := 0
var _camera: Camera3D
var _seen := {}
var _quad := QuadMesh.new()


## Builds the warm-up under `camera` for the view under `view_root` (its ActorViews `actors`); null when the switch
## is off or there is no camera.
static func build(view_root: Node, camera: Camera3D, actors: ActorViews) -> ShaderWarmup:
	if not RenderSwitches.SHADER_WARMUP or camera == null:
		return null
	var w := ShaderWarmup.new()
	w.name = "ShaderWarmup"
	w.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	w._camera = camera
	w._quad.size = Vector2.ONE
	for c in view_root.get_children():  # the root itself is hidden while a load builds it
		w._from_view(c, false)
	w._first_use()
	w._enemies(actors)
	var host := view_root.get_parent() if view_root.is_inside_tree() else null
	if host != null and camera.is_inside_tree():
		host.add_child(w)
		w.global_transform = (
			camera.global_transform * Transform3D(Basis.from_scale(Vector3.ONE * TINY), AT)
		)
	else:
		w.position = AT
		w.scale = Vector3.ONE * TINY
		camera.add_child(w)
	return w


func _process(_delta: float) -> void:
	_waited += 1
	if is_instance_valid(_camera) and get_viewport().get_camera_3d() == _camera:
		_frames += 1
	if _frames > FRAMES or _waited > MAX_WAIT or not is_instance_valid(_camera):
		queue_free()


## The view's pieces not drawn now (`hidden`: under a hidden node; a MultiMesh showing no instance).
func _from_view(n: Node, hidden: bool) -> void:
	if hidden_proxies >= MAX_PROXIES or n == self:
		return
	var off := hidden or (n is Node3D and not (n as Node3D).visible)
	if n is MultiMeshInstance3D:
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm != null and mm.mesh != null and (off or _shown(mm) == 0):
			_multimesh_proxy(mm, mmi.material_override)
	elif n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and off:
			_mesh_proxy(mi)
	for c in n.get_children():
		_from_view(c, off)


static func _shown(mm: MultiMesh) -> int:
	return mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count


func _mesh_proxy(mi: MeshInstance3D) -> void:
	var key := "m/%d/%d" % [mi.mesh.get_instance_id(), _material_id(mi)]
	if _seen.has(key):
		return
	_seen[key] = true
	var p := MeshInstance3D.new()
	p.mesh = mi.mesh
	p.material_override = mi.material_override
	for k in mi.get_surface_override_material_count():
		p.set_surface_override_material(k, mi.get_surface_override_material(k))
	_add(p)
	hidden_proxies += 1


func _multimesh_proxy(src: MultiMesh, mat: Material) -> void:
	var key := (
		"mm/%d/%d/%d/%d/%d"
		% [
			src.mesh.get_instance_id(),
			mat.get_instance_id() if mat != null else 0,
			src.transform_format,
			int(src.use_colors),
			int(src.use_custom_data),
		]
	)
	if _seen.has(key):
		return
	_seen[key] = true
	var mm := MultiMesh.new()
	mm.transform_format = src.transform_format
	mm.use_colors = src.use_colors
	mm.use_custom_data = src.use_custom_data
	mm.mesh = src.mesh
	mm.instance_count = 1
	var p := MultiMeshInstance3D.new()
	p.multimesh = mm
	p.material_override = mat
	_add(p)
	hidden_proxies += 1


static func _material_id(mi: MeshInstance3D) -> int:
	if mi.material_override != null:
		return mi.material_override.get_instance_id()
	var h := 0
	for k in mi.get_surface_override_material_count():
		var m := mi.get_surface_override_material(k)
		h = hash([h, m.get_instance_id() if m != null else 0])
	return h


## The materials the views make only on first use (one each: the shader and its pipeline are what compile).
func _first_use() -> void:
	var hero := ThemePalette.color(&"player_core")
	var mats: Array[Material] = [
		HeroPulseViews.core_material(hero, 1.0),
		HeroPulseViews.glow_material(hero),
		HeroPulseViews.trail_material(hero),
		_bare(BossStrikeLooks.mark_shader()),
		_bare(FireballShaders.core(true)),
		_bare(FireballShaders.core(false)),
		_bare(FireballShaders.edge()),
		_bare(FireballShaders.trail(true)),
		_bare(FireballShaders.trail(false)),
		FxTextures.flare_material(hero, Color.WHITE, 0),
		FxTextures.sigil_material(hero, 0),
	]
	for m in mats:
		if m == null:  # an effect sheet not installed: that effect draws its fallback
			continue
		var p := MeshInstance3D.new()
		p.mesh = _quad
		p.material_override = m
		_add(p)
		lazy_proxies += 1


static func _bare(s: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = s
	return m


## One enemy of each horde kind as ActorViews would build it on this floor (its shared materials and meshes made
## now too), still (no frame-time animation).
func _enemies(actors: ActorViews) -> void:
	if actors == null:
		return
	for kind in HORDE_KINDS:
		var h := HordeAvatar.new()
		h.enemy_tint = actors.enemy_tint
		h.role_glow = ActorViews.role_glow_energy
		h.setup(kind, actors.outline_color, actors.technique)
		h.set_process(false)
		add_child(h)
		enemies += 1
	for kind in [WorldReader.KIND_CHARGER, WorldReader.KIND_HATCHLING]:  # the Charger's shared look too
		var c := ChargerAvatar.new()
		c.enemy_tint = actors.enemy_tint
		c.role_glow = ActorViews.role_glow_energy
		c.setup(actors.outline_color, actors.technique, kind)
		c.set_process(false)
		add_child(c)
		enemies += 1


func _add(p: GeometryInstance3D) -> void:
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(p)

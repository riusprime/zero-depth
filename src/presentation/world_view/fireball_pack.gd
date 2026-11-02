class_name FireballPack
extends RefCounted
## v0.10.0 VX4: how FireballViews holds a hostile shot's pack effect (PackFx, family enemy_shot), and (v0.10.5, owner
## PERF_PLAYLOG_1: view.fireballs 53.1 ms on f1 and 47.3 ms on f2, a look's first volley instancing its scenes) the
## shots' pools filled at the floor's load (WorldViewRoot, behind the cover). Looks only (EI-07).

## The least a pack flame's particle lifetime shrinks to for a small shot (its share of the scene's own).
const FLAME_LIFE_MIN := 0.4
## v0.10.5: idle pack shots made per look at the floor's load (prefill; a starting value: a first volley's size).
## Shots past it instance their scene as before.
const PREFILL := 8


## The pack ids the shots draw with (one a look, FireballViews.PACK_SKIP left out).
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in FireballViews.LOOKS:
		if not FireballViews.PACK_SKIP.has(key):
			out.append(StringName("shot_%s" % key))
	return out


## v0.10.5: `pack`'s pool for the shot id `id` filled to PREFILL idle instances, each with its own particle materials
## already (own_particles): the floor's first volley of a look takes them.
static func prefill(pack: PackFx, id: StringName) -> void:
	if pack == null or not FireballViews.PACK_SHOTS or not pack.has_id(id):
		return
	for node in pack.prefill(id, PREFILL):
		own_particles(node)


## v0.10.5 PC (owner PERF_PLAYLOG_2: idle pool nodes in the tree cost every frame): FireballViews.prepare's sets wait
## outside the tree until their look first draws. The set nodes outside it (`sets`: FireballViews._sets).
static func detached(sets: Dictionary) -> Array[Node]:
	var out: Array[Node] = []
	for key: StringName in sets:
		for part: String in ["core", "edge", "trail"]:
			var mi: Node = sets[key][part]
			if mi.get_parent() == null:
				out.append(mi)
	return out


## A look's set (`set_parts`: its core, edge and trail) put in `view`'s tree, if it waits outside it.
static func attach(view: Node, set_parts: Dictionary) -> void:
	for part: String in ["core", "edge", "trail"]:
		var mi: Node = set_parts[part]
		if mi.get_parent() == null:
			view.add_child(mi)


## A shot's own copy of each particle material (keep_playing scales them by the shot's size); once a node.
static func own_particles(node: Node3D) -> void:
	if node.has_meta(&"vx4_dup"):
		return
	node.set_meta(&"vx4_dup", true)
	for c in node.get_children():
		var gp := c as GPUParticles3D
		if gp != null and gp.process_material is ParticleProcessMaterial:
			gp.process_material = gp.process_material.duplicate()


## A held effect must not end by itself: PackFx makes a scene with no animation one-shot, and an animation's end gives
## the effect back; here it loops until the shot ends. A flame or spark particle is not sized by its node's scale in
## world space, so the node's own particle materials scale by `k` (the shot's size). (Colours: PackFx's; the pack's
## shared ShaderMaterials are the lead's to make per-instance.)
static func keep_playing(node: Node3D, k: float) -> void:
	var anim := node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation(PackFx.ANIM):
		anim.get_animation(PackFx.ANIM).loop_mode = Animation.LOOP_LINEAR
	if not node.has_meta(&"vx4_own"):
		node.set_meta(&"vx4_own", true)
		node.set_meta(&"vx4_k", 1.0)
		own_particles(node)
		for c in node.get_children():
			var gp := c as GPUParticles3D
			if gp != null:  # (a smaller shot leaves a shorter flame: the trail is the distance flown in a lifetime)
				gp.lifetime *= clampf(k * 1.6, FLAME_LIFE_MIN, 1.0)
	var ratio := k / float(node.get_meta(&"vx4_k"))
	if not is_equal_approx(ratio, 1.0):
		node.set_meta(&"vx4_k", k)
	for c in node.get_children():
		var p := c as GPUParticles3D
		if p == null:
			continue
		if not is_equal_approx(ratio, 1.0) and p.process_material is ParticleProcessMaterial:
			var pm := p.process_material as ParticleProcessMaterial
			pm.scale_min *= ratio
			pm.scale_max *= ratio
		if p.one_shot:
			p.one_shot = false
			p.restart()

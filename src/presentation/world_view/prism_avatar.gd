class_name PrismAvatar
extends FinalBodyAvatar
## v0.8.0 FB1 (FINAL_BOSS.md F5; the fight is FB2's): the final boss's second body, the owner's model
## assets/models/bosses/final_boss_prism.glb (the torn figure ringed by floating red crystal shards), floating, moved
## as a whole by placeholder clips (FinalStubClips.prism). TODO FB2: its shards as separate pieces that orbit and fire,
## the Cross's beams. Without the model, a code-made crystal stand-in.

const HEIGHT := 3.0
const MODEL_CHEST := Vector3(0.4, 1.9, 0.0)
const CRYSTAL := Color("#C8384E")
const ROBE := Color("#D9CFC8")

var stand_in := Node3D.new()


func model_id() -> StringName:
	return &"final_boss_prism"


func _code_nodes() -> Array[Node]:
	return [stand_in]


func _clip_library() -> Dictionary:
	return FinalStubClips.prism()


func _walk_speed() -> float:
	return 1.0


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.5, 1.8, 0)


func _weak_bone() -> StringName:
	return &"root"


func _build() -> void:
	var p := parts
	stand_in.name = "StandIn"
	model.add_child(stand_in)
	p.piece(stand_in, BossParts.crystal(2.2, 0.6, 21), Vector3(0, 0.6, 0), ROBE)
	for k in 6:
		var a := TAU * k / 6.0
		p.piece(
			stand_in,
			BossParts.crystal(0.7, 0.18, 30 + k),
			Vector3(cos(a) * 1.1, 1.6 + 0.3 * (k % 2), sin(a) * 1.1),
			CRYSTAL
		)

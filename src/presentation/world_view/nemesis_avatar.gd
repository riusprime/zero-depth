class_name NemesisAvatar
extends FinalBodyAvatar
## v0.8.0 FB1 (FINAL_BOSS.md F6; the fight is FB3's): the final boss's last body, the owner's model
## assets/models/bosses/final_boss_nemesis.glb (the small dark hooded figure, the hero's nemesis), moved as a whole by
## placeholder clips (FinalStubClips.nemesis). TODO FB3: its mimicry (your weapon, your dash, your cards) and its rig.
## Without the model, a code-made hooded stand-in.

const HEIGHT := 1.5
const MODEL_CHEST := Vector3(0.25, 0.9, 0.0)
const CLOAK := Color("#2B2530")
const EYE := Color("#FF3A3A")

var stand_in := Node3D.new()


func model_id() -> StringName:
	return &"final_boss_nemesis"


func _code_nodes() -> Array[Node]:
	return [stand_in]


func _clip_library() -> Dictionary:
	return FinalStubClips.nemesis()


func _walk_speed() -> float:
	return 4.6


func _stride() -> float:
	return 1.1


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.3, 0.8, 0)


func _weak_bone() -> StringName:
	return &"root"


func _build() -> void:
	var p := parts
	stand_in.name = "StandIn"
	model.add_child(stand_in)
	p.piece(stand_in, BossParts.crystal(1.3, 0.45, 41), Vector3(0, 0.0, 0), CLOAK)
	p.glow(stand_in, BossParts.block(Vector3(0.06, 0.08, 0.2), 6), Vector3(0.3, 1.0, 0), EYE, 2.5)

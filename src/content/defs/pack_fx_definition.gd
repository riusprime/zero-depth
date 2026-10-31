class_name PackFxDefinition
extends ContentDef
## v0.10.0 VX0 (docs/roadmap/v0.9.5/VFX_PACK.md, the owner's purchased Binbun VFX pack): the table of pack effects the
## game spawns, one row per short id (PackFx). Later steps only add rows. One `.tres` (data/vfx/pack_fx.tres); the
## fields are parallel arrays, one entry per effect:
## - ids: the short name the views spawn by (`explosion_fire_a`);
## - scenes: the pack scene's path under assets/BinbunVFX;
## - families: what kind of effect it is, which sets the live cap (PackFx.CAPS);
## - scales: the scale the scene is drawn at when a caller asks for 1.0;
## - primary / secondary / tertiary: the scene's colours; an alpha of 0 keeps the scene's own.

## The families a row may name; PackFx.CAPS holds each one's live cap (I5).
const FAMILIES: Array[StringName] = [
	&"hit", &"impact", &"explosion", &"area", &"beam", &"cloud", &"projectile", &"status"
]

@export var ids: Array[StringName] = []
@export var scenes := PackedStringArray()
@export var families: Array[StringName] = []
@export var scales := PackedFloat32Array()
@export var primary: Array[Color] = []
@export var secondary: Array[Color] = []
@export var tertiary: Array[Color] = []


func category() -> StringName:
	return &"pack_fx"


func count() -> int:
	return ids.size()


## The row of `effect_id`, or -1.
func row(effect_id: StringName) -> int:
	return ids.find(effect_id)


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	var n := ids.size()
	if (
		scenes.size() != n
		or families.size() != n
		or scales.size() != n
		or primary.size() != n
		or secondary.size() != n
		or tertiary.size() != n
	):
		issues.append(
			ValidationIssue.new(
				&"size_mismatch", resource_path, "every list needs one entry per id"
			)
		)
		return issues
	var seen := {}
	for k in n:
		if seen.has(ids[k]):
			issues.append(
				ValidationIssue.new(&"duplicate_id", resource_path, "id %s twice" % ids[k])
			)
		seen[ids[k]] = true
		if not ResourceLoader.exists(scenes[k]):
			issues.append(
				ValidationIssue.new(
					&"missing_scene", resource_path, "%s: no scene at %s" % [ids[k], scenes[k]]
				)
			)
		if not FAMILIES.has(families[k]):
			issues.append(
				ValidationIssue.new(
					&"bad_family", resource_path, "%s: unknown family %s" % [ids[k], families[k]]
				)
			)
		check_positive(issues, "scales[%d]" % k, scales[k])
	return issues

class_name BiomeDefinition
extends ContentDef
## A biome: palette, props and mild flavour; never a difficulty step (CONTENT_SCHEMA §6, PD-04).

const PALETTE_KEYS: Array[String] = [
	"ground", "ground_alt", "cover", "accent", "edge", "ambient", "outline"
]
const MIN_OUTLINE_CONTRAST := 3.0

@export var name_key: StringName
## Exactly PALETTE_KEYS (docs/art/ART_DIRECTION.md §2): token -> Color.
@export var palette: Dictionary = {}
@export var hazard_flavour: StringName
@export var template_tags: PackedStringArray
## Its lighting mood (v0.5.9 Step 1): what StageView lights the floor with.
@export var mood: BiomeMood


func category() -> StringName:
	return &"biomes"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "name_key is empty"))
	for key in PALETTE_KEYS:
		if not palette.has(key):
			issues.append(
				ValidationIssue.new(&"palette_missing", resource_path, "palette lacks '%s'" % key)
			)
		elif typeof(palette[key]) != TYPE_COLOR:
			issues.append(
				ValidationIssue.new(
					&"palette_type", resource_path, "palette '%s' is not a Color" % key
				)
			)
	for key in palette.keys():
		if not String(key) in PALETTE_KEYS:
			issues.append(
				ValidationIssue.new(
					&"palette_unknown", resource_path, "unknown palette key '%s'" % key
				)
			)
	if mood == null:
		issues.append(ValidationIssue.new(&"mood_missing", resource_path, "no lighting mood"))
	else:
		for p in mood.problems():
			issues.append(ValidationIssue.new(&"mood_invalid", resource_path, "mood " + p))
	if palette.has("ground") and palette.has("outline"):
		var ratio := contrast(palette["ground"], palette["outline"])
		if ratio < MIN_OUTLINE_CONTRAST:
			issues.append(
				ValidationIssue.new(
					&"outline_contrast",
					resource_path,
					"outline vs ground is %.2f:1 (< 3:1)" % ratio
				)
			)
	return issues


## WCAG contrast ratio between two colours.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)

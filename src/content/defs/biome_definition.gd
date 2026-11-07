class_name BiomeDefinition
extends ContentDef
## A biome: palette, props and mild flavour; never a difficulty step (CONTENT_SCHEMA §6, PD-04).

const PALETTE_KEYS: Array[String] = [
	"ground", "ground_alt", "cover", "accent", "edge", "ambient", "outline"
]
const MIN_OUTLINE_CONTRAST := 3.0
## v0.11.0 O13a (Q23): every biome's shared core of four.
const SHARED_CORE: Array[StringName] = [&"charger", &"needle", &"swarmer", &"warden"]
## v0.11.0 O13a: the ten signature enemies of ENEMIES.md R1-R10 that O13b-d build; a signature id may name one before
## its definition exists (any other unknown id fails, so a typo can't hide).
const PENDING_SIGNATURES: Array[StringName] = [
	&"wire_weaver",
	&"scrap_hound",
	&"rock_lurker",
	&"stone_thrower",
	&"kiln_beetle",
	&"cinder_priest",
	&"frost_spitter",
	&"glacier_turtle",
	&"star_warper",
	&"gravity_node",
]
const SIGNATURES_PER_BIOME := 2

@export var name_key: StringName
## v0.7.5 CX: the Codex's line about this biome (a locale key; empty shows no line).
@export var desc_key: StringName
## Exactly PALETTE_KEYS (docs/art/ART_DIRECTION.md §2): token -> Color.
@export var palette: Dictionary = {}
@export var hazard_flavour: StringName
@export var template_tags: PackedStringArray
## Its lighting mood (v0.5.9 Step 1): what StageView lights the floor with.
@export var mood: BiomeMood
## v0.7.5 NB1: ground that plays differently (Frozen Shore's ice); null for none. Mild flavour (PD-04).
@export var surface: BiomeSurface
## v0.7.5 NB1: the biome's own dressing, edge and enemy cast; null keeps the hand-written look (the first three).
@export var look: BiomeLook
## v0.11.0 O9 (PLAN H1; owner Q14: "one horde critter per biome, same rules, its own body"): the enemy id of the
## biome's horde critter (a BehaviourSchemas.CRITTER behaviour), the one its floors' surges send (Surges); &"": none.
@export var critter_id: StringName
## v0.11.0 O13a (PLAN M3; owner Q23): the biome's roster. `core_ids`: the shared core, exactly SHARED_CORE on every
## biome. `signature_ids`: its two signature enemies (ENEMIES.md R1-R10); an id whose kind is not shipped yet is
## listed now (PENDING_SIGNATURES only) and skipped until its definition exists (VariantCompiler.roster_kinds), so
## O13b-d add a kind by adding its file. `variant_id`: its variant of an existing enemy (V1-V5, a
## BehaviourSchemas.VARIANT_OF behaviour). Floor depth still opens the later kinds on every biome (data/curves); a
## signature or a variant spawns only on its own biome's floors (SpawnTable.biome_only, SpawnDirector.unlocked).
@export var core_ids: Array[StringName] = []
@export var signature_ids: Array[StringName] = []
@export var variant_id: StringName


func category() -> StringName:
	return &"biomes"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "name_key is empty"))
	if category() == &"biomes":  # (the final arena is a biome of its own category, with no roster)
		_check_roster(issues)
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
	if surface != null:
		for p in surface.problems():
			issues.append(ValidationIssue.new(&"surface_invalid", resource_path, "surface " + p))
	if look != null:
		for p in look.problems():
			issues.append(ValidationIssue.new(&"look_invalid", resource_path, "look " + p))
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


## v0.11.0 O9: every biome's critter_id names a shipped enemy whose behaviour is a horde critter's.
static func cross_check(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var critters := {}
	for d in defs:
		if (
			d is EnemyDefinition
			and BehaviourSchemas.SCHEMAS.get(d.behaviour_id) == BehaviourSchemas.CRITTER
		):
			critters[d.id] = true
	for d in defs:
		if d is BiomeDefinition and d.critter_id != &"" and not critters.has(d.critter_id):
			issues.append(
				ValidationIssue.new(
					&"critter_unknown",
					d.resource_path,
					"critter_id %s is no horde critter" % d.critter_id
				)
			)
	issues.append_array(_cross_check_rosters(defs))
	return issues


## v0.11.0 O13a (Q23): the roster's own shape: the shared core, two distinct signatures, a variant named.
func _check_roster(issues: Array[ValidationIssue]) -> void:
	var core_ok := core_ids.size() == SHARED_CORE.size()
	for id in SHARED_CORE:
		core_ok = core_ok and core_ids.has(id)
	if not core_ok:
		issues.append(
			ValidationIssue.new(&"roster", resource_path, "core_ids must be %s" % [SHARED_CORE])
		)
	if signature_ids.size() != SIGNATURES_PER_BIOME or signature_ids[0] == signature_ids[-1]:
		issues.append(
			ValidationIssue.new(&"roster", resource_path, "signature_ids must be two distinct ids")
		)
	if variant_id == &"":
		issues.append(ValidationIssue.new(&"roster", resource_path, "variant_id is empty"))


## v0.11.0 O13a: every roster id names a shipped enemy (a signature may be a PENDING_SIGNATURES id not built yet), the
## variant is a variant behaviour's, and no signature or variant belongs to two biomes.
static func _cross_check_rosters(defs: Array[ContentDef]) -> Array[ValidationIssue]:
	var issues: Array[ValidationIssue] = []
	var enemies := {}
	for d in defs:
		if d is EnemyDefinition:
			enemies[d.id] = d
	var owner := {}
	for d in defs:
		if not d is BiomeDefinition or d.category() != &"biomes":
			continue
		var b := d as BiomeDefinition
		var bad := PackedStringArray()
		for id: StringName in b.core_ids:
			if not enemies.has(id):
				bad.append("core %s is no enemy" % id)
		for id: StringName in b.signature_ids:
			if not enemies.has(id) and not PENDING_SIGNATURES.has(id):
				bad.append("signature %s is no enemy" % id)
		var v: EnemyDefinition = enemies.get(b.variant_id)
		if (
			b.variant_id != &""
			and (v == null or not BehaviourSchemas.VARIANT_OF.has(v.behaviour_id))
		):
			bad.append("variant %s is no variant enemy" % b.variant_id)
		var own: Array[StringName] = b.signature_ids.duplicate()
		own.append(b.variant_id)
		for id: StringName in own:
			if id == &"":
				continue
			if owner.has(id) and owner[id] != b.id:
				bad.append("%s is also %s's" % [id, owner[id]])
			owner[id] = b.id
		for m in bad:
			issues.append(ValidationIssue.new(&"roster", b.resource_path, m))
	return issues

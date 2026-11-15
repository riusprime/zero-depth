class_name ForgeHeroViews
extends Node3D
## The hero's own scalding in the Foundry's last phase, on its body, drawn from WorldReader.boss_forge "scald" (EI-07:
## the gauge, the burn and the drain are the sim's, BossForge). No word: an ember glow (fo_ember) round the hero grows
## as the gauge fills, flames (status_burn_a, the burning status's own) wrap it while it burns, and a white steam puff
## (bx_smoke_thin) rises when a slab starts to cool it. Hidden before the scald's phase and after the fight.

const EMBER_ID := &"fo_ember"
const FLAME_ID := &"status_burn_a"
const STEAM_ID := &"bx_smoke_thin"
## The glow shows from this share of the gauge and grows to its full size at the top.
const EMBER_FROM := 0.15
const EMBER_MIN := 0.25
const EMBER_MAX := 0.75
const FLAME_SCALE := 0.7
const STEAM_SCALE := 0.6

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
var _scald := {}
var _hero := Vector3.ZERO
var _was_draining := false
var _puffs := 0


func _init() -> void:
	name = "ForgeHeroViews"


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_scald = reader.boss_forge().get("scald", {})
	_hero = SimPlane.to_3d(reader.actor_pos(0))
	var draining := bool(_scald.get("draining", false))
	if draining and not _was_draining:
		_puffs += 1
		if pack_fx != null and pack_fx.has_id(STEAM_ID) and pack_fx.has_room(&"cloud"):
			pack_fx.spawn(
				STEAM_ID, _hero + Vector3(0, 0.6, 0), STEAM_SCALE, ForgeLooks.STEAM_COLORS
			)
	_was_draining = draining


## 0..1: how full the gauge is.
static func share_of(scald: Dictionary) -> float:
	if scald.is_empty():
		return 0.0
	return clampf(float(scald["gauge"]) / float(maxi(1, int(scald["max"]))), 0.0, 1.0)


func _process(_delta: float) -> void:
	advance()


## Frame-time drawing (the tests and the shot scripts call it too).
func advance() -> void:
	if _scald.is_empty() and hold.count() == 0:
		return
	hold.begin()
	var share := share_of(_scald)
	if share >= EMBER_FROM:
		var size := lerpf(EMBER_MIN, EMBER_MAX, (share - EMBER_FROM) / (1.0 - EMBER_FROM))
		hold.put(&"ember", EMBER_ID, &"status", SiegeLooks.at(_hero + Vector3(0, 0.05, 0), size))
	if bool(_scald.get("burning", false)):
		hold.put(
			&"flame", FLAME_ID, &"status", SiegeLooks.at(_hero + Vector3(0, 0.1, 0), FLAME_SCALE)
		)
	hold.end()


# --- tests and the shot scripts ----------------------------------------------------------------------------------


## The body's read now: &"" none, &"ember", &"burning" (flames over the ember).
func body_read() -> StringName:
	if hold.has(&"flame"):
		return &"burning"
	return &"ember" if hold.has(&"ember") else &""


## The ember glow's size now (0 none).
func ember_size() -> float:
	var n := hold.node(&"ember")
	return n.scale.x if n != null else 0.0


## Steam puffs this view has started (each time a drain began).
func puffs() -> int:
	return _puffs

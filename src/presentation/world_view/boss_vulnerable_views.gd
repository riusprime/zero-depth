class_name BossVulnerableViews
extends Node3D
## A boss that takes more damage now shows it on itself, without a word (the owner: the player discovers it): the
## pack's hot gold pulse (se_strip) round its feet, the size of its body, and its stun stars (o13d_star_ring)
## turning over it. Drawn while WorldReader says a broken quake pillar stuns it (boss_stunned: the Gatekeeper) or the
## Siege Engine's armour is stripped by its cart (boss_siege "stripped") or a bomb blew the Foundry's plate off
## (boss_forge plate "exposed_left"). The violet Warden's broken ward has its own
## stars (WardenWardViews). The boss bar shimmers gold meanwhile (BossBarTones). Reads only (EI-07).

const PULSE_ID := &"se_strip"
const STARS_ID := &"o13d_star_ring"
## The pulse's scale per metre of the body's radius, and the stars' height over the body (m per metre of radius) and
## scale.
const PULSE_PER_M := 0.55
const STARS_UP := 1.25
const STARS_SCALE := 0.5

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## [position (3D), radius, id] of each boss that takes more damage now.
var _bosses: Array = []


func _init() -> void:
	name = "BossVulnerableViews"


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_bosses = []
	if not reader.any_boss():
		return
	var siege := reader.boss_siege()
	var stripped := int(siege.get("boss", -1)) if int(siege.get("stripped", 0)) > 0 else -1
	var exposed := exposed_foundry(reader)
	for i in reader.actor_count():
		if not WorldReader.is_boss_kind(reader.actor_kind(i)) or reader.actor_hp(i) <= 0:
			continue
		if i == stripped or i == exposed or reader.boss_stunned(i):
			_bosses.append(
				[SimPlane.to_3d(reader.actor_pos(i)), reader.actor_radius(i), reader.actor_id(i)]
			)


## The Foundry's index while its plate is blown off (it takes more damage), else -1.
static func exposed_foundry(reader: WorldReader) -> int:
	var forge := reader.boss_forge()
	if int(forge.get("plate", {}).get("exposed_left", 0)) <= 0:
		return -1
	return int(forge["boss"])


func _process(_delta: float) -> void:
	advance()


## Frame-time drawing (the tests and the shot scripts call it too).
func advance() -> void:
	if _bosses.is_empty() and hold.count() == 0:
		return
	hold.begin()
	for b: Array in _bosses:
		var at: Vector3 = b[0]
		var r: float = b[1]
		hold.put(
			[&"pulse", b[2]],
			PULSE_ID,
			&"status",
			SiegeLooks.at(at + Vector3(0, 0.1, 0), r * PULSE_PER_M)
		)
		hold.put(
			[&"stars", b[2]],
			STARS_ID,
			&"area",
			SiegeLooks.at(at + Vector3(0, r * STARS_UP + 1.0, 0), STARS_SCALE)
		)
	hold.end()


## The bosses drawn vulnerable now (tests).
func shown() -> int:
	return _bosses.size()

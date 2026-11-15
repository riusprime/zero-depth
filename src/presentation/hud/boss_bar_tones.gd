class_name BossBarTones
extends RefCounted
## The boss bar's wordless state reads (the owner: the player learns a fight's mechanics from arrows, glows, colour
## and motion, never from words). Each state the sim reports is a tone of the bar's fill: its colour, and whether it
## shimmers (a quick pulse toward white) or breathes (a slow one). Reads only (EI-07).
## - phase_shift: the phase gate; a slow pale breathing (the bar then empties and refills to the new phase).
## - vulnerable: the boss takes more damage now (a broken quake pillar's stun, the violet Warden's broken ward, the
##   Siege Engine's armour stripped by its cart): a hot gold shimmer.
## - invulnerable: cold steel blue, still (a shield, the final body shattering); the shields still to pass are pips
##   under the bar (BossBar).
## - dark / lit: the Lantern Shade in the dark (the fill darkened) or in a lit lantern's pool (lantern gold).
## - fallen_warn / fallen_open: The Fallen's mimic window coming (a slow violet breathing) and open (a violet
##   shimmer).

const NONE := &""
const PHASE_SHIFT := &"phase_shift"
const VULNERABLE := &"vulnerable"
const INVULNERABLE := &"invulnerable"
const DARK := &"dark"
const LIT := &"lit"
const FALLEN_WARN := &"fallen_warn"
const FALLEN_OPEN := &"fallen_open"

const STEEL := Color("#8FB8E8")
const GOLD := Color("#FFC15A")
const HOT := Color("#FFD27A")
const VIOLET := Color("#C59BFF")
const PALE := Color("#E8E4F0")
const DIM := 0.55
## Pulses per second: a shimmer and a breath.
const SHIMMER_HZ := 3.0
const BREATH_HZ := 0.8

## tone -> [colour (null: the HP colour), pulse Hz (0: still), how far toward white it pulses, darken].
const LOOKS := {
	PHASE_SHIFT: [PALE, BREATH_HZ, 0.35, 0.0],
	VULNERABLE: [HOT, SHIMMER_HZ, 0.55, 0.0],
	INVULNERABLE: [STEEL, 0.0, 0.0, 0.0],
	DARK: [null, 0.0, 0.0, DIM],
	LIT: [GOLD, 0.0, 0.0, 0.0],
	FALLEN_WARN: [VIOLET, BREATH_HZ, 0.3, 0.0],
	FALLEN_OPEN: [VIOLET, SHIMMER_HZ, 0.5, 0.0],
}


## The tone of boss i's bar now (the first that holds, in this order).
static func tone_of(reader: WorldReader, i: int, final: bool) -> StringName:
	if reader.boss_in_gate(i):
		return PHASE_SHIFT
	if reader.boss_invulnerable(i):
		return INVULNERABLE
	if vulnerable(reader, i, final):
		return VULNERABLE
	if final:
		match int(reader.final_pace().get("window", WorldReader.FALLEN_OFF)):
			WorldReader.FALLEN_WARN:
				return FALLEN_WARN
			WorldReader.FALLEN_ON:
				return FALLEN_OPEN
		return NONE
	var light := reader.boss_light_permille(i)
	if light < 1000:
		return DARK
	if light > 1000:
		return LIT
	return NONE


## Boss i takes more damage now: stunned by a broken quake pillar, the violet Warden stunned by her broken ward, the
## Siege Engine's armour stripped (the final fight has none of these).
static func vulnerable(reader: WorldReader, i: int, final: bool) -> bool:
	if final:
		return false
	if reader.boss_stunned(i):
		return true
	var siege := reader.boss_siege()
	if int(siege.get("boss", -1)) == i and int(siege.get("stripped", 0)) > 0:
		return true
	var twin := reader.boss_twin(i)
	if twin.is_empty():
		return false
	return bool(reader.boss_twin(int(twin.get("partner", -1))).get("exposed", false))


## The fill's colour in `tone` at clock `t` (s) over the HP colour `base`; reduced motion holds the pulse at its middle.
static func color_of(tone: StringName, base: Color, t: float, still: bool) -> Color:
	if not LOOKS.has(tone):
		return base
	var look: Array = LOOKS[tone]
	var c: Color = base if look[0] == null else look[0]
	if float(look[3]) > 0.0:
		c = c.darkened(float(look[3]))
	var hz := float(look[1])
	if hz <= 0.0:
		return c
	var wave := 0.5 if still else 0.5 + 0.5 * sin(t * TAU * hz)
	return c.lerp(Color.WHITE, float(look[2]) * wave)

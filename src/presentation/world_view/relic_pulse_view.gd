class_name RelicPulseView
extends Node
## OWNER_QUESTIONS §J N1: the City's Heart's saved blow, on any floor (a held relic travels with the
## run): when WorldReader.relic_pulse_tick moves on, the shock ring bursts from where the hero was saved, sized to its
## radius, with a crimson flash at its centre (PD-13: the pack's `o14b_heart_ring`, pulse_area_vfx_02, and
## `o14b_heart_flash`, magic_orb_flash_vfx_01, both tinted crimson and violet). Reads only.

const RING_ID := &"o14b_heart_ring"
const FLASH_ID := &"o14b_heart_flash"
## The pack's area scenes' scale per metre of radius (their quads are 4 m across at 1; StormPack.AREA_PER_M).
const AREA_PER_M := 0.5

var pack_fx: PackFx
## The rings played (tests read it) and the last pulse tick seen.
var played := 0
var _seen := -1


func setup(reader: WorldReader) -> void:
	name = "RelicPulse"
	_seen = reader.relic_pulse_tick()


func sync(reader: WorldReader) -> void:
	var t := reader.relic_pulse_tick()
	if t == _seen:
		return
	_seen = t
	if t < 0:
		return
	played += 1
	if pack_fx == null:
		return
	var at := SimPlane.to_3d(reader.relic_pulse_pos(), 0.05)
	pack_fx.spawn(RING_ID, at, reader.relic_ring_radius() * AREA_PER_M)
	pack_fx.spawn(FLASH_ID, at + Vector3(0, 0.9, 0))

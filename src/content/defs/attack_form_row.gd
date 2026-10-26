class_name AttackFormRow
extends Resource
## v0.9.0 AS (PLAN C60–C65; docs/roadmap/v0.9.0/ATTACK_FORMS.md): one Gun attack form's row of the compatibility table
## (AttackSlotsDefinition.forms): the form, the card that sets it (empty: the default form, Orbs, the Gun's own shot),
## and the Pattern, Secondary and Element cards it takes. A card in `allowed` is on, in `ruled` on with a rule of the
## form's own (the form's step builds the rule; until then it reads as on); every other card is off (C62: "No by
## default"), so it is never offered, never equipped and never compiled with this form.

## v0.9.5 FC3: the numbers the Void row carries (VoidMods.DEFAULTS has the same keys; a test holds them equal).
const VOID_KEYS: Array[String] = [
	"ring_mm",
	"ring_ms",
	"ring_share",
	"ring_ticks",
	"back_share",
	"ricochet_bounces",
	"home_range_mm",
	"home_group_mm",
	"home_every_ms",
	"home_turn_dps",
	"echo_share",
	"echo_life",
	"echo_aura",
	"echo_pull",
	"big_aura_mm",
	"big_pull_mm",
	"big_speed",
	"big_damage",
	"rapid_period_ms",
	"rapid_life",
	"rapid_aura_mm",
	"rapid_damage",
	"split_dist_mm",
	"split_life_ms",
	"split_share",
	"split_aura_mm",
	"split_pull_mm",
	"mine_hold_ms",
	"orbit_mm",
	"orbit_ms",
	"live_max",
]

## v0.9.5 FC2: the numbers the Bomb row carries (BombMods.DEFAULTS has the same keys; a test holds them equal).
const BOMB_KEYS: Array[String] = [
	"halo_dist_mm",
	"halo_delay_ms",
	"halo_share",
	"ring_mm",
	"ring_ms",
	"ring_share",
	"back_fuse_ms",
	"back_share",
	"ricochet_mm",
	"home_range_mm",
	"echo_delay_ms",
	"echo_share",
	"big_blast_mm",
	"big_damage",
	"big_speed",
	"rapid_period_ms",
	"rapid_blast_mm",
	"rapid_damage",
	"split_dist_mm",
	"split_fuse_ms",
	"split_share",
	"split_blast_mm",
	"mine_trigger_mm",
	"mine_max",
	"mine_life_ms",
]

## v0.9.5 FC1: the numbers the Laser row carries (LaserMods.DEFAULTS has the same keys; a test holds them equal).
const LASER_KEYS: Array[String] = [
	"halo_len_mm",
	"halo_turn_deg",
	"halo_share",
	"ring_mm",
	"ring_share",
	"back_mm",
	"back_share",
	"home_dps",
	"home_repick_ms",
	"home_step_mm",
	"home_bend_deg",
	"home_chain",
	"echo_delay_ms",
	"echo_share",
	"big_width",
	"big_damage",
	"big_turn",
	"follow_dps",
	"rapid_period_ms",
	"rapid_ramp_ms",
	"rapid_width",
	"rapid_damage_permille",
	"split_mm",
	"split_deg",
	"split_share",
	"mine_every_ms",
	"mine_mm",
	"mine_share",
	"mine_max",
	"mine_life_ms",
	"mine_trigger_mm",
	"spiral_deg",
	"spiral_hz",
]

@export var id: StringName = &""
@export var card: StringName = &""
@export var allowed: Array[StringName] = []
@export var ruled: Array[StringName] = []
## v0.9.5 FC1: the form's own numbers for what its cards do (the Laser's: LaserMods.DEFAULTS names them and their units
## in their keys); every value a whole number above 0. Empty for the forms without any.
@export var params: Dictionary = {}

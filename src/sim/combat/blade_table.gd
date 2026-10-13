class_name BladeTable
extends RefCounted
## v0.6.5 WN4: the Blade pool's runner numbers in sim units (BladeFormsDefinition compiled by BladeCompiler). Loadout:
## compiled at setup, never written in play (World.blade_table; null = a lab world: these defaults, which mirror
## data/wand/blade_forms.tres).

## Orbit Blades: blades at once, their turn per tick (1/4096 turns), the ticks a blade rests after a hit.
var orbit_max := 6
var orbit_turn := 68
var orbit_gap := 12
## Heavy's push lasts this many ticks; Lunge Step's step at least this many.
var knock_ticks := 8
var lunge_ticks := 6
## A swing's speed never goes under this per mille of its own (stacked slow cards).
var rate_min := 250

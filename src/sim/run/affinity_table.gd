class_name AffinityTable
extends RefCounted
## v0.9.0 RB (AFFINITIES.md A1-A5): the run's rune affinity, compiled from its AffinityDefinition
## (RunContentCompiler.compile_affinity). Content: read in play, never written (the snapshot keeps it as loadout).
## Integers and metres only; the colour and glyph stay in content for the presentation.

var id := &""
## A1 Ember: the burn's duration per mille.
var burn_duration_permille := 1000
## A2 Storm: the dash's shock reach (m from its path) and stacks.
var dash_shock_radius_m := 0.0
var dash_shock_stacks := 0
## A3 Venom: how far a dying enemy's poison jumps (m; 0 off).
var poison_jump_m := 0.0
## A4 Astral (presentation reads them through WorldReader): the secret sense's reach (m) and the minimap's marks.
var secret_sense_m := 0.0
var map_secrets := false
## A5 Guardian: the wards a floor starts with, and the run shards picked up per mille.
var ward_charges := 0
var shard_permille := 1000
## Each compiled item's offer weight per mille (index = item index; 1000 = unweighted).
var card_permille := PackedInt32Array()

# Ported from riusprime/deathventory@1d697803:src/domain/core/rng_step.gd. Changes: header only.
class_name RngStep extends RefCounted

var value: int
var next_state: int

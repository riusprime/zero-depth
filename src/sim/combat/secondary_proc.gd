class_name SecondaryProc
extends RefCounted
## v0.8.0 MR (owner O91: "Extra projectiles must not each duplicate full damage and full-strength effects"; WAND.md
## rule 10; SIM_CONTRACTS §8e): the proc of a secondary attack. The secondary attacks are Twin's second lane, Spread's
## and Halo's bolts past the centre one (a spec with a share_permille: Attacks._bolts), an Echo's repeat and a Double
## Slash echo (ModifierState.FLAG_SECONDARY, PlayerKit.swing_arc). Each runs at WandTable.secondary_proc_permille
## (500, data/wand/wand.tres):
## - the status stacks its hits feed (Engines.on_hit, Attacks._landed's burn, Attacks._feed) × that per mille;
## - its hooks' children launch at that share of the proc (AttackContext.proc_pct: their statuses), and a trigger's
##   cast from its hit deals that share of its damage (Attacks.run_hook). The children are not secondary themselves,
##   so nothing halves twice.
## Stacks are whole numbers: a scaled feed rounds down and owes the remainder (per mille of a stack) to the next one,
## ModifierState.sec_carry, so a run of 1-stack hits at 500 feeds every other hit: exact on average, deterministic,
## no randomness (EI-05).

## The wand's numbers in a world without World.wand_table (a lab): WandTable's defaults (they mirror wand.tres).
static var _defaults := WandTable.new()


## The secondary proc, per mille (WandTable.secondary_proc_permille).
static func permille(w: World) -> int:
	var t := w.wand_table if w.wand_table != null else _defaults
	return clampi(t.secondary_proc_permille, 0, 1000)


## The proc of player projectile `pi`'s hit, per mille: a secondary bolt's (or a repeat's), else 1000.
static func of_projectile(w: World, pi: int) -> int:
	return permille(w) if w.projectiles.second_of(pi) != 0 else 1000


## The proc a launch with `ctx` hits at, per mille.
static func of_ctx(w: World, ctx: AttackContext) -> int:
	return permille(w) if ctx.secondary else 1000


## `n` stacks fed at `pm` per mille: rounded down, the remainder carried to the next scaled feed (class doc).
static func stacks(w: World, n: int, pm: int) -> int:
	if pm >= 1000 or n <= 0:
		return n
	var total := n * pm + w.mx.sec_carry
	w.mx.sec_carry = total % 1000
	return total / 1000

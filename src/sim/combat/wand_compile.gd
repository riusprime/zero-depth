class_name WandCompile
extends RefCounted
## v0.6.5 WN1 (docs/design/WAND.md rules 2–3, owner W3: "the different ways that all items interact in the order
## that you put them in the wand"; SIM_CONTRACTS §8e): the wand compiler. It replaces v0.6.0's fixed stage sort
## (FORM → PATTERN → BEHAVIOUR → PAYLOAD → HOOK → SCALE across every modifier) with the slot order: each modifier
## rewrites the spell built so far, left to right. Compile-time only (Modifiers.compile, on a build change and on
## load); no randomness (EI-05), no trig.
##
## The readings (where an op's meaning depended on the stage order):
## - Inside one card its ops still run in stage order (a card that changes the form and then scales its range keeps
##   its meaning); across cards, the slot order decides.
## - A numeric op changes the field as the spell has it now: Big then Split is one big shot whose splits are normal;
##   Split then Big makes the splits big too.
## - A hook (a card's own child attack, e.g. Split Shot's splits) is built where its card sits: its child is
##   compiled by its own card (never its own hook again: lineage) and the cards to its right, never the ones to its
##   left. So a later card reaches every child built so far, an earlier one only the attack itself.
## - A second form op layers as before (an ON_END copy in the new form), and the copy carries the spell's shape and
##   payload so far but not its hooks (they stay on the first form); it is then compiled by its card's other ops and
##   the cards to its right. A third form op layers on the attack and on the first layer (the depth guard bounds it).
## - A trigger card (ModifierOp.Op.TRIGGER, WAND.md T1–T4) ends the spell: the cards to its right do not rewrite it;
##   they build a child spell, a small copy of the basic attack (WandTable: the Gun's bolt or the Blade's first slash,
##   its size and range scaled, child_damage_permille of the hit that set it off), cast on the trigger: ON_HIT where a
##   hit lands, ON_KILL where an enemy dies, ON_END where the spell ends, ON_FINISHER (the Blade) on the hits of the
##   combo's last step, ON_CRIT (the Gun's T4) on a critical hit. Every spec the trigger reaches gets the cut, the
##   splits of an earlier Split card too; a second trigger nests once more (depth ≤ 2: the attack at 0, its child at
##   1, the child's child at 2; the run-time guard keeps the proc 100 → 50 → 25, the ancestry chain and the 256
##   launches a tick). A spec the trigger's target doesn't reach (a moment: the dash, walking, a blink, the body)
##   reads past it, so a dash card right of a trigger still rewrites the dash.
## - v0.6.5 WN5b: a legendary trigger (ModifierOp.casts > 1, "On Hit ×2") casts its child that many times per trigger,
##   each delay_ticks after the one before (the later ones through the launch queue, ModifierRuntime).
## - v0.8.0 BL (docs/roadmap/v0.8.0/BLADE_AUDIT.md B3, owner 2026-10-14): on a Blade run a slash's hit triggers (On Hit,
##   On Kill, On Finisher) cast WandTable.blade_hit_casts times (2), blade_cast_gap_ticks apart (a legendary trigger's
##   own delay when it has one): a slash hits each enemy once, a Gun volley many times, so trigger builds work on
##   both weapons. The Gun's triggers, a slash's On End and every non-slash spec cast as before.
## - v0.8.0 PF2 (owner O9): a spec a cast-free hook made (WandTable.cast_free_lines: Blade Storm's blades, and anything
##   built from them) takes no trigger cut: the trigger still ends it, but its hits cast nothing.
## - v0.8.0 BL (B6): a spec a once-per-line hook made (WandTable.once_per_line: Split's splits, Explosive's blast, and
##   anything built from them: its lineage holds one) takes none of those hooks again: the first shot splits and
##   explodes, its splits neither split nor explode (the lineage guard alone stopped only the same card).
## - v0.8.0 AO (owner O37: "make the order of the attacks be more important"; evidence/ATTACK_ORDER.md): a SHAPE card
##   (ModifierTable.OrderKind; Ring) takes in what is left of it when it sets the form (take_in): a count becomes the
##   ring's pulses, a motion throws the whole ring group; COUNT and MOTION cards to its right then multiply and move
##   the rings. v0.8.0 N3 (owner O47): the ring is the shot, flying the shot's flight (ring_flight); a motion left of
##   it makes the group spin as it flies (WandRings). Stat-like cards stay order-free. A bolt child built on such a
##   ring (a card to the Ring's right: Split's shards, a trigger's cast) keeps at most WandRings.RING_CHILD_ALIVE_MAX
##   alive (WandRings.cap_child): every ring and pulse of a launch hits, and each hit would throw its own.

const MAX_DEPTH := 2

## The cards in slot order.
var mods: Array[ModifierTable] = []
## A Gun run: T4 cuts on a crit (its trigger_gun); otherwise on the Blade's finisher.
var gun := false
## The Blade's last combo step (ON_FINISHER's spec), &"" without a combo.
var finisher_id := &""
## The small copy of the basic attack a trigger casts (null: a lab compile without a world; the cut then casts
## nothing), and its damage share.
var child_base: AttackSpec
var child_damage_permille := 500
## v0.8.0 BL (B3): a Blade run (its slashes' hit triggers cast hit_casts times, cast_gap_ticks apart).
var blade := false
var hit_casts := 2
var cast_gap_ticks := 6
## v0.8.0 BL (B6): the hook cards a line takes once (WandTable.once_per_line).
var once_per_line: Array[StringName] = [&"split_shot", &"shared_explosive"]
## v0.8.0 PF2: the hook cards whose children cast no trigger (WandTable.cast_free_lines).
var cast_free_lines: Array[StringName] = [&"blade_storm"]


## The compile for world `w`'s build `mods`: the run's weapon picks the child spell and T4's trigger.
static func for_world(w: World, p_mods: Array[ModifierTable]) -> WandCompile:
	var c := WandCompile.new()
	c.mods = p_mods
	c.gun = PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w)
	var n := w.player.combo.size()
	if n > 0:
		c.finisher_id = Modifiers.step_id(n - 1)
	var t := w.wand_table if w.wand_table != null else WandTable.new()
	c.child_damage_permille = t.child_damage_permille
	c.child_base = _small_copy(w, t, c.gun or n == 0)
	c.blade = PlayerBuild.has_blade(w) and n > 0  # v0.8.0 BL
	c.hit_casts = t.blade_hit_casts
	c.cast_gap_ticks = t.blade_cast_gap_ticks
	c.once_per_line = t.once_per_line
	c.cast_free_lines = t.cast_free_lines  # v0.8.0 PF2
	return c


## The basic attack, small (WAND.md rule 3): the Gun's bolt with its radius × size and its flight × range, or the
## Blade's first slash with its reach × size. Tagged hook (a hook's child) on top of the weapon's own tags, so the
## weapon's cards reach it.
static func _small_copy(w: World, t: WandTable, bolt: bool) -> AttackSpec:
	var s: AttackSpec
	if bolt:
		s = Modifiers.base_bolt(w)
		s.radius_m = s.radius_m * t.child_size_permille / 1000.0
		s.life_ticks = maxi(1, s.life_ticks * t.child_range_permille / 1000)
	else:
		s = Modifiers.base_step(w, 0)
		s.reach_m = s.reach_m * t.child_size_permille / 1000.0
		s.hitstop_ticks = 0
	s.period_ticks = 0
	s.tags.append(Modifiers.TAG_HOOK)
	return s


## `base` rewritten by every card (a fresh spec; `base` is not written).
func spec(base: AttackSpec) -> AttackSpec:
	return run(base.copy(), 0)


## `s` rewritten by the cards from slot `from` on, in slot order (in place; returned). `skip_form_at`: the slot whose
## form op made this spec a layer (its other ops still run).
func run(s: AttackSpec, from: int, skip_form_at: int = -1) -> AttackSpec:
	var moment := s.has_tag(Modifiers.TAG_MOMENT)
	for i in range(from, mods.size()):
		var m := mods[i]
		if not s.matches(m.target) or (moment and m.target.is_empty()):
			continue
		if m.is_trigger():
			_cut(s, m, i)
			break
		var applied := false
		for stage in ModifierTable.STAGE_COUNT:  # a card's own ops in stage order
			for op in m.ops:
				if op.stage != stage:
					continue
				if i == skip_form_at and op.op == ModifierOp.Op.SET_FORM:
					continue
				apply(s, m, op, i)
				applied = true
		if applied and not s.modifier_ids.has(String(m.id)):
			s.modifier_ids.append(String(m.id))
	SpecForms.settle(s)
	return s


## Op `op` of card `m` (at slot `i`) on `s`.
func apply(s: AttackSpec, m: ModifierTable, op: ModifierOp, i: int) -> void:
	match op.op:
		ModifierOp.Op.SET_FORM:
			if s.form_layers == 0:
				if m.order_kind == ModifierTable.OrderKind.SHAPE:
					take_in(s, op.form)  # v0.8.0 AO: the shape takes in what is left of it
				SpecForms.change_form(s, op.form)  # v0.6.0 MX4: keeps its range
				s.form_layers = 1
			elif s.depth < MAX_DEPTH:
				s.hooks.append(_layer(s, m, op, i))
				s.form_layers += 1
		ModifierOp.Op.STATUS:
			s.set_status(op.status, op.stacks, op.every)
		ModifierOp.Op.ELEMENT:
			if not s.elements.has(String(op.element)):
				s.elements.append(String(op.element))
		ModifierOp.Op.HOOK:
			if s.depth < MAX_DEPTH and not s.lineage.has(String(m.id)):  # v0.6.0 MX4: lineage
				if not once_more(s, m.id):  # v0.8.0 BL (B6)
					s.hooks.append(_hook(s, m, op, i))
		ModifierOp.Op.TRIGGER:
			pass  # a trigger is a card of its own (run cuts there)
		_:
			Modifiers.numeric(s, op)


## v0.8.0 AO (owner O37; evidence/ATTACK_ORDER.md): a SHAPE card (Ring) turning `s` into `form` takes in what is left
## of it: the count built so far becomes the ring's pulses (Spread · Ring: one bigger ring shot that pulses three
## times as it flies) and its fan goes; a Swirl left of it makes the group fly as one, spinning (Swirl · Ring ·
## Spread: three rings circling one travelling centre). Cards to its right then work on the ring: a count multiplies
## the ring shots (Ring · Spread: a fan of three), a Swirl sends each its own random way (Ring · Spread · Swirl: the
## storm). v0.8.0 N3: the bolt's flight becomes the ring's (ring_flight). Only a ring has a layout; another form keeps
## the old meaning.
static func take_in(s: AttackSpec, form: int) -> void:
	if form != AttackSpec.Form.RING:
		return
	s.ring_layout = 1
	s.ring_flight = s.life_ticks if s.form == AttackSpec.Form.BOLT else 0  # v0.8.0 N3: the shot's flight
	s.ring_pulses = maxi(1, s.count) if s.count > 1 else 0
	s.swirl_group = 1 if s.swirl > 0 or s.swirl_group > 0 else 0
	s.count = 1
	s.spread = 0
	s.swirl = 0


## v0.8.0 BL (B6): whether hook card `id` is a once-per-line card and `s` already comes from one (class doc).
func once_more(s: AttackSpec, id: StringName) -> bool:
	if not once_per_line.has(id):
		return false
	for l in s.lineage:
		if once_per_line.has(StringName(l)):
			return true
	return false


## v0.8.0 PF2: whether `s` comes from a cast-free hook card (class doc): its lineage holds one.
func cast_free(s: AttackSpec) -> bool:
	for l in s.lineage:
		if cast_free_lines.has(StringName(l)):
			return true
	return false


## The hook `op` of card `m` (slot `i`) adds to `s`: its child, compiled by `m` (but its own hook) and the cards to
## its right, one level deeper.
func _hook(s: AttackSpec, m: ModifierTable, op: ModifierOp, i: int) -> AttackHook:
	var c := AttackSpec.new()
	c.id = m.id
	c.form = op.form
	c.tags = op.hook_tags.duplicate()
	if not c.tags.has(Modifiers.TAG_HOOK):
		c.tags.append(Modifiers.TAG_HOOK)
	c.depth = s.depth + 1
	c.radius_m = op.radius_m
	c.reach_m = op.reach_m
	c.seek = op.form == AttackSpec.Form.BEAM
	c.effect_id = op.effect_id
	SpecForms.hook_base(c, s)  # v0.6.0 MX2: the lingering forms' times; MX4: a bolt's flight, an arc's width
	BladeForms.hook_base(c, s)  # v0.6.5 WN4: a spin's wave flies all round
	var shape := WandCompile.new()  # v0.6.0 MX4: the child's own shape (a count, a status, an element...)
	for o in op.child_ops:
		shape.apply(c, m, o, -1)
	c.lineage = s.lineage.duplicate()  # v0.6.0 MX4: this modifier's hook never rides its own child
	c.lineage.append(String(m.id))
	var k := AttackHook.new()
	k.id = m.id
	k.trigger = op.trigger
	k.every = op.hook_every
	k.damage = op.damage
	k.damage_permille = op.damage_permille
	k.delay_ticks = op.delay_ticks  # v0.6.0 MX4
	k.when = op.when
	k.child = WandRings.cap_child(s, run(c, i))  # v0.8.0 AO: a ring's shards, at most so many alive
	return k


## The form-layering rule (design §2, owner B8): a second form op adds an attack in its own form that fires where the
## spec ends (ON_END), a copy of the spell so far (not its hooks), compiled by its card's other ops and the cards to
## its right.
func _layer(s: AttackSpec, m: ModifierTable, op: ModifierOp, i: int) -> AttackHook:
	var c := s.copy()
	c.id = m.id
	SpecForms.change_form(c, op.form)  # v0.6.0 MX4: keeps the range it ends at
	c.form_layers = 1
	c.depth = s.depth + 1
	c.hooks = []
	c.seek = false
	if not c.tags.has(Modifiers.TAG_HOOK):
		c.tags.append(Modifiers.TAG_HOOK)
	var k := AttackHook.new()
	k.id = m.id
	k.trigger = AttackSpec.Trigger.ON_END
	k.damage_permille = 1000
	k.child = run(c, i, i)
	return k


## Trigger card `m` at slot `i` ends `s` (class doc): the cards to its right build the child spell it casts.
func _cut(s: AttackSpec, m: ModifierTable, i: int) -> void:
	if child_base == null or s.depth >= MAX_DEPTH or s.lineage.has(String(m.id)):
		return
	if cast_free(s):  # v0.8.0 PF2: Blade Storm's blades cast nothing
		return
	var op := m.trigger_op()
	var trig := op.trigger_gun if gun and op.trigger_gun >= 0 else op.trigger
	if trig == AttackSpec.Trigger.ON_FINISHER:
		if s.depth != 0 or s.id != finisher_id:
			return  # only the combo's last step finishes; the cut still ends every other spec
		trig = AttackSpec.Trigger.ON_HIT
	var casts := maxi(1, op.casts)
	var gap := op.delay_ticks
	var hit := trig == AttackSpec.Trigger.ON_HIT or trig == AttackSpec.Trigger.ON_KILL
	if blade and hit and s.form == AttackSpec.Form.ARC:  # v0.8.0 BL (B3): a slash hit casts twice
		casts *= maxi(1, hit_casts)
		gap = gap if gap > 0 else cast_gap_ticks
	for n in casts:  # v0.6.5 WN5b: a legendary trigger casts again, delay_ticks apart
		var c := child_base.copy()
		c.id = m.id
		c.effect_id = m.id
		c.depth = s.depth + 1
		if not c.tags.has(WandCasts.TAG_CAST):  # v0.6.5 WN5a: a trigger's cast (the views draw it as one)
			c.tags.append(WandCasts.TAG_CAST)
		c.lineage = s.lineage.duplicate()
		c.lineage.append(String(m.id))
		var k := AttackHook.new()
		k.id = m.id
		k.trigger = trig
		k.damage_permille = child_damage_permille
		k.delay_ticks = gap * n
		k.child = WandRings.cap_child(s, run(c, i + 1))  # v0.8.0 AO: a ring's casts, likewise
		s.hooks.append(k)
	if not s.modifier_ids.has(String(m.id)):
		s.modifier_ids.append(String(m.id))

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
## - v0.9.0 AS (owner C63: "Different attack forms cannot coexist as simultaneous primary weapons"): a spec takes one
##   form op, the first; a later one is skipped (its card's other ops still run). Before AS a second form op layered
##   an ON_END copy of the spell in its own form; that layering is gone (the slot rules hold one Form and one Pattern
##   card, AttackSlots).
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
## - v0.8.0 MR (owner O91: "Prevent repeats repeating themselves"): a trigger's later casts (the second of ×2, a slash
##   hit's second) are repeats (AttackSpec.recast): a spell built from one casts each of its own triggers once, and a
##   repeat's hit (Echo, a Double Slash echo) launches no later cast (Attacks.run_hook). A card with an alt_target
##   (Split Wave) reads a spec of that target the other way while it has no child of the card's own target.
## - v0.8.0 PF2 (owner O9): a spec a cast-free hook made (WandTable.cast_free_lines: Blade Storm's blades, and anything
##   built from them) takes no trigger cut: the trigger still ends it, but its hits cast nothing.
## - v0.8.0 BL (B6): a spec a once-per-line hook made (WandTable.once_per_line: Split's splits, Explosive's blast, and
##   anything built from them: its lineage holds one) takes none of those hooks again: the first shot splits and
##   explodes, its splits neither split nor explode (the lineage guard alone stopped only the same card).
## - v0.8.0 AO (owner O37: "make the order of the attacks be more important"; evidence/ATTACK_ORDER.md): a SHAPE card
##   (ModifierTable.OrderKind; Ring) takes in what is left of it when it sets the form (take_in): a count becomes the
##   ring's pulses, a motion throws the whole ring group; COUNT and MOTION cards to its right then multiply and move
##   the rings (v0.9.0 AS: a count beside the Ring is gone with the one-Pattern rule). v0.8.0 N3 (owner O47): the ring
##   is the shot, flying the shot's flight (ring_flight); a motion left of it makes it wobble as it flies (WandRings).
##   Stat-like cards stay order-free. A bolt child built on such a ring (a card to the Ring's right: Split's shards,
##   a trigger's cast) keeps at most WandRings.RING_CHILD_ALIVE_MAX alive (WandRings.cap_child): every ring of a
##   launch hits, and each hit would throw its own.
## - v0.8.0 RM (owner O91: "Build reusable remnants, connections and events"; WAND.md rule 12): a REMNANT op is a hook
##   (the same guards: depth, lineage, once per line) whose child is what its remnant's activation casts, built where
##   its card sits like a trigger's child: by its own card and the cards to its right, so a later card shapes every
##   activation. The hook records its card's slot and trigger section (how many trigger cards stand left of it: Grand
##   Finale's reach) and, for a FINISHER remnant, whether the spec is the combo's finisher (it extracts; the other steps
##   lodge). A remnant left on a hit is an ON_HIT hook; a link, a path or a consumer is ON_REMNANT (Remnants finds it).

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
## v0.9.0 AS (owner Q13; ShotCap): the most shots one attack launches (0: no cap: a lab, a Blade run), and a merged
## shot's largest radius (per mille of its own).
var shot_cap := 0
var merge_radius_max_permille := 2000


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
	c.shot_cap = ShotCap.per_attack(w)  # v0.9.0 AS (Q13)
	if w.slot_table != null:
		c.merge_radius_max_permille = w.slot_table.merge_radius_max_permille
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


## `base` rewritten by every card (a fresh spec; `base` is not written). v0.9.0 AS: then within the per-attack shot
## cap (ShotCap.tree; none without one).
func spec(base: AttackSpec) -> AttackSpec:
	var s := run(base.copy(), 0)
	ShotCap.tree(s, shot_cap, shot_cap, merge_radius_max_permille)
	return s


## `s` rewritten by the cards from slot `from` on, in slot order (in place; returned).
func run(s: AttackSpec, from: int) -> AttackSpec:
	var moment := s.has_tag(Modifiers.TAG_MOMENT)
	for i in range(from, mods.size()):
		var m := mods[i]
		var alt := alt_reading(s, m)  # v0.8.0 MR: the card's other reading (Split Wave without a wave)
		if not alt and (not s.matches(m.target) or (moment and m.target.is_empty())):
			continue
		if m.is_trigger():
			_cut(s, m, i)
			break
		if s.beam_hold > 0 and LaserMods.is_card(m.id):  # v0.9.5 FC1: the Laser's cards are LaserMods'
			if not s.modifier_ids.has(String(m.id)):
				s.modifier_ids.append(String(m.id))
			continue
		if s.blast_mm > 0 and BombMods.is_card(m.id):  # v0.9.5 FC2: the Bomb's cards are BombMods'
			BombMods.note_card(s, m)
			continue
		if s.void_mm > 0 and VoidMods.is_card(m.id):  # v0.9.5 FC3: the Void's cards are VoidMods'
			VoidMods.note_card(s, m)
			continue
		if s.lance > 0 and LanceMods.is_card(m.id):  # v0.9.5 FC4: the Lance's cards are LanceMods'
			LanceMods.note_card(s, m)
			continue
		if s.rune_mm > 0 and RuneMods.is_card(m.id):  # v0.9.5 FC5: the Rune Explosion's cards are RuneMods'
			RuneMods.note_card(s, m)
			continue
		if s.glaive > 0 and GlaiveMods.is_card(m.id):  # v0.9.5 FC6: the Glaive's cards are GlaiveMods'
			GlaiveMods.note_card(s, m)
			continue
		if s.wave_mm > 0 and WaveMods.is_card(m.id):  # v0.9.5 FC8: the Wave's cards are WaveMods'
			WaveMods.note_card(s, m)
			continue
		if s.seekers > 0 and SeekerMods.is_card(m.id):  # v0.9.5 FC7: the Seekers' cards are SeekerMods'
			SeekerMods.note_card(s, m)
			continue
		var applied := false
		for stage in ModifierTable.STAGE_COUNT:  # a card's own ops in stage order
			for op in m.ops:
				if op.stage != stage or op.alt != alt:
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
			if s.form_layers == 0:  # v0.9.0 AS (C63): one form a spec; a later form op is skipped
				if m.order_kind == ModifierTable.OrderKind.SHAPE:
					take_in(s, op.form)  # v0.8.0 AO: the shape takes in what is left of it
				SpecForms.change_form(s, op.form)  # v0.6.0 MX4: keeps its range
				s.form_layers = 1
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
		ModifierOp.Op.REMNANT:  # v0.8.0 RM: a hook that leaves a remnant (class doc)
			if op.remnant == null or s.depth >= MAX_DEPTH or s.lineage.has(String(m.id)):
				return
			if not once_more(s, m.id):
				s.hooks.append(_remnant(s, m, op, i))
		_:
			Modifiers.numeric(s, op)


## v0.8.0 AO (owner O37; evidence/ATTACK_ORDER.md): a SHAPE card (Ring) turning `s` into `form` takes in what is left
## of it: v0.8.0 N3 the bolt's flight becomes the ring's (ring_flight), and a Swirl left of it makes the ring wobble
## round its line as it flies (Swirl · Ring). v0.9.0 AS (owner Q3): a count can't stand beside the Ring any more (one
## Pattern), so the count's pulses and the spinning group of several rings are gone. Only a ring has a layout; another
## form keeps the old meaning.
static func take_in(s: AttackSpec, form: int) -> void:
	if form != AttackSpec.Form.RING:
		return
	s.ring_layout = 1
	s.ring_flight = s.life_ticks if s.form == AttackSpec.Form.BOLT else 0  # v0.8.0 N3: the shot's flight
	s.swirl_group = 1 if s.swirl > 0 or s.swirl_group > 0 else 0
	s.swirl = 0


## v0.8.0 MR (owner O91: "Make Split Wave useful without Wave"): whether card `m` reads `s` the other way: `s` is of
## its alt_target and not its target, and no hook of `s` has a child of its target yet (a flying slash). Its `alt` ops
## run there instead of the others (ModifierTable.alt_target).
static func alt_reading(s: AttackSpec, m: ModifierTable) -> bool:
	if m.alt_target.is_empty() or s.matches(m.target) or not s.matches(m.alt_target):
		return false
	for k in s.hooks:
		if k.child.matches(m.target):
			return false
	return true


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
	c.recast = s.recast  # v0.8.0 MR: built from a later cast, it casts its triggers once
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


## v0.8.0 RM: the REMNANT op `op` of card `m` (slot `i`) on `s`: a hook (its child built as _hook builds one) that
## carries the remnant, its card's slot and section, and whether `s` extracts (class doc).
func _remnant(s: AttackSpec, m: ModifierTable, op: ModifierOp, i: int) -> AttackHook:
	var k := _hook(s, m, op, i)
	k.remnant = op.remnant
	k.slot = i
	k.section = section_of(i)
	var hit := (
		op.remnant.spawn == RemnantRule.Spawn.CONTACT or op.remnant.spawn == RemnantRule.Spawn.HIT
	)
	k.trigger = AttackSpec.Trigger.ON_HIT if hit else AttackSpec.Trigger.ON_REMNANT
	k.extract = op.remnant.activate == RemnantRule.Activate.FINISHER and s.has_tag(&"finisher")
	return k


## v0.8.0 RM: the trigger section of slot `i`: how many trigger cards stand left of it.
func section_of(i: int) -> int:
	var n := 0
	for k in mini(i, mods.size()):
		if mods[k].is_trigger():
			n += 1
	return n


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
	if s.recast != 0:  # v0.8.0 MR (O91): a later cast (or a spell built from one) casts each trigger once
		casts = 1
	for n in casts:  # v0.6.5 WN5b: a legendary trigger casts again, delay_ticks apart
		var c := child_base.copy()
		c.id = m.id
		c.effect_id = m.id
		c.depth = s.depth + 1
		if not c.tags.has(WandCasts.TAG_CAST):  # v0.6.5 WN5a: a trigger's cast (the views draw it as one)
			c.tags.append(WandCasts.TAG_CAST)
		c.lineage = s.lineage.duplicate()
		c.lineage.append(String(m.id))
		c.recast = 1 if n > 0 or s.recast != 0 else 0  # v0.8.0 MR (O91): the later casts are repeats
		var k := AttackHook.new()
		k.id = m.id
		k.trigger = trig
		k.damage_permille = child_damage_permille
		k.delay_ticks = gap * n
		k.child = WandRings.cap_child(s, run(c, i + 1))  # v0.8.0 AO: a ring's casts, likewise
		s.hooks.append(k)
	if not s.modifier_ids.has(String(m.id)):
		s.modifier_ids.append(String(m.id))

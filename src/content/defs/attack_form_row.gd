class_name AttackFormRow
extends Resource
## v0.9.0 AS (PLAN C60–C65; docs/roadmap/v0.9.0/ATTACK_FORMS.md): one Gun attack form's row of the compatibility table
## (AttackSlotsDefinition.forms): the form, the card that sets it (empty: the default form, Orbs, the Gun's own shot),
## and the Pattern, Secondary and Element cards it takes. A card in `allowed` is on, in `ruled` on with a rule of the
## form's own (the form's step builds the rule; until then it reads as on); every other card is off (C62: "No by
## default"), so it is never offered, never equipped and never compiled with this form.

@export var id: StringName = &""
@export var card: StringName = &""
@export var allowed: Array[StringName] = []
@export var ruled: Array[StringName] = []

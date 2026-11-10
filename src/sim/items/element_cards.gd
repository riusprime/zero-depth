class_name ElementCards
extends RefCounted
## Which held item is each element's card. ElementLevelsFsf and ElementStack ask on every hero hit, and a scan of
## the items held costs several microseconds each time, while the answer changes only with the items held. So it is
## remembered on the build's AttackBook (thrown away with the build) together with the items it was found in, and
## found again whenever those differ. Without a book (the build just changed) every caller scans as before.

## The slots: ElementLevelsFsf's FIRE, STORM, FROST, then ElementStack's five elements.
const FSF_BASE := 0
const STACK_BASE := 3
const SLOTS := 8
## A slot not looked up yet in this set of items.
const UNKNOWN := -2


## The item index remembered for `slot`, or UNKNOWN (also when there is no book to remember it in).
static func cached(w: World, slot: int) -> int:
	var b := w.attack_book
	if b == null:
		return UNKNOWN
	if b.element_idx.size() != SLOTS or b.element_owned != w.items_owned:
		b.element_owned = w.items_owned.duplicate()
		b.element_idx.resize(SLOTS)
		b.element_idx.fill(UNKNOWN)
	return b.element_idx[slot]


## Remembers `idx` (an item index or -1) for `slot`, for the items held now.
static func keep(w: World, slot: int, idx: int) -> void:
	var b := w.attack_book
	if b != null and b.element_idx.size() == SLOTS and b.element_owned == w.items_owned:
		b.element_idx[slot] = idx

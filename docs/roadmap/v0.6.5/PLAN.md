# v0.6.5 — Feedback pass: the wand (plan, owner-directed 2026-10-12)

The owner played v0.6.1 (`main` `950add4`) and finished the run on the normal route ("completed it, from the easy
side, right at the blue portal"). Their message is quoted line by line below. The version number is the lead's
pick for a feedback pass (ROADMAP §4); the owner may rename it. Progress: [`PROGRESS.md`](PROGRESS.md).

## The owner's feedback (2026-10-12, verbatim)
| # | Owner line | Decision | Status | Where |
|---|---|---|---|---|
| W1 | "So the lightning is a little bit buggy. There is a branch that we worked on that's called Gene Volta HT74PZ. And we changed the lightning. We are adding a dev mod menu where I will be able to adjust the balancing and also the lightning from inside the game so I can get what I'm looking for." | Handled on `claude/keen-volta-ht74pz` (the F10 dev panel: balance and lighting edits live; it is at "Dev panel Step 6"). This branch doesn't touch it; it merges in when that work is done | Other branch | keen-volta |
| W2 | "we have different bosses and different rooms based on the kind of boss. So right now we have the shooting boss, the one that's big and it looks like a cannon. And he does have the smaller room and he shouldn't have the room that small." | The Siege Engine's arena goes from 3×1 cells to **3×3** (owner pick: "3×3") | Decided | BR |
| W3 | "we've got the modifiers, but it kind of works the same as it did before, and we are not getting it right. So the point of the modifiers is to actually be a modifier of the basic attack that we are running on the game. So this happens in other roguelike games, like... Binding of Isaac or Magic Craft that you have the different items that you're getting that modify how your basic attack interacts, right? So, for example, the splitting balls in Binding of Isaac, the shooting the bigger balls, then whatever, or at Magic Craft, the different ways that all items interact in the order that you put them in the wand. So we need to change the modifiers and get it to work more in that way. So like almost everything that you take modifies how your basic attack looks and interacts and shoots and the idea is to be able to have a lot of different combinations that destroy the enemies, right?" | The wand: every pickup modifies the basic attack (looks, interaction, how it shoots); the order of the modifiers matters and the player can rearrange them (owner pick: "Order matters, rearrangeable"). Design in [`../../design/WAND.md`](../../design/WAND.md), G1 list for the owner before any build | Design (G1) | WD |
| W4 | (Q: should every pickup change the basic attack, no side attacks?) "We need to have different pools of modifiers tho blade and gun are different interactions and the modifiers should be unique, unless it doesn't matter and could apply to both like bleed or lightning" | Two pools: Blade-only and Gun-only modifiers, each unique to that weapon's interaction; a small shared pool only for what works the same on both (elements and statuses such as bleed, lightning) | Decided | WD |
| W5 | (Q: what do Blade modifiers act on?) "The slash becomes a spell" | Each slash is the Blade's spell: its modifiers make it bigger, split it, throw it as a wave, trigger on hit, and so on | Decided | WD |

## Steps
| Step | Scope | Rows |
|---|---|---|
| BR | The Siege Engine's arena 3×3 (data + generation tests) | W2 |
| WD | The wand design and the G1 modifier lists (Blade, Gun, shared) for the owner; build steps planned after the pick | W3–W5 |

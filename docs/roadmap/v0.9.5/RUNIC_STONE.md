# v0.9.5 G1: the Runic Stone (RUNIC_STONE)

**Owner (2026-10-25, line 1):** "There is a credits stone in the hub, I thought about adding some lore, we are gonna
adding a text bubbles, but the language that appears is gonna be runic, so no regular letters, at the beggning the
credit stone, now called runic stone will be locked, and after some action during the games it will be displaying some
runes that will change with easter egg interactions, the idea is not to create a full story but add some easter eggs
to the game that will build up from the stone in the hub."

**How to answer:** row by row. You can also rewrite any line (the English the runes spell is yours to choose).

## Today (live code)
- The hub's credits stone is `S_credits` in `data/hub/rune_ring.tres:51-61`. It uses the owner's model
  `hub_credits_stone`. Interacting opens the Credits screen (`main.gd:283`).
- Flags already exist for gating hub states: achievements, Codex entries and profile keys
  (`src/application/hub_flags.gd`). The profile is version 3 (`profile_store.gd:16`).

## Proposal
| ID | Topic | Proposal |
|---|---|---|
| S1 | Name and credits | The stone becomes the **Runic Stone**. The Credits move to the small menu (Play, Continue, Options, **Credits**, Quit), so they stay one press from the title screen. That matters for licences |
| S2 | Locked look | Dark, cold stone, no glow. Walking up shows no prompt, only a faint "…" bubble. Pressing does nothing but a low hum |
| S3 | How it wakes | The first time you **activate a purple-rune room** (the event that earns the Purple Portal), the stone's veins light violet in the hub on your return, and it speaks its first line. (Alternatives: S3b, the first boss kill; S3c, your first death) |
| S4 | How it speaks | Press it and a **speech bubble** opens over it, in runes only, one line at a time; press again for the next line it knows. The runes are the Elder Futhark, drawn as line glyphs in code (no font needed), glowing violet, each one fading in. **The hidden cipher:** each rune is one English letter (ᚠ = F, ᚢ = U …), so a curious player can decode every line with a Futhark table. There is no translation in the game: that's the easter egg |
| S5 | What it learns | Each easter egg below adds one line, and the stone always speaks its newest line first. A new line also makes the stone pulse once when you enter the hub |
| S6 | The full stone | With every line learned, the runes ring the stone permanently, and the **Runic** robe (cosmetic, black stone with violet veins) unlocks in the Wardrobe |

## The easter eggs (each one adds a line)
| ID | What you do | The line (English under the runes; yours to change) |
|---|---|---|
| R1 | Wake the stone (S3) | WHAT SLEEPS BELOW REMEMBERS |
| R2 | Die 10 times | YOU RETURN AND RETURN |
| R3 | Press the woken stone 7 times in a row | PATIENCE IS A KEY |
| R4 | Beat a boss without taking damage | UNTOUCHED BY THE DEEP |
| R5 | Stand still in the hub for 60 s (no input) | THE STILL ONE SEES |
| R6 | Find 8 of the 16 collectibles | THE PIECES CALL TO ONE ANOTHER |
| R7 | Beat the Hollow Crown | THE CROWN WAS ALWAYS HOLLOW |
| R8 | Finish 3 Ascension loops in one run | THE WHEEL TURNS FOR THE PATIENT |
| R9 | Break a cracked wall into a hidden room on 5 different runs | THE WALLS HIDE WHAT THEY FEAR |
| R10 | Read the stone in Spanish (switch the language with the stone woken) | EVERY TONGUE ONE RUNE (a joke for the bilingual player) |

## How it is built (once approved)
- **Storage:** a profile section `runes` (a list of learned line ids), so no profile version bump is needed (sections
  are created lazily).
- **Triggers:** reuse `AchievementTracker` stats where one exists (deaths, boss no-hit, collectibles, loops). R3, R5
  and R10 are hub-only checks in `HubSession`.
- **View:** `RuneBubble`, a Control drawn in code from a 24-glyph stroke table, over the stone. The stone's veins come
  from an emission mask on its model, or a code ring if the model has no second surface.
- **Steps:**
  1. **RS1:** the rename, S1–S5, R1–R3.
  2. **RS2:** R4–R10 and S6.
- **Tests:** a unit test for the cipher (each line round-trips); the hub e2e (press the locked stone → nothing; wake
  it → bubble); old profiles without `runes` load.

## Decisions (owner, date)
| ID | Answer | Built in |
|---|---|---|
| S1–S6, R1–R10 | Approved as written (owner, 2026-10-25, in chat) | |

# Roguelike Gap Analysis & Initial Development Roadmap v0.1

> **Status: PENDING. The owner pastes the full document below the line, verbatim.**
>
> This is the design source for the whole game. It was attached to the planning conversation but was not
> available to the session that wrote the starter kit. So this file is a placeholder: no part of the document has
> been reconstructed, summarized or guessed. Paste the original exactly. Don't rewrite or "clean it up".
> Owner action O1 in [`../roadmap/v0.0.1/PLAN.md`](../roadmap/v0.0.1/PLAN.md) Step 0.

## Citation map (the lead fills this in after the paste)

The other docs cite this file as `GA §n` (a section number from the planning conversation) or `GA: <topic>` (a
topic still to be resolved). After the paste, the lead:
1. fills in the **Section** column below;
2. checks that the planning conversation's two section numbers (§1–3 for the scorecard, §5 for the player kit)
   point where the docs say, and corrects any that don't;
3. checks the numbers the kit already states against the document;
4. records any mismatch as an owner question. It never silently fixes one in either direction.

| Topic | Cited from | What the docs expect to find | Section |
|---|---|---|---|
| scorecard (`GA §1–3`) | SCORECARD §2; LESSONS; CONTENT_SCHEMA | Metrics, target bands, bot or archetype definitions | §1–3 (to confirm) |
| player kit (`GA §5`) | BLUEPRINT §C; CONTENT_SCHEMA §8; v0.0.1 PLAN Steps 4, 6 | Move speed, radius, primary, guard, mobile skill and dash numbers | §5 (to confirm) |
| run structure | LOCKED_DECISIONS PD-03 | 3 floors × 7–9 mandatory encounters + 1–3 optional branches; median 35–45 min | |
| rewards | PD-07; BLUEPRINT §B | Starter after Room 1, compatible payoff after Room 3, fallback in Room 4, drought limit 2; pools and weights | |
| threat | PD-05; SIM_CONTRACTS §11; BLUEPRINT §H; SCORECARD M-THREAT | Threat T, what it modifies, its formula | |
| scaling | SIM_CONTRACTS §11; CONTENT_SCHEMA §7; BLUEPRINT §H | Per-floor HP, damage and density | |
| items | CONTENT_SCHEMA §2; BLUEPRINT §D | The 12 slice roles; ≤ 4 plain-support items per 24-item pool | |
| caps | SIM_CONTRACTS §8; BLUEPRINT §D; SCORECARD M-CAP | Sustain caps (heal, barrier, refunds) and their windows | |
| slots | PD-08; BLUEPRINT §D | 6 mechanism slots + 3-slot reserve | |
| enemies | CONTENT_SCHEMA §3; BLUEPRINT §E | Charger, Warden, Needle, Disruptor, Splitter, Anchor; the minimum telegraph length | |
| boss | BLUEPRINT §F | Boss 1 pursuit / lanes / recovery; stagger rules; roles of bosses 2–3 | |
| input | SIM_CONTRACTS §3; ARCHITECTURE §7; BLUEPRINT §C | Aim assist (about a 12° cone, pad only) | |
| meta | PD-06; BLUEPRINT §I | Alternatives, information, cosmetics; no permanent stats | |
| milestones | ROADMAP §4 | M0–M6 (the roadmap splits M4 into M4a/M4b) | |

---

<!-- Paste the full original document below this line. -->

# Roguelike audit framework

> **Provenance:** pasted by the owner on 2026-10-06 and committed verbatim below the line. It is the evaluation
> framework and the instructions for a *Roguelike Gap Analysis Report*: five design pillars, then the five
> sections such a report must contain. It holds no game data or numbers. The report written against it, the
> *Roguelike Gap Analysis & Initial Development Roadmap v0.1*, belongs in
> [`ROGUELIKE_GAP_ANALYSIS_v0.1.md`](ROGUELIKE_GAP_ANALYSIS_v0.1.md).
>
> How the kit uses it:
> - [`GAME_BLUEPRINT.md`](GAME_BLUEPRINT.md) §A maps the game's pillars onto these five.
> - [`../balance/SCORECARD.md`](../balance/SCORECARD.md) §2 turns each report section into measured metrics.
> - SCORECARD §6 schedules this game's own gap-analysis reports, written in this format.

---

# Theoretical Framework for Evaluation
Evaluate the game systems against these 5 core design pillars:

1. **Engine Building vs. Flat Stats:** Satisfying roguelikes give players interlocking mechanical engines (Triggers $\rightarrow$ Conditions $\rightarrow$ Payoffs) rather than passive numerical bloat ($+5\%$ HP, $+10\%$ Damage).
2. **The Polar Archetype Rule (Aggro vs. Control):** The design envelope must support wildly different playstyles at the extremes (e.g., fast high-risk burst vs. slow high-mitigation attrition/defense). Neither extreme should be unviable or trivial.
3. **Compressed Progression Curve:** A 100-hour RPG progression curve must be squashed into a 30–60 minute run. Build identity must crystallize early (by Room 3–4). The game must actively punish the "Skyrim/Generalist" trap (being decent at everything).
4. **Encounters as Engine Stress-Tests:** Enemies must challenge specific build weaknesses (e.g., reactive damage vs. high-frequency burst, dispel vs. buff-stacking) rather than acting as simple DPS sponges.
5. **Meaningful Choice & Non-Dominance:** No single item or combo should be a mandatory "auto-pick," and no items should exist as mathematically dead loot.

---

# Audit Instructions & Required Deliverables

Analyze the game systems and simulation data provided below and output a comprehensive **Roguelike Gap Analysis Report** containing the following sections:

### Section 1: Executive Balance & Archetype Scorecard
* Compare the performance of the game's primary playstyles (Aggro/Burst, Control/Attrition, Combo/Engine, Generalist).
* Document win rates, clear times, floor mortality distributions, and power scaling curves.
* Identify if an archetype monoculture exists (e.g., pure burst dominates while defense is mathematically non-viable).

### Section 2: Engine Health & Item Synergy Matrix
* **Dead Weight Items:** Identify items/skills that provide flat numerical buffs without altering player decision-making or mechanics.
* **Degenerate / Infinite Loops:** Flag any interactions where a resource expenditure generates equal or greater returns, breaking the action economy.
* **Synergy Density:** Measure how well items combine multiplicatively rather than additively.

### Section 3: Progression Pacing & Build Crystallization
* Identify the exact room/floor where character playstyles diverge from the baseline.
* Evaluate whether early rewards force hard specialization or encourage generic stat-stacking.
* Flag any mid-to-late run power plateaus or abrupt vertical spikes.

### Section 4: Encounter Counterplay & Stress-Testing
* Break down how different enemy types and bosses impact each archetype.
* Pinpoint "false difficulty" encounters (e.g., arbitrary hard enrage timers that invalidate defensive control builds by design, or unavoidable chip damage that ruins glass cannons).

### Section 5: Actionable Redesign Specifications
For every major gap identified, provide concrete, drop-in solutions:
* **Item Reworks:** Take at least 3 flagged "flat stat" items and rewrite them using the **Trigger $\rightarrow$ Condition $\rightarrow$ Payoff** model.
* **Archetype Tuning:** Provide exact formula/stat adjustments to balance underperforming archetypes.
* **Pacing Adjustments:** Specify where reward tables or difficulty scaling must be shifted to ensure early build divergence.

---
name: Data section is not the descriptive-stats section
description: Data section describes sample construction and variable definitions only. Distributional facts (means, SDs, frequencies, summary-stats tables) live in a separate descriptive-stats section.
type: feedback
---

The Data section and the Descriptive Statistics section are separate. Do not mix them.

**Data section's job**: explain how the sample was built, what each variable is meant to capture, and what construction choice hits that target. Sample-size facts that characterize the panel structure (number of bank--ZIP--year cells, time period) are OK because they describe the unit of observation, not the variable distributions.

**Descriptive Statistics section's job**: report means, standard deviations, percentiles, frequencies; comment on distributional features; cross-reference the summary-stats table; describe how variables move across size buckets, periods, or subgroups.

What does NOT belong in the Data section:
- Sample mean / SD of any constructed variable (e.g., "deposit beta has a mean of 0.291 and SD of 0.066").
- Frequencies of binary indicators ("true in 56% of observations").
- References to `\ref{tab:descriptive_stats}` or any other summary-stats table.
- Distributional commentary ("the distribution is tight across buckets but shifts to the right for large banks").
- Mean opening rate or any DV-summary statistic.

What DOES belong in the Data section:
- Total panel size (N bank--ZIP--year observations).
- Sample period and unit of observation.
- Sample inclusion/exclusion rules and their rationale.
- Variable definitions and construction logic.
- Why a given measurement target is hit by a given construction.

**Why:** User feedback on first-draft-may2026 data section: "we shouldn't include summary stats in the data section, there is a separate summary stats section which we will get to later." Mixing the two duplicates content and violates the structural separation between sample/variable definition and distributional description.

**How to apply:** Before saving any data section, grep its body for digit patterns indicating distributional content (`\.\d`, `\d+ percent`, `mean of`, `standard deviation`, `\ref\{tab:.*stats\}`). Move every such mention to the descriptive-statistics section.

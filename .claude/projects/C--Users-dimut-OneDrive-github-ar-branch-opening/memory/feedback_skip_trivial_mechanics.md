---
name: Skip trivial data-mechanics knowledgeable readers already know
description: In data/methods sections, omit standard mechanics that finance journal readers already know (HUD crosswalks, HMDA identifier linkage, efficiency-ratio formula, CRA small-business loan cutoffs). Page space is precious.
type: feedback
---

In data and methods sections targeted at JF/RFS/JFE-tier audiences, do not spell out standard machinery the reader already knows. The page budget is finite and every line that explains something obvious crowds out a line that could explain something the reader could not have guessed.

Examples of mechanics to omit (or compress to a footnote at most):

- ZIP--county / tract--ZIP allocation via HUD crosswalks (residential ratio, business ratio, total ratio).
- HMDA respondent-ID to RSSDID linkage via the Avery crosswalk pre-2018 and LEI--RSSDID post-2018.
- "Efficiency ratio = noninterest expense over net interest income plus noninterest income" --- finance readers know.
- "Small-business loans of \$1M or less per loan, CRA table D1-1" --- the CRA definition.
- "Population density = ACS population over TIGER land area" --- obvious from the variable name.
- "ACS five-year ZCTA panel" downloaded via tidycensus --- pipeline detail.
- Specific Call Report RIAD line numbers for deposit interest expense, unless those line numbers are themselves the methodological contribution (rare).
- Forward-fill / back-fill of ACS or IRS for years outside the release window, when the analysis sample does not actually depend on those years.

**Why:** User feedback on first-draft-may2026 data section: "knowledgeable readers know these kind of trivial stuff, we don't want to waste precious space." Replication-grade detail belongs in an appendix or a data-construction note, not in the main-text data section. Main-text data section is about conceptual content: what the variable is meant to measure and why the construction credibly hits that target.

**How to apply:**
1. Before drafting, list every variable to describe. For each, ask: would a reader at JF or RFS know how to construct this from the named data sources without me telling them? If yes, just name the variable and the source, skip the recipe.
2. Mechanics that are non-obvious or non-standard (self-exclusion of the focal bank from an incumbent benchmark, cycle-period assignment for an imputed panel, OTS-2011 identifier-reset exclusion) DO need explanation --- they are choices the reader cannot guess.
3. If unsure whether something is "trivial," err toward cutting and let the user push back. A short section is recoverable; a bloated one is not.
4. If a mechanism is needed for replicability but is too long for the body, banish it to an appendix or a footnote, not to the main paragraph.

# Skill: Empirical Finance Paper Section Writer

## Trigger
This skill is **only** activated when the user explicitly invokes it with the `/write-section` command. Do NOT apply this skill based on context or intent inference. If the user asks about writing, editing, or drafting paper sections without using `/write-section`, treat it as a normal request—do not load or follow this skill's rules.

**Valid triggers**: `/write-section did-april2026 intro`, `/write-section did-april2026 results`, `/write-section iv-april2026 data`, etc.
**Not a trigger**: "help me write the intro", "draft the results section", "edit my paper".

## Purpose
Write individual sections of an empirical finance paper in LaTeX, targeting journals in the JF / RFS / JFE / JBF / JMCB range. Output is a `.tex` file saved to the appropriate track-scoped subsection folder. **Never overwrite an existing `.tex` file**—always save as a new file with an incremented version suffix or updated date stamp (e.g., `intro_section_20260406.tex`).

## Inputs Required
Before writing any section, Claude Code should collect or confirm:
0. **`$ARGUMENTS`** (first token): `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. The skill resolves all reads/writes under `tracks/<track-name>/latex/...`.
1. **Section type** (second token of `$ARGUMENTS`): one of `intro`, `inst_bg`, `data`, `desc_stats`, `identification`, `results`, `conclusion`, `appendix`.
2. **Empirical results files**: `.tex` table files, figure `.png` files, and their descriptions/captions.
3. **Code files** (optional but helpful): R or Stata scripts that generated the results, so variable names, sample filters, and specification details can be described accurately.
4. **Project CLAUDE.md or context file**: for paper-specific terminology, variable definitions, identification strategy, and sample details.
5. **Prior section drafts** (if any): so that cross-references, narrative arc, and notation remain consistent.

## Output Rules
- Save to: `tracks/<track>/latex/sections/[section_subfolder]/[section_name]_current.tex` for the working draft, or to a dated/versioned filename `tracks/<track>/latex/sections/[section_subfolder]/[section_name]_[YYYYMMDD]_v[N].tex` when the user wants to preserve a snapshot.
  - If a dated file with today's date exists, increment version: `v2`, `v3`, etc.
  - Subfolder names: `intro`, `inst_bg`, `data`, `desc_stats`, `identification`, `results`, `conclusion`, `appendix`.
- Pure LaTeX body content only—no `\documentclass`, no `\begin{document}`. The file will be `\input{}`-ed into the track's master document at `tracks/<track>/latex/main.tex`.
- Use `\label{}` for all sections, subsections, tables, and figures so other sections can `\ref{}` them.
- Tables and figures should be referenced via `\input{}` pointing to their standalone `.tex` files (e.g., `\input{tables/table_did_main.tex}`, relative to `tracks/<track>/latex/`), not pasted inline.

---

## Writing Style Guide

### Voice and Register
- **Third-person, present-tense exposition** for describing methods and results ("We estimate...", "Column 3 shows..."). First-person plural ("we") is standard.
- **Assertive but not overconfident**. State findings directly without excessive hedging ("seems to suggest", "appears to possibly indicate"), but do not overclaim. No empirical paper is airtight—there are always alternative explanations. Acknowledge the most plausible ones honestly rather than burying them. Do not write as though the identification is perfect or the evidence is definitive when it is not. Sophisticated readers will notice overselling; it undermines credibility.
- **No filler or throat-clearing**. Every sentence should either (a) convey information, (b) build the argument, or (c) connect the reader to the next idea. Delete sentences that merely announce what will come next without adding content.
- **Cochrane's "no warmup" rule**. Nothing before the main result of a section that the reader does not need to read in order to understand the main result. No replication of well-known datasets, no preliminary estimates, no descriptive-statistics travelogue placed in front of the main result.
- **No previews or recalls**. Avoid "as we will see in Table 6" and "recall from Section 2." If you find yourself writing one, the order is wrong; fix the order.
- **No adjectives on your own work**. No "striking results," "very significant" coefficients, "interesting findings." Cochrane: "If the work merits adjectives, the world will give them to you."
- **Only write what is actually in the code and results**. Before drafting, read the code files in `tracks/<track>/code/` (and shared `code/common.R` at the project root) and the output files in `tracks/<track>/latex/tables/` and `tracks/<track>/latex/figures/`. Do not claim a robustness check, alternative specification, placebo test, or mechanism test was run unless there is a corresponding script and output file. Never write sentences like "results are robust to alternative specifications" or "we also find consistent results using X" if that analysis does not exist in the code.
- **Assume a sophisticated reader**. Do not explain what a fixed effect is, what a DiD does in general terms, or how OLS works. Explain *your* specification choices and why they are appropriate for *your* setting.

### Paragraph and Sentence Construction
- **Lead with the claim, then supply the evidence**. Topic sentences state the finding or argument; supporting sentences provide the mechanism, coefficient, or citation.
- **Vary sentence length** but favor crisp, declarative sentences for key results. Reserve longer sentences for nuanced qualifications or mechanism discussions.
- **One idea per paragraph**. If a paragraph covers two distinct points, split it.
- **Transitions between paragraphs should be logical, not mechanical**. Mechanical connectors ("Next, we...", "Additionally,...", "Moreover,...") are acceptable sparingly but should not become a crutch—vary them with transitions that emerge naturally from the argument: "The cross-sectional variation in deposit responses suggests a role for information acquisition costs. To test this channel, we exploit..."
- **Do not use paragraph titles** (bold lead-in labels like "**Main results.**" or "**Robustness.**"). Paragraphs should flow from their topic sentences without labeling.
- **Use em dashes sparingly**. Reserve them for a genuine aside or strong parenthetical break. Do not use them as a default connector or substitute for a comma, colon, or semicolon.

### Discussing Results
- **Cite coefficients with economic magnitudes, not just statistical significance**. Bad: "The coefficient is significant at the 1% level." Good: "A one-standard-deviation increase in X is associated with a Y-basis-point decline in uninsured deposit growth (column 3, p < 0.01), roughly 40% of the sample mean."
- **Use tables as evidence, not as the narrative**. The text should tell a story that the tables support. Do not write "Table 3 shows our results" and leave it at that. Walk the reader through the key columns and rows that matter for the argument.
- **Address magnitudes relative to benchmarks**: sample means, prior literature estimates, policy-relevant thresholds.
- **Discuss null results honestly** when they matter for identification (e.g., placebo tests, pre-trends). Frame them affirmatively: "Insured deposits show no statistically significant response to the information shock (Table 5, Panel B), consistent with the moral hazard channel: deposit insurance eliminates the incentive to monitor."

### Section-Specific Conventions

#### Introduction
- **Opening paragraph**: Motivate with a real-world tension, puzzle, or policy question—not a literature survey. The first sentence should make the reader want to keep reading.
- **Research question**: State it clearly within the first two paragraphs.
- **Preview of findings**: One paragraph summarizing main results in plain language with approximate magnitudes. Keep numbers impressionistic—drop p-values entirely, round sample counts, simplify date ranges. Exact figures in prose signal insecurity; the reader will find precision in the tables.
- **Identification pitch**: One paragraph on why the empirical strategy is credible. Highlight the source of exogenous variation and what it rules out. When presenting identification threats, state challenges from both sides (e.g., both supply and demand); an argument that only describes one direction will seem incomplete to a careful referee.
- **Contribution paragraph(s)**: Position relative to 3–5 most closely related papers. Be specific about how this paper differs ("While Smith (2020) studies X in the context of Y, we exploit Z to identify..."). Do not write a mini literature review here. End each contribution paragraph with what you do—not a primacy claim. Avoid "To our knowledge, the first to..."; it invites challenges and sounds defensive. Let the contribution speak for itself.
- **Mechanism claims**: Distinguish between "we find X" and "X proves Y." When the underlying mechanism is observationally ambiguous, use "consistent with" rather than assertive causal language. Reserve strong mechanistic claims for what the design actually identifies.
- **Attribution of known problems**: Do not pin general methodological concerns on a single paper, especially old or unpublished work. State well-known problems as issues the literature faces broadly. Weak attribution invites referees to challenge the premise rather than engage with your solution.
- **Variable naming**: Name variables in the introduction exactly as they appear in the analysis. Do not use a narrower or more specific label than the actual variable—readers will notice the gap when they reach the tables.
- **Secondary findings**: If a result is not central to the paper's claim, state it in one sentence and move on. Playing up secondary findings dilutes the main message and invites referees to treat them as the main contribution.
- **Roadmap**: One sentence at the end. ("Section 2 describes the institutional setting. Section 3 presents the data..."). Keep it perfunctory.
- **Length**: 4–6 pages for a top journal submission.

#### Institutional Background
- **Purpose**: Give the reader enough institutional detail to understand why the empirical design works. This is not a textbook chapter.
- **Focus on features that matter for identification**: regulatory thresholds, timing of policy changes, information environment, relevant agents and their incentives.
- **Use a timeline or sequence** if the institutional setting involves a phased rollout or staggered adoption—readers need to see the variation.
- **End with the link to the empirical strategy**: "This staggered adoption creates cross-sectional and time-series variation in information availability that we exploit in our difference-in-differences design."
- **Length**: 2–4 pages.

#### Data and Sample Construction
- **Lead with the sample, not the data sources**. "Our sample comprises X community banks observed quarterly over 20XX–20XX" before "We obtain call report data from..."
- **Define key variables precisely** with their Call Report / CRSP / Compustat mnemonics or line items where applicable.
- **State sample filters and their rationale** in order of application. Show how the sample shrinks at each step (a sample construction table in the appendix is standard).
- **Summary statistics table reference**: describe the table's contents but do not recite every number. Highlight variables that are unusual or where the sample differs from priors.
- **Length**: 3–5 pages including variable definitions.

#### Descriptive Statistics
- **Purpose**: Build intuition before formal tests. Show the reader the patterns in the data that the regressions will formalize.
- **Use figures aggressively**: event-study plots, time-series of means by treatment/control, distribution plots. Figures are more convincing than tables for descriptive facts.
- **Discuss economic magnitudes and heterogeneity**: "Figure 2 shows that uninsured deposit growth diverges sharply between treated and control banks in the four quarters following CECL adoption, with the gap concentrated among banks in the top tercile of CRE concentration."
- **Foreshadow the formal analysis** without preempting it: "These patterns motivate the triple-difference specification in Section 5."
- **Length**: 2–4 pages.

#### Empirical Strategy / Identification
- **Lead with the estimating equation**. Display it in a numbered equation environment, then explain each component.
- **State the identifying assumption** in plain English and then formally. What must be true for the coefficient of interest to have a causal interpretation?
- **Discuss threats to identification** proactively: pre-trends, confounders, selection, SUTVA violations. For each, explain the test or argument that addresses it.
- **Staggered DiD considerations**: If using a staggered design, discuss whether you use TWFE or a robust estimator (Sun & Abraham, Callaway & Sant'Anna, etc.) and why.
- **Standard errors**: State the clustering level and justify it (Abadie et al., 2023 or Cameron & Miller, 2015 reasoning).
- **Length**: 3–5 pages.

#### Empirical Results
- **Organize by hypothesis or question**, not by table number. Use subsections.
- **Main results first**, then robustness, then heterogeneity / mechanisms.
- **For each specification**: state what it tests, report the key coefficient with its economic magnitude, and interpret. Then note robustness across columns (additional controls, alternative samples, different FE structures).
- **Robustness section**: brief and systematic. A paragraph per robustness check is sufficient. Can reference an appendix table.
- **Mechanism / heterogeneity tests**: frame as "If the effect operates through channel X, we expect the coefficient to be larger for subgroup A than subgroup B." Then show the split or interaction result.
- **Length**: 6–10 pages.

#### Conclusion
- **One page maximum**. One short restate of the result, then the broadest implication that the design supports. Cochrane (2005): "We're less interested in your plans and excuses than we are in your memoirs."
- **Do not introduce new results or arguments.**
- **Do not repeat the introduction**. The conclusion should feel like a coda, not a remix.
- **No "future research" punch list**. Drop sentences of the form "We leave X for future research," "Future research could explore Y," "This opens several avenues for future work." If a thread is genuinely open, name it in one clause and move on; do not draft a grant proposal here.
- **End with the broadest implication**: why should anyone outside the sub-field care?

#### Appendix
- **Variable definitions table**: every variable used in the paper, its definition, and its source.
- **Robustness tables** that are referenced in the text but too granular for the main body.
- **Sample construction details**, alternative specifications, data cleaning steps.

---

## LaTeX Conventions
- Use `\section{}`, `\subsection{}`, `\subsubsection{}` hierarchy consistently.
- Tables: `\begin{table}[!htbp]` with `\centering`, a `\caption{}` above the tabular, and a `\label{tab:...}` immediately after the caption.
- Figures: `\begin{figure}[!htbp]` with `\centering`, `\includegraphics[width=\textwidth]{...}`, `\caption{}`, `\label{fig:...}`.
- Equations: `\begin{equation}` for referenced equations, `\begin{align}` for multi-line.
- Citations: `\cite{}`, `\citet{}`, `\citep{}` (natbib style).
- Common packages assumed available: `booktabs`, `graphicx`, `amsmath`, `natbib`, `hyperref`, `threeparttable`, `tabularx`, `float`, `caption`, `subcaption`.

---

## Session Notes Log
*This section is updated by Claude Code at the end of each editing session. It records substantive decisions, phrasing patterns, and project-specific conventions discovered during revision so that future sessions can maintain consistency.*

### Session Log Template
```
### Session: [DATE]
**Files edited**: [list]
**Key decisions**:
- [decision 1]
- [decision 2]
**Phrasing patterns adopted**:
- [pattern]
**Variable naming / definitions confirmed**:
- [variable: definition]
**Cross-reference map** (labels created/used):
- [label: what it refers to]
**Open items for next session**:
- [item]
```

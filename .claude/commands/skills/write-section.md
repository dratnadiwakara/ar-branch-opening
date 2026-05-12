# Skill: Empirical Finance Paper Section Writer

## Trigger
This skill is **only** activated when the user explicitly invokes it with the `/write-section` command. Do NOT apply this skill based on context or intent inference. If the user asks about writing, editing, or drafting paper sections without using `/write-section`, treat it as a normal request—do not load or follow this skill's rules.

**Valid triggers**: `/write-section did-april2026 intro`, `/write-section did-april2026 results`, `/write-section iv-april2026 data`, `/write-section intro` (track inferred), `/write-section results` (track inferred), `/write-section did-april2026 intro emphasize the cost-channel story and cite NRS 2026 in the contribution paragraph`, `/write-section results focus on Table 4 columns 3-5`, etc.
**Not a trigger**: "help me write the intro", "draft the results section", "edit my paper".

### Argument Grammar

```
/write-section [<track>] <section-type> [<free-text instructions...>]
```

- Token 1: track name OR section type (see Track Resolution).
- Next token: section type (only if token 1 was track).
- **Everything after the section type** is treated as a single free-text **instructions** string. Optional.

### Free-Text Instructions (optional trailing argument)

After the required tokens are consumed, any remaining text in `$ARGUMENTS` is the user's section-specific instructions. Treat it as **high-priority guidance** layered on top of the default style rules, but never as a license to violate the hard rules (no warmup, only write what code produces, no fictional robustness, etc.).

For section types that emit multiple subsections from a single file (currently: `data`, which always emits a `Data Sources and Sample Construction` subsection followed by a `Descriptive Statistics` subsection into `data_current.tex`), the free-text instructions accept a `||` separator. Text before the first `||` is the high-priority guidance for the first subsection; text after it is for the second; text after a second `||` is for the third (if applicable). Empty slots inherit no extra guidance. If no `||` appears, the entire instruction string applies to all subsections equally. The same separator rule applies to other multi-subsection section types if any are added later.

Use the instructions to:
- pick which tables/figures to lead with (`focus on Table 4 columns 3-5`),
- enforce a specific framing (`emphasize the cost-channel story`),
- add or drop citations (`cite NRS 2026 in the contribution paragraph`, `do not cite Smith 2020`),
- constrain length (`keep under 2 pages`, `single paragraph`),
- request a particular tone, hedge, or qualifier,
- pin variable naming or notation.

When instructions conflict with the section-specific style block below (e.g., user asks for a "future research" punch list in the conclusion), follow the **user**, but flag the deviation in one line at the top of your reply before producing the file.

If instructions are ambiguous or unverifiable (refer to a table that does not exist, request a robustness check absent from the code), **stop and ask** rather than fabricating.

### Track Resolution

If `$ARGUMENTS` contains only one token and that token is a valid section type (`intro|inst_bg|data|identification|results|conclusion|appendix`; `desc_stats` is an alias for the second subsection of `data` --- see the Data block in section-specific conventions), infer the track:

1. List directories under `tracks/`, excluding `.archived/` and any hidden folders.
2. **Single candidate** → use it. Proceed silently.
3. **Multiple candidates** → pick the most-recently-modified track by checking, in order:
   - latest `git log -1 --format=%ct -- tracks/<name>/` timestamp across candidates, OR
   - mtime of `tracks/<name>/NOTES.md` if git history is sparse.
   If one track is clearly more recent (>7 days gap to next), use it and **announce the inference** in one line: `Inferred track: did-april2026 (most recent activity).`
4. **Ambiguous** (multiple tracks active within 7 days, or no clear signal) → **stop and ask** the user which track. Do not guess.
5. **Zero tracks** → stop, report missing.

If the first token of `$ARGUMENTS` is not a recognized section type, treat it as a track name (existing behavior) and the second token as the section type.

## Purpose
Write individual sections of an empirical finance paper in LaTeX, targeting journals in the JF / RFS / JFE / JBF / JMCB range. Output is a `.tex` file saved to the appropriate track-scoped subsection folder. **Never overwrite an existing `.tex` file**—always save as a new file with an incremented version suffix or updated date stamp (e.g., `intro_section_20260406.tex`).

## Inputs Required
Before writing any section, Claude Code should collect or confirm:
0. **`$ARGUMENTS`** (first token): `<track-name>` — the track folder name under `tracks/`, e.g. `did-april2026`. **Optional**: if omitted (only a section type is passed), the skill infers the track per the **Track Resolution** rules above. The skill resolves all reads/writes under `tracks/<track-name>/latex/...`.
1. **Section type**: one of `intro`, `inst_bg`, `data`, `desc_stats`, `identification`, `results`, `conclusion`, `appendix`. Position depends on whether the track was passed (second token) or inferred (first token).
2. **Free-text instructions** (optional): any tokens after the section type are concatenated into a single instructions string. Applied per the **Free-Text Instructions** rules in the Trigger block.
3. **Empirical results files**: `.tex` table files, figure `.png` files, and their descriptions/captions.
4. **Code files** (optional but helpful): R or Stata scripts that generated the results, so variable names, sample filters, and specification details can be described accurately.
5. **Project CLAUDE.md or context file**: for paper-specific terminology, variable definitions, identification strategy, and sample details.
6. **Prior section drafts** (if any): so that cross-references, narrative arc, and notation remain consistent.

## Output Rules
- Save to: `tracks/<track>/latex/sections/[section_subfolder]/[section_name]_current.tex` for the working draft, or to a dated/versioned filename `tracks/<track>/latex/sections/[section_subfolder]/[section_name]_[YYYYMMDD]_v[N].tex` when the user wants to preserve a snapshot.
  - If a dated file with today's date exists, increment version: `v2`, `v3`, etc.
  - Subfolder names: `intro`, `inst_bg`, `data`, `desc_stats`, `identification`, `results`, `conclusion`, `appendix`.
- Pure LaTeX body content only—no `\documentclass`, no `\begin{document}`. The file will be `\input{}`-ed into the track's master document at `tracks/<track>/latex/main.tex`.
- Use `\label{}` for all sections, subsections, tables, and figures so other sections can `\ref{}` them.
- **Floats live in `tables_figures.tex`, not in section files.** Every `\begin{figure}...\end{figure}` and `\begin{table}...\end{table}` block — its caption, its `\label{}`, its `\adddescription{}`, its `\input{tables/...}` of the bare tabular fragment — is hosted in `tracks/<track>/latex/tables_figures.tex`, the unsectioned floats file `\input{}`-ed from `main.tex` *after* the bibliography. Body sections (intro, data, identification, results, heterogeneity, robustness, conclusion) refer to floats by `\ref{tab:...}` / `\ref{fig:...}` only and never inline a `\begin{figure}` or `\begin{table}` environment. Before drafting any section, grep `tracks/<track>/latex/tables_figures.tex` for existing `\label{fig:...}` and `\label{tab:...}`, build a label-map, and use only those labels in the new section. If the section genuinely needs a float that does not yet exist, add it to `tables_figures.tex` via `/skills/latex-table-inserter` or `/skills/latex-figure-inserter` and then `\ref{}` it from your section.

---

## Writing Style Guide

### Voice and Register
- **Third-person, present-tense exposition** for describing methods and results ("We estimate...", "Column 3 shows..."). First-person plural ("we") is standard.
- **Assertive but not overconfident**. State findings directly without excessive hedging ("seems to suggest", "appears to possibly indicate"), but do not overclaim. No empirical paper is airtight—there are always alternative explanations. Acknowledge the most plausible ones honestly rather than burying them. Do not write as though the identification is perfect or the evidence is definitive when it is not. Sophisticated readers will notice overselling; it undermines credibility.
- **No filler or throat-clearing**. Every sentence should either (a) convey information, (b) build the argument, or (c) connect the reader to the next idea. Delete sentences that merely announce what will come next without adding content.
- **Cochrane's "no warmup" rule**. Nothing before the main result of a section that the reader does not need to read in order to understand the main result. No replication of well-known datasets, no preliminary estimates, no descriptive-statistics travelogue placed in front of the main result.
- **No previews or recalls**. Avoid "as we will see in Table 6" and "recall from Section 2." If you find yourself writing one, the order is wrong; fix the order.
- **No adjectives on your own work**. No "striking results," "very significant" coefficients, "interesting findings." Cochrane: "If the work merits adjectives, the world will give them to you."
- **Only write what is actually in the code and results**. Before drafting, read the code files in `tracks/<track>/code/` (and shared `code/common.R` at the project root), the output files in `tracks/<track>/latex/tables/` and `tracks/<track>/latex/figures/`, and `tracks/<track>/latex/tables_figures.tex` (the inventory of floats actually inserted into the paper, with their `\label{}`s). Do not claim a robustness check, alternative specification, placebo test, or mechanism test was run unless there is a corresponding script and output file. Never write sentences like "results are robust to alternative specifications" or "we also find consistent results using X" if that analysis does not exist in the code.
- **Assume a sophisticated reader**. Do not explain what a fixed effect is, what a DiD does in general terms, or how OLS works. Explain *your* specification choices and why they are appropriate for *your* setting.
- **Reader-objective-first, not code-cataloguing.** Empirical-substrate sections (Data, Sample, Measurement, Identification) must open with the empirical objective the section is serving and what the data needs to deliver to answer it; subsequent paragraphs walk the reader through construction in the order that builds toward that objective, not the order the code runs. Each construction step's purpose is justified by what it contributes to the empirical question. Do not structure prose as a list of variables, sources, or pipeline outputs. Open paragraphs with the measurement target ("To measure a bank's local cost-side advantage, we need..."), then describe the construction that hits the target --- never with "Variable X is defined as the ratio of A to B from source C."
- **Skip trivial mechanics knowledgeable readers know.** Omit standard data-construction machinery that finance journal audiences already know: HUD ZIP--county / tract--ZIP allocation crosswalks; HMDA respondent-ID-to-RSSDID linkage via the Avery crosswalk (and LEI--RSSDID post-2018); efficiency-ratio definitions; CRA small-business loan size cutoffs; ACS / IRS forward-fill or back-fill mechanics outside the analysis window; specific Call Report RIAD line numbers unless the line choice is itself the methodological point. Mechanics that are non-obvious or non-standard --- self-exclusion of the focal bank from an incumbent benchmark, sample-period restrictions driven by identifier resets, cycle-period assignment for an imputed panel --- DO need explanation because the reader cannot guess them. If a mechanism is needed for replicability but is too long for the body, banish it to an appendix or a footnote.

### Paragraph and Sentence Construction
- **Lead with the claim, then supply the evidence**. Topic sentences state the finding or argument; supporting sentences provide the mechanism, coefficient, or citation.
- **Vary sentence length** but favor crisp, declarative sentences for key results. Reserve longer sentences for nuanced qualifications or mechanism discussions.
- **One idea per paragraph**. If a paragraph covers two distinct points, split it.
- **Transitions between paragraphs should be logical, not mechanical**. Mechanical connectors ("Next, we...", "Additionally,...", "Moreover,...") are acceptable sparingly but should not become a crutch—vary them with transitions that emerge naturally from the argument: "The cross-sectional variation in deposit responses suggests a role for information acquisition costs. To test this channel, we exploit..."
- **Do not use paragraph titles or `\paragraph{}` headings.** No bold lead-in labels (`**Main results.**`), no LaTeX `\paragraph{Foo.}` macro, no `\textbf{Foo.}` lead-ins, no `\noindent\textbf{...}` fake headings. Paragraphs must flow from their topic sentences. The topic sentence itself carries the work that a paragraph label would have done.
- **Prefer continuous prose over subsection proliferation.** A section is paragraphs flowing into paragraphs, not a stack of headings. Default to **zero or one** `\subsection{}` per section. Add a `\subsection{}` only when the section spans a genuinely separate content block that a reader will navigate to independently (e.g., a long results section that cleanly splits into "Main Results" and "Heterogeneity"). Do not subsection a topic just because it is a distinct variable, source, or step --- those belong inside the prose, with the topic sentence doing the framing. If you find yourself writing three or more `\subsection{}` calls in the same section, collapse them.
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

#### Data (two subsections in one file)
- **The data section always emits two subsections into `data_current.tex`**, in this order: `\subsection{Data Sources and Sample Construction}\label{sec:data:sources}` followed by `\subsection{Descriptive Statistics}\label{sec:data:desc}`. Both subsections live in the same `data_current.tex` file --- they are *not* separate section files. Do not split into two files. Do not collapse into one untitled block. The two subsections are the only `\subsection{}` calls permitted in the data section; the "default zero-or-one subsection" rule is overridden here because the two-subsection structure is part of the section's job description.
- **Subsection 1 (`Data Sources and Sample Construction`)** describes the panel, sample, variable construction, and ZIP-level controls --- no distributional content. All rules below tagged "Sources/Construction" apply here.
- **Subsection 2 (`Descriptive Statistics`)** owns all distributional content: sample means, SDs, frequencies of binary indicators, cross-bucket / cross-period heterogeneity, the summary-statistics table reference (`\ref{tab:descriptive_stats}` or the relevant label in the results section). It builds intuition before the formal tests. All rules below tagged "Desc" apply here.
- **Free-text instructions are split on `||`** as documented in the trigger block. Text before the first `||` guides subsection 1; text after it guides subsection 2. If only one instruction string is passed, it applies to both.

##### Subsection 1: Data Sources and Sample Construction
- **Open with the empirical objective and what the data must deliver.** First paragraph states the question the section is serving and enumerates the pieces of measurement the question requires (e.g., "a clean count of de novo openings, a candidate-market set in which non-entry carries information, bank--market proxies for the three hypothesized channels, controls absorbing demand variation"). Subsequent paragraphs build each piece in the order that serves the objective.
- **Lead the panel paragraph with the sample, not the data sources.** "We build the panel at the bank--ZIP--year level over 20XX--20XX..." before naming the sources. Sample-period stated should be the analysis-usable window (e.g., 2012 onward when controls require $t-3$ lags), not the raw panel range.
- **Channel paragraphs open with the channel's hypothesis and measurement target**, not with the variable name or formula. E.g., "The first channel is local deposit contestability. The branch-closure literature reads contestability as a force that drives banks out of rate-sensitive markets, so a test on the entry margin requires a measure that varies across the bank--ZIP cells where entry decisions are made." Then construct the variable to hit that target.
- **Sample filters and their rationale, in order of application.** Each filter should carry a one-clause why. Exclusions readers cannot guess (identifier resets, regulatory transitions, M&A vintage cutoffs) DO get explained; size-threshold and other obvious filters get a brief why.
- **Do not include distributional content.** No sample means, no SDs, no frequencies of binary indicators, no references to the summary-statistics table, no commentary on cross-bucket or within-period heterogeneity. All of that lives in the descriptive-statistics section. The data section's only quantitative facts are structural sample-size statements (total N bank-period observations, sample years, number of size buckets).
- **Skip standard data machinery.** No HUD crosswalk names, no Avery / LEI--RSSDID linkage sentences, no efficiency-ratio formulas, no CRA loan-size cutoffs, no ACS / IRS forward-fill mechanics outside the analysis window, no RIAD line numbers unless the choice of line is itself the contribution. Source names + variable names suffice; finance readers can fill in the standard recipe.
- **References to figures and tables go through `\ref` against labels owned by `tables_figures.tex`.** Do not inline `\begin{figure}` or `\begin{table}` blocks in the data section. If the data section references a map of opportunity sets, a stacked-area of openings, or a summary-stats table, the float is hosted in `tables_figures.tex` and the data section only cites the label.
- **Variable definitions still go in an appendix.** The Sources/Construction subsection narrates *what each variable is meant to measure and why the construction hits that target*; the full one-line dictionary of every variable (with Call Report mnemonics, etc.) belongs in an appendix table, not embedded in the body.
- **Length (Subsection 1)**: 2--3 pages. With mechanics moved to appendices and distributional content moved to subsection 2, this block is tighter than the old "Data" section used to be.

##### Subsection 2: Descriptive Statistics
- **Owns all distributional content.** Sample means, standard deviations, frequencies of binary indicators, summary-stats table reference, cross-bucket / cross-period heterogeneity, distributional commentary --- everything subsection 1 deliberately omits.
- **Build intuition before formal tests.** Show the reader the patterns in the data that the regressions will formalize. Lead with the patterns that motivate the design choices in the results section (e.g., "the opening rate is concentrated in the largest size bucket and rises with deposit-beta-weighted contestability, foreshadowing the channel results in Section..."), not with a variable-by-variable recital.
- **Use figures aggressively** when the descriptive pattern is more legible in a picture than in a table (time-series of treatment vs. control, density plots, opening-rate-by-bucket bars). Floats live in `tables_figures.tex` per the float-ownership rule; this subsection references them by `\ref`.
- **Reference the summary-statistics table once**, describe its content (panels, sample period, variables shown), and highlight only variables whose distribution is non-obvious or differs from priors. Do not recite every number.
- **Foreshadow the formal analysis without preempting it.** "These patterns motivate the size-stratified interactions in Section~\ref{sec:results}." Do not preview coefficients or significance.
- **Length (Subsection 2)**: 1--2 pages.


#### Empirical Strategy / Identification
- **Lead with the estimating equation**. Display it in a numbered equation environment, then explain each component.
- **State the identifying assumption** in plain English and then formally. What must be true for the coefficient of interest to have a causal interpretation?
- **Discuss threats to identification** proactively: pre-trends, confounders, selection, SUTVA violations. For each, explain the test or argument that addresses it.
- **Staggered DiD considerations**: If using a staggered design, discuss whether you use TWFE or a robust estimator (Sun & Abraham, Callaway & Sant'Anna, etc.) and why.
- **Standard errors**: State the clustering level and justify it (Abadie et al., 2023 or Cameron & Miller, 2015 reasoning).
- **Length**: 3–5 pages.

#### Empirical Results
- **Purpose**: interpret and discuss the empirical findings. The results section is **prose only** — no `\begin{table}`, no `\begin{figure}`, no `\input{tables/...}`. All floats live in `tables_figures.tex` after the bibliography; this section refers to them via `\ref{tab:...}` and `\ref{fig:...}`.
- **Organize by hypothesis or question**, not by table number. Use subsections sparingly (default zero or one).
- **Main results first**, then robustness, then heterogeneity / mechanisms (or break heterogeneity and robustness out into their own section files when they earn their own headings).
- **For each specification**: state what it tests, point to the relevant column of the referenced table, report the key coefficient with its economic magnitude, and interpret. Then note robustness across columns (additional controls, alternative samples, different FE structures).
- **Robustness section**: brief and systematic. A paragraph per robustness check is sufficient. Can reference an appendix table by `\ref`.
- **Mechanism / heterogeneity tests**: frame as "If the effect operates through channel X, we expect the coefficient to be larger for subgroup A than subgroup B." Then point to the split or interaction result by `\ref`.
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

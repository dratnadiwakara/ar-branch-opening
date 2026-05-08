---
name: academic-table-figure-notes
description: >
  Generate or improve detailed descriptions that appear above or below tables and figures in academic finance papers
  targeting top journals (Journal of Finance, Review of Financial Studies, Journal of Financial Economics, etc.).
  Only invoked via the /skills/table-figure-descriptions slash command. Do NOT trigger based on intent
  inference or keywords.
---

# Academic Table & Figure Notes Skill

This skill produces prose descriptions that appear directly above (or below, per journal convention) tables
and figures in academic finance papers. The goal is to give a reader enough information to understand exactly
what a table or figure shows — sample, variables, specification, estimation method, and any relevant caveats
— **without interpreting or editorializing about the results themselves**.

---

## Style Guide (Journal of Finance Standard)

### What a good note must include

For **tables**:
1. **What the table shows** — the dependent variable, the unit of observation, the regression/test being run.
2. **Sample** — the time period and any key sample restrictions (e.g., "main sample of listings", "IV sample restricted to observations where the initial purchase is observed"). Data sources and CPI-adjustment or construction details generally **do not** belong in the note unless they are essential to understanding the exhibit.
3. **Specification context** — briefly describe the estimation setup when it is not obvious from the column headings (e.g., "baseline linear probability model from Equation (5a)"). Do **not** enumerate the full list of controls and fixed effects in the note unless a particular control or fixed effect is itself the focus of the table; it is sufficient to refer to the "baseline specification" or a numbered equation in the text.
4. **Estimation method** — OLS, IV, probit, etc. If IV, state what the instrument is and where IV details are discussed (e.g., "Details of the IV estimation are discussed in Section 4").
5. **Standard errors** — how they are clustered or computed.
6. **Significance stars** — always include the standard line: `*, **, and *** denote statistical significance at the 10%, 5%, and 1% level, respectively.`
7. **Variable construction** — if a key variable is non-obvious (e.g., `log(1 + experience)`), define it in the note.

For **figures**:
1. **What is plotted** — the outcome on each axis or panel, units, and what each line/bar/color represents.
2. **Sample and time period** — same as tables.
3. **Empirical construction** — describe what regression or aggregation underlies the figure (e.g., "We regress the outcome on housing controls, zipcode-list-year-month fixed effects, and listing agent experience interacted with each calendar year").
4. **Counterfactual or predicted values** — if the figure involves a counterfactual, describe it clearly (e.g., "We then predict sale probability for a counterfactual where all agents are in the top experience tercile").
5. **Line/color legend** — describe each line or element (e.g., "The empirical time series is plotted in the orange dashed line. The blue solid line plots the average counterfactual outcome using the predicted values").
6. **Reference to paper section** — point the reader to where the exercise is discussed (e.g., "discussed in Section 4.6").

### What a note must NOT do
- **Do not interpret results** — do not say "consistent with", "we find", "the results show", or draw any conclusions.
- **Do not be redundant with the title** — the title (e.g., "Table 3: Effect of Agent Experience on Foreclosure") states what the table is; the note provides operational detail.
- **Do not omit variable definitions** — any transformed variable (logs, indicators, interactions) must be defined.
- **Do not use vague language** — "appropriate controls" or "standard fixed effects" are not acceptable when the specification itself is the focus; in such cases, clearly describe how the specification differs from the baseline rather than listing every control.

### Numerical formatting (Cochrane 2005 §2 — Tables)
- **Significant digits**: 2–3 sig figs, not whatever the program prints. `4.56783 (0.6789)` becomes `4.6 (0.7)`. Flag any cell with > 3 sig figs and propose the rounded value in the suggested note or caption.
- **Sensible units**: prefer percentages, basis points, log points, thousands, or millions over raw decimals. Do not report `0.0000023` when `2.3` (with units) reads instantly. If the column is in raw units that produce extreme values, note the unit choice in the suggested caption and recommend a rescaling.
- **Regression-equation in caption**: for regression tables, the caption (or the note) must include the regression equation or an explicit `\eqref{}` to it, plus the name of the left-hand-side variable. Flag captions that name only the table topic (e.g. "Main results") without identifying the LHS variable or the equation.

### Tone and length
- Write in third-person, present tense, declarative sentences.
- Notes are typically 3–8 sentences. Complex tables with multiple panels or many columns may run longer.
- Each panel in a multi-panel table/figure should be described separately if the content differs.
- Do not use bullet points. Notes are flowing prose.

---

## Workflow

### Step 1 — Ingest inputs

**`$ARGUMENTS`**: `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. The skill resolves the default file to `tracks/<track-name>/latex/main.tex`, with tables under `tracks/<track-name>/latex/tables/` and figures under `tracks/<track-name>/latex/figures/`.

The user will provide one of:
- **Single `.tex` file** containing both the paper body and table/figure environments. **Default: `tracks/<track>/latex/main.tex`** — if no file is specified, use that default and figure out what the body and table/figure environments are.
- **Two `.tex` files**: a paper file and a separate tables/figures file. The tables file is `\input{}`-ed or `\include{}`-ed into the paper. Read both.
- Supplementary **code files** in `tracks/<track>/code/sample-construction/` and `tracks/<track>/code/result-generation/` (plus shared `code/common.R` at the project root). Read these when available — they are the ground truth for variable construction, sample filters, and estimation details.

Use `bash_tool` or `view` to read all relevant files. Do not rely on memory alone.

### Step 2 — Inventory all tables and figures

Parse the LaTeX to find every `\begin{table}`, `\begin{figure}`, `\begin{table*}`, `\begin{figure*}` environment. For each, record:
- The label (`\label{}`)
- The caption (`\caption{}`) or title
- The column headers and row labels (for tables)
- Any existing note text (usually in a `\begin{tablenotes}`, `\footnotesize`, `\small`, or similar environment below the tabular body, or in a `\note{}` command)
- The surrounding text that references the table/figure (find the `\ref{}` calls and read the paragraph context)

### Step 3 — Consult code files

For each table/figure, check `tracks/<track>/code/result-generation/` for the script that produces it. Also check `tracks/<track>/code/sample-construction/` for sample definition and variable construction (and the shared `code/common.R` for project-wide helpers). Extract:
- Exact variable names and how they are constructed
- Sample restrictions (merge conditions, date filters, observation requirements)
- Regression specifications (controls, fixed effects, clustering)
- Estimation commands (e.g., `ivreg2`, `feols`, `reghdfe`)

### Step 4 — Draft notes and evaluate captions

For each table and figure, first **assess the existing caption** for clarity and informativeness. Check whether it states what the exhibit is about, distinguishes key dimensions (e.g., sample, period, main variables), and is not overly long or interpretive. When the caption is vague, redundant with the text, or omits crucial information (e.g., "Closures" instead of "Closures by Regime and Bank Size"), propose a concise **alternative caption** that would better serve a top‑journal reader.

Then write one paragraph of descriptive text for each table and figure following the style guide above. Do not prepend the word "Note:"; the text should start directly with the descriptive sentence. Order notes in the same sequence the tables/figures appear in the paper. All suggested captions and notes should be provided as **LaTeX-ready code snippets** (e.g., `\caption{...}` or `\footnotesize ...` blocks) that can be copied and pasted directly into the `.tex` file without additional editing.

If **existing notes are present**, evaluate them against the checklist:
- Are all panels described?
- Are all columns' differences explained?
- Is variable construction defined?
- Is the sample described with restrictions?
- Are fixed effects and controls enumerated?
- Is the estimation method stated?
- Are standard errors described?
- Is the significance-star line present?

Only suggest improvements when something is **missing, ambiguous, or incorrect**. Do not rephrase for style alone. When suggesting improvements, quote the original text and explain specifically what is lacking.

### Step 5 — Output

Produce a single Markdown file under `.claude/cc/table-figure-descriptions/` (create the folder if it does not exist), for example `.claude/cc/table-figure-descriptions/table-figure-notes_<track>_YYYYMMDD.md`, with the following structure:

```
# Table and Figure Notes

## Table 1: [Title]

**Existing caption** (if any):
> [Paste existing caption verbatim]

**Suggested caption** (only if improvements are warranted):
```latex
\caption{[Short, improved caption text]}
```

**Existing note** (if any):
> [Paste existing note verbatim]

**Assessment**: [One sentence: "Existing note is complete and accurate." OR "Existing note is missing X, Y, Z."]

**Rating**: [Star rating from 1 to 5 stars using Unicode stars]

**Suggested note** (only if improvements are warranted):
```latex
[Full revised descriptive text, formatted as LaTeX and without a leading "Note:" prefix]
```

---

## Table 2: [Title]
...

## Figure 1: [Title]
...
```

If there is no existing caption, omit the "Existing caption" block and provide only a "**Suggested caption**" entry. If there is no existing note, omit the "Existing note" and "Assessment" sections and provide only the drafted note under a "**Suggested note:**" heading. All suggested notes should be plain descriptive paragraphs without a leading "Note:" label.

---

## Quality Checklist (run mentally before finalizing each note)

- [ ] Sample is defined (source, period, restrictions)
- [ ] All panels described if multi-panel
- [ ] Column differences explained (e.g., "Columns 3–5 add controls for house characteristics")
- [ ] Key variables defined (especially transformations like logs, indicators, interactions)
- [ ] Estimation method or specification context stated (e.g., "baseline linear probability model from Equation (5a)")
- [ ] If IV: instrument described, and section reference given
- [ ] Standard error clustering stated
- [ ] Significance stars line present (tables only)
- [ ] No result interpretation
- [ ] No vague language ("appropriate", "standard", "various")
- [ ] Figure lines/colors described with their corresponding series
- [ ] Counterfactual construction described (figures only, if applicable)

---

## Examples

### Example 1 — Table Note (IV regression with multiple panels)

> This table reports estimates of the effect of listing agent's experience (using the log(1 + experience)) on a listings' probability of foreclosure in the next two years. All columns include zipcode-by-listing-year-month fixed effects, and Columns 3–5 add controls for house characteristics. Panel A reports results using the main sample of listings. Panel B uses the IV sample of listings, restricted to observations where we observe the initial purchase of the listing. Column 4 shows results from the IV estimation while Column 5 repeats the specification in Column 3 using the IV sample. Details of the IV estimation are discussed in Section 4. Standard errors are clustered at the MLS level. *, **, and *** denote statistical significance at the 10%, 5%, and 1% level, respectively.

### Example 2 — Figure Note (counterfactual exercise)

> This figure plots the results of the naive counterfactual discussed in Section 4.6. In Panel A, we consider the probability of sale in 365 days as the outcome. In Panel B, we consider the probability of a listing subsequently going into foreclosure in the next two years. In each panel, the empirical time series is plotted in the orange dashed line. We then regress the outcome on housing controls, zipcode-list-year-month fixed effects, as well as listing agent experience agent interacted with each calendar year. Using the coefficients of this regression, we then predict sale probability for a counterfactual where all agents are in the top experience tercile. The blue solid line plots the average counterfactual outcome using the predicted values.

---

## Common Mistakes to Avoid

| Mistake | Fix |
|---|---|
| "We use the standard set of controls" | List the controls explicitly |
| "consistent with our hypothesis" | Remove — this is result interpretation |
| Omitting which columns use IV vs OLS | State it explicitly per column or column range |
| Defining significance stars only in Table 1 | Include in every table note |
| Not describing what the dashed vs solid line is | Describe each line/color/marker |
| Note says "log experience" without defining it | Write "log(1 + experience)" and explain units if needed |
| Multi-panel table with one generic note | Describe each panel's sample or specification separately |

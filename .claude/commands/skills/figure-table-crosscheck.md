---
name: paper-table-consistency-check
description: >
  Audit an academic finance paper for consistency between in-text numerical claims and the corresponding
  table values. Only invoked via the /skills/figure-table-crosscheck slash command. Do NOT trigger
  based on intent inference or keywords. Input is a single .tex file, or a paper .tex file plus a
  separate tables .tex file (the latter is \input{}-ed into the former).
---

# Paper–Table Consistency Check Skill

This skill audits every quantitative claim made in the body of a paper against the table or figure
environment it refers to. It produces a Markdown report with one row per claim, a pass/fail verdict,
and a detail section for every discrepancy found.

---

## What counts as a claim to check

Scan the paper body (excluding abstract, notes, and appendix unless instructed otherwise) for any
sentence that:

1. **Cites a specific number** — coefficients, standard errors, t-stats, p-values, percentages,
   means, medians, counts (e.g. "a coefficient of 0.032", "increases by 14%", "the mean is 0.45").
2. **States significance** — "significant at the 1% level", "statistically significant", "p < 0.05",
   "***, **, or * in Table X".
3. **States a sign or direction** — "positively associated", "negative and significant", "the effect
   is larger for subgroup A than B".
4. **References a table or figure by label** — any `\ref{tab:...}` or `\ref{fig:...}` anchor near
   a quantitative claim is a strong signal that the sentence should be checked.

Do **not** check:
- Sentences that make no quantitative claim (e.g. "as shown in Table 3, the pattern is clear").
- Claims sourced from prior literature with explicit citations (e.g. "(Smith et al., 2020)").
- Descriptions of data construction or variable definitions that don't assert a result.

---

## Inputs

- **`$ARGUMENTS`**: `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. The skill resolves the default paper file to `tracks/<track-name>/latex/main.tex` and looks for tables/figures under `tracks/<track-name>/latex/tables/` and `tracks/<track-name>/latex/figures/`. The user may instead pass an explicit paper `.tex` path (and optionally a separate tables `.tex` path) to override the default.

## Workflow

### Step 1 — Ingest files

Read all provided `.tex` files using `view` or `bash_tool`. **If no file is specified, default to `tracks/<track>/latex/main.tex`.** If a separate tables file is provided, read it in addition to the paper body. Resolve `\input{}` and `\include{}` references if possible.

Build two internal structures:
- **Claims list**: every in-text quantitative claim with its surrounding sentence, the table/figure
  label it references, and the column/row the claim appears to refer to.
- **Table index**: for each table, a parsed representation of its cells — column headers, row labels,
  and cell values (coefficients, standard errors, stars).

### Step 2 — Parse tables

For each `\begin{tabular}` (or `\begin{tabularx}`, `\begin{tabulary}`, etc.) environment:

1. Identify the table label from the enclosing `\begin{table}` environment.
2. Parse column headers from the first row(s).
3. Parse row labels from the leftmost column.
4. Extract cell values. For regression tables, a cell typically contains:
   - A coefficient (a number, possibly with a sign)
   - Stars (*, **, ***) on the coefficient line
   - A standard error or t-statistic in parentheses on the next line
5. Note: LaTeX numeric formatting varies — strip `\num{}`, `\numprint{}`, math-mode `$...$`,
   and similar wrappers before comparing.
6. Record the significance level implied by the stars:
   - `***` → significant at 1%
   - `**`  → significant at 5%
   - `*`   → significant at 10%
   - no stars → not significant at conventional levels

### Step 3 — Match claims to table cells

For each claim:

1. Identify the referenced table/figure label (from `\ref{}` in the same sentence or the surrounding
   paragraph).
2. Identify the column and row the claim refers to. Use contextual cues:
   - Column number or header mentioned in text ("Column 3", "the IV specification")
   - Row label mentioned in text ("the coefficient on log experience")
   - If ambiguous, flag as **AMBIGUOUS** and note which cells are candidate matches.
3. Extract the claimed value(s) from the sentence.
4. Extract the actual value(s) from the matched table cell.

### Step 4 — Compare

Apply these comparison rules:

| Claim type | Pass condition |
|---|---|
| Exact number | Claimed value equals table value after rounding to the precision stated in text (e.g. text says "0.03", table has "0.032" → **PASS** if rounded to 2 decimal places; text says "0.04" → **FAIL**) |
| Percentage form | Check whether the text is expressing a coefficient as a percentage of a unit (e.g. table has 0.032 and text says "3.2 percentage points") — flag if conversion seems inconsistent |
| Sign | Claimed sign (positive/negative) matches the sign of the table coefficient → **PASS**; mismatch → **FAIL** |
| Significance level | Stars in table imply the level claimed in text → **PASS** (e.g. text: "significant at 5%", table: ** → PASS; text: "significant at 1%", table: ** → FAIL) |
| Direction comparison | "Larger for group A than B" — compare the two referenced cells; if A > B → **PASS** |
| Qualitative only | "Positive and significant" without a number — check sign and that at least one star is present |

**Rounding tolerance**: treat a claim as matching if the difference is due to rounding to the number
of decimal places stated in the text. Do not require exact floating-point equality.

**Unit mismatch**: if a claim appears to express a coefficient in different units (e.g., multiplied
by 100, expressed as basis points), flag as **UNIT CHECK** — note the apparent conversion and whether
it is consistent, but do not auto-fail.

### Step 5 — Write the report

Produce a Markdown report in the structure below and save it to:

`.claude/cc/figure-table-crosscheck/consistency_audit_report_<track>_YYYY-MM-DD.md`

using today's date in `YYYY-MM-DD` format and the track name passed via `$ARGUMENTS`. Ensure that the
`.claude/cc/figure-table-crosscheck/` directory exists, creating it if necessary.

---

## Output Format

```markdown
# Consistency Audit Report
**Paper**: [filename]
**Tables file**: [filename or "combined"]
**Date**: [today]
**Total claims checked**: N
**Passed**: N  |  **Failed**: N  |  **Ambiguous / needs review**: N

---

## Full Claims Table

| # | Section | In-text sentence (truncated) | Table | Row | Col | Claimed value | Table value | Verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | 4.1 | "...a coefficient of 0.032 (Table 3, Col 2)..." | tab:foreclosure | log(exp) | Col 2 OLS | 0.032** | 0.032** | ✅ PASS |
| 2 | 4.2 | "...significant at the 1% level (Table 3, Col 4)..." | tab:foreclosure | log(exp) | Col 4 IV | 0.028** | 0.028** | ❌ FAIL — text claims 1%, table shows 5% (two stars) |
| 3 | 5.1 | "...the effect is larger in Panel B..." | tab:het | β Panel B | Col 1 | larger | 0.041 vs 0.039 | ⚠️ AMBIGUOUS — Panel B coefficient (0.041) > Panel A (0.039) but difference is small; verify intent |

---

## Discrepancy Detail

### Claim #2 — FAIL
**Section**: 4.2
**Full sentence**: "The IV estimate remains significant at the 1% level (Column 4 of Table 3)."
**Referenced table**: Table 3 (`tab:foreclosure`), Column 4 (IV)
**Row**: Coefficient on log(1 + experience)
**Claimed**: significant at 1% (implying ***)
**Actual**: 0.028** (two stars → significant at 5%, not 1%)
**Action needed**: Either correct the text to "5% level" or verify the table stars are correct.

---

## Ambiguous Claims

### Claim #3 — AMBIGUOUS
**Section**: 5.1
**Full sentence**: "The effect is larger in Panel B, suggesting heterogeneity by market."
**Referenced table**: `tab:het`
**Issue**: "Larger" is confirmed numerically (0.041 > 0.039) but the difference is 0.002 and both
have wide standard errors. The claim is technically correct but may not be statistically meaningful.
No action required unless the claim implies statistical significance.

---

## Claims with No Discrepancy
[List claim numbers that passed, one per line, or "All remaining claims passed."]
```

---

## Handling Edge Cases

**Multiple tables referenced in one sentence**
Decompose into one claim per table reference and check each separately.

**Claim references a figure, not a table**
If the figure shows a time series or bar chart with no underlying cell values accessible in LaTeX,
flag as **FIGURE — cannot verify numerically** and note what the text claims. If the figure is
accompanied by a data table in the appendix, attempt to match there.

**Table cell contains a range or confidence interval**
Match accordingly — e.g., text says "95% CI of [0.01, 0.05]", table shows `[0.01, 0.05]` → PASS.

**Claim is in a footnote**
Include footnote claims in the audit. Mark the section as "fn" in the table.

**Coefficient reported in different units in text vs. table**
Flag as **UNIT CHECK**: state the implied conversion factor and whether it appears intentional
(e.g., table reports raw coefficient 0.032, text says "a 3.2 percentage point increase" — this is
a ×100 conversion, which should be flagged for the author to confirm is intentional).

**No `\ref{}` anchor near the claim**
If a quantitative claim has no explicit table reference, make a best-effort attempt to match it to
the most recently referenced table in the paragraph. If uncertain, flag as **NO ANCHOR — unverified**.

---

## Quality Checklist (before finalizing report)

- [ ] Every `\ref{tab:...}` or `\ref{fig:...}` in the body has been examined for adjacent quantitative claims
- [ ] Significance star levels are checked against the note at the bottom of each table
- [ ] Rounding is applied at the precision stated in text, not at full floating-point precision
- [ ] Unit mismatches (×100, basis points, log points) are flagged rather than auto-failed
- [ ] Multi-panel tables: claims are matched to the correct panel
- [ ] Abstract and prior-literature citations are excluded from the audit
- [ ] The summary counts (Total / Passed / Failed / Ambiguous) add up correctly

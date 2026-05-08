---
name: sanity-check
description: >
  Run a comprehensive sanity check on data used in empirical finance research.
  Only invoked via the /skills/sanity-check slash command. Do NOT trigger based on
  intent inference or keywords. Covers two modes: (1) checking data behind a specific
  regression in an R script, or (2) checking the output dataset of a data-construction
  script. Produces an R script and a Markdown report in .claude/cc/sanity-check/.
---

# Data Sanity Check for Empirical Finance Research

This skill performs rigorous data quality checks on datasets used in regressions targeting
top finance journals (JF, RFS, JFE, JFQA, MS). The goal is to catch silent data errors —
wrong merges, stale variables, dropped observations, miscoded values — before they
contaminate results.

**This skill is manually invoked only.** Do not run it unless the user explicitly asks.

---

## Inputs

- **`$ARGUMENTS`**: `<track-name>` (required) — the track folder name under `tracks/`, e.g. `did-april2026`. The skill resolves regression and data-construction scripts under `tracks/<track-name>/code/sample-construction/` and `tracks/<track-name>/code/result-generation/`. Shared `code/common.R` and the project-root `data/raw/` and `data/constructed/` paths remain unchanged.

---

## Step 1: Determine the Input Mode

Ask the user (if not obvious from context) which mode applies:

### Mode A — Regression Code Reference
The user points to a specific regression in an R script (e.g., a `felm()`, `feols()`,
`lm()`, or `fixest` call). Your job:

1. Read the R script the user references.
2. Identify the exact regression call (the user may specify a line number, variable name,
   or describe it).
3. Extract:
   - **Dependent variable**
   - **Independent variables** (including controls and fixed effects)
   - **Sample filters** — any `filter()`, `subset()`, `which()`, or inline conditions
     (e.g., `data[data$year >= 2000, ]`) that restrict the estimation sample.
   - **Clustering variables**
   - **The dataset object** used in that regression — identify where it is loaded from.
     If the dataset is saved as a file (`.rds`, `.csv`, `.dta`, `.fst`, `.parquet`,
     etc.), load it directly from that file and apply only the sample filters from
     the regression script (e.g., `filter(year >= 2000)`) to replicate the estimation
     sample. If the dataset is NOT saved to a file and only exists as an in-memory
     object constructed within the script, then trace back through the script to
     reconstruct it by re-running the necessary merges, transformations, and sourced
     scripts. Prefer the saved-file path whenever available — only reconstruct when
     there is no saved file to load.
4. The "key variables" for the sanity check are: the dependent variable, all regressors,
   fixed-effect variables, and cluster variables.

### Mode B — Data Construction Script
The user points to a script whose output is a dataset (e.g., it ends with
`write_csv()`, `saveRDS()`, `fwrite()`, `save()`, or assigns a final data frame).
Your job:

1. Read the script.
2. Identify the final output dataset.
3. All variables in that dataset are "key variables" for the sanity check.

---

## Step 2: Identify the Unit of Observation and Panel Structure

This is critical. Determine the unit of observation from context — common units in
finance research include:

- firm-year, firm-quarter, firm-month
- bank-year, bank-quarter, BHC-year
- county-year, state-year, zip code-year, MSA-year
- loan-level, loan-year, borrower-year
- fund-year, fund-quarter, fund-month
- country-year

**How to identify the unit:**
- Look at the ID and time variables (often the first columns, or used in `group_by`,
  fixed effects, or cluster terms).
- Check for `distinct()` or `duplicated()` calls that reveal the intended grain.
- If ambiguous, ask the user to confirm.

Once identified, record the entity identifier(s) (e.g., `permno`, `gvkey`, `rssdid`,
`zip`, `fundid`) and the time variable (e.g., `year`, `yearq`, `date`).

---

## Step 3: Generate the R Sanity-Check Script

Create an R script at `.claude/cc/sanity-check/sanity_check_<track>_<descriptor>.R` where
`<track>` is the track name passed via `$ARGUMENTS` and `<descriptor>` is a short label
derived from the regression or dataset name (e.g.,
`sanity_check_did-april2026_main_reg.R` or `sanity_check_did-april2026_loan_panel.R`).

The script should load the data (or reconstruct the exact estimation sample for Mode A)
and perform every check below. All output should be captured and written to a Markdown
report.

### 3.1 — Panel Completeness and Balance

```r
# Confirm the unit of observation
# Check: are there duplicates at the entity-time level?
dupes <- df %>% group_by(entity_id, time_var) %>% filter(n() > 1)

# Panel balance: observation count per time period
obs_by_time <- df %>% count(time_var) %>% arrange(time_var)

# Flag: any year with observation count dropping more than 20% vs the prior year
# or vs the panel median — these are red flags for merge errors or sample breaks.

# Entity continuity: for each entity, check for gaps in the time variable
# e.g., a firm present in 2005, 2006, 2008 (missing 2007) is a gap.
gaps <- df %>%
  group_by(entity_id) %>%
  arrange(time_var) %>%
  mutate(time_diff = time_var - lag(time_var)) %>%
  filter(time_diff > 1)  # adjust for quarterly/monthly data
```

Report:
- Total observations, unique entities, unique time periods.
- Whether the panel is balanced or unbalanced.
- A table of observation counts by time period, flagging drops > 20%.
- Count and examples of within-entity time gaps.

### 3.2 — Missing Values

```r
# Overall missingness by variable
miss_overall <- df %>%
  summarise(across(all_of(key_vars), ~sum(is.na(.x)))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
  mutate(pct_missing = n_missing / nrow(df) * 100)

# Missingness by time period for each key variable
miss_by_time <- df %>%
  group_by(time_var) %>%
  summarise(across(all_of(key_vars), ~mean(is.na(.x)) * 100)) %>%
  pivot_longer(-time_var, names_to = "variable", values_to = "pct_missing")
```

Report:
- Table of overall missingness per variable.
- Flag variables with > 5% missing overall.
- Flag variable-year combinations where missingness spikes (> 2× the variable's
  overall missing rate) — this often signals a data source changing coverage or a
  merge going wrong in specific years.

### 3.3 — Distributional Summary

For every key variable (numeric), compute:

| Stat | Description |
|------|-------------|
| N (non-missing) | count of valid observations |
| Mean | arithmetic mean |
| SD | standard deviation |
| Min | minimum |
| p1 | 1st percentile |
| p5 | 5th percentile |
| p10 | 10th percentile |
| p25 | 25th quartile |
| p50 | median |
| p75 | 75th quartile |
| p90 | 90th percentile |
| p95 | 95th percentile |
| p99 | 99th percentile |
| Max | maximum |

```r
percentiles <- c(0, 0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 1)
dist_table <- df %>%
  summarise(across(all_of(numeric_key_vars), list(
    N     = ~sum(!is.na(.x)),
    Mean  = ~mean(.x, na.rm = TRUE),
    SD    = ~sd(.x, na.rm = TRUE),
    Min   = ~min(.x, na.rm = TRUE),
    p1    = ~quantile(.x, 0.01, na.rm = TRUE),
    p5    = ~quantile(.x, 0.05, na.rm = TRUE),
    p10   = ~quantile(.x, 0.10, na.rm = TRUE),
    p25   = ~quantile(.x, 0.25, na.rm = TRUE),
    p50   = ~quantile(.x, 0.50, na.rm = TRUE),
    p75   = ~quantile(.x, 0.75, na.rm = TRUE),
    p90   = ~quantile(.x, 0.90, na.rm = TRUE),
    p95   = ~quantile(.x, 0.95, na.rm = TRUE),
    p99   = ~quantile(.x, 0.99, na.rm = TRUE),
    Max   = ~max(.x, na.rm = TRUE)
  )))
```

### 3.4 — Red Flag Detection (Domain Knowledge)

Apply judgment based on common finance variables. This is where the skill adds real
value beyond mechanical checks. Flag anything that looks off given standard knowledge:

**Common variable sanity bounds (examples — adapt to actual variables):**

- **Firm size (log assets / log market cap):** typically 2–14 in logs; values outside
  this range suggest coding errors or units mismatch (thousands vs millions).
- **Leverage (debt/assets):** should be in [0, 1] for most firms; negative values or
  values > 1 need justification (e.g., negative book equity).
- **ROA / ROE:** ROA usually in [-0.5, 0.5]; ROE more volatile but values beyond
  [-2, 2] are suspect outside of micro-caps.
- **Tobin's Q / Market-to-book:** typically [0, 20]; extreme outliers above 50–100
  usually indicate data errors or un-winsorized penny stocks.
- **Interest rates / spreads:** should be in basis points or percent — check which;
  values > 50% for loan spreads are suspect.
- **County/zip-level variables (population, income):** check units (thousands? raw?),
  and whether values are plausible for the US or relevant geography.
- **Indicator/dummy variables:** should be strictly 0/1; any other values are errors.
- **Year/date variables:** should fall within the stated sample period.
- **Winsorized variables:** if variable names suggest winsorization (e.g., `_w`,
  `_win`), confirm p1 = p1 and p99 = p99 (i.e., the tails are actually flat).
- **Log-transformed variables:** should have no non-positive pre-transform values
  sneaking through (check for -Inf or NaN).
- **Ratios:** denominators should not be zero or near-zero (which produces extreme
  values).

**Time-series consistency:**
- Compute the mean and SD of each key variable by time period. Flag any year where
  the variable's mean is > 3 SD away from its cross-time average — this often
  indicates a data vintage issue, a merge failure for that year, or a coding change
  in the source data.

**Cross-variable consistency:**
- If both `assets` and `log_assets` exist, verify the transformation is correct.
- If `leverage = debt / assets`, spot-check that the identity holds.
- If a variable is a first-difference or growth rate, verify it's consistent with
  the levels.

### 3.5 — Additional Checks

- **Constant or near-constant variables:** Flag any variable with SD ≈ 0 or where
  p1 = p99. These contribute nothing to regressions and may indicate a coding error.
- **Duplicate observations:** Beyond the panel-key duplicates in 3.1, check for
  exact duplicate rows across all columns.
- **Extreme outliers:** Flag observations where any variable exceeds 5× the
  interquartile range beyond Q1 or Q3. Report the count and percentage.
- **Sample size vs. expectations:** If the user's regression reports N, verify that
  the loaded and filtered sample matches.
- **Fixed-effect singletons:** If fixed effects are used, count and report
  singleton groups (only one observation) — these are dropped by `fixest`/`lfe`
  and can silently change the sample.

---

## Step 4: Generate the Markdown Report

Write the report to `.claude/cc/sanity-check/sanity_check_<track>_<descriptor>.md`.

Use this structure:

```markdown
# Sanity Check Report: [Descriptor]

**Date:** [auto-generated]
**Track:** `<track>`
**Script:** `.claude/cc/sanity-check/sanity_check_<track>_<descriptor>.R`
**Source:** [path to the R script or data file being checked, e.g. `tracks/<track>/code/result-generation/...R`]
**Mode:** [A: Regression | B: Data Construction]

## 1. Overview
- Dataset: [name/path]
- Unit of observation: [entity]-[time]
- Sample period: [start]–[end]
- Total observations: [N]
- Unique entities: [n_entities]
- Unique time periods: [n_periods]

## 2. Panel Structure
[Panel balance table, gap analysis, flags]

## 3. Missing Values
[Overall missingness table, time-varying missingness flags]

## 4. Distributional Summary
[Full percentile table for all key variables]

## 5. Red Flags and Warnings
[Numbered list of every concern identified, with severity: INFO / WARNING / ERROR]
- ERROR: issues that very likely indicate a data problem.
- WARNING: issues that could be problems or could be legitimate but deserve attention.
- INFO: observations worth noting for context.

## 6. Recommendations
[Concrete next steps: variables to winsorize, merges to audit, filters to add, etc.]
```

---

## Implementation Notes

- Use `tidyverse` and `data.table` as the primary libraries. Use `fixest` or `lfe`
  if needed to reconstruct estimation samples.
- The R script should be **self-contained**: it should load the data, run all checks,
  and write the .md report automatically when sourced.
- Use `cat()` or `writeLines()` to build the Markdown output, or use `knitr::kable()`
  for tables.
- If the project uses `here::here()` for paths, respect that convention.
- If the user's project has a specific package environment (e.g., `renv`), note any
  missing packages at the top of the script.
- The R script should print progress messages to the console so the user can see it
  running.
- Handle edge cases gracefully: if a variable is entirely NA, note it rather than
  crashing. If the dataset is very large (> 1M rows), mention that some checks may
  be slow.

---

## What This Skill Does NOT Do

- It does not run or interpret the regressions themselves.
- It does not fix data problems — it reports them.
- It does not validate causal identification or research design.
- It does not check code syntax or style.

The purpose is purely diagnostic: surface data issues so the researcher can
investigate and fix them before results go to a journal.

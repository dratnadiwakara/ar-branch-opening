# cross-section-may2026 — session notes

## 2026-05-11

### Status
**ABANDONED.** Track duplicates `tracks/first-draft-may2026/` with coarser instruments. Do not extend. Either archive to `tracks/.archived/` or fold any marginal novelty into first-draft.

### Done
- Built bank-cohort + opening/closure counts for banks with >=100 BRSERTYP=11 branches in SOD 2014 (n=80). Files:
  - `code/result-generation/01_bank_branch_changes_20260511.qmd` → `tab_bank_branch_changes.{tex,md}` + `fig_opening_share_churn.png`
  - `code/result-generation/02_high_low_open_share_20260511.qmd` → `tab_high_low_open_share.{tex,md}` (median-split t-test, 28 vars, only Premises/Assets sig at 5%)
  - `code/result-generation/03_open_share_regressions_20260511.qmd` → `tab_open_share_univariate.{tex,md}`, `tab_open_share_multivariate.{tex,md}` (z-scored RHS, OLS; Premises/Assets + log(Dep/Branch) survive multivariate, adj R^2 0.06-0.08)
  - `code/result-generation/04_bank_county_main_20260511.qmd` → `tab_bc_main.{tex,md}`, `tab_bc_heterogeneity.{tex,md}` (8450 bank-county Poisson, county HHI strongly negative, but all bank-char × HHI interactions null)
- Sample-construction:
  - `code/sample-construction/01_build_bank_dataset_20260511.R` → `data/cohort_2014_20260511.rds` (80 banks × 61 cols, Call Report 2014-Q4 + SOD geography)
  - `code/sample-construction/02_build_bank_county_panel_20260511.R` → `data/bank_county_2014_20260511.rds` (8450 bank-county cells, within-footprint at-risk set)
- LHS: `open_share_of_churn = openings / (openings + closures)`. Cohort median = 0.133 — most large banks heavy on closures.

### Dead ends
- **Whole track is the dead end.** first-draft-may2026 already has:
  - Bank-zip-year master panel (`master_bank_zip_year_*` 8+ parts) — finer unit than my bank-county.
  - Deposit beta at zip — sharper contestability than my county HHI.
  - bank-zip lending advantage, cross-sell index, CRA/mortgage beachheads — the bank-market match measures I flagged as missing.
  - `14_close_vs_open` already explored close-rate / open-rate axes on the ≥100-branch cohort and concluded close-rate is the discriminating axis. NOTES says "cross-section is quiet; within-bank tests carry the story."
- **NPL/loans via harmonized `npl_tot`**: returns 0 for large 031 filers (Wells, BofA, PNC, JPM). RC-N `RCFD1403`/`RCFD1407` are NULL on those filings (FFIEC stores 90+/nonaccrual by loan category, not the aggregate). Use llres + net-chargeoffs instead, or compute NPL from RC-N category-level codes manually.
- **SOD `STALP` field is institution-HQ state, NOT branch state.** All JPM branches show `STALP="OH"` in 2014. Derive branch state from `LPAD(STCNTYBR,5,'0')` first 2 chars, OR query `STALPBR` (not documented in current SOD README).
- **Median-split vs continuous LHS on bank-level chars**: both produce essentially the same null. 74-obs bank-level cross-section is power-starved; standard banking covariates explain 18-24% of open_share variance (adj R^2 6-8%).
- **Interaction story (bank edge × market contestability) does not show up with generic bank chars** (log_assets, ROA, Premises/Assets). All three HHI interactions p > 0.5 in bank-county Poisson. Real interaction story needs lending-match/cross-sell measures — which first-draft already has.

### Lessons
- **Always check sibling tracks before starting one.** This track was effectively a re-derivation of cohort + open/close counts already in first-draft. Read `tracks/*/NOTES.md` first.
- **Organic openings rule**: UNINUMBR first global appearance (across all SOD history) under bank's RSSDID, year > cohort year. Excludes M&A — M&A-acquired branches' UNINUMBRs already existed. OTS-adjustment (mirrors `branch_openings.py`): drop RSSDIDs with first new UNINUMBR in 2011 and zero new in 2004-2010 (510 such RSSDIDs in current SOD).
- **Organic closures rule**: UNINUMBR last global appearance under bank's RSSDID in [cohort_year, max_year). Branches sold to other banks DO NOT count — UNINUMBR continues elsewhere globally.
- **OLS vs Poisson divergence on bank-county count data**: 88% of bank-county cells have 0 openings. OLS on `openings/branches_2014` gets dragged by tails; Poisson with `log(branches_2014)` offset handles zero-mass correctly. County HHI flips sign (OLS ~null/positive → Poisson strongly negative).
- **fepois drops singletons when RSSDID FE + all-zero outcome**: 462-629 obs dropped under bank/state FE. Conditioning issue — typical for FE Poisson, document but don't ignore.
- **DuckDB harmonized `npl_tot` formula likely `COALESCE(RCFD1403,0) + COALESCE(RCFD1407,0)`**: silently returns 0 when RC-N aggregate codes are NULL (form 031 large banks). Prefer raw schedule_rcn category sums.
- **tidyverse not installed in R 4.5.3 here** — common.R does `library(tidyverse)` and fails. Load minimal: data.table + duckdb + DBI + here + knitr + stringr + ggplot2 individually. Skip `source(common.R)` for new scripts in this track.
- **knitr::purl(qmd) → source(.R)** is canonical way to run `type: source` qmd as plain R. Never `rmarkdown::render()`.

### Next
- **Do not extend.** If anything from this session is worth keeping, move it into first-draft-may2026:
  1. The OLS-vs-Poisson note on zero-heavy count LHS (already in first-draft's existing close/open analyses? verify).
  2. The County HHI Poisson result (sanity check; first-draft has it sharper via zip-level deposit beta).
- Archive options: `git mv tracks/cross-section-may2026 tracks/.archived/` once user confirms.

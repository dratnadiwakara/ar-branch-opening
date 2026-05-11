# first-draft-may2026 — session notes

## 2026-05-08

### Done
- Built `align_decimals()` helper in `code/result-generation/06_publishable_tables_20260508.qmd` to post-process etable tex output: strip outer `\begin{table}`, swap `{lccc...}` to siunitx `{lS[table-format=-1.4]...}`, brace-wrap `$^{***}$` stars, wrap non-numeric body+header cells in `\multicolumn{1}{c}{...}`.
- Added `\usepackage{siunitx}` + `\sisetup{detect-all, input-symbols={()*}, table-align-text-after=false, table-align-text-before=false, table-format=-1.4}` to `latex/main.tex`.
- Inserted `tab_deposit_beta_main` (single-table) and two multi-panel blocks (`tab:rate_paying_advantage` = additive + interaction; `tab:cross_sell` = additive + interaction) into `latex/sections/results/results_current.tex`.
- Compiled `latex/main.tex` to 5-page PDF at `latex/build/main.pdf`.

### Dead ends
- Direct `latexmk` re-run after a failure stays cached as failure: must `rm -f build/main.*` (or `-g`) before retry.
- Bash heredoc with R `-e '...'` segfaults on the `\` escapes in this regex-heavy script — write a temp `.R` file and `R --vanilla -f file.R` instead.

### Lessons
- siunitx `S[table-format=-1.D]` rejects: text headers, `Yes`/`No` cells, math macros (`\times`, `\frac`), thousands-separator commas, bare `$...$`. All must be wrapped in `\multicolumn{1}{c}{...}` per cell.
- Numeric-ish allow regex: `^[-+0-9.()*$^{}\s]+$` — **no comma, no backslash, no letters**.
- `&`-split in tabular rows must respect `\&` (escaped ampersand in note rows like `Clustered (Bank \& Zip)`): use `(?<!\\)&` perl regex, else footnote rows get shredded.
- Whole-row `\multicolumn{N}{l|c|r}{...}` banners (SE-note, sig-codes) must be skipped before splitting on `&`, else they get re-wrapped recursively.
- `fixest::etable(tex=TRUE, title=, label=)` emits `\caption{\label{tab:foo} Title}` — label nested inside caption, not standalone. Wrapper-strip regex must match this.
- etable titles round-trip mojibake: `â€"` for em dash. Clean to `---` before adopting source caption verbatim.
- MiKTeX may not auto-install `siunitx`: run `mpm --install=siunitx` if `! File 'siunitx.sty' not found.`
- Windows + `pdflatex -output-directory=build` + `bibtex build/main` can't find `main.bib` in parent dir (path-format bug); bibtex error is harmless when no `\cite{}` present (PDF still produced by pdflatex pass).
- `tables/*.tex` invariant: contain ONLY `\begin{tabular}...\end{tabular}`. Outer `\begin{table}`, `\caption`, `\label`, `\centering` belong to the section file's wrapper. Nested `\begin{table}` inside section's wrapper triggers `! Not in outer par mode.`
- `etable(..., file=...)` writes the wrapped form. Capture as string (`tex=TRUE` no `file=`), pipe through `align_decimals`, then `writeLines` — never use the `file=` arg.

### Next
- Re-source the qmd to regenerate all `tables/*.tex` from current `align_decimals` (current saved files were partly hand-stripped from older runs).
- Replace placeholder `[PAPER\_TITLE]`, `[AUTHOR]`, `[ABSTRACT]` in `latex/main.tex`.
- Wire `bibtex` once first `\cite{}` is added (or fix Windows path bug by symlinking `main.bib` into `build/`).
- Uncomment section `\input{}`s in `latex/main.tex` once those drafts exist.

## 2026-05-09

### Done
- Built cross-sectional descriptive analyses for the paper's setup section. Five new files in `code/result-generation/`:
  - `09_cross_section_openers_*.qmd` — opener intensity = bank-zip-year opening events / mean branch count, 2012-24. **Superseded by 10/11.** Output tables deleted.
  - `10_cross_section_new_branches_*.qmd` — vintage = share of 2024 branches with global UNINUMBR `first_yr >= 2015`. Cleaner. Output tables deleted (also superseded).
  - `11_cross_section_franchise_*.qmd` — broad franchise indicators (cost / fee / loan-book / capital / breadth / paper-canonical). Paper-ready `tab_franchise_paper_{big,mid,sml}.tex` with thematic subhead rows via `\multicolumn{7}{l}{\emph{Block name}}`. Bucket-aware branch floor via `min_branches_for(bucket)`: ge_100bn = 100, others = 5.
  - `12_seminar_figure_franchise_*.R` — single composite seminar PNG/PDF: forest plot (left, standardized mean diff w/ 95% CI) + bivariate scatter (right, loans/assets x non-int income / revenue, ggrepel bank labels). Uses `patchwork`. Sample = ge_100bn n=19.
  - `13_cross_section_franchise_100br_*.qmd` — universal >=100 branch floor in 2024. n=19/51/6 by bucket.
  - `14_close_vs_open_*.qmd` — sample = banks with >=100 branches in 2014 AND present 2024 (n=68). Three classifiers: close_rate, open_rate, net_change_rate. Closer axis discriminates more than opener axis: high closers in mid bucket are less efficient, lower ROA, thinner core funding, more wholesale-borrowed, under-reserved.
- Fixed master RSSDID type mismatch: `dt[, RSSDID := as.character(RSSDID)]` after `readRDS(master_*part*)` — master stores RSSDID as INTEGER, FFIEC bs_panel.idrssd / sod.duckdb are VARCHAR. data.table merge errors with "Incompatible join types" without coercion.
- Documented uninsured-deposit fraction bug in upstream `code/sample-construction/01_build_deposit_beta.R:172-202` (see Lessons). Fixed locally in 11/13/14 by re-querying RCONF049 / bs.deposits; **upstream untouched** because it would invalidate the deposit-beta first-stage regression sample currently feeding `tab_first_stage`, `tab_deposit_beta_main`, etc.
- Installed `ggrepel` + `patchwork` (one-time, needed `wininet` download method due to SSL error on default).

### Dead ends
- Headline cross-sectional finding "high-vintage big banks have a deep fee/cross-sell franchise" was **driven entirely by 4 wholesale outliers** (Goldman, BNY Mellon, HSBC USA, Northern Trust) with <100 branches each. Restricting to >=100 branches collapses the big-bucket story (no significant franchise differences). Conclusion: among true retail-style large banks, cross-section is quiet; the paper's headline within-bank tests carry the story.
- Initial seminar-figure narrative "less in loans, more in fees" no longer holds with >=100 branch restriction; updated title to "Cross-section of >=$100B retail-banking franchises by branch vintage".

### Lessons
- **Uninsured deposit fraction in `bank_year_dec_controls_*.rds` is buggy**: `01_build_deposit_beta.R:197-202` divides RCONF049 by `(RCONF049 + RCONF045)`, but **RCONF045 is listing-service deposits** (a small sub-component), not total insured deposits. Output is ~95% for almost every bank. **Correct formula: RCONF049 / bs.deposits** (total deposits) — yields plausible 14-65% range. Fix locally before using; do not rebuild upstream without a plan to refresh the entire deposit-beta first-stage paper output.
- **SOD UNINUMBR vintage**: a UNINUMBR's `first_yr` must be computed **globally** (across all SOD history), NOT within a window. Otherwise a branch existing pre-2015 but acquired by bank B in 2018 falsely looks "new" to bank B. See `08_descriptive_figures_*.R:96-127` for the canonical pattern.
- **Master RSSDID is INTEGER**, FFIEC bs_panel.idrssd is VARCHAR, sod.RSSDID is VARCHAR. Always `as.character()` master RSSDID immediately after `readRDS()`.
- **Wholesale outliers in big bucket**: Goldman Sachs Bank USA (5 branches in 2024), BNY Mellon (6), HSBC USA (21), Northern Trust (58), Charles Schwab Bank (custody-only). These dominate any descriptive analysis of large banks unless a branch-count floor (>=100) is applied.
- **Small-bucket t-tests with n<10 routinely return NA p-values** when within-group variance is degenerate. `build_panel` must guard with `is.na(pv)` before stars logic.
- `knitr::purl(qmd, output=tmp.R, quiet=TRUE)` then `source(tmp.R)` is the canonical way to run a `type: source` qmd as plain R. Per-CLAUDE.md never `rmarkdown::render()`.
- Bank-level branch HHI of zip distribution: built from SOD count per zip, not deposits per zip. Don't reuse `dep_b_zip` from master since master uses RSSDID-zip aggregates that are noisy at the very small zips.
- `ggrepel` + `patchwork` not pre-installed in this R 4.5.3 setup. SSL error on default download method; install with `options(download.file.method='wininet')`.
- Branch closures at bank level: anti-join `own_2014[!own_2024, on = .(RSSDID, UNINUMBR)]` — branches owned by bank B in 2014 that are no longer owned by B in 2024 (counted as closures regardless of whether the UNINUMBR continues at another bank). Different from "branch deletion" (would require checking UNINUMBR absence from any 2024 record).
- Closure rates in the >=100 branch sample are **high everywhere** — median 27-37% over 10 yrs. Opening rates much smaller (5-8%). Net = shrinking footprint for big and small banks.
- 2x2 typology (high/low close x high/low open) gives roughly even quartiles: ~25-30% pure closers, pure openers, quiet, high churn. Useful framing for paper.

### Next
- Decide whether to fix `01_build_deposit_beta.R` uninsured-deposits bug and refresh paper β tables, or note as caveat.
- Pick which cross-section to lead with in the paper's setup section: `13_*` (franchise, broad) or `14_*` (closer-vs-opener, sharper signal in mid bucket). Closer-vs-opener has cleaner story but requires reframing.
- Consider rebuilding `12_*` seminar figure on the n=68 sample with closer-vs-opener axes (e.g., scatter of close_rate x open_rate, color = ROA).
- Decide treatment of small-bucket (n=6-8) results — too thin for any robust comparison; either drop the panel or report as descriptive moments only.

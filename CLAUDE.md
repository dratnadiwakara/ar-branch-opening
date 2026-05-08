# Why Banks Open Branches in the Digital Era — Project Context

**Paper**: Why Banks Open Branches in the Digital Era
**Slug**: ar-branch-opening
**Description**: Empirical investigation of the determinants of bank branch entry decisions. Positions against the branch-closure literature (e.g., NRS 2026, which emphasizes deposit contestability driving exits) and asks the mirror question: conditional on branches still being opened at substantial volume, what makes a given bank choose a given market? The paper explores several non-contestability channels — lending comparative advantage, cross-sell opportunity, operating efficiency advantages — and how they interact with local market characteristics. The headline finding reframes branches in the digital era as **distribution platforms, not deposit-rent vehicles**: banks open branches in *more* contestable markets, not less, and do so precisely where an existing cost or lending franchise (operating efficiency, mortgage presence, CRA small-business presence) lets them monetize the customer relationship.
**Authorship**: coauthored

## Project Layout

A project is organized around one or more **tracks**. Each track is a self-contained analytical sub-project (its own code, data, and full LaTeX paper draft). The project root holds shared assets used across tracks.

```
data/raw/                     ← SHARED raw source data (never modified)
data/constructed/             ← SHARED constructed datasets used by multiple tracks
code/common.R                 ← SHARED libraries, paths, ggplot2 theme, fixest globals
tracks/                       ← container for analytical tracks
tracks/<descriptor>-<month-year>/         ← one self-contained track (e.g. tracks/did-april2026/)
tracks/<descriptor>-<month-year>/code/                       ← track-local code
tracks/<descriptor>-<month-year>/code/sample-construction/   ← .R scripts that build track samples
tracks/<descriptor>-<month-year>/code/result-generation/     ← .qmd analyses producing tables and figures
tracks/<descriptor>-<month-year>/code/archives/              ← old scripts (not sourced)
tracks/<descriptor>-<month-year>/data/                       ← track-specific intermediate datasets
tracks/<descriptor>-<month-year>/latex/main.tex              ← full paper draft for this track
tracks/<descriptor>-<month-year>/latex/main.bib              ← BibTeX references
tracks/<descriptor>-<month-year>/latex/sections/             ← section .tex files (\input{} from main.tex)
tracks/<descriptor>-<month-year>/latex/figures/              ← figures emitted by this track's scripts
tracks/<descriptor>-<month-year>/latex/tables/               ← tables emitted by this track's scripts
tracks/<descriptor>-<month-year>/latex/build/                ← pdflatex output (gitignored)
docs/_config.yml              ← Jekyll config for GitHub Pages
docs/index.md                 ← snapshot registry (GitHub Pages landing page)
docs/snapshots/               ← versioned result snapshots (one folder per run)
docs/slides/                  ← presentation files
docs/memos/                   ← revision plans, referee responses, todo
related-papers/               ← downloaded PDFs (gitignored)
correspondence/               ← agent-generated reports and reviews
scripts/                      ← new-project + new-track initialization scripts
```

**Create a new track:**

```
# from the ai-vault directory
.\scripts\new-track.ps1 -ProjectPath <project-path> -TrackName <descriptor>
# or:  ./scripts/new-track.sh <project-path> <descriptor>
```

The script appends the current month-year automatically, so `did` becomes `tracks/did-april2026/`.

## Paper-Specific Context

### Current Narrative

Branches have closed by the thousands over the past decade, and a growing literature ties these exits to high local deposit contestability. Yet large U.S. banks continue to open branches at substantial volume. This paper asks why.

The emerging story: branches in the digital era are not deposit-rent vehicles but distribution platforms. Banks enter rate-sensitive markets when an existing bank-level franchise — cost, lending, or relationship — lets them monetize the customer beyond the deposit margin. The entry margin is therefore not a clean mirror of the exit margin, and the action lies in the *interaction* between market contestability and bank-level edges rather than in either dimension alone. The result reconciles continued entry with the closure literature and reshapes how we read bank branch networks in a high-rate world.

### Research Question

Why do banks open branches in particular markets? The branch-closure literature (notably NRS 2026) argues that high deposit contestability drives incumbent exits. This paper studies the entry margin and asks what determines where entry happens. Deposit contestability is one candidate channel; additional candidates include:

- **Lending comparative advantage** — the bank's loan-portfolio specialization aligns with the market's industry mix, so incremental deposits fund informationally-advantaged loans.
- **Cross-sell opportunity** — the local customer base is amenable to multi-product relationships (wealth management, mortgage, consumer credit), converting a branch into a distribution channel for higher-lifetime-value accounts.
- **Operating / efficiency advantages** — local cost structure, existing footprint economies, or bank-specific scale benefits lower the effective cost of operating a branch in the market.

These channels are not mutually exclusive; the paper examines each and their interactions with market-level contestability.

### Identification Strategy

To be finalized. Likely combination of:

- Bank–market–year panel with bank-year and market-year fixed effects to absorb aggregate bank- and market-level shocks.
- Exogenous variation in the bank's lending specialization (e.g., merger-induced portfolio shifts, distant-market instruments) to address endogeneity of the match measure.
- Bartik-style shift-share variation in local industry composition where needed.
- Restricted "at-risk" choice set (e.g., candidate markets within a geographic or regulatory radius of the bank's existing footprint) to handle the rare-event nature of de novo entry.

### Outcome

De novo branch entry by bank `b` into market `ℓ` in year `t` (constructed from year-over-year changes in the FDIC Summary of Deposits, with care to exclude M&A-driven entries).

### Key Variables

- **Deposit contestability (β)** — local sensitivity of depositors to rate differentials, measured following the deposit-beta literature.
- **Industry match (m)** — bank-market dot product of the bank's loan-portfolio shares and local industry employment shares.
- **Cross-sell opportunity** — bank-market index of predicted multi-product-relationship potential, trained on existing-footprint markets and projected to candidate markets.
- **Efficiency / cost measures** — local operating cost shifters; bank-specific cost structure.
- **Market controls** — size, concentration, demographics, credit demand.

### Sample

- Unit of observation: bank × market × year (market = county or ZIP, to be decided).
- Time period: recent decades of branch banking, with emphasis on the digital era.
- Sample likely restricted to large banks (concentrated source of openings; also aligns with availability of Y-14M and granular Call Report data).

### Data Sources

- FDIC Summary of Deposits (SOD) — branch locations, deposits, opening/closing events.
- Bank Call Reports — loan portfolio composition, bank financials.
- QCEW / CBP — county- or ZIP-level industry employment and establishment shares.
- ACS / Census — local demographics.
- RateWatch or SOD-implied deposit rates — for contestability measurement.
- FR Y-14M credit card data — for cross-sell index construction on the large-bank subsample.
- Raw inputs live under `data/raw/`; many variables are pulled from DuckDB harmonized views maintained in the sibling `empirical-data-construction` repository.

---

## Tracks: Self-Contained Analytical Sub-Projects

A track is a complete, self-contained attempt at the paper: its own data prep, its own analyses, and its own LaTeX draft. Multiple tracks can coexist in `tracks/` and run in parallel — useful when comparing competing identification strategies (DiD vs. IV) or before settling on one main specification.

**Conventions:**

- Track folder name is `<descriptor>-<month-year>` where month-year is lowercase (e.g., `did-april2026`, `iv-shift-share-may2026`). The month-year suffix marks when the track was started and disambiguates re-attempts.
- Scripts inside follow the date-suffix convention: `01_desc_20260401.R`.
- Each track may add `code/common_<slug>.R` for track-specific settings that augment the shared `code/common.R` at project root.
- **A track owns its outputs end-to-end.** Tables and figures are written directly to `tracks/<name>/latex/tables/` and `tracks/<name>/latex/figures/` (no separate "exploration vs. final" stage — the track's `latex/` is the live paper draft).
- Shared data lives at `data/raw/` and `data/constructed/` (project root). Track-specific intermediates that are not useful elsewhere go to `tracks/<name>/data/`.
- When a track is abandoned, move it to `tracks/.archived/` rather than deleting.
- Skills that operate on a paper (snapshot, latex-compile, write-section, figure-inserter, cochrane-style-check, etc.) require the **track name as their first argument** so they target the right folder.

### Result Snapshots

Use `/skills/snapshot-results <track-name> [label]` to capture a track's tables and figures into a versioned report under `docs/snapshots/`. The skill reads from `tracks/<track-name>/latex/tables/` and `tracks/<track-name>/latex/figures/` and writes to `docs/snapshots/<date>-<track-name>-<label>/`.

```
docs/snapshots/
└── 20260409-did-april2026-baseline/
    ├── index.md        ← report with embedded figures and rendered tables
    ├── figures/        ← copies of tracks/did-april2026/latex/figures/*.png and *.pdf
    └── tables/         ← markdown-rendered versions of tracks/did-april2026/latex/tables/*.tex
```

**When to snapshot:** Only when the user explicitly requests it. Never snapshot automatically.

**Workflow:**

```
/skills/snapshot-results did-april2026 baseline
# → reads from tracks/did-april2026/latex/tables/ and tracks/did-april2026/latex/figures/
# → creates docs/snapshots/20260409-did-april2026-baseline/
# → updates docs/index.md registry
# → fill in the Summary section in index.md
```

---

## API Keys & Secrets

All API keys and credentials stored at `C:\key-variables\key-variables.yaml`. Read from there when any key is needed — do not ask user to provide keys manually.

---

## Runtime Paths

> **IMPORTANT:** Before running any R or Python command, verify these paths are filled in. If either is still a placeholder, stop and ask the user to provide the correct path before proceeding.

```
R_EXE           = "C:/Program Files/R/R-4.5.3/bin/R.exe"
PYTHON_VENV     = C:/envs/.basic_venv
PYTHON_VENV_DOCLING = C:/envs/.docling_venv
```

**Rules:**

- Always invoke R via `R_EXE` (e.g., `"$R_EXE" script.R`), never rely on `Rscript` or `R` being on PATH.
- Always activate the venv before running Python: source `$PYTHON_VENV/Scripts/activate` (Windows) or `$PYTHON_VENV/bin/activate` (Unix), then call `python`.
- **Exception:** When running `related-papers/convert_batch.py`, use `PYTHON_VENV_DOCLING` (`C:/envs/.docling_venv`) instead of `PYTHON_VENV`.
- If `R_EXE` is still `[PLACEHOLDER...]`, do **not** attempt to run the script — prompt the user: *"Please set `R_EXE` in CLAUDE.md before I can run this."*

---

## R Coding Standards

### Core Principles

- **Never render** `.qmd` or `.Rmd` files during script execution — run regressions and output tables/figures by sourcing `.R` scripts or running Quarto CLI explicitly.
- Place all `library()` calls at the very top of each script.
- Reset the environment with `rm(list = ls())` as the first line of every standalone script.
- Use **relative paths** exclusively. In Quarto/R Markdown documents, construct paths with `here::here()`. In plain `.R` scripts, use paths relative to the project root (e.g., `"data/raw/file.csv"`).
- Append date suffixes (`YYYYMMDD`) to new script filenames (e.g., `01_build_panel_20260406.R`).

### Project Organization

| Folder                                              | Contents                                                                                                                |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `code/common.R` (project root)                      | Shared libraries, paths, ggplot2 theme, fixest globals — sourced by all tracks                                          |
| `tracks/<name>/code/sample-construction/`           | Plain `.R` scripts that read from `data/raw/` and write to `data/constructed/` (shared) or `tracks/<name>/data/` (local) |
| `tracks/<name>/code/result-generation/`             | `.qmd` documents with `type: source` that produce this track's tables and figures                                       |
| `tracks/<name>/code/common_<slug>.R` (optional)     | Track-specific settings layered on top of the shared `code/common.R`                                                    |

### Data Management

- Raw data lives in `data/raw/` (project root) and is **never modified**. Shared across all tracks.
- Cross-track constructed datasets go to `data/constructed/` (project root).
- Track-specific intermediate datasets that are not reused elsewhere go to `tracks/<name>/data/`.
- Define a `data_path` constant near the top of each analysis script — typically `data_path <- here::here("data", "constructed")` for shared, or `here::here("tracks", "<name>", "data")` for track-local.
- Generate timestamped output filenames: `format(Sys.time(), "%Y%m%d_%H%M%S")`.
- Include a comment in each script indicating which upstream script generated any imported dataset.

### Data Lineage Comments

Every script that reads a prebuilt `.rds` / `.parquet` / `.csv` from `data/` or `data/constructed/` must include a lineage comment block **immediately above** the `readRDS()` / `load_latest()` / `fread()` call. Format:

```r
# Source: <path to file, with YYYYMMDD placeholder if glob-loaded>
# Built by:   <path to upstream build script>
# Contents:   <one- or two-line description of key columns / sample>
dt <- setDT(load_latest("data", "^zip_tech_sample_\\d{8}\\.rds$"))
```

Rules:

- Build-script path must be clickable in the IDE (use the repo-relative path, e.g. `tracks/<name>/code/sample-construction/B1_xxx.R`, or `code/sample-construction/...` only if the script genuinely lives at project root).
- If the file touches external (OneDrive, duckdb) sources, document those too — either inline above the path constant, or in a block above `source()`.
- When a single `00_common.R` is sourced by many scripts, the top of `00_common.R` should carry a full lineage map listing every consumed dataset and its upstream script.
- When refactoring a folder (e.g. moving build scripts to a new location), update every lineage comment that references the old path — the comments are load-bearing documentation, not decoration.

### External Data: `empirical-data-construction`

If any script consumes data produced by `C:\Users\dimut\OneDrive\github\empirical-data-construction`:

- **Read the `README.md` files carefully** (root README and the per-dataset README for the specific dataset) before writing code that loads the data. Column names, units, coverage, and caveats live there.
- **Do not load the `.parquet` files directly.** Query the **DuckDB harmonized views** instead — they apply the canonical joins, filters, and naming conventions.
- If a harmonized view does not exist for the needed dataset, stop and ask the user before falling back to parquet.

### Figure & Table Export

- Each track owns its outputs end-to-end. Write directly to the track's LaTeX folders:
  - Figures → `tracks/<name>/latex/figures/` as `.png` files with `bg = "white"` (and `.pdf` once finalized).
  - Tables → `tracks/<name>/latex/tables/`. During active iteration, write a `.md` companion alongside the `.tex` so the user can scan results in chat without compiling LaTeX.
- Never write outputs into another track's folder. If a result is genuinely shared (e.g., a descriptive table over the full sample used in multiple tracks), put it in the track that owns the prose and `\input{}` it from other tracks via a relative path.
- Control exports with logical flags at the top of each script:

  ```r
  save_figures <- TRUE
  save_tables  <- TRUE
  ```

### Regression Table Markdown Export

For regression tables emitted from a track's `code/result-generation/`, convert `etable()` output to a true pipe-delimited markdown table via `knitr::kable(format = "pipe")` and write it alongside the `.tex` file:

```r
# etable() with tex=FALSE returns a data.frame-like object.  Use a CHARACTER
# VECTOR for `headers` (one label per column) -- the list-form
# `headers = list("Early" = 1, ...)` encodes column-spans and produces stray
# 0/1 rows in the markdown output.
et <- etable(m1, m2, m3,
             headers = c("Early", "Mid", "Late"),
             tex     = FALSE)
df <- as.data.frame(et, stringsAsFactors = FALSE)
rownames(df) <- NULL
md <- knitr::kable(df, format = "pipe", row.names = FALSE)
writeLines(as.character(md), paste0(tables_path, "tab_name.md"))
```

- Pass column labels as a **character vector**, not a named list, to avoid span-encoded 1-rows in the output.
- For descriptive stat tables, use `knitr::kable(df, format = "pipe")`.
- Always emit the `.md` companion file in addition to the `.tex` so the user can read the table in chat without compiling LaTeX.
- Do not use `capture.output(print(et))` -- it produces space-aligned text that line-wraps when the terminal is narrow and breaks the table into chunks.

### Visualization Standards

Apply `theme_custom()` (defined in `code/common.R`) to all ggplot2 plots. Use these brand colors:

| Name           | Hex         |
| -------------- | ----------- |
| Primary blue   | `"#012169"` |
| Primary gold   | `"#f2a900"` |
| Accent gray    | `"#525252"` |
| Positive green | `"#15803d"` |
| Negative red   | `"#b91c1c"` |

### Econometric Modeling

- Use the `fixest` package for all panel regressions.
- Define formula macros with `setFixest_fml()` once per script (or in a shared common file). Use `..fc` for controls and `..fe` for fixed effects so formulas don't repeat the same control block and FE spec on every line:

  ```r
  setFixest_fml(
    ..fc = ~ log_assets_w + leverage_w + tangibility_w + netincome_assets_w,
    ..fe = ~ unit + year
  )
  feols(y ~ x * z + ..fc | ..fe, data = df, cluster = cl)
  ```
- Set global output options with `setFixest_etable()` once.
- Group a regression set's models in an unnamed `list()` — one block per table:

  ```r
  c_list <- list(
    feols(y1 ~ x * z1 + ..fc | ..fe, data = df,             cluster = cl),
    feols(y1 ~ x * z2 + ..fc | ..fe, data = df,             cluster = cl),
    feols(y2 ~ x * z1 + ..fc | ..fe, data = df[group == 1], cluster = cl)
  )
  etable(c_list, tex = FALSE, headers = headers)
  ```

#### Regression Style: Explicit, Not Programmatic

**Never generate regressions inside loops, `lapply`, `purrr::map`, or any other iteration construct.** Each regression must be written out explicitly so the user can highlight and run a single model without executing the entire script. Each `feols()` call should fit on one line via the `..fc` / `..fe` macros.

```r
# CORRECT — each model is a standalone, runnable line; controls/FE via macros
c_list <- list(
  feols(y ~ x1 * z + ..fc | ..fe, data = df,             cluster = cl),
  feols(y ~ x2 * z + ..fc | ..fe, data = df,             cluster = cl),
  feols(y ~ x1 * z + ..fc | ..fe, data = df[group == 1], cluster = cl)
)

# WRONG — hides individual models, cannot run one at a time
specs <- list(~x1, ~x1+x2, ~x1+x2+x3)
r <- lapply(specs, function(s) feols(as.formula(paste("y ~", s)), data = df))

# WRONG — repeats controls + FE on every line
m1 <- feols(y ~ x1 * z + log_assets_w + leverage_w + tangibility_w | unit + year, data = df, cluster = cl)
m2 <- feols(y ~ x2 * z + log_assets_w + leverage_w + tangibility_w | unit + year, data = df, cluster = cl)
```

This rule applies even when specifications differ only slightly. Repetition of the *spec* is intentional — it makes each model independently readable and executable. Repetition of *controls and FE* is not; collapse them into `..fc` and `..fe`.

### Winsorization

Winsorize sparingly and document the choice on a per-variable basis.

- **Default cutoffs are 1/99.** Use the 1st and 99th percentiles unless there is a specific reason to deviate (and ask the user before deviating).
- **Skip bounded variables by default.** Percentages, fractions, ratios with a natural [0, 1] (or [0, 100]) support, and other inherently bounded measures do not require winsorization. Apply it only if the distribution exhibits genuinely extreme values that visibly distort estimates — never as a routine pre-processing step.
- **Skip variables with a well-behaved distribution.** If the tails are not pathological (no isolated outliers many standard deviations from the mass, no obvious data-entry errors), leave the variable untouched.
- **Winsorize within period for panel data.** When the variable has meaningful time-series variation, compute the winsorization cutoffs within each period (year, quarter, cycle) rather than pooling across the panel. Pooled winsorization disproportionately clips periods with systematically high or low realizations (e.g., crisis years, rate-hike cycles) and induces spurious mean reversion across time.
- **Ask when in doubt.** If it is not obvious whether a given variable should be winsorized, or which cutoffs (1/99 vs. 5/95) and grouping (within period, within bank, full panel) apply, stop and ask the user before proceeding. Do not silently winsorize a newly added variable.
- **Document every winsorization site** with a one-line comment stating the cutoffs and the grouping (e.g., `# winsor 1/99 within YEAR`).

### Regression Table Footer Rows

Every regression table must include two footer rows below N: **Mean(DV)** and **SD(treatment)**.

- `Mean(DV)`: mean of the dependent variable computed from the exact `data=` subset passed to `feols()` (after all sample filters and `na.omit`), rounded to 3 decimal places.
- `SD(treatment)`: standard deviation of the key treatment variable (not controls) from the same subset, rounded to 3 decimal places.
- Use the actual variable name as the label when cleaner (e.g., `Mean(gr\_branch)`, `SD(share\_deps\_closed)`).

Compute inline before calling `feols()`:

```r
mean_dv  <- round(mean(data$dep_var,     na.rm = TRUE), 3)
sd_treat <- round(sd(data$treatment_var, na.rm = TRUE), 3)
```

Add via `etable()` `extralines` argument or append manually to the exported `.tex`. Row order: **N → Mean(DV) → SD(treatment) → Within R²**.

### Key Results Summary (print after generating regression tables)

After a regression script finishes writing table files, print a concise key-coefficient summary in the chat as a Markdown table. This gives the user a fast overview without having to open each table file.

**Format:**

```
| Outcome | Coef | SE | Sig | N |
|---|---|---|---|---|
| Δ Loans | -0.033 | 0.374 |  | 2,654 |
| Δ Securities | 0.486 | 0.303 |  | 2,654 |
| Δ log(A/Emp) | 0.023 | 0.008 | *** | 2,654 |
| ... | ... | ... | ... | ... |
```

**Rules:**

- One row per outcome (dependent variable). For multi-column tables in the same table file, list each column as a separate row.
- Columns: **Outcome**, **Coef** (key endogenous/treatment coefficient, 3 decimals), **SE** (3 decimals), **Sig** (stars: `*` p<0.10, `**` p<0.05, `***` p<0.01; blank if not significant), **N**.
- Below the table, report the first-stage F-statistic (for IV specifications) and flag any specification change from the prior run (e.g., controls added/removed, sample filter changed).
- End with one short line (≤25 words) summarizing the overall pattern — not per-coefficient interpretation.
- Do **not** repeat the full etable output (controls, fixed effects lines, SE type) — that lives in the saved `.md` file.
- Do **not** print this summary for descriptive-stat tables (Table 1, Table 2 style) — only for regression tables.

### Quarto Documents

- Use `type: source` in the Quarto YAML front matter so the document runs as a script without rendering to HTML/PDF.
- Suppress warnings and messages by default in chunk options.
- Do not knit/render `.qmd` files to check results — source them or run them via `quarto run`.

---

## Python Coding Standards

### Exploratory Display Rule

When executing code inline (e.g. `python -c "..."` or running a scratch snippet to answer "view/check/show me") and the result is a DataFrame with **< 100 rows and < 10 columns**, render it visually using Matplotlib:

```python
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(min(12, max(4, len(df.columns))), min(8, max(2, len(df) * 0.3 + 1))))
ax.axis('off')
tbl = ax.table(cellText=df.values, colLabels=df.columns, loc='center', cellLoc='center')
tbl.auto_set_font_size(True)
tbl.set_fontsize(10)
fig.tight_layout()
plt.show()
```

**When to use:** User says "view", "check", "show", "what does X look like", or you are running exploratory one-off code to display a result.

**When NOT to use:** Writing or editing a `.py` script/file. Never embed `plt.show()` table pop-outs inside saved scripts — they are for interactive inspection only.

---

## Session Memory

`NOTES.md` files are written by the `/agents/session-debrief` agent after each work session. They summarize what was done, decisions made, and open threads.

- `NOTES.md` in project root → high-level summary of overall paper progress
- `NOTES.md` per track (e.g., `tracks/did-april2026/NOTES.md`) → focused notes specific to that track's work

Read relevant `NOTES.md` at session start to orient quickly. They are a supplement to — not a substitute for — reading code and git history when deeper context is needed.

---

## Skills & Agents

Skills and agents live in `.claude/commands/` (symlinked from ai-vault in project repositories).
Invoke via slash commands in Claude Code.

**Track argument convention:** Skills that operate on a paper draft, code base, or per-track results take the track name (e.g., `did-april2026`) as their first argument. Skills that operate at project level (literature management, etc.) do not. Each skill's instructions list the exact form.

**Skills:**

- `/skills/snapshot-results` — snapshot current tables & figures into `docs/snapshots/` for GitHub Pages sharing
- `/skills/latex-compile` — compile LaTeX to PDF (pdflatex, no latexmk)
- `/skills/write-section` — write a paper section as a LaTeX file
- `/skills/latex-preflight-check` — pre-submission QA checklist
- `/skills/latex-figure-inserter` — insert a figure environment into a .tex file
- `/skills/latex-table-inserter` — insert a table environment into a .tex file
- `/skills/academic-paragraph-inserter` — insert a prose paragraph at a line number
- `/skills/academic-introduction-evaluator` — evaluate introduction against JF/RFS standards
- `/skills/table-figure-descriptions` — generate table/figure notes (Journal of Finance style)
- `/skills/figure-table-crosscheck` — audit in-text numbers against table values
- `/skills/bib-validator` — validate BibTeX entries against Google Scholar
- `/skills/sanity-check` — generate R data sanity-check script and report
- `/skills/pipeline-audit` — retrospective code-simplicity audit: maps every reported result to the code that produces it, identifies dead code and unnecessary complexity, and produces a simplification report
- `/skills/cochrane-style-check` — audit a `.tex` file against Cochrane (2005) "Writing Tips for Ph.D. Students"; report under `.claude/cc/cochrane-style-check/`. Reads `**Authorship**` field from this file

**Agents:**

- `/agents/finance-paper-reviewer` — full pre-submission review (6 sub-agents in parallel)
- `/agents/literature-downloader` — acquire PDFs and convert to markdown (3 phases: `seed`, `expand`, `finalize`)
- `/agents/literature-reviewer` — build .bib, summarize papers, write literature review (run after literature-downloader)
- `/agents/ai-detector` — detect LLM fingerprints and robotic prose
- `/agents/harsh-editor` — adversarial editorial review of paper vs. code
- `/agents/professor-robustness-check` — quick robustness replication from raw data
- `/agents/referee2-audit` — systematic 5-audit replication and code review
- `/agents/referee-response-evaluator` — evaluate and improve referee response letters
- `/agents/academic-paper-writer` — draft paper sections with IMRAD structure

---

## Output Style & Formatting Rules

### Professional Mode (Outward-Facing)

**Condition:** Task involves editing/generating content in `.tex`, `.bib`, or `.md` files, or drafting emails or academic prose.

- Ignore Caveman instructions entirely.
- Use professional academic English suitable for a Finance Professor: formal grammar, precise terminology, standard punctuation.
- Ensure all mathematical notation and citations strictly follow professional standards.

### Caveman Mode (Internal Communication)

**Condition:** Providing explanations, debugging code, or responding in the chat interface.

- Follow the Caveman protocol for token efficiency.
- Minimalist, no-fluff style. Technical accuracy and speed over prose.

**Examples:**

- "Why is my fixest regression failing?" → Caveman explanation.
- "Draft the methodology section in paper.tex" → Formal academic prose.

---

## LaTeX Conventions

All paths below are **relative to the active track's `latex/` folder** (i.e. `tracks/<name>/latex/`).

- Output directory for pdflatex: `tracks/<name>/latex/build/`
- Figures referenced as `\includegraphics{figures/filename}` (graphicspath set in the track's `main.tex`)
- Tables `\input{}`-ed from `tables/` or inline in section files
- Section files: `sections/<section>/<section>_current.tex` (`\input{}`-ed from `main.tex`)
- Never edit `build/` contents directly
- Compile sequence: `pdflatex → bibtex → pdflatex → pdflatex` (all run from the track's `latex/` directory)

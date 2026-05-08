# Public-Data Replication, By Bank-Size Bucket

Self-contained replication folder mirroring `approach-public-data-april2026`,
but reporting every regression separately for three bank-size buckets:

| Bucket | Bank-year assets |
|---|---|
| `ge_100bn`   | >= $100B |
| `10_100bn`   | $10B - $100B |
| `1_10bn`     | $1B - $10B |

A bank is assigned to a bucket on the basis of its **bank-year assets**
(SOD `ASSET` * 1000), so a single bank can move between buckets across years.
Banks with year-assets below $1B are excluded.

The folder is fully self-contained: every `.rds` input lives in `data/`, and
the regression script reads only from `data/`.  External DuckDB views are
needed only when the build pipeline (`00 - 04`) is rerun.

## Folder contents

| File / folder | Purpose |
|---|---|
| `README.md` | This file. |
| `NOTES.md`  | Session notes. |
| `common_public_data.R` | Libraries, paths, helpers, `base_controls`, regression-table writer (extended with per-column data subsets), bucket definitions. |
| `00_build_panel.R` | **Creator-only.**  Rebuilds `bank_year_zip_panel_<DATE>.rds` with the size threshold lowered to **$1B max-ever** (was $50B in the upstream pipeline). |
| `01_build_deposit_beta.R` | **Creator-only.**  Rebuilds the six-stage deposit-beta pipeline (bank-quarter expense -> cycle DV -> Dec controls -> demographics -> first-stage -> impute) end-to-end on the wider bank universe. |
| `02_build_bank_advantage.R` | **Creator-only.**  Rebuilds `eff_ratio` / `int_exp_assets` / focal-vs-incumbent advantage pipeline end-to-end. |
| `03_build_cross_sell.R` | **Creator-only.**  Rebuilds HMDA mortgage and CRA small-business beachhead variables end-to-end. |
| `04_build_master_dataset.R` | **Creator-only.**  Joins the four upstream local outputs and adds bank-year `bank_assets` from SOD.  Writes split master + bank-cycle file. |
| `code/result-generation/05_run_all_results.R` | **The main script.**  Reads the local `.rds` files, runs the 12 regressions per bucket, writes 12 markdown tables to `latex/tables/`. |
| `data/` | All `.rds` outputs of `00 - 04`.  Master split into 8 parts (each ~80 MB). |
| `latex/tables/` | 12 markdown tables produced by `05`.  Bucket = column (single-spec tables) or panel (multi-spec tables). |
| `latex/figures/` | Reserved (none in current pipeline). |

## How to run (coauthor)

If `data/master_bank_zip_year_*_partNN.rds` and `data/bank_cycle_first_stage_*.rds`
are already present, just run:

```r
source("tracks/public-data-results-may2026/code/result-generation/05_run_all_results.R")
```

Required packages: `data.table`, `fixest`, `knitr`, `ggplot2`.  No internet
or external DuckDB needed.

## How to rebuild (creator)

Run the build pipeline in order (each writes to local `data/`):

```bash
"$R_EXE" -f tracks/public-data-results-may2026/code/sample-construction/00_build_panel.R
"$R_EXE" -f tracks/public-data-results-may2026/code/sample-construction/01_build_deposit_beta.R
"$R_EXE" -f tracks/public-data-results-may2026/code/sample-construction/02_build_bank_advantage.R
"$R_EXE" -f tracks/public-data-results-may2026/code/sample-construction/03_build_cross_sell.R
"$R_EXE" -f tracks/public-data-results-may2026/code/sample-construction/04_build_master_dataset.R
"$R_EXE" -f tracks/public-data-results-may2026/code/result-generation/05_run_all_results.R
```

The build pipeline depends on the external DuckDB views in
`C:/empirical-data-construction/{sod,call-reports-FFIEC,hmda,cra,irs}` and on
the project-level zip-population-density (`data/raw/`) and ACS panel
(`data/constructed/zip_year_acs_panel_*.rds`) files (zip-level public data,
independent of the bank-size threshold).

## Layout of the output tables

| File | What it shows | Layout |
|---|---|---|
| `01_tab_descriptive.md`         | Sample shape, treatment distribution. | Bucket = row dimension. |
| `02_tab_baseline.md`            | Branch opening on **zip deposit growth** + controls. | 3 columns (one per bucket).  FE = Bank x Year + State x Year. |
| `03_tab_first_stage.md`         | First-stage of deposit beta. 3 cycles x 2 specs. | 3 panels (one per bucket); 6 cols within each. |
| `04_tab_opening_with_beta.md`   | Branch opening on **deposit beta** + controls. | 3 columns (one per bucket). |
| `05_tab_efficiency_adv.md`      | Branch opening on **efficiency advantage** (continuous). | 3 columns. |
| `06_tab_high_iea.md`            | Branch opening on **high_IEA** dummy. | 3 columns. |
| `07_tab_high_eff.md`            | Branch opening on **high_eff** dummy. | 3 columns. |
| `08_tab_advantage_combined.md`  | beta + efficiency_adv / high_IEA, additive + interactive. | 3 panels (bucket); 6 cols within each. |
| `09_tab_advantage_combined_dummies.md` | beta + high_eff / high_IEA. | 3 panels; 6 cols within each. |
| `10_tab_beta_x_mortgage.md`     | Deposit beta x mortgage presence. | 3 panels; 5 cols within each. |
| `11_tab_beta_x_cra.md`          | Deposit beta x CRA small-business presence. | 3 panels; 5 cols within each. |
| `12_tab_beta_x_both.md`         | Both lending channels combined. | 3 panels; 5 cols within each. |

All regressions are linear probability models clustered on `zip5`, sample
restricted to `yr <= 2024`.  Treatments are winsorized 1/99 within bucket-year
on their effective subsamples.

## Differences vs. `approach-public-data-april2026`

1. **Bank universe**: lowered max-ever threshold from $50B to $1B (1479 banks
   instead of ~140) so the $10B-$100B and $1B-$10B buckets have full coverage.
2. **`bank_assets` column** added to the master from SOD `ASSET`.  Used by
   `05` to assign each row to a bucket.
3. **Tables collapsed**: 12 tables (matching `approach-public-data-april2026`)
   rather than 36 (one set per bucket).  Bucket appears as a column or panel
   inside each table.
4. **Bottom bucket dropped**: rows with bank-year assets below $1B excluded.

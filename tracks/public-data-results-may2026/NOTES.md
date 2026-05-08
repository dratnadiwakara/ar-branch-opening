# NOTES -- public-data-results-may2026

## 2026-04-27

### Done
- Forked `approach-public-data-april2026` to add a bank-size dimension. Three
  buckets defined on bank-year assets: >=$100B, $10B-$100B, $1B-$10B. Bottom
  bucket (<$1B) excluded per user instruction.
- Lowered upstream `large_bank_threshold_dollars` from $50B to $1B in the
  panel builder (00). Rebuilt the four upstream pipelines (panel, deposit
  beta, bank advantage, cross-sell) end-to-end inside this folder so the
  original `data/constructed/` files are untouched.
- `04_build_master_dataset.R` adds `bank_assets` column (SOD ASSET * 1000)
  to the master, used by `05` for bucket assignment.
- `05_run_all_results.R`: 12 tables. Single-spec tables show bucket as
  columns (one per bucket, FE = Bank x Year + State x Year). Multi-spec
  tables (03 first-stage, 08-12) stack three panels (one per bucket),
  preserving the original FE column structure within each panel.

### Lessons
- Lowering the threshold to $1B grew the panel from ~3M rows (large_rssd ~140
  banks) to 14.4M rows (1479 banks). Build runtime: panel ~25 min,
  deposit-beta ~25 min, advantage ~25 min, cross-sell ~heavy (HMDA + CRA
  cross-joins). Master build adds bank_assets in seconds.
- `write_reg_table()` extended with optional `out_dir` arg and per-column
  `data_for_stats` list so each bucket-column shows its own Mean(opening)
  and SD(treatment) footers.
- Bucket assignment via `assign_bucket(assets)` in `common_public_data.R`.
  NA assets -> NA bucket; <$1B -> NA bucket. Both excluded by the at-risk
  filter in `05`.

### Next
- Possible: add columns showing bucket-vs-bucket coefficient differences
  (`coef[ge_100bn] - coef[1_10bn]`) with SEs from a stacked regression, to
  formally test whether the channels operate differently across size buckets.
- Possible: a separate descriptive table showing what fraction of
  bank-year-zips a bank moves between buckets across the panel (sticky vs.
  rapidly growing/shrinking banks).

## 2026-04-27 (build execution + bug fix)

### Done
- Ran full pipeline 00 -> 05 end-to-end. Panel ~7 min, deposit-beta ~6 min,
  advantage ~3 min, cross-sell ~5 min, master ~1 min, results ~7 min per run.
  All 12 tables in `tables/` regenerated post bug fix.
- Pipeline numbers: panel 14.36M rows / 1,479 banks; bucket split master
  rows ge_100bn=2.95M, 10_100bn=2.86M, 1_10bn=6.26M (~2.3M rows below $1B
  dropped). bank-cycle file: 17,104 rows (4 cycles).
- Headline coefs (FE = Bank x Year + State x Year): deposit_beta = 0.030 /
  0.034 / 0.023 across the three buckets, all sig at 1%. efficiency_adv
  uniform ~0.002 across buckets. high_eff dummy insignificant for >=$100B
  but +0.0005*** for $10-100B and +0.0003** for $1-10B. Baseline
  g_dep_zip flips sign: insignificant for >=$100B, -0.0005*** for $1-10B.

### Dead ends
- First run of 05 produced empty `03_tab_first_stage.md` (3 buckets, no
  models). Cause: `bc` table inherits `bank_assets` from FFIEC `bs.assets`
  in $thousands, but `assign_bucket()` expects dollars. So 100B / 10B / 1B
  cutoffs misclassified everything. Fix: `bc[, size_bucket := assign_bucket(bank_assets * 1000)]`.

### Lessons
- **Unit gotcha**: SOD ASSET multiplied by 1000 in 04 master build (so
  master `bank_assets` is in $); FFIEC `bs.assets` from
  `bank_year_dec_controls_*.rds` is in $thousands and used directly in
  `bc` (no multiply). Any future code that bucketizes `bc` must convert
  first. Both upstream tables `bank_year_dec_controls` and
  `bank_cycle_first_stage` carry the unconverted value.
- **First-stage panel skinny for >=$100B early cycles**: 2004 cycle has
  only ~3-5 banks above $100B in current dollars, so my `nrow(cdat) < 25`
  filter drops Early-Full / Mid-Full / Early-Soph / Mid-Soph cols for that
  bucket. Resulting panel for >=$100B has only 2 of 6 columns (Late-Full
  + Late-Soph). Acceptable but worth noting in slides.
- **Build-script idempotency**: rerunning 05 overwrites tables; outputs
  deterministic from cached .rds files, no need to rerun 00-04.
- **Compute order matters for parallelism**: 02 (advantage) and 03
  (cross-sell) are independent of each other after panel built. Ran in
  parallel to save ~5 min.

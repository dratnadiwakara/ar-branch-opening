# 05_run_all_results.R
# =============================================================================
# Reproduces every regression and descriptive table for the bank-branch-
# openings paper, BUT with three parallel size buckets reported as columns
# (or panels) within a single table per analysis.  Reads .rds files from
# ./data/, runs all regressions per bucket, writes markdown tables to
# ./tables/.
#
# Buckets (defined in common_public_data.R):
#   ge_100bn  : bank-year assets >= $100B
#   10_100bn  : bank-year assets [$10B, $100B)
#   1_10bn    : bank-year assets [$1B, $10B)
#
# A row is assigned to a bucket based on its bank-year `bank_assets` value
# (SOD ASSET * 1000).  A bank can move between buckets across years.
#
# Layout convention:
#   - Single-spec tables (02, 04, 05, 06, 07): three columns (one per
#     bucket) using the tightest non-zip FE spec (Bank x Year + State x Year).
#   - Multi-spec tables (03 first-stage, 08-12): three stacked panels (one
#     per bucket) preserving all original FE columns.
#   - Descriptive table (01): bucket is a row dimension.
# =============================================================================

rm(list = ls())
source("tracks/public-data-results-may2026/code/common_public_data.R")

# =============================================================================
# 0. Setup
# =============================================================================

cat("\n========================================\n",
    "0. Setup\n",
    "========================================\n", sep = "")

master_parts <- Sys.glob(file.path(data_dir,
                                   "master_bank_zip_year_*_part*.rds"))
if (length(master_parts) == 0L)
  stop("No master parts found in ", data_dir, " -- run 04 first.")
dates        <- regmatches(master_parts, regexpr("\\d{8}", master_parts))
latest_date  <- max(dates)
master_parts <- sort(master_parts[dates == latest_date])
cat("Master parts (", length(master_parts), ", date ", latest_date, "):\n", sep = "")
for (p in master_parts) cat("  ", p, "\n")

bc_path <- load_latest(file.path(data_dir, "bank_cycle_first_stage_*.rds"))
cat("Bank-cycle:", bc_path, "\n")

dt <- rbindlist(lapply(master_parts, readRDS))
bc <- setDT(readRDS(bc_path))

# Outcome and lagged regressors (need bank-zip ordering).
setorder(dt, RSSDID, zip5, yr)
dt[, n_branches_lag1    := shift(n_branches_bzt,    1L), by = .(RSSDID, zip5)]
dt[, bank_in_state_lag1 := shift(bank_in_state_bzt, 1L), by = .(RSSDID, zip5)]
dt[, share_bzt_lag1     := shift(share_bzt,         1L), by = .(RSSDID, zip5)]
dt[, opening := as.integer(n_branches_bzt > n_branches_lag1)]

dt[, n_large_banks_zip      := sum(n_branches_bzt > 0L), by = .(yr, zip5)]
dt[, n_large_banks_zip_lag1 := shift(n_large_banks_zip, 1L), by = .(RSSDID, zip5)]

dt[, g_dep_zip_t1_t3 := log1p(dep_zip_total_lag1) - log1p(dep_zip_total_lag3)]
dt[, g_hmda_t1_t3    := log1p(hmda_amt_lag1)      - log1p(hmda_amt_lag3)]
dt[, g_cra_t1_t3     := log1p(cra_amt_lag1)       - log1p(cra_amt_lag3)]
dt[, log_dep_zip_lag1    := log1p(dep_zip_total_lag1)]
dt[, log_avg_agi_lag1    := log(avg_agi_lag1)]
dt[, log_n_branches_lag1 := log1p(n_branches_lag1)]
dt[, hhi_lag1            := deposit_hhi_zip_lag1 / 10000]
dt[is.na(share_bzt_lag1), share_bzt_lag1 := 0]

dt[!is.na(int_exp_assets_share_undercut),
   high_IEA := as.integer(int_exp_assets_share_undercut > 0.5)]
dt[!is.na(rate_paying_adv),
   high_rate_paying := as.integer(rate_paying_adv > 0)]

# Bucket assignment from bank-year assets.
dt[, size_bucket := assign_bucket(bank_assets)]

# Master at-risk filter (also drop yr > 2024 and rows outside the three
# buckets, since <$1B and unknown-assets rows are not analysed).
base_filter <- quote(
  yr <= 2024L                        &
  !is.na(size_bucket)                &
  !is.na(n_branches_lag1)            &
  !is.na(bank_in_state_lag1)         &
  !is.na(n_large_banks_zip_lag1)     &
  !is.na(g_dep_zip_t1_t3)            &
  !is.na(g_hmda_t1_t3)               &
  !is.na(g_cra_t1_t3)                &
  !is.na(log_dep_zip_lag1)           &
  !is.na(log_avg_agi_lag1)           &
  !is.na(log_pop_density_lag1)       &
  !is.na(median_age_lag1)            &
  !is.na(pct_college_educated_lag1)  &
  !is.na(hhi_lag1)                   &
  !is.na(no_bank_zip_lag1)
)

ar_master <- dt[eval(base_filter)]
cat("\nar_master rows:", nrow(ar_master), "\n")
cat("Rows per bucket:\n"); print(ar_master[, .N, by = size_bucket])

# Build per-bucket subsets and re-winsorize within each bucket-yr.
make_bucket_dt <- function(d, bk) {
  out <- d[size_bucket == bk]
  for (v in c("g_dep_zip_t1_t3", "g_hmda_t1_t3", "g_cra_t1_t3",
              "median_age_lag1", "pct_college_educated_lag1")) {
    out[, (v) := winsor(get(v)), by = yr]
  }
  out
}
ar_bucket <- lapply(setNames(bucket_names, bucket_names),
                    function(bk) make_bucket_dt(ar_master, bk))

# Bank-cycle file by bucket (uses bank_assets at the cycle's demo_year).
# bc bank_assets is from FFIEC bs.assets in $ thousands; convert to dollars
# for the bucket assignment, which expects dollar units.
bc[, size_bucket := assign_bucket(bank_assets * 1000)]
bc_bucket <- lapply(setNames(bucket_names, bucket_names),
                    function(bk) bc[size_bucket == bk])

cat("\nrows by bucket (master):\n")
for (bk in bucket_names) cat(sprintf("  %s: %s\n", bk, format(nrow(ar_bucket[[bk]]), big.mark = ",")))
cat("rows by bucket (bank-cycle):\n")
for (bk in bucket_names) cat(sprintf("  %s: %s\n", bk, format(nrow(bc_bucket[[bk]]), big.mark = ",")))

# FE families.
fe_bxy <- "RSSDID^yr"
fe_bsy <- "RSSDID^yr + state_fips^yr"
fe_zxy <- "RSSDID^yr + zip5^yr"

fml_build <- function(treatment, fe = NULL) {
  rhs <- paste(treatment, "+", base_rhs)
  if (is.null(fe)) as.formula(paste("opening ~", rhs))
  else             as.formula(paste("opening ~", rhs, "|", fe))
}

# Run a model spec for each bucket; return a list parallel to bucket_names.
run_per_bucket <- function(treatment, fe, dataset_list = ar_bucket) {
  lapply(bucket_names, function(bk) {
    d <- dataset_list[[bk]]
    if (nrow(d) == 0L) return(NULL)
    feols(fml_build(treatment, fe), data = d, cluster = ~ zip5)
  })
}

# Run an arbitrary feols formula for each bucket.
run_per_bucket_fml <- function(fml_string, dataset_list = ar_bucket) {
  lapply(bucket_names, function(bk) {
    d <- dataset_list[[bk]]
    if (nrow(d) == 0L) return(NULL)
    feols(as.formula(fml_string), data = d, cluster = ~ zip5)
  })
}

# Helper: replace NULL models with a placeholder so write_reg_table can skip.
drop_null <- function(models, headers, datas, fe_labels) {
  keep <- !vapply(models, is.null, logical(1))
  list(models = models[keep], headers = headers[keep],
       datas = datas[keep], fe_labels = fe_labels[keep])
}

# Wrapper: write a 3-bucket-as-columns table for a single FE spec.
write_bucket_columns <- function(treatment, fe, fe_label, treat_label, filename,
                                 dataset_list = ar_bucket) {
  models <- run_per_bucket(treatment, fe, dataset_list)
  parts  <- drop_null(models, bucket_short, dataset_list, rep(fe_label, length(bucket_names)))
  if (length(parts$models) == 0L) {
    cat("Skip (no buckets): ", filename, "\n"); return(invisible(NULL))
  }
  write_reg_table(
    models         = parts$models,
    col_headers    = parts$headers,
    treat_name     = treatment,
    treat_label    = treat_label,
    data_for_stats = parts$datas,
    fe_labels      = parts$fe_labels,
    filename       = filename
  )
}

# Wrapper: stack 3 panels (one per bucket) into one .md file, each with the
# original multi-FE column layout.
write_bucket_panels <- function(per_spec_runner, col_headers, fe_labels,
                                treat_name, treat_label, filename,
                                dataset_list = ar_bucket) {
  # `per_spec_runner` is a function(bucket_dt) -> list of feols models
  # parallel to col_headers.
  bucket_blocks <- list()
  for (bk in bucket_names) {
    d <- dataset_list[[bk]]
    if (nrow(d) == 0L) {
      bucket_blocks[[bk]] <- paste0("\n### Panel: ", bucket_label[bk],
                                    " (no rows)\n")
      next
    }
    models <- per_spec_runner(d)
    keep   <- !vapply(models, is.null, logical(1))
    if (!any(keep)) {
      bucket_blocks[[bk]] <- paste0("\n### Panel: ", bucket_label[bk],
                                    " (no models)\n")
      next
    }
    # Use a temp file then read back -- simplest way to reuse write_reg_table.
    tf <- tempfile(fileext = ".md")
    write_reg_table(
      models         = models[keep],
      col_headers    = col_headers[keep],
      treat_name     = treat_name,
      treat_label    = treat_label,
      data_for_stats = d,
      fe_labels      = fe_labels[keep],
      filename       = basename(tf),
      out_dir        = dirname(tf)
    )
    body <- paste(readLines(tf), collapse = "\n")
    bucket_blocks[[bk]] <- paste0("\n### Panel ", which(bucket_names == bk),
                                  ": ", bucket_label[bk], "\n\n", body)
    file.remove(tf)
  }
  out_md <- file.path(tables_dir, filename)
  writeLines(do.call(c, bucket_blocks), out_md)
  cat("Wrote:", out_md, "\n")
}

# =============================================================================
# 1. Descriptive statistics (bucket = row dimension)
# =============================================================================

cat("\n========================================\n",
    "1. Descriptive statistics\n",
    "========================================\n", sep = "")

samp_rows <- list()
for (bk in bucket_names) {
  d <- ar_bucket[[bk]]
  if (nrow(d) == 0L) {
    samp_rows[[bk]] <- data.table(bucket = bucket_short[bk],
                                  metric = "Bank-zip-year obs", value = "0")
    next
  }
  samp_rows[[bk]] <- data.table(
    bucket = bucket_short[bk],
    metric = c("Years",
               "Banks",
               "Zip codes",
               "Bank-zip-year obs",
               "Openings",
               "Opening rate (%)"),
    value  = c(sprintf("%d-%d", min(d$yr), max(d$yr)),
               format(uniqueN(d$RSSDID), big.mark = ","),
               format(uniqueN(d$zip5),   big.mark = ","),
               format(nrow(d),           big.mark = ","),
               format(sum(d$opening),    big.mark = ","),
               sprintf("%.3f", mean(d$opening) * 100))
  )
}
samp <- rbindlist(samp_rows)
print(samp)

treats <- c("g_dep_zip_t1_t3", "deposit_beta",
            "rate_paying_adv", "int_exp_assets_share_undercut",
            "mortgage_presence", "mortgage_share",
            "cra_presence",      "cra_share")

dist_rows <- list()
for (bk in bucket_names) {
  d <- ar_bucket[[bk]]
  for (v in treats) {
    x <- d[[v]]
    dist_rows[[length(dist_rows) + 1L]] <- data.table(
      bucket   = bucket_short[bk],
      variable = v,
      n        = sum(!is.na(x) & is.finite(x)),
      mean     = round(mean(x,           na.rm = TRUE), 4),
      sd       = round(sd(x,             na.rm = TRUE), 4),
      p10      = round(quantile(x, 0.10, na.rm = TRUE), 4),
      p50      = round(quantile(x, 0.50, na.rm = TRUE), 4),
      p90      = round(quantile(x, 0.90, na.rm = TRUE), 4)
    )
  }
}
dist_tbl <- rbindlist(dist_rows)
print(dist_tbl)

if (save_tables) {
  out_md <- file.path(tables_dir, "01_tab_descriptive.md")
  con    <- file(out_md, open = "w")
  writeLines("## Sample shape (by size bucket)\n", con)
  writeLines(knitr::kable(samp, format = "pipe", row.names = FALSE), con)
  writeLines("\n## Distribution of treatments (by size bucket)\n", con)
  writeLines(knitr::kable(dist_tbl, format = "pipe", row.names = FALSE), con)
  close(con)
  cat("Wrote:", out_md, "\n")
}

# =============================================================================
# 2. Baseline regression  (treatment = zip deposit growth)
# =============================================================================

cat("\n========================================\n",
    "2. Baseline (g_dep_zip_t1_t3)\n",
    "========================================\n", sep = "")

write_bucket_columns(
  treatment   = "g_dep_zip_t1_t3",
  fe          = fe_bsy,
  fe_label    = "Bank x Year + State x Year",
  treat_label = "g_dep_zip_t1_t3",
  filename    = "02_tab_baseline.md"
)

# =============================================================================
# 3. Deposit beta -- first stage (bank-cycle data, panel layout)
# =============================================================================

cat("\n========================================\n",
    "3. First-stage deposit beta\n",
    "========================================\n", sep = "")

fml_full <- deposit_exp_chg ~ factor_age_bin + dividend_frac + college_frac +
  log(family_income) + bank_hhi + log(bank_assets) + population_density +
  trans_accts_frac_assets + uninsured_deposits_frac + time_deposits_assets

fml_soph <- deposit_exp_chg ~ sophisticated_frac + factor_age_bin +
  log(family_income) + bank_hhi + log(bank_assets) + population_density +
  trans_accts_frac_assets + uninsured_deposits_frac + time_deposits_assets

# Stack one block per bucket.
fs_blocks <- list()
for (bk in bucket_names) {
  d <- bc_bucket[[bk]]
  fs_models <- list()
  for (cyc in c("cycle_0406", "cycle_1619", "cycle_2224")) {
    cdat <- d[cycle == cyc]
    if (nrow(cdat) < 25L) next   # too few banks for 11-coef regression
    fs_models[[paste0(cyc, "_full")]] <- feols(fml_full, data = cdat, notes = FALSE)
    fs_models[[paste0(cyc, "_soph")]] <- feols(fml_soph, data = cdat, notes = FALSE)
  }
  if (length(fs_models) == 0L) {
    fs_blocks[[bk]] <- paste0("\n### Panel: ", bucket_label[bk], " (no models)\n")
    next
  }
  ord <- intersect(c("cycle_0406_full", "cycle_1619_full", "cycle_2224_full",
                     "cycle_0406_soph", "cycle_1619_soph", "cycle_2224_soph"),
                   names(fs_models))
  fs_models <- fs_models[ord]
  hdr_map <- c(cycle_0406_full = "Early-Full", cycle_1619_full = "Mid-Full",
               cycle_2224_full = "Late-Full", cycle_0406_soph = "Early-Soph",
               cycle_1619_soph = "Mid-Soph",  cycle_2224_soph = "Late-Soph")
  et_fs <- do.call(etable, c(fs_models, list(headers = unname(hdr_map[ord]),
                                             depvar = FALSE, tex = FALSE)))
  df <- as.data.frame(et_fs, stringsAsFactors = FALSE)
  rownames(df) <- NULL
  body <- paste(as.character(knitr::kable(df, format = "pipe", row.names = FALSE)),
                collapse = "\n")
  fs_blocks[[bk]] <- paste0("\n### Panel ", which(bucket_names == bk), ": ",
                            bucket_label[bk], "\n\n", body, "\n")
}

if (save_tables) {
  out_md <- file.path(tables_dir, "03_tab_first_stage.md")
  writeLines(do.call(c, fs_blocks), out_md)
  cat("Wrote:", out_md, "\n")
}

# =============================================================================
# 4. Deposit beta -- main regression (bucket as columns)
# =============================================================================

cat("\n========================================\n",
    "4. Main regression with deposit_beta\n",
    "========================================\n", sep = "")

ar_beta <- lapply(setNames(bucket_names, bucket_names), function(bk) {
  d <- ar_bucket[[bk]][!is.na(deposit_beta) & is.finite(deposit_beta)]
  d[, deposit_beta := winsor(deposit_beta), by = yr]
  d
})

write_bucket_columns(
  treatment    = "deposit_beta",
  fe           = fe_bsy,
  fe_label     = "Bank x Year + State x Year",
  treat_label  = "deposit_beta",
  filename     = "04_tab_opening_with_beta.md",
  dataset_list = ar_beta
)

# =============================================================================
# 5. Bank-advantage tables 5-7 (bucket as columns)
# =============================================================================

cat("\n========================================\n",
    "5. Bank-advantage\n",
    "========================================\n", sep = "")

ar_eff <- lapply(setNames(bucket_names, bucket_names), function(bk) {
  d <- ar_bucket[[bk]][!is.na(rate_paying_adv) & is.finite(rate_paying_adv)]
  d[, rate_paying_adv := winsor(rate_paying_adv), by = yr]
  d[, high_rate_paying       := as.integer(rate_paying_adv > 0)]
  d
})

ar_iea <- lapply(setNames(bucket_names, bucket_names), function(bk)
  ar_bucket[[bk]][!is.na(high_IEA)])

write_bucket_columns("rate_paying_adv", fe_bsy,
                     "Bank x Year + State x Year", "rate_paying_adv",
                     "05_tab_rate_paying_adv.md", ar_eff)

write_bucket_columns("high_IEA",      fe_bsy,
                     "Bank x Year + State x Year", "high_IEA",
                     "06_tab_high_iea.md",        ar_iea)

write_bucket_columns("high_rate_paying",      fe_bsy,
                     "Bank x Year + State x Year", "high_rate_paying",
                     "07_tab_high_rate_paying.md",        ar_eff)

# 5d/5e Combined: deposit_beta + rate_paying_adv (and dummies).
ar_comb <- lapply(setNames(bucket_names, bucket_names), function(bk) {
  d <- ar_bucket[[bk]][!is.na(rate_paying_adv) & is.finite(rate_paying_adv) &
                       !is.na(high_IEA) &
                       !is.na(deposit_beta) & is.finite(deposit_beta)]
  d[, rate_paying_adv := winsor(rate_paying_adv), by = yr]
  d[, deposit_beta   := winsor(deposit_beta),   by = yr]
  d[, high_rate_paying       := as.integer(rate_paying_adv > 0)]
  d
})

# 08: 6-spec (continuous) panel layout.
write_bucket_panels(
  per_spec_runner = function(d) list(
    feols(fml_build("deposit_beta + rate_paying_adv", fe_bsy),
          data = d, cluster = ~ zip5),
    feols(fml_build("deposit_beta + high_IEA",       fe_bsy),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * rate_paying_adv +", base_rhs, "|", fe_bsy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * high_IEA +",       base_rhs, "|", fe_bsy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * rate_paying_adv +", base_rhs, "|", fe_zxy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * high_IEA +",       base_rhs, "|", fe_zxy)),
          data = d, cluster = ~ zip5)
  ),
  col_headers  = c("(1) beta+eff", "(2) beta+IEA",
                   "(3) beta\u00d7eff", "(4) beta\u00d7IEA",
                   "(5) beta\u00d7eff Zip\u00d7Y",
                   "(6) beta\u00d7IEA Zip\u00d7Y"),
  fe_labels    = c(rep("Bank x Year + State x Year", 4),
                   rep("Bank x Year + Zip x Year",   2)),
  treat_name   = "deposit_beta",
  treat_label  = "deposit_beta",
  filename     = "08_tab_advantage_combined.md",
  dataset_list = ar_comb
)

# 09: 6-spec (dummy) panel layout.
write_bucket_panels(
  per_spec_runner = function(d) list(
    feols(fml_build("deposit_beta + high_rate_paying", fe_bsy),
          data = d, cluster = ~ zip5),
    feols(fml_build("deposit_beta + high_IEA", fe_bsy),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * high_rate_paying +", base_rhs, "|", fe_bsy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * high_IEA +", base_rhs, "|", fe_bsy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * high_rate_paying +", base_rhs, "|", fe_zxy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * high_IEA +", base_rhs, "|", fe_zxy)),
          data = d, cluster = ~ zip5)
  ),
  col_headers  = c("(1) beta+heff", "(2) beta+hIEA",
                   "(3) beta\u00d7heff", "(4) beta\u00d7hIEA",
                   "(5) beta\u00d7heff Zip\u00d7Y",
                   "(6) beta\u00d7hIEA Zip\u00d7Y"),
  fe_labels    = c(rep("Bank x Year + State x Year", 4),
                   rep("Bank x Year + Zip x Year",   2)),
  treat_name   = "deposit_beta",
  treat_label  = "deposit_beta",
  filename     = "09_tab_advantage_combined_dummies.md",
  dataset_list = ar_comb
)

# =============================================================================
# 6. Cross-sell (panels 10, 11, 12)
# =============================================================================

cat("\n========================================\n",
    "6. Cross-sell\n",
    "========================================\n", sep = "")

ar_cs <- lapply(setNames(bucket_names, bucket_names), function(bk) {
  d <- ar_bucket[[bk]][!is.na(deposit_beta) & is.finite(deposit_beta)]
  d[, deposit_beta := winsor(deposit_beta), by = yr]
  d
})

# 10: deposit_beta x mortgage_presence (5-spec panel layout)
write_bucket_panels(
  per_spec_runner = function(d) list(
    feols(fml_build("deposit_beta + mortgage_presence", fe_bxy),  data = d, cluster = ~ zip5),
    feols(fml_build("deposit_beta + mortgage_presence", fe_bsy),  data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * mortgage_presence +", base_rhs, "|", fe_bxy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * mortgage_presence +", base_rhs, "|", fe_bsy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * mortgage_presence +", base_rhs, "|", fe_zxy)),
          data = d, cluster = ~ zip5)
  ),
  col_headers  = c("(1) Add B\u00d7Y",
                   "(2) Add B\u00d7Y+S\u00d7Y",
                   "(3) Int B\u00d7Y",
                   "(4) Int B\u00d7Y+S\u00d7Y",
                   "(5) Int B\u00d7Y+Zip\u00d7Y"),
  fe_labels    = c("Bank x Year",
                   "Bank x Year + State x Year",
                   "Bank x Year",
                   "Bank x Year + State x Year",
                   "Bank x Year + Zip x Year"),
  treat_name   = "deposit_beta",
  treat_label  = "deposit_beta",
  filename     = "10_tab_beta_x_mortgage.md",
  dataset_list = ar_cs
)

# 11: deposit_beta x cra_presence (5-spec panel layout)
write_bucket_panels(
  per_spec_runner = function(d) list(
    feols(fml_build("deposit_beta + cra_presence", fe_bxy),  data = d, cluster = ~ zip5),
    feols(fml_build("deposit_beta + cra_presence", fe_bsy),  data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * cra_presence +", base_rhs, "|", fe_bxy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * cra_presence +", base_rhs, "|", fe_bsy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * cra_presence +", base_rhs, "|", fe_zxy)),
          data = d, cluster = ~ zip5)
  ),
  col_headers  = c("(1) Add B\u00d7Y",
                   "(2) Add B\u00d7Y+S\u00d7Y",
                   "(3) Int B\u00d7Y",
                   "(4) Int B\u00d7Y+S\u00d7Y",
                   "(5) Int B\u00d7Y+Zip\u00d7Y"),
  fe_labels    = c("Bank x Year",
                   "Bank x Year + State x Year",
                   "Bank x Year",
                   "Bank x Year + State x Year",
                   "Bank x Year + Zip x Year"),
  treat_name   = "deposit_beta",
  treat_label  = "deposit_beta",
  filename     = "11_tab_beta_x_cra.md",
  dataset_list = ar_cs
)

# 12: both channels combined (5-spec panel layout)
write_bucket_panels(
  per_spec_runner = function(d) list(
    feols(as.formula(paste("opening ~ deposit_beta * mortgage_presence + cra_presence +",
                            base_rhs, "|", fe_bsy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * cra_presence + mortgage_presence +",
                            base_rhs, "|", fe_bsy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * mortgage_presence +",
                            "deposit_beta * cra_presence +", base_rhs, "|", fe_bxy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * mortgage_presence +",
                            "deposit_beta * cra_presence +", base_rhs, "|", fe_bsy)),
          data = d, cluster = ~ zip5),
    feols(as.formula(paste("opening ~ deposit_beta * mortgage_presence +",
                            "deposit_beta * cra_presence +", base_rhs, "|", fe_zxy)),
          data = d, cluster = ~ zip5)
  ),
  col_headers  = c("(1) \u03b2\u00d7Mort, CRA add",
                   "(2) \u03b2\u00d7CRA, Mort add",
                   "(3) Both int B\u00d7Y",
                   "(4) Both int B\u00d7Y+S\u00d7Y",
                   "(5) Both int B\u00d7Y+Zip\u00d7Y"),
  fe_labels    = c("Bank x Year + State x Year",
                   "Bank x Year + State x Year",
                   "Bank x Year",
                   "Bank x Year + State x Year",
                   "Bank x Year + Zip x Year"),
  treat_name   = "deposit_beta",
  treat_label  = "deposit_beta",
  filename     = "12_tab_beta_x_both.md",
  dataset_list = ar_cs
)

# =============================================================================
# 7. Done
# =============================================================================

cat("\n========================================\n",
    "Done. Tables in:", tables_dir, "\n",
    "========================================\n", sep = "")

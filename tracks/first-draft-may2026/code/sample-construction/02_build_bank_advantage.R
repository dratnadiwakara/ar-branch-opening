# 02_build_bank_advantage.R
# =============================================================================
# Bank x zip x year advantage variables (rate_paying_adv,
# int_exp_assets_share_undercut).  Combines stages 01..03 of
# code/approach-bank-advantage-april2026 into a single self-contained script.
#
# Stages:
#   A. Bank-year advantage metrics (eff_ratio, int_exp_assets) from FFIEC Q4
#   B. Zip-year incumbent benchmarks (deposit-weighted by SOD) + branch-level
#      file
#   C. Bank-zip-year advantage (focal-vs-incumbent, self-excluded)
#
# Outputs (in tracks/first-draft-may2026/data/):
#   bank_year_advantage_metrics_<DATE>.rds        (A)
#   sod_branch_metrics_<DATE>.rds                  (B)
#   zip_year_incumbent_benchmarks_<DATE>.rds       (B)
#   bank_zip_year_advantage_<DATE>.rds             (C)
# =============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(duckdb)
})

data_dir          <- "tracks/first-draft-may2026/data"
ffiec_duckdb_path <- "C:/empirical-data-construction/call-reports-FFIEC/call-reports-ffiec.duckdb"
sod_duckdb_path   <- "C:/empirical-data-construction/sod/sod.duckdb"

if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)
today <- format(Sys.Date(), "%Y%m%d")

normalize_zip5 <- function(x) {
  x_chr <- gsub("[^0-9]", "", trimws(as.character(x)))
  out <- rep(NA_character_, length(x_chr))
  ok <- nzchar(x_chr)
  out[ok] <- sprintf("%05.0f", suppressWarnings(as.numeric(x_chr[ok])))
  out
}

load_latest <- function(glob) {
  hits <- Sys.glob(glob)
  if (length(hits) == 0L) return(NULL)
  hits[order(file.info(hits)$mtime, decreasing = TRUE)[1]]
}

winsor <- function(x, p = c(0.01, 0.99)) {
  q <- quantile(x, probs = p, na.rm = TRUE)
  pmin(pmax(x, q[[1]]), q[[2]])
}

con_ffiec <- function() dbConnect(duckdb::duckdb(), dbdir = ffiec_duckdb_path, read_only = TRUE)
con_sod   <- function() dbConnect(duckdb::duckdb(), dbdir = sod_duckdb_path,   read_only = TRUE)

# =============================================================================
# A. Bank-year advantage metrics (Q4)
# =============================================================================

cat("\n--- A. bank_year_advantage_metrics ---\n")

con <- con_ffiec()
sql <- "
  SELECT bs.id_rssd, bs.activity_year AS yr, bs.deposits,
         bs.assets AS total_assets,
         ip.ytdnonint_exp AS nonint_exp,
         ip.ytdint_inc_net AS int_inc_net,
         ip.ytdnonint_inc AS nonint_inc,
         TRY_CAST(ri.RIAD4073 AS DOUBLE) AS int_exp_total
  FROM bs_panel bs
  LEFT JOIN is_panel ip
    ON bs.idrssd = ip.idrssd AND bs.activity_year = ip.activity_year
   AND bs.activity_quarter = ip.activity_quarter
  LEFT JOIN schedule_ri ri
    ON bs.idrssd = ri.IDRSSD AND bs.activity_year = ri.activity_year
   AND bs.activity_quarter = ri.activity_quarter
  WHERE bs.activity_quarter = 4
    AND bs.activity_year BETWEEN 2003 AND 2025
    AND bs.deposits > 0
"
raw <- setDT(dbGetQuery(con, sql))
dbDisconnect(con, shutdown = TRUE)

raw[, rev := int_inc_net + nonint_inc]
raw[, eff_ratio := nonint_exp / rev]
raw <- raw[is.finite(eff_ratio) & rev > 0]
raw[, int_exp_assets := fifelse(
  is.finite(int_exp_total) & total_assets > 0,
  int_exp_total / total_assets, NA_real_
)]
raw <- raw[is.na(int_exp_assets) | (is.finite(int_exp_assets) & int_exp_assets >= 0)]
raw[, eff_ratio := winsor(eff_ratio), by = yr]
raw[!is.na(int_exp_assets), int_exp_assets := winsor(int_exp_assets), by = yr]

metrics <- raw[, .(id_rssd, yr, eff_ratio, int_exp_assets)]
metrics_path <- file.path(data_dir, paste0("bank_year_advantage_metrics_", today, ".rds"))
saveRDS(metrics, metrics_path)
cat("Wrote:", metrics_path, " rows=", nrow(metrics), "\n")

# =============================================================================
# B. Zip-year incumbent benchmarks (deposit-weighted) + branch-level file
# =============================================================================

cat("\n--- B. zip_year_incumbent_benchmarks ---\n")

con <- con_sod()
sod <- setDT(dbGetQuery(con, "
  SELECT RSSDID, YEAR AS yr_sod, ZIPBR, DEPSUMBR
  FROM sod
  WHERE YEAR BETWEEN 2003 AND 2024
    AND RSSDID IS NOT NULL
    AND DEPSUMBR > 0
"))
dbDisconnect(con, shutdown = TRUE)

sod[, zip5 := normalize_zip5(ZIPBR)]
sod <- sod[!is.na(zip5) & !is.na(RSSDID)]
sod[, yr_panel := yr_sod + 1L]

sod_m <- merge(
  sod, metrics[, .(id_rssd, yr, eff_ratio, int_exp_assets)],
  by.x = c("RSSDID", "yr_sod"), by.y = c("id_rssd", "yr"),
  all.x = FALSE
)
cat("SOD rows after metrics merge:", nrow(sod_m), "\n")

branches <- sod_m[, .(RSSDID, zip5, yr_sod, yr_panel, DEPSUMBR,
                      eff_ratio, int_exp_assets)]
branch_path <- file.path(data_dir, paste0("sod_branch_metrics_", today, ".rds"))
saveRDS(branches, branch_path)
cat("Wrote:", branch_path, "\n")

bench <- sod_m[, {
  ok_eff <- !is.na(eff_ratio)
  w_denom_eff <- sum(DEPSUMBR[ok_eff], na.rm = TRUE)
  ie <- if (w_denom_eff > 0)
    sum(eff_ratio[ok_eff] * DEPSUMBR[ok_eff], na.rm = TRUE) / w_denom_eff
  else NA_real_

  ok_iea <- !is.na(int_exp_assets)
  w_denom_iea <- sum(DEPSUMBR[ok_iea], na.rm = TRUE)
  ii <- if (w_denom_iea > 0)
    sum(int_exp_assets[ok_iea] * DEPSUMBR[ok_iea], na.rm = TRUE) / w_denom_iea
  else NA_real_

  .(incumb_eff_ratio_wt = ie, incumb_int_exp_assets_wt = ii,
    n_incumbents = .N, total_incumb_dep = sum(DEPSUMBR, na.rm = TRUE))
}, by = .(zip5, yr_panel)]
setnames(bench, "yr_panel", "yr")

bench_path <- file.path(data_dir, paste0("zip_year_incumbent_benchmarks_", today, ".rds"))
saveRDS(bench, bench_path)
cat("Wrote:", bench_path, " rows=", nrow(bench), "\n")

# =============================================================================
# C. Bank-zip-year advantage (focal-vs-incumbent, self-excluded)
# =============================================================================

cat("\n--- C. bank_zip_year_advantage ---\n")

panel_path <- load_latest(file.path(data_dir, "bank_year_zip_panel_*.rds"))
if (is.null(panel_path)) stop("Missing bank_year_zip_panel in local data/.")
panel <- setDT(readRDS(panel_path))
if ("YEAR" %in% names(panel)) setnames(panel, "YEAR", "yr")
panel[, zip5 := normalize_zip5(zip5)]
pk <- unique(panel[, .(RSSDID, yr, zip5)])
cat("Panel keys:", nrow(pk), "\n")

pk[, yr_lag := yr - 1L]
pk <- merge(
  pk,
  metrics[, .(id_rssd, yr,
              focal_eff_ratio      = eff_ratio,
              focal_int_exp_assets = int_exp_assets)],
  by.x = c("RSSDID", "yr_lag"), by.y = c("id_rssd", "yr"), all.x = TRUE
)
cat("Rows with focal eff_ratio non-NA:",
    pk[!is.na(focal_eff_ratio), .N], "/", nrow(pk), "\n")

pk <- merge(pk, bench, by = c("zip5", "yr"), all.x = TRUE)

# Self-exclusion
self_rows <- merge(
  pk[, .(RSSDID, yr, zip5)],
  branches[, .(RSSDID, zip5, yr = yr_panel, DEPSUMBR,
               self_eff_ratio      = eff_ratio,
               self_int_exp_assets = int_exp_assets)],
  by = c("RSSDID", "zip5", "yr"), all.x = FALSE
)

self_agg <- self_rows[, .(
  self_dep                = sum(DEPSUMBR, na.rm = TRUE),
  self_eff_ratio_avg      = weighted.mean(self_eff_ratio,      DEPSUMBR, na.rm = TRUE),
  self_int_exp_assets_avg = weighted.mean(self_int_exp_assets, DEPSUMBR, na.rm = TRUE)
), by = .(RSSDID, zip5, yr)]

pk <- merge(pk, self_agg, by = c("RSSDID", "zip5", "yr"), all.x = TRUE)
pk[is.na(self_dep), self_dep := 0]

pk[, incumb_eff_excl := fifelse(
  self_dep > 0 & !is.na(incumb_eff_ratio_wt),
  (incumb_eff_ratio_wt * total_incumb_dep - self_eff_ratio_avg * self_dep) /
    pmax(total_incumb_dep - self_dep, 1e-9),
  incumb_eff_ratio_wt
)]
pk[, rate_paying_adv := incumb_eff_excl - focal_eff_ratio]
pk[!is.na(rate_paying_adv), rate_paying_adv := winsor(rate_paying_adv), by = yr]

# IEA share-undercut via cross-join (memory-intensive)
incumbents <- branches[!is.na(int_exp_assets), .(
  bank_dep       = sum(DEPSUMBR, na.rm = TRUE),
  int_exp_assets = first(int_exp_assets)
), by = .(RSSDID, zip5, yr_panel)]
setnames(incumbents, c("RSSDID", "yr_panel"), c("RSSDID_inc", "yr"))
cat("Incumbent bank-zip-yr rows:", nrow(incumbents), "\n")

focal_keys <- pk[!is.na(focal_int_exp_assets),
                 .(RSSDID, yr, zip5, focal_int_exp_assets)]
xj <- merge(focal_keys, incumbents,
            by = c("zip5", "yr"), allow.cartesian = TRUE)
xj <- xj[RSSDID != RSSDID_inc]
cat("Cross-join rows after self-exclusion:", nrow(xj), "\n")

share_dt_iea <- xj[, .(
  total_inc_dep_excl_iea = sum(bank_dep, na.rm = TRUE),
  below_dep_iea          = sum(bank_dep[int_exp_assets < focal_int_exp_assets], na.rm = TRUE)
), by = .(RSSDID, yr, zip5)]
share_dt_iea[, int_exp_assets_share_undercut := fifelse(
  total_inc_dep_excl_iea > 0,
  below_dep_iea / total_inc_dep_excl_iea, NA_real_
)]

pk <- merge(pk, share_dt_iea[, .(RSSDID, yr, zip5, int_exp_assets_share_undercut)],
            by = c("RSSDID", "yr", "zip5"), all.x = TRUE)

out <- pk[, .(RSSDID, yr, zip5,
              rate_paying_adv, int_exp_assets_share_undercut,
              focal_eff_ratio, focal_int_exp_assets,
              incumb_eff_ratio_wt, incumb_int_exp_assets_wt, n_incumbents)]
adv_path <- file.path(data_dir, paste0("bank_zip_year_advantage_", today, ".rds"))
saveRDS(out, adv_path)
cat("Wrote:", adv_path, " rows=", nrow(out), "\n")

cat("\nDone (bank_advantage).\n")

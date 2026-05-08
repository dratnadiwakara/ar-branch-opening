# 01_build_deposit_beta.R
# =============================================================================
# Bank x zip x year deposit-beta panel.  Combines the six stages of
# code/approach-deposit-beta-april2026/01..06_*.R into a single self-contained
# script.  All inputs read from external DuckDB views + the local data/
# folder; all outputs written to the local data/ folder.
#
# Stages (run sequentially in this script):
#   A. Bank-quarter deposit-expense ratio at each cycle endpoint
#   B. Bank-cycle DV (deposit_exp_chg)
#   C. Bank-year December controls (assets, transaction, time, uninsured)
#   D. Bank-cycle deposit-weighted ZIP demographics
#   E. First-stage cycle regressions (predict deposit_exp_chg from demographics)
#   F. Impute bank x zip x year deposit_beta
#
# Outputs (all in tracks/public-data-results-may2026/data/):
#   bank_quarter_deposit_expense_<DATE>.rds        (A)
#   bank_cycle_dv_<DATE>.rds                       (B)
#   bank_year_dec_controls_<DATE>.rds              (C)
#   bank_cycle_demographics_<DATE>.rds             (D)
#   first_stage_models_<DATE>.rds                  (E)
#   bank_zip_year_deposit_beta_<DATE>.rds          (F)
# =============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(duckdb)
  library(fixest)
  library(readxl)
})

# ---- Paths -------------------------------------------------------------------

data_dir          <- "tracks/public-data-results-may2026/data"
ffiec_duckdb_path <- "C:/empirical-data-construction/call-reports-FFIEC/call-reports-ffiec.duckdb"
sod_duckdb_path   <- "C:/empirical-data-construction/sod/sod.duckdb"
irs_duckdb_path   <- "C:/empirical-data-construction/irs/irs.duckdb"
zip_county_path   <- "data/raw/ZIP_COUNTY_092020.xlsx"
zip_pop_density_path <- "data/raw/zip_population_density.rds"

if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)

today <- format(Sys.Date(), "%Y%m%d")

# ---- Helpers -----------------------------------------------------------------

normalize_zip5 <- function(x) {
  x_chr <- gsub("[^0-9]", "", trimws(as.character(x)))
  out <- rep(NA_character_, length(x_chr))
  ok <- nzchar(x_chr)
  out[ok] <- sprintf("%05.0f", suppressWarnings(as.numeric(x_chr[ok])))
  out
}

normalize_county_fips <- function(x) normalize_zip5(x)

load_latest <- function(glob) {
  hits <- Sys.glob(glob)
  if (length(hits) == 0L) return(NULL)
  hits[order(file.info(hits)$mtime, decreasing = TRUE)[1]]
}

winsor_drop <- function(x, p = 0.01) {
  q <- quantile(x, c(p, 1 - p), na.rm = TRUE)
  x >= q[1] & x <= q[2]
}

con_ffiec <- function() dbConnect(duckdb::duckdb(), dbdir = ffiec_duckdb_path, read_only = TRUE)
con_sod   <- function() dbConnect(duckdb::duckdb(), dbdir = sod_duckdb_path,   read_only = TRUE)
con_irs   <- function() dbConnect(duckdb::duckdb(), dbdir = irs_duckdb_path,   read_only = TRUE)

acs_proxy_year_for_2004 <- 2009L

cycles_definition <- list(
  cycle_0406 = list(cycle = "cycle_0406", start_date = as.Date("2004-03-31"),
                    end_date = as.Date("2006-03-31"), rate_change = 3.5,
                    demo_year = 2004L, apply_years = 2000:2015),
  cycle_1619 = list(cycle = "cycle_1619", start_date = as.Date("2016-03-31"),
                    end_date = as.Date("2019-03-31"), rate_change = 2.5,
                    demo_year = 2016L, apply_years = 2016:2021),
  cycle_2224 = list(cycle = "cycle_2224", start_date = as.Date("2022-03-31"),
                    end_date = as.Date("2023-03-31"), rate_change = 4.0,
                    demo_year = 2022L, apply_years = 2022:2026)
)

# =============================================================================
# A. Bank-quarter deposit-expense ratio
# =============================================================================

cat("\n--- A. bank_quarter_deposit_expense ---\n")

endpoint_dates <- sort(unique(unlist(lapply(
  cycles_definition, function(c) c(c$start_date, c$end_date)
))))
endpoint_dates <- as.Date(endpoint_dates, origin = "1970-01-01")

con <- con_ffiec()
sql <- sprintf("
  SELECT bs.id_rssd, bs.date, bs.activity_year, bs.activity_quarter, bs.deposits,
    4 * (
      COALESCE(TRY_CAST(ri.RIAD4508 AS DOUBLE), 0) +
      COALESCE(TRY_CAST(ri.RIAD0093 AS DOUBLE), 0) +
      CASE WHEN bs.activity_year >= 2017
        THEN COALESCE(TRY_CAST(ri.RIADHK03 AS DOUBLE), 0) +
             COALESCE(TRY_CAST(ri.RIADHK04 AS DOUBLE), 0)
        ELSE COALESCE(TRY_CAST(ri.RIADA517 AS DOUBLE), 0) +
             COALESCE(TRY_CAST(ri.RIADA518 AS DOUBLE), 0)
      END
    ) AS int_exp_dep_annual
  FROM bs_panel bs
  LEFT JOIN schedule_ri ri
    ON bs.idrssd = ri.IDRSSD
   AND bs.activity_year = ri.activity_year
   AND bs.activity_quarter = ri.activity_quarter
  WHERE bs.activity_quarter = 1
    AND bs.date IN ('%s')
", paste(format(endpoint_dates), collapse = "','"))

bank_q <- setDT(dbGetQuery(con, sql))
dbDisconnect(con, shutdown = TRUE)

bank_q <- bank_q[!is.na(deposits) & deposits > 0]
bank_q[, deposit_exp_deposits := 100 * int_exp_dep_annual / deposits]
bank_q <- bank_q[is.finite(deposit_exp_deposits)]

bq_out <- bank_q[, .(id_rssd, date, deposits, deposit_exp_deposits)]
bq_path <- file.path(data_dir, paste0("bank_quarter_deposit_expense_", today, ".rds"))
saveRDS(bq_out, bq_path)
cat("Wrote:", bq_path, " rows=", nrow(bq_out), "\n")

# =============================================================================
# B. Bank-cycle DV
# =============================================================================

cat("\n--- B. bank_cycle_dv ---\n")

cycle_dt_list <- list()
for (cycle_name in names(cycles_definition)) {
  cyc <- cycles_definition[[cycle_name]]
  sub <- bq_out[date %in% c(cyc$start_date, cyc$end_date)]
  wide <- dcast(sub, id_rssd ~ date, value.var = "deposit_exp_deposits")
  setnames(wide, c("id_rssd", "dep_exp_start", "dep_exp_end"))
  wide <- wide[!is.na(dep_exp_start) & !is.na(dep_exp_end)]
  wide[, deposit_exp_chg := dep_exp_end - dep_exp_start]
  wide[, cycle := cycle_name]
  keep <- winsor_drop(wide$deposit_exp_chg, p = 0.01)
  wide <- wide[keep]
  cat(sprintf("%s: %d banks, mean chg=%.4f (beta=%.3f)\n", cycle_name, nrow(wide),
              mean(wide$deposit_exp_chg), mean(wide$deposit_exp_chg) / cyc$rate_change))
  cycle_dt_list[[cycle_name]] <- wide[, .(id_rssd, cycle, deposit_exp_chg,
                                          dep_exp_start, dep_exp_end)]
}
cycle_dv <- rbindlist(cycle_dt_list)
dv_path <- file.path(data_dir, paste0("bank_cycle_dv_", today, ".rds"))
saveRDS(cycle_dv, dv_path)
cat("Wrote:", dv_path, " rows=", nrow(cycle_dv), "\n")

# =============================================================================
# C. Bank-year December controls
# =============================================================================

cat("\n--- C. bank_year_dec_controls ---\n")

con <- con_ffiec()
sql <- sprintf("
  SELECT bs.id_rssd, bs.activity_year AS yr, bs.assets AS bank_assets,
         bs.deposits, bs.transaction_dep,
    CASE WHEN bs.activity_year >= 2010
      THEN COALESCE(TRY_CAST(rce.RCONJ473 AS DOUBLE), 0) +
           COALESCE(TRY_CAST(rce.RCONJ474 AS DOUBLE), 0) +
           COALESCE(TRY_CAST(rce.RCON6648 AS DOUBLE), 0)
      ELSE COALESCE(TRY_CAST(rce.RCON2604 AS DOUBLE), 0) +
           COALESCE(TRY_CAST(rce.RCON6648 AS DOUBLE), 0)
    END AS time_deposits_total,
    TRY_CAST(rco.RCONF049 AS DOUBLE) AS deposits_uninsured,
    TRY_CAST(rco.RCONF045 AS DOUBLE) AS deposits_insured
  FROM bs_panel bs
  LEFT JOIN schedule_rce rce
    ON bs.idrssd = rce.IDRSSD AND bs.activity_year = rce.activity_year
   AND bs.activity_quarter = rce.activity_quarter
  LEFT JOIN schedule_rco rco
    ON bs.idrssd = rco.IDRSSD AND bs.activity_year = rco.activity_year
   AND bs.activity_quarter = rco.activity_quarter
  WHERE bs.activity_quarter = 4
    AND bs.activity_year BETWEEN %d AND %d
", 2003L, 2025L)

bd <- setDT(dbGetQuery(con, sql))
dbDisconnect(con, shutdown = TRUE)

bd <- bd[!is.na(bank_assets) & bank_assets > 0]
bd[, trans_accts_frac_assets := pmin(transaction_dep / bank_assets, 1)]
bd[, time_deposits_assets    := pmin(time_deposits_total / bank_assets, 1)]
bd[, uninsured_total         := deposits_uninsured + deposits_insured]
bd[, uninsured_deposits_frac := fifelse(
  !is.na(uninsured_total) & uninsured_total > 0,
  pmin(deposits_uninsured / uninsured_total, 1),
  NA_real_
)]
ctrls_out <- bd[, .(id_rssd, yr, bank_assets, trans_accts_frac_assets,
                    time_deposits_assets, uninsured_deposits_frac)]
setorder(ctrls_out, id_rssd, yr)
ctrls_out[, uninsured_deposits_frac := nafill(uninsured_deposits_frac, type = "nocb"), by = id_rssd]

ctrl_path <- file.path(data_dir, paste0("bank_year_dec_controls_", today, ".rds"))
saveRDS(ctrls_out, ctrl_path)
cat("Wrote:", ctrl_path, " rows=", nrow(ctrls_out), "\n")

# =============================================================================
# D. Bank-cycle demographics (deposit-weighted ZIP)
# =============================================================================

cat("\n--- D. bank_cycle_demographics ---\n")

demo_years <- sort(unique(vapply(cycles_definition, `[[`, integer(1), "demo_year")))
hhi_years  <- sort(unique(c(demo_years, demo_years - 1L)))

con <- con_sod()
sod <- setDT(dbGetQuery(con, sprintf("
  SELECT RSSDID, YEAR AS yr, STCNTYBR, ZIPBR, DEPSUMBR
  FROM sod
  WHERE YEAR IN (%s)
    AND RSSDID IS NOT NULL
", paste(hhi_years, collapse = ","))))
dbDisconnect(con, shutdown = TRUE)
sod[, zip5 := normalize_zip5(ZIPBR)]
sod[, STCNTYBR := normalize_county_fips(STCNTYBR)]
sod <- sod[!is.na(zip5) & !is.na(STCNTYBR)]

county_hhi <- sod[, .(deposits_rssd = sum(DEPSUMBR, na.rm = TRUE)),
                  by = .(STCNTYBR, yr, RSSDID)]
county_hhi[, total := sum(deposits_rssd, na.rm = TRUE), by = .(STCNTYBR, yr)]
county_hhi[, share := deposits_rssd / total]
county_hhi <- county_hhi[, .(county_hhi_raw = sum(share^2, na.rm = TRUE)),
                         by = .(STCNTYBR, yr)]
county_hhi[, yr := yr + 1L]
setnames(county_hhi, "county_hhi_raw", "county_hhi")

acs_path <- load_latest("data/constructed/zip_year_acs_panel_*.rds")
if (is.null(acs_path)) stop("Missing zip_year_acs_panel in data/constructed/")
acs <- readRDS(acs_path); setDT(acs); acs[, zip5 := normalize_zip5(zip5)]

popden <- readRDS(zip_pop_density_path); setDT(popden); popden[, zip5 := normalize_zip5(zip5)]

con <- con_irs()
irs <- setDT(dbGetQuery(con, sprintf("
  SELECT zipcode AS zip5, year AS yr, dividend_frac
  FROM irs
  WHERE year IN (%s)
", paste(unique(c(demo_years, demo_years - 1L)), collapse = ","))))
dbDisconnect(con, shutdown = TRUE)
irs[, zip5 := normalize_zip5(zip5)]

bank_cycle_list <- list()
for (cycle_name in names(cycles_definition)) {
  cyc <- cycles_definition[[cycle_name]]
  dy  <- cyc$demo_year
  acs_yr <- if (dy == 2004L) acs_proxy_year_for_2004 else (dy - 1L)
  irs_yr <- if (dy == 2004L) 2004L else (dy - 1L)

  sod_dy <- sod[yr == dy, .(RSSDID, STCNTYBR, zip5, DEPSUMBR)]
  dt <- merge(sod_dy, acs[yr == acs_yr,
    .(zip5, median_income, median_age, pct_college_educated, deposit_hhi_zip)],
    by = "zip5", all.x = FALSE)
  dt <- merge(dt, popden[yr == acs_yr, .(zip5, population_density)], by = "zip5", all.x = TRUE)
  dt <- merge(dt, irs[yr == irs_yr, .(zip5, dividend_frac)], by = "zip5", all.x = TRUE)
  dt <- merge(dt, county_hhi[yr == dy, .(STCNTYBR, county_hhi)], by = "STCNTYBR", all.x = TRUE)

  dt[, college_frac := pct_college_educated / 100]
  dt[, family_income := median_income]
  dt[, age := median_age]
  age_q <- quantile(dt$age, c(0.25, 0.5, 0.75), na.rm = TRUE)
  dt[, age_bin := as.integer(cut(age, breaks = c(-Inf, age_q, Inf), labels = FALSE))]
  med_col <- median(dt$college_frac, na.rm = TRUE)
  med_div <- median(dt$dividend_frac, na.rm = TRUE)
  dt[, sophisticated := as.integer(college_frac >= med_col & dividend_frac >= med_div)]

  demo_cols <- c("college_frac", "dividend_frac", "family_income", "population_density",
                 "age", "age_bin", "sophisticated", "county_hhi")
  dt <- dt[complete.cases(dt[, ..demo_cols])]
  dt <- dt[!is.na(DEPSUMBR) & DEPSUMBR > 0]
  dt[, w := DEPSUMBR / sum(DEPSUMBR, na.rm = TRUE), by = RSSDID]

  bank_agg <- dt[, .(
    college_frac       = sum(college_frac * w),
    dividend_frac      = sum(dividend_frac * w),
    family_income      = sum(family_income * w),
    population_density = sum(population_density * w),
    age                = sum(age * w),
    age_bin            = { ws <- tapply(w, age_bin, sum); as.integer(names(ws)[which.max(ws)]) },
    sophisticated_frac = sum(sophisticated * w),
    bank_hhi           = sum(county_hhi * w),
    n_branches         = .N,
    total_deposits_dy  = sum(DEPSUMBR, na.rm = TRUE)
  ), by = RSSDID]
  setnames(bank_agg, "RSSDID", "id_rssd")
  bank_agg[, cycle := cycle_name]
  bank_agg[, factor_age_bin := factor(age_bin)]
  cat(sprintf("%s: %d banks (demo_year=%d)\n", cycle_name, nrow(bank_agg), dy))
  bank_cycle_list[[cycle_name]] <- bank_agg
}

demos <- rbindlist(bank_cycle_list, use.names = TRUE, fill = TRUE)
demo_path <- file.path(data_dir, paste0("bank_cycle_demographics_", today, ".rds"))
saveRDS(demos, demo_path)
cat("Wrote:", demo_path, " rows=", nrow(demos), "\n")

# =============================================================================
# E. First-stage cycle regressions
# =============================================================================

cat("\n--- E. first_stage_models ---\n")

fml_full <- deposit_exp_chg ~ factor_age_bin + dividend_frac + college_frac +
  log(family_income) + bank_hhi + log(bank_assets) + population_density +
  trans_accts_frac_assets + uninsured_deposits_frac + time_deposits_assets

fml_soph <- deposit_exp_chg ~ sophisticated_frac + factor_age_bin +
  log(family_income) + bank_hhi + log(bank_assets) + population_density +
  trans_accts_frac_assets + uninsured_deposits_frac + time_deposits_assets

first_stage <- list()
for (cycle_name in names(cycles_definition)) {
  cyc <- cycles_definition[[cycle_name]]
  cycle_dv   <- cycle_dv[cycle == cycle_name]
  cycle_ctrl <- ctrls_out[yr == cyc$demo_year,
    .(id_rssd, bank_assets, trans_accts_frac_assets,
      time_deposits_assets, uninsured_deposits_frac)]
  cycle_demo <- demos[cycle == cycle_name]

  dt <- merge(cycle_dv[, .(id_rssd, deposit_exp_chg)], cycle_demo, by = "id_rssd")
  dt <- merge(dt, cycle_ctrl, by = "id_rssd")
  dt <- dt[bank_assets > 0]
  cat(sprintf("%s: merged n=%d\n", cycle_name, nrow(dt)))

  reg_full <- feols(fml_full, data = dt, notes = FALSE)
  reg_soph <- feols(fml_soph, data = dt, notes = FALSE)

  first_stage[[cycle_name]] <- list(
    cycle       = cycle_name,
    rate_change = cyc$rate_change,
    demo_year   = cyc$demo_year,
    reg_full    = reg_full,
    reg_soph    = reg_soph
  )

  # Re-fetch cycle_dv from the original (loop overwrote local binding above);
  # actually reload from disk to be safe.
  cycle_dv <- readRDS(dv_path); setDT(cycle_dv)
}

fs_path <- file.path(data_dir, paste0("first_stage_models_", today, ".rds"))
saveRDS(first_stage, fs_path)
cat("Wrote:", fs_path, "\n")

# =============================================================================
# F. Impute bank-zip-year deposit beta
# =============================================================================

cat("\n--- F. bank_zip_year_deposit_beta ---\n")

panel_path <- load_latest(file.path(data_dir, "bank_year_zip_panel_*.rds"))
if (is.null(panel_path)) stop("Missing bank_year_zip_panel in local data/.")
p <- readRDS(panel_path); setDT(p)
if ("YEAR" %in% names(p)) setnames(p, "YEAR", "yr")
cat("Panel rows:", nrow(p), "\n")

pk <- unique(p[, .(RSSDID, yr, zip5)])
cat("Unique (RSSDID, yr, zip5):", nrow(pk), "\n")
pk[, zip5 := normalize_zip5(zip5)]

# Re-pull pop density / acs / IRS for full year range.
con <- con_irs()
irs_full <- setDT(dbGetQuery(con,
  "SELECT zipcode AS zip5, year AS yr, dividend_frac FROM irs"))
dbDisconnect(con, shutdown = TRUE)
irs_full[, zip5 := normalize_zip5(zip5)]
irs_max_yr <- irs_full[, max(yr, na.rm = TRUE)]
if (irs_max_yr < 2026L) {
  fill <- irs_full[yr == irs_max_yr]
  for (y in (irs_max_yr + 1L):2026L) {
    irs_full <- rbind(irs_full, copy(fill)[, yr := y])
  }
}

# County HHI across all panel years
con <- con_sod()
sod_hhi_src <- setDT(dbGetQuery(con, "
  SELECT RSSDID, YEAR AS yr, STCNTYBR, DEPSUMBR
  FROM sod
  WHERE YEAR BETWEEN 2000 AND 2025
    AND RSSDID IS NOT NULL
"))
dbDisconnect(con, shutdown = TRUE)
sod_hhi_src[, STCNTYBR := normalize_county_fips(STCNTYBR)]

county_hhi_full <- sod_hhi_src[, .(deposits_rssd = sum(DEPSUMBR, na.rm = TRUE)),
                               by = .(STCNTYBR, yr, RSSDID)]
county_hhi_full[, total := sum(deposits_rssd, na.rm = TRUE), by = .(STCNTYBR, yr)]
county_hhi_full[, share := deposits_rssd / total]
county_hhi_full <- county_hhi_full[, .(county_hhi = sum(share^2, na.rm = TRUE)),
                                   by = .(STCNTYBR, yr)]
county_hhi_full[, yr := yr + 1L]

zxc <- setDT(read_xlsx(zip_county_path))
setnames(zxc, tolower(names(zxc)))
zxc[, zip5 := normalize_zip5(zip)]
zxc[, county := normalize_county_fips(county)]
if ("res_ratio" %in% names(zxc)) {
  setorder(zxc, zip5, -res_ratio)
} else {
  setorder(zxc, zip5)
}
zip_to_county <- unique(zxc, by = "zip5")[, .(zip5, STCNTYBR = county)]

ctrls_panel <- copy(ctrls_out); setnames(ctrls_panel, "id_rssd", "RSSDID")

age_breaks <- quantile(acs$median_age, c(0.25, 0.5, 0.75), na.rm = TRUE)

pk[, acs_lookup_yr  := pmax(yr - 1L, 2009L)]
pk[, irs_lookup_yr  := yr - 1L]
pk[, ctrl_lookup_yr := yr - 1L]

pk <- merge(pk, zip_to_county, by = "zip5", all.x = TRUE)
pk <- merge(pk, acs[, .(zip5, yr, median_income, median_age, pct_college_educated)],
            by.x = c("zip5", "acs_lookup_yr"), by.y = c("zip5", "yr"), all.x = TRUE)
pk <- merge(pk, popden[, .(zip5, yr, population_density)],
            by.x = c("zip5", "acs_lookup_yr"), by.y = c("zip5", "yr"), all.x = TRUE)
pk <- merge(pk, irs_full[, .(zip5, yr, dividend_frac)],
            by.x = c("zip5", "irs_lookup_yr"), by.y = c("zip5", "yr"), all.x = TRUE)
pk <- merge(pk, county_hhi_full[, .(STCNTYBR, yr, county_hhi)],
            by.x = c("STCNTYBR", "ctrl_lookup_yr"), by.y = c("STCNTYBR", "yr"), all.x = TRUE)
pk <- merge(pk, ctrls_panel,
            by.x = c("RSSDID", "ctrl_lookup_yr"), by.y = c("RSSDID", "yr"), all.x = TRUE)

pk[, college_frac  := pct_college_educated / 100]
pk[, family_income := median_income]
pk[, age           := median_age]
pk[, bank_hhi      := county_hhi]
pk[, age_bin       := as.integer(cut(age, breaks = c(-Inf, age_breaks, Inf), labels = FALSE))]
pk[, factor_age_bin := factor(age_bin, levels = 1:4)]

needed <- c("factor_age_bin", "dividend_frac", "college_frac", "family_income",
            "bank_hhi", "bank_assets", "population_density",
            "trans_accts_frac_assets", "uninsured_deposits_frac",
            "time_deposits_assets")
ok <- rowSums(is.na(pk[, ..needed])) == 0
cat("Rows with complete inputs:", sum(ok), "/", nrow(pk), "\n")

build_X <- function(dt) {
  model.matrix(
    ~ factor_age_bin + dividend_frac + college_frac +
      log(family_income) + bank_hhi + log(bank_assets) + population_density +
      trans_accts_frac_assets + uninsured_deposits_frac + time_deposits_assets,
    data = as.data.frame(dt)
  )
}

predict_linear <- function(mm, reg) {
  cf <- coef(reg)
  common <- intersect(colnames(mm), names(cf))
  if (length(common) != ncol(mm)) {
    missing_cols <- setdiff(colnames(mm), names(cf))
    stop("Coefficient vector missing columns: ", paste(missing_cols, collapse = ", "))
  }
  as.numeric(mm[, common, drop = FALSE] %*% cf[common])
}

pk[, pred_cycle_0406 := NA_real_]
pk[, pred_cycle_1619 := NA_real_]
pk[, pred_cycle_2224 := NA_real_]

sub_ok <- pk[ok]
mm <- build_X(sub_ok)
pk[ok, pred_cycle_0406 := predict_linear(mm, first_stage$cycle_0406$reg_full)]
pk[ok, pred_cycle_1619 := predict_linear(mm, first_stage$cycle_1619$reg_full)]
pk[ok, pred_cycle_2224 := predict_linear(mm, first_stage$cycle_2224$reg_full)]

pk[, deposit_beta := fifelse(
  yr <= 2015L,
  pred_cycle_0406 / cycles_definition$cycle_0406$rate_change,
  fifelse(yr <= 2021L,
          pred_cycle_1619 / cycles_definition$cycle_1619$rate_change,
          pred_cycle_2224 / cycles_definition$cycle_2224$rate_change))]

out <- pk[, .(RSSDID, yr, zip5, deposit_beta,
              pred_cycle_0406, pred_cycle_1619, pred_cycle_2224)]
cat("Rows with non-NA deposit_beta:",
    out[, sum(!is.na(deposit_beta) & is.finite(deposit_beta))], "\n")

beta_path <- file.path(data_dir, paste0("bank_zip_year_deposit_beta_", today, ".rds"))
saveRDS(out, beta_path)
cat("\nWrote:", beta_path, " rows=", nrow(out), "\n")

cat("\nDone (deposit_beta).\n")

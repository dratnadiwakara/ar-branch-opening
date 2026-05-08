# 04_build_master_dataset.R
# =============================================================================
# Build the bank-zip-year master panel by joining the local outputs of
# 00_build_panel.R, 01_build_deposit_beta.R, 02_build_bank_advantage.R, and
# 03_build_cross_sell.R.  Adds a bank-year `bank_assets` column from SOD ASSET
# (used downstream by 05 to assign the row to a size bucket).
#
# Forked from code/approach-public-data-april2026/00_build_master_dataset.R.
# Differences:
#   - Reads upstream .rds from local data/ (not data/constructed/).
#   - Writes outputs to local data/.
#   - Adds `bank_assets` column from SOD aggregated by (RSSDID, yr).
#
# Output (in tracks/public-data-results-may2026/data/):
#   master_bank_zip_year_<DATE>_part01..08.rds   (split for 45 MB cap)
#   bank_cycle_first_stage_<DATE>.rds            (used by 05 first-stage table)
# =============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(duckdb)
})

source("tracks/public-data-results-may2026/code/common_public_data.R")

sod_duckdb_path <- "C:/empirical-data-construction/sod/sod.duckdb"

pick <- function(glob) load_latest(file.path(data_dir, glob))

normalize_zip5 <- function(x) {
  x_chr <- gsub("[^0-9]", "", trimws(as.character(x)))
  out <- rep(NA_character_, length(x_chr))
  ok  <- nzchar(x_chr)
  out[ok] <- sprintf("%05.0f", suppressWarnings(as.numeric(x_chr[ok])))
  out
}

# =============================================================================
# 1. Bank-zip-year master panel
# =============================================================================

cat("\n--- Building master_bank_zip_year ---\n")

panel_path <- pick("bank_year_zip_panel_*.rds")
cat("Panel       :", panel_path, "\n")
dt <- setDT(readRDS(panel_path))
if ("YEAR" %in% names(dt)) setnames(dt, "YEAR", "yr")
dt[, zip5 := normalize_zip5(zip5)]

beta_path <- pick("bank_zip_year_deposit_beta_*.rds")
cat("Deposit beta:", beta_path, "\n")
bb <- setDT(readRDS(beta_path))
bb[, zip5 := normalize_zip5(zip5)]
dt <- merge(dt, bb[, .(RSSDID, yr, zip5, deposit_beta)],
            by = c("RSSDID", "yr", "zip5"), all.x = TRUE)

adv_path <- pick("bank_zip_year_advantage_*.rds")
cat("Advantage   :", adv_path, "\n")
adv <- setDT(readRDS(adv_path))
adv[, zip5 := normalize_zip5(zip5)]
dt <- merge(dt, adv[, .(RSSDID, yr, zip5, rate_paying_adv,
                        int_exp_assets_share_undercut)],
            by = c("RSSDID", "yr", "zip5"), all.x = TRUE)

hmda_path <- pick("bank_zip_year_mortgage_beachhead_*.rds")
cat("Mortgage    :", hmda_path, "\n")
hmda <- setDT(readRDS(hmda_path))
hmda[, zip5 := normalize_zip5(zip5)]
dt[, yr_lag := yr - 1L]
dt <- merge(dt,
            hmda[, .(id_rssd, yr, zip5,
                     mortgage_share    = mortgage_mktshare,
                     mortgage_presence = mortgage_beachhead)],
            by.x = c("RSSDID", "yr_lag", "zip5"),
            by.y = c("id_rssd", "yr",    "zip5"),
            all.x = TRUE)

cra_path <- pick("bank_zip_year_cra_beachhead_*.rds")
cat("CRA         :", cra_path, "\n")
cra <- setDT(readRDS(cra_path))
cra[, zip5 := normalize_zip5(zip5)]
dt <- merge(dt,
            cra[, .(id_rssd, yr, zip5,
                    cra_share    = cra_county_share,
                    cra_presence = cra_beachhead)],
            by.x = c("RSSDID", "yr_lag", "zip5"),
            by.y = c("id_rssd", "yr",    "zip5"),
            all.x = TRUE)

dt[is.na(mortgage_presence), mortgage_presence := 0L]
dt[is.na(mortgage_share),    mortgage_share    := 0]
dt[is.na(cra_presence),      cra_presence      := 0L]
dt[is.na(cra_share),         cra_share         := 0]
dt[, yr_lag := NULL]

# ---- BHC parent + bank-year assets from SOD --------------------------------

cat("BHC + assets: ", sod_duckdb_path, "\n")
con <- dbConnect(duckdb::duckdb(), dbdir = sod_duckdb_path, read_only = TRUE)
sod_meta <- setDT(dbGetQuery(con, "
  SELECT
    RSSDID,
    YEAR AS yr,
    MAX(RSSDHCR) AS bhc_rssd,
    MAX(NAMEHCR) AS bhc_name,
    MAX(ASSET)   AS asset_thousands
  FROM sod
  WHERE RSSDID IS NOT NULL
  GROUP BY 1, 2
"))
dbDisconnect(con, shutdown = TRUE)

sod_meta[is.na(bhc_rssd) | bhc_rssd == 0, bhc_rssd := RSSDID]
sod_meta[is.na(bhc_name) | nchar(trimws(bhc_name)) == 0,
         bhc_name := NA_character_]
sod_meta[, bank_assets := as.numeric(asset_thousands) * 1000]
sod_meta[, asset_thousands := NULL]

dt <- merge(dt, sod_meta, by = c("RSSDID", "yr"), all.x = TRUE)
dt[is.na(bhc_rssd), bhc_rssd := RSSDID]

# Coverage
n_assets_na <- sum(is.na(dt$bank_assets))
cat("bank_assets NA rows:", n_assets_na, "/", nrow(dt),
    " (", round(100 * n_assets_na / nrow(dt), 2), "%)\n", sep = "")

# ---- Trim to columns needed downstream --------------------------------------

keep_cols <- c(
  "RSSDID", "yr", "zip5", "state_fips",
  "bhc_rssd", "bhc_name", "bank_assets",
  "n_branches_bzt", "dep_b_zip", "share_bzt", "bank_in_state_bzt",
  "dep_zip_total_lag1", "dep_zip_total_lag3",
  "hmda_amt_lag1", "hmda_amt_lag3",
  "cra_amt_lag1",  "cra_amt_lag3",
  "avg_agi_lag1",
  "median_age_lag1", "pct_college_educated_lag1",
  "log_pop_density_lag1",
  "deposit_hhi_zip_lag1", "no_bank_zip_lag1",
  "deposit_beta",
  "rate_paying_adv", "int_exp_assets_share_undercut",
  "mortgage_presence", "mortgage_share",
  "cra_presence",      "cra_share"
)

missing <- setdiff(keep_cols, names(dt))
if (length(missing) > 0L) stop("Master is missing columns: ",
                               paste(missing, collapse = ", "))

dt <- dt[, ..keep_cols]
cat("Master rows:", nrow(dt), " | columns:", ncol(dt), "\n")

# ---- Coverage report --------------------------------------------------------

cov_report <- function(x) {
  if (is.character(x)) sum(nzchar(x) & !is.na(x))
  else                 sum(!is.na(x) & is.finite(x))
}
cov_dt <- data.table(
  column   = names(dt),
  non_na_n = vapply(dt, cov_report, integer(1)),
  total    = nrow(dt)
)
cov_dt[, non_na_pct := round(100 * non_na_n / total, 1)]
print(cov_dt)

# Bucket coverage diagnostic.
dt[, size_bucket := assign_bucket(bank_assets)]
cat("\nRows per size bucket:\n")
print(dt[, .N, by = size_bucket])
dt[, size_bucket := NULL]

# ---- Save split parts -------------------------------------------------------

today <- format(Sys.Date(), "%Y%m%d")

n_parts    <- 8L
chunk_size <- ceiling(nrow(dt) / n_parts)
written    <- character(0)
for (i in seq_len(n_parts)) {
  start <- (i - 1L) * chunk_size + 1L
  end   <- min(i * chunk_size, nrow(dt))
  if (start > nrow(dt)) break
  out_part <- file.path(
    data_dir,
    sprintf("master_bank_zip_year_%s_part%02d.rds", today, i)
  )
  saveRDS(dt[start:end], out_part)
  size_mb <- round(file.info(out_part)$size / (1024 * 1024), 1)
  cat(sprintf("Part %02d: rows=%d  size=%.1f MB  %s\n",
              i, end - start + 1L, size_mb, out_part))
  written <- c(written, out_part)
}

# Remove any old monolithic master_*.rds (no _partNN suffix).
old_mono <- list.files(data_dir,
                       pattern = "^master_bank_zip_year_\\d{8}\\.rds$",
                       full.names = TRUE)
if (length(old_mono) > 0L) {
  cat("Removing monolithic master file(s):\n")
  for (f in old_mono) { cat("  ", f, "\n"); file.remove(f) }
}

# =============================================================================
# 2. Bank-cycle first-stage dataset (deposit beta)
# =============================================================================

cat("\n--- Building bank_cycle_first_stage ---\n")

dv_path    <- pick("bank_cycle_dv_*.rds")
demo_path  <- pick("bank_cycle_demographics_*.rds")
ctrl_path  <- pick("bank_year_dec_controls_*.rds")
cat("DV     :", dv_path,   "\n")
cat("Demos  :", demo_path, "\n")
cat("Ctrls  :", ctrl_path, "\n")

dv     <- setDT(readRDS(dv_path))
demos  <- setDT(readRDS(demo_path))
ctrls  <- setDT(readRDS(ctrl_path))

cycles_definition <- list(
  cycle_0406 = list(start_date = as.Date("2004-03-31"),
                    end_date   = as.Date("2006-03-31"),
                    rate_change = 3.5, demo_year = 2004L),
  cycle_1619 = list(start_date = as.Date("2016-03-31"),
                    end_date   = as.Date("2019-03-31"),
                    rate_change = 2.5, demo_year = 2016L),
  cycle_2224 = list(start_date = as.Date("2022-03-31"),
                    end_date   = as.Date("2023-03-31"),
                    rate_change = 4.0, demo_year = 2022L)
)

bc_pieces <- list()
for (cycle_name in names(cycles_definition)) {
  cyc <- cycles_definition[[cycle_name]]
  cycle_dv   <- dv[cycle == cycle_name, .(id_rssd, deposit_exp_chg)]
  cycle_ctrl <- ctrls[yr == cyc$demo_year,
                      .(id_rssd, bank_assets, trans_accts_frac_assets,
                        time_deposits_assets, uninsured_deposits_frac)]
  cycle_demo <- demos[cycle == cycle_name]

  cdt <- merge(cycle_dv, cycle_demo, by = "id_rssd")
  cdt <- merge(cdt, cycle_ctrl, by = "id_rssd")
  cdt <- cdt[bank_assets > 0]
  cdt[, rate_change := cyc$rate_change]
  bc_pieces[[cycle_name]] <- cdt
}

bc <- rbindlist(bc_pieces, use.names = TRUE, fill = TRUE)
cat("First-stage rows:", nrow(bc), " | by cycle:\n"); print(bc[, .N, by = cycle])

out_bc <- file.path(data_dir, paste0("bank_cycle_first_stage_", today, ".rds"))
saveRDS(bc, out_bc)
cat("Wrote:", out_bc, "\n")

cat("\nDone.\n")

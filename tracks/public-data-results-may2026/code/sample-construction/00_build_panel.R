# 00_build_panel.R
# =============================================================================
# Bank-year-zip opportunity-set panel for ALL banks with max assets ever
# >= $1B (lowered from the $50B threshold used by the main pipeline so the
# $1B-$10B and $10B-$100B size buckets have full coverage).
#
# Forked from code/approach-baseline-regression/01_build_bank_year_zip_panel_*.R.
# Only edits:
#   - large_bank_threshold_dollars : 50e9 -> 1e9
#   - out_dir                       : data/constructed -> local data/
#
# All other inputs (CBSA xwalk, ZIP_COUNTY xwalk, tract_zip xwalk, IRS,
# HMDA, CRA, SOD, ACS panel, zip pop density) are read from their existing
# project-level locations -- they are zip-level public data, independent of
# the bank-size threshold, so no need to rebuild here.
#
# Output: tracks/public-data-results-may2026/data/bank_year_zip_panel_<DATE>.rds
# =============================================================================

rm(list = ls())

library(data.table)
library(readxl)
library(DBI)
library(duckdb)

# ---- Parameters --------------------------------------------------------------

sod_duckdb_path        <- "C:/empirical-data-construction/sod/sod.duckdb"
hmda_duckdb_path       <- "C:/empirical-data-construction/hmda/hmda.duckdb"
cra_duckdb_path        <- "C:/empirical-data-construction/cra/cra.duckdb"
irs_duckdb_path        <- "C:/empirical-data-construction/irs/irs.duckdb"
cbsa_xwalk_path        <- "data/raw/cbsa2fipsxw.csv"
zip_county_xwalk_path  <- "data/raw/ZIP_COUNTY_092020.xlsx"
tract_zip_xwalk_path   <- "data/raw/tract_zip_122019.xlsx"
zip_pop_density_path   <- "data/raw/zip_population_density.rds"
zip_acs_panel_glob     <- "data/constructed/zip_year_acs_panel_*.rds"

start_year                   <- 2009L
end_year                     <- 2026L
large_bank_threshold_dollars <- 1e9             # $1B max-asset cutoff (was 50e9)
out_dir                      <- "tracks/public-data-results-may2026/data"

# ---- Pre-flight --------------------------------------------------------------

for (p in c(sod_duckdb_path, hmda_duckdb_path, cra_duckdb_path, irs_duckdb_path,
            cbsa_xwalk_path, zip_county_xwalk_path, tract_zip_xwalk_path,
            zip_pop_density_path)) {
  if (!file.exists(p)) stop("Missing input: ", p, call. = FALSE)
}
if (length(Sys.glob(zip_acs_panel_glob)) == 0L) {
  stop("Missing input: ", zip_acs_panel_glob, call. = FALSE)
}
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

normalize_zip5 <- function(x) {
  x_chr <- gsub("[^0-9]", "", trimws(as.character(x)))
  out <- rep(NA_character_, length(x_chr))
  ok <- nzchar(x_chr)
  out[ok] <- sprintf("%05.0f", suppressWarnings(as.numeric(x_chr[ok])))
  out
}

normalize_county_fips <- function(x) {
  x_chr <- gsub("[^0-9]", "", trimws(as.character(x)))
  out <- rep(NA_character_, length(x_chr))
  ok <- nzchar(x_chr)
  out[ok] <- sprintf("%05.0f", suppressWarnings(as.numeric(x_chr[ok])))
  out
}

# ---- Load SOD via DuckDB harmonized view -------------------------------------

con <- dbConnect(duckdb::duckdb(), dbdir = sod_duckdb_path, read_only = TRUE)
sod <- setDT(dbGetQuery(con, sprintf("
  SELECT RSSDID, YEAR, STCNTYBR, ZIPBR, DEPSUMBR, ASSET
  FROM sod
  WHERE YEAR BETWEEN %d AND %d
    AND RSSDID IS NOT NULL
", start_year, end_year)))

uninumbr_hist <- setDT(dbGetQuery(con, "
  SELECT RSSDID, MIN(YEAR) AS first_year
  FROM sod
  WHERE RSSDID IS NOT NULL AND UNINUMBR IS NOT NULL AND YEAR <= 2011
  GROUP BY RSSDID, UNINUMBR
"))
dbDisconnect(con, shutdown = TRUE)

ots_flag <- uninumbr_hist[, .(
  has_new_2011      = any(first_year == 2011L),
  has_new_2004_2010 = any(first_year >= 2004L & first_year <= 2010L)
), by = RSSDID]
ots_transfer_rssd <- ots_flag[has_new_2011 & !has_new_2004_2010, RSSDID]

message("OTS-transfer RSSDIDs excluded: ", length(ots_transfer_rssd))
sod <- sod[!(RSSDID %in% ots_transfer_rssd)]

sod[, YEAR        := as.integer(YEAR)]
sod[, county_fips := normalize_county_fips(STCNTYBR)]
sod[, zip5        := normalize_zip5(ZIPBR)]
sod[, deposits    := as.numeric(DEPSUMBR) * 1000]
sod[, assets      := as.numeric(ASSET)    * 1000]

# ---- Identify banks above $1B max-ever threshold ----------------------------

large_rssd <- sod[
  ,
  .(max_assets = max(assets, na.rm = TRUE)),
  by = RSSDID
][max_assets >= large_bank_threshold_dollars, RSSDID]

if (length(large_rssd) == 0L) stop("No institutions above size threshold.")
message("Banks above $1B max-ever: ", length(large_rssd))

sod_lb <- sod[RSSDID %in% large_rssd]

# ---- CBSA expansion ----------------------------------------------------------

cbsa_raw <- fread(cbsa_xwalk_path)
cbsa_raw[, `:=`(
  county_fips  = sprintf("%02d%03d", as.integer(fipsstatecode), as.integer(fipscountycode)),
  cbsacode_chr = trimws(as.character(cbsacode))
)]
cbsa_map <- unique(cbsa_raw[nzchar(cbsacode_chr), .(county_fips, cbsacode = cbsacode_chr)])
cbsa_to_counties <- unique(cbsa_map[, .(cbsacode, county_fips)])

sod_lb <- cbsa_map[sod_lb, on = "county_fips"]

expand_counties <- function(cbsa_codes, nonmetro_counties) {
  cbsa_codes <- unique(cbsa_codes[!is.na(cbsa_codes) & nzchar(cbsa_codes)])
  from_cbsa  <- cbsa_to_counties[cbsacode %in% cbsa_codes, unique(county_fips)]
  unique(c(from_cbsa, nonmetro_counties))
}

ops <- unique(sod_lb[!is.na(YEAR), .(RSSDID, YEAR, county_fips, cbsacode)])
bank_year_counties <- ops[
  ,
  {
    cb <- unique(na.omit(cbsacode))
    nm <- unique(county_fips[is.na(cbsacode)])
    .(counties = list(expand_counties(cb, nm)))
  },
  by = .(RSSDID, YEAR)
]

# ---- Allocate candidate counties to ZIPs -------------------------------------

zip_alloc <- as.data.table(read_xlsx(zip_county_xwalk_path))
if (!all(c("ZIP", "COUNTY") %in% names(zip_alloc))) {
  stop("ZIP_COUNTY xwalk must contain ZIP and COUNTY columns.")
}
zip_alloc[, `:=`(
  zip5        = normalize_zip5(ZIP),
  county_fips = normalize_county_fips(COUNTY)
)]
zip_alloc <- unique(zip_alloc[, .(zip5, county_fips)])

bank_year_zips <- bank_year_counties[
  ,
  .(zip5 = unique(zip_alloc[county_fips %in% unlist(counties), zip5])),
  by = .(RSSDID, YEAR)
]
bank_year_zips <- unique(bank_year_zips[!is.na(zip5)])

# ---- Bank-zip deposits and branch count --------------------------------------

bank_zip_y <- sod_lb[
  !is.na(zip5),
  .(
    dep_b_zip      = sum(deposits, na.rm = TRUE),
    n_branches_bzt = .N
  ),
  by = .(RSSDID, YEAR, zip5)
]
setorder(bank_zip_y, RSSDID, zip5, YEAR)
bank_zip_y[, dep_b_zip_lag3 := shift(dep_b_zip, 3L), by = .(RSSDID, zip5)]
bank_zip_y[, g_b_zip_3yr := fifelse(
  dep_b_zip > 0 & dep_b_zip_lag3 > 0,
  log(dep_b_zip) - log(dep_b_zip_lag3),
  NA_real_
)]

# ---- Zip-year lending series: deposits, HMDA, CRA ---------------------------

zip_y <- sod[
  !is.na(zip5),
  .(dep_zip_total = sum(deposits, na.rm = TRUE)),
  by = .(YEAR, zip5)
]

hmda_con <- dbConnect(duckdb::duckdb(), dbdir = hmda_duckdb_path, read_only = TRUE)
hmda_tract <- setDT(dbGetQuery(hmda_con, sprintf("
  SELECT year AS YEAR,
         census_tract,
         COUNT(*) AS hmda_n,
         SUM(TRY_CAST(loan_amount AS DOUBLE)) AS hmda_amt
  FROM lar_panel
  WHERE year BETWEEN %d AND %d
    AND action_taken = '1'
    AND census_tract IS NOT NULL AND census_tract <> ''
  GROUP BY year, census_tract
", start_year, end_year)))
dbDisconnect(hmda_con, shutdown = TRUE)

hmda_tract[, YEAR := as.integer(YEAR)]
hmda_tract[, tract11 := trimws(as.character(census_tract))]

tract_zip <- as.data.table(read_xlsx(tract_zip_xwalk_path))
tract_zip[, tract11 := trimws(as.character(TRACT))]
tract_zip[, zip5    := normalize_zip5(ZIP)]
tract_zip <- tract_zip[!is.na(zip5) & nchar(tract11) == 11L,
                       .(tract11, zip5, RES_RATIO = as.numeric(RES_RATIO))]

hmda_alloc <- tract_zip[hmda_tract, on = "tract11", allow.cartesian = TRUE]
hmda_zip_y <- hmda_alloc[!is.na(zip5), .(
  hmda_amt = sum(hmda_amt * RES_RATIO, na.rm = TRUE),
  hmda_n   = sum(hmda_n   * RES_RATIO, na.rm = TRUE)
), by = .(YEAR, zip5)]
rm(hmda_tract, hmda_alloc); gc()

cra_con <- dbConnect(duckdb::duckdb(), dbdir = cra_duckdb_path, read_only = TRUE)
cra_county <- setDT(dbGetQuery(cra_con, sprintf("
  SELECT year AS YEAR,
         county_fips,
         SUM(num_loans_lt_100k + num_loans_100k_250k + num_loans_250k_1m) AS cra_n,
         1000 * SUM(amt_loans_lt_100k + amt_loans_100k_250k + amt_loans_250k_1m) AS cra_amt
  FROM aggregate_panel
  WHERE TRIM(table_id)      = 'A1-1'
    AND CAST(action_taken   AS INTEGER) = 1
    AND TRIM(report_level)  = '200'
    AND year BETWEEN %d AND %d
    AND county_fips IS NOT NULL
  GROUP BY year, county_fips
", start_year, end_year)))
dbDisconnect(cra_con, shutdown = TRUE)

cra_county[, YEAR        := as.integer(YEAR)]
cra_county[, county_fips := normalize_county_fips(county_fips)]

zip_county_ratios <- as.data.table(read_xlsx(zip_county_xwalk_path))
zip_county_ratios[, zip5        := normalize_zip5(ZIP)]
zip_county_ratios[, county_fips := normalize_county_fips(COUNTY)]
zip_county_ratios <- zip_county_ratios[
  !is.na(zip5) & !is.na(county_fips),
  .(zip5, county_fips, BUS_RATIO = as.numeric(BUS_RATIO))
]

cra_alloc <- zip_county_ratios[cra_county, on = "county_fips", allow.cartesian = TRUE]
cra_zip_y <- cra_alloc[!is.na(zip5), .(
  cra_amt = sum(cra_amt * BUS_RATIO, na.rm = TRUE),
  cra_n   = sum(cra_n   * BUS_RATIO, na.rm = TRUE)
), by = .(YEAR, zip5)]
rm(cra_county, cra_alloc); gc()

irs_con <- dbConnect(duckdb::duckdb(), dbdir = irs_duckdb_path, read_only = TRUE)
irs_y <- setDT(dbGetQuery(irs_con, sprintf("
  SELECT zipcode AS zip5,
         year    AS YEAR,
         n_returns,
         agi_total
  FROM irs
  WHERE year BETWEEN %d AND %d
    AND zipcode IS NOT NULL
    AND n_returns >= 10
", start_year, end_year)))
dbDisconnect(irs_con, shutdown = TRUE)

irs_y[, YEAR    := as.integer(YEAR)]
irs_y[, zip5    := normalize_zip5(zip5)]
irs_y[, avg_agi := as.numeric(agi_total) / as.numeric(n_returns)]
irs_y <- irs_y[!is.na(zip5), .(YEAR, zip5, avg_agi)]

max_irs_year <- max(irs_y$YEAR, na.rm = TRUE)
if (end_year > max_irs_year) {
  base_2022 <- irs_y[YEAR == max_irs_year, .(zip5, avg_agi)]
  fill <- CJ(YEAR = (max_irs_year + 1L):end_year, zip5 = base_2022$zip5)
  fill <- base_2022[fill, on = "zip5"]
  irs_y <- rbind(irs_y, fill[, .(YEAR, zip5, avg_agi)])
  message("AGI forward-filled: ", max_irs_year + 1L, "-", end_year,
          " (rows added: ", nrow(fill), ")")
}

zip_pop <- setDT(readRDS(zip_pop_density_path))[
  , .(YEAR = as.integer(yr), zip5 = as.character(zip5), log_pop_density = log_population_density)
]

acs_paths <- Sys.glob(zip_acs_panel_glob)
acs_path  <- acs_paths[order(file.info(acs_paths)$mtime, decreasing = TRUE)][1L]
zip_acs <- setDT(readRDS(acs_path))[
  , .(YEAR = as.integer(yr), zip5 = as.character(zip5),
      median_income, median_age, pct_college_educated, deposit_hhi_zip)
]
zip_acs[, no_bank_zip := as.integer(is.na(deposit_hhi_zip))]
zip_acs[is.na(deposit_hhi_zip), deposit_hhi_zip := 0]

zip_y <- merge(zip_y, hmda_zip_y, by = c("YEAR", "zip5"), all.x = TRUE)
zip_y <- merge(zip_y, cra_zip_y,  by = c("YEAR", "zip5"), all.x = TRUE)
zip_y <- merge(zip_y, irs_y,      by = c("YEAR", "zip5"), all.x = TRUE)
zip_y <- merge(zip_y, zip_pop,    by = c("YEAR", "zip5"), all.x = TRUE)
zip_y <- merge(zip_y, zip_acs,    by = c("YEAR", "zip5"), all.x = TRUE)

setorder(zip_y, zip5, YEAR)
for (v in c("dep_zip_total", "hmda_amt", "cra_amt", "avg_agi", "log_pop_density",
            "median_income", "median_age", "pct_college_educated",
            "deposit_hhi_zip", "no_bank_zip")) {
  zip_y[, (paste0(v, "_lag1")) := shift(get(v), 1L), by = zip5]
  zip_y[, (paste0(v, "_lag3")) := shift(get(v), 3L), by = zip5]
}

# ---- Assemble panel ----------------------------------------------------------

panel <- bank_zip_y[bank_year_zips, on = .(RSSDID, YEAR, zip5)]
panel <- zip_y[
  , .(YEAR, zip5,
       dep_zip_total, dep_zip_total_lag1, dep_zip_total_lag3,
       hmda_amt, hmda_amt_lag1, hmda_amt_lag3,
       cra_amt,  cra_amt_lag1,  cra_amt_lag3,
       avg_agi,  avg_agi_lag1,  avg_agi_lag3,
       log_pop_density, log_pop_density_lag1,
       median_income, median_income_lag1,
       median_age, median_age_lag1,
       pct_college_educated, pct_college_educated_lag1,
       deposit_hhi_zip, deposit_hhi_zip_lag1,
       no_bank_zip, no_bank_zip_lag1)
][panel, on = .(YEAR, zip5)]
panel[, share_bzt := fifelse(dep_zip_total > 0, dep_b_zip / dep_zip_total, NA_real_)]

for (col in c("dep_b_zip", "n_branches_bzt",
              "hmda_amt", "hmda_amt_lag1", "hmda_amt_lag3",
              "cra_amt",  "cra_amt_lag1",  "cra_amt_lag3")) {
  panel[is.na(get(col)), (col) := 0]
}

# ---- Bank-in-state dummy -----------------------------------------------------

zip_state <- unique(zip_alloc[!is.na(county_fips), .(
  zip5,
  state_fips = substr(county_fips, 1, 2)
)])
zip_state <- zip_state[nchar(state_fips) == 2L]

bank_year_state <- unique(sod_lb[!is.na(county_fips) & !is.na(YEAR), .(
  RSSDID,
  YEAR,
  state_fips = substr(county_fips, 1, 2)
)])
bank_year_state <- bank_year_state[nchar(state_fips) == 2L]
bank_year_state[, bank_in_state_bzt := 1L]

panel_state <- zip_state[panel[, .(RSSDID, YEAR, zip5)], on = "zip5", allow.cartesian = TRUE]
panel_state <- bank_year_state[panel_state, on = .(RSSDID, YEAR, state_fips)]
panel_state[, bank_in_state_bzt := fifelse(is.na(bank_in_state_bzt), 0L, 1L)]
panel_state <- panel_state[,
  .(bank_in_state_bzt = max(bank_in_state_bzt)),
  by = .(RSSDID, YEAR, zip5)
]

panel <- panel_state[panel, on = .(RSSDID, YEAR, zip5)]
panel[is.na(bank_in_state_bzt), bank_in_state_bzt := 0L]

zip_county_full <- as.data.table(read_xlsx(zip_county_xwalk_path))
zip_county_full[, zip5       := normalize_zip5(ZIP)]
zip_county_full[, state_fips := substr(normalize_county_fips(COUNTY), 1, 2)]
zip_primary_state <- zip_county_full[
  !is.na(zip5) & nchar(state_fips) == 2L,
  .(w = sum(as.numeric(TOT_RATIO), na.rm = TRUE)),
  by = .(zip5, state_fips)
]
setorder(zip_primary_state, zip5, -w)
zip_primary_state <- zip_primary_state[, .SD[1L], by = zip5][, .(zip5, state_fips)]
rm(zip_county_full)

panel <- zip_primary_state[panel, on = "zip5"]

# ---- Save --------------------------------------------------------------------

out_file <- file.path(out_dir, paste0("bank_year_zip_panel_", format(Sys.Date(), "%Y%m%d"), ".rds"))
saveRDS(panel, out_file)

message("Saved: ",            out_file)
message("Rows: ",              nrow(panel))
message("Banks (>=$1B): ",     length(large_rssd))
message("Years: ",             paste(range(panel$YEAR, na.rm = TRUE), collapse = "-"))
message("Unique zips: ",       uniqueN(panel$zip5))
message("Rows with branch: ",  sum(panel$n_branches_bzt > 0))

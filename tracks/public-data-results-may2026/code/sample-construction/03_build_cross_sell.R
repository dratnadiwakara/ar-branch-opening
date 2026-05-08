# 03_build_cross_sell.R
# =============================================================================
# Bank x zip x year mortgage-presence and CRA-presence panels.  Combines
# code/approach-cross-sell-april2026/03_*.R (HMDA mortgage beachhead) and
# 03b_*.R (CRA small-business beachhead) into a single self-contained
# script.
#
# Outputs (in tracks/public-data-results-may2026/data/):
#   bank_zip_year_mortgage_beachhead_<DATE>.rds
#   bank_zip_year_cra_beachhead_<DATE>.rds
# =============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(duckdb)
  library(readxl)
})

data_dir          <- "tracks/public-data-results-may2026/data"
hmda_duckdb_path  <- "C:/empirical-data-construction/hmda/hmda.duckdb"
cra_duckdb_path   <- "C:/empirical-data-construction/cra/cra.duckdb"
zip_county_path   <- "data/raw/ZIP_COUNTY_092020.xlsx"
tract_zip_path    <- "data/raw/tract_zip_122019.xlsx"

if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)
today <- format(Sys.Date(), "%Y%m%d")

normalize_zip5 <- function(x) {
  x_chr <- gsub("[^0-9]", "", trimws(as.character(x)))
  out <- rep(NA_character_, length(x_chr))
  ok <- nzchar(x_chr)
  out[ok] <- sprintf("%05.0f", suppressWarnings(as.numeric(x_chr[ok])))
  out
}

con_hmda <- function() dbConnect(duckdb::duckdb(), dbdir = hmda_duckdb_path, read_only = TRUE)
con_cra  <- function() dbConnect(duckdb::duckdb(), dbdir = cra_duckdb_path,  read_only = TRUE)

# =============================================================================
# A. Mortgage beachhead (HMDA)
# =============================================================================

cat("\n--- A. mortgage_beachhead ---\n")

cat("Loading tract-zip crosswalk...\n")
tract_zip <- as.data.table(read_excel(tract_zip_path))
setnames(tract_zip, tolower(names(tract_zip)))
if ("tract" %in% names(tract_zip)) setnames(tract_zip, "tract", "tract11")
if ("zip"   %in% names(tract_zip)) setnames(tract_zip, "zip",   "zip5")
tract_zip[, tract11 := as.character(tract11)]
tract_zip[nchar(tract11) < 11, tract11 := sprintf("%011.0f", as.numeric(tract11))]
tract_zip[, zip5 := normalize_zip5(as.character(zip5))]
tract_zip <- tract_zip[!is.na(zip5) & !is.na(res_ratio) & res_ratio > 0,
                        .(tract11, zip5, res_ratio)]

con <- con_hmda()
sql_pre <- "
  SELECT l.year AS yr, ac.rssd_id AS id_rssd, l.census_tract,
         SUM(TRY_CAST(l.loan_amount AS DOUBLE)) AS bank_tract_amt
  FROM lar_panel l
  JOIN avery_crosswalk ac
    ON l.respondent_id = ac.respondent_id AND l.agency_code = ac.agency_code
   AND l.year = ac.activity_year
  WHERE l.year BETWEEN 2003 AND 2017
    AND l.action_taken = 1
    AND l.census_tract IS NOT NULL AND l.census_tract <> '' AND l.census_tract <> 'NA'
    AND ac.rssd_id IS NOT NULL
  GROUP BY l.year, ac.rssd_id, l.census_tract
"
sql_post <- "
  SELECT l.year AS yr, ac.rssd_id AS id_rssd, l.census_tract,
         SUM(TRY_CAST(l.loan_amount AS DOUBLE)) AS bank_tract_amt
  FROM lar_panel l
  JOIN avery_crosswalk ac
    ON l.lei = ac.lei AND l.year = ac.activity_year
  WHERE l.year BETWEEN 2018 AND 2025
    AND l.action_taken = 1
    AND l.lei IS NOT NULL AND l.lei <> 'NA'
    AND l.census_tract IS NOT NULL AND l.census_tract <> '' AND l.census_tract <> 'NA'
    AND ac.rssd_id IS NOT NULL
  GROUP BY l.year, ac.rssd_id, l.census_tract
"
sql_tot_pre <- "
  SELECT l.year AS yr, l.census_tract,
         SUM(TRY_CAST(l.loan_amount AS DOUBLE)) AS total_tract_amt
  FROM lar_panel l
  WHERE l.year BETWEEN 2003 AND 2017
    AND l.action_taken = 1
    AND l.census_tract IS NOT NULL AND l.census_tract <> '' AND l.census_tract <> 'NA'
  GROUP BY l.year, l.census_tract
"
sql_tot_post <- "
  SELECT l.year AS yr, l.census_tract,
         SUM(TRY_CAST(l.loan_amount AS DOUBLE)) AS total_tract_amt
  FROM lar_panel l
  WHERE l.year BETWEEN 2018 AND 2025
    AND l.action_taken = 1
    AND l.census_tract IS NOT NULL AND l.census_tract <> '' AND l.census_tract <> 'NA'
  GROUP BY l.year, l.census_tract
"

cat("Querying HMDA...\n")
bk_pre   <- setDT(dbGetQuery(con, sql_pre))
bk_post  <- setDT(dbGetQuery(con, sql_post))
tot_pre  <- setDT(dbGetQuery(con, sql_tot_pre))
tot_post <- setDT(dbGetQuery(con, sql_tot_post))
dbDisconnect(con, shutdown = TRUE)

bank_tract <- rbindlist(list(bk_pre, bk_post), use.names = TRUE)
tot_tract  <- rbindlist(list(tot_pre, tot_post), use.names = TRUE)

std_tract <- function(x) {
  x <- gsub("[^0-9]", "", trimws(as.character(x)))
  ifelse(nchar(x) == 11, x,
         ifelse(nchar(x) > 0, sprintf("%011.0f", suppressWarnings(as.numeric(x))), NA_character_))
}
bank_tract[, census_tract := std_tract(census_tract)]
tot_tract[ , census_tract := std_tract(census_tract)]
bank_tract <- bank_tract[!is.na(census_tract)]
tot_tract  <- tot_tract[ !is.na(census_tract)]

bank_zip <- merge(bank_tract, tract_zip, by.x = "census_tract", by.y = "tract11",
                  allow.cartesian = TRUE)
bank_zip <- bank_zip[!is.na(zip5), .(
  focal_hmda_amt = sum(bank_tract_amt * res_ratio, na.rm = TRUE)
), by = .(id_rssd, yr, zip5)]

tot_zip <- merge(tot_tract, tract_zip, by.x = "census_tract", by.y = "tract11",
                 allow.cartesian = TRUE)
tot_zip <- tot_zip[!is.na(zip5), .(
  total_hmda_amt = sum(total_tract_amt * res_ratio, na.rm = TRUE)
), by = .(yr, zip5)]

beachhead <- merge(bank_zip, tot_zip, by = c("yr", "zip5"), all.x = TRUE)
beachhead[, mortgage_mktshare  := focal_hmda_amt / total_hmda_amt]
beachhead[, mortgage_beachhead := as.integer(focal_hmda_amt > 0)]

mort_out <- beachhead[, .(id_rssd, yr, zip5, mortgage_mktshare, mortgage_beachhead)]
mort_path <- file.path(data_dir, paste0("bank_zip_year_mortgage_beachhead_", today, ".rds"))
saveRDS(mort_out, mort_path)
cat("Wrote:", mort_path, " rows=", nrow(mort_out), "\n")

# =============================================================================
# B. CRA beachhead
# =============================================================================

cat("\n--- B. cra_beachhead ---\n")

zip_county <- as.data.table(read_excel(zip_county_path))
setnames(zip_county, tolower(names(zip_county)))
zip_county[, zip5        := normalize_zip5(as.character(zip))]
zip_county[, county_fips := as.character(county)]
zip_county[nchar(county_fips) < 5,
           county_fips := sprintf("%05.0f", as.numeric(county_fips))]
zip_county <- zip_county[!is.na(zip5) & !is.na(county_fips) & bus_ratio > 0,
                          .(zip5, county_fips, bus_ratio)]

con <- con_cra()
sql_bank <- "
  SELECT t.rssdid AS id_rssd, d.county_fips, d.year AS yr,
         SUM(COALESCE(d.amt_loans_lt_100k,0) +
             COALESCE(d.amt_loans_100k_250k,0) +
             COALESCE(d.amt_loans_250k_1m,0)) AS bank_cra_amt,
         SUM(COALESCE(d.num_loans_lt_100k,0) +
             COALESCE(d.num_loans_100k_250k,0) +
             COALESCE(d.num_loans_250k_1m,0)) AS bank_cra_n
  FROM disclosure_panel d
  JOIN transmittal_panel t
    ON d.respondent_id = t.respondent_id AND d.agency_code = t.agency_code
   AND d.year = t.year
  WHERE d.year BETWEEN 2003 AND 2024
    AND d.table_id = 'D1-1'
    AND t.rssdid IS NOT NULL AND t.rssdid > 0
    AND d.county_fips IS NOT NULL
  GROUP BY t.rssdid, d.county_fips, d.year
"
sql_total <- "
  SELECT d.county_fips, d.year AS yr,
         SUM(COALESCE(d.amt_loans_lt_100k,0) +
             COALESCE(d.amt_loans_100k_250k,0) +
             COALESCE(d.amt_loans_250k_1m,0)) AS total_cra_amt
  FROM disclosure_panel d
  WHERE d.year BETWEEN 2003 AND 2024
    AND d.table_id = 'D1-1'
    AND d.county_fips IS NOT NULL
  GROUP BY d.county_fips, d.year
"

bank_county <- setDT(dbGetQuery(con, sql_bank))
tot_county  <- setDT(dbGetQuery(con, sql_total))
dbDisconnect(con, shutdown = TRUE)

std5 <- function(x) {
  x <- as.character(x)
  ifelse(nchar(x) == 5, x,
         ifelse(nchar(x) > 0, sprintf("%05.0f", suppressWarnings(as.numeric(x))),
                NA_character_))
}
bank_county[, county_fips := std5(county_fips)]
tot_county[ , county_fips := std5(county_fips)]
bank_county <- bank_county[!is.na(county_fips) & bank_cra_amt > 0]
tot_county  <- tot_county[ !is.na(county_fips)]

bank_zip <- merge(bank_county, zip_county, by = "county_fips", allow.cartesian = TRUE)
bank_zip <- bank_zip[!is.na(zip5), .(
  focal_cra_amt = sum(bank_cra_amt * bus_ratio, na.rm = TRUE),
  focal_cra_n   = sum(bank_cra_n   * bus_ratio, na.rm = TRUE)
), by = .(id_rssd, yr, zip5)]

tot_zip <- merge(tot_county, zip_county, by = "county_fips", allow.cartesian = TRUE)
tot_zip <- tot_zip[!is.na(zip5), .(
  total_cra_amt = sum(total_cra_amt * bus_ratio, na.rm = TRUE)
), by = .(yr, zip5)]

beachhead <- merge(bank_zip, tot_zip, by = c("yr", "zip5"), all.x = TRUE)
beachhead[, cra_county_share := focal_cra_amt / total_cra_amt]
beachhead[, cra_beachhead    := as.integer(focal_cra_amt > 0)]

cra_out <- beachhead[, .(id_rssd, yr, zip5, cra_county_share, cra_beachhead)]
cra_path <- file.path(data_dir, paste0("bank_zip_year_cra_beachhead_", today, ".rds"))
saveRDS(cra_out, cra_path)
cat("Wrote:", cra_path, " rows=", nrow(cra_out), "\n")

cat("\nDone (cross_sell).\n")

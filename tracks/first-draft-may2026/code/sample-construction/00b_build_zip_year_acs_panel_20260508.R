# 00b_build_zip_year_acs_panel_20260508.R
# =============================================================================
# Build zip-year ACS demographics + deposit-HHI panel.
#
# Demographics target: closely match NRS zip_demographics_panel.rds columns
#   median_income, median_age, pct_college_educated (bachelor's+ share of 25+ pop).
# Deposit HHI: zip-year Herfindahl over all banks in FDIC SOD, scaled 0-10,000.
#
# Years: ACS 5-yr pulled 2011-2024. 2009-2010 back-filled from 2011; 2025
# forward-filled from 2024 (ACS 2025 5-yr not yet released).
#
# Forked from:
#   C:/Users/dimut/OneDrive/github/_delete/bank-branch-openings/
#     code/approach-baseline-regression/05_build_zip_year_acs_panel_20260424.R
# (vendored into this track so the sample-construction pipeline is self-
# contained.)  Output stays in project-level `data/constructed/` because it is
# zip-level public data, independent of the bank-size threshold used in this
# track, and is consumed by 00_build_panel.R via a glob on that directory.
#
# Run order (within tracks/first-draft-may2026/code/sample-construction):
#   00a -> 00b (this script) -> 00 -> 01 -> 02 -> 03 -> 04
#
# Output:    data/constructed/zip_year_acs_panel_<YYYYMMDD>.rds
# =============================================================================

rm(list = ls())

library(data.table)
library(tidycensus)
library(readxl)
library(DBI)
library(duckdb)
library(yaml)

# ---- Parameters --------------------------------------------------------------

key_yaml_path       <- "C:/key-variables/key-variables.yaml"
sod_duckdb_path     <- "C:/empirical-data-construction/sod/sod.duckdb"
zip_county_path     <- "data/raw/ZIP_COUNTY_092020.xlsx"
out_dir             <- "data/constructed"

acs_years           <- 2011:2024
backfill_min_year   <- 2009L     # carry 2011 back to 2009, 2010
forwardfill_max_year <- 2025L    # carry 2024 forward to 2025
sod_year_range      <- c(2009L, 2026L)

out_path <- file.path(out_dir, paste0("zip_year_acs_panel_",
                                      format(Sys.Date(), "%Y%m%d"), ".rds"))

for (p in c(key_yaml_path, sod_duckdb_path, zip_county_path)) {
  if (!file.exists(p)) stop("Missing input: ", p, call. = FALSE)
}
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

normalize_zip5 <- function(x) {
  x_chr <- gsub("[^0-9]", "", trimws(as.character(x)))
  out <- rep(NA_character_, length(x_chr))
  ok <- nzchar(x_chr)
  out[ok] <- sprintf("%05.0f", suppressWarnings(as.numeric(x_chr[ok])))
  out
}

# ---- API key -----------------------------------------------------------------

keys <- yaml::read_yaml(key_yaml_path)
census_key <- keys$api_keys$census
if (is.null(census_key) || !nzchar(census_key)) {
  stop("api_keys$census not set in ", key_yaml_path, call. = FALSE)
}
census_api_key(census_key, overwrite = TRUE, install = FALSE)

# ---- Pull ACS ZCTA-year ------------------------------------------------------

# Variables (2012+):
#   B19013_001 = median household income ($)
#   B01002_001 = median age (years)
#   B15003_001 = population 25+ (denominator for college share)
#   B15003_022 = bachelor's; _023 master's; _024 professional; _025 doctorate
# 2011 uses older B15002 schema (bachelor's+ spans _015/_016/_017/_018 M and _032/_033/_034/_035 F).
acs_vars_2012p <- c("B19013_001", "B01002_001",
                    "B15003_001", "B15003_022", "B15003_023",
                    "B15003_024", "B15003_025")
acs_vars_2011  <- c("B19013_001", "B01002_001",
                    "B15002_001",
                    "B15002_015", "B15002_016", "B15002_017", "B15002_018",
                    "B15002_032", "B15002_033", "B15002_034", "B15002_035")

extract_zip5 <- function(d) {
  z_full <- rep(NA_character_, nrow(d))
  m <- regexpr("[0-9]{5}$", d$NAME)
  has_match <- m > 0
  z_full[has_match] <- regmatches(d$NAME, m)
  z_full[!has_match] <- normalize_zip5(d$GEOID[!has_match])
  z_full
}

pull_acs <- function(yr) {
  message("ACS pull: ", yr)
  vars <- if (yr >= 2012L) acs_vars_2012p else acs_vars_2011
  d <- tryCatch(
    tidycensus::get_acs(geography = "zcta", variables = vars,
                        year = yr, survey = "acs5", output = "wide"),
    error = function(e) { message("  failed ", yr, ": ", conditionMessage(e)); NULL }
  )
  if (is.null(d)) return(NULL)
  setDT(d)
  if (yr >= 2012L) {
    return(data.table(
      zip5 = extract_zip5(d),
      yr = as.integer(yr),
      median_income = d$B19013_001E,
      median_age    = d$B01002_001E,
      pop25         = d$B15003_001E,
      college_num   = d$B15003_022E + d$B15003_023E + d$B15003_024E + d$B15003_025E
    ))
  }
  data.table(
    zip5 = extract_zip5(d),
    yr = as.integer(yr),
    median_income = d$B19013_001E,
    median_age    = d$B01002_001E,
    pop25         = d$B15002_001E,
    college_num   = d$B15002_015E + d$B15002_016E + d$B15002_017E + d$B15002_018E +
                    d$B15002_032E + d$B15002_033E + d$B15002_034E + d$B15002_035E
  )
}

acs_dt <- rbindlist(lapply(acs_years, pull_acs), fill = TRUE)
acs_dt <- acs_dt[!is.na(zip5)]
acs_dt[, pct_college_educated := fifelse(pop25 > 0, college_num / pop25 * 100, NA_real_)]
acs_dt <- acs_dt[, .(zip5, yr, median_income, median_age, pct_college_educated)]
acs_dt <- unique(acs_dt, by = c("zip5", "yr"))

# ---- ZIP universe ------------------------------------------------------------

zc <- as.data.table(read_xlsx(zip_county_path))
zc[, zip5 := normalize_zip5(ZIP)]
zips_universe <- sort(unique(zc[!is.na(zip5), zip5]))
message("ZIP universe: ", length(zips_universe))

# ---- Deposit HHI from SOD (zip-year, all banks) ------------------------------

con <- dbConnect(duckdb::duckdb(), dbdir = sod_duckdb_path, read_only = TRUE)
sod <- setDT(dbGetQuery(con, sprintf("
  SELECT RSSDID, YEAR, ZIPBR, DEPSUMBR
  FROM sod
  WHERE YEAR BETWEEN %d AND %d
    AND RSSDID IS NOT NULL
    AND ZIPBR IS NOT NULL
    AND DEPSUMBR IS NOT NULL
", sod_year_range[1], sod_year_range[2])))
dbDisconnect(con, shutdown = TRUE)

sod[, YEAR     := as.integer(YEAR)]
sod[, zip5     := normalize_zip5(ZIPBR)]
sod[, deposits := as.numeric(DEPSUMBR) * 1000]
sod <- sod[!is.na(zip5) & deposits > 0]

bank_zip <- sod[, .(bank_dep = sum(deposits)),
                by = .(RSSDID, YEAR, zip5)]
zip_tot <- bank_zip[, .(tot_dep = sum(bank_dep)),
                    by = .(YEAR, zip5)]
bank_zip <- merge(bank_zip, zip_tot, by = c("YEAR", "zip5"))
bank_zip[, sh := bank_dep / tot_dep]
hhi_dt <- bank_zip[, .(deposit_hhi_zip = sum(sh^2) * 10000),
                   by = .(YEAR, zip5)]
setnames(hhi_dt, "YEAR", "yr")

# ---- Panel assembly ----------------------------------------------------------

full_years <- backfill_min_year:forwardfill_max_year
panel <- CJ(zip5 = zips_universe, yr = full_years)
panel <- merge(panel, acs_dt,  by = c("zip5", "yr"), all.x = TRUE, sort = FALSE)
panel <- merge(panel, hhi_dt,  by = c("zip5", "yr"), all.x = TRUE, sort = FALSE)

# Back-fill ACS to pre-2011 from 2011 values (no ZCTA ACS prior to 2011).
acs_2011 <- acs_dt[yr == 2011L,
                   .(zip5,
                     median_income_2011 = median_income,
                     median_age_2011 = median_age,
                     pct_college_educated_2011 = pct_college_educated)]
panel <- merge(panel, acs_2011, by = "zip5", all.x = TRUE, sort = FALSE)
panel[yr < 2011L & is.na(median_income),        median_income := median_income_2011]
panel[yr < 2011L & is.na(median_age),           median_age := median_age_2011]
panel[yr < 2011L & is.na(pct_college_educated), pct_college_educated := pct_college_educated_2011]
panel[, c("median_income_2011", "median_age_2011", "pct_college_educated_2011") := NULL]

# Forward-fill ACS 2024 -> 2025.
acs_2024 <- acs_dt[yr == 2024L,
                   .(zip5,
                     median_income_2024 = median_income,
                     median_age_2024 = median_age,
                     pct_college_educated_2024 = pct_college_educated)]
panel <- merge(panel, acs_2024, by = "zip5", all.x = TRUE, sort = FALSE)
panel[yr == 2025L & is.na(median_income),        median_income := median_income_2024]
panel[yr == 2025L & is.na(median_age),           median_age := median_age_2024]
panel[yr == 2025L & is.na(pct_college_educated), pct_college_educated := pct_college_educated_2024]
panel[, c("median_income_2024", "median_age_2024", "pct_college_educated_2024") := NULL]

setorder(panel, zip5, yr)

# ---- Save --------------------------------------------------------------------

saveRDS(panel, out_path)
message("Saved: ", out_path,
        "  rows=", nrow(panel),
        "  zips=", uniqueN(panel$zip5),
        "  years=", paste(range(panel$yr), collapse = "-"))

# ---- Validation vs NRS file (optional) ---------------------------------------

nrs_path <- "C:/Users/dimut/OneDrive/github/_delete/bank-branch-openings-old/data/raw/zip_demographics_panel.rds"
if (file.exists(nrs_path)) {
  nrs <- setDT(readRDS(nrs_path))
  nrs[, zip5 := normalize_zip5(zip)]
  nrs[, yr := as.integer(yr)]
  cmp <- merge(
    panel[, .(zip5, yr, median_income, median_age, pct_college_educated)],
    nrs[, .(zip5, yr,
            nrs_median_income = median_income,
            nrs_median_age = median_age,
            nrs_pct_college = pct_college_educated)],
    by = c("zip5", "yr")
  )
  cmp <- cmp[!is.na(median_income) & !is.na(nrs_median_income)]
  cat("\n--- NRS comparison (n = ", nrow(cmp), ") ---\n", sep = "")
  cat(sprintf("median_income        corr = %.4f  mean_diff = %.1f\n",
              cor(cmp$median_income, cmp$nrs_median_income),
              mean(cmp$median_income - cmp$nrs_median_income, na.rm = TRUE)))
  cat(sprintf("median_age           corr = %.4f  mean_diff = %.3f\n",
              cor(cmp$median_age, cmp$nrs_median_age, use = "complete.obs"),
              mean(cmp$median_age - cmp$nrs_median_age, na.rm = TRUE)))
  cat(sprintf("pct_college_educated corr = %.4f  mean_diff = %.3f\n",
              cor(cmp$pct_college_educated, cmp$nrs_pct_college, use = "complete.obs"),
              mean(cmp$pct_college_educated - cmp$nrs_pct_college, na.rm = TRUE)))
}

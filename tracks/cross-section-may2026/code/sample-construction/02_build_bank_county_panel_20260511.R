# Build bank-county cross-section for the 2014 cohort.
#
# At-risk set: bank-county pairs (b, c) where bank b had >= 1 full-service
# brick-and-mortar branch in county c in SOD 2014 (within-footprint margin).
#
# LHS (built downstream): organic branch openings by bank b in county c
# over (2014, max_year]; organic closures over [2014, max_year).
#
# Inputs (DuckDB views):
#   C:/empirical-data-construction/sod/sod.duckdb  -- sod (hive year-partitioned)
#
# Output:
#   tracks/cross-section-may2026/data/bank_county_2014_<YYYYMMDD>.rds
#
# Rows: one per (RSSDID, county_fips) where bank had a 2014 branch.
# Bank-level covariates joined by RSSDID downstream.

rm(list = ls())

library(data.table)
library(duckdb)
library(DBI)
library(here)

track    <- "cross-section-may2026"
data_dir <- here("tracks", track, "data")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

sod_db <- "C:/empirical-data-construction/sod/sod.duckdb"

BRSERTYP_FILTER <- 11L
COHORT_YEAR     <- 2014L
MIN_BRANCHES    <- 100L

con <- dbConnect(duckdb(), sod_db, read_only = TRUE)

# OTS regulatory transfers (drop, see Dratnadiwakara et al.)
ots_rssds <- dbGetQuery(con, sprintf("
  WITH first_year AS (
    SELECT UNINUMBR, RSSDID, MIN(YEAR) AS first_yr
    FROM sod WHERE BRSERTYP = %d
    GROUP BY UNINUMBR, RSSDID
  ),
  rssd_window AS (
    SELECT RSSDID,
           MAX(CASE WHEN first_yr = 2011 THEN 1 ELSE 0 END) AS opened_2011,
           MAX(CASE WHEN first_yr BETWEEN 2004 AND 2010 THEN 1 ELSE 0 END) AS opened_pre
    FROM first_year WHERE first_yr BETWEEN 2004 AND 2011
    GROUP BY RSSDID
  )
  SELECT RSSDID FROM rssd_window WHERE opened_2011 = 1 AND opened_pre = 0
", BRSERTYP_FILTER))$RSSDID

max_year <- dbGetQuery(con, sprintf(
  "SELECT MAX(YEAR) AS my FROM sod WHERE BRSERTYP = %d", BRSERTYP_FILTER))$my

ots_clause <- if (length(ots_rssds) == 0) "" else
  paste0("AND s.RSSDID NOT IN (", paste(ots_rssds, collapse = ","), ")")

cat("Max SOD year: ", max_year,
    " | OTS-excluded RSSDs: ", length(ots_rssds), "\n", sep = "")

# Cohort RSSDIDs (>= 100 brick-and-mortar branches in 2014)
cohort_rssds <- dbGetQuery(con, sprintf("
  SELECT RSSDID
  FROM sod
  WHERE YEAR = %d AND BRSERTYP = %d
  GROUP BY RSSDID
  HAVING COUNT(*) >= %d
", COHORT_YEAR, BRSERTYP_FILTER, MIN_BRANCHES))$RSSDID
cohort_clause <- paste0("(", paste(cohort_rssds, collapse = ","), ")")
cat("Cohort banks: ", length(cohort_rssds), "\n", sep = "")

# 2014 bank-county footprint: branches and deposits
footprint <- setDT(dbGetQuery(con, sprintf("
  SELECT RSSDID,
         LPAD(STCNTYBR, 5, '0') AS county_fips,
         COUNT(*)        AS branches_2014,
         SUM(DEPSUMBR)   AS bank_dep_2014_k
  FROM sod
  WHERE YEAR = %d
    AND BRSERTYP = %d
    AND RSSDID IN %s
  GROUP BY RSSDID, county_fips
", COHORT_YEAR, BRSERTYP_FILTER, cohort_clause)))
cat("Footprint bank-county rows: ", nrow(footprint), "\n", sep = "")

# County-level totals in 2014 (across all banks) for HHI + size
co_b <- setDT(dbGetQuery(con, sprintf("
  SELECT LPAD(STCNTYBR, 5, '0') AS county_fips,
         RSSDID,
         SUM(DEPSUMBR) AS dep_k
  FROM sod
  WHERE YEAR = %d AND BRSERTYP = %d
  GROUP BY county_fips, RSSDID
", COHORT_YEAR, BRSERTYP_FILTER)))

co_tot <- co_b[, .(county_dep_2014_k = sum(dep_k, na.rm = TRUE),
                   n_banks_county_2014 = uniqueN(RSSDID)),
               by = county_fips]
co_b   <- merge(co_b, co_tot[, .(county_fips, county_dep_2014_k)], by = "county_fips")
co_b[, share := dep_k / county_dep_2014_k]
co_hhi <- co_b[, .(county_hhi_2014 = sum(share^2)), by = county_fips]
county <- merge(co_tot, co_hhi, by = "county_fips")
cat("Counties in 2014 SOD: ", nrow(county), "\n", sep = "")

# Bank-county openings: UNINUMBR first global appearance (BRSERTYP=11), under
# cohort RSSDID, year > COHORT_YEAR. M&A acquisitions excluded by global-first
# rule; OTS RSSDs excluded.
openings <- setDT(dbGetQuery(con, sprintf("
  WITH first_year AS (
    SELECT UNINUMBR, MIN(YEAR) AS first_yr
    FROM sod WHERE BRSERTYP = %d
    GROUP BY UNINUMBR
  )
  SELECT s.RSSDID,
         LPAD(s.STCNTYBR, 5, '0') AS county_fips,
         COUNT(*) AS openings
  FROM sod s
  JOIN first_year fy ON s.UNINUMBR = fy.UNINUMBR AND s.YEAR = fy.first_yr
  WHERE s.BRSERTYP = %d
    AND s.YEAR > %d
    AND s.RSSDID IN %s
    %s
  GROUP BY s.RSSDID, county_fips
", BRSERTYP_FILTER, BRSERTYP_FILTER, COHORT_YEAR, cohort_clause, ots_clause)))
cat("Opening (RSSDID, county) cells: ", nrow(openings), "\n", sep = "")

# Bank-county closures: UNINUMBR last global appearance under cohort RSSDID,
# in [COHORT_YEAR, max_year). Branches sold to other banks not counted.
closures <- setDT(dbGetQuery(con, sprintf("
  WITH last_year AS (
    SELECT UNINUMBR, MAX(YEAR) AS last_yr
    FROM sod WHERE BRSERTYP = %d
    GROUP BY UNINUMBR
  )
  SELECT s.RSSDID,
         LPAD(s.STCNTYBR, 5, '0') AS county_fips,
         COUNT(*) AS closures
  FROM sod s
  JOIN last_year ly ON s.UNINUMBR = ly.UNINUMBR AND s.YEAR = ly.last_yr
  WHERE s.BRSERTYP = %d
    AND ly.last_yr >= %d
    AND ly.last_yr <  %d
    AND s.RSSDID IN %s
  GROUP BY s.RSSDID, county_fips
", BRSERTYP_FILTER, BRSERTYP_FILTER, COHORT_YEAR, max_year, cohort_clause)))
cat("Closure (RSSDID, county) cells: ", nrow(closures), "\n", sep = "")

dbDisconnect(con, shutdown = TRUE)

# ------------------------------------------------------ assemble bank-county
dt <- copy(footprint)

# Bank-county-level: openings, closures (default 0)
dt <- merge(dt, openings, by = c("RSSDID", "county_fips"), all.x = TRUE)
dt <- merge(dt, closures, by = c("RSSDID", "county_fips"), all.x = TRUE)
dt[is.na(openings), openings := 0L]
dt[is.na(closures), closures := 0L]

# County controls
dt <- merge(dt, county, by = "county_fips", all.x = TRUE)

# Derived
dt[, deposit_share_2014 := bank_dep_2014_k / county_dep_2014_k]
dt[, log_county_dep     := log(county_dep_2014_k)]
dt[, log_bank_dep_in_county := log(bank_dep_2014_k)]
dt[, log_branches_2014  := log(branches_2014)]
dt[, churn_bc           := openings + closures]
dt[, opening_intensity  := openings / branches_2014]           # openings per 2014 branch
dt[, net_growth_bc      := (openings - closures) / branches_2014]
dt[, open_share_bc      := ifelse(churn_bc > 0,
                                  openings / churn_bc, NA_real_)]

cat("Final bank-county panel: ", nrow(dt),
    " rows | banks: ", uniqueN(dt$RSSDID),
    " | counties: ", uniqueN(dt$county_fips), "\n", sep = "")

stamp <- format(Sys.Date(), "%Y%m%d")
out_file <- file.path(data_dir, paste0("bank_county_2014_", stamp, ".rds"))
saveRDS(dt, out_file)
cat("Wrote: ", out_file, "\n", sep = "")

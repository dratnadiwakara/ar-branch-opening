# Build bank-level cross-section dataset for the 2014 cohort.
#
# Cohort: RSSDIDs with >= 100 full-service brick-and-mortar branches (BRSERTYP=11)
# in SOD 2014. Computes branch openings/closures 2014 onward, opening share of
# churn, bank-level Call Report measures (2014-Q4), and SOD-derived geography.
#
# Inputs (DuckDB views):
#   C:/empirical-data-construction/sod/sod.duckdb
#     - sod                 (built by .../sod/construct.py)
#   C:/empirical-data-construction/call-reports-FFIEC/call-reports-ffiec.duckdb
#     - bs_panel, is_panel  (built by .../call-reports-FFIEC/construct.py)
#
# Output:
#   tracks/cross-section-may2026/data/cohort_2014_<YYYYMMDD>.rds

rm(list = ls())

library(data.table)
library(duckdb)
library(DBI)
library(here)

track     <- "cross-section-may2026"
data_dir  <- here("tracks", track, "data")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

sod_db   <- "C:/empirical-data-construction/sod/sod.duckdb"
ffiec_db <- "C:/empirical-data-construction/call-reports-FFIEC/call-reports-ffiec.duckdb"

BRSERTYP_FILTER <- 11L   # full-service brick-and-mortar
COHORT_YEAR     <- 2014L
MIN_BRANCHES    <- 100L
MIN_CHURN       <- 20L   # min openings+closures for open_share to be meaningful

# ---------------------------------------------------------------- SOD cohort
con <- dbConnect(duckdb(), sod_db, read_only = TRUE)

# OTS regulatory-transfer RSSDs (Dodd-Frank 2011 OTS->OCC)
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

cohort <- setDT(dbGetQuery(con, sprintf("
  WITH first_year AS (
    SELECT UNINUMBR, MIN(YEAR) AS first_yr FROM sod WHERE BRSERTYP = %1$d GROUP BY UNINUMBR
  ),
  last_year AS (
    SELECT UNINUMBR, MAX(YEAR) AS last_yr  FROM sod WHERE BRSERTYP = %1$d GROUP BY UNINUMBR
  ),
  banks_2014 AS (
    SELECT RSSDID, ANY_VALUE(NAMEFULL) AS NAMEFULL, COUNT(*) AS branches_2014
    FROM sod WHERE YEAR = %2$d AND BRSERTYP = %1$d
    GROUP BY RSSDID HAVING COUNT(*) >= %3$d
  ),
  openings AS (
    SELECT s.RSSDID, COUNT(*) AS openings
    FROM sod s
    JOIN first_year fy ON s.UNINUMBR = fy.UNINUMBR AND s.YEAR = fy.first_yr
    WHERE s.BRSERTYP = %1$d AND s.YEAR > %2$d %4$s
    GROUP BY s.RSSDID
  ),
  closures AS (
    SELECT s.RSSDID, COUNT(*) AS closures
    FROM sod s
    JOIN last_year ly ON s.UNINUMBR = ly.UNINUMBR AND s.YEAR = ly.last_yr
    WHERE s.BRSERTYP = %1$d AND ly.last_yr >= %2$d AND ly.last_yr < %5$d
    GROUP BY s.RSSDID
  )
  SELECT b.RSSDID, b.NAMEFULL, b.branches_2014,
         COALESCE(c.closures, 0) AS closures,
         COALESCE(o.openings, 0) AS openings
  FROM banks_2014 b
  LEFT JOIN openings o ON b.RSSDID = o.RSSDID
  LEFT JOIN closures c ON b.RSSDID = c.RSSDID
", BRSERTYP_FILTER, COHORT_YEAR, MIN_BRANCHES, ots_clause, max_year)))

cohort[, churn      := closures + openings]
cohort[, open_share := ifelse(churn >= MIN_CHURN, openings / churn, NA_real_)]
cohort[, net_growth := (openings - closures) / branches_2014]

cat("Cohort: ", nrow(cohort),
    " | with valid open_share (churn >= ", MIN_CHURN, "): ",
    sum(!is.na(cohort$open_share)), "\n", sep = "")

# ------------------------------------------------------------- SOD geography
sod_2014 <- setDT(dbGetQuery(con, sprintf("
  SELECT RSSDID, LPAD(STCNTYBR, 5, '0') AS county_fips, DEPSUMBR
  FROM sod WHERE YEAR = %d AND BRSERTYP = %d
", COHORT_YEAR, BRSERTYP_FILTER)))
# STALP in SOD is institution-HQ state, not branch state. Use FIPS prefix.
sod_2014[, branch_state := substr(county_fips, 1, 2)]

# County HHI of deposits (across ALL banks, not just cohort).
co_b <- sod_2014[, .(b_dep = sum(DEPSUMBR, na.rm = TRUE)),
                 by = .(county_fips, RSSDID)]
co_t <- co_b[, .(tot = sum(b_dep)), by = county_fips]
co_b <- merge(co_b, co_t, by = "county_fips")
co_b[, share := b_dep / tot]
county_hhi_idx <- co_b[, .(county_hhi = sum(share^2)), by = county_fips]

# Per-cohort-bank geography.
b_county <- sod_2014[RSSDID %in% cohort$RSSDID,
                     .(bank_dep_c = sum(DEPSUMBR, na.rm = TRUE),
                       branches_c = .N),
                     by = .(RSSDID, county_fips)]
b_county <- merge(b_county, county_hhi_idx, by = "county_fips", all.x = TRUE)
b_tot <- b_county[, .(bank_dep_tot = sum(bank_dep_c)), by = RSSDID]
b_county <- merge(b_county, b_tot, by = "RSSDID")
b_county[, w := bank_dep_c / bank_dep_tot]

geo <- b_county[, .(
  branch_geo_hhi = sum(w^2),
  avg_local_hhi  = sum(w * county_hhi),
  n_counties     = uniqueN(county_fips)
), by = RSSDID]

states <- sod_2014[RSSDID %in% cohort$RSSDID,
                   .(n_states = uniqueN(branch_state)), by = RSSDID]
geo <- merge(geo, states, by = "RSSDID", all.x = TRUE)

dbDisconnect(con, shutdown = TRUE)

# -------------------------------------------------------- Call Reports 2014-Q4
rssd_list <- paste(cohort$RSSDID, collapse = ",")
fcon <- dbConnect(duckdb(), ffiec_db, read_only = TRUE)

cr <- setDT(dbGetQuery(fcon, sprintf("
  SELECT b.id_rssd AS RSSDID,
         b.assets, b.deposits, b.domestic_dep,
         b.equity, b.ln_tot, b.ln_re, b.ln_ci, b.ln_cons, b.ln_cc, b.ln_agr,
         b.llres, b.securities, b.cash, b.premises,
         b.brokered_dep, b.dom_deposit_nib, b.dom_deposit_ib,
         b.qtr_avg_assets,
         i.ytdnetinc, i.ytdint_inc_net, i.ytdnonint_exp, i.ytdnonint_inc,
         i.ytdchargeoffs, i.ytdrecoveries, i.num_employees
  FROM bs_panel b
  LEFT JOIN is_panel i USING (id_rssd, date)
  WHERE b.activity_year = %d AND b.activity_quarter = 4
    AND b.id_rssd IN (%s)
", COHORT_YEAR, rssd_list)))

dbDisconnect(fcon, shutdown = TRUE)
cat("Call Report matches: ", nrow(cr), " / ", nrow(cohort), "\n", sep = "")

# ------------------------------------------------------------- Combine + vars
dt <- merge(cohort, cr,  by = "RSSDID", all.x = TRUE)
dt <- merge(dt,     geo, by = "RSSDID", all.x = TRUE)

# Size
dt[, log_assets         := log(assets)]
dt[, log_deposits       := log(deposits)]
dt[, log_branches       := log(branches_2014)]
dt[, log_dep_per_branch := log(deposits / branches_2014)]

# Capital
dt[, equity_assets := equity / assets]

# Profitability (2014 YTD = full year)
dt[, roa := ytdnetinc / qtr_avg_assets]
dt[, nim := ytdint_inc_net / qtr_avg_assets]

# Efficiency
dt[, eff_ratio         := ytdnonint_exp / (ytdint_inc_net + ytdnonint_inc)]
dt[, nonint_exp_assets := ytdnonint_exp / assets]
dt[, premises_assets   := premises / assets]

# Asset composition
dt[, loans_assets      := ln_tot / assets]
dt[, securities_assets := securities / assets]
dt[, cash_assets       := cash / assets]

# Loan mix
dt[, re_share   := ln_re   / ln_tot]
dt[, ci_share   := ln_ci   / ln_tot]
dt[, cons_share := ln_cons / ln_tot]
dt[, cc_share   := ln_cc   / ln_tot]

# Credit risk
dt[, llres_loans          := llres / ln_tot]
dt[, net_chargeoffs_loans := (ytdchargeoffs - ytdrecoveries) / ln_tot]

# Funding
dt[, deposits_assets := deposits / assets]
dt[, nib_share       := dom_deposit_nib / domestic_dep]
dt[, brokered_share  := brokered_dep / deposits]

# Workforce
dt[, log_employees       := log(num_employees)]
dt[, assets_per_employee := assets / num_employees]

# ------------------------------------------------------------------ save
stamp <- format(Sys.Date(), "%Y%m%d")
out_file <- file.path(data_dir, paste0("cohort_2014_", stamp, ".rds"))
saveRDS(dt, out_file)
cat("Wrote: ", out_file, "\n", sep = "")
cat("Rows: ", nrow(dt), " | cols: ", ncol(dt), "\n", sep = "")

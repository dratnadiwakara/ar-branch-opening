# 12_seminar_figure_franchise_20260509.R
# =============================================================================
# Single composite seminar figure: cross-section story for >=$100B banks.
#   Panel A (left)  -- Forest plot of standardized mean differences for ~12
#                      franchise indicators (high-vintage vs low-vintage).
#   Panel B (right) -- Bank-level scatter, x = loans/assets,
#                      y = non-int income / revenue, color = new_share_b,
#                      size = log assets, labels = bank short names.
#
# Sample + variable construction mirrors 11_cross_section_franchise_20260509.qmd.
# That .qmd is the canonical reference for the table panels; this script is a
# self-contained .R producing a slide-ready PNG + PDF.
#
# Output:
#   tracks/first-draft-may2026/latex/figures/fig_franchise_seminar.png
#   tracks/first-draft-may2026/latex/figures/fig_franchise_seminar.pdf
# =============================================================================

rm(list = ls())

source("tracks/first-draft-may2026/code/common_first_draft.R")

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(duckdb)
  library(ggplot2)
  library(scales)
  library(ggrepel)
  library(patchwork)
})

# ---- Window ----------------------------------------------------------------
yr_anchor   <- 2024L
yr_lookback <- 10L
yr_new_min  <- yr_anchor - yr_lookback + 1L
min_total_branches <- 100L  # focal >=$100B sample: drop wholesale/custody banks

sod_duckdb_path   <- "C:/empirical-data-construction/sod/sod.duckdb"
ffiec_duckdb_path <- "C:/empirical-data-construction/call-reports-FFIEC/call-reports-ffiec.duckdb"

# =============================================================================
# 1. SOD vintage and 2024 stock
# =============================================================================

con <- dbConnect(duckdb::duckdb(), dbdir = sod_duckdb_path, read_only = TRUE)
uninumbr_first <- setDT(dbGetQuery(con, "
  SELECT UNINUMBR, MIN(YEAR) AS first_yr
  FROM sod
  WHERE UNINUMBR IS NOT NULL
  GROUP BY UNINUMBR
"))
sod_2024 <- setDT(dbGetQuery(con, sprintf("
  SELECT RSSDID, UNINUMBR, ASSET FROM sod
  WHERE YEAR = %d AND RSSDID IS NOT NULL AND UNINUMBR IS NOT NULL
", yr_anchor)))
banks_at_start <- setDT(dbGetQuery(con, sprintf("
  SELECT DISTINCT RSSDID FROM sod WHERE YEAR = %d AND RSSDID IS NOT NULL
", yr_new_min - 1L)))
dbDisconnect(con, shutdown = TRUE)

sod_2024[, RSSDID := as.character(RSSDID)]
banks_at_start[, RSSDID := as.character(RSSDID)]
sod_2024 <- merge(sod_2024, uninumbr_first, by = "UNINUMBR", all.x = TRUE)
sod_2024[, is_new_b := as.integer(first_yr >= yr_new_min)]

bank_lvl <- sod_2024[, .(
  n_total_2024_b  = .N,
  n_new_b         = sum(is_new_b, na.rm = TRUE),
  asset_thousands = max(as.numeric(ASSET), na.rm = TRUE)
), by = RSSDID]
bank_lvl[, new_share_b      := n_new_b / pmax(n_total_2024_b, 1)]
bank_lvl[, bank_assets      := asset_thousands * 1000]
bank_lvl[, mean_assets_b_bn := bank_assets / 1e9]
bank_lvl[, size_bucket      := assign_bucket(bank_assets)]
bank_lvl <- bank_lvl[size_bucket == "ge_100bn" &
                     n_total_2024_b >= min_total_branches &
                     RSSDID %in% banks_at_start$RSSDID]
keep_ids <- unique(bank_lvl$RSSDID)
cat("Sample size (>=$100B):", nrow(bank_lvl), "\n")

# =============================================================================
# 2. Call Report ratios + bank legal name (Q4 2014-2024)
# =============================================================================

con <- dbConnect(duckdb::duckdb(), dbdir = ffiec_duckdb_path, read_only = TRUE)
bs <- setDT(dbGetQuery(con, sprintf("
  SELECT idrssd, activity_year AS yr,
         assets, qtr_avg_assets, deposits, nm_lgl,
         cash, securities,
         ln_tot, ln_re, ln_ci, ln_cons, ln_cc, ln_agr, ln_lease,
         intangibles, goodwill, msa, equity
  FROM bs_panel
  WHERE activity_quarter = 4
    AND activity_year BETWEEN %d AND %d
    AND assets > 0
", yr_new_min - 1L, yr_anchor)))

is_ <- setDT(dbGetQuery(con, sprintf("
  SELECT idrssd, activity_year AS yr,
         ytdint_inc, ytdint_exp, ytdint_inc_net,
         ytdnonint_inc, ytdnonint_exp, ytdnetinc,
         ytdfiduc_inc, ytdsvc_charges, ytdtradrev_inc,
         ytdsalaries, num_employees
  FROM is_panel
  WHERE activity_quarter = 4
    AND activity_year BETWEEN %d AND %d
", yr_new_min - 1L, yr_anchor)))

unins_raw <- setDT(dbGetQuery(con, sprintf("
  SELECT bs.idrssd, bs.activity_year AS yr,
         bs.deposits AS dep_total,
         TRY_CAST(rco.RCONF049 AS DOUBLE) AS unins
  FROM bs_panel bs
  LEFT JOIN schedule_rco rco
    ON bs.idrssd = rco.IDRSSD
   AND bs.activity_year = rco.activity_year
   AND bs.activity_quarter = rco.activity_quarter
  WHERE bs.activity_quarter = 4
    AND bs.activity_year BETWEEN %d AND %d
    AND bs.deposits > 0
", yr_new_min - 1L, yr_anchor)))
dbDisconnect(con, shutdown = TRUE)

bs[,  idrssd := as.character(idrssd)]
is_[, idrssd := as.character(idrssd)]
unins_raw[, idrssd := as.character(idrssd)]
unins_raw[, unins_frac := pmin(unins / pmax(dep_total, 1), 1)]

cr <- merge(bs, is_, by = c("idrssd", "yr"), all.x = TRUE)
cr <- merge(cr, unins_raw[, .(idrssd, yr, unins_frac)],
            by = c("idrssd", "yr"), all.x = TRUE)
setnames(cr, "idrssd", "RSSDID")
cr <- cr[RSSDID %in% keep_ids]

# Ratios
cr[, denom_assets := pmax(assets, 1)]
cr[, denom_qavg   := pmax(qtr_avg_assets, assets, 1)]
cr[, denom_loans  := pmax(ln_tot, 1)]
cr[, revenue      := ytdint_inc_net + ytdnonint_inc]

cr[, eff_ratio          := ifelse(revenue > 0, ytdnonint_exp / revenue, NA_real_)]
cr[, nonint_inc_revenue := ifelse(revenue > 0, ytdnonint_inc / revenue, NA_real_)]
cr[, fiduc_inc_revenue  := ifelse(revenue > 0, ytdfiduc_inc  / revenue, NA_real_)]
cr[, trading_rev_revenue:= ifelse(revenue > 0, ytdtradrev_inc / revenue, NA_real_)]
cr[, msa_assets         := msa     / denom_assets]
cr[, intang_assets      := (intangibles + goodwill) / denom_assets]
cr[, loans_assets       := ln_tot  / denom_assets]
cr[, re_share_loans     := ln_re   / denom_loans]
cr[, ci_share_loans     := ln_ci   / denom_loans]
cr[, assets_per_emp_mn  := ifelse(num_employees > 0,
                                  assets / num_employees / 1e3, NA_real_)]
cr[, loan_hhi := (ln_re/denom_loans)^2 + (ln_ci/denom_loans)^2 +
                 (ln_cons/denom_loans)^2 + (ln_cc/denom_loans)^2 +
                 (ln_agr/denom_loans)^2 + (ln_lease/denom_loans)^2]

ratio_cols <- c("eff_ratio", "nonint_inc_revenue", "fiduc_inc_revenue",
                "trading_rev_revenue", "msa_assets", "intang_assets",
                "loans_assets", "re_share_loans", "ci_share_loans",
                "assets_per_emp_mn", "loan_hhi", "unins_frac")

cr_b <- cr[, lapply(.SD, function(x) mean(x, na.rm = TRUE)),
           by = RSSDID, .SDcols = ratio_cols]

# Bank short name from most recent record.
nm <- cr[order(RSSDID, -yr)][!is.na(nm_lgl) & nzchar(nm_lgl),
                              .(nm_lgl = first(nm_lgl)), by = RSSDID]
cr_b <- merge(cr_b, nm, by = "RSSDID", all.x = TRUE)

# =============================================================================
# 3. Deposit beta (bank-zip-year -> bank avg) and master mortgage breadth
# =============================================================================

beta_path <- load_latest(file.path(data_dir, "bank_zip_year_deposit_beta_*.rds"))
bb <- setDT(readRDS(beta_path))
bb[, RSSDID := as.character(RSSDID)]
beta_b <- bb[!is.na(deposit_beta) & is.finite(deposit_beta) &
             yr >= yr_new_min - 1L & yr <= yr_anchor &
             RSSDID %in% keep_ids,
             .(deposit_beta = mean(deposit_beta, na.rm = TRUE)),
             by = RSSDID]

master_parts <- Sys.glob(file.path(data_dir, "master_bank_zip_year_*_part*.rds"))
dates_m      <- regmatches(master_parts, regexpr("\\d{8}", master_parts))
master_parts <- sort(master_parts[dates_m == max(dates_m)])
mst <- rbindlist(lapply(master_parts, readRDS))
mst[, RSSDID := as.character(RSSDID)]
br <- mst[yr >= yr_new_min - 1L & yr <= yr_anchor & RSSDID %in% keep_ids,
          .(n_zips_op   = sum(n_branches_bzt > 0L,        na.rm = TRUE),
            n_zips_mort = sum(mortgage_presence == 1L,    na.rm = TRUE)),
          by = .(RSSDID, yr)]
breadth_b <- br[, .(mort_branch_ratio = mean(n_zips_mort / pmax(n_zips_op, 1))),
                by = RSSDID]
rm(mst); gc(verbose = FALSE)

# =============================================================================
# 4. Combined panel
# =============================================================================

panel <- Reduce(function(a, b) merge(a, b, by = "RSSDID", all.x = TRUE),
                list(bank_lvl, cr_b, beta_b, breadth_b))

# Winsorize 1/99 within sample to keep extreme-bank pull off scale.
winsor_vars <- c(ratio_cols, "deposit_beta", "mort_branch_ratio")
for (v in winsor_vars) {
  set(panel, j = v, value = winsor(panel[[v]], p = c(0.01, 0.99)))
}

# High-vintage indicator (median split within >=$100B).
panel[, high_opener := as.integer(new_share_b >= median(new_share_b, na.rm = TRUE))]

# =============================================================================
# 5. Forest plot data: standardized mean differences with 95% CI
# =============================================================================

forest_vars <- c(
  "loans_assets",         "Loans / assets",
  "re_share_loans",       "RE / loans",
  "msa_assets",           "Mortgage servicing rights / assets",
  "unins_frac",           "Uninsured deposits / total",
  "loan_hhi",             "Loan portfolio HHI",
  "eff_ratio",            "Efficiency ratio",
  "deposit_beta",         "Deposit beta",
  "ci_share_loans",       "C&I / loans",
  "assets_per_emp_mn",    "Assets / employee",
  "mort_branch_ratio",    "Mortgage zips / branch zips",
  "intang_assets",        "Intangibles+goodwill / assets",
  "nonint_inc_revenue",   "Non-int income / revenue",
  "fiduc_inc_revenue",    "Fiduciary income / revenue",
  "trading_rev_revenue",  "Trading revenue / revenue"
)
forest_dt <- data.table(
  var   = forest_vars[seq(1, length(forest_vars), by = 2)],
  label = forest_vars[seq(2, length(forest_vars), by = 2)]
)

compute_smd <- function(d, v) {
  x_lo <- d[high_opener == 0L, get(v)]; x_lo <- x_lo[is.finite(x_lo)]
  x_hi <- d[high_opener == 1L, get(v)]; x_hi <- x_hi[is.finite(x_hi)]
  if (length(x_lo) < 2 || length(x_hi) < 2) return(list(NA, NA, NA, NA, ""))
  s_pool <- sqrt(((length(x_lo) - 1) * var(x_lo) +
                  (length(x_hi) - 1) * var(x_hi)) /
                 (length(x_lo) + length(x_hi) - 2))
  d_smd  <- (mean(x_hi) - mean(x_lo)) / s_pool
  tt     <- tryCatch(t.test(x_hi, x_lo), error = function(e) NULL)
  ci_lo  <- if (!is.null(tt)) tt$conf.int[1] / s_pool else NA_real_
  ci_hi  <- if (!is.null(tt)) tt$conf.int[2] / s_pool else NA_real_
  p      <- if (!is.null(tt)) tt$p.value else NA_real_
  sig    <- if (is.na(p)) "" else if (p < 0.01) "***" else if (p < 0.05) "**" else if (p < 0.10) "*" else ""
  list(d_smd, ci_lo, ci_hi, p, sig)
}

forest_dt[, c("smd", "lo", "hi", "p", "sig") :=
            transpose(lapply(var, function(v) compute_smd(panel, v)))]
forest_dt[, smd := as.numeric(smd)]
forest_dt[, lo  := as.numeric(lo)]
forest_dt[, hi  := as.numeric(hi)]
forest_dt[, label_full := ifelse(nzchar(sig),
                                 paste0(label, " ", sig),
                                 label)]
forest_dt[, sign_color := ifelse(smd >= 0, "more", "less")]
setorder(forest_dt, smd)
forest_dt[, label_full := factor(label_full, levels = label_full)]

# =============================================================================
# 6. Scatter: short bank names
# =============================================================================

# Hand-curated short-name dictionary keyed on case-insensitive substring of nm_lgl.
short_map <- list(
  list("JPMORGAN",                  "JPMorgan"),
  list("BANK OF AMERICA",           "BoA"),
  list("WELLS FARGO",               "Wells Fargo"),
  list("CITIBANK",                  "Citi"),
  list("U.S. BANK",                 "US Bank"),
  list("PNC BANK",                  "PNC"),
  list("CAPITAL ONE",               "Capital One"),
  list("TD BANK",                   "TD Bank"),
  list("GOLDMAN SACHS",             "Goldman"),
  list("MORGAN STANLEY",            "Morgan Stanley"),
  list("CHARLES SCHWAB",            "Schwab"),
  list("BANK OF NEW YORK MELLON",   "BNY Mellon"),
  list("STATE STREET",              "State Street"),
  list("FIFTH THIRD",               "Fifth Third"),
  list("HUNTINGTON NATIONAL",       "Huntington"),
  list("KEYBANK",                   "KeyBank"),
  list("REGIONS BANK",              "Regions"),
  list("FIRST CITIZENS BANK",       "First Citizens"),
  list("CITIZENS BANK",             "Citizens"),
  list("TRUIST",                    "Truist"),
  list("M&T BANK",                  "M&T"),
  list("MANUFACTURERS AND TRADERS", "M&T"),
  list("ALLY BANK",                 "Ally"),
  list("FLAGSTAR",                  "Flagstar"),
  list("BMO BANK",                  "BMO"),
  list("BMO HARRIS",                "BMO"),
  list("HSBC",                      "HSBC"),
  list("NORTHERN TRUST",            "Northern Trust"),
  list("DISCOVER",                  "Discover"),
  list("AMERICAN EXPRESS",          "AmEx"),
  list("USAA FEDERAL",              "USAA"),
  list("FIRST REPUBLIC",            "First Republic"),
  list("SILICON VALLEY",            "SVB"),
  list("SIGNATURE BANK",            "Signature"),
  list("ZIONS BANCORPORATION",      "Zions"),
  list("ZIONS BANK",                "Zions"),
  list("COMERICA",                  "Comerica"),
  list("WEBSTER BANK",              "Webster"),
  list("EAST WEST",                 "East West"),
  list("CIBC",                      "CIBC"),
  list("RBC BANK",                  "RBC"),
  list("UBS BANK",                  "UBS"),
  list("DEUTSCHE BANK",             "Deutsche"),
  list("BARCLAYS",                  "Barclays"),
  list("MUFG",                      "MUFG"),
  list("MIZUHO",                    "Mizuho"),
  list("SUMITOMO MITSUI",           "SMBC"),
  list("SANTANDER",                 "Santander"),
  list("VALLEY NATIONAL",           "Valley")
)

short_name <- function(s) {
  if (is.na(s) || !nzchar(s)) return(NA_character_)
  s_up <- toupper(trimws(s))
  for (m in short_map) {
    if (grepl(m[[1L]], s_up, fixed = TRUE)) return(m[[2L]])
  }
  # Fallback: title-case, drop "BANK" / "NATIONAL ASSOCIATION" tail.
  s2 <- gsub(", NATIONAL ASSOCIATION", "", s_up, fixed = TRUE)
  s2 <- gsub(",? N\\.?A\\.?$", "", s2, perl = TRUE)
  s2 <- gsub(", THE$", "", s2)
  s2 <- gsub(" BANK( USA)?$", "", s2)
  s2 <- gsub(" COMPANY$", "", s2)
  tools::toTitleCase(tolower(s2))
}
panel[, name_short := vapply(nm_lgl, short_name, character(1))]

# =============================================================================
# 7. Plot
# =============================================================================

p_forest <- ggplot(forest_dt,
                   aes(x = smd, y = label_full, color = sign_color)) +
  geom_vline(xintercept = 0, color = accent_gray, linewidth = 0.4) +
  geom_pointrange(aes(xmin = lo, xmax = hi), size = 0.5, linewidth = 0.7) +
  scale_color_manual(values = c(more = primary_blue, less = primary_gold),
                     guide = "none") +
  labs(x = "Standardized difference (high \u2212 low vintage)",
       y = NULL,
       subtitle = "Mean differences (95% CI)") +
  theme_custom(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        axis.text.y = element_text(size = 10))

p_scatter <- ggplot(panel, aes(x = loans_assets, y = nonint_inc_revenue)) +
  geom_hline(yintercept = median(panel$nonint_inc_revenue, na.rm = TRUE),
             color = accent_gray, linetype = "dashed", linewidth = 0.3) +
  geom_vline(xintercept = median(panel$loans_assets, na.rm = TRUE),
             color = accent_gray, linetype = "dashed", linewidth = 0.3) +
  geom_point(aes(color = new_share_b, size = log(mean_assets_b_bn + 1)),
             alpha = 0.9, stroke = 0.4) +
  geom_text_repel(aes(label = name_short),
                  size = 3.2, max.overlaps = 30,
                  segment.color = accent_gray, segment.size = 0.3,
                  min.segment.length = 0, box.padding = 0.35) +
  scale_color_gradient(low = primary_gold, high = primary_blue,
                       labels = scales::percent_format(accuracy = 1),
                       name = "Share new\n(2015\u201324)") +
  scale_size_continuous(range = c(2, 7), guide = "none") +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(NA, NA)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(x = "Loans / assets",
       y = "Non-interest income / revenue",
       subtitle = paste0("Each dot = one bank (n=", nrow(panel), ")")) +
  theme_custom(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        legend.position  = "right")

caption_txt <- paste0(
  "Sample: ", nrow(panel),
  " U.S. commercial banks with assets >=$100B in 2024, >=100 branches in 2024, and present in SOD in 2014. ",
  "Variables averaged 2014-2024.")

fig <- (p_forest | p_scatter) +
  plot_layout(widths = c(0.42, 0.58)) +
  plot_annotation(
    title    = "Cross-section of >=$100B retail-banking franchises by branch vintage",
    caption  = caption_txt,
    theme    = theme(plot.title   = element_text(face = "bold",
                                                 color = primary_blue,
                                                 size = 15,
                                                 margin = margin(b = 8)),
                     plot.caption = element_text(color = accent_gray,
                                                 size = 9, hjust = 0))
  )

# =============================================================================
# 8. Save
# =============================================================================

out_png <- file.path(figures_dir, "fig_franchise_seminar.png")
out_pdf <- file.path(figures_dir, "fig_franchise_seminar.pdf")
ggsave(out_png, plot = fig, width = 14, height = 6.5, dpi = 300, bg = "white")
ggsave(out_pdf, plot = fig, width = 14, height = 6.5,             bg = "white")
cat("Wrote:", out_png, "\n")
cat("Wrote:", out_pdf, "\n")

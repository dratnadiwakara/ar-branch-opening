# common_first_draft.R  -- by-size variant
#
# Shared libraries, paths, helpers, and regression-table utilities for the
# size-bucketed public-data approach.  Sourced by every script in this folder.
#
# Folder layout (relative to project root):
#   tracks/first-draft-may2026/
#       code/common_first_draft.R              # this file
#       code/sample-construction/00_build_panel.R
#       code/sample-construction/01_build_deposit_beta.R
#       code/sample-construction/02_build_bank_advantage.R
#       code/sample-construction/03_build_cross_sell.R
#       code/sample-construction/04_build_master_dataset.R
#       code/result-generation/05_run_all_results.R
#       data/                          # ALL .rds outputs land here (track-local)
#       latex/tables/                  # markdown tables (one per analysis)
#       latex/figures/                 # reserved
#
# write_reg_table() accepts an optional out_dir argument.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(knitr)
  library(ggplot2)
})

# ---- Paths -------------------------------------------------------------------

track_dir    <- "tracks/first-draft-may2026"
data_dir     <- file.path(track_dir, "data")
tables_dir   <- file.path(track_dir, "latex", "tables")
figures_dir  <- file.path(track_dir, "latex", "figures")

dir.create(data_dir,    showWarnings = FALSE, recursive = TRUE)
dir.create(tables_dir,  showWarnings = FALSE, recursive = TRUE)
dir.create(figures_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Toggles -----------------------------------------------------------------

save_tables  <- TRUE
save_figures <- TRUE

# ---- Colour palette ----------------------------------------------------------

primary_blue   <- "#012169"
primary_gold   <- "#f2a900"
accent_gray    <- "#525252"
positive_green <- "#15803d"
negative_red   <- "#b91c1c"

theme_custom <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", color = primary_blue),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      plot.background  = element_rect(fill = "transparent", color = NA),
      panel.background = element_rect(fill = "transparent", color = NA)
    )
}

# ---- Helpers -----------------------------------------------------------------

load_latest <- function(glob, must_exist = TRUE) {
  hits <- Sys.glob(glob)
  if (length(hits) == 0L) {
    if (must_exist) stop("No file matched glob: ", glob)
    return(NULL)
  }
  hits[order(file.info(hits)$mtime, decreasing = TRUE)[1]]
}

winsor <- function(x, p = c(0.01, 0.99)) {
  q <- quantile(x, probs = p, na.rm = TRUE)
  pmin(pmax(x, q[[1]]), q[[2]])
}

# ---- Size-bucket definition (used by 04 + 05) --------------------------------
# Buckets defined on bank-year assets ($, from SOD ASSET * 1000).  A bank can
# move between buckets across years.  Bottom bucket (<$1B) intentionally
# excluded.

size_buckets <- list(
  ge_100bn  = list(label = "Bank assets >= $100B", min = 100e9, max = Inf,    short = ">=$100B"),
  `10_100bn`= list(label = "Bank assets $10B-$100B", min = 10e9,  max = 100e9, short = "$10B-$100B"),
  `1_10bn`  = list(label = "Bank assets $1B-$10B",  min = 1e9,   max = 10e9,  short = "$1B-$10B")
)

bucket_names  <- names(size_buckets)
bucket_short  <- vapply(size_buckets, `[[`, character(1), "short")
bucket_label  <- vapply(size_buckets, `[[`, character(1), "label")

# Assign a row to a bucket name (NA if outside [1e9, Inf) or missing assets).
assign_bucket <- function(assets) {
  out <- rep(NA_character_, length(assets))
  for (bk in bucket_names) {
    cfg <- size_buckets[[bk]]
    out[!is.na(assets) & assets >= cfg$min & assets < cfg$max] <- bk
  }
  out
}

# ---- fixest defaults ---------------------------------------------------------

setFixest_etable(
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.1),
  se.below    = TRUE
)

# ---- Canonical control vector ------------------------------------------------

base_controls <- c(
  "g_dep_zip_t1_t3", "g_hmda_t1_t3", "g_cra_t1_t3",
  "log_dep_zip_lag1", "log_avg_agi_lag1",
  "median_age_lag1", "pct_college_educated_lag1",
  "log_pop_density_lag1",
"no_bank_zip_lag1",
 "bank_in_state_lag1","share_bzt_lag1",
   "log_n_branches_lag1"
)
#, "share_bzt_lag1""bank_in_state_lag1", "n_large_banks_zip_lag1",  "hhi_lag1", 
base_rhs <- paste(base_controls, collapse = " + ")

# ---- Variable labels (for table dictionaries) --------------------------------

var_labels <- c(
  g_dep_zip_t1_t3              = "Zip deposit growth, t-3 to t-1",
  deposit_beta                 = "Deposit beta",
  rate_paying_adv              = "Rate-paying advantage (cost slack vs incumbents)",
  high_rate_paying             = "1{rate_paying_adv > 0}",
  high_IEA                     = "1{IEA undercut > 0.5}",
  int_exp_assets_share_undercut = "IEA undercut share",
  mortgage_presence            = "Mortgage presence (binary, t-1)",
  mortgage_share               = "Mortgage market share, t-1",
  cra_presence                 = "CRA small-biz presence (binary, t-1)",
  cra_share                    = "CRA small-biz county share, t-1",
  "deposit_beta:rate_paying_adv"     = "Deposit beta x Rate-paying adv",
  "deposit_beta:high_rate_paying"    = "Deposit beta x high_rate_paying",
  "deposit_beta:high_IEA"            = "Deposit beta x high_IEA",
  "deposit_beta:mortgage_presence"   = "Deposit beta x Mortgage presence",
  "deposit_beta:cra_presence"        = "Deposit beta x CRA presence",
  g_hmda_t1_t3                 = "Zip HMDA lending growth, t-3 to t-1",
  g_cra_t1_t3                  = "Zip CRA small-biz growth, t-3 to t-1",
  log_dep_zip_lag1             = "log(zip deposits), t-1",
  log_avg_agi_lag1             = "log(avg AGI), t-1",
  median_age_lag1              = "Median age, t-1",
  pct_college_educated_lag1    = "% college educated (25+), t-1",
  log_pop_density_lag1         = "log(zip pop density), t-1",
  hhi_lag1                     = "Zip deposit HHI / 10,000, t-1",
  no_bank_zip_lag1             = "No SOD bank in zip, t-1",
  n_large_banks_zip_lag1       = "# large banks in zip, t-1",
  bank_in_state_lag1           = "Bank in zip's state, t-1",
  log_n_branches_lag1          = "log(1 + bank's branches in zip), t-1",
  share_bzt_lag1               = "Bank's zip deposit share, t-1"
)

treat_vars_all <- c(
  "g_dep_zip_t1_t3",
  "deposit_beta",
  "rate_paying_adv", "high_rate_paying", "high_IEA", "int_exp_assets_share_undercut",
  "mortgage_presence", "mortgage_share",
  "cra_presence", "cra_share",
  "deposit_beta:rate_paying_adv",
  "deposit_beta:high_rate_paying",
  "deposit_beta:high_IEA",
  "deposit_beta:mortgage_presence",
  "deposit_beta:cra_presence"
)

# ---- Regression-table writer (markdown) --------------------------------------

stars <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.01)  "***"
  else if (p < 0.05) "**"
  else if (p < 0.10) "*"
  else ""
}

# Write a regression table.  `models` is a list (length = number of columns),
# `col_headers` parallel-length character vector.  `data_for_stats_list` is
# either a single data.table (used for every column's Mean/SD footers) or a
# list of data.tables (one per model column) when each column was estimated
# on a different sample (e.g., one bucket per column).
write_reg_table <- function(models, col_headers, treat_name, treat_label,
                            data_for_stats, fe_labels, filename,
                            out_dir = tables_dir) {

  ds_is_list <- is.list(data_for_stats) && !is.data.frame(data_for_stats)
  if (ds_is_list && length(data_for_stats) != length(models))
    stop("data_for_stats list length must match models length")

  mean_dv  <- if (ds_is_list)
    vapply(data_for_stats, function(d) round(mean(d$opening, na.rm = TRUE), 4),
           numeric(1))
  else rep(round(mean(data_for_stats$opening, na.rm = TRUE), 4),
           length(models))

  sd_treat <- if (ds_is_list)
    vapply(data_for_stats, function(d) round(sd(d[[treat_name]], na.rm = TRUE), 4),
           numeric(1))
  else rep(round(sd(data_for_stats[[treat_name]], na.rm = TRUE), 4),
           length(models))

  all_vars   <- unique(unlist(lapply(models, function(m) names(coef(m)))))
  treat_v    <- all_vars[all_vars %in% treat_vars_all]
  ctrl_v     <- setdiff(all_vars, treat_v)
  ordered_v  <- c(treat_v, ctrl_v)

  rows <- list()
  for (v in ordered_v) {
    label <- if (!is.na(var_labels[v])) var_labels[v] else v
    est_row <- c(label, sapply(models, function(m) {
      co <- coef(m)[v]
      if (is.na(co)) return("")
      se <- sqrt(diag(vcov(m)))[v]
      p  <- 2 * pnorm(-abs(co / se))
      sprintf("%.5f%s", co, stars(p))
    }))
    se_row  <- c("", sapply(models, function(m) {
      se <- sqrt(diag(vcov(m)))[v]
      if (is.na(se)) return("")
      sprintf("(%.5f)", se)
    }))
    rows[[length(rows) + 1L]] <- est_row
    rows[[length(rows) + 1L]] <- se_row
  }

  n_row    <- c("N",             sapply(models, function(m) format(nobs(m), big.mark = ",")))
  fe_row   <- c("Fixed Effects", fe_labels)
  cl_row   <- c("Cluster",       rep("zip5", length(models)))
  mean_row <- c("Mean(opening)", sprintf("%.4f", mean_dv))
  sd_row   <- c(paste0("SD(", treat_label, ")"),
                sprintf("%.4f", sd_treat))
  rows <- c(rows, list(n_row, fe_row, cl_row, mean_row, sd_row))

  tbl <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  colnames(tbl) <- c("", col_headers)

  out_md <- file.path(out_dir, filename)
  md     <- knitr::kable(tbl, format = "pipe", row.names = FALSE)
  writeLines(as.character(md), out_md)
  cat("Wrote:", out_md, "\n")
}

# ---- Chat-summary helper -----------------------------------------------------

key_coef <- function(model, var_name) {
  if (!var_name %in% names(coef(model))) return(NULL)
  co  <- coef(model)[[var_name]]
  se  <- sqrt(diag(vcov(model)))[[var_name]]
  p   <- 2 * pnorm(-abs(co / se))
  list(co = co, se = se, sig = stars(p), n = nobs(model))
}

print_summary <- function(models, spec_labels, var_name) {
  cat("\n--- Key-coefficient summary (treatment =", var_name, ") ---\n")
  cat("| Spec | Coef | SE | Sig | N |\n|---|---|---|---|---|\n")
  for (i in seq_along(models)) {
    r <- key_coef(models[[i]], var_name)
    if (is.null(r)) next
    cat(sprintf("| %s | %.5f | %.5f | %s | %s |\n",
                spec_labels[[i]], r$co, r$se, r$sig,
                format(r$n, big.mark = ",")))
  }
}

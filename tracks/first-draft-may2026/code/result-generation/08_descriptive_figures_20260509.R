# 08_descriptive_figures_20260509.R
# =============================================================================
# Descriptive figures for the first-draft-may2026 paper:
#   (1) Total U.S. branches per year from FDIC SOD (full SOD history).
#   (2) Stacked-area de-novo openings by year and bank size bucket
#       (sample period >= 2010), mirroring
#       _delete/.../approach-descriptive-april2026/02_denovo_openings_by_year_size_*.R.
#   (3) Three candidate-market choropleth maps:
#         JPMorgan Chase 2016, Bank of America 2018, Wells Fargo 2022.
#       Counties shaded by status: existing footprint vs. candidate-only.
#
# Outputs (under tracks/first-draft-may2026/latex/figures/):
#   fig_us_branches_total.png    + .pdf
#   fig_openings_by_size_stacked.png + .pdf
#   fig_map_jpm_2016.png         + .pdf
#   fig_map_boa_2018.png         + .pdf
#   fig_map_wfc_2022.png         + .pdf
# =============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(duckdb)
  library(ggplot2)
  library(scales)
  library(sf)
  library(tigris)
})

source("tracks/first-draft-may2026/code/common_first_draft.R")

options(tigris_use_cache = TRUE)

sod_duckdb_path <- "C:/empirical-data-construction/sod/sod.duckdb"

stopifnot(file.exists(sod_duckdb_path))

save_fig <- function(p, stem, w = 8, h = 4.5, dpi = 300) {
  out <- file.path(figures_dir, paste0(stem, ".png"))
  ggsave(out, plot = p, width = w, height = h, dpi = dpi, bg = "white")
  cat("Wrote:", out, "\n")
}

normalize_zip5 <- function(x) {
  x_chr <- gsub("[^0-9]", "", trimws(as.character(x)))
  out   <- rep(NA_character_, length(x_chr))
  ok    <- nzchar(x_chr)
  out[ok] <- sprintf("%05.0f", suppressWarnings(as.numeric(x_chr[ok])))
  out
}

# =============================================================================
# 1. Total U.S. branches per year
# =============================================================================

cat("\n--- (1) Branch count time series ---\n")

con <- dbConnect(duckdb::duckdb(), dbdir = sod_duckdb_path, read_only = TRUE)
brn <- setDT(dbGetQuery(con,
  "SELECT YEAR, COUNT(*) AS n_branches FROM sod GROUP BY YEAR ORDER BY YEAR"
))
dbDisconnect(con, shutdown = TRUE)

brn[, YEAR := as.integer(YEAR)]
cat("Years:", min(brn$YEAR), "-", max(brn$YEAR),
    "| total range:", format(min(brn$n_branches), big.mark = ","),
    "to", format(max(brn$n_branches), big.mark = ","), "\n")

p_brn <- ggplot(brn, aes(x = YEAR, y = n_branches)) +
  geom_line(color = primary_blue, linewidth = 0.9) +
  geom_point(color = primary_blue, size = 1.8) +
  scale_y_continuous(labels = scales::comma) +
  scale_x_continuous(breaks = seq(1995, 2025, 5)) +
  labs(x = "Year", y = "Number of branches", title = NULL) +
  theme_custom()

save_fig(p_brn, "fig_us_branches_total", w = 8, h = 4.5)

# =============================================================================
# 2. Stacked-area de-novo openings by size bucket
# =============================================================================

cat("\n--- (2) Stacked openings by size ---\n")

cut_large <- 100e9
cut_mid   <-  10e9
cut_small <-   1e9
year_min  <- 2012L

ots_transfer_year <- 2011L
ots_pre_start     <- 2004L
ots_pre_end       <- 2010L

con <- dbConnect(duckdb::duckdb(), dbdir = sod_duckdb_path, read_only = TRUE)
sod <- setDT(dbGetQuery(con, "
  SELECT UNINUMBR, YEAR, RSSDID, ASSET
  FROM sod
  WHERE UNINUMBR IS NOT NULL
"))
uninumbr_global <- setDT(dbGetQuery(con, "
  SELECT UNINUMBR, MIN(YEAR) AS first_yr
  FROM sod
  WHERE UNINUMBR IS NOT NULL
  GROUP BY UNINUMBR
"))
ots_rssd <- setDT(dbGetQuery(con, sprintf("
  WITH first_year AS (
    SELECT UNINUMBR, RSSDID, MIN(YEAR) AS first_yr
    FROM sod
    GROUP BY UNINUMBR, RSSDID
  ),
  rssd_window AS (
    SELECT
      RSSDID,
      MAX(CASE WHEN first_yr = %d THEN 1 ELSE 0 END) AS opened_2011,
      MAX(CASE WHEN first_yr BETWEEN %d AND %d THEN 1 ELSE 0 END) AS opened_pre
    FROM first_year
    WHERE first_yr BETWEEN %d AND %d
    GROUP BY RSSDID
  )
  SELECT RSSDID
  FROM rssd_window
  WHERE opened_2011 = 1 AND opened_pre = 0
", ots_transfer_year, ots_pre_start, ots_pre_end,
   ots_pre_start,     ots_transfer_year)))$RSSDID
dbDisconnect(con, shutdown = TRUE)

cat("OTS-transfer RSSDs excluded:", length(ots_rssd), "\n")

sod[, YEAR   := as.integer(YEAR)]
sod[, assets := as.numeric(ASSET) * 1000]
year_max <- max(sod$YEAR, na.rm = TRUE)

openings <- merge(sod, uninumbr_global, by = "UNINUMBR")
openings <- openings[YEAR == first_yr & !(RSSDID %in% ots_rssd)]
openings <- openings[YEAR >= year_min & YEAR <= year_max]

openings[, size_bucket := fcase(
  is.na(assets),       "unknown",
  assets >= cut_large, ">=$100B",
  assets >= cut_mid,   "$10B-$100B",
  assets >= cut_small, "$1B-$10B",
  default            = "<$1B"
)]
openings <- openings[size_bucket != "unknown"]

agg <- openings[, .(n_open = .N), by = .(year = YEAR, size_bucket)]
agg[, size_bucket := factor(size_bucket,
                            levels = c("<$1B", "$1B-$10B",
                                       "$10B-$100B", ">=$100B"))]
setorder(agg, year, size_bucket)

bucket_palette <- c(
  "<$1B"        = accent_gray,
  "$1B-$10B"    = positive_green,
  "$10B-$100B"  = primary_gold,
  ">=$100B"     = primary_blue
)

p_open <- ggplot(agg, aes(x = year, y = n_open, fill = size_bucket)) +
  geom_area(alpha = 0.95) +
  scale_fill_manual(values = bucket_palette,
                    breaks = c(">=$100B", "$10B-$100B",
                               "$1B-$10B", "<$1B")) +
  scale_y_continuous(labels = scales::comma) +
  scale_x_continuous(breaks = seq(year_min, year_max, 2)) +
  labs(x = "Year", y = "De-novo branch openings",
       fill = "Bank assets", title = NULL) +
  theme_custom()

save_fig(p_open, "fig_openings_by_size_stacked", w = 8, h = 4.5)

# =============================================================================
# 3. Candidate-market maps at the ZCTA level
#    (JPM 2016, BoA 2018, WF 2022)
# Mirrors _delete/.../approach-baseline-regression/02_map_opportunity_set_*.R.
# =============================================================================

cat("\n--- (3) Candidate-market maps (ZCTA level) ---\n")

bank_targets <- data.table(
  rssdid    = c(852218L,         480228L,           451965L),
  short     = c("jpm",           "boa",             "wfc"),
  bank_name = c("JPMorgan Chase","Bank of America", "Wells Fargo"),
  year      = c(2016L,           2018L,             2022L)
)

zcta_year        <- 2020L
simplify_deg     <- 0.005
zcta_cache       <- "data/constructed/zcta_conus_2020_simplified.rds"
states_cache     <- "data/constructed/states_conus_2020.rds"
conus_non_states <- c("AK", "HI", "PR", "VI", "GU", "AS", "MP")

# ---- State outlines ---------------------------------------------------------
if (file.exists(states_cache)) {
  states_sf <- readRDS(states_cache)
} else {
  cat("Downloading state polygons via tigris...\n")
  s <- tigris::states(year = zcta_year, cb = TRUE, progress_bar = FALSE)
  s <- s[!s$STUSPS %in% conus_non_states, ]
  s <- st_transform(s, 4326)
  s <- st_simplify(s, dTolerance = simplify_deg, preserveTopology = TRUE)
  states_sf <- s[, "STUSPS"]
  saveRDS(states_sf, states_cache)
}

# ---- ZCTA polygons (CONUS, simplified) --------------------------------------
if (file.exists(zcta_cache)) {
  zcta_sf <- readRDS(zcta_cache)
} else {
  cat("Downloading ZCTA polygons via tigris (one-time, ~50 MB)...\n")
  z <- tigris::zctas(year = zcta_year, cb = TRUE, progress_bar = FALSE)
  zip_col <- intersect(c("ZCTA5CE20", "GEOID20", "ZCTA5CE10", "GEOID10",
                         "ZCTA5CE", "GEOID"), names(z))[1L]
  if (is.na(zip_col)) stop("Cannot find ZCTA code column in tigris output.")
  z$zip5 <- as.character(z[[zip_col]])
  z <- z[nchar(z$zip5) == 5L, ]
  z <- st_transform(z, 4326)

  cent <- suppressWarnings(st_coordinates(st_centroid(st_geometry(z))))
  keep <- cent[, 1] > -125 & cent[, 1] < -66 & cent[, 2] > 24 & cent[, 2] < 50
  z <- z[keep, ]

  cat("Simplifying", nrow(z), "ZCTA polygons...\n")
  z <- st_simplify(z, dTolerance = simplify_deg, preserveTopology = TRUE)
  zcta_sf <- z[, "zip5"]
  saveRDS(zcta_sf, zcta_cache)
}

cat("ZCTA polygons:", nrow(zcta_sf), "| States:", nrow(states_sf), "\n")

# ---- Opportunity panel ------------------------------------------------------
opp <- setDT(readRDS(load_latest(file.path(data_dir,
                                            "bank_year_zip_panel_*.rds"))))
if ("YEAR" %in% names(opp)) setnames(opp, "YEAR", "yr")
opp[, zip5 := normalize_zip5(zip5)]
opp[, yr   := as.integer(yr)]

map_palette <- c(
  "Operating"            = primary_blue,
  "In sample, no branch" = primary_gold
)

theme_map <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", color = primary_blue),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      plot.background  = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      panel.grid       = element_blank(),
      axis.text        = element_blank(),
      axis.title       = element_blank()
    )
}

draw_one_map <- function(rssdid, yr_t, bank_name, file_stem) {
  cat(sprintf("  %s (%d): RSSDID %d\n", bank_name, yr_t, rssdid))
  d <- opp[RSSDID == rssdid & yr == yr_t]
  if (nrow(d) == 0L)
    stop(sprintf("No opportunity-set rows for RSSDID %d in %d", rssdid, yr_t))

  d[, zip_status := fifelse(n_branches_bzt > 0, "Operating",
                                                "In sample, no branch")]
  m <- merge(zcta_sf, d[, .(zip5, zip_status)], by = "zip5")
  m$zip_status <- factor(m$zip_status,
                         levels = c("Operating", "In sample, no branch"))

  cat(sprintf("    zctas: %d operating, %d candidate-only\n",
              sum(m$zip_status == "Operating"),
              sum(m$zip_status == "In sample, no branch")))

  p <- ggplot() +
    geom_sf(data = states_sf, fill = "white", color = "gray70", linewidth = 0.2) +
    geom_sf(data = m, aes(fill = zip_status), color = NA) +
    geom_sf(data = states_sf, fill = NA, color = "gray40", linewidth = 0.25) +
    scale_fill_manual(values = map_palette, drop = FALSE) +
    coord_sf(xlim = c(-125, -66), ylim = c(24, 50), expand = FALSE) +
    labs(title = NULL, subtitle = NULL) +
    theme_map()

  save_fig(p, file_stem, w = 10, h = 6.5, dpi = 150)
}

for (i in seq_len(nrow(bank_targets))) {
  bt <- bank_targets[i]
  draw_one_map(bt$rssdid, bt$year, bt$bank_name,
               sprintf("fig_map_%s_%d", bt$short, bt$year))
}

cat("\nDone.\n")

# 00a_build_zip_population_density_20260508.R
# =============================================================================
# Build county-year and zip-year population density panels.
#
# Population density = 1000 people per square kilometer.
# Formula: (pop_acs5 * 1e6 / land_area_sqm) / 1000.
#
# Forked from:
#   C:/Users/dimut/OneDrive/github/_delete/bank-branch-openings/
#     code/approach-baseline-regression/04_build_population_density_20260424.R
# (vendored into this track so the sample-construction pipeline is self-
# contained.)  No edits beyond this header -- ZCTA boundaries and ACS pulls
# are not bank-size-dependent, so output paths remain the project-level
# `data/raw/` locations consumed by 00_build_panel.R.
#
# Run order (within tracks/first-draft-may2026/code/sample-construction):
#   00a (this script) -> 00b -> 00 -> 01 -> 02 -> 03 -> 04
#
# Output:
#   data/raw/county_population_density.rds   (2000-2023)
#   data/raw/zip_population_density.rds      (ACS 5-yr zcta coverage + fills)
# =============================================================================

rm(list = ls())

library(data.table)
library(tigris)
library(tidycensus)
library(sf)
library(yaml)

options(tigris_use_cache = TRUE)

# ---- Parameters --------------------------------------------------------------

key_yaml_path  <- "C:/key-variables/key-variables.yaml"
raw_dir        <- "data/raw"
acs_years      <- 2009:2022          # acs5 available from 2009
zcta_vintage   <- 2020               # boundary/area vintage
fill_forward_to   <- 2023            # carry 2022 -> 2023
fill_backward_min <- 2000            # carry 2009 back to 2000

county_out_path <- file.path(raw_dir, "county_population_density.rds")
zip_out_path    <- file.path(raw_dir, "zip_population_density.rds")

# ---- API key -----------------------------------------------------------------

if (!file.exists(key_yaml_path)) stop("Missing: ", key_yaml_path, call. = FALSE)
keys <- yaml::read_yaml(key_yaml_path)
census_key <- keys$api_keys$census
if (is.null(census_key) || !nzchar(census_key)) {
  stop("api_keys$census not set in ", key_yaml_path, call. = FALSE)
}
census_api_key(census_key, overwrite = TRUE, install = FALSE)

# ============================================================================
# County-year population density
# ============================================================================

message("Downloading county boundaries (cb vintage ", zcta_vintage, ")...")
us_counties <- tigris::counties(cb = TRUE, year = zcta_vintage, progress_bar = FALSE)
county_area <- setDT(sf::st_drop_geometry(us_counties[, "GEOID"]))
county_area[, land_area_sqm := us_counties$ALAND]
setnames(county_area, "GEOID", "county")
county_area <- unique(county_area[!is.na(county) & nchar(county) == 5L])

message("Downloading ACS 5-yr county population ", min(acs_years), "-", max(acs_years), "...")
acs_county <- rbindlist(lapply(acs_years, function(y) {
  d <- tryCatch(
    tidycensus::get_acs(geography = "county", variables = "B01003_001",
                        year = y, survey = "acs5", output = "wide"),
    error = function(e) { message("  ", y, ": ", conditionMessage(e)); NULL }
  )
  if (is.null(d)) return(NULL)
  data.table(county = d$GEOID, pop = d$B01003_001E, yr = y)
}), fill = TRUE)

county_pd <- merge(county_area, acs_county, by = "county")
county_pd[, population_density := (pop * 1e6 / land_area_sqm) / 1000]
county_pd[, log_population_density := log(population_density)]
county_pd <- county_pd[is.finite(population_density),
                      .(county, yr, population_density, log_population_density)]

# Forward-fill: 2022 -> 2023
fwd <- county_pd[yr == max(acs_years)][, yr := fill_forward_to]
county_pd <- rbind(county_pd, fwd)

# Backward-fill: 2009 -> 2000-2008
base <- county_pd[yr == min(acs_years)]
for (y in fill_backward_min:(min(acs_years) - 1L)) {
  county_pd <- rbind(county_pd, copy(base)[, yr := y])
}

setorder(county_pd, county, yr)
saveRDS(county_pd, county_out_path)
message("Saved: ", county_out_path, "  rows=", nrow(county_pd),
        "  counties=", uniqueN(county_pd$county),
        "  years=", paste(range(county_pd$yr), collapse = "-"))

# ============================================================================
# Zip-year population density
# ============================================================================

message("Downloading ZCTA boundaries (vintage ", zcta_vintage, ")...")
us_zctas <- tigris::zctas(year = zcta_vintage, cb = TRUE, progress_bar = FALSE)
zip_id_col  <- intersect(c("ZCTA5CE20","GEOID20","ZCTA5CE10","GEOID10","ZCTA5CE","GEOID"),
                         names(us_zctas))[1L]
zip_land_col <- intersect(c("ALAND20","ALAND10","ALAND"), names(us_zctas))[1L]
if (is.na(zip_id_col) || is.na(zip_land_col)) stop("Unexpected ZCTA schema.")
zip_area <- data.table(
  zip5 = as.character(us_zctas[[zip_id_col]]),
  land_area_sqm = as.numeric(us_zctas[[zip_land_col]])
)
zip_area <- unique(zip_area[!is.na(zip5) & nchar(zip5) == 5L & land_area_sqm > 0])

message("Downloading ACS 5-yr ZCTA population ", min(acs_years), "-", max(acs_years), "...")
acs_zip <- rbindlist(lapply(acs_years, function(y) {
  d <- tryCatch(
    tidycensus::get_acs(geography = "zcta", variables = "B01003_001",
                        year = y, survey = "acs5", output = "wide"),
    error = function(e) { message("  ", y, ": ", conditionMessage(e)); NULL }
  )
  if (is.null(d)) return(NULL)
  data.table(zip5 = as.character(d$GEOID), pop = d$B01003_001E, yr = y)
}), fill = TRUE)

if (nrow(acs_zip) == 0L) stop("ZCTA ACS pull returned zero rows.", call. = FALSE)

zip_pd <- merge(zip_area, acs_zip, by = "zip5")
zip_pd[, population_density := (pop * 1e6 / land_area_sqm) / 1000]
zip_pd[, log_population_density := log(population_density)]
zip_pd <- zip_pd[is.finite(population_density),
                .(zip5, yr, population_density, log_population_density)]

# Forward/backward fill analogous to county panel.
zip_years_have <- sort(unique(zip_pd$yr))
zip_max <- max(zip_years_have); zip_min <- min(zip_years_have)
if (fill_forward_to > zip_max) {
  fwd <- zip_pd[yr == zip_max]
  for (y in (zip_max + 1L):fill_forward_to) {
    zip_pd <- rbind(zip_pd, copy(fwd)[, yr := y])
  }
}
if (fill_backward_min < zip_min) {
  base <- zip_pd[yr == zip_min]
  for (y in fill_backward_min:(zip_min - 1L)) {
    zip_pd <- rbind(zip_pd, copy(base)[, yr := y])
  }
}

setorder(zip_pd, zip5, yr)
saveRDS(zip_pd, zip_out_path)
message("Saved: ", zip_out_path, "  rows=", nrow(zip_pd),
        "  zips=", uniqueN(zip_pd$zip5),
        "  years=", paste(range(zip_pd$yr), collapse = "-"))

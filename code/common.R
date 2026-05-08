# common.R — shared libraries, paths, and global options
# Project: [PAPER_TITLE]
# --------------------------------------------------------

rm(list = ls())

library(tidyverse)
library(fixest)
library(ggfixest)
library(here)

# --- Paths ---
data_path <- "data/constructed/"

# --- Toggles ---
save_figures <- TRUE
save_tables  <- TRUE

# --- Color palette ---
primary_blue   <- "#012169"
primary_gold   <- "#f2a900"
accent_gray    <- "#525252"
positive_green <- "#15803d"
negative_red   <- "#b91c1c"

# --- ggplot2 theme ---
theme_custom <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", color = "#012169"),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      plot.background  = element_rect(fill = "transparent", color = NA),
      panel.background = element_rect(fill = "transparent", color = NA)
    )
}

# --- fixest global settings ---
# setFixest_fml(
#   ..fe       = ~ unit_id + year,
#   ..controls = ~ control1 + control2
# )
setFixest_etable(
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.1),
  se.below    = TRUE
)

# --- summary stats utility ---
source("https://raw.githubusercontent.com/dratnadiwakara/r-utilities/refs/heads/main/summary_stat_tables.R")

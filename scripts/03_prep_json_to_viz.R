# writes to_viz/nhood_wide
source("_utils/pkgs.R")

if (exists("snakemake")) {
  comb_path <- snakemake@input[["comb"]]
  viz_path <- snakemake@output[["viz"]]
} else {
  comb_path <- file.path("output_data", stringr::str_glue("{acs_year}_acs_health_cws_comb.rds"))
  viz_path <- file.path("to_viz", stringr::str_glue("town_wide_{acs_year}.json"))
}

############ DATA ######################################################
# prof_wide has format
# {
#   "bridgeport": {
#     "age": [
#       {
#         "level": "1_state",
#         "location": "Connecticut"
# ...
prof_wide <- readRDS(comb_path) |>
  mutate(indicator = as_factor(indicator)) |>
  select(-year) |>
  rename(location = name) |>
  split(~topic) |>
  map(distinct, level, location, indicator, .keep_all = TRUE) |>
  map(tidyr::pivot_wider, names_from = indicator) |>
  map(select, -topic, -source)

jsonlite::write_json(prof_wide, viz_path, auto_unbox = TRUE)
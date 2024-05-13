source("_utils/pkgs.R")

if (exists("snakemake")) {
  hdr_path <- snakemake@input[["headings"]]
  comb_path <- snakemake@input[["comb"]]
  out_path <- snakemake@output[["distro"]]
} else {
  hdr_path <- file.path("to_viz", "indicators.json")
  comb_path <- file.path("output_data", stringr::str_glue("{acs_year}_acs_health_cws_comb.rds"))
  out_path <- file.path("to_distro", stringr::str_glue("{acs_year}_town_acs_health_cws_distro.csv"))
}

hdrs <- jsonlite::read_json(hdr_path, simplifyVector = TRUE) |>
  purrr::map_dfr(purrr::pluck, "indicators") |>
  distinct(indicator, display)

############ FLAT FILE, ALL GEOS ########################################
prof <- readRDS(comb_path) |>
  inner_join(hdrs, by = "indicator") |>
  distinct(name, display, year, .keep_all = TRUE)
  
prof_out <- prof |>
  tidyr::pivot_wider(id_cols = c(level, name), names_from = c(display, year), values_from = value)

readr::write_csv(prof_out, out_path)

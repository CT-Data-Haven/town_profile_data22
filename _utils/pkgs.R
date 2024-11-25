library(dplyr, warn.conflicts = FALSE, quietly = TRUE)
library(purrr, warn.conflicts = FALSE, quietly = TRUE)
library(forcats, warn.conflicts = FALSE, quietly = TRUE)

if (exists("snakemake")) {
    acs_year <- snakemake@params[["acs_year"]]
    cdc_year <- snakemake@params[["cdc_year"]]
    cws_year <- snakemake@params[["cws_year"]]
    proj_year <- snakemake@params[["proj_year"]]
} else {
    acs_year <- 2022
    cdc_year <- 2023
    cws_year <- "15_24"
    proj_year <- 2024
}

# given 15_24, return 2015-2024
extract_yrs <- function(x, sep = "-") {
    x <- stringr::str_match_all(x, "(?<=\\D?)(\\d{2})(?=\\D?)")[[1]][,2]
    x <- paste0("20", x)
    x <- paste(x, collapse = sep)
    x
}

library(dplyr, warn.conflicts = FALSE, quietly = TRUE)
library(purrr, warn.conflicts = FALSE, quietly = TRUE)
library(forcats, warn.conflicts = FALSE, quietly = TRUE)

if (exists("snakemake")) {
    acs_year <- snakemake@params[["acs_year"]]
    cdc_year <- snakemake@params[["cdc_year"]]
} else {
    acs_year <- 2022
    cdc_year <- 2023
}
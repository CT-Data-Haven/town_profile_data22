source("_utils/pkgs.R")

# each town has cog for comparison
# filter for town being shown, then pull up definition
geo_meta <- cwi::xwalk |>
  distinct(cog, town) |>
  split(~cog) |>
  map(pull, town) |>
  map(sort)

############ NOTES #####################################################
# geography meta, sources, download URLs
sources <- readr::read_delim(file.path("_utils", "manual", "sources.txt"), delim = ";", show_col_types = FALSE)
urls <- readr::read_csv(file.path("_utils", "manual", "urls.txt"), show_col_types = FALSE) |>
  tibble::deframe() |>
  as.list()

notes <- list(geography = geo_meta, sources = sources, dwurls = urls)
jsonlite::write_json(notes, file.path("to_viz", "notes.json"), auto_unbox = TRUE)

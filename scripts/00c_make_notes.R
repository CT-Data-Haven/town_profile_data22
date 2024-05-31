source("_utils/pkgs.R")

if (exists("snakemake")) {
  paths_in <- snakemake@input
  paths_out <- snakemake@output
} else {
  paths_in <- list(
    sources = file.path("_utils", "manual", "sources.txt"),
    urls = file.path("_utils", "manual", "urls.txt"),
    methods = file.path("_utils", "manual", "methods.txt")
  )
  paths_out <- list(
    notes = file.path("to_viz", "notes.json"),
    xwalk = file.path("to_viz", "town_cog_xwalk.json")
  )
}

# each town has cog for comparison
# filter for town being shown, then pull up definition
town_cog <- cwi::xwalk |>
  distinct(cog_fips, town) |>
  select(town, cog_fips)

cogs <- cwi::xwalk |>
  distinct(cog_fips, cog) |>
  mutate(cog = cwi::fix_cogs(cog))

geo_meta <- list(xwalk = town_cog, cogs = cogs) |>
  map(mutate, cog_fips = substring(cog_fips, 3, 5)) |>
  map(tibble::deframe) |>
  map(as.list)

############ NOTES #####################################################
# geography meta, sources, download URLs
methods <- readr::read_csv(paths_in[["methods"]], show_col_types = FALSE)

sources <- readr::read_delim(paths_in[["sources"]], delim = ";", show_col_types = FALSE) |>
  left_join(methods, by = "id")

urls <- readr::read_csv(paths_in[["urls"]], show_col_types = FALSE) |>
  tibble::deframe() |>
  as.list()

notes <- list(sources = sources, dwurls = urls)
jsonlite::write_json(notes, paths_out[["notes"]], auto_unbox = TRUE)

jsonlite::write_json(geo_meta, paths_out[["xwalk"]], auto_unbox = TRUE)

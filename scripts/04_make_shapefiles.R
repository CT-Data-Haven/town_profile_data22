# writes to_viz/cities
source("_utils/pkgs.R")
library(sf, warn.conflicts = FALSE, quietly = TRUE)
sf::sf_use_s2(FALSE)

if (exists("snakemake")) {
  out_path <- snakemake@output[["topo"]]
} else {
  out_path <- file.path("to_viz", "towns_topo.json")
}

############ SHAPEFILES ################################################
town_sf <- tigris::county_subdivisions(state = "09", cb = TRUE) |>
  select(name = NAME, cog_fips = COUNTYFP) |>
  # rmapshaper::ms_simplify(keep = 0.8) |>
  st_transform(4326) |>
  st_cast("MULTIPOLYGON")

geojsonio::geojson_write(town_sf, object_name = "town", file = out_path)

system(stringr::str_glue(
  "mapshaper {out_path} -clean -filter-slivers -simplify 75% -o force format=topojson {out_path}"
))

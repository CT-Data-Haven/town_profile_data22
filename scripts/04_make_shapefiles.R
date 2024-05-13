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
cwi::town_sf |>
  st_transform(4326) |>
  st_cast("MULTIPOLYGON") |>
  select(-GEOID) |>
  geojsonio::geojson_write(object_name = "town", file = out_path)

system(stringr::str_glue("mapshaper {out_path} -clean -filter-slivers -o force format=topojson {out_path}"))

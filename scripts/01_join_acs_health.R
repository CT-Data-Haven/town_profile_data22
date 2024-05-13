# writes output_data/all_nhood_yr_acs_health_comb.rds
source("_utils/pkgs.R")

if (exists("snakemake")) {
  paths <- snakemake@input
  path_out <- snakemake@output[["comb"]]
} else {
  paths <- list(
    acs = stringr::str_glue("acs_town_basic_profile_{acs_year}.rds"),
    cdc = stringr::str_glue("cdc_health_all_lvls_nhood_{cdc_year}.rds"),
    civic = "cws_1521_civic_by_loc.csv",
    health = "cws_1521_health_race.csv",
    walk = "cws_1521_walkability_race.csv"
  ) |>
    map(\(x) file.path("input_data", x))
  paths[["headings"]] = file.path("to_viz", "indicators.json")
  path_out <- file.path("output_data", stringr::str_glue("{acs_year}_acs_health_cws_comb.rds"))
}

# datasets need indicators as tXother_race, mXasthma to match meta
acs <- readRDS(paths[["acs"]]) |>
  mutate(topic = as_factor(topic)) |>
  mutate(level = fct_relabel(level, stringr::str_remove, "\\d_") |>
    fct_recode(cog = "county")) |>
  select(topic, level, name, year, indicator = group, estimate, share) |>
  tidyr::pivot_longer(estimate:share, names_to = "type", values_drop_na = TRUE) |>
  mutate(type = fct_recode(type, t = "estimate", m = "share")) |>
  mutate(year = as.character(year)) |>
  filter(topic %in% c("age", "race", "foreign_born", "poverty", "income_children", "income_seniors", "tenure", "housing_cost"))

cdc <- readRDS(paths[["cdc"]]) |>
  mutate(type = factor("m")) |>
  mutate(question = question |>
    fct_relabel(snakecase::to_snake_case) |>
    fct_recode(
      checkup = "annual_checkup",
      heart_disease = "coronary_heart_disease",
      asthma = "current_asthma",
      blood_pressure = "high_blood_pressure",
      dental = "dental_visit",
      smoking = "current_smoking",
      sleep = "sleep_7_hours",
      life_exp = "life_expectancy",
      insurance = "health_insurance"
    )) |>
  mutate(level = fct_recode(level, cog = "region")) |>
  rename(indicator = question) |>
  select(topic, level, name, year, indicator, value, type)

cws <- paths[c("civic", "health", "walk")] |>
  map(readr::read_csv, show_col_types = FALSE) |>
  bind_rows(.id = "topic") |>
  filter(age == "Total") |>
  filter(race == "Total") |>
  filter(large_sample) |>
  mutate(level = as_factor(level) |>
    fct_recode(cog = "region")) |>
  mutate(year = "2015-2021") |>
  mutate(type = "m") |>
  select(topic, level, name, year, indicator, value, type)

geos <- acs |>
  filter(level %in% c("state", "cog", "town")) |>
  distinct(level, name)

hdrs <- jsonlite::read_json(paths[["headings"]], simplifyDataFrame = TRUE) |>
  map(pluck, "indicators") |>
  bind_rows(.id = "topic")

# use headings to filter
out <- tibble::lst(acs, cdc, cws) |>
  bind_rows(.id = "source") |>
  semi_join(geos, by = c("name", "level")) |>
  mutate(topic = as_factor(topic) |>
    fct_collapse(
      health_outcomes = c("HLTHOUT", "life_expectancy"),
      housing = c("tenure", "housing_cost")
    ) |>
    fct_recode(
      civic_life = "civic",
      financial_security = "health",
      neighborhood_walkability = "walk",
      disability = "DISABLT",
      prevention = "PREVENT",
      health_risk_behaviors = "RISKBEH",
      immigration = "foreign_born",
      income = "poverty"
    )) |>
  tidyr::unite(col = indicator, type, indicator, sep = "X") |>
  semi_join(hdrs, by = c("topic", "indicator")) |>
  mutate(across(where(is.factor), fct_drop)) |>
  # left_join(meta, by = "indicator") |>
  arrange(topic, level, name)

saveRDS(out, path_out)

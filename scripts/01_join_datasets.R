# writes output_data/all_nhood_yr_acs_health_comb.rds
source("_utils/pkgs.R")

if (exists("snakemake")) {
    paths <- snakemake@input
    path_out <- snakemake@output[["comb"]]
} else {
    paths <- list(
        acs = stringr::str_glue("acs_town_basic_profile_{acs_year}.rds"),
        cdc = stringr::str_glue("cdc_health_all_lvls_nhood_{cdc_year}.rds"),
        # civic = "cws_1521_civic_by_loc.csv",
        # health = "cws_1521_health_race.csv",
        # walk = "cws_1521_walkability_race.csv"
        cws = "mrp_estimates_town_profiles.csv"
    ) |>
        map(\(x) file.path("input_data", x))
    paths[["headings"]] <- file.path("to_viz", "indicators.json")
    paths[["cws_head"]] <- file.path("_utils", "mrp_cws_indicator_headings.txt")
    path_out <- file.path("output_data", stringr::str_glue("{acs_year}_acs_health_cws_comb.rds"))
}


hdrs <- jsonlite::read_json(paths[["headings"]], simplifyDataFrame = TRUE) |>
    map(pluck, "indicators") |>
    bind_rows(.id = "topic")

# need lookup to get unified indicators for codes
cws_hdr <- readr::read_csv(paths[["cws_head"]], show_col_types = FALSE)

# datasets need indicators as tXother_race, mXasthma to match meta
# need to reconcile cog names
acs <- readRDS(paths[["acs"]]) |>
    mutate(topic = as_factor(topic)) |>
    mutate(level = fct_relabel(level, stringr::str_remove, "\\d_") |>
        fct_recode(cog = "county")) |>
    select(topic, level, name, year, indicator = group, estimate, share) |>
    tidyr::pivot_longer(estimate:share, names_to = "type", values_drop_na = TRUE) |>
    mutate(type = fct_recode(type, t = "estimate", m = "share")) |>
    mutate(year = as.character(year)) |>
    filter(topic %in% c(
        "age", "race", "foreign_born", "poverty",
        "income_children", "income_seniors", "tenure", "housing_cost"
    ))

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
    rename(indicator = question) |>
    select(topic, level, name, year, indicator, value, type)

cws <- readr::read_csv(paths[["cws"]], show_col_types = FALSE) |>
    select(code = var, yes_bin, level, name, value = mrp_estimate) |>
    left_join(cws_hdr |> select(topic, code, indicator), by = "code") |>
    mutate(value = ifelse(indicator %in% c("financial_insecurity", "safe_to_walk_at_night"),
        1 - value,
        value
    )) |>
    mutate(value = round(value, digits = 2)) |>
    mutate(
        year = "2015-2021",
        type = "m"
    ) |>
    mutate(level = as_factor(level) |>
        fct_relevel("state", "cog")) |>
    select(topic, level, name, year, indicator, value, type)




# use headings to filter
out <- tibble::lst(acs, cdc, cws) |>
    bind_rows(.id = "source") |>
    mutate(level = ifelse(grepl("COG$", name), "cog", as.character(level)) |>
        as_factor()) |>
    filter(level %in% c("state", "cog", "town")) |>
    mutate(name = cwi::fix_cogs(name)) |>
    # semi_join(geos, by = c("name", "level")) |>
    mutate(topic = as_factor(topic) |>
        fct_collapse(
            health_outcomes = c("HLTHOUT", "life_expectancy"),
            housing = c("tenure", "housing_cost")
        ) |>
        fct_recode(
            # civic_life = "civic",
            # financial_security = "health",
            # neighborhood_walkability = "walk",
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
    arrange(topic, level, name) |>
    distinct(topic, indicator, level, name, .keep_all = TRUE)

saveRDS(out, path_out)

library(tidyverse)

ts_confirmed <- readRDS("data/covid-19_ts_confirmed.rds")
ts_deaths <- readRDS("data/covid-19_ts_deaths.rds")
ts_recovered <- readRDS("data/covid-19_ts_recovered.rds")

# Naive rates, need to account for lag ~ 14d (estimated)
latest_rates <- as_tibble(ts_confirmed) %>%
  filter(ts == max(ts)) %>%
  select(-lat, -lon, -ts) %>%
  left_join(
    as_tibble(ts_deaths) %>%
      filter(ts == max(ts)) %>%
      select(-lat, -lon, -ts),
    by = c("continent", "iso3c", "country_region", "province_state")
  ) %>%
  left_join(
    as_tibble(ts_recovered) %>%
      filter(ts == max(ts)) %>%
      select(-lat, -lon, -ts),
    by = c("continent", "iso3c", "country_region", "province_state")
  ) %>%
  arrange(desc(confirmed), country_region) %>%
  mutate(
    confirmed_pct = 100 * confirmed / sum(confirmed, na.rm = TRUE) #,
  #   death_rate = 100 * ifelse(is.na(deaths), 0, deaths) / confirmed,
  #   recovery_rate = 100 * ifelse(is.na(recovered), 0, recovered) / confirmed
  )

china <- latest_rates %>%
  filter(iso3c == "CHN")

not_china <- latest_rates %>%
  filter(iso3c != "CHN")

capture.output(
  knitr::kable(china,
               format = "markdown", digits = 2,
               caption = paste("Latest rates in China:", max(ts_confirmed$ts))
               ),
  file = "latest_china_rates.md"
)

capture.output(
  knitr::kable(not_china,
               format = "markdown", digits = 2,
               caption = paste("Latest rates outside China:", max(ts_confirmed$ts))
               ),
  file = "latest_not_china_rates.md"
)

#max(ts_confirmed$ts)
#um(china$confirmed_pct)

# regenerate README.md
rmarkdown::render(
  input = "README.Rmd",
  output_format = "md_document",
  output_file = "README.md"
)

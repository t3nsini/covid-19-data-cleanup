library(tidyverse)
library(gh)
library(countrycode)

#-- get the list of daily reports
cases <- gh("GET /repos/:owner/:repo/contents/:path",
            owner = "CSSEGISandData",
            repo = "COVID-19",
            path = "/csse_covid_19_data/csse_covid_19_daily_reports", # path changed
            branch = "master")

cases_df <- cases %>%
  unlist() %>%
  matrix(ncol = 12, byrow = T) %>%
  as_tibble() %>%
  rename(
    name = V1,
    path = V2,
    sha = V3,
    size = V4,
    url = V5,
    html_url = V6,
    git_url = V7,
    download_url = V8,
    type = V9,
    link_self = V10,
    link_git = V11,
    link_html = V12
  ) %>%
  filter(
    str_detect(name, "\\.csv")
  )

#-- attempt two ways of parsing the timestamp
#   because some files have m/d/y h:m, and others y-m-d h:m:s
parse_timestamp <- function(dt) {
  # try using m/d/y h:m first
  ts <- lubridate::mdy_hm(dt)
  if(is.na(ts)) {
    # try using ymd h:m:s
    ts <- lubridate::ymd_hms(dt)
  }
  return(ts)
}

#-- get the data from the CSV files and parse it
get_data <- function(csv) {
  fname <- csv
  ts <- basename(fname) %>%
    str_remove(".csv") %>%
    strptime(format = "%m-%d-%Y") %>%
    strftime()

  # parse columns
  col_spec <- list(
    province_state = col_character(),
    country_region = col_character(),
    update = col_character(),
    confirmed = col_integer(),
    dead = col_integer(),
    recovered = col_integer(),
    lat = col_double(),
    lon = col_double()
  )
  read_csv(fname,
           col_types = col_spec, skip = 1,
           col_names = names(col_spec)) %>%
    mutate(
      update = parse_timestamp(update),
      data_update = ts
    )
}

#-- get all cases in one data frame
cases_raw <- data.frame()

for (fn in cases_df$download_url) {
  d <- get_data(fn)
  cases_raw <- bind_rows(cases_raw, d)
}

# case files from march onwards, have lat long

# get the places with lat, long
places <- cases_raw %>%
  filter(!is.na(lat) & !is.na(lon)) %>%
  select(country_region, province_state, lat, lon) %>%
  mutate(
    lat = round(as.double(lat), 5),
    lon = round(as.double(lon), 5)
  ) %>%
  distinct(country_region, province_state, .keep_all = TRUE)
  # use this because some places have multiple
  # lat, lon: i.e. Croatia, Luxembourg, Romania

# add lat lon, and reorder
cases_raw <- cases_raw %>%
  select(-lat, -lon) %>%
  left_join(
    places,
    by = c("country_region", "province_state")
  ) %>%
  select(
    country_region,
    province_state,
    confirmed,
    dead,
    recovered,
    lat,
    lon,
    update,
    data_update
  ) %>%
  mutate( # add iso3 and continent
    iso3c = countrycode(country_region,
                        origin = "country.name",
                        destination = "iso3c",
                        nomatch = NULL),
    continent = countrycode(country_region,
                            origin = "country.name",
                            destination = "continent",
                            nomatch = NULL)
  ) %>%
  select(
    11, 10, 1:9
  )

# save data
saveRDS(
  cases_raw,
  file = "data/covid-19_cases_raw.rds"
)

write.csv(
  cases_raw,
  file = "data/covid-19_cases_raw.csv",
  row.names = FALSE
)

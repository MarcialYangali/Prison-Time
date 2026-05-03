# 0 Tabular merge and item selection

# Paquetes ----------------------------------------------------------------
library(dplyr)
library(janitor)
library(lubridate)

# Data --------------------------------------------------------------------
# Original RData from INEGI:

load("~/Documents/Data/Prisons/ENPOL RData/BD_ENPOL_2021.RData")

# Detention time variables
enpol_det <- ENPOL2021_2_3 |>
    clean_names() |>
    select(
        id_per,
        est_dis,
        fac_per,
        fpc,
        det_year = p3_5_a,
        det_month = p3_5_m,
        det_day = p3_5_d
    ) |>
    mutate(
        det_year = as.numeric(det_year),
        det_month = as.numeric(det_month),
        det_day = as.numeric(det_day)
    )


# Sentence date variables
enpol_sent <- ENPOL2021_5 |>
    clean_names() |>
    select(
        id_per,
        status = p5_3,
        sent_year  = p5_5_a,
        sent_month = p5_5_m
    ) |>
    mutate(
        sent_year  = as.numeric(sent_year),
        sent_month = as.numeric(sent_month)
    )

# Merge
microdata <- enpol_det |>
    left_join(enpol_sent, by = "id_per")

# Interview possible dates -------------------------------------------
survey_dates <- seq(
    from = as.Date("2021-06-14"),
    to   = as.Date("2021-07-26"),
    by   = "day")

save(microdata, survey_dates, file = "in/data.RData")

rm(list = ls())

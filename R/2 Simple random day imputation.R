# 2 Simple random day imputation

# Paquetes ----------------------------------------------------------------
library(dplyr)
library(janitor)
library(lubridate)

# Data from (See "R/0 Tabular merge and item selection.R")
load("in/data.RData")


set.seed(123) # Same seed for replication purposes

option2 <- microdata |>
    
    # DETENTION ------------------------------------------------------------
mutate(
    det_year = ifelse(det_year %in% c(9998, 9999), NA, det_year),
    det_month = ifelse(det_month %in% c(98, 99), NA, det_month),
    det_day = ifelse(det_day %in% c(98, 99), NA, det_day)
) |>
    rowwise() |>
    mutate(
        # Random interview date within survey fieldwork period,
        # conditional on being after the observed detention information
        survey_date = {
            
            possible_survey_dates <- survey_dates
            
            if (!is.na(det_year)) {
                possible_survey_dates <- possible_survey_dates[
                    year(possible_survey_dates) >= det_year
                ]
            }
            
            if (!is.na(det_year) & !is.na(det_month)) {
                possible_survey_dates <- possible_survey_dates[
                    year(possible_survey_dates) > det_year |
                        (
                            year(possible_survey_dates) == det_year &
                                month(possible_survey_dates) >= det_month
                        )
                ]
            }
            
            if (!is.na(det_year) & !is.na(det_month) & !is.na(det_day)) {
                det_date_observed <- make_date(det_year, det_month, det_day)
                
                possible_survey_dates <- possible_survey_dates[
                    possible_survey_dates > det_date_observed
                ]
            }
            
            if (length(possible_survey_dates) == 0) NA_Date_
            else sample(possible_survey_dates, 1)
        }
    ) |>
    ungroup() |>
    
    

    rowwise() |>
    mutate(
        # Random detention month, conditional on being before survey date
        det_month = if (is.na(det_month) & !is.na(det_year)) {
            
            possible_months <- 1:12
            possible_months <- possible_months[
                make_date(det_year, possible_months, 1) <= survey_date
            ]
            
            if (length(possible_months) == 0) NA_real_
            else sample(possible_months, 1)
            
        } else {
            det_month
        },
        
        det_days_in_month = if (
            is.na(det_year) | is.na(det_month)
        ) {
            NA_real_
        } else {
            days_in_month(make_date(det_year, det_month, 1))
        },
        
        # Random detention day, conditional on being before survey date
        det_day = if (is.na(det_day)) {
            
            if (is.na(det_days_in_month)) {
                NA_real_
            } else {
                possible_days <- 1:det_days_in_month
                possible_dates <- make_date(det_year, det_month, possible_days)
                
                possible_days <- possible_days[
                    possible_dates < survey_date
                ]
                
                if (length(possible_days) == 0) NA_real_
                else sample(possible_days, 1)
            }
            
        } else {
            det_day
        },
        
        det_date = make_date(det_year, det_month, det_day)
    ) |>
    ungroup() |>
    
    # SENTENCE -------------------------------------------------------------
mutate(
    sent_year = ifelse(sent_year %in% c(9998, 9999), NA, sent_year),
    sent_month = ifelse(sent_month %in% c(98, 99), NA, sent_month)
) |>
    rowwise() |>
    mutate(
        # Random sentence month, conditional only on being before survey date
        sent_month = if (is.na(sent_month) & !is.na(sent_year)) {
            
            possible_months <- 1:12
            possible_month_dates <- make_date(sent_year, possible_months, 1)
            
            possible_months <- possible_months[
                possible_month_dates <= survey_date
            ]
            
            if (length(possible_months) == 0) NA_real_
            else sample(possible_months, 1)
            
        } else {
            sent_month
        },
        
        sent_days_in_month = if (
            is.na(sent_year) | is.na(sent_month)
        ) {
            NA_real_
        } else {
            days_in_month(make_date(sent_year, sent_month, 1))
        },
        
        # Random sentence day, conditional only on being before survey date
        sent_day = if (is.na(sent_days_in_month)) {
            
            NA_real_
            
        } else {
            
            possible_days <- 1:sent_days_in_month
            possible_dates <- make_date(sent_year, sent_month, possible_days)
            
            possible_days <- possible_days[
                possible_dates < survey_date
            ]
            
            if (length(possible_days) == 0) NA_real_
            else sample(possible_days, 1)
        },
        
        sent_date = make_date(sent_year, sent_month, sent_day)
    ) |>
    ungroup() |>
    
    # FINAL VARIABLES ------------------------------------------------------
mutate(
    # Total time in prison
    det_days = as.numeric(survey_date - det_date),
    det_years = det_days / 365,
    
    # Time in prison without sentence
    sent_days = as.numeric(sent_date - det_date),
    sent_years = sent_days / 365,
    
    # Completed years
    det_years_floor = ifelse(!is.na(det_years), floor(det_years), NA),
    sent_years_floor = ifelse(!is.na(sent_years), floor(sent_years), NA)
)



# rm(option2)





# Revisión rápida cálculo 2
summary(option2$det_years)
summary(option2$sent_years)
table(is.na(option2$anos_det))
874/(874+60575)*100 # 1.4% NAs
table(is.na(option2$anos_sent))
23968/(23968+37481)*100 # 39% NAs


names(option2)
table(option2$fecha_det)
class(option2$fecha_det)

option2 |> 
    select(id_per, fac_per, yearsdet = det_years, yearsdet_floor = det_years_floor, detdate = det_date, survdate = survey_date) |> 
    saveRDS(file = "/Users/marcialyangali/Documents/Investigación/Heat-Stress-Behind-Bars/in/microdata/option2.RDS")

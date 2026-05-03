# Approach 1: Measure and remove NA

# Packages
library(dplyr)
library(janitor)
library(lubridate)

# Data from (See "R/0 Tabular merge and item selection.R")
load("in/data.RData")



# Revisión de no especificados en detención
na_detention <- tibble(
    interval = "Detention",
    date = c("year", "month", "day"),
    na = c(
        sum(microdata$det_year  %in% c(9998, 9999), na.rm = TRUE),
        sum(microdata$det_month %in% c(98, 99), na.rm = TRUE),
        sum(microdata$det_day   %in% c(98, 99), na.rm = TRUE)),
    percentage = round(100 * na / nrow(microdata), 2))
na_detention

# Revisión de no especificados en sentencia
# En ENPOL 2021 aquí solo hay año y mes de sentencia.
# Para construir fecha, el día se fija en 15 únicamente cuando año y mes están especificados.
na_sentence <- tibble(
    interval = "Sentence",
    date = c("year", "month"),
    na = c(
        sum(microdata$sent_year %in% c(9998, 9999), na.rm = TRUE),
        sum(microdata$sent_month %in% c(98, 99), na.rm = TRUE)),
    percentage = round(100 * na / nrow(microdata), 2))

na_sentence

rbind(na_detention, na_sentence) |> 
    ggplot()+
    aes(x = percentage, y = date)+
    geom_col(fill = "black")+
    geom_text(aes(x = percentage +1, label = na),
              size = 3) +
    facet_wrap(~interval, ncol = 2)+
    scale_x_continuous(
        # limits = c(0, 100),
        breaks = seq(0,100,5),
        labels = paste0(seq(0,100,5), "%")
    )+
    theme_bw()+
    labs(y = NULL,
         x = NULL)


# Cálculo 1
option1 <- microdata |>
    mutate(
        # Indicadores de no especificación: detención
        det_year_unspec  = det_year  %in% c(9998, 9999),
        det_month_unspec = det_month %in% c(98, 99),
        det_day_unspec   = det_day   %in% c(98, 99),
        
        # Indicadores de no especificación: sentencia
        sent_year_unspec  = sent_year  %in% c(9998, 9999),
        sent_month_unspec = sent_month %in% c(98, 99)
    ) |>
    mutate(
        # Fecha de detención: solo si todo está especificado
        fecha_det = ifelse(
            !det_year_unspec & !det_month_unspec & !det_day_unspec,
            as.character(make_date(det_year, det_month, det_day)),
            NA_character_
        ),
        fecha_det = as.Date(fecha_det),
        
        # Fecha de sentencia:
        # como no hay día, se fija en 15 únicamente cuando año y mes están especificados
        fecha_sent = ifelse(
            !sent_year_unspec & !sent_month_unspec,
            as.character(make_date(sent_year, sent_month, 15)),
            NA_character_
        ),
        fecha_sent = as.Date(fecha_sent),
        
        # Fecha de entrevista fija en el punto medio del levantamiento
        fecha_encuesta = as.Date("2021-07-05")
    ) |>
    mutate(
        # Tiempo total en prisión
        dias_det = as.numeric(fecha_encuesta - fecha_det),
        anos_det = dias_det / 365,
        
        # Tiempo en prisión sin sentencia
        dias_sent = as.numeric(fecha_sent - fecha_det),
        anos_sent = dias_sent / 365
    ) |>
    # Se usa otra pregunta para ver si la persona ha recibido o no sentencia al momento de la entrevista. Si no, el tiemop sin sentencia es igual al total del tiempo en prisión.
    mutate(anos_sent = case_when(
        status == 1 ~ anos_det,
        status %in% c(2, 3) ~ anos_sent)) |>
    
    mutate(
        # Protección ante negativos
        anos_det = ifelse(!is.na(anos_det)  & anos_det  < 0, 0, anos_det),
        anos_sent = ifelse(!is.na(anos_sent) & anos_sent < 0, 0, anos_sent),
        
        # Años completos
        anos_det_floor  = ifelse(!is.na(anos_det), 
                                 floor(anos_det),  NA),
        anos_sent_floor = ifelse(!is.na(anos_sent), floor(anos_sent), NA))



# Plots
library(ggplot2)
library(tidyr)
names(option1)

density_plot <- option1 |>
    select(id_per, anos_det, anos_sent) |>
    pivot_longer(cols = c("anos_det", "anos_sent"),
                 names_to = "interval",
                 values_to = "time") |> 
    ggplot()+
    geom_density(aes(x = time, y = ..count.., fill = interval,
                     color = interval), 
                 # color = NA,
                 alpha = .6)+
    scale_fill_manual(values = c(
        "darkred", "darkgreen"))+
    scale_color_manual(values = c(
        "darkred", "darkgreen"))+
    scale_x_continuous(
        breaks = seq(0,50,5)
    )+
    theme_bw()+
    labs(x = "Years in prison", 
         y = "Population")+
    theme(legend.position = "none")

na <- rbind(
option1 |> 
    summarise(mean = mean(anos_sent, na.rm = T),
              valid = (1-mean(is.na(anos_sent) == T))*100,
              na = mean(is.na(anos_sent) == T)*100) |> 
    mutate(interval = "Time without sentence"),
option1 |> 
    summarise(mean = mean(anos_det, na.rm = T),
              valid = (1-mean(is.na(anos_det) == T))*100,
              na = mean(is.na(anos_det) == T)*100) |> 
    mutate(interval = "Time in prison")
) |> 
    pivot_longer(cols = valid:na,
                 names_to = "valid",
                 values_to = "percentage")
    
    


bar_plot <- na |> 
    mutate(inter_valid = paste(interval, valid)) |> 
    ggplot()+
    geom_col(aes(y = percentage, x = interval, 
                 fill = inter_valid,
                 color = inter_valid), 
             alpha = .8)+
    scale_fill_manual(values = c(
        "gray","darkred", "gray", "darkgreen"))+
    scale_color_manual(values = c(
        "gray","darkred", "gray", "darkgreen"))+
    scale_y_continuous(
        breaks = seq(0,100,25),
        labels = paste0(seq(0,100,25), "%")
    )+
    labs(y = "Valid Responses", x = NULL)+
    theme_bw()+
    theme(legend.position = "none")

library(patchwork)
bar_plot+density_plot+plot_layout(widths = c(.6,1))

ggsave("out/1.Valid responses and distribution.jpg",
       scale = 1, height = 4, width = 9, dpi = 300)

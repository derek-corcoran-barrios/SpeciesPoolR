## code to prepare `Richness_PD` dataset goes here

Richness_PD <- as.data.frame(data.table::fread("data-raw/Richness_PD.csv"))

usethis::use_data(Richness_PD, overwrite = TRUE)

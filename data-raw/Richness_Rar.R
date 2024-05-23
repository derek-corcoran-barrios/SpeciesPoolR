## code to prepare `Richness_Rar` dataset goes here

Richness_Rar <- as.data.frame(data.table::fread("data-raw/Richness_Rar.csv"))

usethis::use_data(Richness_Rar, overwrite = TRUE)

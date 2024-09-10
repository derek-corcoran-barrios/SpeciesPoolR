#' Export Final Species Presences to CSV Files
#'
#' This function exports the final filtered species presences to CSV files. The data is grouped by land-use type, and each species is saved in a separate CSV file within a folder corresponding to its land-use type.
#'
#' @param DF A data frame containing the final species presences with columns including `species` and `Landuse`.
#' @param folder A string specifying the directory where the CSV files should be saved. The function will create subfolders for each land-use type within this directory.
#'
#' @importFrom data.table %chin%
#' @importFrom readr write_csv
#' @importFrom janitor make_clean_names
#'
#' @export
export_final_presences <- function(DF, folder) {
  Landuse <- NULL
  Landuses <- unique(DF$Landuse)
  if(!dir.exists(folder)) {
    dir.create(folder)
  }
  for(i in seq_along(Landuses)) {
    landuse_dir <- paste0(folder, "/", Landuses[i])

    if(!dir.exists(landuse_dir)) {
      dir.create(landuse_dir)
    }

    Temp <- DF[Landuse %chin% Landuses[i]]
    readr::write_csv(Temp,
                     paste0(landuse_dir, "/", janitor::make_clean_names(unique(Temp$species)), ".csv"),
                     append = TRUE)
  }
}

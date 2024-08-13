#' Get Landuse Presences
#'
#' This function reads and combines species presence data from multiple files within a specified folder for a given land use type.
#'
#' @param folder A character string specifying the path to the folder containing the land use data files.
#' @param Landuse A character string specifying the land use type for which the presence data is to be read. The function assumes that the files are located in subdirectories named after the land use type within the specified folder.
#' @return A data frame containing combined species presence data with columns `cell`, `species`, and `Landuse`.
#' @examples
#' \dontrun{
#'   # Example usage:
#'   folder <- system.file("ex/", package="SpeciesPoolR")
#'   Landuse <- "ForestDryPoor"
#'   presences <- GetLandusePresences(folder, Landuse)
#'   head(presences)
#' }
#' @import data.table
#' @importFrom purrr map keep
#' @export
GetLandusePresences <- function(folder, Landuse){
  DT <- list.files(path = paste0(folder, Landuse, "/"), full.names = TRUE) |>
    purrr::map(function(file) {
      tryCatch({
        fread_result <- data.table::fread(file, header = FALSE, colClasses = c("integer", "character", "character"))
        if (ncol(fread_result) == 3) {
          fread_result[, V1 := as.integer(V1)]  # Convert first column to integer
          return(fread_result)
        } else {
          warning(paste("Skipping file", file, "because it has fewer than three columns"))
          return(NULL)
        }
      }, error = function(e) {
        warning(paste("Skipping file", file, "due to error:", conditionMessage(e)))
        return(NULL)
      })
    }) |>
    purrr::keep(~ !is.null(.)) |>
    data.table::rbindlist()

  colnames(DT) <- c("cell", "species", "Landuse")
  DT <- as.data.frame(DT)
  return(DT)
}


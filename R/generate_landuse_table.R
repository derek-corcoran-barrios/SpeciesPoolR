#' Generate a Land-Use Suitability Table
#'
#' This function takes the path to a raster file containing land-use suitability values and converts it to a data frame. It filters the data to include only the cells that have a value of 1 in at least one of the land-use categories, indicating suitability.
#'
#' @param path A string representing the file path to the raster file containing land-use suitability data.
#'
#' @return A data frame with the raster cells that have a suitability value of 1 in at least one of the land-use categories. The data frame includes the `cell` identifier and the corresponding suitability values for each land-use category.
#'
#' @importFrom terra rast as.data.frame
#' @importFrom dplyr filter across
#'
#' @examples
#' # Get path for habitat suitability raster
#' HabSut <- system.file("ex/HabSut.tif", package = "SpeciesPoolR")
#'
#' # Use the function to get the data frame
#' generate_landuse_table(path = HabSut)
#'
#' @export
generate_landuse_table <- function(path) {
  DF <- terra::rast(path) |>
    terra::as.data.frame(cells = TRUE) |>
    dplyr::filter(rowSums(dplyr::across(-cell, ~. == 1)) > 0)
  return(DF)
}

#' Generate and Transform a Land-Use Suitability Table
#'
#' This function takes the path to a raster file containing land-use suitability values, converts it to a data frame, and filters it to include only the cells that have a value of 1 in at least one of the land-use categories. It then transforms the filtered data into a long-format table where each row corresponds to a specific cell and habitat type.
#'
#' @param path A string representing the file path to the raster file containing land-use suitability data.
#'
#' @return A data frame in long format with the raster cells that have a suitability value of 1 in at least one of the land-use categories. The data frame includes the `cell` identifier and the corresponding habitat types (`Habitat`) where suitability is 1.
#'
#' @importFrom terra rast as.data.frame
#' @importFrom dplyr filter across
#' @importFrom data.table as.data.table melt
#'
#' @examples
#' # Get path for habitat suitability raster
#' HabSut <- system.file("ex/HabSut.tif", package = "SpeciesPoolR")
#'
#' # Use the function to generate and transform the land-use suitability table
#' generate_long_landuse_table(path = HabSut)
#'
#' @export
generate_long_landuse_table <- function(path) {
  # Convert raster to data frame and filter for cells with at least one suitability value of 1
  DF <- terra::rast(path) |>
    terra::as.data.frame(cells = TRUE) |>
    dplyr::filter(rowSums(dplyr::across(-cell, ~. == 1)) > 0)

  # Convert to data.table and reshape to long format
  DF <- as.data.table(DF) |>
    melt(id.vars = "cell",
         measure.vars = c("ForestDryPoor", "ForestDryRich", "ForestWetPoor", "ForestWetRich", "OpenDryPoor", "OpenDryRich", "OpenWetPoor", "OpenWetRich"),
         variable.name = "Habitat",
         value.name = "Suitability", na.rm = TRUE)

  # Filter out rows where Suitability is 0 or less
  DF <- DF[Suitability > 0]

  # Remove the Suitability column and convert back to a data frame
  DF <- DF[, Suitability := NULL]
  DF <- as.data.frame(DF)

  return(DF)
}

#' Export Species Richness to Cloud-Optimized GeoTIFF
#'
#' This function takes a data.table of species richness results and a path to a raster template.
#' It generates a `SpatRaster` object using the `terra` package, populates it with the species richness values,
#' and writes the result out as a Cloud-Optimized GeoTIFF.
#'
#' @param Results A data.table containing species richness results. This data.table must contain at least the columns
#'        `cell` and `SR`, where `cell` refers to the cell index in the raster and `SR` refers to the species richness value.
#' @param path A character string specifying the file path to a raster template. This raster is used as a template for the output raster.
#' @param folder A folder where to store the Cloud-Optimized GeoTIFF.

#' @examples
#' \dontrun{
#'   # Example usage:
#'   data(Richness_PD)
#'   template_path <- system.file("ex/LU.tif", package="SpeciesPoolR")
#'   output_folder <- "Results/Richness"
#'   output_path <- export_richness(Richness_PD, template_path, output_folder)
#' }
#' @importFrom terra rast ncell values<-
#' @import data.table
#' @export

export_richness <- function(Results, path, folder) {

  cell <- NULL

  if (!dir.exists(folder)) {
    dir.create(folder, recursive = TRUE)
  }

  Temp <- as.numeric(terra::rast(path))
  Temp[!is.na(Temp)] <- 0
  Richness <- Temp
  Results <- Results[cell > 0 & !is.na(cell) & cell <= ncell(Temp)]
  message(paste("the number of rows in Results is", nrow(Results)))
  message(paste("the Range in cells is", nrow(Results)))
  terra::values(Richness)[as.numeric(Results$cell),] <- Results$SR
  names(Richness) <- paste("Richness", unique(Results$Landuse), sep = "_")
  output_path <- paste0(folder, "/Richness_", unique(Results$Landuse), ".tif")
  write_cog(Richness, output_path)
}

#' Export Phylogenetic Diversity to Cloud-Optimized GeoTIFF
#'
#' This function takes a data.table of Phylogenetic Diversity results and a path to a raster template.
#' It generates a `SpatRaster` object using the `terra` package, populates it with the Phylogenetic Diversity values,
#' and writes the result out as a Cloud-Optimized GeoTIFF.
#'
#' @param Results A data.table containing Phylogenetic Diversity results. This data.table must contain at least the columns
#'        `cell` and `PD`, where `cell` refers to the cell index in the raster and `PD` refers to the Phylogenetic Diversity value.
#' @param path A character string specifying the file path to a raster template. This raster is used as a template for the output raster.
#' @importFrom terra rast ncell values<-
#' @import data.table
#' @export

export_pd <- function(Results, path){

  cell <- NULL

  if (!dir.exists("Results/PD/")) {
    dir.create("Results/PD/", recursive = TRUE)
  }
  Temp <- as.numeric(terra::rast(path))
  Temp[!is.na(Temp)] <- 0
  PD <- Temp
  Results <- Results[cell > 0 & !is.na(cell) & cell <= ncell(Temp)]
  terra::values(PD)[as.numeric(Results$cell),] <- Results$PD
  names(PD) <- paste("PD", unique(Results$Landuse), sep = "_")
  output_path <- paste0("Results/PD/PD_",unique(Results$Landuse), ".tif")
  write_cog(PD, output_path)
  paste0(output_path)
}

#' Export Rarity to Cloud-Optimized GeoTIFF
#'
#' This function takes a data.table of rarity results and a path to a raster template.
#' It generates a `SpatRaster` object using the `terra` package, populates it with the rarity values,
#' and writes the result out as a Cloud-Optimized GeoTIFF.
#'
#' @param Results A data.table containing rarity results. This data.table must contain at least the columns
#'        `cell` and `Irr`, where `cell` refers to the cell index in the raster and `Irr` refers to the rarity value.
#' @param path A character string specifying the file path to a raster template. This raster is used as a template for the output raster.
#'
#' @return A character string indicating the file path of the output Cloud-Optimized GeoTIFF.
#'
#' @importFrom terra rast values<-
#' @export

export_rarity <- function(Results, path){

  if (!dir.exists("Results/Rarity/")) {
    dir.create("Results/Rarity/", recursive = TRUE)
  }

  Temp <- as.numeric(terra::rast(path))
  Temp[!is.na(Temp)] <- 0
  Rarity <- Temp
  names(Rarity) <- paste("Rarity", unique(Results$Landuse), sep = "_")
  terra::values(Rarity)[as.numeric(Results$cell)] <- Results$Irr
  write_cog(Rarity, paste0("Results/Rarity/Rarity_",unique(Results$Landuse), ".tif"))
  paste0("Results/Rarity/Rarity_",unique(Results$Landuse), ".tif")
}

#' Write Cloud-Optimized GeoTIFF (COG)
#'
#' Writes a `SpatRaster` as a Cloud-Optimized GeoTIFF. Unchanged from the
#' pre-`geotargets` version -- purely I/O, nothing here depended on the
#' old data.table workflow.
#'
#' @param SpatRaster A `SpatRaster` to write out.
#' @param Name Output file path, including the `.tif` extension.
#'
#' @return Invisibly, the file path (from `terra::writeRaster()`).
#'
#' @importFrom terra writeRaster
#'
#' @export
write_cog <- function(SpatRaster, Name) {
  terra::writeRaster(
    x = SpatRaster,
    filename = Name, overwrite = TRUE,
    gdal = c("COMPRESS=DEFLATE", "TFW=YES", "of=COG")
  )
}

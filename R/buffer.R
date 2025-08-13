#' Generate a Rasterized Buffer Around Species Occurrences and Convert to Long Format
#'
#' This function takes species occurrence data, generates a buffer around each occurrence point, rasterizes the buffer onto a given raster template, and converts the resulting raster data into a long-format data.table. The buffer distance can be specified by the user.
#'
#' @param DT A data.table or data.frame containing species occurrence data. The data should include the columns: `decimalLatitude`, `decimalLongitude`, `family`, `genus`, and `species`.
#' @param file A file path to the raster file that will be used as a template for rasterizing the buffers.
#' @param dist A numeric value specifying the buffer distance in meters. Default is 500 meters.
#'
#' @return A data.table in long format with two columns: `cell`, indicating the raster cell number, and `species`, indicating the species name corresponding to the cell.
#'
#' @importFrom terra rast vect project buffer crs
#' @importFrom dplyr select mutate group_split
#' @importFrom purrr map
#' @importFrom stringr str_replace_all
#' @importFrom data.table as.data.table
#'
#' @examples
#' \dontrun{
#' # Assuming DT contains species occurrence data and 'raster_file.tif' is the raster template
#' buffer_df <- make_buffer_rasterized(DT, file = "raster_file.tif", dist = 500)
#' }
#'
#' @export
make_buffer_rasterized <- function(DT, file, dist = 500) {
  cell <- . <- genus <- family <- decimalLongitude <- decimalLatitude <- NULL
  if (nrow(DT) == 0) {
    DT <- data.frame(matrix(ncol = 2, nrow = 0))
    colnames(DT) <- c("cell", "species")
    as.data.table(DT)
  } else {
    Rast <- terra::rast(file)
    Result <- DT |>
      dplyr::select(decimalLatitude, decimalLongitude, family, genus, species) |>
      dplyr::mutate(presence = 1)

    Temp <- Result |>
      dplyr::group_split(species) |>
      purrr::map(~terra::vect(.x, geom = c("decimalLongitude", "decimalLatitude"), crs = "+proj=longlat +datum=WGS84")) |>
      purrr::map(~terra::project(.x, terra::crs(Rast))) |>
      purrr::map(~terra::buffer(.x, dist)) |>
      purrr::reduce(rbind)
  }
  return(Temp)
}

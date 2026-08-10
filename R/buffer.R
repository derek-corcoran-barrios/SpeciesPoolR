#' Build buffered occurrence geometries around species records
#'
#' Takes species occurrence data and buffers each occurrence point by a fixed
#' distance, then dissolves overlapping buffers within each species into
#' spatially distinct patches. Returns a single `SpatVector` (one feature per
#' disjoint patch per species), still in geographic (lon/lat) coordinates.
#'
#' Buffering is done directly on lon/lat data because `terra::buffer()`
#' computes distances in meters correctly for a longitude/latitude CRS, and
#' terra's own documentation notes that pre-projecting to a planar CRS makes
#' the result *less* precise, not more. GBIF occurrence data (`decimalLatitude`/
#' `decimalLongitude`) is always WGS84, so no raster/CRS input is needed here.
#'
#' Rasterization is intentionally not done here either: keeping the result as
#' vector geometry means you can reproject and rasterize it onto any raster
#' template later (e.g. if the land-use raster resolution, extent, or CRS
#' changes) without repeating the buffering step.
#'
#' @param DT A data.frame/data.table with columns `decimalLongitude`,
#'   `decimalLatitude`, `family`, `genus`, and `species` (as produced by
#'   [get_presences()]).
#' @param dist A numeric value specifying the buffer distance in meters.
#'   Default is 500 meters.
#'
#' @return A `SpatVector` (CRS EPSG:4326), one feature per spatially distinct
#'   (non-overlapping) buffer patch per species, with attributes `family`,
#'   `genus`, `species`, and `n_records` (the number of occurrence records
#'   whose buffers were merged into that patch). If `DT` has zero rows, an
#'   empty `SpatVector` with the same CRS and `family`/`genus`/`species`
#'   fields is returned.
#'
#' @importFrom terra vect buffer aggregate disagg
#' @importFrom dplyr select
#'
#' @examples
#' \dontrun{
#' # Assuming Presences contains species occurrence data
#' buffer_vect <- make_buffer_rasterized(Presences, dist = 500)
#' }
#'
#' @export
make_buffer <- function(DT, dist = 500) {
  decimalLongitude <- decimalLatitude <- family <- genus <- species <- NULL

  if (nrow(DT) == 0) {
    empty <- data.frame(
      decimalLongitude = numeric(0),
      decimalLatitude  = numeric(0),
      family  = character(0),
      genus   = character(0),
      species = character(0)
    )
    return(terra::vect(empty,
                       geom = c("decimalLongitude", "decimalLatitude"),
                       crs  = "EPSG:4326"))
  }

  buffered <- DT |>
    dplyr::select(decimalLongitude, decimalLatitude, family, genus, species) |>
    terra::vect(geom = c("decimalLongitude", "decimalLatitude"), crs = "EPSG:4326") |>
    terra::buffer(width = dist)

  dissolved <- terra::aggregate(buffered,
                                by = c("family", "genus", "species"),
                                dissolve = TRUE,
                                count = TRUE)
  dissolved <- terra::disagg(dissolved)
  names(dissolved)[names(dissolved) == "agg_n"] <- "n_records"

  dissolved
}

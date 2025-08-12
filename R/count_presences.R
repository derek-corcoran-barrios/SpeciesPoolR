#' Build a CCW WKT polygon from a shapefile (lon/lat)
#'
#' Creates a minimum bounding rectangle (MBR) around the provided shapefile and
#' returns it as a WKT POLYGON in counter‑clockwise order. If the shapefile is
#' not in lon/lat, it is projected to EPSG:4326.
#'
#' @param shapefile Path to a vector file readable by \code{terra::vect()}.
#' @return A single-length character vector with WKT POLYGON, suitable for GBIF's `geometry` param.
#' @examples
#' f <- system.file("ex/Aarhus.shp", package = "SpeciesPoolR")
#' wkt <- wkt_rect_ccw(f)
#' cat(substr(wkt, 1, 60), "...\n")
#'
#' @importFrom terra vect is.lonlat project ext xmin xmax ymin ymax crs
#' @export
wkt_rect_ccw <- function(shapefile) {
  stopifnot(!is.null(shapefile), file.exists(shapefile))
  v <- terra::vect(shapefile)

  # Reproject to lon/lat if necessary
  if (!terra::is.lonlat(v)) {
    v <- terra::project(v, "EPSG:4326")
  }

  e <- terra::ext(v)
  xmn <- terra::xmin(e); xmx <- terra::xmax(e)
  ymn <- terra::ymin(e); ymx <- terra::ymax(e)

  # Counter‑clockwise ring: (xmin ymin, xmax ymin, xmax ymax, xmin ymax, xmin ymin)
  coords <- sprintf(
    "%f %f, %f %f, %f %f, %f %f, %f %f",
    xmn, ymn,  xmx, ymn,  xmx, ymx,  xmn, ymx,  xmn, ymn
  )
  paste0("POLYGON ((", coords, "))")
}

#' Count Presences of Species within a Specified Area
#'
#' Counts the number of GBIF occurrences (1999–2023) for each species in `species`
#' within a country or within the minimum bounding rectangle of a shapefile.
#'
#' @param species A data.frame/tibble with columns `family`, `genus`, `species`.
#' @param shapefile Path to a shapefile (lon/lat coordinates preferred). If provided (and
#'   `country` is NULL), a minimum bounding rectangle is used as the query geometry.
#' @param country Two-letter country code (e.g., "DK"). Ignored if `shapefile` is provided.
#'
#' @return A `data.table` with columns `family`, `genus`, `species`, `N`.
#'
#' @details
#' If both `shapefile` and `country` are provided, an error is thrown. If neither is provided,
#' GBIF query is global.
#'
#' @importFrom data.table data.table rbindlist
#' @importFrom rgbif occ_count
#' @examples
#' # Example species data.frame
#' species <- structure(
#'   list(family = "Polytrichaceae", genus = "Atrichum", species = "Atrichum undulatum"),
#'   row.names = c(NA, -1L), class = c("tbl_df","tbl","data.frame")
#' )
#'
#' # Using a country code
#' # df_country <- count_presences(species, country = "DK")
#'
#' # Using a shapefile (example from the package)
#' # f <- system.file("ex/Aarhus.shp", package="SpeciesPoolR")
#' # df_shapefile <- count_presences(species, shapefile = f)
#'
#' @export
count_presences <- function(species, shapefile = NULL, country = NULL) {
  # sanity checks
  if (!is.null(shapefile) && !is.null(country)) {
    stop("Provide either 'shapefile' OR 'country', not both.")
  }
  if (!all(c("family","genus","species") %in% colnames(species))) {
    stop("`species` must have columns: family, genus, species")
  }

  # Build geometry WKT if shapefile is given
  geometry <- NULL
  if (!is.null(shapefile) && is.null(country)) {
    geometry <- wkt_rect_ccw(shapefile)
    message("Geometry created: ", geometry)
  }

  # row-wise query to GBIF
  results_list <- apply(species, 1, function(row) {
    sci <- as.character(row[["species"]])
    data.table::data.table(
      family  = as.character(row[["family"]]),
      genus   = as.character(row[["genus"]]),
      species = sci,
      N = rgbif::occ_count(
        scientificName      = sci,
        hasCoordinate       = TRUE,
        hasGeospatialIssue  = FALSE,
        year                = "1999,2023",
        country             = country,
        geometry            = geometry
      )
    )
  })

  data.table::rbindlist(results_list)
}

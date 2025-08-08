#' Count Presences of Species within a Specified Area
#'
#' This function counts the number of occurrences of specified species within a defined area.
#' The area can be specified using a shapefile or a two-letter country code. The function
#' uses the `rgbif` package to query species occurrences and returns a data.frame with the
#' results.
#'
#' @param species A data.frame containing the columns `family`, `genus`, and `species`.
#'   These should be the taxonomic details of the species for which you want to count occurrences.
#' @param shapefile A shapefile (with lat/long coordinates) defining the area of interest.
#'   The function will create a minimum bounding rectangle around the shapefile to query the
#'   species occurrences. Default is `NULL`.
#' @param country A two-letter country code (e.g., "DK" for Denmark) to define the area of interest.
#'   Default is `NULL`.
#'
#' @return A data.frame with columns `family`, `genus`, `species`, and `N` where `N`
#'   represents the number of occurrences of each species within the defined area.
#'
#' @importFrom terra vect hull geom
#' @importFrom data.table data.table rbindlist
#' @importFrom rgbif occ_count
#'
#' @examples
#' # Example species data.frame
#' species <- structure(list(family = "Polytrichaceae", genus = "Atrichum",
#'                           species = "Atrichum undulatum"), row.names = c(NA, -1L),
#'                      class = c("tbl_df", "tbl", "data.frame"))
#'
#' # Example 1: Using a country code
#' df_country <- count_presences(species, country = "DK")
#' print(df_country)
#'
#' # Example 2: Using a shapefile
#' # Assuming "Aarhus.shp" is in the working directory
#' f <- system.file("ex/Aarhus.shp", package="SpeciesPoolR")
#' df_shapefile <- count_presences(species, shapefile = f)
#' print(df_shapefile)
#'
#' @export

count_presences <- function(species, shapefile = NULL, country = NULL){
  # Calculate geometry if a shapefile is provided
  geometry <- if (!is.null(shapefile) & is.null(country)) {
    terra::vect(shapefile) |>
      terra::hull(type = "rectangle") |>
      terra::geom(wkt = TRUE)
  } else {
    NULL
  }

  # Apply the function row-wise over the species data.frame
  results_list <- apply(species, 1, function(row) {
    # Create a data.table for the current species row
    data.table::data.table(
      family = row['family'],
      genus = row['genus'],
      species = row['species'],
      N = rgbif::occ_count(
        scientificName = row['species'],
        hasCoordinate = TRUE,
        country = country,
        hasGeospatialIssue = FALSE,
        year = '1999,2023',
        geometry = geometry
      )
    )
  })

  # Combine all results into a single data.table
  final_result <- data.table::rbindlist(results_list)

  return(final_result)
}

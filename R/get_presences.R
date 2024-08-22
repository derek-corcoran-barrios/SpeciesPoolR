#' Get occurrence data
#'
#' This function uses the \code{rgbif} package to get occurrence data from the Global Biodiversity Information Facility (GBIF) API.
#'
#' @param Species A vector containing the species to query.
#' @param WriteFile Logical. If \code{TRUE}, the occurrence data will be written to the \code{Occs} folder. If \code{FALSE}, the occurrence data will be returned in a list.
#' @param continent what contintent are the occurrences downloaded from
#' @param shapefile A shapefile (with lat/long coordinates) defining the area of interest.
#'   The function will create a minimum bounding rectangle around the shapefile to query the
#'   species occurrences. Default is `NULL`.
#' @param country A two-letter country code (e.g., "DK" for Denmark) to define the area of interest.
#' @param limit maximum number of occurrences downloaded
#' @param Log Logical. If \code{TRUE}, a log file will be created with information on the progress of the function.
#' @param ... Additional arguments to be passed to the \code{occ_data} function.
#'
#' @return If \code{WriteFile = TRUE}, this function does not return anything. If \code{WriteFile = FALSE}, a list containing the occurrence data for each species is returned.
#'
#' @export
#'
#' @importFrom rgbif occ_data
#' @importFrom janitor make_clean_names
#' @importFrom utils write.table
#' @examples
#' # Get occurrence data for species in FinalSpeciesList
#' \donttest{
#' Presences <- GetOccs(Species = c("Abies concolor", "Canis lupus"), WriteFile = FALSE)
#' }

GetOccs <- function(Species, WriteFile = T, continent = NULL, country = NULL, shapefile = NULL, limit = 10000, Log = T, ...){

  if (!is.character(Species)) {
    stop("Species argument must be a character vector")
  }
  if (!is.logical(WriteFile)) {
    stop("WriteFile argument must be a logical value")
  }
  if (!is.null(continent) && !is.character(continent)) {
    stop("Continent argument must be a character string")
  }
  if (!is.null(country) && !is.character(country)) {
    stop("country argument must be a character string")
  }
  if (!is.numeric(limit)) {
    stop("Limit argument must be a numeric value")
  }

  if(WriteFile == T){
    dir.create("Occs", showWarnings = FALSE)
  } else if(WriteFile == F){
    Presences <- list()
  }

  if(Log == T){
    log_file <- paste0("Occs_Log_", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".csv")
    write.table(data.frame(Species = character(), Start_time = character(), End_time = character(), Error = character(), Num_presences = numeric()), file = log_file, row.names = FALSE, sep = ",")
  }

  for(i in 1:length(Species)){
    message(paste("Starting species", i))

    # Check if RDS file already exists
    rds_file <- paste0("Occs/",janitor::make_clean_names(unique(Species[i])),".rds")
    if (file.exists(rds_file)) {
      message(paste("Skipping", Species[i], "- RDS file already exists"))
      if(Log == T){
        log_entry <- data.frame(Species = Species[i], Start_time = NA, End_time = NA, Error = "RDS file exists", Num_presences = NA)
        write.table(log_entry, file = log_file, append = TRUE, row.names = FALSE, col.names = FALSE, sep = ",")
      }
      next
    }

    # Download occurrence data
    Occs <- tryCatch(
      expr = {
        rgbif::occ_data(scientificName = Species[i],
                        hasCoordinate = T,
                        continent = continent,
                        country = country,
                        hasGeospatialIssue = FALSE,
                        limit = limit,
                        ...)
      },
      error = function(e) {
        message(paste("Error for species", Species[i], Sys.time()))
        if(Log == T){
          log_entry <- data.frame(Species = Species[i], Start_time = NA, End_time = format(Sys.time()), Error = "Error downloading occurrence data", Num_presences = NA)
          write.table(log_entry, file = log_file, append = TRUE, row.names = FALSE, col.names = FALSE, sep = ",")
        }
        NULL
      })

    # Save occurrence data or add to list
    if (is.null(Occs)) {
      message(paste("Skipping", Species[i], "- Error downloading occurrence data"))
    } else {
      if(WriteFile == T){
        try({saveRDS(Occs$data, rds_file)})
      } else if(WriteFile == F){
        Presences[[i]] <- Occs$data
      }
      if(Log == T){
        if(is.null(Occs$data)){
          log_entry <- data.frame(Species = Species[i], Start_time = format(Sys.time()), End_time = format(Sys.time()), Error = NA, Num_presences = 0)
        } else if (!is.null(Occs$data)){
          log_entry <- data.frame(Species = Species[i], Start_time = format(Sys.time()), End_time = format(Sys.time()), Error = NA, Num_presences = nrow(Occs$data))
        }
        write.table(log_entry, file = log_file, append = TRUE, row.names = FALSE, col.names = FALSE, sep = ",")
      }
    }

    rm(Occs)
    gc()

    message(paste(i, "of", length(Species), "ready!", Sys.time()))
  }

  if(WriteFile == F){
    return(Presences)
  }
}

#' Get Occurrence Data for a Given Species List
#'
#' This function retrieves occurrence data for a given list of species using the `GetOccs` function. The function is designed to fetch data for species in Denmark (`country = "DK"`) from 1999 to 2023 and return a cleaned data frame with selected columns.
#'
#' @param species A data.frame or tibble containing a column named `species` with the list of species to query.
#' @param shapefile A shapefile (with lat/long coordinates) defining the area of interest.
#'   The function will create a minimum bounding rectangle around the shapefile to query the
#'   species occurrences. Default is `NULL`.
#' @param country A two-letter country code (e.g., "DK" for Denmark) to define the area of interest.
#'
#' @return A data.frame containing the occurrence data for the specified species, including the columns: `scientificName`, `decimalLatitude`, `decimalLongitude`, `family`, `genus`, and `species`.
#'
#' @importFrom dplyr select
#' @importFrom terra geom minRect vect
#' @examples
#' \dontrun{
#' # Assume `species_list` is a data.frame with a column named `species`
#' presences <- get_presences(species_list)
#' }
#' @export

get_presences <- function(species, country = NULL, shapefile = NULL){

  scientificName <- decimalLatitude <- decimalLongitude <- family <- genus <- species <- NULL

  if(!is.null(shapefile)){
    geometry <- terra::vect(shapefile) |>
      terra::minRect() |>
      terra::geom(wkt = TRUE)
  } else if(is.null(shapefile)){
    geometry <- NULL
  }

  DF<- GetOccs(Species = unique(as.character(species$species)),
                             WriteFile = FALSE,
                             Log = FALSE,
                             country = country,
                             limit = 100000,
                             year='1999,2023',
                             geometry = geometry)
  try(DF <- DF[[1]] |> dplyr::select(scientificName, decimalLatitude, decimalLongitude, family, genus, species))
  return(DF)
}

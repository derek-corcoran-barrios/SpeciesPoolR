#' Convex_20
#'
#' Creates a 20% expanded convex hull from a set of coordinates.
#'
#' @param DF The dataframe containing the coordinates.
#' @param lon The name of the longitude column in the dataframe.
#' @param lat The name of the latitude column in the dataframe.
#' @param proj The projection of the coordinates.
#' @return A polygon representing the expanded convex hull by 20%.
#' @importFrom terra vect crds convHull geom centroids
#' @importFrom dplyr select
#' @export
#'
#' @examples
#'
#' DF <- data.frame(decimalLongitude =
#'       c(23.978543, 23.785003, 11.485,  -2.054027, 12.9069),
#'                  decimalLatitude =
#'        c(38.088876, 60.238213, 48.165, 53.33939, 56.80782))
#'
#' Convex_20(DF, lon = "decimalLongitude", lat = "decimalLatitude",
#' proj = "+proj=longlat +datum=WGS84 +no_defs")
#'

Convex_20 <- function(DF, lon = "decimalLongitude", lat = "decimalLatitude", proj = "+proj=longlat +datum=WGS84 +no_defs"){
  x <- y <- NULL
  SppOccur_TV <- terra::vect(DF, crs=proj, geom = c(lon, lat))

  # Then I get the coordinates as a dataframe for later use.
  occs <- as.data.frame(terra::crds(SppOccur_TV))
  colnames(occs) <- c("Longitude", "Latitude")

  # Here I generate a minimum convex hull
  SppConvexTerra <- terra::convHull(SppOccur_TV)

  ncg <- terra::geom(SppConvexTerra)|> as.data.frame() |> dplyr::select(x,y)
  # Then I extract the geometry of it.

  # And the centroid.
  cntrd <- terra::centroids(SppConvexTerra) |>
    terra::geom() |> as.data.frame() |> dplyr::select(x,y)

  # Finally, I expand the convex hull by 20%.
  ncg2 <- ncg

  ncg2$x <- (ncg$x - cntrd$x)*1.2 + cntrd$x
  ncg2$y <- (ncg$y - cntrd$y)*1.2 + cntrd$y



  # And get it back as a polygon.
  ncg2 <- terra::vect(as.matrix(ncg2), crs=proj, type = "polygon")
}



#' Sample Land-Use Data for Species Presences or Background Locations
#'
#' This function samples land-use data either from species presence locations or from background locations within a specified geographic area.
#'
#' @param DF A data frame containing species presence or background data, with columns for `species`, `decimalLongitude`, and `decimalLatitude`.
#' @param file A string representing the path to a raster file that contains land-use data.
#' @param type A string specifying whether to sample land-use data from species presences (`"pres"`) or from background locations (`"bg"`). Defaults to `"pres"`.
#'
#' @return A data frame with the sampled land-use data. The data frame contains columns for `species`, `Landuse`, and `Pres`, where `Pres` indicates whether the row corresponds to a presence (1) or background (0) point.
#'
#' @importFrom terra rast project extract crop spatSample names
#' @importFrom dplyr select mutate filter
#' @importFrom stringr str_detect
#' @importFrom data.table as.data.table
#'
#' @export
SampleLanduse <- function(DF, file, type = "pres") {
  species <- decimalLongitude <- decimalLatitude <- Landuse <- .data <- NULL

  # Load raster and detect layer name
  LU <- terra::rast(file)
  layer_name <- names(LU)[1]  # Get the first layer name (adjust index if needed)

  Temp <- DF |>
    dplyr::select(species, decimalLongitude, decimalLatitude) |>
    terra::vect(geom = c("decimalLongitude", "decimalLatitude"), crs = "epsg:4326") |>
    terra::project(terra::crs(LU))

  if (type == "pres") {
    Data <- terra::extract(LU, Temp) |>
      dplyr::mutate(Landuse = as.character(.data[[layer_name]]), Pres = 1) |>
      dplyr::filter(!is.na(Landuse))
  } else if (type == "bg") {
    Data <- LU |>
      terra::crop(Convex_20(as.data.frame(Temp, geom = "xy"), lon = "x", lat = "y", proj = terra::crs(LU))) |>
      terra::spatSample(10000, na.rm = TRUE) |>
      dplyr::mutate(Landuse = as.character(.data[[layer_name]]), Pres = 0) |>
      dplyr::filter(!is.na(Landuse))
  }

  Data$species <- unique(Temp$species)
  return(Data)
}

#' Fit a Species Distribution Model Based on Land-Use Data
#'
#' This function fits a MaxEnt model to predict species distribution based on land-use data. It handles cases where land-use types are listed as "Both" by splitting these into separate "Poor" and "Rich" categories.
#'
#' @param DF A data frame containing species presence and background data, with columns for `species`, `Landuse`, and `Pres`. The `Landuse` column should be a factor representing different land-use types, and `Pres` should indicate whether the row corresponds to a presence (1) or background (0) point.
#'
#' @return A data frame with predicted species distribution for each land-use type. The data frame contains columns for `Landuse`, `Pred` (predicted value), and `species`.
#'
#' @importFrom dplyr mutate select filter arrange desc bind_rows
#' @importFrom tidyr pivot_longer
#' @importFrom stats model.matrix predict
#' @importFrom stringr str_remove_all
#' @importFrom maxnet maxnet
#'
#' @export


ModelSpecies <- function(DF) {
  Landuse <- Pred <-NULL
  All <- DF |>
    dplyr::mutate(Landuse = as.factor(Landuse))

  if (length(unique(All$Landuse)) > 1) {
    Landuse_matrix <- model.matrix(~ Landuse - 1, data = All)
    Mod <- tryCatch(
      maxnet::maxnet(p = All$Pres, data = as.data.frame(Landuse_matrix)),
      error = function(e) {
        cat("Error in model fitting:", conditionMessage(e), "\n")
        return(NULL)
      }
    )

    Preds <- data.frame(Landuse = unique(All$Landuse), Pred = 0)
    Landuse_matrix <- model.matrix(~ Landuse - 1, data = Preds)

    if (!is.null(Mod)) {
      Preds$Pred <- tryCatch(
        predict(Mod, Landuse_matrix, type = "cloglog"),
        error = function(e) {
          cat("Error in prediction:", conditionMessage(e), "\n")
          return(rep(0, nrow(Preds)))
        }
      )
    }

    Preds <- Preds |> dplyr::arrange(desc(Pred))
    Preds$species <- unique(All$species)
  } else {
    Preds <- data.frame(Landuse = unique(All$Landuse), Pred = 0, species = unique(All$species))
  }

  return(Preds)
}

#' @title Model and Predict Habitat Suitability
#'
#' @description This function performs the complete workflow for modeling habitat suitability for multiple species. It includes sampling land-use data for presence and background points separately, and then fitting a MaxEnt model to predict habitat suitability based on the available land-use types.
#'
#' @param DF A data frame containing species presence data with columns for species name, longitude (`decimalLongitude`), and latitude (`decimalLatitude`).
#' @param file A file path to the raster layer containing land-use data.
#'
#' @details The function encompasses several steps:
#' \enumerate{
#'   \item Grouping the data by species using `dplyr::group_split`.
#'   \item Sampling land-use data for species presence points using the `SampleLanduse` function.
#'   \item Sampling land-use data for background points using the `SampleLanduse` function.
#'   \item Combining the presence and background data, and fitting a MaxEnt model to predict habitat suitability using the `ModelSpecies` function, which also handles the duplication of rows where necessary.
#' }
#'
#' @return A data frame with predicted habitat suitability scores for each land-use type for each species.
#'
#' @importFrom terra rast vect project crop extract spatSample levels
#' @importFrom dplyr select mutate filter bind_rows left_join distinct arrange group_split
#' @importFrom stringr str_detect str_replace_all str_remove_all
#' @importFrom maxnet maxnet
#' @importFrom tidyr pivot_longer
#' @importFrom purrr map
#' @importFrom data.table as.data.table
#'
#' @export
ModelAndPredictFunc <- function(DF, file) {
  species <- NULL

  # Load the raster and extract land-use levels
  LU <- terra::rast(file)
  landuse_levels <- levels(LU)[[1]][,2]  # Get the land-use level names (adjust as needed)

  # Split the data by species
  split_species <- dplyr::group_split(DF, species)

  # Function to model each species individually
  model_single_species <- function(species_data) {
    Predicted <- data.frame(
      Pred = 0,
      Landuse = landuse_levels,  # Use the dynamic land-use categories here
      species = unique(species_data$species)
    )

    if (nrow(species_data) > 0) {
      tryCatch({
        # Sample land-use data for presence points
        Pres <- SampleLanduse(DF = species_data, file = file, type = "pres")

        # Sample land-use data for background points
        BG <- SampleLanduse(DF = species_data, file = file, type = "bg")

        # Combine presence and background data
        Both <- dplyr::bind_rows(Pres, BG)

        # Model species habitat suitability
        Predicted <- ModelSpecies(DF = Both)

      }, error = function(e) {
        # Handle the exception
        cat("An error occurred:", conditionMessage(e), "\n")
      })
    }

    return(Predicted)
  }

  # Apply the modeling function to each species
  results <- purrr::map(split_species, model_single_species)

  # Combine the results into a single data frame
  combined_results <- dplyr::bind_rows(results)

  return(combined_results)
}



#' Create Prediction Thresholds for Species Distribution Models
#'
#' This function generates thresholds for species distribution predictions based on modeled land-use preferences. Thresholds are calculated for the 99th, 95th, and 90th percentiles of the predicted values.
#'
#' @param Model A data frame containing model predictions, with columns for `species`, `Landuse`, and `Pred`.
#' @param reference A data frame containing reference species presence data for threshold calibration.
#' @param file A string representing the path to a raster file that contains land-use data.
#'
#' @return A data frame with the calculated thresholds. The data frame contains columns for `species`, `Thres_99`, `Thres_95`, and `Thres_90`.
#'
#' @importFrom dplyr filter left_join slice_max pull bind_rows
#' @importFrom stringr str_detect str_replace_all
#' @importFrom purrr map2 compact
#'
#' @export

create_thresholds <- function(Model, reference, file) {
  species <- process_species <- Pred <- NULL
  # Find species that are present in both Model and reference
  common_species <- intersect(unique(Model$species), unique(reference$species))

  # Filter Model and reference to include only common species
  Model <- Model |> dplyr::filter(species %in% common_species)
  reference <- reference |> dplyr::filter(species %in% common_species)

  # Split Model and reference by species
  Model_split <- split(Model, Model$species)
  reference_split <- split(reference, reference$species)

  # Define a helper function to process each species individually
  process_species <- function(Model_species, reference_species) {
    tryCatch({
      if (nrow(reference_species) == 0) {
        return(data.frame(
          species = unique(Model_species$species),
          Thres_99 = 1,
          Thres_95 = 1,
          Thres_90 = 1
        ))
      } else {
        Thres <- data.frame(
          species = unique(Model_species$species),
          Thres_99 = NA,
          Thres_95 = NA,
          Thres_90 = NA
        )

        Pres <- SampleLanduse(DF = reference_species, file = file)

        Thres$Thres_99 <- Pres |>
          dplyr::left_join(Model_species, by = c("species", "Landuse")) |>
          dplyr::slice_max(order_by = Pred, prop = 0.99, with_ties = FALSE) |>
          dplyr::pull(Pred) |>
          min()

        Thres$Thres_95 <- Pres |>
          dplyr::left_join(Model_species, by = c("species", "Landuse")) |>
          dplyr::slice_max(order_by = Pred, prop = 0.95, with_ties = FALSE) |>
          dplyr::pull(Pred) |>
          min()

        Thres$Thres_90 <- Pres |>
          dplyr::left_join(Model_species, by = c("species", "Landuse")) |>
          dplyr::slice_max(order_by = Pred, prop = 0.90, with_ties = FALSE) |>
          dplyr::pull(Pred) |>
          min()

        return(Thres)
      }
    }, error = function(e) {
      # If there's an error, return NULL or another appropriate value
      return(NULL)
    })
  }

  # Use purrr::map2 to apply process_species to each pair of Model and reference subsets
  thresholds_list <- purrr::map2(Model_split, reference_split, process_species)

  # Filter out any NULL results (if any errors occurred)
  thresholds_list <- purrr::compact(thresholds_list)

  # Combine the results into a single data frame
  thresholds <- dplyr::bind_rows(thresholds_list)

  return(thresholds)
}

#' Generate a Lookup Table for Species Land-Use Preferences
#'
#' This function generates a lookup table that indicates the land-use types where species are predicted to be present, based on model predictions and specified thresholds.
#'
#' @param Model A data frame containing model predictions, with columns for `species`, `Landuse`, and `Pred`.
#' @param Thresholds A data frame containing the thresholds for presence predictions, with columns for `species`, `Thres_99`, `Thres_95`, and `Thres_90`.
#'
#' @return A data frame that indicates the land-use types where species are predicted to be present. The data frame contains columns for `species`, `Landuse`, and `Pres`.
#'
#' @importFrom dplyr mutate select
#' @importFrom data.table as.data.table
#'
#' @export

Generate_Lookup <- function(Model, Thresholds) {
  species <- Pres <- Pred <- Thres_95 <- Landuse <- . <- NULL
  Model <- as.data.table(Model)
  Model <- Model[species != "Spp"]
  Thresholds <- as.data.table(Thresholds)
  Thresholds <- Thresholds[species != "Spp"]
  joined_data <- merge(Model, as.data.table(Thresholds), by = c("species"), all = TRUE)
  joined_data[, Pres := ifelse(Pred > Thres_95, 1, 0)]
  joined_data <- joined_data[Pres > 0]  # Assign the filtered result to joined_data
  joined_data[, .(species, Landuse, Pres)]  # Return the selected columns
}


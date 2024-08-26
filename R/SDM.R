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
#' @importFrom terra rast project extract crop spatSample
#' @importFrom dplyr select mutate filter
#' @importFrom stringr str_detect
#' @importFrom data.table as.data.table
#' @examples
#' file <- system.file("extdata", "landuse.tif", package = "SpeciesPoolR")
#' presence_data <- SampleLanduse(DF = species_data, file = file, type = "pres")
#' background_data <- SampleLanduse(DF = species_data, file = file, type = "bg")
#'
#' @export
SampleLanduse <- function(DF, file, type = "pres") {
  Denmark_LU <- terra::rast(file)
  Temp <- DF |>
    dplyr::select(species, decimalLongitude, decimalLatitude) |>
    terra::vect(geom = c("decimalLongitude", "decimalLatitude"), crs = "epsg:4326") |>
    terra::project(terra::crs(Denmark_LU))

  if (type == "pres") {
    Data <- terra::extract(Denmark_LU, Temp) |>
      dplyr::mutate(Landuse = as.character(SN_ModelClass), Pres = 1) |>
      dplyr::filter(!is.na(Landuse))
  } else if (type == "bg") {
    Data <- Denmark_LU |>
      terra::crop(Convex_20(as.data.frame(Temp, geom = "xy"), lon = "x", lat = "y", proj = terra::crs(Denmark_LU))) |>
      terra::spatSample(10000, na.rm = TRUE) |>
      dplyr::mutate(Landuse = as.character(SN_ModelClass), Pres = 0) |>
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
#' @importFrom dplyr mutate select filter arrange
#' @importFrom tidyr pivot_longer
#' @importFrom stringr str_remove_all
#' @importFrom maxnet maxnet
#' @examples
#' model_output <- ModelSpecies(DF = combined_data)
#'
#' @export


ModelSpecies <- function(DF) {
  All <- DF |>
    dplyr::mutate(Landuse = as.factor(Landuse))

  is_both <- stringr::str_detect(All$Landuse, "Both")
  duplicated_rows1 <- All[is_both, ]
  duplicated_rows2 <- All[is_both, ]
  duplicated_rows1$Landuse <- stringr::str_replace_all(duplicated_rows1$Landuse, "Both", "Poor")
  duplicated_rows2$Landuse <- stringr::str_replace_all(duplicated_rows2$Landuse, "Both", "Rich")
  All <- All[!is_both, ] |>
    bind_rows(duplicated_rows1, duplicated_rows2)

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
#' @importFrom terra rast vect project crop extract spatSample
#' @importFrom dplyr select mutate filter bind_rows left_join distinct arrange group_split
#' @importFrom stringr str_detect str_replace_all str_remove_all
#' @importFrom maxnet maxnet
#' @importFrom tidyr pivot_longer
#' @importFrom purrr map
#' @importFrom data.table as.data.table
#'
#' @export
ModelAndPredictFunc <- function(DF, file) {
  # Split the data by species
  split_species <- dplyr::group_split(DF, species)

  # Function to model each species individually
  model_single_species <- function(species_data) {
    Predicted <- data.frame(
      Pred = 0,
      Landuse = c("ForestDryRich", "ForestDryPoor", "ForestWetRich", "OpenDryPoor",
                  "ForestWetPoor", "OpenDryRich", "OpenWetPoor", "Exclude", "OpenWetRich"),
      species = unique(species_data$species)
    )

    if (nrow(species_data) > 0) {
      tryCatch({
        # Sample land-use data for presence points
        Pres <- SampleLanduse(DF = species_data, file = file, type = "presence")

        # Sample land-use data for background points
        BG <- SampleLanduse(DF = species_data, file = file, type = "background")

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
#' @importFrom dplyr left_join slice_max pull
#' @examples
#' thresholds <- create_thresholds(Model = model_output, reference = reference_data, file = file)
#'
#' @export

create_thresholds <- function(Model, reference, file){
  if (nrow(reference) == 0) {
    Thres <- data.frame(species = unique(Model$species),Thres_99 = 1, Thres_95 = 1, Thres_90 = 1)
  } else {
    Thres <- data.frame(species = unique(Model$species),Thres_99 = NA, Thres_95 = NA, Thres_90 = NA)
    Pres <- SamplePresLanduse(DF = reference, file = file)
    FixedDataset <- DuplicateBoth(DF = Pres)
    Thres$Thres_99 <- FixedDataset |>
      dplyr::left_join(Model) |>
      slice_max(order_by = Pred,prop = 0.99, with_ties = F) |>
      pull(Pred) |>
      min()

    Thres$Thres_95 <- FixedDataset |>
      dplyr::left_join(Model) |>
      slice_max(order_by = Pred,prop = 0.95, with_ties = F) |>
      pull(Pred) |>
      min()

    Thres$Thres_90 <- FixedDataset |>
      dplyr::left_join(Model) |>
      slice_max(order_by = Pred,prop = 0.90, with_ties = F) |>
      pull(Pred) |>
      min()
  }

  return(Thres)
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
#' @examples
#' lookup_table <- Generate_Lookup(Model = model_output, Thresholds = thresholds)
#'
#' @export

Generate_Lookup <- function(Model, Thresholds) {
  Model <- as.data.table(Model)
  Model <- Model[species != "Spp"]
  Thresholds <- as.data.table(Thresholds)
  Thresholds <- Thresholds[species != "Spp"]
  joined_data <- merge(Model, as.data.table(Thresholds), by = c("species"), all = TRUE)
  joined_data[, Pres := ifelse(Pred > Thres_95, 1, 0)]
  joined_data <- joined_data[Pres > 0]  # Assign the filtered result to joined_data
  joined_data[, .(species, Landuse, Pres)]  # Return the selected columns
}


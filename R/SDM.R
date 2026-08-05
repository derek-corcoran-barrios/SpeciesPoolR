#' Convex_20
#'
#' Creates an expanded convex hull from a set of coordinates, used to define
#' a background-sampling area around a species' known occurrences.
#'
#' @param DF The dataframe containing the coordinates.
#' @param lon The name of the longitude column in the dataframe.
#' @param lat The name of the latitude column in the dataframe.
#' @param proj The projection of the coordinates.
#' @param expansion Numeric expansion factor applied to the convex hull
#'   around its centroid. Default 1.2 (a 20% expansion).
#' @return A polygon representing the expanded convex hull.
#' @importFrom terra vect convHull geom centroids
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
Convex_20 <- function(DF, lon = "decimalLongitude", lat = "decimalLatitude",
                      proj = "+proj=longlat +datum=WGS84 +no_defs", expansion = 1.2) {
  x <- y <- NULL
  SppOccur_TV <- terra::vect(DF, crs = proj, geom = c(lon, lat))

  SppConvexTerra <- terra::convHull(SppOccur_TV)

  ncg <- terra::geom(SppConvexTerra) |> as.data.frame() |> dplyr::select(x, y)

  cntrd <- terra::centroids(SppConvexTerra) |>
    terra::geom() |> as.data.frame() |> dplyr::select(x, y)

  ncg2 <- ncg
  ncg2$x <- (ncg$x - cntrd$x) * expansion + cntrd$x
  ncg2$y <- (ncg$y - cntrd$y) * expansion + cntrd$y

  terra::vect(as.matrix(ncg2), crs = proj, type = "polygon")
}

#' Sample Environmental Data for Species Presences or Background Locations
#'
#' Samples one or more environmental layers (categorical and/or continuous)
#' either at species presence locations or at background locations drawn
#' from within an expanded convex hull around those presences.
#'
#' @param DF A data frame with columns `species`, `decimalLongitude`, and
#'   `decimalLatitude`.
#' @param file A path (or vector of paths) to raster file(s) with the
#'   environmental layers. Passed to `terra::rast()`, which stacks multiple
#'   files into one multi-layer `SpatRaster` automatically.
#' @param categorical Optional character vector naming which layer(s) in the
#'   stack are categorical (e.g. land use). Layers not listed here are
#'   treated as continuous. Layers already stored as factors in the raster
#'   itself don't need to be listed.
#' @param type Either `"pres"` (sample at presence locations) or `"bg"`
#'   (sample background locations). Defaults to `"pres"`.
#' @param n_bg Number of background points to sample when `type = "bg"`.
#'   Default 10000.
#'
#' @return A data frame with one column per environmental layer (factor for
#'   categorical layers, numeric for continuous ones), plus `species` and
#'   `Pres` (1 for presence rows, 0 for background rows).
#'
#' @importFrom terra rast vect project extract crop spatSample is.factor as.factor
#' @importFrom dplyr select mutate
#' @importFrom tidyr drop_na
#'
#' @export
SampleEnv <- function(DF, file, categorical = NULL, type = "pres", n_bg = 10000) {
  species <- decimalLongitude <- decimalLatitude <- NULL

  Env <- terra::rast(file)
  if (!is.null(categorical)) {
    for (lyr in categorical) {
      if (!terra::is.factor(Env[[lyr]])) Env[[lyr]] <- terra::as.factor(Env[[lyr]])
    }
  }

  Temp <- DF |>
    dplyr::select(species, decimalLongitude, decimalLatitude) |>
    terra::vect(geom = c("decimalLongitude", "decimalLatitude"), crs = "EPSG:4326") |>
    terra::project(terra::crs(Env))

  if (type == "pres") {
    Data <- terra::extract(Env, Temp, ID = FALSE) |>
      dplyr::mutate(Pres = 1) |>
      tidyr::drop_na()
  } else if (type == "bg") {
    Data <- Env |>
      terra::crop(Convex_20(as.data.frame(Temp, geom = "xy"), lon = "x", lat = "y", proj = terra::crs(Env))) |>
      terra::spatSample(n_bg, na.rm = TRUE, as.df = TRUE) |>
      dplyr::mutate(Pres = 0) |>
      tidyr::drop_na()
  }

  Data$species <- unique(Temp$species)
  Data
}

#' Fit a Species Distribution Model from Mixed Environmental Predictors
#'
#' Fits a MaxEnt model (via `maxnet`) to presence/background data with any
#' mix of categorical and continuous predictors. Categorical predictors
#' (factor columns) are dummy-coded; continuous predictors get linear,
#' quadratic, hinge, and/or product terms, chosen automatically by
#' `maxnet::maxnet.formula()` based on sample size. No manual design matrix
#' is built -- `maxnet` handles both column types directly from raw data.
#'
#' @param DF A data frame with `species`, `Pres` (1 = presence, 0 =
#'   background), and one or more predictor columns (factor or numeric), as
#'   produced by [SampleEnv()].
#'
#' @return A fitted `maxnet` model object, or `NULL` if fitting failed or the
#'   predictors have no variability to model against.
#'
#' @importFrom maxnet maxnet
#'
#' @export
ModelSpecies <- function(DF) {
  predictors <- setdiff(names(DF), c("species", "Pres"))

  has_variability <- any(vapply(
    DF[predictors],
    function(x) length(unique(x[!is.na(x)])) > 1,
    logical(1)
  ))

  if (!has_variability) return(NULL)

  tryCatch(
    maxnet::maxnet(p = DF$Pres, data = DF[predictors]),
    error = function(e) {
      message("Error in model fitting: ", conditionMessage(e))
      NULL
    }
  )
}

#' @title Model and Predict Habitat Suitability
#'
#' @description Fits a species distribution model per species and predicts
#'   habitat suitability across every cell of the environmental raster
#'   stack, returning one continuous suitability layer per species (rather
#'   than a lookup table of predictions per category).
#'
#' @param DF A data frame with species presence data: `species`,
#'   `decimalLongitude`, `decimalLatitude`.
#' @param file A path (or vector of paths) to the environmental raster
#'   layer(s). Passed to `terra::rast()`.
#' @param categorical Optional character vector naming which layer(s) are
#'   categorical (e.g. land use). See [SampleEnv()].
#'
#' @details For each species: samples the environment at presence points and
#'   at background points (via [SampleEnv()]), fits a model (via
#'   [ModelSpecies()]), and predicts a full suitability surface with
#'   `terra::predict(..., type = "cloglog")`. If fitting fails for a
#'   species, that species' layer is filled with 0 rather than dropped, so
#'   the output stack always has one layer per input species.
#'
#' @return A multi-layer `SpatRaster`, one layer per species (named by
#'   species), each cell holding predicted habitat suitability (0-1).
#'
#' @importFrom terra rast is.factor as.factor predict values
#' @importFrom dplyr group_split bind_rows
#' @importFrom purrr map
#'
#' @export
ModelAndPredictFunc <- function(DF, file, categorical = NULL) {
  species <- NULL

  Env <- terra::rast(file)
  if (!is.null(categorical)) {
    for (lyr in categorical) {
      if (!terra::is.factor(Env[[lyr]])) Env[[lyr]] <- terra::as.factor(Env[[lyr]])
    }
  }

  empty_template <- function() {
    r <- terra::rast(Env[[1]])  # same geometry, no values, no factor levels
    terra::values(r) <- 0
    r
  }

  split_species <- dplyr::group_split(DF, species)

  model_single_species <- function(species_data) {
    sp <- unique(species_data$species)

    Suitability <- tryCatch({
      if (nrow(species_data) == 0) stop("no presence records")

      Pres <- SampleEnv(species_data, file = file, categorical = categorical, type = "pres")
      BG   <- SampleEnv(species_data, file = file, categorical = categorical, type = "bg")
      Both <- dplyr::bind_rows(Pres, BG)

      Mod <- ModelSpecies(Both)

      if (is.null(Mod)) {
        empty_template()
      } else {
        terra::predict(Env, Mod, type = "cloglog", na.rm = TRUE)
      }
    }, error = function(e) {
      message("An error occurred modeling ", sp, ": ", conditionMessage(e))
      empty_template()
    })

    names(Suitability) <- sp
    Suitability
  }

  results <- purrr::map(split_species, model_single_species)
  do.call(c, results)
}

#' Create Prediction Thresholds for Species Distribution Models
#'
#' Generates presence-prediction thresholds directly from a species'
#' predicted suitability raster, evaluated at its own known occurrence
#' points -- no re-sampling of the environmental stack needed, since the
#' suitability raster already encodes the model.
#'
#' @param Model A multi-layer `SpatRaster` of predicted suitability, one
#'   layer per species (named by species), as produced by
#'   [ModelAndPredictFunc()].
#' @param reference A data frame of reference occurrence points for
#'   threshold calibration, with columns `species`, `decimalLongitude`,
#'   `decimalLatitude`.
#'
#' @return A data frame with columns `species`, `Thres_99`, `Thres_95`, and
#'   `Thres_90` -- the suitability value below which 1%, 5%, and 10% of
#'   known occurrences fall, respectively.
#'
#' @importFrom terra vect project extract crs
#' @importFrom dplyr filter select
#' @importFrom purrr map compact
#' @importFrom stats quantile
#'
#' @export
create_thresholds <- function(Model, reference) {
  species <- decimalLongitude <- decimalLatitude <- NULL

  common_species <- intersect(names(Model), unique(reference$species))
  reference <- reference |> dplyr::filter(species %in% common_species)
  reference_split <- split(reference, reference$species)

  process_species <- function(sp) {
    ref_sp <- reference_split[[sp]]

    tryCatch({
      if (is.null(ref_sp) || nrow(ref_sp) == 0) {
        return(data.frame(species = sp, Thres_99 = 1, Thres_95 = 1, Thres_90 = 1))
      }

      pts <- ref_sp |>
        dplyr::select(decimalLongitude, decimalLatitude) |>
        terra::vect(geom = c("decimalLongitude", "decimalLatitude"), crs = "EPSG:4326") |>
        terra::project(terra::crs(Model))

      vals <- terra::extract(Model[[sp]], pts)[[sp]]
      vals <- vals[!is.na(vals)]

      q <- stats::quantile(vals, probs = c(0.01, 0.05, 0.10), na.rm = TRUE)

      data.frame(species = sp, Thres_99 = unname(q[1]), Thres_95 = unname(q[2]), Thres_90 = unname(q[3]))
    }, error = function(e) NULL)
  }

  thresholds_list <- purrr::map(common_species, process_species)
  thresholds_list <- purrr::compact(thresholds_list)

  dplyr::bind_rows(thresholds_list)
}

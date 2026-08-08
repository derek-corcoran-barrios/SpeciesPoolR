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
    maxnet::maxnet(
      p = DF$Pres,
      data = as.data.frame(DF[predictors]),
      addsamplestobackground = FALSE # Bypasses the apply() bug
    ),
    error = function(e) {
      message("Error in model fitting: ", conditionMessage(e))
      NULL
    }
  )
}

#' Predict a maxnet model onto every non-NA cell of a raster stack
#'
#' Bypasses `terra::predict()`'s internal per-chunk data building, which has
#' known quirks with `maxnet`/`maxent` models on rasters that contain NA
#' cells (rspatial/terra#352) and doesn't always propagate factor levels the
#' same way `terra::extract()` does. Instead, this pulls every non-NA cell
#' out as a plain data frame (factors intact, exactly like [SampleEnv()]
#' would see them), predicts on that data frame directly with
#' `predict.maxnet()`, and writes the results back into a template raster by
#' cell index -- so training-space and prediction-space are guaranteed to be
#' built the same way.
#'
#' Note this loads every non-NA cell into memory as one data frame, unlike
#' `terra::predict()`'s memory-safe chunking. Fine for a country-sized
#' raster at moderate resolution; if you outgrow memory, this would need to
#' be chunked (e.g. with `terra::blocks()`).
#'
#' @param Env The environmental `SpatRaster` stack (already prepared with
#'   any categorical layers marked via `terra::as.factor()`).
#' @param Mod A fitted `maxnet` model.
#' @param type Prediction type passed to `predict.maxnet()`. Default
#'   `"cloglog"`.
#'
#' @return A single-layer `SpatRaster` of predicted values, NA outside the
#'   cells that had complete predictor data.
#'
#' @importFrom terra as.data.frame rast values
#' @keywords internal
predict_maxnet_raster <- function(Env, Mod, type = "cloglog") {
  vals <- terra::as.data.frame(Env, cells = TRUE, na.rm = TRUE)

  Suitability <- terra::rast(Env, nlyrs = 1)
  terra::values(Suitability) <- NA_real_

  if (nrow(vals) == 0) return(Suitability)

  cell_ids <- vals$cell
  newdata <- vals[, setdiff(names(vals), "cell"), drop = FALSE]

  preds <- as.numeric(predict(Mod, newdata = newdata, type = type))
  Suitability[cell_ids] <- preds

  Suitability
}

#' Fit Species Distribution Models
#'
#' Samples the environment at presence and background locations and fits a
#' model per species, returning the fitted models themselves rather than a
#' prediction. Keeping fitting separate from prediction means the (often
#' expensive) fitting step only has to happen once -- the same fitted models
#' can later be predicted onto the current land-use raster and onto any
#' number of hypothetical scenario rasters, without refitting and without
#' introducing fresh background-sampling noise into each comparison.
#'
#' @param DF A data frame with species presence data: `species`,
#'   `decimalLongitude`, `decimalLatitude`.
#' @param file A path (or vector of paths) to the environmental raster
#'   layer(s) used to sample training data. Passed to `terra::rast()`.
#' @param categorical Optional character vector naming which layer(s) are
#'   categorical (e.g. land use). See [SampleEnv()].
#'
#' @return A named list of fitted `maxnet` models, one per species (`NULL`
#'   for a species whose model failed to fit or had no variability to model
#'   against). A plain R list -- no `terra` objects -- so it stores fine as
#'   an ordinary `targets::tar_target()`.
#'
#' @importFrom dplyr group_split bind_rows
#' @importFrom purrr map map_chr
#'
#' @export
FitSpeciesModels <- function(DF, file, categorical = NULL) {
  species <- NULL
  split_species <- dplyr::group_split(DF, species)

  fit_one <- function(species_data) {
    sp <- unique(species_data$species)

    tryCatch({
      if (nrow(species_data) == 0) stop("no presence records")

      Pres <- SampleEnv(species_data, file = file, categorical = categorical, type = "pres")
      BG   <- SampleEnv(species_data, file = file, categorical = categorical, type = "bg")
      Both <- dplyr::bind_rows(Pres, BG)

      ModelSpecies(Both)
    }, error = function(e) {
      message("An error occurred fitting ", sp, ": ", conditionMessage(e))
      NULL
    })
  }

  Models <- purrr::map(split_species, fit_one)
  names(Models) <- purrr::map_chr(split_species, ~ unique(.x$species))
  Models
}

#' Predict Habitat Suitability From Already-Fitted Models
#'
#' Predicts habitat suitability across every cell of an environmental raster
#' stack, using models that were already fit by [FitSpeciesModels()]. Pass
#' the current land-use raster for a baseline prediction, or a hypothetical
#' scenario raster (same layers, different values) to see how suitability
#' would shift under that scenario -- same models either time, so any
#' difference reflects the land-use change itself, not modeling noise.
#'
#' @param Models A named list of fitted `maxnet` models (or `NULL` entries),
#'   as produced by [FitSpeciesModels()].
#' @param file A path (or vector of paths) to the raster layer(s) to predict
#'   onto, or an already-loaded `SpatRaster` (e.g. one scenario pulled out
#'   of a `SpatRasterCollection`). Must have the same layer names (and, for
#'   categorical layers, comparable categories) as the raster used to fit
#'   the models.
#' @param categorical Optional character vector naming which layer(s) are
#'   categorical. See [SampleEnv()].
#'
#' @return A multi-layer `SpatRaster`, one layer per species (named by
#'   species), each cell holding predicted habitat suitability (0-1). A
#'   species whose model was `NULL` gets a layer filled with 0 rather than
#'   being dropped, so the output always has one layer per input model.
#'
#' @importFrom terra rast is.factor as.factor values
#' @importFrom purrr map
#'
#' @export
PredictSuitability <- function(Models, file, categorical = NULL) {
  Env <- if (inherits(file, "SpatRaster")) file else terra::rast(file)
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

  predict_one <- function(sp) {
    Mod <- Models[[sp]]

    Suitability <- if (is.null(Mod)) {
      empty_template()
    } else {
      tryCatch(
        predict_maxnet_raster(Env, Mod, type = "cloglog"),
        error = function(e) {
          message("An error occurred predicting ", sp, ": ", conditionMessage(e))
          empty_template()
        }
      )
    }

    names(Suitability) <- sp
    Suitability
  }

  results <- purrr::map(names(Models), predict_one)
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
#'   [PredictSuitability()].
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

#' Load a Single User-Supplied Scenario Raster
#'
#' Loads and (optionally) crops/masks one scenario's raster file(s). This is
#' the per-branch counterpart to [load_scenario_collection()] -- use this
#' one (branched with `pattern = map()` over a spec of scenarios) inside a
#' `targets` pipeline via `geotargets::tar_terra_rast()`, not
#' `tar_terra_sprc()`: `tar_terra_sprc()` has no `preserve_metadata`
#' argument, so a categorical layer's real category labels (e.g. "Forest",
#' "Agriculture") can silently come back as plain numeric codes after the
#' storage round trip, which is exactly the kind of mismatch that breaks
#' prediction against a model trained on the real labels. `tar_terra_rast()`
#' does support `preserve_metadata`, hence loading scenarios one at a time.
#'
#' @param path A path (or vector of paths, for a scenario made of several
#'   layers) for one scenario.
#' @param crop_to Optional: a study-area boundary to crop and mask to -- a
#'   path to a vector file, or an already-loaded `SpatVector`.
#' @param categorical Optional character vector naming which layer(s) are
#'   categorical (e.g. land use). See [SampleEnv()].
#'
#' @return A single `SpatRaster` for this one scenario.
#'
#' @importFrom terra rast vect crop mask is.factor as.factor
#'
#' @export
load_one_scenario <- function(path, crop_to = NULL, categorical = NULL) {
  r <- terra::rast(path)

  if (!is.null(crop_to)) {
    boundary <- if (inherits(crop_to, "SpatVector")) crop_to else terra::vect(crop_to)
    r <- terra::crop(r, boundary)
    r <- terra::mask(r, boundary)
  }

  if (!is.null(categorical)) {
    for (lyr in categorical) {
      if (!terra::is.factor(r[[lyr]])) r[[lyr]] <- terra::as.factor(r[[lyr]])
    }
  }

  r
}

#' Load User-Supplied Scenario Rasters (All at Once, for Interactive Use)
#'
#' The multi-scenario convenience version of [load_one_scenario()]: loads
#' every scenario in one call and packages them into a `SpatRasterCollection`
#' for easy interactive inspection (e.g. `terra::plot(Scenarios)`). Fine to
#' use this directly outside a pipeline. Inside a `targets` pipeline, prefer
#' branching with [load_one_scenario()] via `geotargets::tar_terra_rast()`
#' instead of wrapping this in `tar_terra_sprc()` -- see [load_one_scenario()]
#' for why.
#'
#' @param files A named list. Each element is a path (or vector of paths,
#'   for a scenario made of several layers) for one scenario. The list
#'   names become the scenario names.
#' @param crop_to Optional: a study-area boundary to crop and mask every
#'   scenario to -- a path to a vector file, or an already-loaded
#'   `SpatVector`. Use this when your scenario rasters cover a larger area
#'   than you actually want to study (e.g. all of Europe, but you only care
#'   about Denmark).
#' @param categorical Optional character vector naming which layer(s) are
#'   categorical (e.g. land use). See [SampleEnv()].
#'
#' @return A `SpatRasterCollection`, one member per scenario, named as in
#'   `files`.
#'
#' @importFrom terra sprc
#' @importFrom purrr map
#'
#' @export
load_scenario_collection <- function(files, crop_to = NULL, categorical = NULL) {
  scenarios <- purrr::map(files, load_one_scenario, crop_to = crop_to, categorical = categorical)
  terra::sprc(scenarios)
}

#' Build Land-Use Scenario Rasters by Recoding a Category (Convenience Helper)
#'
#' A convenience for the simple case: mechanically recoding one land-use
#' category into alternatives on a raster that's already at the right
#' extent (e.g. testing/demo purposes). For a real analysis with
#' externally-produced scenarios or a larger source extent that needs
#' cropping to a study area, use [load_scenario_collection()] instead.
#'
#' @param file Path to the baseline land-use raster.
#' @param old_value The raw category code to replace (e.g. Agriculture).
#' @param new_value Numeric vector of replacement category codes, one per
#'   scenario.
#' @param name Character vector of scenario names, same length as
#'   `new_value`, used as each scenario's layer name (so `categorical`
#'   matching still works downstream).
#'
#' @return A `SpatRasterCollection`, one member per scenario.
#'
#' @importFrom terra rast ifel sprc
#' @importFrom purrr map
#'
#' @export
make_landuse_scenarios <- function(file, old_value, new_value, name) {
  LU <- terra::rast(file)

  scenarios <- purrr::map(seq_along(new_value), function(i) {
    s <- terra::ifel(LU == old_value, new_value[i], LU)
    names(s) <- names(LU)
    s
  })
  names(scenarios) <- name

  terra::sprc(scenarios)
}

#' Predict Suitability Across a Collection of Land-Use Scenarios
#'
#' Applies [PredictSuitability()] to every member of a scenario
#' `SpatRasterCollection`, using the same already-fitted models each time
#' (see [FitSpeciesModels()]) -- no refitting per scenario.
#'
#' @param Models A named list of fitted `maxnet` models, one per species
#'   (the *combined* list across all species, not a single-species branch).
#' @param Scenarios A `SpatRasterCollection`, as produced by
#'   [load_scenario_collection()] or [make_landuse_scenarios()].
#' @param categorical Optional character vector naming which layer(s) are
#'   categorical. See [SampleEnv()].
#'
#' @return A `SpatRasterCollection`, one member per scenario, each member a
#'   multi-layer `SpatRaster` (one layer per species) of predicted
#'   suitability -- directly comparable to a baseline stack built the same
#'   way from [PredictSuitability()].
#'
#' @importFrom terra sprc
#' @importFrom purrr map
#'
#' @export
PredictScenarios <- function(Models, Scenarios, categorical = NULL) {
  scenario_list <- as.list(Scenarios)

  predicted <- purrr::map(
    scenario_list,
    \(env) PredictSuitability(Models, file = env, categorical = categorical)
  )

  terra::sprc(predicted)
}

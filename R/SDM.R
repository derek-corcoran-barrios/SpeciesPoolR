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

#' Predict a maxnet model onto a raster stack in bounded-memory blocks
#'
#' Reads the environmental raster a block at a time, converts only that block
#' to the tabular representation required by `predict.maxnet()`, and writes
#' predictions immediately to a file-backed raster. This keeps peak memory
#' bounded by the selected block size instead of the total number of raster
#' cells.
#'
#' `terra::readValues(..., dataframe = TRUE)` is used deliberately so that
#' categorical raster layers are returned with their category labels. Factor
#' predictors are then aligned explicitly to the levels stored in the fitted
#' `maxnet` model. Cells with an incomplete predictor vector, including a
#' categorical value not seen during model fitting, are written as `NA`.
#'
#' @param Env The environmental `SpatRaster` stack (already prepared with
#'   any categorical layers marked via `terra::as.factor()`).
#' @param Mod A fitted `maxnet` model.
#' @param type Prediction type passed to `predict.maxnet()`. Default
#'   `"cloglog"`.
#' @param filename Optional output filename. If `""`, a temporary GeoTIFF is
#'   created. Supplying a filename is useful when the caller wants to manage
#'   the prediction file explicitly.
#' @param overwrite Logical passed to `terra::writeStart()`.
#' @param blocks_in_memory Positive integer passed as `n` to
#'   `terra::blocks()`. It represents the approximate number of copies of the
#'   input data that may be needed in memory while choosing a block size.
#'   Default `4L`.
#'
#' @return A file-backed, single-layer `SpatRaster` of predicted values, with
#'   `NA` in cells that did not have a complete, model-compatible predictor
#'   vector.
#'
#' @importFrom terra blocks rast readStart readStop readValues writeStart
#'   writeStop writeValues
#' @keywords internal
predict_maxnet_raster <- function(
    Env,
    Mod,
    type = "cloglog",
    filename = "",
    overwrite = TRUE,
    blocks_in_memory = 4L
) {
  if (!inherits(Env, "SpatRaster")) {
    stop("`Env` must be a terra SpatRaster.", call. = FALSE)
  }

  if (!inherits(Mod, "maxnet")) {
    stop("`Mod` must be a fitted maxnet model.", call. = FALSE)
  }

  type <- match.arg(
    type,
    choices = c("link", "exponential", "cloglog", "logistic")
  )

  blocks_in_memory <- as.integer(blocks_in_memory)
  if (
    length(blocks_in_memory) != 1L ||
    is.na(blocks_in_memory) ||
    blocks_in_memory < 1L
  ) {
    stop("`blocks_in_memory` must be one positive integer.", call. = FALSE)
  }

  if (length(filename) != 1L || is.na(filename)) {
    stop("`filename` must be one non-missing character value.", call. = FALSE)
  }

  model_predictors <- names(Mod$levels)
  if (is.null(model_predictors) || length(model_predictors) == 0L) {
    model_predictors <- unique(c(names(Mod$varmin), names(Mod$samplemeans)))
  }

  missing_predictors <- setdiff(model_predictors, names(Env))
  if (length(missing_predictors) > 0L) {
    stop(
      "Prediction raster is missing model predictor(s): ",
      paste(missing_predictors, collapse = ", "),
      call. = FALSE
    )
  }

  # Keep the same predictor order used for fitting and ignore unrelated layers.
  Env <- Env[[model_predictors]]

  if (!nzchar(filename)) {
    filename <- tempfile(
      pattern = "SpeciesPoolR_suitability_",
      fileext = ".tif"
    )
  }

  out <- terra::rast(Env[[1]])
  names(out) <- "suitability"

  block_info <- terra::blocks(Env, n = blocks_in_memory)

  reading_open <- FALSE
  writing_open <- FALSE

  on.exit({
    if (isTRUE(reading_open)) {
      try(terra::readStop(Env), silent = TRUE)
    }
    if (isTRUE(writing_open)) {
      try(terra::writeStop(out), silent = TRUE)
    }
  }, add = TRUE)

  terra::readStart(Env)
  reading_open <- TRUE

  terra::writeStart(
    out,
    filename = filename,
    overwrite = overwrite,
    datatype = "FLT4S",
    gdal = c("COMPRESS=DEFLATE")
  )
  writing_open <- TRUE

  model_levels <- Mod$levels
  factor_predictors <- if (is.null(model_levels)) {
    character()
  } else {
    names(model_levels)[lengths(model_levels) > 0L]
  }

  for (i in seq_along(block_info$row)) {
    newdata <- terra::readValues(
      Env,
      row = block_info$row[i],
      nrows = block_info$nrows[i],
      dataframe = TRUE
    )

    # Force categorical predictors to exactly the levels used for fitting.
    # Unknown scenario categories become NA and are not predicted.
    for (predictor in intersect(factor_predictors, names(newdata))) {
      newdata[[predictor]] <- factor(
        as.character(newdata[[predictor]]),
        levels = model_levels[[predictor]]
      )
    }

    complete <- stats::complete.cases(newdata)
    prediction <- rep(NA_real_, nrow(newdata))

    if (any(complete)) {
      predicted <- as.numeric(
        predict(
          Mod,
          newdata = newdata[complete, , drop = FALSE],
          type = type
        )
      )

      if (length(predicted) != sum(complete)) {
        stop(
          "`predict.maxnet()` returned ", length(predicted),
          " values for ", sum(complete), " complete raster cells.",
          call. = FALSE
        )
      }

      prediction[complete] <- predicted
    }

    terra::writeValues(
      out,
      prediction,
      start = block_info$row[i],
      nrows = block_info$nrows[i]
    )
  }

  terra::readStop(Env)
  reading_open <- FALSE

  terra::writeStop(out)
  writing_open <- FALSE

  result <- terra::rast(filename)
  names(result) <- "suitability"
  result
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
#' @param blocks_in_memory Positive integer passed to the internal block-based
#'   raster predictor. Default `4L`. Lower-memory systems can increase this
#'   value to request smaller processing blocks.
#'
#' @return A multi-layer `SpatRaster`, one layer per species (named by
#'   species), each cell holding predicted habitat suitability (0-1). A
#'   species whose model was `NULL` gets a layer filled with 0 rather than
#'   being dropped, so the output always has one layer per input model.
#'
#' @importFrom terra rast is.factor as.factor init
#' @importFrom purrr map
#'
#' @export
PredictSuitability <- function(
    Models,
    file,
    categorical = NULL,
    blocks_in_memory = 4L
) {
  if (!is.list(Models) || length(Models) == 0L) {
    stop("`Models` must be a non-empty named list.", call. = FALSE)
  }

  model_names <- names(Models)
  if (
    is.null(model_names) ||
    anyNA(model_names) ||
    any(!nzchar(model_names)) ||
    anyDuplicated(model_names)
  ) {
    stop("`Models` must have unique, non-empty species names.", call. = FALSE)
  }

  blocks_in_memory <- as.integer(blocks_in_memory)
  if (
    length(blocks_in_memory) != 1L ||
    is.na(blocks_in_memory) ||
    blocks_in_memory < 1L
  ) {
    stop("`blocks_in_memory` must be one positive integer.", call. = FALSE)
  }

  Env <- if (inherits(file, "SpatRaster")) file else terra::rast(file)

  if (!is.null(categorical)) {
    missing_categorical <- setdiff(categorical, names(Env))
    if (length(missing_categorical) > 0L) {
      stop(
        "Categorical raster layer(s) not found: ",
        paste(missing_categorical, collapse = ", "),
        call. = FALSE
      )
    }

    for (lyr in categorical) {
      if (!terra::is.factor(Env[[lyr]])) Env[[lyr]] <- terra::as.factor(Env[[lyr]])
    }
  }

  empty_template <- function() {
    filename <- tempfile(
      pattern = "SpeciesPoolR_zero_suitability_",
      fileext = ".tif"
    )

    r <- terra::rast(Env[[1]])
    r <- terra::init(
      r,
      fun = 0,
      filename = filename,
      overwrite = TRUE,
      wopt = list(
        datatype = "FLT4S",
        gdal = c("COMPRESS=DEFLATE")
      )
    )
    r
  }

  predict_one <- function(sp) {
    Mod <- Models[[sp]]

    Suitability <- if (is.null(Mod)) {
      empty_template()
    } else {
      tryCatch(
        predict_maxnet_raster(
          Env = Env,
          Mod = Mod,
          type = "cloglog",
          blocks_in_memory = blocks_in_memory
        ),
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
  result <- do.call(c, results)
  names(result) <- names(Models)
  result
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

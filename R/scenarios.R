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

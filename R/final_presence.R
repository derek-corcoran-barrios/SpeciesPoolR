#' Mask Suitability by a Dispersal Buffer, Preserving True No-Data
#'
#' Sets suitability to 0 outside the buffer -- not `NA` -- so that a later
#' sum across species (for richness) treats "not within reach of this
#' species" as a real zero rather than a missing value. Genuine no-data
#' cells (e.g. ocean, outside the study area) stay `NA`:
#' `terra::mask(..., updatevalue = 0)` alone would zero those out too,
#' since it only checks whether a cell falls inside the mask geometry, not
#' whether the input itself was already `NA` there -- so this re-masks
#' against the original `Model` afterward to restore true `NA` wherever the
#' environment itself had no data.
#'
#' @param Model A single-layer `SpatRaster` of predicted suitability for
#'   one species (as produced by [PredictSuitability()]).
#' @param Mask A `SpatVector` -- the species' dispersal buffer, as produced
#'   by [make_buffer()].
#'
#' @return A `SpatRaster`, same extent and resolution as `Model`: original
#'   suitability values inside the buffer, 0 outside the buffer (wherever
#'   `Model` had real data), `NA` wherever `Model` itself was `NA`.
#'
#' @importFrom terra mask
#'
#' @export
mask_suitability <- function(Model, Mask) {
  masked <- terra::mask(Model, Mask, updatevalue = 0)
  terra::mask(masked, Model)
}

#' Threshold a Suitability Raster into Binary Presence/Absence
#'
#' Applies each species' own threshold (from [create_thresholds()]) to its
#' suitability layer, converting continuous suitability into binary (0/1)
#' presence/absence. Works on a single-species layer or a multi-species
#' stack alike -- matches thresholds to layers by name, so `Model`'s layer
#' names must be species names, matching `Thresholds$species`.
#'
#' @param Model A `SpatRaster` (one or more layers) of predicted
#'   suitability, one layer per species, layer-named by species.
#' @param Thresholds A data frame with columns `species` and a threshold
#'   column (see `threshold`), as produced by [create_thresholds()].
#' @param threshold Which threshold column to use. Default `"Thres_95"`.
#'
#' @return A `SpatRaster`, same shape as `Model`, with each layer recoded
#'   to 1 (suitability at or above that species' threshold) or 0 (below
#'   it). `NA` is preserved wherever `Model` was `NA`.
#'
#' @importFrom terra nlyr ifel
#'
#' @export
threshold_suitability <- function(Model, Thresholds, threshold = "Thres_95") {
  th <- Thresholds[
    match(names(Model), Thresholds$species),
    threshold
  ]
  if (anyNA(th)) {
    stop("Missing threshold for one or more species.")
  }
  out <- Model
  for (i in seq_len(terra::nlyr(Model))) {
    out[[i]] <- terra::ifel(
      Model[[i]] >= th[i],
      1,
      0
    )
  }
  names(out) <- names(Model)
  out
}

#' Mask a Multi-Species Suitability Stack by Per-Species Buffers
#'
#' Applies [mask_suitability()] species by species to a multi-layer
#' suitability stack (e.g. one scenario's full stack from
#' [PredictScenarios()]), matching each layer to its own buffer via the
#' buffer's own `species` attribute, not list position or names.
#'
#' @param Suitability A multi-layer `SpatRaster`, one layer per species,
#'   layer-named by species.
#' @param buffer A list of per-species dispersal-buffer `SpatVector`s, as
#'   produced by [make_buffer()].
#'
#' @return A `SpatRaster`, same shape as `Suitability`, masked per
#'   [mask_suitability()]. A species with no buffer gets 0 wherever
#'   `Suitability` had data, `NA` elsewhere.
#'
#' @importFrom terra ifel
#' @importFrom purrr map map_chr
#'
#' @export
mask_suitability_stack <- function(Suitability, buffer) {
  buffer_by_species <- stats::setNames(
    buffer,
    purrr::map_chr(buffer, \(b) unique(as.character(b$species))[1])
  )

  masked <- purrr::map(names(Suitability), function(sp) {
    buf <- buffer_by_species[[sp]]
    r <- if (is.null(buf) || nrow(buf) == 0) {
      terra::ifel(is.na(Suitability[[sp]]), NA, 0)
    } else {
      mask_suitability(Suitability[[sp]], buf)
    }
    names(r) <- sp
    r
  })

  do.call(c, masked)
}

#' Mask Every Scenario's Suitability Stack by Per-Species Buffers
#'
#' Applies [mask_suitability_stack()] to every member of a scenario
#' `SpatRasterCollection` (e.g. [PredictScenarios()]'s output), reusing the
#' same `buffer` for each -- buffers don't change per scenario.
#'
#' @param Suitability_scenarios A `SpatRasterCollection`, one multi-species
#'   suitability stack per scenario.
#' @param buffer A list of per-species dispersal-buffer `SpatVector`s.
#'
#' @return A `SpatRasterCollection`, one masked stack per scenario.
#'
#' @importFrom terra sprc
#' @importFrom purrr map
#'
#' @export
mask_suitability_scenarios <- function(Suitability_scenarios, buffer) {
  results <- purrr::map(as.list(Suitability_scenarios), mask_suitability_stack, buffer = buffer)
  terra::sprc(results)
}

#' Threshold Every Scenario's Masked Suitability into Binary Presence
#'
#' Applies [threshold_suitability()] to every member of a scenario
#' `SpatRasterCollection`, reusing the same `Thresholds` for each --
#' thresholds are calibrated from real occurrence data, not from any one
#' scenario.
#'
#' @param Masked_scenarios A `SpatRasterCollection`, one masked
#'   multi-species suitability stack per scenario, as produced by
#'   [mask_suitability_scenarios()].
#' @param Thresholds,threshold See [threshold_suitability()].
#'
#' @return A `SpatRasterCollection`, one binary multi-species stack per
#'   scenario.
#'
#' @importFrom terra sprc
#' @importFrom purrr map
#'
#' @export
threshold_suitability_scenarios <- function(Masked_scenarios, Thresholds, threshold = "Thres_95") {
  results <- purrr::map(
    as.list(Masked_scenarios), threshold_suitability,
    Thresholds = Thresholds, threshold = threshold
  )
  terra::sprc(results)
}

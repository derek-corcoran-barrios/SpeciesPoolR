#' Calculate Baseline Range-Size Rarity Weights
#'
#' Calculates an inverse range-size weight for every species in a binary
#' presence/absence raster stack. Each layer must represent one species and
#' contain 1 for predicted presence, 0 for predicted absence, and optionally
#' `NA` outside the area evaluated for that species.
#'
#' For the default `unit = "cells"`, the range size of species \eqn{i} is the
#' number of raster cells in which it is predicted present:
#'
#' \deqn{A_i = \sum_j B_{ij}}
#'
#' and its range-size rarity weight is:
#'
#' \deqn{w_i = 1 / A_i}
#'
#' This has a useful interpretation for equal-area rasters: each species
#' contributes a total weight of 1 across its entire predicted baseline range,
#' so narrow-ranging species concentrate their contribution into fewer cells.
#'
#' Species with no predicted baseline cells receive a weight of 0. This avoids
#' infinite weights and, importantly, prevents a species absent from the
#' baseline from receiving an arbitrarily large rarity value if a scenario
#' creates suitable habitat for it.
#'
#' The weights should normally be calculated ONCE from the baseline binary
#' rasters and then reused unchanged for all scenarios. Recalculating weights
#' independently for each scenario would make successful range expansion reduce
#' a species' rarity weight and would therefore partly penalize a scenario for
#' improving habitat.
#'
#' @param Binary A multi-layer binary (0/1) `SpatRaster`, one layer per
#'   species, or a list of single-layer `SpatRaster` objects such as a branched
#'   `Binary_baseline` target.
#' @param unit Character. Either `"cells"` (default) or `"km2"`.
#'   `"cells"` is fastest and is recommended when all raster cells have the
#'   same area. `"km2"` calculates the predicted occupied area using
#'   [terra::cellSize()].
#'
#' @return A data frame with one row per raster layer and columns:
#'   `species`, `range_size`, and `weight`.
#'
#' @importFrom terra global cellSize
#'
#' @export
calc_range_weights <- function(Binary, unit = c("cells", "km2")) {
  unit <- match.arg(unit)

  if (is.list(Binary)) {
    Binary <- do.call(c, Binary)
  }

  if (!inherits(Binary, "SpatRaster")) {
    stop("`Binary` must be a SpatRaster or a list of SpatRaster objects.")
  }

  if (terra::nlyr(Binary) == 0L) {
    stop("`Binary` contains no raster layers.")
  }

  species <- normalize_species_name(names(Binary))

  if (anyDuplicated(species)) {
    duplicated_species <- unique(species[duplicated(species)])
    stop(
      "Species names are not unique after normalization: ",
      paste(duplicated_species, collapse = ", ")
    )
  }

  if (unit == "cells") {
    range_size <- terra::global(Binary, fun = "sum", na.rm = TRUE)[, 1]
  } else {
    cell_area <- terra::cellSize(Binary[[1]], unit = "km")
    range_size <- terra::global(
      Binary * cell_area,
      fun = "sum",
      na.rm = TRUE
    )[, 1]
  }

  range_size <- as.numeric(range_size)

  weight <- ifelse(
    is.finite(range_size) & range_size > 0,
    1 / range_size,
    0
  )

  out <- data.frame(
    species = species,
    range_size = range_size,
    weight = weight,
    stringsAsFactors = FALSE
  )

  attr(out, "range_unit") <- unit
  out
}


#' Calculate Range-Size Rarity / Irreplaceability
#'
#' Calculates a cell-level range-size rarity score as the sum of the baseline
#' inverse-range weights of all species predicted present in each cell:
#'
#' \deqn{RSR_j = \sum_i B_{ij} w_i}
#'
#' where \eqn{B_{ij}} is 1 when species \eqn{i} is predicted present in cell
#' \eqn{j}, and \eqn{w_i = 1/A_i} is the inverse baseline range size produced
#' by [calc_range_weights()].
#'
#' This is also commonly interpreted as weighted endemism or a simple
#' irreplaceability score. Cells containing geographically restricted species
#' receive larger values than cells containing only widespread species.
#'
#' Species weights are matched to raster layers BY NAME, not by position.
#' Species missing from the weight table cause an error. Species with baseline
#' weight 0 contribute 0 to the score.
#'
#' @param Binary A multi-layer binary (0/1) `SpatRaster`, one layer per
#'   species, or a list of single-layer `SpatRaster` objects.
#' @param Weights A data frame produced by [calc_range_weights()] containing
#'   columns `species` and `weight`.
#' @param name Character name for the output raster layer.
#'   Default `"RangeRarity"`.
#'
#' @return A single-layer `SpatRaster` containing range-size rarity values.
#'   Cells that are `NA` for every species remain `NA`.
#'
#' @importFrom terra app allNA ifel nlyr
#'
#' @export
calc_range_rarity <- function(
    Binary,
    Weights,
    name = "RangeRarity"
) {
  if (is.list(Binary)) {
    Binary <- do.call(c, Binary)
  }

  if (!inherits(Binary, "SpatRaster")) {
    stop("`Binary` must be a SpatRaster or a list of SpatRaster objects.")
  }

  required_columns <- c("species", "weight")
  if (!all(required_columns %in% names(Weights))) {
    stop(
      "`Weights` must contain columns: ",
      paste(required_columns, collapse = ", "),
      "."
    )
  }

  raster_species <- normalize_species_name(names(Binary))
  weight_species <- normalize_species_name(Weights$species)

  if (anyDuplicated(raster_species)) {
    stop("Raster layer names are not unique after species-name normalization.")
  }

  if (anyDuplicated(weight_species)) {
    stop("`Weights$species` is not unique after species-name normalization.")
  }

  idx <- match(raster_species, weight_species)

  if (anyNA(idx)) {
    missing_species <- raster_species[is.na(idx)]
    stop(
      "No range-size weight was found for: ",
      paste(missing_species, collapse = ", ")
    )
  }

  w <- as.numeric(Weights$weight[idx])

  if (any(!is.finite(w))) {
    stop("All range-size weights must be finite numeric values.")
  }

  # Multiply each species layer by its baseline inverse-range weight.
  weighted <- Binary * w

  # Built-in terra summaries operate block-wise and avoid converting the
  # complete species x cells raster stack into an in-memory R matrix.
  out <- terra::app(weighted, fun = "sum", na.rm = TRUE)

  # `sum(..., na.rm = TRUE)` returns 0 where every layer is NA. Restore
  # those cells to NA explicitly. terra::allNA() is implemented for
  # SpatRaster objects and avoids constructing a species x cells R matrix.
  all_na <- terra::allNA(Binary)
  out <- terra::ifel(all_na, NA, out)

  names(out) <- name
  out
}


#' Calculate Range-Size Rarity Across Scenarios
#'
#' Applies [calc_range_rarity()] to every scenario in a
#' `SpatRasterCollection`, using ONE fixed set of baseline range-size weights.
#'
#' Reusing baseline weights is intentional. Species retain the same rarity
#' value under every scenario, so a scenario is rewarded when it creates or
#' retains suitable habitat for species that were geographically restricted
#' under the baseline.
#'
#' @param Binary_scenarios A `SpatRasterCollection` containing one
#'   multi-species binary raster stack per scenario.
#' @param Weights Baseline range-size weights produced by
#'   [calc_range_weights()].
#' @param names Character vector of scenario names in the same order as
#'   `Binary_scenarios`.
#'
#' @return A multi-layer `SpatRaster`, one range-size rarity layer per
#'   scenario, named `"RangeRarity_<scenario>"`.
#'
#' @importFrom terra rast
#' @importFrom purrr map2
#'
#' @export
calc_range_rarity_scenarios <- function(
    Binary_scenarios,
    Weights,
    names
) {
  scenario_list <- as.list(Binary_scenarios)

  if (length(scenario_list) != length(names)) {
    stop(
      "`names` must have the same length as `Binary_scenarios`."
    )
  }

  results <- purrr::map2(
    scenario_list,
    names,
    function(stack, nm) {
      calc_range_rarity(
        stack,
        Weights,
        name = paste0("RangeRarity_", nm)
      )
    }
  )

  terra::rast(results)
}

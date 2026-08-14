#' Normalize Species Names for Matching Across Sources
#'
#' Different sources in this pipeline write species names differently --
#' `"Anthyllis vulneraria"` (spaces, from GBIF/taxonomic data), vs. raster
#' layer names that can end up as `"Anthyllis.vulneraria"` (dots, from R's
#' `make.names()`-style handling when layers get combined), vs. phylogeny
#' tip labels that are conventionally `"Anthyllis_vulneraria"`
#' (underscores). Collapsing all of these to one common form before
#' matching avoids silent mismatches (exactly the bug this pipeline hit
#' once already with branch-name mangling).
#'
#' @param x A character vector of species names.
#' @return `x` with any run of non-alphanumeric characters collapsed to a
#'   single underscore.
#' @keywords internal
normalize_species_name <- function(x) {
  gsub("[^A-Za-z0-9]+", "_", x)
}

#' Compute Species Richness
#'
#' Sums a multi-layer binary presence/absence stack across species, cell by
#' cell.
#'
#' @param Binary A multi-layer binary (0/1) `SpatRaster`, one layer per
#'   species (as produced by [threshold_suitability()]), or a list of
#'   single-layer branches to be combined first (e.g. a branched
#'   `Binary_baseline` referenced as a whole).
#' @param name Name for the resulting layer. Default `"Richness"`.
#'
#' @return A single-layer `SpatRaster` of species richness (count of
#'   species meeting the presence criteria per cell). `NA` is preserved
#'   wherever every input layer was `NA`.
#'
#' @importFrom terra app
#'
#' @export
calc_richness <- function(Binary, name = "Richness") {
  if (is.list(Binary)) Binary <- do.call(c, Binary)
  richness <- terra::app(Binary, fun = sum)
  names(richness) <- name
  richness
}

#' Compute Richness Across a Collection of Scenarios
#'
#' Applies [calc_richness()] to every member of a scenario
#' `SpatRasterCollection`.
#'
#' @param Binary_scenarios A `SpatRasterCollection`, one binary
#'   multi-species stack per scenario.
#' @param names Character vector of scenario names, in the same order as
#'   `Binary_scenarios` (e.g. `Scenario_specs$scenario`).
#'
#' @return A multi-layer `SpatRaster`, one richness layer per scenario,
#'   named `"Richness_<scenario>"`.
#'
#' @importFrom terra rast
#' @importFrom purrr map2
#'
#' @export
calc_richness_scenarios <- function(Binary_scenarios, names) {
  scenario_list <- as.list(Binary_scenarios)
  richness_list <- purrr::map2(
    scenario_list, names,
    \(stack, nm) calc_richness(stack, name = paste0("Richness_", nm))
  )
  terra::rast(richness_list)
}

#' Calculate Rarity Weights for Species
#'
#' Calculates rarity weights from species occurrence counts using
#' `Rarity::rWeights()`. Purely tabular (no geometry involved), unchanged
#' from the pre-`geotargets` version of this package.
#'
#' @param df A data frame with columns `species` and `N` (occurrence
#'   counts), e.g. [count_presences()]'s output.
#'
#' @return A data.frame (from `Rarity::rWeights()`: columns `Q`, `R`, `W`,
#'   `cut.off`), with species as row names -- not a named vector.
#'
#' @importFrom Rarity rWeights
#'
#' @export
calc_rarity_weight <- function(df) {
  occ <- df$N
  names(occ) <- df$species

  Rarity::rWeights(occ)
}

#' Calculate the Index of Relative Rarity, Cell by Cell
#'
#' Computes `Rarity::Irr()` once for every non-`NA` cell in a binary
#' presence/absence stack, rather than the pre-`geotargets` version's
#' per-land-use-category loop over a long-format table -- same underlying
#' calculation, done directly on the raster.
#'
#' @param Binary A multi-layer binary (0/1) `SpatRaster`, one layer per
#'   species, layer-named by species.
#' @param RW Rarity weights, as produced by [calc_rarity_weight()] -- a
#'   data.frame with species as row names (not `names()`), per how
#'   `Rarity::rWeights()`/`Rarity::Irr()` expect it.
#'
#' @return A single-layer `SpatRaster` of Irr values, `NA` wherever
#'   `Binary` was `NA`.
#'
#' @importFrom terra as.data.frame rast values
#' @importFrom Rarity Irr
#'
#' @export
calc_rarity_raster <- function(Binary, RW) {
  vals <- terra::as.data.frame(Binary, cells = TRUE, na.rm = TRUE)

  out <- terra::rast(Binary, nlyrs = 1)
  terra::values(out) <- NA_real_
  names(out) <- "Rarity"

  if (nrow(vals) == 0) return(out)

  cell_ids <- vals$cell
  mat <- as.matrix(vals[, setdiff(names(vals), "cell"), drop = FALSE])
  colnames(mat) <- normalize_species_name(colnames(mat))
  mat <- t(mat) # Irr() wants species (rows) x sites (columns)

  rownames(RW) <- normalize_species_name(rownames(RW))

  Irr_result <- as.data.frame(Rarity::Irr(assemblages = mat, W = RW))

  out[cell_ids] <- Irr_result$Irr
  out
}

#' Calculate Rarity Across a Collection of Scenarios
#'
#' Applies [calc_rarity_raster()] to every member of a scenario
#' `SpatRasterCollection`, reusing the same rarity weights for each --
#' weights are calibrated from real occurrence counts, not from any one
#' scenario.
#'
#' @param Binary_scenarios A `SpatRasterCollection`, one binary
#'   multi-species stack per scenario.
#' @param RW Rarity weights, as produced by [calc_rarity_weight()].
#' @param names Character vector of scenario names, in the same order as
#'   `Binary_scenarios`.
#'
#' @return A multi-layer `SpatRaster`, one rarity layer per scenario, named
#'   `"Rarity_<scenario>"`.
#'
#' @importFrom terra rast
#' @importFrom purrr map2
#'
#' @export
calc_rarity_scenarios <- function(Binary_scenarios, RW, names) {
  scenario_list <- as.list(Binary_scenarios)
  results <- purrr::map2(scenario_list, names, function(stack, nm) {
    r <- calc_rarity_raster(stack, RW)
    names(r) <- paste0("Rarity_", nm)
    r
  })
  terra::rast(results)
}

#' Generate a Phylogenetic Tree for a Species List
#'
#' Builds a phylogenetic tree via `V.PhyloMaker::phylo.maker()`, using the
#' vascular-plant megaphylogeny -- so, as in the pre-`geotargets` version,
#' this only applies to species pools of plants. Unchanged: purely
#' tabular input, no geometry involved.
#'
#' @param DF A data frame with columns `species`, `genus`, and `family`.
#'
#' @return A phylogenetic tree object from `V.PhyloMaker::phylo.maker()`.
#'
#' @importFrom dplyr select distinct
#' @importFrom V.PhyloMaker phylo.maker
#'
#' @export
generate_tree <- function(DF) {
  species <- genus <- family <- NULL

  DF |>
    dplyr::select(species, genus, family) |>
    dplyr::distinct() |>
    V.PhyloMaker::phylo.maker(tree = V.PhyloMaker::GBOTB.extended, nodes = V.PhyloMaker::nodes.info.1)
}

#' Calculate Phylogenetic Diversity, Cell by Cell
#'
#' Computes `picante::pd()` once for every non-`NA` cell in a binary
#' presence/absence stack, rather than the pre-`geotargets` version's
#' per-land-use-category loop over a long-format table.
#'
#' @param Binary A multi-layer binary (0/1) `SpatRaster`, one layer per
#'   species, layer-named by species.
#' @param Tree A phylogenetic tree, as produced by [generate_tree()].
#'   Uses the `scenario.3` tree, matching the pre-`geotargets` version.
#'
#' @return A single-layer `SpatRaster` of PD values, `NA` wherever `Binary`
#'   was `NA`. Cells with no species matching the tree get PD 0.
#'
#' @importFrom terra as.data.frame rast values
#' @importFrom picante pd
#'
#' @export
calc_pd_raster <- function(Binary, Tree) {
  vals <- terra::as.data.frame(Binary, cells = TRUE, na.rm = TRUE)

  out <- terra::rast(Binary, nlyrs = 1)
  terra::values(out) <- NA_real_
  names(out) <- "PD"

  if (nrow(vals) == 0) return(out)

  cell_ids <- vals$cell
  mat <- as.matrix(vals[, setdiff(names(vals), "cell"), drop = FALSE])
  colnames(mat) <- normalize_species_name(colnames(mat))

  tip_labels <- normalize_species_name(Tree$scenario.3$tip.label)
  keep <- intersect(colnames(mat), tip_labels)

  if (length(keep) == 0) {
    stop("None of the species in Binary match the tree's tip labels.")
  }
  mat <- mat[, keep, drop = FALSE]

  PD_result <- picante::pd(samp = mat, tree = Tree$scenario.3, include.root = FALSE)
  PD_result$PD[is.na(PD_result$PD)] <- 0

  out[cell_ids] <- PD_result$PD
  out
}

#' Calculate Phylogenetic Diversity Across a Collection of Scenarios
#'
#' Applies [calc_pd_raster()] to every member of a scenario
#' `SpatRasterCollection`, reusing the same tree for each -- the
#' phylogeny doesn't depend on land use.
#'
#' @param Binary_scenarios A `SpatRasterCollection`, one binary
#'   multi-species stack per scenario.
#' @param Tree A phylogenetic tree, as produced by [generate_tree()].
#' @param names Character vector of scenario names, in the same order as
#'   `Binary_scenarios`.
#'
#' @return A multi-layer `SpatRaster`, one PD layer per scenario, named
#'   `"PD_<scenario>"`.
#'
#' @importFrom terra rast
#' @importFrom purrr map2
#'
#' @export
calc_pd_scenarios <- function(Binary_scenarios, Tree, names) {
  scenario_list <- as.list(Binary_scenarios)
  results <- purrr::map2(scenario_list, names, function(stack, nm) {
    r <- calc_pd_raster(stack, Tree)
    names(r) <- paste0("PD_", nm)
    r
  })
  terra::rast(results)
}

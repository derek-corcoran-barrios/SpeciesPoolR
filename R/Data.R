#' Species Richness and Rarity Data
#'
#' A dataset containing species richness results along with associated Index of Relative Rarity (Irr) and land use information.
#'
#' @format A data.table and data.frame with 26,433 rows and 4 variables:
#' \describe{
#'   \item{cell}{Numeric. The cell index in the raster.}
#'   \item{Irr}{Numeric. The Index of Relative Rarity calculated with the `rarity` R package.}
#'   \item{Richness}{Integer. The species richness value for the cell.}
#'   \item{Landuse}{Character. The type of land use associated with the cell (e.g., "ForestDryPoor").}
#' }
#' @examples
#' \dontrun{
#'   data(Richness_Rar)
#'   head(Richness_Rar)
#' }
"Richness_Rar"


#' Species Richness and Phylogenetic Diversity Data
#'
#' A dataset containing species richness and phylogenetic diversity results along with associated land use information.
#'
#' @format A data.table and data.frame with 26,433 rows and 4 variables:
#' \describe{
#'   \item{PD}{Numeric. The Phylogenetic Diversity calculated with the `picante` R package.}
#'   \item{SR}{Integer. The Species Richness calculated with the `picante` R package.}
#'   \item{cell}{Integer. The cell index in the raster.}
#'   \item{Landuse}{Character. The type of land use associated with the cell (e.g., "ForestDryPoor").}
#' }
#' @examples
#' \dontrun{
#'   data(Richness_PD)
#'   head(Richness_PD)
#' }
"Richness_PD"

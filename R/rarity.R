#' Calculate Rarity Weights for Species
#'
#' This function calculates rarity weights for a given set of species occurrences using the `rWeights` function from the `Rarity` package. The weights are based on the species' occurrences and are used to assess their rarity within the dataset.
#'
#' @param df A data frame containing at least two columns: `species` and `N`, where `species` represents the species names and `N` represents the number of occurrences for each species.
#'
#' @return A data frame with rarity weights for each species, calculated using the `rWeights` function.
#'
#' @importFrom Rarity rWeights
#'
#' @examples
#' # Example usage:
#' species_data <- data.frame(
#'   species = c("Species1", "Species2", "Species3"),
#'   N = c(10, 5, 1)
#' )
#' rarity_weights <- calc_rarity_weight(species_data)
#' print(rarity_weights)
#'
#' @export
calc_rarity_weight <- function(df) {

  occ <- df$N
  names(occ) <- df$species

  rarity.weights <- Rarity::rWeights(occ)
  return(rarity.weights)
}


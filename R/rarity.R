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
#' @export
calc_rarity_weight <- function(df) {
  occ <- df$N
  names(occ) <- df$species

  rarity.weights <- Rarity::rWeights(occ)
  return(rarity.weights)
}


#' Calculate the Index of Relative Rarity for Species Assemblages
#'
#' This function calculates the Index of Relative Rarity (Irr) for species assemblages based on their occurrences in specific land-use types. It uses the rarity weights calculated from the `calc_rarity_weight` function.
#'
#' @param Fin A data frame of final species presences, containing columns for `cell`, `species`, and `Landuse`.
#' @param RW A data frame of rarity weights, as calculated by the `calc_rarity_weight` function.
#'
#' @return A data frame containing the Index of Relative Rarity (Irr) for each cell, along with the corresponding land-use type.
#'
#' @importFrom data.table as.data.table dcast
#' @importFrom stringr str_replace_all
#' @importFrom tibble column_to_rownames rownames_to_column
#' @importFrom Rarity Irr
#'
#' @export

calc_rarity <- function(Fin, RW) {
  Pres <- species <- cell <- Landuse <- NULL
  Fin <- as.data.table(Fin)
  unique_landuse <- unique(Fin$Landuse)

  result_list <- list()  # To store the results for each land-use type

  for (landuse in unique_landuse) {
    # Subset data for the current land-use type
    Fin_subset <- Fin[Landuse == landuse]

    # Continue with the original calculations
    Fin_subset[, Pres := 1]
    Fin_subset[, species := stringr::str_replace_all(species, " ", "_")]
    Fin_subset <- Fin_subset[cell > 0 & !is.na(cell)]

    Fin2 <- dcast(Fin_subset, cell ~ species, value.var = "Pres", fill = 0)
    Fin2 <- tibble::column_to_rownames(as.data.frame(Fin2), "cell")
    colnames(Fin2) <- stringr::str_replace_all(colnames(Fin2), "[^\\p{L}\\p{N}\\s]", " ")
    Fin2 <- t(Fin2)
    rownames(RW) <- stringr::str_replace_all(rownames(RW), "[^\\p{L}\\p{N}\\s]", " ")

    # Calculate rarity using the Rarity package's Irr function
    Rarity <- Rarity::Irr(assemblages = Fin2, W = RW)
    Rarity <- as.data.frame(Rarity)
    Rarity$Landuse <- landuse  # Assign the land-use type

    # Add cell column back
    Rarity <- tibble::rownames_to_column(Rarity, var = "cell")

    # Store the result for this land-use type
    result_list[[landuse]] <- Rarity
  }

  # Combine all the results into one data frame
  final_result <- do.call(rbind, result_list)

  return(final_result)
}

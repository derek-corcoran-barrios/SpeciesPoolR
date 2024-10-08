#' Generate Phylogenetic Tree
#'
#' This function takes a CSV file path, reads the data, and generates a phylogenetic tree using the `V.PhyloMaker` package.
#'
#' @param DF A data.frame. The data.frame must contain columns named `species`, `genus`, and `family`.
#' @return A phylogenetic tree object generated by the `V.PhyloMaker::phylo.maker` function.
#' @importFrom dplyr select distinct
#' @importFrom V.PhyloMaker phylo.maker
#' @export
generate_tree <- function(DF){

  species <- genus <- family <- NULL

  Tree <- DF |>
    dplyr::select(species, genus, family) |>
    dplyr::distinct() |>
    V.PhyloMaker::phylo.maker(tree = V.PhyloMaker::GBOTB.extended, nodes = V.PhyloMaker::nodes.info.1)
  return(Tree)
}

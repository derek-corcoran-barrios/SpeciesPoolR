#' Run the SpeciesPoolR Workflow
#'
#' This function sets up and runs a `targets` workflow using the functions provided in the
#' `SpeciesPoolR` package. The workflow includes steps for cleaning species data, counting
#' species presences, filtering data, and generating buffers for spatial analysis.
#'
#' @param workers Number of parallel workers to use in the `crew` controller. Default is 4.
#' @param error Handling for errors in outdated targets. Default is "null".
#' @param file_path Path to the Excel or csv file containing the data.
#' @param landuse_suitability Path to the land use suitability raster file.
#' @param landuse_tiff Path to the land use TIFF file.
#' @param n Minimum number of occurrences for species filtering. Default is 5.
#' @return Executes the `targets` pipeline.
#' @importFrom crew crew_controller
#' @importFrom targets tar_option_set tar_target
#' @export
run_workflow <- function(workers = 4,
                         error = "null",
                         file_path,
                         landuse_suitability,
                         landuse_tiff,
                         n = 5) {

  LanduseSuitability <- LandUseTiff <- data <- Clean <- clean_species <- NULL

  # Set tar_option_set for the workflow
  targets::tar_option_set(
    packages = c("SpeciesPoolR"),
    controller = crew::crew_controller(workers = workers),
    error = error
  )

  # Define the targets pipeline
  targets <- list(
    targets::tar_target(LanduseSuitability, landuse_suitability, format = "file"),
    targets::tar_target(LandUseTiff, landuse_tiff, format = "file"),
    targets::tar_target(file, command = file_path, format = "file"),
    targets::tar_target(data, get_data(file)),
    targets::tar_target(Clean, clean_species(data))
  )

  # Run the workflow
  targets::tar_make(targets)
}

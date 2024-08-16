#' Run the SpeciesPoolR Workflow
#'
#' This function sets up and runs a `targets` workflow using the functions provided in the
#' `SpeciesPoolR` package. The workflow includes steps for cleaning species data, counting
#' species presences, filtering data, and generating buffers for spatial analysis.
#'
#' @param workers Number of parallel workers to use in the `crew` controller. Default is 2.
#' @param error Handling for errors in outdated targets. Default is "null".
#' @param file_path Path to the Excel or csv file containing the data.
#' @return Executes the `targets` pipeline.
#' @importFrom crew crew_controller_local
#' @importFrom targets tar_option_set tar_target tar_script
#' @export
run_workflow <- function(workers = 2,
                         error = "null",
                         file_path) {

  data <- Clean <- clean_species <- NULL

  controller <- substitute(crew::crew_controller_local(workers = workers))
  error_val <- substitute(error)
  file_path_val <- substitute(file_path)

  # Set tar_option_set for the workflow
  targets::tar_script({
    targets::tar_option_set(
      packages = c("SpeciesPoolR"),
      controller = eval(controller),
      error = eval(error_val)
    )

    # Define the targets pipeline
    targets <- list(
      targets::tar_target(file, command = eval(file_path_val), format = "file"),
      targets::tar_target(data, get_data(file)),
      targets::tar_target(Clean, clean_species(data))
    )
  }, ask = FALSE)

  # Run the workflow
  targets::tar_make(targets)
}

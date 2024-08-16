#' Run the SpeciesPoolR Workflow
#'
#' This function sets up and runs a `targets` workflow using the functions provided in the
#' `SpeciesPoolR` package. The workflow includes steps for cleaning species data, counting
#' species presences, filtering data, and generating buffers for spatial analysis.
#'
#' @param workers Number of parallel workers to use in the `crew` controller. Default is 2.
#' @param error Handling for errors in outdated targets. Default is "null".
#' @param file_path Path to the Excel or csv file containing the data.
#' @param filter An optional expression used to filter the resulting `data.frame`. This should be an expression
#' written as if you were using `dplyr::filter()`. The default is NULL, meaning no filtering is applied.
#' @return Executes the `targets` pipeline.
#' @importFrom crew crew_controller_local
#' @importFrom rlang enquo
#' @importFrom targets tar_option_set tar_target tar_helper tar_make
#' @export

run_workflow <- function(workers = 2,
                         error = "null",
                         file_path,
                         filter = NULL
                         ) {

  data <- Clean <- NULL

  # Write the script using tar_helper()
  targets::tar_helper(
    path = "_targets.R",
    code = {

      targets::tar_option_set(
        packages = c("SpeciesPoolR"),
        controller =  crew::crew_controller_local(workers = !!workers),
        error = !!error
      )

      list(
        targets::tar_target(file, command = !!file_path, format = "file"),
        targets::tar_target(data, get_data(file, filter = !!rlang::enquo(filter))),
        targets::tar_target(Clean, SpeciesPoolR::Clean_Taxa(data$Species))
      )
    },
    tidy_eval = TRUE  # This ensures the !! operators work as expected
  )

  # Run the workflow
  targets::tar_make()
}


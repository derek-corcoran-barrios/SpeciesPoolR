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
#' @param country A two-letter country code to define the area of interest for counting species presences. Default is NULL.
#' @param shapefile Path to a shapefile defining the area of interest for counting species presences. Default is NULL.
#' @param plot if TRUE (default) it will run the `targets::tar_visnetwork()` to plot the workflow
#' @return Executes the `targets` pipeline.
#' @importFrom crew crew_controller_local
#' @importFrom rlang enquo
#' @importFrom targets tar_option_set tar_target tar_helper tar_make tar_visnetwork
#' @export

run_workflow <- function(workers = 2,
                         error = "null",
                         file_path,
                         filter = NULL,
                         country = NULL,
                         shapefile = NULL,
                         plot = TRUE) {

  data <- Clean <- Count_Presences <- Presences <- shp <- More_than_zero <- N <- NULL

  # Write the script using tar_helper()
  targets::tar_helper(
    path = "_targets.R",
    code = {

      targets::tar_option_set(
        packages = c("SpeciesPoolR", "data.table"),
        controller = crew::crew_controller_local(workers = !!workers),
        error = !!error
      )

      target_list <- list(
        targets::tar_target(file, command = !!file_path, format = "file"),
        targets::tar_target(data, get_data(file, filter = !!rlang::enquo(filter))),
        targets::tar_target(shp, command = !!shapefile, format = "file"),
        targets::tar_target(Clean, SpeciesPoolR::Clean_Taxa(data$Species)),
        targets::tar_target(Count_Presences,
                            count_presences(Clean, country = !!country, shapefile = shp),
                            pattern = map(Clean)),
        targets::tar_target(More_than_zero, Count_Presences[N > 0,]),
        targets::tar_target(Presences,
                            get_presences(More_than_zero$species, country = !!country,
                                          shapefile = shp),
                            pattern = map(More_than_zero))
        )
    },
    tidy_eval = TRUE  # This ensures the !! operators work as expected
  )

  # Run the workflow
  targets::tar_make()
  if (plot) {
    targets::tar_visnetwork()
  }
}

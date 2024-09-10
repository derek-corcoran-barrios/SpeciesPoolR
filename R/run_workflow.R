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
#' @param rastertemp A file path to the raster file that will be used as a template for rasterizing the buffers.
#' @param rasterLU A file path to the raster file that has the landuses that exist in the area that will be modeled.
#' @param LanduseSuitability	A string representing the file path to the raster file containing land-use binary suitability data.
#' @param dist A numeric value specifying the buffer distance in meters. Default is 500 meters.
#' @param plot if TRUE (default) it will run the `targets::tar_visnetwork()` to plot the workflow
#' @return Executes the `targets` pipeline.
#' @importFrom crew crew_controller_local
#' @importFrom rlang enquo
#' @importFrom targets tar_option_set tar_target tar_helper tar_make tar_visnetwork
#' @export

run_workflow <- function(workers = 2,
                         error = "null",
                         file_path,
                         rastertemp,
                         rasterLU,
                         LanduseSuitability,
                         dist = 500,
                         filter = NULL,
                         country = NULL,
                         shapefile = NULL,
                         plot = TRUE) {

  Clean <- Count_Presences <- Final_Presences <- Landuse <- Landuses <- Landusesuitability <- Long_LU_table <- LookUpTable <- ModelAndPredict <- More_than_zero <- N <- PhyloDiversity <- Phylo_Tree <- Presences <- Raster <- Thresholds <- buffer <- data <- export_presences <- output_Rarity <- rarity <- rarity_weight <- shp <- species <- unique_habitats <- unique_species <- NULL

  # Write the script using tar_helper()
  targets::tar_helper(
    path = "_targets.R",
    code = {

      targets::tar_option_set(
        packages = c("SpeciesPoolR", "data.table"),
        controller = crew::crew_controller_local(workers = !!workers),
        error = !!error
      )

      list(
        targets::tar_target(file, command = !!file_path, format = "file"),
        targets::tar_target(data, get_data(file, filter = !!rlang::enquo(filter))),
        targets::tar_target(shp, command = !!shapefile, format = "file"),
        targets::tar_target(Raster, command = !!rastertemp, format = "file"),
        targets::tar_target(Landuses, command = !!rasterLU, format = "file"),
        targets::tar_target(Landusesuitability, !!LanduseSuitability,format = "file"),
        targets::tar_target(Clean, SpeciesPoolR::Clean_Taxa(data$Species)),
        targets::tar_target(Count_Presences,
                            count_presences(Clean, country = !!country, shapefile = shp),
                            pattern = map(Clean)),
        targets::tar_target(More_than_zero, Count_Presences[N > 0,,
                                                            by = species,
                                                            sum(N)]),
        targets::tar_target(Presences,
                            get_presences(More_than_zero$species, country = !!country,
                                          shapefile = shp),
                            pattern = map(More_than_zero)),
        targets::tar_target(buffer, make_buffer_rasterized(DT = Presences, file = Raster, dist = !!dist),
                   pattern = map(Presences)),
        targets::tar_target(ModelAndPredict, ModelAndPredictFunc(Presences, file = Landuses), pattern = map(Presences)),
        targets::tar_target(Thresholds, create_thresholds(Model = ModelAndPredict, reference = Presences, file = Landuses)),
        targets::tar_target(LookUpTable, Generate_Lookup(Model = ModelAndPredict, Thresholds = Thresholds)),
        targets::tar_target(Long_LU_table, generate_long_landuse_table(path = Landusesuitability)),
        targets::tar_target(Final_Presences, make_final_presences(Long_LU_table,
                                                                  buffer, LookUpTable), pattern = map(buffer)),
        targets::tar_target(
          unique_species,
          unique(Final_Presences$species)
        ),
        targets::tar_target(
          unique_habitats,
          unique(Final_Presences$Landuse)
        ),
        targets::tar_target(
          export_presences,
          export_final_presences(Final_Presences[species == unique_species, ], folder = "Field_Final_Presences"),
          pattern = map(unique_species),
          format = "file"
        ),
        targets::tar_target(Phylo_Tree, generate_tree(More_than_zero)),
        targets::tar_target(PhyloDiversity,
                   calc_pd(Final_Presences[Landuse == unique_habitats,], Phylo_Tree),
                   pattern = map(unique_habitats)),
        targets::tar_target(rarity_weight, calc_rarity_weight(More_than_zero)),
        targets::tar_target(rarity, calc_rarity(Final_Presences[Landuse == unique_habitats,], rarity_weight),
                            pattern = map(unique_habitats)),
        targets::tar_target(name = output_Rarity,
                   command = export_rarity(Results = rarity, path = Raster),
                   map(rarity),
                   format = "file")
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

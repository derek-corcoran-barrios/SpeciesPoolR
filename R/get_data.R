#' Read in Data from a CSV or XLSX File
#'
#' This function reads in data from a CSV or XLSX file. The file must contain a "Species" column.
#' You can optionally apply a filter expression to the dataset before returning it.
#' The function returns a `data.frame` with the filtered results for further processing in the pipeline.
#'
#' @param file A string specifying the path to the CSV or XLSX file to read. The file must contain a "Species" column.
#' @param filter An optional expression used to filter the resulting `data.frame`. This should be an expression
#' written as if you were using `dplyr::filter()`. The default is NULL, meaning no filtering is applied.
#' @return A `data.frame` containing the data read from the file, optionally filtered.
#'
#' @importFrom readr read_csv
#' @importFrom readxl read_xlsx
#' @importFrom dplyr filter
#'
#' @examples
#' \dontrun{
#' # Read in data without filtering
#' f <- system.file("ex/Species_List.csv", package="SpeciesPoolR")
#' data <- get_data(f)
#'
#' # Read in data and filter for Plantae kingdom and certain taxon ranges
#' filtered_data <- get_data(
#'   file = f,
#'   filter = quote(
#'    Kingdom == "Plantae" &
#'    Class == "Magnoliopsida"
#'   )
#' )
#' }
#' @export

get_data <- function(file, filter = NULL) {
  file_ext <- tools::file_ext(file)

  if(file_ext == "csv"){
    Data <- readr::read_csv(file)
  } else if (file_ext == "xlsx"){
    Data <- readxl::read_xlsx(file)
  } else {
    stop("Unsupported file type. Please provide a .csv or .xlsx file.")
  }

  if (!is.null(filter)) {
    Data <- dplyr::filter(Data, !!filter)
  }

  return(Data)
}

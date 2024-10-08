% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/generate_landuse_table.R
\name{generate_landuse_table}
\alias{generate_landuse_table}
\title{Generate a Land-Use Suitability Table}
\usage{
generate_landuse_table(path)
}
\arguments{
\item{path}{A string representing the file path to the raster file containing land-use suitability data.}
}
\value{
A data frame with the raster cells that have a suitability value of 1 in at least one of the land-use categories. The data frame includes the \code{cell} identifier and the corresponding suitability values for each land-use category.
}
\description{
This function takes the path to a raster file containing land-use suitability values and converts it to a data frame. It filters the data to include only the cells that have a value of 1 in at least one of the land-use categories, indicating suitability.
}
\examples{
# Get path for habitat suitability raster
HabSut <- system.file("ex/HabSut.tif", package = "SpeciesPoolR")

# Use the function to get the data frame
generate_landuse_table(path = HabSut)

}

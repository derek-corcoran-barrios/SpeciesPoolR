# Get Landuse Presences

This function reads and combines species presence data from multiple
files within a specified folder for a given land use type.

## Usage

``` r
GetLandusePresences(folder, Landuse)
```

## Arguments

- folder:

  A character string specifying the path to the folder containing the
  land use data files.

- Landuse:

  A character string specifying the land use type for which the presence
  data is to be read. The function assumes that the files are located in
  subdirectories named after the land use type within the specified
  folder.

## Value

A data frame containing combined species presence data with columns
`cell`, `species`, and `Landuse`.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Example usage:
  folder <- system.file("ex/", package="SpeciesPoolR")
  list.files(folder, pattern = ".zip")
  Landuse <- "ForestDryPoor"
  presences <- GetLandusePresences(folder, Landuse)
  head(presences)
} # }
```

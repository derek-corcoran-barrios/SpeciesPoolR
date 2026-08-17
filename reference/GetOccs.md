# Get occurrence data

This function uses the `rgbif` package to get occurrence data from the
Global Biodiversity Information Facility (GBIF) API.

## Usage

``` r
GetOccs(
  Species,
  WriteFile = FALSE,
  continent = NULL,
  country = NULL,
  shapefile = NULL,
  limit = 10000,
  Log = FALSE,
  ...
)
```

## Arguments

- Species:

  A vector containing the species to query.

- WriteFile:

  Logical. If `TRUE`, the occurrence data will be written to the `Occs`
  folder. If `FALSE`, the occurrence data will be returned in a list.

- continent:

  what contintent are the occurrences downloaded from

- country:

  A two-letter country code (e.g., "DK" for Denmark) to define the area
  of interest.

- shapefile:

  A shapefile (with lat/long coordinates) defining the area of interest.
  The function will create a minimum bounding rectangle around the
  shapefile to query the species occurrences. Default is `NULL`.

- limit:

  maximum number of occurrences downloaded

- Log:

  Logical. If `TRUE`, a log file will be created with information on the
  progress of the function.

- ...:

  Additional arguments to be passed to the `occ_data` function.

## Value

If `WriteFile = TRUE`, this function does not return anything. If
`WriteFile = FALSE`, a list containing the occurrence data for each
species is returned.

## Examples

``` r
# Get occurrence data for species in FinalSpeciesList
# \donttest{
Presences <- GetOccs(Species = c("Abies concolor", "Canis lupus"), WriteFile = FALSE)
#> Starting species 1
#> 1 of 2 ready! 2026-08-17 11:22:59.118313
#> Starting species 2
#> 2 of 2 ready! 2026-08-17 11:23:15.824548
# }
```

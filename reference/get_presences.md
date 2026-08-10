# Get Occurrence Data for a Given Species List

This function retrieves occurrence data for a given list of species
using the `GetOccs` function. The function is designed to fetch data for
species in Denmark (`country = "DK"`) from 1999 to 2023 and return a
cleaned data frame with selected columns.

## Usage

``` r
get_presences(species, country = NULL, shapefile = NULL, limit = 1e+05)
```

## Arguments

- species:

  A vector of species to use.

- country:

  A two-letter country code (e.g., "DK" for Denmark) to define the area
  of interest.

- shapefile:

  A shapefile (with lat/long coordinates) defining the area of interest.
  The function will create a minimum bounding rectangle around the
  shapefile to query the species occurrences. Default is `NULL`.

- limit:

  maximum number of occurrences downloaded

## Value

A data.frame containing the occurrence data for the specified species,
including the columns: `scientificName`, `decimalLatitude`,
`decimalLongitude`, `family`, `genus`, and `species`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Assume `species_list` is a data.frame with a column named `species`
presences <- get_presences(species_list)
} # }
```

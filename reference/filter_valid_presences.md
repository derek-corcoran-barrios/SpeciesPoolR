# Filter Valid Species Presences

Removes malformed, empty, duplicated, and spatially invalid occurrence
datasets.

## Usage

``` r
filter_valid_presences(x)
```

## Arguments

- x:

  A data frame or list of data frames returned by
  [`get_presences()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/get_presences.md).

## Value

A list of cleaned, non-empty presence data frames.

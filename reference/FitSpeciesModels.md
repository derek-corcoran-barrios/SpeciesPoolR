# Fit Species Distribution Models

Samples the environment at presence and background locations and fits a
model per species, returning the fitted models themselves rather than a
prediction. Keeping fitting separate from prediction means the (often
expensive) fitting step only has to happen once – the same fitted models
can later be predicted onto the current land-use raster and onto any
number of hypothetical scenario rasters, without refitting and without
introducing fresh background-sampling noise into each comparison.

## Usage

``` r
FitSpeciesModels(DF, file, categorical = NULL)
```

## Arguments

- DF:

  A data frame with species presence data: `species`,
  `decimalLongitude`, `decimalLatitude`.

- file:

  A path (or vector of paths) to the environmental raster layer(s) used
  to sample training data. Passed to
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html).

- categorical:

  Optional character vector naming which layer(s) are categorical (e.g.
  land use). See
  [`SampleEnv()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/SampleEnv.md).

## Value

A named list of fitted `maxnet` models, one per species (`NULL` for a
species whose model failed to fit or had no variability to model
against). A plain R list – no `terra` objects – so it stores fine as an
ordinary
[`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html).

# Predict Habitat Suitability From Already-Fitted Models

Predicts habitat suitability across every cell of an environmental
raster stack, using models that were already fit by
[`FitSpeciesModels()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/FitSpeciesModels.md).
Pass the current land-use raster for a baseline prediction, or a
hypothetical scenario raster (same layers, different values) to see how
suitability would shift under that scenario – same models either time,
so any difference reflects the land-use change itself, not modeling
noise.

## Usage

``` r
PredictSuitability(Models, file, categorical = NULL)
```

## Arguments

- Models:

  A named list of fitted `maxnet` models (or `NULL` entries), as
  produced by
  [`FitSpeciesModels()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/FitSpeciesModels.md).

- file:

  A path (or vector of paths) to the raster layer(s) to predict onto, or
  an already-loaded `SpatRaster` (e.g. one scenario pulled out of a
  `SpatRasterCollection`). Must have the same layer names (and, for
  categorical layers, comparable categories) as the raster used to fit
  the models.

- categorical:

  Optional character vector naming which layer(s) are categorical. See
  [`SampleEnv()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/SampleEnv.md).

## Value

A multi-layer `SpatRaster`, one layer per species (named by species),
each cell holding predicted habitat suitability (0-1). A species whose
model was `NULL` gets a layer filled with 0 rather than being dropped,
so the output always has one layer per input model.

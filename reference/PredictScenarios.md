# Predict Suitability Across a Collection of Land-Use Scenarios

Applies
[`PredictSuitability()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/PredictSuitability.md)
to every member of a scenario `SpatRasterCollection`, using the same
already-fitted models each time (see
[`FitSpeciesModels()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/FitSpeciesModels.md))
– no refitting per scenario.

## Usage

``` r
PredictScenarios(Models, Scenarios, categorical = NULL)
```

## Arguments

- Models:

  A named list of fitted `maxnet` models, one per species (the
  *combined* list across all species, not a single-species branch).

- Scenarios:

  A `SpatRasterCollection`, as produced by
  [`load_scenario_collection()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/load_scenario_collection.md)
  or
  [`make_landuse_scenarios()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/make_landuse_scenarios.md).

- categorical:

  Optional character vector naming which layer(s) are categorical. See
  [`SampleEnv()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/SampleEnv.md).

## Value

A `SpatRasterCollection`, one member per scenario, each member a
multi-layer `SpatRaster` (one layer per species) of predicted
suitability – directly comparable to a baseline stack built the same way
from
[`PredictSuitability()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/PredictSuitability.md).

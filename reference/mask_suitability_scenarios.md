# Mask Every Scenario's Suitability Stack by Per-Species Buffers

Applies
[`mask_suitability_stack()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/mask_suitability_stack.md)
to every member of a scenario `SpatRasterCollection` (e.g.
[`PredictScenarios()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/PredictScenarios.md)'s
output), reusing the same `buffer` for each – buffers don't change per
scenario.

## Usage

``` r
mask_suitability_scenarios(Suitability_scenarios, buffer)
```

## Arguments

- Suitability_scenarios:

  A `SpatRasterCollection`, one multi-species suitability stack per
  scenario.

- buffer:

  A list of per-species dispersal-buffer `SpatVector`s.

## Value

A `SpatRasterCollection`, one masked stack per scenario.

# Threshold Every Scenario's Masked Suitability into Binary Presence

Applies
[`threshold_suitability()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/threshold_suitability.md)
to every member of a scenario `SpatRasterCollection`, reusing the same
`Thresholds` for each – thresholds are calibrated from real occurrence
data, not from any one scenario.

## Usage

``` r
threshold_suitability_scenarios(
  Masked_scenarios,
  Thresholds,
  threshold = "Thres_95"
)
```

## Arguments

- Masked_scenarios:

  A `SpatRasterCollection`, one masked multi-species suitability stack
  per scenario, as produced by
  [`mask_suitability_scenarios()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/mask_suitability_scenarios.md).

- Thresholds, threshold:

  See
  [`threshold_suitability()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/threshold_suitability.md).

## Value

A `SpatRasterCollection`, one binary multi-species stack per scenario.

# Compute Richness Across a Collection of Scenarios

Applies
[`calc_richness()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/calc_richness.md)
to every member of a scenario `SpatRasterCollection`.

## Usage

``` r
calc_richness_scenarios(Binary_scenarios, names)
```

## Arguments

- Binary_scenarios:

  A `SpatRasterCollection`, one binary multi-species stack per scenario.

- names:

  Character vector of scenario names, in the same order as
  `Binary_scenarios` (e.g. `Scenario_specs$scenario`).

## Value

A multi-layer `SpatRaster`, one richness layer per scenario, named
`"Richness_<scenario>"`.

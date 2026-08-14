# Calculate Rarity Across a Collection of Scenarios

Applies
[`calc_rarity_raster()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/calc_rarity_raster.md)
to every member of a scenario `SpatRasterCollection`, reusing the same
rarity weights for each – weights are calibrated from real occurrence
counts, not from any one scenario.

## Usage

``` r
calc_rarity_scenarios(Binary_scenarios, RW, names)
```

## Arguments

- Binary_scenarios:

  A `SpatRasterCollection`, one binary multi-species stack per scenario.

- RW:

  Rarity weights, as produced by
  [`calc_rarity_weight()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/calc_rarity_weight.md).

- names:

  Character vector of scenario names, in the same order as
  `Binary_scenarios`.

## Value

A multi-layer `SpatRaster`, one rarity layer per scenario, named
`"Rarity_<scenario>"`.

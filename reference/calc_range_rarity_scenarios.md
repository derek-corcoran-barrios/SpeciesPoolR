# Calculate Range-Size Rarity Across Scenarios

Applies
[`calc_range_rarity()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/calc_range_rarity.md)
to every scenario in a `SpatRasterCollection`, using ONE fixed set of
baseline range-size weights.

## Usage

``` r
calc_range_rarity_scenarios(Binary_scenarios, Weights, names)
```

## Arguments

- Binary_scenarios:

  A `SpatRasterCollection` containing one multi-species binary raster
  stack per scenario.

- Weights:

  Baseline range-size weights produced by
  [`calc_range_weights()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/calc_range_weights.md).

- names:

  Character vector of scenario names in the same order as
  `Binary_scenarios`.

## Value

A multi-layer `SpatRaster`, one range-size rarity layer per scenario,
named `"RangeRarity_<scenario>"`.

## Details

Reusing baseline weights is intentional. Species retain the same rarity
value under every scenario, so a scenario is rewarded when it creates or
retains suitable habitat for species that were geographically restricted
under the baseline.

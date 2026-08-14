# Calculate the Index of Relative Rarity, Cell by Cell

Computes [`Rarity::Irr()`](https://rdrr.io/pkg/Rarity/man/Irr.html) once
for every non-`NA` cell in a binary presence/absence stack, rather than
the pre-`geotargets` version's per-land-use-category loop over a
long-format table – same underlying calculation, done directly on the
raster.

## Usage

``` r
calc_rarity_raster(Binary, RW)
```

## Arguments

- Binary:

  A multi-layer binary (0/1) `SpatRaster`, one layer per species,
  layer-named by species.

- RW:

  Rarity weights, as produced by
  [`calc_rarity_weight()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/calc_rarity_weight.md)
  – a data.frame with species as row names (not
  [`names()`](https://rdrr.io/r/base/names.html)), per how
  [`Rarity::rWeights()`](https://rdrr.io/pkg/Rarity/man/rWeights.html)/[`Rarity::Irr()`](https://rdrr.io/pkg/Rarity/man/Irr.html)
  expect it.

## Value

A single-layer `SpatRaster` of Irr values, `NA` wherever `Binary` was
`NA`.

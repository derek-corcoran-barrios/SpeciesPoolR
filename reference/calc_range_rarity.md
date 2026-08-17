# Calculate Range-Size Rarity / Irreplaceability

Calculates a cell-level range-size rarity score as the sum of the
baseline inverse-range weights of all species predicted present in each
cell:

## Usage

``` r
calc_range_rarity(Binary, Weights, name = "RangeRarity")
```

## Arguments

- Binary:

  A multi-layer binary (0/1) `SpatRaster`, one layer per species, or a
  list of single-layer `SpatRaster` objects.

- Weights:

  A data frame produced by
  [`calc_range_weights()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/calc_range_weights.md)
  containing columns `species` and `weight`.

- name:

  Character name for the output raster layer. Default `"RangeRarity"`.

## Value

A single-layer `SpatRaster` containing range-size rarity values. Cells
that are `NA` for every species remain `NA`.

## Details

\$\$RSR_j = \sum_i B\_{ij} w_i\$\$

where \\B\_{ij}\\ is 1 when species \\i\\ is predicted present in cell
\\j\\, and \\w_i = 1/A_i\\ is the inverse baseline range size produced
by
[`calc_range_weights()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/calc_range_weights.md).

This is also commonly interpreted as weighted endemism or a simple
irreplaceability score. Cells containing geographically restricted
species receive larger values than cells containing only widespread
species.

Species weights are matched to raster layers BY NAME, not by position.
Species missing from the weight table cause an error. Species with
baseline weight 0 contribute 0 to the score.

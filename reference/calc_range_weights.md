# Calculate Baseline Range-Size Rarity Weights

Calculates an inverse range-size weight for every species in a binary
presence/absence raster stack. Each layer must represent one species and
contain 1 for predicted presence, 0 for predicted absence, and
optionally `NA` outside the area evaluated for that species.

## Usage

``` r
calc_range_weights(Binary, unit = c("cells", "km2"))
```

## Arguments

- Binary:

  A multi-layer binary (0/1) `SpatRaster`, one layer per species, or a
  list of single-layer `SpatRaster` objects such as a branched
  `Binary_baseline` target.

- unit:

  Character. Either `"cells"` (default) or `"km2"`. `"cells"` is fastest
  and is recommended when all raster cells have the same area. `"km2"`
  calculates the predicted occupied area using
  [`terra::cellSize()`](https://rspatial.github.io/terra/reference/cellSize.html).

## Value

A data frame with one row per raster layer and columns: `species`,
`range_size`, and `weight`.

## Details

For the default `unit = "cells"`, the range size of species \\i\\ is the
number of raster cells in which it is predicted present:

\$\$A_i = \sum_j B\_{ij}\$\$

and its range-size rarity weight is:

\$\$w_i = 1 / A_i\$\$

This has a useful interpretation for equal-area rasters: each species
contributes a total weight of 1 across its entire predicted baseline
range, so narrow-ranging species concentrate their contribution into
fewer cells.

Species with no predicted baseline cells receive a weight of 0. This
avoids infinite weights and, importantly, prevents a species absent from
the baseline from receiving an arbitrarily large rarity value if a
scenario creates suitable habitat for it.

The weights should normally be calculated ONCE from the baseline binary
rasters and then reused unchanged for all scenarios. Recalculating
weights independently for each scenario would make successful range
expansion reduce a species' rarity weight and would therefore partly
penalize a scenario for improving habitat.

# Calculate Phylogenetic Diversity, Cell by Cell

Computes [`picante::pd()`](https://rdrr.io/pkg/picante/man/pd.html) once
for every non-`NA` cell in a binary presence/absence stack, rather than
the pre-`geotargets` version's per-land-use-category loop over a
long-format table.

## Usage

``` r
calc_pd_raster(Binary, Tree)
```

## Arguments

- Binary:

  A multi-layer binary (0/1) `SpatRaster`, one layer per species,
  layer-named by species.

- Tree:

  A phylogenetic tree, as produced by
  [`generate_tree()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/generate_tree.md).
  Uses the `scenario.3` tree, matching the pre-`geotargets` version.

## Value

A single-layer `SpatRaster` of PD values, `NA` wherever `Binary` was
`NA`. Cells with no species matching the tree get PD 0.

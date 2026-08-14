# Compute Species Richness

Sums a multi-layer binary presence/absence stack across species, cell by
cell.

## Usage

``` r
calc_richness(Binary, name = "Richness")
```

## Arguments

- Binary:

  A multi-layer binary (0/1) `SpatRaster`, one layer per species (as
  produced by
  [`threshold_suitability()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/threshold_suitability.md)),
  or a list of single-layer branches to be combined first (e.g. a
  branched `Binary_baseline` referenced as a whole).

- name:

  Name for the resulting layer. Default `"Richness"`.

## Value

A single-layer `SpatRaster` of species richness (count of species
meeting the presence criteria per cell). `NA` is preserved wherever
every input layer was `NA`.

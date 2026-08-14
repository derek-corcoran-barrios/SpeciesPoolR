# Calculate Phylogenetic Diversity Across a Collection of Scenarios

Applies
[`calc_pd_raster()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/calc_pd_raster.md)
to every member of a scenario `SpatRasterCollection`, reusing the same
tree for each – the phylogeny doesn't depend on land use.

## Usage

``` r
calc_pd_scenarios(Binary_scenarios, Tree, names)
```

## Arguments

- Binary_scenarios:

  A `SpatRasterCollection`, one binary multi-species stack per scenario.

- Tree:

  A phylogenetic tree, as produced by
  [`generate_tree()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/generate_tree.md).

- names:

  Character vector of scenario names, in the same order as
  `Binary_scenarios`.

## Value

A multi-layer `SpatRaster`, one PD layer per scenario, named
`"PD_<scenario>"`.

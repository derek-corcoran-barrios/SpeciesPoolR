# Calculate the Index of Relative Rarity for Species Assemblages

This function calculates the Index of Relative Rarity (Irr) for species
assemblages based on their occurrences in specific land-use types. It
uses the rarity weights calculated from the `calc_rarity_weight`
function.

## Usage

``` r
calc_rarity(Fin, RW)
```

## Arguments

- Fin:

  A data frame of final species presences, containing columns for
  `cell`, `species`, and `Landuse`.

- RW:

  A data frame of rarity weights, as calculated by the
  `calc_rarity_weight` function.

## Value

A data frame containing the Index of Relative Rarity (Irr) for each
cell, along with the corresponding land-use type.

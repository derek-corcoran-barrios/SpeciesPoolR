# Calculate Rarity Weights for Species

Calculates rarity weights from species occurrence counts using
[`Rarity::rWeights()`](https://rdrr.io/pkg/Rarity/man/rWeights.html).
Purely tabular (no geometry involved), unchanged from the
pre-`geotargets` version of this package.

This function calculates rarity weights for a given set of species
occurrences using the `rWeights` function from the `Rarity` package. The
weights are based on the species' occurrences and are used to assess
their rarity within the dataset.

## Usage

``` r
calc_rarity_weight(df)

calc_rarity_weight(df)
```

## Arguments

- df:

  A data frame containing at least two columns: `species` and `N`, where
  `species` represents the species names and `N` represents the number
  of occurrences for each species.

## Value

A data.frame (from
[`Rarity::rWeights()`](https://rdrr.io/pkg/Rarity/man/rWeights.html):
columns `Q`, `R`, `W`, `cut.off`), with species as row names – not a
named vector.

A data frame with rarity weights for each species, calculated using the
`rWeights` function.

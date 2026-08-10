# Calculate Rarity Weights for Species

This function calculates rarity weights for a given set of species
occurrences using the `rWeights` function from the `Rarity` package. The
weights are based on the species' occurrences and are used to assess
their rarity within the dataset.

## Usage

``` r
calc_rarity_weight(df)
```

## Arguments

- df:

  A data frame containing at least two columns: `species` and `N`, where
  `species` represents the species names and `N` represents the number
  of occurrences for each species.

## Value

A data frame with rarity weights for each species, calculated using the
`rWeights` function.

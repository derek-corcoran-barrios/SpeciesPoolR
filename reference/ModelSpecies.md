# Fit a Species Distribution Model from Mixed Environmental Predictors

Fits a MaxEnt model (via `maxnet`) to presence/background data with any
mix of categorical and continuous predictors. Categorical predictors
(factor columns) are dummy-coded; continuous predictors get linear,
quadratic, hinge, and/or product terms, chosen automatically by
[`maxnet::maxnet.formula()`](https://rdrr.io/pkg/maxnet/man/maxnet.html)
based on sample size. No manual design matrix is built – `maxnet`
handles both column types directly from raw data.

## Usage

``` r
ModelSpecies(DF)
```

## Arguments

- DF:

  A data frame with `species`, `Pres` (1 = presence, 0 = background),
  and one or more predictor columns (factor or numeric), as produced by
  [`SampleEnv()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/SampleEnv.md).

## Value

A fitted `maxnet` model object, or `NULL` if fitting failed or the
predictors have no variability to model against.

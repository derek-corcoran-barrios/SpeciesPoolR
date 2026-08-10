# Threshold a Suitability Raster into Binary Presence/Absence

Applies each species' own threshold (from
[`create_thresholds()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/create_thresholds.md))
to its suitability layer, converting continuous suitability into binary
(0/1) presence/absence. Works on a single-species layer or a
multi-species stack alike – matches thresholds to layers by name, so
`Model`'s layer names must be species names, matching
`Thresholds$species`.

## Usage

``` r
threshold_suitability(Model, Thresholds, threshold = "Thres_95")
```

## Arguments

- Model:

  A `SpatRaster` (one or more layers) of predicted suitability, one
  layer per species, layer-named by species.

- Thresholds:

  A data frame with columns `species` and a threshold column (see
  `threshold`), as produced by
  [`create_thresholds()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/create_thresholds.md).

- threshold:

  Which threshold column to use. Default `"Thres_95"`.

## Value

A `SpatRaster`, same shape as `Model`, with each layer recoded to 1
(suitability at or above that species' threshold) or 0 (below it). `NA`
is preserved wherever `Model` was `NA`.

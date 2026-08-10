# Sample Environmental Data for Species Presences or Background Locations

Samples one or more environmental layers (categorical and/or continuous)
either at species presence locations or at background locations drawn
from within an expanded convex hull around those presences.

## Usage

``` r
SampleEnv(DF, file, categorical = NULL, type = "pres", n_bg = 10000)
```

## Arguments

- DF:

  A data frame with columns `species`, `decimalLongitude`, and
  `decimalLatitude`.

- file:

  A path (or vector of paths) to raster file(s) with the environmental
  layers. Passed to
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html),
  which stacks multiple files into one multi-layer `SpatRaster`
  automatically.

- categorical:

  Optional character vector naming which layer(s) in the stack are
  categorical (e.g. land use). Layers not listed here are treated as
  continuous. Layers already stored as factors in the raster itself
  don't need to be listed.

- type:

  Either `"pres"` (sample at presence locations) or `"bg"` (sample
  background locations). Defaults to `"pres"`.

- n_bg:

  Number of background points to sample when `type = "bg"`. Default
  10000.

## Value

A data frame with one column per environmental layer (factor for
categorical layers, numeric for continuous ones), plus `species` and
`Pres` (1 for presence rows, 0 for background rows).

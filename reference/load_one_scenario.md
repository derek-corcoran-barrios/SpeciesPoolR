# Load a Single User-Supplied Scenario Raster

Loads and (optionally) crops/masks one scenario's raster file(s). This
is the per-branch counterpart to
[`load_scenario_collection()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/load_scenario_collection.md)
– use this one (branched with `pattern = map()` over a spec of
scenarios) inside a `targets` pipeline via
[`geotargets::tar_terra_rast()`](https://docs.ropensci.org/geotargets/reference/tar_terra_rast.html),
not `tar_terra_sprc()`: `tar_terra_sprc()` has no `preserve_metadata`
argument, so a categorical layer's real category labels (e.g. "Forest",
"Agriculture") can silently come back as plain numeric codes after the
storage round trip, which is exactly the kind of mismatch that breaks
prediction against a model trained on the real labels.
`tar_terra_rast()` does support `preserve_metadata`, hence loading
scenarios one at a time.

## Usage

``` r
load_one_scenario(path, crop_to = NULL, categorical = NULL)
```

## Arguments

- path:

  A path (or vector of paths, for a scenario made of several layers) for
  one scenario.

- crop_to:

  Optional: a study-area boundary to crop and mask to – a path to a
  vector file, or an already-loaded `SpatVector`.

- categorical:

  Optional character vector naming which layer(s) are categorical (e.g.
  land use). See
  [`SampleEnv()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/SampleEnv.md).

## Value

A single `SpatRaster` for this one scenario.

# Load User-Supplied Scenario Rasters (All at Once, for Interactive Use)

The multi-scenario convenience version of
[`load_one_scenario()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/load_one_scenario.md):
loads every scenario in one call and packages them into a
`SpatRasterCollection` for easy interactive inspection (e.g.
`terra::plot(Scenarios)`). Fine to use this directly outside a pipeline.
Inside a `targets` pipeline, prefer branching with
[`load_one_scenario()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/load_one_scenario.md)
via
[`geotargets::tar_terra_rast()`](https://docs.ropensci.org/geotargets/reference/tar_terra_rast.html)
instead of wrapping this in `tar_terra_sprc()` – see
[`load_one_scenario()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/load_one_scenario.md)
for why.

## Usage

``` r
load_scenario_collection(files, crop_to = NULL, categorical = NULL)
```

## Arguments

- files:

  A named list. Each element is a path (or vector of paths, for a
  scenario made of several layers) for one scenario. The list names
  become the scenario names.

- crop_to:

  Optional: a study-area boundary to crop and mask every scenario to – a
  path to a vector file, or an already-loaded `SpatVector`. Use this
  when your scenario rasters cover a larger area than you actually want
  to study (e.g. all of Europe, but you only care about Denmark).

- categorical:

  Optional character vector naming which layer(s) are categorical (e.g.
  land use). See
  [`SampleEnv()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/SampleEnv.md).

## Value

A `SpatRasterCollection`, one member per scenario, named as in `files`.

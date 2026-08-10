# Build Land-Use Scenario Rasters by Recoding a Category (Convenience Helper)

A convenience for the simple case: mechanically recoding one land-use
category into alternatives on a raster that's already at the right
extent (e.g. testing/demo purposes). For a real analysis with
externally-produced scenarios or a larger source extent that needs
cropping to a study area, use
[`load_scenario_collection()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/load_scenario_collection.md)
instead.

## Usage

``` r
make_landuse_scenarios(file, old_value, new_value, name)
```

## Arguments

- file:

  Path to the baseline land-use raster.

- old_value:

  The raw category code to replace (e.g. Agriculture).

- new_value:

  Numeric vector of replacement category codes, one per scenario.

- name:

  Character vector of scenario names, same length as `new_value`, used
  as each scenario's layer name (so `categorical` matching still works
  downstream).

## Value

A `SpatRasterCollection`, one member per scenario.

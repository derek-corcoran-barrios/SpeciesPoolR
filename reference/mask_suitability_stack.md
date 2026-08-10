# Mask a Multi-Species Suitability Stack by Per-Species Buffers

Applies
[`mask_suitability()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/mask_suitability.md)
species by species to a multi-layer suitability stack (e.g. one
scenario's full stack from
[`PredictScenarios()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/PredictScenarios.md)),
matching each layer to its own buffer via the buffer's own `species`
attribute, not list position or names.

## Usage

``` r
mask_suitability_stack(Suitability, buffer)
```

## Arguments

- Suitability:

  A multi-layer `SpatRaster`, one layer per species, layer-named by
  species.

- buffer:

  A list of per-species dispersal-buffer `SpatVector`s, as produced by
  [`make_buffer()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/make_buffer.md).

## Value

A `SpatRaster`, same shape as `Suitability`, masked per
[`mask_suitability()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/mask_suitability.md).
A species with no buffer gets 0 wherever `Suitability` had data, `NA`
elsewhere.

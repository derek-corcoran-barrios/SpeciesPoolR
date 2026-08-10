# Mask Suitability by a Dispersal Buffer, Preserving True No-Data

Sets suitability to 0 outside the buffer – not `NA` – so that a later
sum across species (for richness) treats "not within reach of this
species" as a real zero rather than a missing value. Genuine no-data
cells (e.g. ocean, outside the study area) stay `NA`:
`terra::mask(..., updatevalue = 0)` alone would zero those out too,
since it only checks whether a cell falls inside the mask geometry, not
whether the input itself was already `NA` there – so this re-masks
against the original `Model` afterward to restore true `NA` wherever the
environment itself had no data.

## Usage

``` r
mask_suitability(Model, Mask)
```

## Arguments

- Model:

  A single-layer `SpatRaster` of predicted suitability for one species
  (as produced by
  [`PredictSuitability()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/PredictSuitability.md)).

- Mask:

  A `SpatVector` – the species' dispersal buffer, as produced by
  [`make_buffer()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/make_buffer.md).

## Value

A `SpatRaster`, same extent and resolution as `Model`: original
suitability values inside the buffer, 0 outside the buffer (wherever
`Model` had real data), `NA` wherever `Model` itself was `NA`.

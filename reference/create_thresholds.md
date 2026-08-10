# Create Prediction Thresholds for Species Distribution Models

Generates presence-prediction thresholds directly from a species'
predicted suitability raster, evaluated at its own known occurrence
points – no re-sampling of the environmental stack needed, since the
suitability raster already encodes the model.

## Usage

``` r
create_thresholds(Model, reference)
```

## Arguments

- Model:

  A multi-layer `SpatRaster` of predicted suitability, one layer per
  species (named by species), as produced by
  [`PredictSuitability()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/PredictSuitability.md).

- reference:

  A data frame of reference occurrence points for threshold calibration,
  with columns `species`, `decimalLongitude`, `decimalLatitude`.

## Value

A data frame with columns `species`, `Thres_99`, `Thres_95`, and
`Thres_90` – the suitability value below which 1%, 5%, and 10% of known
occurrences fall, respectively.

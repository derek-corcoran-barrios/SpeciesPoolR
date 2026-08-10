# Predict a maxnet model onto every non-NA cell of a raster stack

Bypasses
[`terra::predict()`](https://rspatial.github.io/terra/reference/predict.html)'s
internal per-chunk data building, which has known quirks with
`maxnet`/`maxent` models on rasters that contain NA cells
(rspatial/terra#352) and doesn't always propagate factor levels the same
way
[`terra::extract()`](https://rspatial.github.io/terra/reference/extract.html)
does. Instead, this pulls every non-NA cell out as a plain data frame
(factors intact, exactly like
[`SampleEnv()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/SampleEnv.md)
would see them), predicts on that data frame directly with
`predict.maxnet()`, and writes the results back into a template raster
by cell index – so training-space and prediction-space are guaranteed to
be built the same way.

## Usage

``` r
predict_maxnet_raster(Env, Mod, type = "cloglog")
```

## Arguments

- Env:

  The environmental `SpatRaster` stack (already prepared with any
  categorical layers marked via
  [`terra::as.factor()`](https://rspatial.github.io/terra/reference/is.bool.html)).

- Mod:

  A fitted `maxnet` model.

- type:

  Prediction type passed to `predict.maxnet()`. Default `"cloglog"`.

## Value

A single-layer `SpatRaster` of predicted values, NA outside the cells
that had complete predictor data.

## Details

Note this loads every non-NA cell into memory as one data frame, unlike
[`terra::predict()`](https://rspatial.github.io/terra/reference/predict.html)'s
memory-safe chunking. Fine for a country-sized raster at moderate
resolution; if you outgrow memory, this would need to be chunked (e.g.
with
[`terra::blocks()`](https://rspatial.github.io/terra/reference/readwrite.html)).

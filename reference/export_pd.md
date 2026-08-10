# Export Phylogenetic Diversity to Cloud-Optimized GeoTIFF

This function takes a data.table of Phylogenetic Diversity results and a
path to a raster template. It generates a `SpatRaster` object using the
`terra` package, populates it with the Phylogenetic Diversity values,
and writes the result out as a Cloud-Optimized GeoTIFF.

## Usage

``` r
export_pd(Results, path)
```

## Arguments

- Results:

  A data.table containing Phylogenetic Diversity results. This
  data.table must contain at least the columns `cell` and `PD`, where
  `cell` refers to the cell index in the raster and `PD` refers to the
  Phylogenetic Diversity value.

- path:

  A character string specifying the file path to a raster template. This
  raster is used as a template for the output raster.

# Export Rarity to Cloud-Optimized GeoTIFF

This function takes a data.table of rarity results and a path to a
raster template. It generates a `SpatRaster` object using the `terra`
package, populates it with the rarity values, and writes the result out
as a Cloud-Optimized GeoTIFF.

## Usage

``` r
export_rarity(Results, path)
```

## Arguments

- Results:

  A data.table containing rarity results. This data.table must contain
  at least the columns `cell` and `Irr`, where `cell` refers to the cell
  index in the raster and `Irr` refers to the rarity value.

- path:

  A character string specifying the file path to a raster template. This
  raster is used as a template for the output raster.

## Value

A character string indicating the file path of the output
Cloud-Optimized GeoTIFF.

# Write Cloud-Optimized GeoTIFF (COG)

Writes a `SpatRaster` as a Cloud-Optimized GeoTIFF. Unchanged from the
pre-`geotargets` version – purely I/O, nothing here depended on the old
data.table workflow.

## Usage

``` r
write_cog(SpatRaster, Name)
```

## Arguments

- SpatRaster:

  A `SpatRaster` to write out.

- Name:

  Output file path, including the `.tif` extension.

## Value

Invisibly, the file path (from
[`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html)).

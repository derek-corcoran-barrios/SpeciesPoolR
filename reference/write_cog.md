# Write Cloud Optimized Geotiff (COG)

This function takes a SpatRaster object and saves it as a Cloud
Optimized Geotiff (COG). COGs are geospatial files optimized for
efficient cloud storage and retrieval.

## Usage

``` r
write_cog(SpatRaster, Name)
```

## Arguments

- SpatRaster:

  A SpatRaster object (class SpatRaster) representing the raster data to
  be saved as a COG.

- Name:

  The desired name for the COG file, including the ".tif" extension.

## Value

A Cloud Optimized Geotiff saved at the specified location.

## Examples

``` r
# Load required libraries if not already loaded
# library(terra)

# Create a sample SpatRaster
r <- terra::rast(nrows = 5, ncols = 5, vals = 1:25)

# Save the SpatRaster as a COG
write_cog(SpatRaster = r, Name = "test.tif")

# Clean up later
file.remove("test.tif")
#> [1] TRUE
file.remove("test.tfw")
#> [1] TRUE
```

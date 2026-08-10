# Build a CCW WKT polygon from a shapefile (lon/lat)

Creates a minimum bounding rectangle (MBR) around the provided shapefile
and returns it as a WKT POLYGON in counter‑clockwise order. If the
shapefile is not in lon/lat, it is projected to EPSG:4326.

## Usage

``` r
wkt_rect_ccw(shapefile)
```

## Arguments

- shapefile:

  Path to a vector file readable by
  [`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html).

## Value

A single-length character vector with WKT POLYGON, suitable for GBIF's
`geometry` param.

## Examples

``` r
f <- system.file("ex/Aarhus.shp", package = "SpeciesPoolR")
wkt <- wkt_rect_ccw(f)
cat(substr(wkt, 1, 60), "...\n")
#> POLYGON ((9.948676 55.995865, 10.389723 55.995865, 10.389723 ...
```

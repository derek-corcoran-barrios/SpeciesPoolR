# Convex_20

Creates an expanded convex hull from a set of coordinates, used to
define a background-sampling area around a species' known occurrences.

## Usage

``` r
Convex_20(
  DF,
  lon = "decimalLongitude",
  lat = "decimalLatitude",
  proj = "+proj=longlat +datum=WGS84 +no_defs",
  expansion = 1.2
)
```

## Arguments

- DF:

  The dataframe containing the coordinates.

- lon:

  The name of the longitude column in the dataframe.

- lat:

  The name of the latitude column in the dataframe.

- proj:

  The projection of the coordinates.

- expansion:

  Numeric expansion factor applied to the convex hull around its
  centroid. Default 1.2 (a 20% expansion).

## Value

A polygon representing the expanded convex hull.

## Examples

``` r

DF <- data.frame(decimalLongitude =
      c(23.978543, 23.785003, 11.485,  -2.054027, 12.9069),
                 decimalLatitude =
       c(38.088876, 60.238213, 48.165, 53.33939, 56.80782))

Convex_20(DF, lon = "decimalLongitude", lat = "decimalLatitude",
proj = "+proj=longlat +datum=WGS84 +no_defs")
#> class       : SpatVector
#> geometry    : polygons
#> dimensions  : 1, 0  (geometries, attributes)
#> extent      : -5.512134, 25.72695, 35.59555, 62.17476  (xmin, xmax, ymin, ymax)
#> coord. ref. : +proj=longlat +datum=WGS84 +no_defs
```

# Build buffered occurrence geometries around species records

Takes species occurrence data and buffers each occurrence point by a
fixed distance, then dissolves overlapping buffers within each species
into spatially distinct patches. Returns a single `SpatVector` (one
feature per disjoint patch per species), still in geographic (lon/lat)
coordinates.

## Usage

``` r
make_buffer(DT, dist = 500)
```

## Arguments

- DT:

  A data.frame/data.table with columns `decimalLongitude`,
  `decimalLatitude`, `family`, `genus`, and `species` (as produced by
  [`get_presences()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/get_presences.md)).

- dist:

  A numeric value specifying the buffer distance in meters. Default is
  500 meters.

## Value

A `SpatVector` (CRS EPSG:4326), one feature per spatially distinct
(non-overlapping) buffer patch per species, with attributes `family`,
`genus`, `species`, and `n_records` (the number of occurrence records
whose buffers were merged into that patch). If `DT` has zero rows, an
empty `SpatVector` with the same CRS and `family`/`genus`/`species`
fields is returned.

## Details

Buffering is done directly on lon/lat data because
[`terra::buffer()`](https://rspatial.github.io/terra/reference/buffer.html)
computes distances in meters correctly for a longitude/latitude CRS, and
terra's own documentation notes that pre-projecting to a planar CRS
makes the result *less* precise, not more. GBIF occurrence data
(`decimalLatitude`/ `decimalLongitude`) is always WGS84, so no
raster/CRS input is needed here.

Rasterization is intentionally not done here either: keeping the result
as vector geometry means you can reproject and rasterize it onto any
raster template later (e.g. if the land-use raster resolution, extent,
or CRS changes) without repeating the buffering step.

## Examples

``` r
if (FALSE) { # \dontrun{
# Assuming Presences contains species occurrence data
buffer_vect <- make_buffer_rasterized(Presences, dist = 500)
} # }
```

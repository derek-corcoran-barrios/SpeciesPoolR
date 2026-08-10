# Fast presence counts via GBIF facets (unauthenticated)

Performs a single GBIF search using a facet on `species` and returns
occurrence counts for the supplied species list within either a country
or the minimum bounding rectangle (MBR) of a shapefile (converted to CCW
WKT with
[`wkt_rect_ccw`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/wkt_rect_ccw.md)).
This method is **fast and polite** (one request), but facet results can
be truncated if your species list exceeds `facet_limit`.

## Usage

``` r
count_presences_simple(
  species,
  shapefile = NULL,
  country = NULL,
  year = c(1999L, as.integer(format(Sys.Date(), "%Y"))),
  facet_limit = 20000L,
  verbose = TRUE
)
```

## Arguments

- species:

  A data frame/data.table/tibble with columns `family`, `genus`,
  `species`. (Use cleaned GBIF-aligned names for best matches.)

- shapefile:

  Path to a vector file readable by
  [`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html).
  If provided (and `country` is `NULL`), its MBR is used as the GBIF
  `geometry` filter via
  [`wkt_rect_ccw`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/wkt_rect_ccw.md).
  Mutually exclusive with `country`.

- country:

  Two-letter ISO country code (e.g., `"DK"`). Ignored if `shapefile` is
  provided. Mutually exclusive with `shapefile`.

- year:

  Integer vector `c(start, end)` with the year range (inclusive).
  Default is `c(1999, current_year)`.

- facet_limit:

  Integer maximum number of facet entries GBIF will return. Default
  `20000`.

- verbose:

  Logical; if `TRUE`, prints helpful warnings.

## Value

A `data.table` with columns `family`, `genus`, `species`, `N`.

## Details

Count presences quickly (no auth) using GBIF facets

This function makes **one** call to
[`rgbif::occ_search()`](https://docs.ropensci.org/rgbif/reference/occ_search.html)
with `facet = "species"` and joins the returned canonical species counts
to your requested species. Species not present in the facet response
receive `N = 0`. If your list is longer than `facet_limit`, GBIF may
truncate the facet; consider
[`count_presences_auth`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_auth.md)
for complete, reproducible results.

## See also

[`count_presences_auth`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_auth.md),
[`count_presences`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences.md),
[`wkt_rect_ccw`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/wkt_rect_ccw.md)

Other GBIF helpers:
[`count_presences()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences.md),
[`count_presences_auth()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_auth.md)

## Examples

``` r
if (FALSE) { # \dontrun{
f_species <- system.file("ex/Species_List.csv", package = "SpeciesPoolR")
shp       <- system.file("ex/Aarhus.shp",      package = "SpeciesPoolR")
sp        <- SpeciesPoolR::get_data(f_species)
clean     <- SpeciesPoolR::Clean_Taxa(sp$Species)

out <- count_presences_simple(
  species   = clean,
  shapefile = shp,
  year      = c(1999, as.integer(format(Sys.Date(), "%Y")))
)
head(out)
} # }
```

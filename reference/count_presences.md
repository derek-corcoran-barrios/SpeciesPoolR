# Unified interface for GBIF presence counts

Convenience wrapper that dispatches to
[`count_presences_simple`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_simple.md)
(fast, no authentication) or
[`count_presences_auth`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_auth.md)
(robust, authenticated GBIF download). Returns a tidy table of counts
per species within either a country or the MBR of a shapefile.

## Usage

``` r
count_presences(
  species,
  shapefile = NULL,
  country = NULL,
  method = c("simple"),
  year = c(1999L, as.integer(format(Sys.Date(), "%Y"))),
  ...
)
```

## Arguments

- species:

  A data frame/data.table/tibble with columns `family`, `genus`,
  `species`.

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

- method:

  Character; one of `"simple"` (default) or `"auth"`. Matching is
  case-insensitive.

- year:

  Integer vector `c(start, end)` with the year range (inclusive).
  Default is `c(1999, current_year)`.

- ...:

  Additional arguments passed to the selected backend:

  - For `method = "simple"`: `facet_limit`, `verbose`.

  - For `method = "auth"`: `restrict_to_species`, `verbose`.

## Value

A `data.table` with columns `family`, `genus`, `species`, `N`.

## Details

Count presences via GBIF (choose fast **simple** or robust **auth**
method)

Use `method = "simple"` for quick exploratory work; switch to `"auth"`
for larger lists or when you need a citable, reproducible download
record.

## See also

[`count_presences_simple`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_simple.md),
[`count_presences_auth`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_auth.md),
[`wkt_rect_ccw`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/wkt_rect_ccw.md)

Other GBIF helpers:
[`count_presences_auth()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_auth.md),
[`count_presences_simple()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_simple.md)

## Examples

``` r
if (FALSE) { # \dontrun{
f_species <- system.file("ex/Species_List.csv", package = "SpeciesPoolR")
shp       <- system.file("ex/Aarhus.shp",      package = "SpeciesPoolR")
sp        <- SpeciesPoolR::get_data(f_species)
clean     <- SpeciesPoolR::Clean_Taxa(sp$Species)

# Fast
out1 <- count_presences(clean, shapefile = shp, method = "simple")

# Robust (requires GBIF_USER/GBIF_PWD/GBIF_EMAIL)
out2 <- count_presences(clean, shapefile = shp, method = "auth", restrict_to_species = TRUE)
} # }
```

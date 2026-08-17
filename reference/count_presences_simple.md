# Fast presence counts via GBIF facets

Counts GBIF occurrence records for a supplied species list within either
a country or a spatial extent. Always queries the country/geometry alone
(never restricted by species key) and requests the complete speciesKey
facet for that region, then joins those counts back onto the supplied
species locally.

There is deliberately no size-based branch that puts species keys
directly into the query for "small" lists. That alternative failed in
practice somewhere around a few thousand keys (a connection reset from
GBIF's API), but the exact safe threshold below that isn't known – it
could be far lower. Rather than guess a cutoff and risk hitting the same
failure at a smaller, more confusing scale, this function always uses
the regional-facet strategy: the query never grows with the number of
species requested, whether that's 7 or 400,000, so there's no query-size
failure mode left to hit at all.

Failed GBIF requests are retried with exponential backoff, since this
project has repeatedly hit transient GBIF/network failures. Retries only
help with *transient* failures, though – if a request fails because it
is structurally too large (e.g. `facet_limit` set unreasonably high),
retrying will just fail the same way every time.

## Usage

``` r
count_presences_simple(
  species,
  shapefile = NULL,
  country = NULL,
  year = c(1999L, as.integer(format(Sys.Date(), "%Y"))),
  facet_limit = 200000L,
  retries = 5L,
  verbose = TRUE
)
```

## Arguments

- species:

  A data frame/data.table/tibble with columns `family`, `genus`,
  `species`, and `gbif_speciesKey`.

- shapefile:

  Optional path to a vector file readable by
  [`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html).
  If supplied and `country` is `NULL`, its bounding rectangle (via
  [`wkt_rect_ccw()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/wkt_rect_ccw.md))
  is used as the GBIF `geometry` filter. Mutually exclusive with
  `country`. Prefer `country` when possible: a bounding rectangle over a
  coastal, island-heavy country like Denmark includes a fair amount of
  sea (and can nick neighboring countries), where a country code gives
  GBIF's exact attribution.

- country:

  Optional two-letter ISO country code, e.g. `"DK"`. Mutually exclusive
  with `shapefile`.

- year:

  Integer vector `c(start, end)` defining the year range (inclusive).
  Default `c(1999, current_year)`.

- facet_limit:

  Integer maximum number of speciesKey facet entries GBIF will return.
  Must be sized to the number of distinct species GBIF has ever recorded
  in the country/region, *not* the length of your species list, since
  the facet covers the whole region regardless of how many species you
  asked about. Default `200000L`, matching rgbif's own documented
  example for country-level species counts. rgbif's docs report reliable
  results up to `500000`; going much higher risks the request itself
  failing.

- retries:

  Number of attempts for a failed GBIF request, with exponential backoff
  between attempts. Default `5`.

- verbose:

  Logical; print progress and retry messages. Default `TRUE`.

## Value

A `data.table` with columns `family`, `genus`, `species`, `N`.

## Details

Count presences using GBIF species facets

If the facet response has exactly `facet_limit` rows, that's a strong
signal of truncation – GBIF sorts facets by count descending, so a
truncated facet drops the *rarest* species first, silently. Rather than
return possibly-incomplete counts, this raises an error asking you to
increase `facet_limit`.

## See also

[`count_presences_auth()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_auth.md),
[`count_presences()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences.md),
[`wkt_rect_ccw()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/wkt_rect_ccw.md)

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
  species = clean,
  country = "DK",
  year    = c(1999, as.integer(format(Sys.Date(), "%Y")))
)
head(out)
} # }
```

# Reproducible presence counts via GBIF downloads (authenticated)

Submits an authenticated GBIF Occurrence Download restricted by
country/geometry and year (optionally restricted to your species via
GBIF taxon keys), waits for completion, imports the result, and
summarizes counts per species locally. This is the **robust** and
reproducible approach recommended for larger jobs.

## Usage

``` r
count_presences_auth(
  species,
  shapefile = NULL,
  country = NULL,
  year = c(1999L, as.integer(format(Sys.Date(), "%Y"))),
  restrict_to_species = TRUE,
  verbose = TRUE
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

- year:

  Integer vector `c(start, end)` with the year range (inclusive).
  Default is `c(1999, current_year)`.

- restrict_to_species:

  Logical; if `TRUE` (default), the download is restricted to your
  species by GBIF `taxonKey` (resolved via
  [`rgbif::name_backbone()`](https://docs.ropensci.org/rgbif/reference/name_backbone.html)).
  If `FALSE`, the download uses only area/time filters and species are
  filtered locally afterwards.

- verbose:

  Logical; if `TRUE`, prints progress messages.

## Value

A `data.table` with columns `family`, `genus`, `species`, `N`.

## Details

Count presences robustly using the GBIF Occurrence Download API (auth
required)

## Credentials

Requires the environment variables `GBIF_USER`, `GBIF_PWD`,
`GBIF_EMAIL`. A convenient place to define them is your `~/.Renviron`.

## See also

[`count_presences_simple`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_simple.md),
[`count_presences`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences.md),
[`wkt_rect_ccw`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/wkt_rect_ccw.md)

Other GBIF helpers:
[`count_presences()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences.md),
[`count_presences_simple()`](https://derek-corcoran-barrios.github.io/SpeciesPoolR/reference/count_presences_simple.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Set GBIF creds in ~/.Renviron:
# GBIF_USER=youruser
# GBIF_PWD=yourpassword
# GBIF_EMAIL=you@example.org

f_species <- system.file("ex/Species_List.csv", package = "SpeciesPoolR")
shp       <- system.file("ex/Aarhus.shp",      package = "SpeciesPoolR")
sp        <- SpeciesPoolR::get_data(f_species)
clean     <- SpeciesPoolR::Clean_Taxa(sp$Species)

out <- count_presences_auth(
  species   = clean,
  shapefile = shp,
  year      = c(1999, as.integer(format(Sys.Date(), "%Y"))),
  restrict_to_species = TRUE,
  verbose   = TRUE
)
head(out)
} # }
```

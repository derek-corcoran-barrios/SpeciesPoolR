# Clean taxa using Taxize

This function cleans a vector of taxa using the Global Names
Architecture via the taxize package.

## Usage

``` r
Clean_Taxa_Taxize(Taxons, WriteFile = FALSE, verbose = TRUE)
```

## Arguments

- Taxons:

  Vector of taxa to be cleaned.

- WriteFile:

  logical; if FALSE (default) only returns a data frame, if TRUE will
  generate a folder (Results) in the working directory with a CSV of the
  results.

- verbose:

  logical; if TRUE, prints progress and summary messages (default:
  TRUE).

## Value

A data frame with the cleaned taxa and their scores.

## Examples

``` r
Clean_Taxa_Taxize(
  Taxons =  c("Abies concolor", "Abies lowiana", "Canis lupus", "Cannis lupus"),
  verbose = TRUE
)
#> 4 of 4 names resolved; 2 unique accepted names (non-synonyms).
#> # A tibble: 2 × 4
#>   Taxa           score currentCanonicalFull TaxaID
#>   <chr>          <dbl> <chr>                 <int>
#> 1 Abies concolor     1 Abies concolor            1
#> 2 Canis lupus        1 Canis lupus               3
```

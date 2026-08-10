# Clean taxa using Taxize and rgbif

This function cleans a vector of taxa using Taxize and rgbif
sequentially.

## Usage

``` r
Clean_Taxa(Taxons, WriteFile = FALSE, Species_Only = TRUE, verbose = TRUE)
```

## Arguments

- Taxons:

  Vector of taxa to be cleaned.

- WriteFile:

  logical; if FALSE (default) only returns a data frame, if TRUE will
  generate a folder (Results) with CSVs.

- Species_Only:

  logical; if TRUE (default) only species will be returned, if FALSE
  returns highest possible taxonomic resolution.

- verbose:

  logical; if TRUE, prints progress and summary messages (default:
  TRUE).

## Value

A data frame with the cleaned taxa and their scores.

## Examples

``` r
Cleaned <- Clean_Taxa(c("Canis lupus", "C. lupus"), verbose = TRUE)
#> 1 of 2 names resolved; 1 unique accepted names (non-synonyms).
#> 1 taxa retained after GBIF cleaning (species only).
```

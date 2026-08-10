# Clean Taxa from GBIF

Clean the taxonomic list using GBIF.

## Usage

``` r
Clean_Taxa_rgbif(
  Cleaned_Taxize,
  WriteFile = FALSE,
  Species_Only = TRUE,
  verbose = FALSE
)
```

## Arguments

- Cleaned_Taxize:

  a data frame containing the cleaned taxonomic list from
  `Clean_Taxa_Taxize`.

- WriteFile:

  logical; if FALSE (default) only returns a data frame, if TRUE will
  generate a folder (Results) with a CSV.

- Species_Only:

  logical; if TRUE (default) only species will be returned, if FALSE
  returns highest possible taxonomic resolution.

- verbose:

  logical; if TRUE, prints progress and summary messages (default:
  FALSE).

## Value

A data frame containing the GBIF-cleaned taxonomic list.

## Examples

``` r
if (FALSE) { # \dontrun{
Cleaned_Taxize <- Clean_Taxa_Taxize(c("Abies concolor", "Canis lupus"), verbose = TRUE)
Clean_Taxa_rgbif(Cleaned_Taxize, verbose = TRUE)
} # }
```

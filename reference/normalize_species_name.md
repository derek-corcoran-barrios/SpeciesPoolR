# Normalize Species Names for Matching Across Sources

Different sources in this pipeline write species names differently –
`"Anthyllis vulneraria"` (spaces, from GBIF/taxonomic data), vs. raster
layer names that can end up as `"Anthyllis.vulneraria"` (dots, from R's
[`make.names()`](https://rdrr.io/r/base/make.names.html)-style handling
when layers get combined), vs. phylogeny tip labels that are
conventionally `"Anthyllis_vulneraria"` (underscores). Collapsing all of
these to one common form before matching avoids silent mismatches
(exactly the bug this pipeline hit once already with branch-name
mangling).

## Usage

``` r
normalize_species_name(x)
```

## Arguments

- x:

  A character vector of species names.

## Value

`x` with any run of non-alphanumeric characters collapsed to a single
underscore.

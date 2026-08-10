# Species Richness and Phylogenetic Diversity Data

A dataset containing species richness and phylogenetic diversity results
along with associated land use information.

## Usage

``` r
Richness_PD
```

## Format

A data.table and data.frame with 26,433 rows and 4 variables:

- PD:

  Numeric. The Phylogenetic Diversity calculated with the `picante` R
  package.

- SR:

  Integer. The Species Richness calculated with the `picante` R package.

- cell:

  Integer. The cell index in the raster.

- Landuse:

  Character. The type of land use associated with the cell (e.g.,
  "ForestDryPoor").

## Examples

``` r
if (FALSE) { # \dontrun{
  data(Richness_PD)
  head(Richness_PD)
} # }
```

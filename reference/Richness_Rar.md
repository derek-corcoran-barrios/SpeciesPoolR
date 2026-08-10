# Species Richness and Rarity Data

A dataset containing species richness results along with associated
Index of Relative Rarity (Irr) and land use information.

## Usage

``` r
Richness_Rar
```

## Format

A data.table and data.frame with 26,433 rows and 4 variables:

- cell:

  Numeric. The cell index in the raster.

- Irr:

  Numeric. The Index of Relative Rarity calculated with the `rarity` R
  package.

- Richness:

  Integer. The species richness value for the cell.

- Landuse:

  Character. The type of land use associated with the cell (e.g.,
  "ForestDryPoor").

## Examples

``` r
if (FALSE) { # \dontrun{
  data(Richness_Rar)
  head(Richness_Rar)
} # }
```

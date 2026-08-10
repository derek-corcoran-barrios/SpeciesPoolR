# Read in Data from a CSV or XLSX File

This function reads in data from a CSV or XLSX file. The file must
contain a "Species" column. You can optionally apply a filter expression
to the dataset before returning it. The function returns a `data.frame`
with the filtered results for further processing in the pipeline.

## Usage

``` r
get_data(file, filter = NULL)
```

## Arguments

- file:

  A string specifying the path to the CSV or XLSX file to read. The file
  must contain a "Species" column.

- filter:

  An optional expression used to filter the resulting `data.frame`. This
  should be an expression written as if you were using
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html).
  The default is NULL, meaning no filtering is applied.

## Value

A `data.frame` containing the data read from the file, optionally
filtered.

## Examples

``` r
if (FALSE) { # \dontrun{
# Read in data without filtering
f <- system.file("ex/Species_List.csv", package="SpeciesPoolR")
data <- get_data(f)

# Read in data and filter for Plantae kingdom and certain taxon ranges
filtered_data <- get_data(
  file = f,
  filter = quote(
   Kingdom == "Plantae" &
   Class == "Magnoliopsida"
  )
)
} # }
```

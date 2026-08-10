# Export Final Species Presences to CSV Files

This function exports the final filtered species presences to CSV files.
The data is grouped by land-use type, and each species is saved in a
separate CSV file within a folder corresponding to its land-use type.

## Usage

``` r
export_final_presences(DF, folder)
```

## Arguments

- DF:

  A data frame containing the final species presences with columns
  including `species` and `Landuse`.

- folder:

  A string specifying the directory where the CSV files should be saved.
  The function will create subfolders for each land-use type within this
  directory.

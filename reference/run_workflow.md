# Run the SpeciesPoolR Workflow

This function sets up and runs a `targets` workflow using the functions
provided in the `SpeciesPoolR` package. The workflow includes steps for
cleaning species data, counting species presences, filtering data, and
generating buffers for spatial analysis.

## Usage

``` r
run_workflow(
  workers = 2,
  error = "null",
  file_path,
  rastertemp,
  rasterLU,
  LanduseSuitability,
  dist = 500,
  limit = 1000,
  filter = NULL,
  country = NULL,
  shapefile = NULL,
  plot = TRUE
)
```

## Arguments

- workers:

  Number of parallel workers to use in the `crew` controller. Default is
  2.

- error:

  Handling for errors in outdated targets. Default is "null".

- file_path:

  Path to the Excel or csv file containing the data.

- rastertemp:

  A file path to the raster file that will be used as a template for
  rasterizing the buffers.

- rasterLU:

  A file path to the raster file that has the landuses that exist in the
  area that will be modeled.

- LanduseSuitability:

  A string representing the file path to the raster file containing
  land-use binary suitability data.

- dist:

  A numeric value specifying the buffer distance in meters. Default is
  500 meters.

- limit:

  maximum number of occurrences downloaded

- filter:

  An optional expression used to filter the resulting `data.frame`. This
  should be an expression written as if you were using
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html).
  The default is NULL, meaning no filtering is applied.

- country:

  A two-letter country code to define the area of interest for counting
  species presences. Default is NULL.

- shapefile:

  Path to a shapefile defining the area of interest for counting species
  presences. Default is NULL.

- plot:

  if TRUE (default) it will run the
  [`targets::tar_visnetwork()`](https://docs.ropensci.org/targets/reference/tar_visnetwork.html)
  to plot the workflow

## Value

Executes the `targets` pipeline.

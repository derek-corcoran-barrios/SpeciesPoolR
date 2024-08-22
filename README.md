
<!-- README.md is generated from README.Rmd. Please edit that file -->

# SpeciesPoolR

<!-- badges: start -->

[![R-CMD-check](https://github.com/derek-corcoran-barrios/SpeciesPoolR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/derek-corcoran-barrios/SpeciesPoolR/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of the `SpeciesPoolR` package is to generate potential species
pools and their summary metrics in a spatial way.

## Installation

You can install the development version of SpeciesPoolR from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("derek-corcoran-barrios/SpeciesPoolR")
```

No you can load the package

``` r
library(SpeciesPoolR)
```

## Summary metrics

Now that you have in which habitat and where a species can be found, we
can generate several summary metrics, we will start by reading in the
resulting potential occurrence by species in.

## Read in Presences from a folder

The first thing to do is to read in Presences from a folder, with the
function `GetLandusePresences` as seen in the following code

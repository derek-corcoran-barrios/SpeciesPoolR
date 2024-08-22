
- [1 SpeciesPoolR](#1-speciespoolr)
- [2 Using SpeciesPoolR Manually](#2-using-speciespoolr-manually)
  - [2.1 Importing and Downloading Species
    Presences](#21-importing-and-downloading-species-presences)
- [3 Running the SpeciesPoolR
  Workflow](#3-running-the-speciespoolr-workflow)
  - [3.1 How It Works](#31-how-it-works)

<!-- README.md is generated from README.Rmd. Please edit that file -->

# 1 SpeciesPoolR

<!-- badges: start -->

[![R-CMD-check](https://github.com/derek-corcoran-barrios/SpeciesPoolR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/derek-corcoran-barrios/SpeciesPoolR/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of the SpeciesPoolR package is to generate potential species
pools and their summary metrics in a spatial way. You can install the
package directly from GitHub:

``` r
#install.packages("remotes")
remotes::install_github("derek-corcoran-barrios/SpeciesPoolR")
```

No you can load the package

``` r
library(SpeciesPoolR)
```

# 2 Using SpeciesPoolR Manually

## 2.1 Importing and Downloading Species Presences

### 2.1.1 Step 1: Reading and Filtering Data

If you are going to use each of the functions of the SpeciesPoolR
manually and sequentially, the first step would be to read in a species
list from either a CSV or an XLSX file. You can use the get_data
function for this. The function allows you to filter your data in a
dplyr-like style:

``` r
f <- system.file("ex/Species_List.csv", package="SpeciesPoolR")
filtered_data <- get_data(
   file = f,
   filter = quote(Kingdom == "Plantae" & 
                    Class == "Magnoliopsida" & 
                    Family == "Fabaceae")
)
```

This will generate a dataset that can be used subsequently to count
species presences and download species data as seen in table
<a href="#tab:tablespecies">2.1</a>

| redlist_2010 | Kingdom | Phyllum       | Class         | Order   | Family   | Genus     | Species               |
|:-------------|:--------|:--------------|:--------------|:--------|:---------|:----------|:----------------------|
| NA           | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Vicia     | Vicia sepium          |
| NA           | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Genista   | Genista tinctoria     |
| NA           | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Trifolium | Trifolium vesiculosum |
| LC           | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Vicia     | Vicia sativa          |
| NA           | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Lathyrus  | Lathyrus latifolius   |
| NA           | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Anthyllis | Anthyllis vulneraria  |
| NA           | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Vicia     | Vicia sepium          |
| NA           | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Lathyrus  | Lathyrus japonicus    |
| NA           | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Vicia     | Vicia villosa         |

<span id="tab:tablespecies"></span>Table 2.1: Species that will be used
to generate species pools

### 2.1.2 Step 2: Taxonomic Harmonization

Next, you should perform taxonomic harmonization to ensure that the
species names you use are recognized by the GBIF taxonomic backbone.
This can be done using the Clean_Taxa function:

``` r
Clean_Species <- SpeciesPoolR::Clean_Taxa(filtered_data$Species)
```

The resulting data frame, with harmonized species names, is shown in
table <a href="#tab:cleantable">2.2</a>

| Taxa                  | matched_name2         | confidence | canonicalName         | kingdom | phylum       | class         | order   | family   | genus     | species               | rank    |
|:----------------------|:----------------------|-----------:|:----------------------|:--------|:-------------|:--------------|:--------|:---------|:----------|:----------------------|:--------|
| Vicia sepium          | Vicia sepium          |         99 | Vicia sepium          | Plantae | Tracheophyta | Magnoliopsida | Fabales | Fabaceae | Vicia     | Vicia sepium          | SPECIES |
| Genista tinctoria     | Genista tinctoria     |         99 | Genista tinctoria     | Plantae | Tracheophyta | Magnoliopsida | Fabales | Fabaceae | Genista   | Genista tinctoria     | SPECIES |
| Trifolium vesiculosum | Trifolium vesiculosum |         99 | Trifolium vesiculosum | Plantae | Tracheophyta | Magnoliopsida | Fabales | Fabaceae | Trifolium | Trifolium vesiculosum | SPECIES |
| Vicia sativa          | Vicia sativa          |         97 | Vicia sativa          | Plantae | Tracheophyta | Magnoliopsida | Fabales | Fabaceae | Vicia     | Vicia sativa          | SPECIES |
| Lathyrus latifolius   | Lathyrus latifolius   |         98 | Lathyrus latifolius   | Plantae | Tracheophyta | Magnoliopsida | Fabales | Fabaceae | Lathyrus  | Lathyrus latifolius   | SPECIES |
| Anthyllis vulneraria  | Anthyllis vulneraria  |         97 | Anthyllis vulneraria  | Plantae | Tracheophyta | Magnoliopsida | Fabales | Fabaceae | Anthyllis | Anthyllis vulneraria  | SPECIES |
| Lathyrus japonicus    | Lathyrus japonicus    |         99 | Lathyrus japonicus    | Plantae | Tracheophyta | Magnoliopsida | Fabales | Fabaceae | Lathyrus  | Lathyrus japonicus    | SPECIES |
| Vicia villosa         | Vicia villosa         |         97 | Vicia villosa         | Plantae | Tracheophyta | Magnoliopsida | Fabales | Fabaceae | Vicia     | Vicia villosa         | SPECIES |

<span id="tab:cleantable"></span>Table 2.2: Taxonomicallty harmonized
dataset

### 2.1.3 Step 3: Counting Species Presences

After harmonizing the species names, it’s important to obtain the number
of occurrences of each species in your study area, especially if you
plan to calculate rarity. You can do this using the `count_presences`
function. This function allows you to filter occurrences by country or
by a shapefile. Below is an example for Denmark:

``` r
# Assuming Clean_Species is your data frame
Count_DK <- count_presences(Clean_Species, country = "DK")
```

The resulting data frame of species presences in Denmark is shown in
table <a href="#tab:tableCountDenmark">2.3</a>

``` r
knitr::kable(Count_DK, caption = "Counts of presences for the different species within Denmark")
```

| family   | genus     | species               |     N |
|:---------|:----------|:----------------------|------:|
| Fabaceae | Vicia     | Vicia sepium          |  2897 |
| Fabaceae | Genista   | Genista tinctoria     |   988 |
| Fabaceae | Trifolium | Trifolium vesiculosum |     0 |
| Fabaceae | Vicia     | Vicia sativa          | 17379 |
| Fabaceae | Lathyrus  | Lathyrus latifolius   |   684 |
| Fabaceae | Anthyllis | Anthyllis vulneraria  |  8876 |
| Fabaceae | Lathyrus  | Lathyrus japonicus    |  3904 |
| Fabaceae | Vicia     | Vicia villosa         |   243 |

<span id="tab:tableCountDenmark"></span>Table 2.3: Counts of presences
for the different species within Denmark

Alternatively, you can filter by a specific region using a shapefile.
For example, to count species presences within Aarhus commune:

``` r
shp <- system.file("ex/Aarhus.shp", package="SpeciesPoolR")

Count_Aarhus <- count_presences(Clean_Species, shapefile = shp)
```

The resulting data.frame for Aarhus commune is shown int table
<a href="#tab:tableCountAarhus">2.4</a>

| family   | genus     | species               |   N |
|:---------|:----------|:----------------------|----:|
| Fabaceae | Vicia     | Vicia sepium          | 283 |
| Fabaceae | Genista   | Genista tinctoria     |  27 |
| Fabaceae | Trifolium | Trifolium vesiculosum |   0 |
| Fabaceae | Vicia     | Vicia sativa          | 467 |
| Fabaceae | Lathyrus  | Lathyrus latifolius   |  41 |
| Fabaceae | Anthyllis | Anthyllis vulneraria  | 153 |
| Fabaceae | Lathyrus  | Lathyrus japonicus    |  39 |
| Fabaceae | Vicia     | Vicia villosa         |  10 |

<span id="tab:tableCountAarhus"></span>Table 2.4: Counts of presences
for the different species within Aarhus commune

Now it is recommended to eliminate species that have no occurrences in
the area, this is done automatically in the workflow version:

``` r
library(data.table)
Count_Aarhus <- Count_Aarhus[N > 0,]
```

So that then we can retrieve the species presences using the function
`SpeciesPoolR::get_presences`.

``` r
Presences <- get_presences(species = Count_Aarhus$species, shapefile = shp)
#> [1] "Geometry created: POLYGON ((10.401438 56.302419, 10.048024 56.355225, 9.886316 56.019928, 10.239729 55.966657, 10.401438 56.302419))"
```

there we end up with 1070 presences for our 7 species.

# 3 Running the SpeciesPoolR Workflow

If you prefer to automate the process and run the `SpeciesPoolR`
workflow as a pipeline, you can use the `run_workflow` function. This
function sets up a `targets` workflow that sequentially executes the
steps for cleaning species data, counting species presences, and
performing spatial analysis. This approach is especially useful for
larger datasets or when you want to ensure reproducibility.

To run the workflow, you can use the following code. We’ll use the same
species filter as before, focusing on the `Plantae` kingdom,
`Magnoliopsida` class, and `Fabaceae` family. Additionally, we’ll focus
on the Aarhus commune using a shapefile.

``` r
shp <- system.file("ex/Aarhus.shp", package = "SpeciesPoolR")

run_workflow(
  file_path = system.file("ex/Species_List.csv", package = "SpeciesPoolR"),
  filter = quote(Kingdom == "Plantae" & Class == "Magnoliopsida" & Family == "Fabaceae"),
  shapefile = shp
)
```

## 3.1 How It Works

The run_workflow function creates a pipeline that:

1- Reads the data from the specified file path. 2- Filters the data
using the provided filter expression. 3- Cleans the species names to
match the GBIF taxonomic backbone. 4- Counts the species presences
within the specified geographic area (in this case, Aarhus). 5-
Generates a visual representation of the workflow (if plot = TRUE).

You can monitor the progress of the workflow and visualize the
dependencies between steps using targets::tar_visnetwork(). The result
will be similar to running the steps manually but with the added
benefits of parallel execution and reproducibility.

This automated approach allows you to streamline your analysis and
ensures that all steps are consistently applied to your data. It also
makes it easier to rerun the workflow with different parameters or
datasets.

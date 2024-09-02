
- [1 SpeciesPoolR](#1-speciespoolr)
- [2 Motivation for the pacakge](#2-motivation-for-the-pacakge)
  - [2.1 Rare species are common and
    important](#21-rare-species-are-common-and-important)
- [3 Using SpeciesPoolR Manually](#3-using-speciespoolr-manually)
  - [3.1 Importing and Downloading Species
    Presences](#31-importing-and-downloading-species-presences)
  - [3.2 Creating Spatial Buffers and Habitat
    Filtering](#32-creating-spatial-buffers-and-habitat-filtering)
  - [3.3 Generating summary biodiversity
    statistics](#33-generating-summary-biodiversity-statistics)
- [4 Running the SpeciesPoolR
  Workflow](#4-running-the-speciespoolr-workflow)
  - [4.1 How It Works](#41-how-it-works)
- [5 References](#5-references)

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

# 2 Motivation for the pacakge

## 2.1 Rare species are common and important

In ecological research, the debate on whether rare species outnumber
common species within communities is pivotal for understanding
biodiversity and guiding conservation efforts. Numerous studies have
shown that rare species typically dominate large ecological assemblages,
although common species often exert a more substantial influence on
overall species richness patterns (Magurran and Henderson 2003;
Bregović, Fišer, and Zagmajster 2019; Schalkwyk, Pryke, and Samways
2019). This complexity underscores the need for innovative approaches in
studying biodiversity, particularly since rare species are challenging
to model using traditional Species Distribution Models (SDMs) due to
their low occurrence rates (Boyd et al. 2022).

Given the limitations of SDMs in capturing the dynamics of rare species,
it is essential to develop alternative methods for integrating these
species into biodiversity assessments and conservation planning.
Although rare species contribute uniquely to functional diversity and
ecosystem stability, especially in specific habitats (Chapman,
Tunnicliffe, and Bates 2018; Säterberg et al. 2019), their elusiveness
in ecological models presents a significant challenge. The question of
the minimum number of presence records required for reliable SDMs is
crucial. Research has shown that while as few as 10-15 presence
observations can produce nonrandom models for some species (Støa et al.
2019), others require higher thresholds—ranging from 14 to 25 records
depending on the species’ prevalence and geographic range (Proosdij et
al. 2016; Sampaio and Cavalcante 2023). These findings suggest that even
sparse datasets can be useful, but the threshold varies significantly
depending on species traits and habitat characteristics. Therefore,
researchers must explore novel analytical frameworks and conservation
strategies that better accommodate the ecological importance of rare
species, thereby enhancing our ability to manage and preserve
biodiversity effectively (Reddin, Bothwell, and Lennon 2015).

In highly degraded habitats, such as Denmark, where over 60% of the land
is dominated by agriculture and less than 10% remains as natural
habitat, traditional SDMs may face further limitations. The scarcity of
natural habitats means that presence records are often skewed towards
human-modified landscapes, complicating the modeling of species’
ecological preferences. In such contexts, where the majority of
occurrences may not reflect the species’ natural behaviors or habitat
use, relying on complex SDMs could lead to misleading predictions.
Instead, simpler algorithms that incorporate basic dispersal mechanisms
and habitat filtering might be more effective. By reducing assumptions
about habitat preferences, these methods can provide a more realistic
framework for conservation planning, particularly when dealing with the
restoration of agricultural lands into natural habitats.

For rare species, and indeed for many others, this approach may offer a
more practical solution in scenarios where detailed ecological data is
sparse or unreliable. Studies have suggested that in such landscapes,
simplistic models that prioritize dispersal and broad habitat
suitability over intricate ecological niches can better capture species’
potential distributions and their responses to environmental changes
(GUISAN et al. 2006; Thuiller et al. 2005), an example to this approach
would be range bagging (Drake 2015). This pragmatic approach is
especially pertinent when planning conservation actions in areas where
habitat degradation has left little intact nature, and it ensures that
even under data constraints, effective biodiversity management can still
be pursued.

# 3 Using SpeciesPoolR Manually

## 3.1 Importing and Downloading Species Presences

### 3.1.1 Step 1: Reading and Filtering Data

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
<a href="#tab:tablespecies">3.1</a>

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

<span id="tab:tablespecies"></span>Table 3.1: Species that will be used
to generate species pools

### 3.1.2 Step 2: Taxonomic Harmonization

Next, you should perform taxonomic harmonization to ensure that the
species names you use are recognized by the GBIF taxonomic backbone.
This can be done using the Clean_Taxa function:

``` r
Clean_Species <- SpeciesPoolR::Clean_Taxa(filtered_data$Species)
```

The resulting data frame, with harmonized species names, is shown in
table <a href="#tab:cleantable">3.2</a>

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

<span id="tab:cleantable"></span>Table 3.2: Taxonomicallty harmonized
dataset

### 3.1.3 Step 3: Counting Species Presences

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
table <a href="#tab:tableCountDenmark">3.3</a>

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

<span id="tab:tableCountDenmark"></span>Table 3.3: Counts of presences
for the different species within Denmark

Alternatively, you can filter by a specific region using a shapefile.
For example, to count species presences within Aarhus commune:

``` r
shp <- system.file("ex/Aarhus.shp", package="SpeciesPoolR")

Count_Aarhus <- count_presences(Clean_Species, shapefile = shp)
```

The resulting data.frame for Aarhus commune is shown int table
<a href="#tab:tableCountAarhus">3.4</a>

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

<span id="tab:tableCountAarhus"></span>Table 3.4: Counts of presences
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

there we end up with 1074 presences for our 7 species.

## 3.2 Creating Spatial Buffers and Habitat Filtering

### 3.2.1 Step 1 Creating Buffers Around Species Presences

Once you have identified the species presences within your area of
interest, the next step is to create spatial buffers around these
occurrences. These buffers represent the potential dispersal range of
each species, helping to assess areas where the species might establish
itself given a specified dispersal distance.

To create these buffers, you’ll use a raster file as a template to
rasterize the buffers and specify the distance (in meters) representing
the species’ dispersal range.

``` r
Raster <- system.file("ex/LU_Aarhus.tif", package="SpeciesPoolR")

buffer500 <- make_buffer_rasterized(Presences, file = Raster, dist = 500)
```

In this example, the make_buffer_rasterized function generates a
500-meter buffer around each occurrence point in the Presences dataset.
The function utilizes the provided raster file as a template for
rasterizing these buffers.

The resulting buffer500 data frame indicates which raster cells are
covered by the buffer for each species. Table
<a href="#tab:showbuffer500">3.5</a> displays the first 10 observations
of this data frame, providing a detailed view of the buffer’s overlap
with raster cells, listing each cell and the corresponding species
within that buffer.

| cell | species      |
|-----:|:-------------|
|   26 | Vicia sepium |
|   27 | Vicia sepium |
|   28 | Vicia sepium |
|   29 | Vicia sepium |
|   30 | Vicia sepium |
|  161 | Vicia sepium |
|  162 | Vicia sepium |
|  163 | Vicia sepium |
|  164 | Vicia sepium |
|  165 | Vicia sepium |

<span id="tab:showbuffer500"></span>Table 3.5: Raster cells within the
500-meter buffer of each species

This table provides a detailed view of how the buffer overlaps with the
raster cells, listing each cell and the corresponding species present
within that buffer.

### 3.2.2 Step 2: Habitat Filtering

After creating the buffers, the next logical step is to filter these
areas based on habitat suitability. This allows you to focus on specific
land-use types or habitats where the species is more likely to thrive.
Habitat filtering typically involves using raster data to refine or
subset the buffer areas according to the desired habitat criteria.

#### 3.2.2.1 Preparing Land-Use Data

Before you can apply habitat filtering, you need to prepare a
long-format land-use table that matches each raster cell to its
corresponding habitat types. This is done using the
generate_long_landuse_table function, which takes the path to your
raster file and transforms it into a long-format data frame. The
function also filters the data to include only those cells where the
suitability value is 1 for at least one land-use type.

``` r
# Get path for habitat suitability
HabSut <- system.file("ex/HabSut.tif", package = "SpeciesPoolR")

# Generate the long-format land-use table
long_LU_table <- generate_long_landuse_table(path = HabSut)
```

This is crucial for the next steps, the result is shown in table
<a href="#tab:longtablehab">3.6</a>, as it links each raster cell to
potential habitats, enabling you to match species occurrences to
suitable environments within their buffer zones.

| cell | Habitat     |
|-----:|:------------|
|   79 | OpenDryPoor |
|   80 | OpenDryPoor |
|   81 | OpenDryPoor |
|   82 | OpenDryPoor |
|   83 | OpenDryPoor |
|  214 | OpenDryPoor |
|  215 | OpenDryPoor |
|  216 | OpenDryPoor |
|  217 | OpenDryPoor |
|  218 | OpenDryPoor |

<span id="tab:longtablehab"></span>Table 3.6: First 10 observations of
landuse suitability per cell

#### 3.2.2.2 Applying Habitat Filtering

Once you have the long-format land-use table, you can proceed with
habitat filtering. To achieve this, you’ll use the
`ModelAndPredictFunc`, which takes the presence data frame (e.g.,
Presences) obtained through the get_presences function and the land-use
raster. This comprehensive function encompasses several critical steps:

1- *Grouping Data by Species*: The presence data is grouped by species
using `group_split`, ensuring that each species is modeled individually.

2- *Sampling Land-Use Data*: For each species, land-use data is sampled
at the presence points using the SampleLanduse function.

3- *Sampling Background Data*: Background points are also sampled from
the same land-use raster, providing a contrast to the presence data.

4- *Modeling Habitat Suitability*: The presence and background data are
combined and passed to the `ModelSpecies` function. This function fits a
MaxEnt model to predict habitat suitability across the different
land-use types.

5- *Predicting Suitability*: The fitted model is then used to predict
habitat suitability for each species across all available land-use
types.

``` r
Habitats <- ModelAndPredictFunc(DF = Presences, file = Raster)
```

The resulting Habitats data frame contains continuous suitability
predictions for each species across various land-use types. Table
<a href="#tab:tablespeciespred">3.7</a> shows the first 9 observations,
illustrating the predicted habitat suitability scores for the first
species in each land-use type.

``` r
knitr::kable(Habitats[1:9,], caption = "Predicted habitat suitability scores across various land-use types for the first species. The values represent continuous predictions, indicating the relative likelihood of species presence in each land-use category.")
```

| Landuse       |      Pred | species              |
|:--------------|----------:|:---------------------|
| OpenDryRich   | 1.0000000 | Anthyllis vulneraria |
| OpenDryPoor   | 1.0000000 | Anthyllis vulneraria |
| ForestWetRich | 0.6743700 | Anthyllis vulneraria |
| OpenWetRich   | 0.6743700 | Anthyllis vulneraria |
| OpenWetPoor   | 0.6743700 | Anthyllis vulneraria |
| Exclude       | 0.5073091 | Anthyllis vulneraria |
| ForestDryRich | 0.3768599 | Anthyllis vulneraria |
| ForestDryPoor | 0.2284649 | Anthyllis vulneraria |
| Exclude       | 0.6335459 | Genista tinctoria    |

<span id="tab:tablespeciespred"></span>Table 3.7: Predicted habitat
suitability scores across various land-use types for the first species.
The values represent continuous predictions, indicating the relative
likelihood of species presence in each land-use category.

### 3.2.3 Step 3: Generating Habitat Suitability Thresholds

While continuous predictions provide a detailed picture of habitat
suitability, it is often useful to classify these predictions into
binary suitability thresholds. Thresholds can help determine areas where
species presence is more likely or unlikely based on habitat
preferences.

The create_thresholds function facilitates this by generating thresholds
based on the modeled land-use preferences, using the 90th, 95th, and
99th percentiles of the predicted suitability values. These thresholds
represent the commission rates, helping to define the probability cutoff
above which a land-use type is considered suitable for a species.

Here’s how you can generate these thresholds for the species in your
dataset:

``` r
Thresholds <- create_thresholds(Model = Habitats, reference = Presences, file = Raster)
```

This will generate de data set with the threshold for the comission
rates of 90, 95 and 99th percentile for each species that can be seen in
Table <a href="#tab:thresholdtables">3.8</a>.

| species              | Thres_99 | Thres_95 | Thres_90 |
|:---------------------|---------:|---------:|---------:|
| Anthyllis vulneraria |    0.507 |    0.507 |    0.507 |
| Genista tinctoria    |    0.634 |    0.634 |    0.634 |
| Lathyrus japonicus   |    0.407 |    0.407 |    0.407 |
| Lathyrus latifolius  |    0.634 |    0.634 |    0.634 |
| Vicia sativa         |    0.405 |    0.405 |    0.405 |
| Vicia sepium         |    0.294 |    0.294 |    0.294 |
| Vicia villosa        |    0.633 |    0.633 |    0.633 |

<span id="tab:thresholdtables"></span>Table 3.8: Threshold based on
commission rate for the species that are used above

This step produces a data frame containing the thresholds for each
species, which can then be used to classify habitat suitability into
binary categories, helping you to identify core habitats or areas of
higher conservation value.

After we have the continuous thresholds we can generate a lookup table
to see which species can inhabit in each landuse type

``` r
LookupTable <- Generate_Lookup(Model = Habitats, Thresholds = Thresholds)
```

This creates Table <a href="#tab:lookuptab">3.9</a>, notice how it only
shows for each species which habitats are available not the ones that
are not.

| species              | Landuse       | Pres |
|:---------------------|:--------------|-----:|
| Anthyllis vulneraria | OpenDryRich   |    1 |
| Anthyllis vulneraria | OpenDryPoor   |    1 |
| Anthyllis vulneraria | ForestWetRich |    1 |
| Anthyllis vulneraria | OpenWetRich   |    1 |
| Anthyllis vulneraria | OpenWetPoor   |    1 |
| Lathyrus japonicus   | OpenDryPoor   |    1 |
| Vicia sativa         | OpenDryPoor   |    1 |
| Vicia sativa         | OpenDryRich   |    1 |
| Vicia sativa         | OpenWetRich   |    1 |
| Vicia sativa         | ForestWetRich |    1 |
| Vicia sativa         | OpenWetPoor   |    1 |
| Vicia sativa         | ForestDryRich |    1 |
| Vicia sepium         | ForestWetRich |    1 |
| Vicia sepium         | ForestDryRich |    1 |
| Vicia sepium         | OpenDryPoor   |    1 |
| Vicia sepium         | OpenWetRich   |    1 |
| Vicia sepium         | OpenWetPoor   |    1 |
| Vicia sepium         | OpenDryRich   |    1 |

<span id="tab:lookuptab"></span>Table 3.9: dummy variable that shows
which species can inhabit each habitat type

## 3.3 Generating summary biodiversity statistics

### 3.3.1 Step 1 Generating Phylogenetic diversity metrics

In order to generate Phylogenetic Diversity measures, the first step is
to generate a phylogenetic tree with the species we have, for that we
will use the V.Phylomaker package function `phylo.maker`based on the
megaphylogeny of vascular plants (Jin and Qian 2019; Zanne et al. 2014),
this means that we can only use this functions in species pools of
plants.

In this case we use the `generate_tree` from SpeciesPoolR to do so:

``` r
tree <- generate_tree(Count_Aarhus)
#> [1] "All species in sp.list are present on tree."
```

# 4 Running the SpeciesPoolR Workflow

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
Raster <- system.file("ex/LU_Aarhus.tif", package="SpeciesPoolR")

run_workflow(
  file_path = system.file("ex/Species_List.csv", package = "SpeciesPoolR"),
  filter = quote(Kingdom == "Plantae" & Class == "Magnoliopsida" & Family == "Fabaceae"),
  shapefile = shp,
  dist = 500,
  rastertemp = Raster,
  rasterLU = Raster
)
#> ▶ dispatched target Raster
#> ▶ dispatched target Landuses
#> ● completed target Raster [8.218 seconds]
#> ▶ dispatched target shp
#> ● completed target Landuses [0 seconds]
#> ▶ dispatched target file
#> ● completed target shp [0 seconds]
#> ● completed target file [0 seconds]
#> ▶ dispatched target data
#> ● completed target data [0.809 seconds]
#> ▶ dispatched target Clean
#> ● completed target Clean [1.301 seconds]
#> ▶ dispatched branch Count_Presences_33538e94b3809372
#> ▶ dispatched branch Count_Presences_52d72a5ad405e933
#> ● completed branch Count_Presences_33538e94b3809372 [0.296 seconds]
#> ▶ dispatched branch Count_Presences_e70f77d9439a4770
#> ● completed branch Count_Presences_e70f77d9439a4770 [0.146 seconds]
#> ▶ dispatched branch Count_Presences_dea4ef8633a449a1
#> ● completed branch Count_Presences_dea4ef8633a449a1 [0.083 seconds]
#> ▶ dispatched branch Count_Presences_69210fc440d13855
#> ● completed branch Count_Presences_69210fc440d13855 [0.072 seconds]
#> ▶ dispatched branch Count_Presences_a61be030e01ebaf5
#> ● completed branch Count_Presences_a61be030e01ebaf5 [0.07 seconds]
#> ▶ dispatched branch Count_Presences_974105e269324d3e
#> ● completed branch Count_Presences_974105e269324d3e [0.049 seconds]
#> ▶ dispatched branch Count_Presences_37d1f8d5f74d852c
#> ● completed branch Count_Presences_37d1f8d5f74d852c [0.062 seconds]
#> ● completed branch Count_Presences_52d72a5ad405e933 [8.249 seconds]
#> ● completed pattern Count_Presences
#> ▶ dispatched target More_than_zero
#> ● completed target More_than_zero [0.006 seconds]
#> ▶ dispatched branch Presences_c112b37cd15959d6
#> ▶ dispatched branch Presences_af64bac105a08467
#> ● completed branch Presences_af64bac105a08467 [0.643 seconds]
#> ▶ dispatched branch buffer_0e19b8cb545404d2
#> ● completed branch buffer_0e19b8cb545404d2 [0.142 seconds]
#> ▶ dispatched branch Presences_daf8d6353bc80f0c
#> ● completed branch Presences_c112b37cd15959d6 [1.009 seconds]
#> ▶ dispatched branch buffer_626a53b08dfe709d
#> ● completed branch buffer_626a53b08dfe709d [0.138 seconds]
#> ▶ dispatched branch Presences_310adeccf6b44725
#> ● completed branch Presences_310adeccf6b44725 [0.455 seconds]
#> ▶ dispatched branch buffer_b226446ac3154351
#> ● completed branch Presences_daf8d6353bc80f0c [0.833 seconds]
#> ▶ dispatched branch buffer_edb09c8ec5c9a988
#> ● completed branch buffer_b226446ac3154351 [0.404 seconds]
#> ▶ dispatched branch Presences_e65f4227e8299cc4
#> ● completed branch buffer_edb09c8ec5c9a988 [0.424 seconds]
#> ▶ dispatched branch Presences_d4b9dc68293bd5b2
#> ● completed branch Presences_e65f4227e8299cc4 [0.684 seconds]
#> ▶ dispatched branch buffer_0a8436ee3d4f2644
#> ● completed branch Presences_d4b9dc68293bd5b2 [0.756 seconds]
#> ▶ dispatched branch buffer_cae8301e59fc4e01
#> ● completed branch buffer_0a8436ee3d4f2644 [0.101 seconds]
#> ▶ dispatched branch Presences_88937156c1302a12
#> ● completed branch buffer_cae8301e59fc4e01 [0.098 seconds]
#> ▶ dispatched target Phylo_Tree
#> ● completed branch Presences_88937156c1302a12 [0.549 seconds]
#> ● completed pattern Presences
#> ▶ dispatched branch buffer_a0190cbfdf5f6f1f
#> ● completed branch buffer_a0190cbfdf5f6f1f [0.054 seconds]
#> ● completed pattern buffer
#> ▶ dispatched branch ModelAndPredict_0e19b8cb545404d2
#> ● completed branch ModelAndPredict_0e19b8cb545404d2 [1.751 seconds]
#> ▶ dispatched branch ModelAndPredict_626a53b08dfe709d
#> ● completed branch ModelAndPredict_626a53b08dfe709d [25.977 seconds]
#> ▶ dispatched branch ModelAndPredict_edb09c8ec5c9a988
#> ● completed branch ModelAndPredict_edb09c8ec5c9a988 [27.366 seconds]
#> ▶ dispatched branch ModelAndPredict_b226446ac3154351
#> ● completed target Phylo_Tree [56.36 seconds]
#> ▶ dispatched branch ModelAndPredict_0a8436ee3d4f2644
#> ● completed branch ModelAndPredict_b226446ac3154351 [6.842 seconds]
#> ▶ dispatched branch ModelAndPredict_cae8301e59fc4e01
#> ● completed branch ModelAndPredict_cae8301e59fc4e01 [1.044 seconds]
#> ▶ dispatched branch ModelAndPredict_a0190cbfdf5f6f1f
#> ● completed branch ModelAndPredict_a0190cbfdf5f6f1f [0.386 seconds]
#> ● completed branch ModelAndPredict_0a8436ee3d4f2644 [13.738 seconds]
#> ● completed pattern ModelAndPredict
#> ▶ dispatched target Thresholds
#> ● completed target Thresholds [0.848 seconds]
#> ▶ dispatched target LookUpTable
#> ● completed target LookUpTable [0.01 seconds]
#> ▶ ended pipeline [1.616 minutes]
#> Warning message:
#> 3 targets produced warnings. Run targets::tar_meta(fields = warnings, complete_only = TRUE) for the messages.
```

<img src="man/figures/README-run_workflow-1.png" width="100%" />

## 4.1 How It Works

The run_workflow function creates a pipeline that:

1.  Reads the data from the specified file path.

2.  Filters the data using the provided filter expression.

3.  Cleans the species names to match the GBIF taxonomic backbone.

4.  Counts the species presences within the specified geographic area
    (in this case, Aarhus).

5.  Generates a buffer around the species presences within the specified
    distance, for a template raster.

6.  Predicts habitat suitability for each species across different
    land-use types using the ModelAndPredictFunc, which models habitat
    preferences and provides continuous predictions.

7.  Generates a threshold for each species based on presences and the
    models that where build.

8.  Build a lookup table for each species with the suitable habitats.

9.  Generates a phyllogenetic tree for the species in the species list.

10. Generates a visual representation of the workflow (if plot = TRUE).

You can monitor the progress of the workflow and visualize the
dependencies between steps using targets::tar_visnetwork(). The result
will be similar to running the steps manually but with the added
benefits of parallel execution and reproducibility.

This automated approach allows you to streamline your analysis and
ensures that all steps are consistently applied to your data. It also
makes it easier to rerun the workflow with different parameters or
datasets.

# 5 References

<div id="refs" class="references csl-bib-body hanging-indent"
entry-spacing="0">

<div id="ref-Boyd2022Eco-evolutionary" class="csl-entry">

Boyd, Jennifer Nagel, Jill T. Anderson, Jessica R. Brzyski, Carol J.
Baskauf, and J. Cruse-Sanders. 2022. “Eco-Evolutionary Causes and
Consequences of Rarity in Plants: A Meta-Analysis.” *The New
Phytologist*. <https://doi.org/10.1111/nph.18172>.

</div>

<div id="ref-Bregovic2019Contribution" class="csl-entry">

Bregović, Petra, C. Fišer, and M. Zagmajster. 2019. “Contribution of
Rare and Common Species to Subterranean Species Richness Patterns.”
*Ecology and Evolution* 9: 11606–18.
<https://doi.org/10.1002/ece3.5604>.

</div>

<div id="ref-Chapman2018Both" class="csl-entry">

Chapman, Abbie S. A., V. Tunnicliffe, and A. Bates. 2018. “Both Rare and
Common Species Make Unique Contributions to Functional Diversity in an
Ecosystem Unaffected by Human Activities.” *Diversity and Distributions*
24: 568–78. <https://doi.org/10.1111/ddi.12712>.

</div>

<div id="ref-drake2015range" class="csl-entry">

Drake, John M. 2015. “Range Bagging: A New Method for Ecological Niche
Modelling from Presence-Only Data.” *Journal of the Royal Society
Interface* 12 (107): 20150086.

</div>

<div id="ref-GUISAN_2006" class="csl-entry">

GUISAN, ANTOINE, OLIVIER BROENNIMANN, ROBIN ENGLER, MATHIAS VUST, NIGEL
G. YOCCOZ, ANTHONY LEHMANN, and NIKLAUS E. ZIMMERMANN. 2006. “Using
Niche‐based Models to Improve the Sampling of Rare Species.”
*Conservation Biology* 20 (2): 501–11.
<https://doi.org/10.1111/j.1523-1739.2006.00354.x>.

</div>

<div id="ref-Jin2019" class="csl-entry">

Jin, Yi, and Hong Qian. 2019. “V.PhyloMaker: An r Package That Can
Generate Very Large Phylogenies for Vascular Plants.” *Ecography* 42:
1353–59.

</div>

<div id="ref-Magurran2003Explaining" class="csl-entry">

Magurran, A., and P. Henderson. 2003. “Explaining the Excess of Rare
Species in Natural Species Abundance Distributions.” *Nature* 422:
714–16. <https://doi.org/10.1038/nature01547>.

</div>

<div id="ref-Proosdij2016Minimum" class="csl-entry">

Proosdij, A. V., M. Sosef, J. Wieringa, and N. Raes. 2016. “Minimum
Required Number of Specimen Records to Develop Accurate Species
Distribution Models.” *Ecography* 39: 542–52.
<https://doi.org/10.1111/ECOG.01509>.

</div>

<div id="ref-Reddin2015Between-taxon" class="csl-entry">

Reddin, Carl J., J. Bothwell, and J. Lennon. 2015. “Between-Taxon
Matching of Common and Rare Species Richness Patterns.” *Global Ecology
and Biogeography* 24: 1476–86. <https://doi.org/10.1111/GEB.12372>.

</div>

<div id="ref-Sampaio2023Accurate" class="csl-entry">

Sampaio, A. C. G., and A. Cavalcante. 2023. “Accurate Species
Distribution Models: Minimum Required Number of Specimen Records in the
Caatinga Biome.” *Anais Da Academia Brasileira de Ciencias* 95 2:
e20201421. <https://doi.org/10.1590/0001-3765202320201421>.

</div>

<div id="ref-Saterberg2019A" class="csl-entry">

Säterberg, Torbjörn, T. Jonsson, J. Yearsley, Sofia Berg, and B.
Ebenman. 2019. “A Potential Role for Rare Species in Ecosystem
Dynamics.” *Scientific Reports* 9.
<https://doi.org/10.1038/s41598-019-47541-6>.

</div>

<div id="ref-Schalkwyk2019Contribution" class="csl-entry">

Schalkwyk, J., J. Pryke, and M. Samways. 2019. “Contribution of Common
Vs. Rare Species to Species Diversity Patterns in Conservation
Corridors.” *Ecological Indicators*.
<https://doi.org/10.1016/J.ECOLIND.2019.05.014>.

</div>

<div id="ref-Stoa2019How" class="csl-entry">

Støa, Bente, R. Halvorsen, J. Stokland, and V. I. Gusarov. 2019. “How
Much Is Enough? Influence of Number of Presence Observations on the
Performance of Species Distribution Models.” *Sommerfeltia* 39: 1–28.
<https://doi.org/10.2478/som-2019-0001>.

</div>

<div id="ref-Thuiller_2005" class="csl-entry">

Thuiller, Wilfried, Sandra Lavorel, Miguel B. Araújo, Martin T. Sykes,
and I. Colin Prentice. 2005. “Climate Change Threats to Plant Diversity
in Europe.” *Proceedings of the National Academy of Sciences* 102 (23):
8245–50. <https://doi.org/10.1073/pnas.0409902102>.

</div>

<div id="ref-Zanne2014" class="csl-entry">

Zanne, Amy E., David C. Tank, William K. Cornwell, Jonathan M. Eastman,
Stephen A. Smith, Richard G. FitzJohn, Daniel J. McGlinn, et al. 2014.
“Three Keys to the Radiation of Angiosperms into Freezing Environments.”
*American Journal of Botany* 506: 89–92.

</div>

</div>

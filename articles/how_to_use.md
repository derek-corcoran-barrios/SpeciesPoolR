# How to use the SpeciesPoolR package

## SpeciesPoolR

[![R-CMD-check](https://github.com/derek-corcoran-barrios/SpeciesPoolR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/derek-corcoran-barrios/SpeciesPoolR/actions/workflows/R-CMD-check.yaml)

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
#> Warning: replacing previous import 'data.table::between' by 'dplyr::between'
#> when loading 'SpeciesPoolR'
```

## Motivation for the pacakge

### Rare species are common and important

In ecological research, the debate on whether rare species outnumber
common species within communities is pivotal for understanding
biodiversity and guiding conservation efforts. Numerous studies have
shown that rare species typically dominate large ecological assemblages,
although common species often exert a more substantial influence on
overall species richness patterns (Magurran and Henderson 2003; Bregović
et al. 2019; Schalkwyk et al. 2019). This complexity underscores the
need for innovative approaches in studying biodiversity, particularly
since rare species are challenging to model using traditional Species
Distribution Models (SDMs) due to their low occurrence rates (Boyd et
al. 2022).

Given the limitations of SDMs in capturing the dynamics of rare species,
it is essential to develop alternative methods for integrating these
species into biodiversity assessments and conservation planning.
Although rare species contribute uniquely to functional diversity and
ecosystem stability, especially in specific habitats (Chapman et al.
2018; Säterberg et al. 2019), their elusiveness in ecological models
presents a significant challenge. The question of the minimum number of
presence records required for reliable SDMs is crucial. Research has
shown that while as few as 10-15 presence observations can produce
nonrandom models for some species (Støa et al. 2019), others require
higher thresholds—ranging from 14 to 25 records depending on the
species’ prevalence and geographic range (Proosdij et al. 2016; Sampaio
and Cavalcante 2023). These findings suggest that even sparse datasets
can be useful, but the threshold varies significantly depending on
species traits and habitat characteristics. Therefore, researchers must
explore novel analytical frameworks and conservation strategies that
better accommodate the ecological importance of rare species, thereby
enhancing our ability to manage and preserve biodiversity effectively
(Reddin et al. 2015).

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
(Guisan et al. 2006; Thuiller et al. 2005), an example to this approach
would be range bagging (Drake 2015). This pragmatic approach is
especially pertinent when planning conservation actions in areas where
habitat degradation has left little intact nature, and it ensures that
even under data constraints, effective biodiversity management can still
be pursued.

## Required Data Files

To effectively execute the `SpeciesPoolR` workflow, a set of essential
data files must be provided. These files contain the necessary spatial
and taxonomic information that underpin the various analytical steps in
the package. Below, we detail each required file and its role within the
workflow.

### Species List File

- **File Type**: CSV or Excel file

- **Description**: The species list file serves as the foundational
  dataset, comprising the species of interest for your analysis. At a
  minimum, this file must include a column for the scientific names of
  species (`Species`). Additional taxonomic columns, such as `Kingdom`,
  `Class`, and `Family`, may also be included to facilitate filtering
  and subgroup analyses.

An example of this file is provided within the package and can be
accessed using the following code:

``` r

exampleSpecies <- system.file("ex/Species_List.csv", package="SpeciesPoolR")
print(exampleSpecies)
#> [1] "/home/runner/work/_temp/Library/SpeciesPoolR/ex/Species_List.csv"
```

This dataset is further discussed in the section on [Reading and
Filtering Data](#step-1-reading-and-filtering-data), with a filtered
subset displayed in Table @ref(tab:tablespecies).

### Shapefile

- **File Type**: Shapefile (.shp)

- **Description**: The shapefile delineates the geographic area of
  interest, which can range from a broad region, such as a country, to a
  more specific locality, such as a nature reserve. This file is
  utilized to spatially constrain species occurrences, ensuring that
  only those within the defined boundaries are included in the analysis.

If a shapefile is unavailable, a two-letter country code (e.g., “DK” for
Denmark) may be provided as an alternative to specify the area of
interest.

An example shapefile is included in the package and can be accessed as
follows:

``` r

shp <- system.file("ex/Aarhus.shp", package="SpeciesPoolR")
print(shp)
#> [1] "/home/runner/work/_temp/Library/SpeciesPoolR/ex/Aarhus.shp"
```

The shapefile’s application is illustrated in the section on [Counting
Species Presences](#step-3-counting-species-presences), where it is used
to delineate the boundaries of Aarhus commune, as shown in Figure
@ref(fig:plotshapefile).

![Outline of the comune of
Aarhus](how_to_use_files/figure-html/plotshapefile-1.png)

Outline of the comune of Aarhus

### Raster Template File

- **File Type**: Raster file (e.g., .tif)

- **Description**: The raster template file is employed as a spatial
  reference for rasterizing species presence buffers. It must cover the
  entire area of interest and possess a resolution appropriate for the
  intended analysis. This template ensures consistent spatial alignment
  across all raster-based operations.

You can explore an example of this file using the following code:

``` r

template <- system.file("ex/LU_Aarhus.tif", package="SpeciesPoolR")
print(template)
#> [1] "/home/runner/work/_temp/Library/SpeciesPoolR/ex/LU_Aarhus.tif"
```

The raster template’s role in buffer creation is further explained in
the section on [Creating Buffers Around Species
Presences](#step-1-creating-buffers-around-species-presences), with an
example shown in Figure @ref(fig:plottemplate).

![Raster of the Aarhus comune, the package will use Non NA cells as part
of the template](how_to_use_files/figure-html/plottemplate-1.png)

Raster of the Aarhus comune, the package will use Non NA cells as part
of the template

### Land-Use Raster File

- **File Type**: Raster file (e.g., .tif)

- **Description**: This file contains land-use classifications for the
  study area, where each raster cell is assigned to a specific land-use
  category (e.g., forest, wetland, urban). This data is crucial for
  modeling habitat suitability, enabling the filtering of species
  occurrences based on the prevalent land uses within their potential
  habitats.

An example file is provided in the package:

``` r

LU <- system.file("ex/LU_Aarhus.tif", package="SpeciesPoolR")
print(LU)
#> [1] "/home/runner/work/_temp/Library/SpeciesPoolR/ex/LU_Aarhus.tif"
```

The land-use raster is identical to the template shown in Figure
@ref(fig:plottemplate).

### Land-Use Suitability Raster File

- **File Type**: Raster file (e.g., .tif)

- **Description**: This file comprises binary suitability values for
  various land-use types within the study area, indicating whether each
  land-use type is suitable (value = 1) or unsuitable (value = 0) for
  the habitat of interest. The data is subsequently transformed into a
  long-format table, which is integral to the habitat filtering and
  species distribution modeling processes.

An example raster file is available in the package, and its application
is discussed in the section on [Preparing Land-Use
Data](#preparing-land-use-data). A visualization of this file is
presented in Figure @ref(fig:plotexampleLU).

![Landuse suitability for 8 different landuses in the aarhus
commune](how_to_use_files/figure-html/plotexampleLU-1.png)

Landuse suitability for 8 different landuses in the aarhus commune

## Using SpeciesPoolR Manually

### Importing and Downloading Species Presences

#### Step 1: Reading and Filtering Data

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
#> Rows: 200 Columns: 8
#> ── Column specification ────────────────────────────────────────────────────────
#> Delimiter: ","
#> chr (8): redlist_2010, Kingdom, Phyllum, Class, Order, Family, Genus, Species
#> 
#> ℹ Use `spec()` to retrieve the full column specification for this data.
#> ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.
```

This will generate a dataset that can be used subsequently to count
species presences and download species data as seen in table
@ref(tab:tablespecies)

| redlist_2010 | Kingdom | Phyllum | Class | Order | Family | Genus | Species |
|:---|:---|:---|:---|:---|:---|:---|:---|
| NA | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Vicia | Vicia sepium |
| NA | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Genista | Genista tinctoria |
| NA | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Trifolium | Trifolium vesiculosum |
| LC | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Vicia | Vicia sativa |
| NA | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Lathyrus | Lathyrus latifolius |
| NA | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Anthyllis | Anthyllis vulneraria |
| NA | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Vicia | Vicia sepium |
| NA | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Lathyrus | Lathyrus japonicus |
| NA | Plantae | Magnoliophyta | Magnoliopsida | Fabales | Fabaceae | Vicia | Vicia villosa |

Species that will be used to generate species pools {.table}

## References

Boyd, Jennifer Nagel, Jill T. Anderson, Jessica R. Brzyski, Carol J.
Baskauf, and J. Cruse-Sanders. 2022. “Eco-Evolutionary Causes and
Consequences of Rarity in Plants: A Meta-Analysis.” *The New
Phytologist*, ahead of print. <https://doi.org/10.1111/nph.18172>.

Bregović, Petra, C. Fišer, and M. Zagmajster. 2019. “Contribution of
Rare and Common Species to Subterranean Species Richness Patterns.”
*Ecology and Evolution* 9: 11606–18.
<https://doi.org/10.1002/ece3.5604>.

Chapman, Abbie S. A., V. Tunnicliffe, and A. Bates. 2018. “Both Rare and
Common Species Make Unique Contributions to Functional Diversity in an
Ecosystem Unaffected by Human Activities.” *Diversity and Distributions*
24: 568–78. <https://doi.org/10.1111/ddi.12712>.

Drake, John M. 2015. “Range Bagging: A New Method for Ecological Niche
Modelling from Presence-Only Data.” *Journal of the Royal Society
Interface* 12 (107): 20150086.

Guisan, Antoine, Olivier Broennimann, Robin Engler, et al. 2006. “Using
Niche-Based Models to Improve the Sampling of Rare Species.”
*Conservation Biology* 20 (2): 501–11.

Magurran, A., and P. Henderson. 2003. “Explaining the Excess of Rare
Species in Natural Species Abundance Distributions.” *Nature* 422:
714–16. <https://doi.org/10.1038/nature01547>.

Proosdij, A. V., M. Sosef, J. Wieringa, and N. Raes. 2016. “Minimum
Required Number of Specimen Records to Develop Accurate Species
Distribution Models.” *Ecography* 39: 542–52.
<https://doi.org/10.1111/ECOG.01509>.

Reddin, Carl J., J. Bothwell, and J. Lennon. 2015. “Between-Taxon
Matching of Common and Rare Species Richness Patterns.” *Global Ecology
and Biogeography* 24: 1476–86. <https://doi.org/10.1111/GEB.12372>.

Sampaio, A. C. G., and A. Cavalcante. 2023. “Accurate Species
Distribution Models: Minimum Required Number of Specimen Records in the
Caatinga Biome.” *Anais Da Academia Brasileira de Ciencias* 95 2:
e20201421. <https://doi.org/10.1590/0001-3765202320201421>.

Säterberg, Torbjörn, T. Jonsson, J. Yearsley, Sofia Berg, and B.
Ebenman. 2019. “A Potential Role for Rare Species in Ecosystem
Dynamics.” *Scientific Reports* 9.
<https://doi.org/10.1038/s41598-019-47541-6>.

Schalkwyk, J., J. Pryke, and M. Samways. 2019. “Contribution of Common
Vs. Rare Species to Species Diversity Patterns in Conservation
Corridors.” *Ecological Indicators*, ahead of print.
<https://doi.org/10.1016/J.ECOLIND.2019.05.014>.

Støa, Bente, R. Halvorsen, J. Stokland, and V. I. Gusarov. 2019. “How
Much Is Enough? Influence of Number of Presence Observations on the
Performance of Species Distribution Models.” *Sommerfeltia* 39: 1–28.
<https://doi.org/10.2478/som-2019-0001>.

Thuiller, Wilfried, Sandra Lavorel, Miguel B. Araújo, Martin T. Sykes,
and I. Colin Prentice. 2005. “Climate Change Threats to Plant Diversity
in Europe.” *Proceedings of the National Academy of Sciences* 102 (23):
8245–50. <https://doi.org/10.1073/pnas.0409902102>.

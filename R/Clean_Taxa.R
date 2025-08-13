#' @title Clean taxa using Taxize
#'
#' @description
#' This function cleans a vector of taxa using the Global Names Architecture
#' via the \pkg{taxize} package.
#'
#' @param Taxons Vector of taxa to be cleaned.
#' @param WriteFile logical; if FALSE (default) only returns a
#'   data frame, if TRUE will generate a folder (Results) in the
#'   working directory with a CSV of the results.
#' @param verbose logical; if TRUE, prints progress and summary
#'   messages (default: TRUE).
#'
#' @return A data frame with the cleaned taxa and their scores.
#'
#' @export
#'
#' @examples
#' Clean_Taxa_Taxize(
#'   Taxons =  c("Abies concolor", "Abies lowiana", "Canis lupus", "Cannis lupus"),
#'   verbose = TRUE
#' )
#'
#' @importFrom taxize gna_verifier
#' @importFrom dplyr select filter group_by ungroup rename left_join
#' @importFrom readr write_csv
#' @importFrom tibble rowid_to_column
Clean_Taxa_Taxize <- function(Taxons, WriteFile = FALSE, verbose = TRUE) {
  score <- matched_name2 <- TaxaID <- user_supplied_name <- Taxa <- fuzzyLessScore <- currentCanonicalFull <- submittedName <- NULL

  NewTaxa <- data.frame(Taxa = Taxons, score = NA, matched_name2 = NA) |>
    tibble::rowid_to_column(var = "TaxaID")

  if (WriteFile) dir.create("Results", showWarnings = FALSE)

  # Try vectorized form first
  Temp <- tryCatch(
    taxize::gna_verifier(NewTaxa$Taxa, data_sources = 11, capitalize = TRUE, fuzzy_uninomial = TRUE),
    error = function(e) NULL
  )

  # If vectorized form fails, use loop
  if (is.null(Temp)) {
    if (verbose) message("Vectorized form did not work, switching to loop.")
    for (i in 1:nrow(NewTaxa)) {
      try({
        Temp <- taxize::gna_verifier(
          NewTaxa$Taxa[i],
          data_sources = 11,
          capitalize = TRUE,
          fuzzy_uninomial = TRUE
        ) |>
          dplyr::select(fuzzyLessScore, currentCanonicalFull) |>
          dplyr::rename(score = fuzzyLessScore)

        NewTaxa[i, 3:4] <- Temp
      })
      if (verbose && (i %% 50) == 0) {
        message(paste(i, "of", nrow(NewTaxa), "processed at", Sys.time()))
      }
      gc()
    }
  } else {
    NewTaxa <- Temp |>
      dplyr::rename(Taxa = submittedName) |>
      dplyr::select(Taxa, fuzzyLessScore, currentCanonicalFull) |>
      dplyr::left_join(dplyr::select(NewTaxa, TaxaID, Taxa), by = "Taxa") |>
      dplyr::rename(score = fuzzyLessScore)
  }

  if (WriteFile) {
    readr::write_csv(NewTaxa, "Results/Cleaned_Taxa_Taxize.csv")
  }

  Cleaned_Taxize <- NewTaxa |>
    dplyr::filter(!is.na(currentCanonicalFull)) |>
    dplyr::group_by(currentCanonicalFull) |>
    dplyr::filter(TaxaID == min(TaxaID)) |>
    dplyr::ungroup()

  if (verbose) {
    n_resolved <- sum(!is.na(NewTaxa$currentCanonicalFull))
    n_unique <- nrow(Cleaned_Taxize)
    message(sprintf(
      "%d of %d names resolved; %d unique accepted names (non-synonyms).",
      n_resolved, length(Taxons), n_unique
    ))
  }

  return(Cleaned_Taxize)
}


#' @title Clean Taxa from GBIF
#' @description Clean the taxonomic list using GBIF.
#' @param Cleaned_Taxize a data frame containing the cleaned taxonomic list from \code{Clean_Taxa_Taxize}.
#' @param Species_Only logical; if TRUE (default) only species will be returned, if FALSE returns highest possible taxonomic resolution.
#' @param WriteFile logical; if FALSE (default) only returns a data frame, if TRUE will generate a folder (Results) with a CSV.
#' @param verbose logical; if TRUE, prints progress and summary messages (default: FALSE).
#' @return A data frame containing the GBIF-cleaned taxonomic list.
#' @export
#'
#' @examples
#' \dontrun{
#' Cleaned_Taxize <- Clean_Taxa_Taxize(c("Abies concolor", "Canis lupus"), verbose = TRUE)
#' Clean_Taxa_rgbif(Cleaned_Taxize, verbose = TRUE)
#' }
Clean_Taxa_rgbif <- function(Cleaned_Taxize, WriteFile = FALSE, Species_Only = TRUE, verbose = FALSE) {
  verbatim_name <- currentCanonicalFull <- Taxa <- confidence <- kingdom <- phylum <- family <- genus <- species <- canonicalName <- NULL

  if (WriteFile) dir.create("Results", showWarnings = FALSE)

  rgbif_find <- rgbif::name_backbone_checklist(Cleaned_Taxize$currentCanonicalFull) |>
    dplyr::rename(currentCanonicalFull = verbatim_name) |>
    dplyr::relocate(currentCanonicalFull, .before = dplyr::everything()) |>
    dplyr::left_join(Cleaned_Taxize, by = "currentCanonicalFull") |>
    dplyr::select(Taxa, currentCanonicalFull, confidence, canonicalName, kingdom, phylum, class, order, family, genus, species, rank)

  if (WriteFile) {
    readr::write_csv(rgbif_find, "Results/Cleaned_Taxa_rgbif.csv")
  }

  if (Species_Only) {
    FinalSpeciesList <- rgbif_find |>
      dplyr::filter(!is.na(species)) |>
      dplyr::group_by(species) |>
      dplyr::filter(confidence == max(confidence)) |>
      dplyr::ungroup()
  } else {
    FinalSpeciesList <- rgbif_find |>
      dplyr::group_by(canonicalName) |>
      dplyr::filter(confidence == max(confidence)) |>
      dplyr::ungroup()
  }

  if (WriteFile) {
    readr::write_csv(FinalSpeciesList, "Results/FinalSpeciesList.csv")
  }

  if (verbose) {
    message(sprintf(
      "%d taxa retained after GBIF cleaning (%s only).",
      nrow(FinalSpeciesList),
      ifelse(Species_Only, "species", "all ranks")
    ))
  }

  return(FinalSpeciesList)
}


#' @title Clean taxa using Taxize and rgbif
#'
#' @description
#' This function cleans a vector of taxa using Taxize and rgbif sequentially.
#'
#' @param Taxons Vector of taxa to be cleaned.
#' @param WriteFile logical; if FALSE (default) only returns a data frame, if TRUE will generate a folder (Results) with CSVs.
#' @param Species_Only logical; if TRUE (default) only species will be returned, if FALSE returns highest possible taxonomic resolution.
#' @param verbose logical; if TRUE, prints progress and summary messages (default: TRUE).
#'
#' @return A data frame with the cleaned taxa and their scores.
#'
#' @export
#'
#' @examples
#' Cleaned <- Clean_Taxa(c("Canis lupus", "C. lupus"), verbose = TRUE)
Clean_Taxa <- function(Taxons, WriteFile = FALSE, Species_Only = TRUE, verbose = TRUE) {
  if (length(Taxons) < 10000) {
    Cleaned_Taxize <- Clean_Taxa_Taxize(Taxons = Taxons, WriteFile = WriteFile, verbose = verbose)
    Final_Result <- Clean_Taxa_rgbif(Cleaned_Taxize, WriteFile = WriteFile, Species_Only = Species_Only, verbose = verbose)
  } else {
    if (verbose) message("More than 10000 taxons; processing in chunks of 1000.")
    Taxons <- split(Taxons, ceiling(seq_along(Taxons) / 1000))
    Final_Result <- list()
    for (i in seq_along(Taxons)) {
      Cleaned_Taxize <- Clean_Taxa_Taxize(Taxons = Taxons[[i]], WriteFile = WriteFile, verbose = verbose)
      Final_Result[[i]] <- Clean_Taxa_rgbif(Cleaned_Taxize, WriteFile = WriteFile, Species_Only = Species_Only, verbose = verbose)
      if (verbose) message(paste("Chunk", i, "of", length(Taxons), "ready at", Sys.time()))
    }
    Final_Result <- purrr::reduce(Final_Result, rbind)
  }
  return(Final_Result)
}

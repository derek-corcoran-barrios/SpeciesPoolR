#' Filter for Species Covered by rtrees Megatrees
#'
#' Returns a `quote()`d filter expression (for `get_data(file, filter = ...)`,
#' same convention as any other manual filter) that keeps only species in
#' taxonomic groups `rtrees::get_tree()` can currently build a phylogeny
#' for: plants, and among animals, birds, mammals, amphibians, reptiles,
#' cartilaginous fish, bony fish, bees, and butterflies. See
#' `rtrees::taxa_supported()` for the authoritative, currently-installed
#' group list -- this filter should be kept in sync with it by hand, since
#' it can't be queried from inside a `quote()`d expression.
#'
#' Bees and butterflies aren't full taxonomic ranks in GBIF's backbone (a
#' `Class`/`Order` filter can't isolate them the way it can for
#' vertebrates), so they're matched by family instead: bee families are the
#' superfamily Anthophila (Andrenidae, Apidae, Colletidae, Halictidae,
#' Megachilidae, Melittidae, Stenotritidae); butterfly families are the
#' superfamily Papilionoidea (Papilionidae, Pieridae, Nymphalidae,
#' Lycaenidae, Hesperiidae, Riodinidae).
#'
#' Everything else -- all fungi, and most insects (beetles, flies, non-bee
#' Hymenoptera, non-butterfly Lepidoptera, true bugs), arachnids, and other
#' invertebrates -- is excluded here, since `rtrees` has no megatree for
#' them yet. For a typical multi-taxon species list, that excluded set is
#' usually most of the list by species count, not a minority.
#'
#' @return A `quote()`d filter expression, meant to be passed directly:
#'   `get_data(file, filter = rtrees_supported_filter())`.
#'
#' @export
rtrees_supported_filter <- function() {
  quote(
    Kingdom == "Plantae" |
      Class == "Aves" |
      Class == "Mammalia" |
      Class == "Amphibia" |
      Class %in% c("Reptilia", "Squamata", "Testudines", "Crocodylia") |
      Class == "Chondrichthyes" |
      Class %in% c("Actinopterygii", "Sarcopterygii") |
      Family %in% c(
        "Andrenidae", "Apidae", "Colletidae", "Halictidae",
        "Megachilidae", "Melittidae", "Stenotritidae"
      ) |
      Family %in% c(
        "Papilionidae", "Pieridae", "Nymphalidae",
        "Lycaenidae", "Hesperiidae", "Riodinidae"
      )
  )
}

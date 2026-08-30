test_that("rtrees_supported_filter uses the Clean_Taxa column schema", {
  taxa <- data.frame(
    species = paste("Species", seq_len(8L)),
    kingdom = c("Plantae", rep("Animalia", 7L)),
    class = c(
      "Magnoliopsida",
      "Aves",
      "Reptilia",
      "Testudines",
      "Insecta",
      "Insecta",
      "Insecta",
      "Arachnida"
    ),
    order = c(
      "Rosales",
      "Passeriformes",
      "Squamata",
      NA_character_,
      "Hymenoptera",
      "Lepidoptera",
      "Coleoptera",
      "Araneae"
    ),
    family = c(
      "Rosaceae",
      "Corvidae",
      "Colubridae",
      "Emydidae",
      "Apidae",
      "Nymphalidae",
      "Carabidae",
      "Lycosidae"
    ),
    stringsAsFactors = FALSE
  )

  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(taxa, path, row.names = FALSE)

  selected <- SpeciesPoolR::get_data(
    path,
    filter = SpeciesPoolR::rtrees_supported_filter()
  )

  expect_equal(
    selected$species,
    paste("Species", c(1L, 2L, 3L, 5L, 6L))
  )
})

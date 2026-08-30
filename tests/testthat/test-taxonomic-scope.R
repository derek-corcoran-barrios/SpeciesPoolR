test_that("rtrees_supported_filter uses the Clean_Taxa column schema", {
  taxa <- data.frame(
    species = paste("Species", seq_len(6L)),
    kingdom = c("Plantae", rep("Animalia", 5L)),
    class = c(
      "Magnoliopsida",
      "Aves",
      "Insecta",
      "Insecta",
      "Insecta",
      "Arachnida"
    ),
    family = c(
      "Rosaceae",
      "Corvidae",
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
    paste("Species", seq_len(4L))
  )
})

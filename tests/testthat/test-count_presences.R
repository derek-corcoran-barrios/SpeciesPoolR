test_that("GBIF facet counts are parsed from current rgbif facet data frames", {
  facets <- list(data.frame(
    name = c("Trifolium repens", "Vicia cracca"),
    count = c(12, 3)
  ))

  out <- SpeciesPoolR:::extract_gbif_facet_counts(facets)

  expect_s3_class(out, "data.table")
  expect_equal(out$species, c("Trifolium repens", "Vicia cracca"))
  expect_equal(out$N, c(12L, 3L))
})

test_that("GBIF facet counts are parsed from nested count lists", {
  facets <- list(list(counts = data.frame(
    name = "Trifolium repens",
    count = 12
  )))

  out <- SpeciesPoolR:::extract_gbif_facet_counts(facets)

  expect_equal(out$species, "Trifolium repens")
  expect_equal(out$N, 12L)
})

test_that("missing or malformed GBIF facet counts return an empty count table", {
  out <- SpeciesPoolR:::extract_gbif_facet_counts(list(data.frame(foo = character())))

  expect_s3_class(out, "data.table")
  expect_equal(names(out), c("species", "N"))
  expect_equal(nrow(out), 0L)
})

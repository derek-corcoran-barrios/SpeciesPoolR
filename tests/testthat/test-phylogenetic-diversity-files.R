make_pd_test_raster <- function(values, filename) {
  raster <- terra::rast(
    nrows = 2L,
    ncols = 2L,
    xmin = 0,
    xmax = 2000,
    ymin = 0,
    ymax = 2000,
    crs = "EPSG:3857"
  )
  terra::values(raster) <- values
  terra::writeRaster(raster, filename, overwrite = TRUE)
  filename
}

make_pd_file_fixture <- function() {
  directory <- tempfile("pd_files_")
  dir.create(directory)

  paths <- c(
    "Species one" = make_pd_test_raster(
      c(1, 1, 1, 0),
      file.path(directory, "one.tif")
    ),
    "Species two" = make_pd_test_raster(
      c(1, 0, 1, 0),
      file.path(directory, "two.tif")
    ),
    "Species three" = make_pd_test_raster(
      c(0, 1, 1, 1),
      file.path(directory, "three.tif")
    )
  )
  template <- make_pd_test_raster(
    rep(1, 4),
    file.path(directory, "template.tif")
  )
  tree <- ape::read.tree(
    text = "((Species_one:1,Species_two:1):2,Species_three:3);"
  )

  list(
    directory = directory,
    paths = paths,
    template = terra::rast(template),
    tree = tree
  )
}

test_that("taxonomic rows are assigned to exact rtrees group names", {
  taxonomy <- data.frame(
    Kingdom = c(
      "Plantae", rep("Animalia", 9L), "Fungi"
    ),
    Class = c(
      "Magnoliopsida",
      "Aves",
      "Mammalia",
      "Amphibia",
      "Squamata",
      "Chondrichthyes",
      "Actinopterygii",
      "Insecta",
      "Insecta",
      "Insecta",
      "Agaricomycetes"
    ),
    Family = c(
      "Rosaceae",
      "Corvidae",
      "Muridae",
      "Ranidae",
      "Colubridae",
      "Rajidae",
      "Cyprinidae",
      "Apidae",
      "Nymphalidae",
      "Carabidae",
      "Agaricaceae"
    ),
    stringsAsFactors = FALSE
  )

  expect_equal(
    classify_rtrees_group(taxonomy),
    c(
      "plant",
      "bird",
      "mammal",
      "amphibian",
      "reptile",
      "shark_ray",
      "fish",
      "bee",
      "butterfly",
      NA_character_,
      NA_character_
    )
  )
})

test_that("build_rtrees_tree prepares taxonomy and selects one tree", {
  first_tree <- ape::read.tree(text = "(First_species:1,Second_species:1);")
  second_tree <- ape::read.tree(text = "(First_species:2,Second_species:2);")
  tree_collection <- list(first_tree, second_tree)
  class(tree_collection) <- "multiPhylo"

  captured <- new.env(parent = emptyenv())
  builder <- function(...) {
    captured$arguments <- list(...)
    captured$arguments$tree
  }
  taxonomy <- data.frame(
    Species = c("First species", "Second species"),
    Genus = c("First", "Second"),
    Family = c("Firstidae", "Secondidae"),
    stringsAsFactors = FALSE
  )

  result <- build_rtrees_tree(
    species = taxonomy,
    group = "plant",
    tree = tree_collection,
    tree_index = 2L,
    .tree_builder = builder
  )

  expect_s3_class(result, "phylo")
  expect_equal(captured$arguments$sp_list$species, c(
    "First_species",
    "Second_species"
  ))
  expect_equal(captured$arguments$taxon, "plant")
  expect_true(captured$arguments$tree_by_user)
  expect_equal(captured$arguments$mc_cores, 1L)
  expect_equal(attr(result, "requested_species"), c(
    "First_species",
    "Second_species"
  ))
  expect_equal(attr(result, "rtrees_group"), "plant")
  expect_equal(attr(result, "rtrees_tree_index"), 2L)
})

test_that("tree coverage distinguishes matched and missing species", {
  tree <- ape::read.tree(text = "(Species_one:1,Species_two:1);")
  tree$tip.label[[1L]] <- paste0(tree$tip.label[[1L]], "*")
  tree$graft_status <- data.frame(
    tip_label = tree$tip.label,
    species = c("Species_one", "Species_two"),
    status = c("grafted at genus level", "existing species in the megatree"),
    stringsAsFactors = FALSE
  )
  attr(tree, "rtrees_group") <- "plant"

  audit <- audit_tree_coverage(
    c("Species one", "Species two", "Species absent"),
    tree
  )

  expect_equal(audit$group, rep("plant", 3L))
  expect_equal(audit$matched, c(TRUE, TRUE, FALSE))
  expect_equal(
    audit$coverage_status,
    c("matched", "matched", "missing_from_tree")
  )
  expect_equal(audit$tree_tip[[1L]], "Species_one*")
  expect_equal(audit$graft_status[[1L]], "grafted at genus level")
  expect_true(is.na(audit$tree_tip[[3L]]))
})

test_that("file-backed PD agrees with picante in multiple spatial blocks", {
  fixture <- make_pd_file_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  output_path <- file.path(fixture$directory, "pd.tif")
  result <- calc_pd_files(
    paths = fixture$paths,
    Tree = fixture$tree,
    template = fixture$template,
    filename = output_path,
    max_cells_per_block = 2L,
    verbose = FALSE
  )

  assemblage <- cbind(
    Species_one = c(1, 1, 1, 0),
    Species_two = c(1, 0, 1, 0),
    Species_three = c(0, 1, 1, 1)
  )
  expected <- suppressWarnings(
    picante::pd(
      samp = assemblage,
      tree = fixture$tree,
      include.root = FALSE
    )$PD
  )
  expected[is.na(expected)] <- 0

  expect_true(file.exists(output_path))
  expect_equal(
    as.numeric(terra::values(result)),
    expected,
    tolerance = 1e-10
  )
  expect_equal(as.numeric(terra::values(result)), c(2, 6, 7, 0))
})

test_that("include_root is equivalent to picante", {
  fixture <- make_pd_file_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  result <- calc_pd_files(
    paths = fixture$paths,
    Tree = fixture$tree,
    template = fixture$template,
    filename = file.path(fixture$directory, "pd_root.tif"),
    include_root = TRUE,
    max_cells_per_block = 2L,
    verbose = FALSE
  )
  assemblage <- cbind(
    Species_one = c(1, 1, 1, 0),
    Species_two = c(1, 0, 1, 0),
    Species_three = c(0, 1, 1, 1)
  )
  expected <- picante::pd(
    samp = assemblage,
    tree = fixture$tree,
    include.root = TRUE
  )$PD
  expected[is.na(expected)] <- 0

  expect_equal(
    as.numeric(terra::values(result)),
    expected,
    tolerance = 1e-10
  )
})

test_that("PD preserves the template domain", {
  fixture <- make_pd_file_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)
  terra::values(fixture$template) <- c(1, 1, NA, NA)

  result <- calc_pd_files(
    paths = fixture$paths,
    Tree = fixture$tree,
    template = fixture$template,
    filename = file.path(fixture$directory, "pd_domain.tif"),
    max_cells_per_block = 2L,
    verbose = FALSE
  )
  values <- as.numeric(terra::values(result))

  expect_equal(values[1:2], c(2, 6))
  expect_true(all(is.na(values[3:4])))
})

test_that("PD requires complete tree coverage by default", {
  fixture <- make_pd_file_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)
  incomplete_tree <- ape::drop.tip(fixture$tree, "Species_three")

  expect_error(
    calc_pd_files(
      paths = fixture$paths,
      Tree = incomplete_tree,
      template = fixture$template,
      filename = file.path(fixture$directory, "incomplete.tif"),
      verbose = FALSE
    ),
    "missing from `Tree`"
  )
})

test_that("PD rejects non-binary raster values", {
  fixture <- make_pd_file_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)
  invalid <- terra::rast(fixture$paths[[1L]])
  invalid_values <- terra::values(invalid)
  invalid_values[1L, 1L] <- 0.5
  terra::values(invalid) <- invalid_values
  invalid_path <- file.path(fixture$directory, "invalid_input.tif")
  terra::writeRaster(invalid, invalid_path, overwrite = TRUE)
  fixture$paths[[1L]] <- invalid_path

  expect_error(
    calc_pd_files(
      paths = fixture$paths,
      Tree = fixture$tree,
      template = fixture$template,
      filename = file.path(fixture$directory, "invalid.tif"),
      max_cells_per_block = 2L,
      verbose = FALSE
    ),
    "other than 0 or 1"
  )
})

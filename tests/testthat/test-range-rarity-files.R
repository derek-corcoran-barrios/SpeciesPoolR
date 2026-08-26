make_range_rarity_test_raster <- function(
    values,
    filename,
    nrows = 2L,
    ncols = 2L,
    xmin = 0,
    xmax = 2000,
    ymin = 0,
    ymax = 2000) {
  raster <- terra::rast(
    nrows = nrows,
    ncols = ncols,
    xmin = xmin,
    xmax = xmax,
    ymin = ymin,
    ymax = ymax,
    crs = "EPSG:3857"
  )
  terra::values(raster) <- values
  terra::writeRaster(raster, filename, overwrite = TRUE)
  filename
}

make_range_rarity_fixture <- function() {
  directory <- tempfile("range_rarity_files_")
  dir.create(directory)

  first <- make_range_rarity_test_raster(
    c(1, 1, 0, 0),
    file.path(directory, "first.tif")
  )
  second <- make_range_rarity_test_raster(
    c(0, 1, 1, 1),
    file.path(directory, "second.tif")
  )
  template_path <- make_range_rarity_test_raster(
    rep(1, 4),
    file.path(directory, "template.tif")
  )

  list(
    directory = directory,
    paths = c(
      "Species one" = first,
      "Species two" = second
    ),
    template = terra::rast(template_path)
  )
}

test_that("file-backed cell range weights have known values", {
  fixture <- make_range_rarity_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  weights <- calc_range_weights_files(
    paths = fixture$paths,
    template = fixture$template,
    unit = "cells",
    verbose = FALSE
  )

  expect_equal(weights$species, names(fixture$paths))
  expect_equal(weights$range_size, c(2, 3))
  expect_equal(weights$weight, c(1 / 2, 1 / 3))
  expect_equal(weights$range_unit, rep("cells", 2))
})

test_that("file-backed range rarity matches a known weighted sum", {
  fixture <- make_range_rarity_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  weights <- calc_range_weights_files(
    paths = fixture$paths,
    template = fixture$template,
    unit = "cells",
    verbose = FALSE
  )
  output_path <- file.path(fixture$directory, "range_rarity.tif")

  result <- calc_range_rarity_files(
    paths = fixture$paths,
    Weights = weights[2:1, , drop = FALSE],
    template = fixture$template,
    filename = output_path,
    chunk_size = 2L,
    verbose = FALSE
  )

  expect_true(file.exists(output_path))
  expect_true(any(
    normalizePath(
      as.character(terra::sources(result)),
      winslash = "/",
      mustWork = TRUE
    ) == normalizePath(output_path, winslash = "/", mustWork = TRUE)
  ))
  expect_equal(
    as.numeric(terra::values(result)),
    c(1 / 2, 1 / 2 + 1 / 3, 1 / 3, 1 / 3),
    tolerance = 1e-10
  )
})

test_that("file-backed and stack range rarity agree on an equal-area grid", {
  fixture <- make_range_rarity_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  weights <- calc_range_weights_files(
    paths = fixture$paths,
    template = fixture$template,
    unit = "cells",
    verbose = FALSE
  )
  output_path <- file.path(fixture$directory, "file_result.tif")

  file_result <- calc_range_rarity_files(
    paths = fixture$paths,
    Weights = weights,
    template = fixture$template,
    filename = output_path,
    chunk_size = 2L,
    verbose = FALSE
  )

  stack <- terra::rast(unname(fixture$paths))
  names(stack) <- names(fixture$paths)
  stack_result <- calc_range_rarity(stack, weights)

  expect_equal(
    as.numeric(terra::values(file_result)),
    as.numeric(terra::values(stack_result)),
    tolerance = 1e-10
  )
})

test_that("area-weighted baseline contributions sum to species count", {
  fixture <- make_range_rarity_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  weights <- calc_range_weights_files(
    paths = fixture$paths,
    template = fixture$template,
    unit = "km2",
    verbose = FALSE
  )
  output_path <- file.path(fixture$directory, "contribution.tif")

  contribution <- calc_range_rarity_files(
    paths = fixture$paths,
    Weights = weights,
    template = fixture$template,
    filename = output_path,
    output = "cell_contribution",
    chunk_size = 2L,
    verbose = FALSE
  )

  total <- terra::global(
    contribution,
    fun = "sum",
    na.rm = TRUE
  )[[1L]]
  expect_equal(total, 2, tolerance = 1e-8)
})

test_that("a species with no baseline range receives zero weight", {
  fixture <- make_range_rarity_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  zero_path <- make_range_rarity_test_raster(
    rep(0, 4),
    file.path(fixture$directory, "zero.tif")
  )
  paths <- c(fixture$paths, "Species zero" = zero_path)

  weights <- calc_range_weights_files(
    paths = paths,
    template = fixture$template,
    unit = "cells",
    verbose = FALSE
  )

  expect_equal(weights$range_size[[3L]], 0)
  expect_equal(weights$weight[[3L]], 0)
})

test_that("the template domain is preserved as NA", {
  fixture <- make_range_rarity_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  terra::values(fixture$template) <- c(1, 1, NA, NA)
  weights <- calc_range_weights_files(
    paths = fixture$paths,
    template = fixture$template,
    unit = "cells",
    verbose = FALSE
  )
  output_path <- file.path(fixture$directory, "domain.tif")

  result <- calc_range_rarity_files(
    paths = fixture$paths,
    Weights = weights,
    template = fixture$template,
    filename = output_path,
    chunk_size = 2L,
    verbose = FALSE
  )

  expect_equal(weights$range_size, c(2, 1))
  expect_true(all(is.na(as.numeric(terra::values(result))[3:4])))
})

test_that("geometry mismatch requires explicit nearest-neighbour alignment", {
  fixture <- make_range_rarity_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  different_path <- make_range_rarity_test_raster(
    rep(c(1, 0), each = 8),
    file.path(fixture$directory, "different.tif"),
    nrows = 4L,
    ncols = 4L
  )
  paths <- c("Different species" = different_path)

  expect_error(
    calc_range_weights_files(
      paths = paths,
      template = fixture$template,
      unit = "cells",
      align = "error",
      verbose = FALSE
    ),
    "geometry differs"
  )

  expect_no_error(
    calc_range_weights_files(
      paths = paths,
      template = fixture$template,
      unit = "cells",
      align = "near",
      verbose = FALSE
    )
  )
})

test_that("paths must be species-named and weights must be complete", {
  fixture <- make_range_rarity_fixture()
  on.exit(unlink(fixture$directory, recursive = TRUE), add = TRUE)

  expect_error(
    calc_range_weights_files(
      paths = unname(fixture$paths),
      template = fixture$template,
      verbose = FALSE
    ),
    "must be named"
  )

  incomplete_weights <- data.frame(
    species = "Species one",
    weight = 0.5,
    range_unit = "cells"
  )
  expect_error(
    calc_range_rarity_files(
      paths = fixture$paths,
      Weights = incomplete_weights,
      template = fixture$template,
      filename = file.path(fixture$directory, "missing_weight.tif"),
      chunk_size = 2L,
      verbose = FALSE
    ),
    "No baseline range-size weight"
  )
})

make_test_prediction_raster <- function() {
  climate <- terra::rast(
    nrows = 4,
    ncols = 5,
    xmin = 0,
    xmax = 5,
    ymin = 0,
    ymax = 4
  )
  terra::values(climate) <- seq_len(terra::ncell(climate)) / 100
  names(climate) <- "climate"

  landuse <- terra::rast(climate)
  terra::values(landuse) <- rep(c(1L, 2L), length.out = terra::ncell(landuse))
  levels(landuse) <- data.frame(
    ID = c(1L, 2L),
    Landuse = c("forest", "open")
  )
  names(landuse) <- "Landuse"

  c(climate, landuse)
}

make_test_maxnet <- function() {
  set.seed(20260819)

  training <- data.frame(
    climate = seq(0.001, 1, length.out = 400),
    Landuse = factor(
      rep(c("forest", "open"), length.out = 400),
      levels = c("forest", "open")
    )
  )

  probability <- stats::plogis(
    -1 +
      2 * training$climate +
      0.6 * (training$Landuse == "forest")
  )
  presence <- stats::rbinom(nrow(training), size = 1L, prob = probability)

  maxnet::maxnet(
    p = presence,
    data = training,
    f = maxnet::maxnet.formula(
      p = presence,
      data = training,
      classes = "l"
    ),
    addsamplestobackground = FALSE
  )
}

test_that("block prediction is file-backed and preserves factor labels", {
  env <- make_test_prediction_raster()
  model <- make_test_maxnet()

  output_file <- tempfile(fileext = ".tif")
  on.exit(unlink(output_file), add = TRUE)

  result <- SpeciesPoolR:::predict_maxnet_raster(
    Env = env,
    Mod = model,
    filename = output_file,
    blocks_in_memory = 4L
  )

  input <- terra::as.data.frame(env)
  expected <- as.numeric(
    stats::predict(
      model,
      newdata = input,
      type = "cloglog"
    )
  )

  expect_s4_class(result, "SpatRaster")
  expect_true(nzchar(terra::sources(result)[1]))
  expect_equal(
    terra::values(result, mat = FALSE),
    expected,
    tolerance = 1e-6
  )
})

test_that("block prediction preserves cells with incomplete predictors as NA", {
  env <- make_test_prediction_raster()
  climate_values <- terra::values(env[["climate"]], mat = FALSE)
  climate_values[3] <- NA_real_
  terra::values(env[["climate"]]) <- climate_values

  result <- SpeciesPoolR:::predict_maxnet_raster(
    Env = env,
    Mod = make_test_maxnet(),
    blocks_in_memory = 4L
  )

  expect_true(is.na(terra::values(result, mat = FALSE)[3]))
})

test_that("NULL models receive a file-backed zero raster", {
  result <- PredictSuitability(
    Models = list("Test species" = NULL),
    file = make_test_prediction_raster(),
    categorical = "Landuse",
    blocks_in_memory = 4L
  )

  expect_identical(names(result), "Test species")
  expect_true(nzchar(terra::sources(result)[1]))
  expect_true(all(terra::values(result, mat = FALSE) == 0))
})

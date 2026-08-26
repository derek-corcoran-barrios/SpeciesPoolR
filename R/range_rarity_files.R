#' File-backed range-size rarity
#'
#' These functions calculate baseline range-size weights and range-size rarity
#' from named, single-layer binary raster files. They are intended for large
#' workflows where combining every species into one `SpatRaster` would use too
#' much memory.
#'
#' @name range_rarity_files
NULL

.range_rarity_assert_scalar_character <- function(x, argument) {
  if (
    !is.character(x) ||
      length(x) != 1L ||
      is.na(x) ||
      !nzchar(x)
  ) {
    stop(
      "`", argument, "` must be one non-empty character value.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

.validate_named_binary_paths <- function(paths) {
  species <- names(paths)
  paths <- as.character(paths)

  if (length(paths) == 0L) {
    stop("`paths` must contain at least one raster file.", call. = FALSE)
  }

  if (
    is.null(species) ||
      length(species) != length(paths) ||
      anyNA(species) ||
      any(!nzchar(species))
  ) {
    stop(
      "`paths` must be named with exactly one species name per raster.",
      call. = FALSE
    )
  }

  species_key <- normalize_species_name(species)
  if (anyDuplicated(species_key)) {
    duplicated_species <- unique(species[duplicated(species_key)])
    stop(
      "Species names are not unique after normalization: ",
      paste(duplicated_species, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  if (anyDuplicated(paths)) {
    stop("Each species must have a different binary raster file.", call. = FALSE)
  }

  missing_paths <- paths[!file.exists(paths)]
  if (length(missing_paths) > 0L) {
    stop(
      "Binary raster files do not exist: ",
      paste(utils::head(missing_paths, 20L), collapse = ", "),
      if (length(missing_paths) > 20L) " ..." else "",
      call. = FALSE
    )
  }

  stats::setNames(paths, species)
}

.range_rarity_domain <- function(template) {
  if (
    !inherits(template, "SpatRaster") &&
      !(is.character(template) && length(template) > 0L)
  ) {
    stop(
      "`template` must be a SpatRaster or raster file path vector.",
      call. = FALSE
    )
  }

  make_predictor_domain(template)
}

.prepare_binary_for_domain <- function(path, domain, align) {
  binary <- terra::rast(path)

  if (terra::nlyr(binary) != 1L) {
    stop(
      "Every binary raster file must contain exactly one layer: ",
      path,
      call. = FALSE
    )
  }

  same_geometry <- terra::compareGeom(
    binary,
    domain,
    stopOnError = FALSE
  )

  if (isTRUE(same_geometry)) {
    return(list(raster = binary, temporary = NA_character_))
  }

  if (identical(align, "error")) {
    stop(
      "Binary raster geometry differs from `template`: ",
      path,
      ". Use `align = \"near\"` only when nearest-neighbour alignment is ",
      "scientifically appropriate.",
      call. = FALSE
    )
  }

  temporary <- tempfile(
    pattern = "SpeciesPoolR_binary_aligned_",
    fileext = ".tif"
  )
  completed <- FALSE
  on.exit({
    if (!completed && file.exists(temporary)) {
      unlink(temporary, force = TRUE)
    }
  }, add = TRUE)

  binary <- terra::resample(
    binary,
    domain,
    method = "near",
    filename = temporary,
    overwrite = TRUE,
    wopt = list(
      datatype = "INT1U",
      NAflag = 255,
      gdal = c("COMPRESS=DEFLATE", "TILED=YES")
    )
  )

  completed <- TRUE
  list(raster = binary, temporary = temporary)
}

.range_rarity_unit <- function(weights) {
  unit <- if ("range_unit" %in% names(weights)) {
    unique(as.character(weights$range_unit))
  } else {
    attr(weights, "range_unit", exact = TRUE)
  }

  unit <- unit[!is.na(unit) & nzchar(unit)]
  if (length(unit) != 1L || !unit %in% c("cells", "km2")) {
    stop(
      "`Weights` must identify one `range_unit`: `cells` or `km2`.",
      call. = FALSE
    )
  }

  unit
}

.match_range_rarity_weights <- function(paths, weights) {
  if (!is.data.frame(weights)) {
    stop("`Weights` must be a data frame.", call. = FALSE)
  }

  required <- c("species", "weight")
  missing_columns <- setdiff(required, names(weights))
  if (length(missing_columns) > 0L) {
    stop(
      "`Weights` must contain: ",
      paste(required, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  path_species <- normalize_species_name(names(paths))
  weight_species <- normalize_species_name(as.character(weights$species))

  if (anyDuplicated(weight_species)) {
    stop(
      "`Weights$species` is not unique after normalization.",
      call. = FALSE
    )
  }

  index <- match(path_species, weight_species)
  if (anyNA(index)) {
    missing_species <- names(paths)[is.na(index)]
    stop(
      "No baseline range-size weight was found for: ",
      paste(missing_species, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  selected <- as.numeric(weights$weight[index])
  if (any(!is.finite(selected)) || any(selected < 0)) {
    stop(
      "All selected range-size weights must be finite and non-negative.",
      call. = FALSE
    )
  }

  stats::setNames(selected, names(paths))
}

#' Calculate baseline range-size weights from raster files
#'
#' Reads one binary species raster at a time and calculates its baseline range
#' size inside a common comparison domain. This avoids constructing a complete
#' cells-by-species raster stack.
#'
#' Range sizes should normally be calculated once from current-condition
#' projections and reused unchanged for all scenarios. With `unit = "km2"`,
#' the range size of species \eqn{i} is
#'
#' \deqn{A_i = \sum_j B_{ij} a_j,}
#'
#' where \eqn{B_{ij}} is binary presence and \eqn{a_j} is cell area in square
#' kilometres. The corresponding weight is \eqn{w_i = 1 / A_i}.
#'
#' @param paths Named character vector of single-layer binary raster files.
#'   Names must be species names. The named vector returned by
#'   [select_projection_paths()] is suitable.
#' @param template A `terra::SpatRaster` or raster file path vector defining
#'   the common output geometry and valid domain. A cell is included only when
#'   every template layer is non-missing.
#' @param unit Range-size unit: `"km2"` (recommended for longitude/latitude
#'   rasters) or `"cells"` for an equal-area grid.
#' @param align Geometry handling. `"error"` requires every binary raster to
#'   match `template`. `"near"` aligns mismatched binary rasters to the
#'   template with nearest-neighbour resampling.
#' @param verbose Whether to report progress. Default `TRUE`.
#'
#' @return A data frame containing `species`, `range_size`, `weight`,
#'   `range_unit`, and `binary_path`. A species with no occupied baseline cells
#'   receives weight zero.
#' @export
calc_range_weights_files <- function(
    paths,
    template,
    unit = c("km2", "cells"),
    align = c("error", "near"),
    verbose = TRUE) {
  paths <- .validate_named_binary_paths(paths)
  unit <- match.arg(unit)
  align <- match.arg(align)
  domain <- .range_rarity_domain(template)

  cell_area <- if (identical(unit, "km2")) {
    area <- terra::cellSize(domain, unit = "km")
    terra::mask(area, domain)
  } else {
    NULL
  }

  range_size <- numeric(length(paths))

  for (index in seq_along(paths)) {
    prepared <- .prepare_binary_for_domain(
      path = unname(paths[[index]]),
      domain = domain,
      align = align
    )

    binary <- prepared$raster
    quantity <- if (identical(unit, "km2")) {
      binary * cell_area
    } else {
      binary * domain
    }

    value <- terra::global(
      quantity,
      fun = "sum",
      na.rm = TRUE
    )[[1L]]

    if (length(value) != 1L || is.na(value)) {
      value <- 0
    }
    if (!is.finite(value) || value < 0) {
      stop(
        "Invalid range size calculated for ", names(paths)[[index]], ".",
        call. = FALSE
      )
    }
    range_size[[index]] <- value

    temporary <- prepared$temporary
    rm(binary, quantity, prepared)
    if (!is.na(temporary) && file.exists(temporary)) {
      invisible(gc())
      unlink(temporary, force = TRUE)
    }

    if (
      isTRUE(verbose) &&
        (index == 1L || index %% 100L == 0L || index == length(paths))
    ) {
      message(
        "Calculated baseline range size for ", index,
        " of ", length(paths), " species."
      )
    }
  }

  weight <- ifelse(range_size > 0, 1 / range_size, 0)
  out <- data.frame(
    species = names(paths),
    range_size = as.numeric(range_size),
    weight = as.numeric(weight),
    range_unit = unit,
    binary_path = unname(paths),
    stringsAsFactors = FALSE
  )

  attr(out, "range_unit") <- unit
  out
}

#' Calculate file-backed range-size rarity
#'
#' Calculates range-size rarity from named binary raster files using a bounded
#' tree reduction. At most `chunk_size` species rasters are opened for one
#' first-level sum, and only partial sums are opened at later levels.
#'
#' Baseline weights are matched to files by normalized species name, never by
#' row position. Supply the same baseline `Weights` for current conditions and
#' every scenario.
#'
#' `output = "density"` returns \eqn{\sum_i B_{ij} / A_i}. For kilometre-based
#' weights, `output = "cell_contribution"` multiplies this value by cell area,
#' so each species contributes a total of one across its baseline range. On an
#' equal-area cell-count analysis, density and cell contribution are the same.
#'
#' @param paths Named character vector of single-layer binary raster files,
#'   normally returned by [select_projection_paths()].
#' @param Weights Baseline weight table returned by
#'   [calc_range_weights_files()] or [calc_range_weights()].
#' @param template A `terra::SpatRaster` or raster file path vector defining
#'   the common geometry and non-missing output domain.
#' @param filename Output GeoTIFF path.
#' @param name Output raster-layer name. Default `"RangeRarity"`.
#' @param output Either `"density"` or `"cell_contribution"`.
#' @param chunk_size Maximum number of species rasters opened in a first-level
#'   reduction. Default `50L`.
#' @param align Geometry handling. See [calc_range_weights_files()].
#' @param overwrite Whether `filename` may be replaced. Default `TRUE`.
#' @param verbose Whether to report reduction progress. Default `TRUE`.
#'
#' @return A file-backed, single-layer `terra::SpatRaster`.
#' @export
calc_range_rarity_files <- function(
    paths,
    Weights,
    template,
    filename,
    name = "RangeRarity",
    output = c("density", "cell_contribution"),
    chunk_size = 50L,
    align = c("error", "near"),
    overwrite = TRUE,
    verbose = TRUE) {
  paths <- .validate_named_binary_paths(paths)
  output <- match.arg(output)
  align <- match.arg(align)
  .range_rarity_assert_scalar_character(filename, "filename")
  .range_rarity_assert_scalar_character(name, "name")

  chunk_size <- as.integer(chunk_size)
  if (
    length(chunk_size) != 1L ||
      is.na(chunk_size) ||
      chunk_size < 2L
  ) {
    stop("`chunk_size` must be an integer of at least 2.", call. = FALSE)
  }

  if (file.exists(filename) && !isTRUE(overwrite)) {
    stop("Output raster already exists: ", filename, call. = FALSE)
  }

  input_paths <- normalizePath(paths, winslash = "/", mustWork = TRUE)
  output_path <- normalizePath(filename, winslash = "/", mustWork = FALSE)
  if (.Platform$OS.type == "windows") {
    input_paths <- tolower(input_paths)
    output_path <- tolower(output_path)
  }
  if (output_path %in% input_paths) {
    stop("`filename` must not overwrite an input raster.", call. = FALSE)
  }

  weights <- .match_range_rarity_weights(paths, Weights)
  range_unit <- .range_rarity_unit(Weights)
  domain <- .range_rarity_domain(template)
  dir.create(dirname(filename), recursive = TRUE, showWarnings = FALSE)

  temporary_files <- character()
  on.exit({
    existing <- temporary_files[file.exists(temporary_files)]
    if (length(existing) > 0L) {
      unlink(existing, force = TRUE)
    }
  }, add = TRUE)

  groups <- split(
    seq_along(paths),
    ceiling(seq_along(paths) / chunk_size)
  )

  current_level <- vapply(seq_along(groups), function(group_number) {
    group_index <- groups[[group_number]]
    prepared <- lapply(group_index, function(index) {
      .prepare_binary_for_domain(
        path = unname(paths[[index]]),
        domain = domain,
        align = align
      )
    })

    aligned_temporary <- vapply(
      prepared,
      function(x) x$temporary,
      character(1)
    )
    aligned_temporary <- aligned_temporary[
      !is.na(aligned_temporary) & nzchar(aligned_temporary)
    ]
    temporary_files <<- c(temporary_files, aligned_temporary)

    weighted_layers <- Map(
      function(x, weight) x$raster * as.numeric(weight),
      prepared,
      unname(weights[group_index])
    )
    weighted_stack <- if (length(weighted_layers) == 1L) {
      weighted_layers[[1L]]
    } else {
      do.call(c, weighted_layers)
    }

    partial_path <- tempfile(
      pattern = "SpeciesPoolR_range_rarity_level_1_",
      fileext = ".tif"
    )
    temporary_files <<- c(temporary_files, partial_path)

    partial <- terra::app(
      weighted_stack,
      fun = "sum",
      na.rm = TRUE,
      filename = partial_path,
      overwrite = TRUE,
      wopt = list(
        datatype = "FLT8S",
        gdal = c("COMPRESS=DEFLATE", "TILED=YES")
      )
    )

    rm(partial, weighted_stack, weighted_layers, prepared)
    invisible(gc())
    existing_aligned <- aligned_temporary[file.exists(aligned_temporary)]
    if (length(existing_aligned) > 0L) {
      unlink(existing_aligned, force = TRUE)
    }
    temporary_files <<- setdiff(temporary_files, aligned_temporary)

    if (isTRUE(verbose)) {
      message(
        "Completed weighted group ", group_number,
        " of ", length(groups), "."
      )
    }

    partial_path
  }, character(1))

  level_number <- 1L
  while (length(current_level) > 1L) {
    level_number <- level_number + 1L
    level_groups <- split(
      current_level,
      ceiling(seq_along(current_level) / chunk_size)
    )

    next_level <- vapply(seq_along(level_groups), function(group_number) {
      group_paths <- level_groups[[group_number]]
      if (length(group_paths) == 1L) {
        return(group_paths[[1L]])
      }

      partial_path <- tempfile(
        pattern = paste0(
          "SpeciesPoolR_range_rarity_level_",
          level_number,
          "_"
        ),
        fileext = ".tif"
      )
      temporary_files <<- c(temporary_files, partial_path)

      partial <- terra::app(
        terra::rast(group_paths),
        fun = "sum",
        na.rm = TRUE,
        filename = partial_path,
        overwrite = TRUE,
        wopt = list(
          datatype = "FLT8S",
          gdal = c("COMPRESS=DEFLATE", "TILED=YES")
        )
      )
      rm(partial)
      invisible(gc())
      partial_path
    }, character(1))

    obsolete <- setdiff(current_level, next_level)
    existing_obsolete <- obsolete[file.exists(obsolete)]
    if (length(existing_obsolete) > 0L) {
      unlink(existing_obsolete, force = TRUE)
    }
    temporary_files <- setdiff(temporary_files, obsolete)
    current_level <- next_level

    if (isTRUE(verbose)) {
      message(
        "Completed range-rarity reduction level ", level_number,
        "; ", length(current_level), " partial raster(s) remain."
      )
    }
  }

  total <- terra::rast(current_level[[1L]])
  result <- total
  if (
    identical(output, "cell_contribution") &&
      identical(range_unit, "km2")
  ) {
    cell_area <- terra::cellSize(domain, unit = "km")
    result <- result * terra::mask(cell_area, domain)
  }
  names(result) <- name

  out <- terra::mask(
    result,
    domain,
    filename = filename,
    overwrite = overwrite,
    wopt = list(
      datatype = "FLT8S",
      gdal = c("COMPRESS=DEFLATE", "TILED=YES")
    )
  )
  names(out) <- name

  rm(total, result, domain)
  invisible(gc())
  existing <- temporary_files[file.exists(temporary_files)]
  if (length(existing) > 0L) {
    unlink(existing, force = TRUE)
  }
  temporary_files <- character()

  out
}

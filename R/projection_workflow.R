#' Projection workflow helpers
#'
#' Utilities in this file standardize the small tabular products produced by
#' per-species projection branches. They are deliberately independent of
#' `targets`, so the same validation, auditing, and raster reduction logic can
#' be used in a targets pipeline, an interactive analysis, or another workflow
#' manager.
#'
#' @name projection_workflow
NULL

.projection_status_levels <- c(
  "projected",
  "model_failed",
  "insufficient_complete_presences",
  "no_finite_suitability",
  "non_finite_threshold",
  "skipped_current_projection_failed",
  "prediction_error",
  "model_branch_missing",
  "projection_missing"
)

.projection_terminal_statuses <- c(
  "model_failed",
  "insufficient_complete_presences",
  "no_finite_suitability",
  "non_finite_threshold",
  "skipped_current_projection_failed"
)

.empty_projection_status <- function() {
  data.frame(
    species = character(),
    scenario = character(),
    status = character(),
    reason = character(),
    binary_path = character(),
    threshold_path = character(),
    summary_path = character(),
    finite_cells = double(),
    complete_presence_records = integer(),
    stringsAsFactors = FALSE
  )
}

.assert_scalar_character <- function(x, argument, allow_na = FALSE) {
  valid <- is.character(x) && length(x) == 1L

  if (valid && !allow_na) {
    valid <- !is.na(x) && nzchar(x)
  }

  if (valid && allow_na && !is.na(x)) {
    valid <- nzchar(x)
  }

  if (!valid) {
    stop(
      "`", argument, "` must be one ",
      if (allow_na) "non-empty character value or NA." else
        "non-empty character value.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

.validate_projection_status <- function(x, allow_empty = TRUE) {
  if (!is.data.frame(x)) {
    stop("Projection status data must be a data frame.", call. = FALSE)
  }

  required <- c(
    "species",
    "scenario",
    "status",
    "reason",
    "binary_path",
    "threshold_path",
    "summary_path",
    "finite_cells",
    "complete_presence_records"
  )

  missing_columns <- setdiff(required, names(x))
  if (length(missing_columns) > 0L) {
    stop(
      "Projection status data are missing: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  if (!allow_empty && nrow(x) == 0L) {
    stop("Projection status data must contain at least one row.", call. = FALSE)
  }

  if (nrow(x) == 0L) {
    return(x)
  }

  x$species <- as.character(x$species)
  x$scenario <- as.character(x$scenario)
  x$status <- as.character(x$status)
  x$reason <- as.character(x$reason)
  x$binary_path <- as.character(x$binary_path)
  x$threshold_path <- as.character(x$threshold_path)
  x$summary_path <- as.character(x$summary_path)
  x$finite_cells <- as.double(x$finite_cells)
  x$complete_presence_records <- as.integer(x$complete_presence_records)

  if (anyNA(x$species) || any(!nzchar(x$species))) {
    stop("Every projection status row needs a species name.", call. = FALSE)
  }
  if (anyNA(x$scenario) || any(!nzchar(x$scenario))) {
    stop("Every projection status row needs a scenario name.", call. = FALSE)
  }

  invalid_status <- setdiff(unique(x$status), .projection_status_levels)
  if (length(invalid_status) > 0L) {
    stop(
      "Unknown projection status: ",
      paste(invalid_status, collapse = ", "),
      ". Allowed statuses are: ",
      paste(.projection_status_levels, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  key <- paste(x$scenario, x$species, sep = "\r")
  if (anyDuplicated(key)) {
    duplicated_key <- unique(key[duplicated(key)])
    stop(
      "Projection status data contain duplicate scenario/species rows: ",
      paste(utils::head(duplicated_key, 20L), collapse = ", "),
      call. = FALSE
    )
  }

  x
}

#' List recognized projection statuses
#'
#' Returns the controlled vocabulary used by [projection_status_record()],
#' [make_projection_audit()], and the projection-status marker files. A status
#' describes a branch outcome, not biological absence. In particular,
#' `"no_finite_suitability"` must never be replaced with a zero raster.
#'
#' @return A character vector of recognized status values.
#' @export
projection_status_levels <- function() {
  .projection_status_levels
}

#' List terminal projection exclusions
#'
#' Terminal statuses describe species which cannot be included in comparable
#' richness or diversity products without changing the data or model. By
#' contrast, `"prediction_error"`, `"model_branch_missing"`, and
#' `"projection_missing"` are unresolved failures which should be retried or
#' investigated rather than silently excluded.
#'
#' @return A character vector containing the default terminal statuses.
#' @export
projection_terminal_statuses <- function() {
  .projection_terminal_statuses
}

#' Create one standardized projection-status record
#'
#' Creates the one-row table written by a per-species, per-scenario projection
#' branch. Successful and unsuccessful branches use exactly the same schema,
#' which lets downstream audits distinguish a terminal scientific exclusion
#' from an unresolved computing failure.
#'
#' @param species Scientific name represented by the branch.
#' @param scenario Scenario name, including `"current"` for the baseline.
#' @param status One value returned by [projection_status_levels()].
#' @param reason Human-readable explanation. Use `NA_character_` when no
#'   explanation is needed.
#' @param binary_path,threshold_path,summary_path Paths to branch products, or
#'   `NA_character_` when that product was not created.
#' @param finite_cells Number of usable cells in the continuous suitability
#'   raster, or `NA_real_` if it was not evaluated.
#' @param complete_presence_records Number of occurrence records with complete
#'   predictor values, or `NA_integer_` if it was not evaluated.
#'
#' @return A one-row data frame following the SpeciesPoolR projection-status
#'   schema.
#' @export
projection_status_record <- function(
    species,
    scenario,
    status,
    reason = NA_character_,
    binary_path = NA_character_,
    threshold_path = NA_character_,
    summary_path = NA_character_,
    finite_cells = NA_real_,
    complete_presence_records = NA_integer_) {
  .assert_scalar_character(species, "species")
  .assert_scalar_character(scenario, "scenario")
  .assert_scalar_character(status, "status")
  .assert_scalar_character(reason, "reason", allow_na = TRUE)
  .assert_scalar_character(binary_path, "binary_path", allow_na = TRUE)
  .assert_scalar_character(threshold_path, "threshold_path", allow_na = TRUE)
  .assert_scalar_character(summary_path, "summary_path", allow_na = TRUE)

  if (!status %in% .projection_status_levels) {
    stop(
      "Unknown projection status `", status, "`. Allowed statuses are: ",
      paste(.projection_status_levels, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  if (
    length(finite_cells) != 1L ||
      (!is.na(finite_cells) && !is.finite(finite_cells)) ||
      (!is.na(finite_cells) && finite_cells < 0)
  ) {
    stop("`finite_cells` must be one non-negative number or NA.", call. = FALSE)
  }

  if (
    length(complete_presence_records) != 1L ||
      (!is.na(complete_presence_records) &&
        (!is.finite(complete_presence_records) ||
          complete_presence_records < 0 ||
          complete_presence_records != as.integer(complete_presence_records)))
  ) {
    stop(
      "`complete_presence_records` must be one non-negative integer or NA.",
      call. = FALSE
    )
  }

  .validate_projection_status(
    data.frame(
      species = species,
      scenario = scenario,
      status = status,
      reason = reason,
      binary_path = binary_path,
      threshold_path = threshold_path,
      summary_path = summary_path,
      finite_cells = as.double(finite_cells),
      complete_presence_records = as.integer(complete_presence_records),
      stringsAsFactors = FALSE
    ),
    allow_empty = FALSE
  )
}

#' Assess a completed continuous projection and threshold
#'
#' Converts objective projection checks into one standardized status record.
#' This function is intended to run inside a current-projection branch after
#' suitability prediction and threshold creation but before binary conversion.
#' It automatically flags insufficient predictor-complete occurrences, an
#' all-missing suitability raster, and a missing or non-finite threshold.
#'
#' @param suitability A single-layer `terra::SpatRaster` for one species.
#' @param thresholds A threshold table containing `species` and the requested
#'   `threshold` column.
#' @param species,scenario Species and scenario represented by the branch.
#' @param threshold Name of the threshold column to inspect.
#' @param complete_presence_records Number of predictor-complete occurrence
#'   records used for fitting.
#' @param minimum_complete_presences Minimum acceptable number of complete
#'   occurrence records. Default `7L`.
#'
#' @return A one-row projection-status record. A `"projected"` result means
#'   that the suitability surface and threshold passed these checks; it does
#'   not itself write the binary or summary products.
#' @export
assess_projection_status <- function(
    suitability,
    thresholds,
    species,
    scenario = "current",
    threshold = "Thres_95",
    complete_presence_records = NA_integer_,
    minimum_complete_presences = 7L) {
  if (!inherits(suitability, "SpatRaster")) {
    stop("`suitability` must be a terra SpatRaster.", call. = FALSE)
  }
  if (terra::nlyr(suitability) != 1L) {
    stop("`suitability` must contain exactly one species layer.", call. = FALSE)
  }
  .assert_scalar_character(species, "species")
  .assert_scalar_character(scenario, "scenario")
  .assert_scalar_character(threshold, "threshold")

  minimum_complete_presences <- as.integer(minimum_complete_presences)
  if (
    length(minimum_complete_presences) != 1L ||
      is.na(minimum_complete_presences) ||
      minimum_complete_presences < 1L
  ) {
    stop(
      "`minimum_complete_presences` must be one positive integer.",
      call. = FALSE
    )
  }

  if (
    length(complete_presence_records) != 1L ||
      (!is.na(complete_presence_records) &&
        (!is.finite(complete_presence_records) ||
          complete_presence_records < 0 ||
          complete_presence_records != as.integer(complete_presence_records)))
  ) {
    stop(
      "`complete_presence_records` must be one non-negative integer or NA.",
      call. = FALSE
    )
  }

  non_missing_cells <- terra::global(
    !is.na(suitability),
    fun = "sum",
    na.rm = TRUE
  )[[1L]]

  bounds <- terra::global(
    suitability,
    fun = c("min", "max"),
    na.rm = TRUE
  )
  usable_surface <-
    length(non_missing_cells) == 1L &&
    is.finite(non_missing_cells) &&
    non_missing_cells > 0 &&
    nrow(bounds) == 1L &&
    all(is.finite(as.matrix(bounds)))

  finite_cells <- if (
    length(non_missing_cells) == 1L && is.finite(non_missing_cells)
  ) {
    as.double(non_missing_cells)
  } else {
    0
  }

  records_are_known <-
    length(complete_presence_records) == 1L &&
    !is.na(complete_presence_records)

  if (
    records_are_known &&
      complete_presence_records < minimum_complete_presences
  ) {
    reason <- paste0(
      "Only ", complete_presence_records,
      " occurrence records had complete predictor values; at least ",
      minimum_complete_presences, " are required."
    )
    if (!usable_surface) {
      reason <- paste(
        reason,
        "The suitability raster also contained no usable finite surface."
      )
    }

    return(projection_status_record(
      species = species,
      scenario = scenario,
      status = "insufficient_complete_presences",
      reason = reason,
      finite_cells = finite_cells,
      complete_presence_records = complete_presence_records
    ))
  }

  if (!usable_surface) {
    return(projection_status_record(
      species = species,
      scenario = scenario,
      status = "no_finite_suitability",
      reason = "The suitability raster contained no usable finite cells.",
      finite_cells = finite_cells,
      complete_presence_records = complete_presence_records
    ))
  }

  if (!is.data.frame(thresholds)) {
    threshold_ok <- FALSE
    threshold_reason <- "The threshold result was not a data frame."
  } else if (!all(c("species", threshold) %in% names(thresholds))) {
    threshold_ok <- FALSE
    threshold_reason <- paste0(
      "The threshold table did not contain `species` and `", threshold, "`."
    )
  } else {
    values <- thresholds[
      as.character(thresholds$species) == species,
      threshold,
      drop = TRUE
    ]
    threshold_ok <- length(values) == 1L && is.finite(values)
    threshold_reason <- if (length(values) == 0L) {
      "No threshold row was returned for the species."
    } else if (length(values) > 1L) {
      "More than one threshold row was returned for the species."
    } else {
      paste0("The `", threshold, "` threshold was not finite.")
    }
  }

  if (!threshold_ok) {
    return(projection_status_record(
      species = species,
      scenario = scenario,
      status = "non_finite_threshold",
      reason = threshold_reason,
      finite_cells = finite_cells,
      complete_presence_records = complete_presence_records
    ))
  }

  projection_status_record(
    species = species,
    scenario = scenario,
    status = "projected",
    finite_cells = finite_cells,
    complete_presence_records = complete_presence_records
  )
}

#' Write a projection-status marker
#'
#' Writes one status record to a human-readable CSV file suitable for a
#' `targets` target with `format = "file"`. Failed branches should return this
#' marker path instead of returning a zero suitability raster.
#'
#' @param status_record A one-row table from [projection_status_record()] or
#'   [assess_projection_status()].
#' @param filename Output CSV path.
#' @param overwrite Whether an existing marker may be replaced. Default
#'   `TRUE`, which makes rerun targets idempotent.
#'
#' @return `filename`, invisibly.
#' @export
write_projection_status <- function(
    status_record,
    filename,
    overwrite = TRUE) {
  status_record <- .validate_projection_status(
    status_record,
    allow_empty = FALSE
  )
  if (nrow(status_record) != 1L) {
    stop("A status marker must contain exactly one row.", call. = FALSE)
  }
  .assert_scalar_character(filename, "filename")

  if (file.exists(filename) && !isTRUE(overwrite)) {
    stop("Status marker already exists: ", filename, call. = FALSE)
  }

  dir.create(dirname(filename), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(status_record, filename, na = "")
  invisible(filename)
}

#' Read projection-status markers
#'
#' @param paths Character vector of marker CSV files written by
#'   [write_projection_status()].
#'
#' @return A data frame containing all marker rows plus `status_file`, the
#'   source path for each row.
#' @export
read_projection_status <- function(paths) {
  paths <- unique(as.character(paths))
  paths <- paths[!is.na(paths) & nzchar(paths)]

  if (length(paths) == 0L) {
    out <- .empty_projection_status()
    out$status_file <- character()
    return(out)
  }

  missing_paths <- paths[!file.exists(paths)]
  if (length(missing_paths) > 0L) {
    stop(
      "Projection-status files do not exist: ",
      paste(utils::head(missing_paths, 20L), collapse = ", "),
      call. = FALSE
    )
  }

  records <- purrr::map_dfr(paths, function(path) {
    record <- readr::read_csv(
      path,
      show_col_types = FALSE,
      progress = FALSE
    )
    record$status_file <- path
    record
  })

  .validate_projection_status(records)
}

#' Summarize per-species model branches
#'
#' Converts dynamically branched model results into a compact model audit.
#' Each branch is expected to be a one-element named list, as returned by
#' [FitSpeciesModels()]. A `NULL` model is retained in the audit with
#' `model_ok = FALSE`.
#'
#' @param model_branches List of dynamically branched model results.
#'
#' @return A data frame with `species`, `model_ok`, and `model_class`.
#' @export
summarise_model_branches <- function(model_branches) {
  if (!is.list(model_branches)) {
    stop("`model_branches` must be a list.", call. = FALSE)
  }

  rows <- lapply(model_branches, function(models) {
    valid_container <-
      is.list(models) &&
      length(models) == 1L &&
      !is.null(names(models)) &&
      length(names(models)) == 1L &&
      !is.na(names(models)[[1L]]) &&
      nzchar(names(models)[[1L]])

    species <- if (valid_container) names(models)[[1L]] else NA_character_
    model_ok <- valid_container && !is.null(models[[1L]])

    data.frame(
      species = species,
      model_ok = model_ok,
      model_class = if (model_ok) {
        paste(class(models[[1L]]), collapse = "/")
      } else {
        NA_character_
      },
      stringsAsFactors = FALSE
    )
  })

  if (length(rows) == 0L) {
    return(data.frame(
      species = character(),
      model_ok = logical(),
      model_class = character(),
      stringsAsFactors = FALSE
    ))
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.species_from_presences <- function(valid_presences) {
  if (is.character(valid_presences)) {
    species <- valid_presences
  } else if (is.data.frame(valid_presences)) {
    if (!"species" %in% names(valid_presences)) {
      stop("Presence data must contain `species`.", call. = FALSE)
    }
    species <- as.character(valid_presences$species)
  } else if (is.list(valid_presences)) {
    species <- names(valid_presences)

    if (is.null(species) || anyNA(species) || any(!nzchar(species))) {
      species <- vapply(valid_presences, function(x) {
        if (is.data.frame(x) && "species" %in% names(x)) {
          values <- unique(as.character(x$species))
          values <- values[!is.na(values) & nzchar(values)]
          if (length(values) == 1L) values else NA_character_
        } else {
          NA_character_
        }
      }, character(1))
    }
  } else {
    stop(
      "`valid_presences` must be species names, a data frame, or a list.",
      call. = FALSE
    )
  }

  species <- unique(as.character(species))
  species <- species[!is.na(species) & nzchar(species)]
  if (length(species) == 0L) {
    stop("No valid species names were found.", call. = FALSE)
  }
  species
}

.normalise_projection_summary <- function(x) {
  if (is.null(x) || (is.data.frame(x) && nrow(x) == 0L)) {
    return(data.frame(
      scenario = character(),
      species = character(),
      binary_path = character(),
      stringsAsFactors = FALSE
    ))
  }
  if (!is.data.frame(x)) {
    stop("Projection summaries must be data frames.", call. = FALSE)
  }

  required <- c("scenario", "species")
  missing_columns <- setdiff(required, names(x))
  if (length(missing_columns) > 0L) {
    stop(
      "Projection summaries are missing: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  if (!"binary_path" %in% names(x)) {
    x$binary_path <- NA_character_
  }

  data.frame(
    scenario = as.character(x$scenario),
    species = as.character(x$species),
    binary_path = as.character(x$binary_path),
    stringsAsFactors = FALSE
  )
}

#' Build a complete projection audit
#'
#' Expands all expected species-by-scenario combinations and joins model
#' outcomes, projection summaries, and optional standardized status markers.
#' Status markers take precedence over inferred outcomes. Without markers, a
#' summary row is treated as `"projected"`; a missing row from a successful
#' model is treated as the unresolved status `"projection_missing"`.
#'
#' @param valid_presences A named list of valid occurrence data frames, one
#'   occurrence data frame containing `species`, or a character vector of
#'   expected species names.
#' @param model_audit Data frame from [summarise_model_branches()].
#' @param current_summary Current-projection summary data frame.
#' @param scenario_summary Scenario-projection summary data frame.
#' @param scenarios Character vector of scenario names, excluding `"current"`.
#' @param projection_statuses Optional status data frame or vector of marker
#'   paths read by [read_projection_status()]. New pipelines should supply
#'   these markers; the summary-only behavior supports older cached runs.
#'
#' @return One row per expected species and scenario, including `model_ok`,
#'   `projected`, `status`, `reason`, `binary_path`, and marker diagnostics.
#' @export
make_projection_audit <- function(
    valid_presences,
    model_audit,
    current_summary = NULL,
    scenario_summary = NULL,
    scenarios = character(),
    projection_statuses = NULL) {
  species <- .species_from_presences(valid_presences)
  scenario_levels <- unique(c("current", as.character(scenarios)))
  scenario_levels <- scenario_levels[
    !is.na(scenario_levels) & nzchar(scenario_levels)
  ]

  if (!is.data.frame(model_audit)) {
    stop("`model_audit` must be a data frame.", call. = FALSE)
  }
  required_model_columns <- c("species", "model_ok")
  missing_model_columns <- setdiff(required_model_columns, names(model_audit))
  if (length(missing_model_columns) > 0L) {
    stop(
      "`model_audit` is missing: ",
      paste(missing_model_columns, collapse = ", "),
      call. = FALSE
    )
  }
  if (anyDuplicated(as.character(model_audit$species))) {
    stop("`model_audit` contains duplicated species.", call. = FALSE)
  }
  if (!"model_class" %in% names(model_audit)) {
    model_audit$model_class <- NA_character_
  }

  expected <- expand.grid(
    scenario = scenario_levels,
    species = species,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )

  model_index <- match(
    expected$species,
    as.character(model_audit$species)
  )
  expected$model_ok <- as.logical(model_audit$model_ok[model_index])
  expected$model_class <- as.character(
    model_audit$model_class[model_index]
  )

  observed <- rbind(
    .normalise_projection_summary(current_summary),
    .normalise_projection_summary(scenario_summary)
  )
  observed_key <- paste(observed$scenario, observed$species, sep = "\r")
  if (anyDuplicated(observed_key)) {
    stop(
      "Projection summaries contain duplicated scenario/species rows.",
      call. = FALSE
    )
  }

  expected_key <- paste(expected$scenario, expected$species, sep = "\r")
  observed_index <- match(expected_key, observed_key)
  summary_present <- !is.na(observed_index)
  expected$binary_path <- observed$binary_path[observed_index]

  if (is.null(projection_statuses)) {
    markers <- .empty_projection_status()
    markers$status_file <- character()
  } else if (is.character(projection_statuses)) {
    markers <- read_projection_status(projection_statuses)
  } else {
    markers <- .validate_projection_status(projection_statuses)
    if (!"status_file" %in% names(markers)) {
      markers$status_file <- NA_character_
    }
  }

  marker_key <- paste(markers$scenario, markers$species, sep = "\r")
  marker_index <- match(expected_key, marker_key)
  marker_present <- !is.na(marker_index)

  recorded_status <- markers$status[marker_index]
  recorded_reason <- markers$reason[marker_index]
  expected$threshold_path <- markers$threshold_path[marker_index]
  expected$summary_path <- markers$summary_path[marker_index]
  expected$finite_cells <- markers$finite_cells[marker_index]
  expected$complete_presence_records <-
    markers$complete_presence_records[marker_index]
  expected$status_file <- markers$status_file[marker_index]

  inferred_status <- rep("projection_missing", nrow(expected))
  inferred_status[is.na(expected$model_ok)] <- "model_branch_missing"
  inferred_status[
    !is.na(expected$model_ok) & !expected$model_ok
  ] <- "model_failed"
  inferred_status[summary_present] <- "projected"

  final_status <- inferred_status
  final_status[marker_present] <- recorded_status[marker_present]
  final_reason <- rep(NA_character_, nrow(expected))
  final_reason[marker_present] <- recorded_reason[marker_present]

  marker_without_summary <-
    marker_present &
    recorded_status == "projected" &
    !summary_present
  final_status[marker_without_summary] <- "projection_missing"
  final_reason[marker_without_summary] <- paste(
    "The status marker reports `projected`, but no projection summary",
    "was found."
  )

  summary_with_failure_marker <-
    marker_present &
    recorded_status != "projected" &
    summary_present
  final_status[summary_with_failure_marker] <- "prediction_error"
  final_reason[summary_with_failure_marker] <- paste(
    "A projection summary exists, but the status marker reports a",
    "non-projected outcome."
  )

  failed_model_with_summary <-
    !is.na(expected$model_ok) &
    !expected$model_ok &
    summary_present
  final_status[failed_model_with_summary] <- "prediction_error"
  final_reason[failed_model_with_summary] <- paste(
    "A projection summary exists even though the model audit reports a",
    "failed model."
  )

  expected$projected <- final_status == "projected"
  expected$status <- final_status
  expected$reason <- final_reason

  expected <- expected[order(
    match(expected$scenario, scenario_levels),
    expected$status,
    expected$species
  ), , drop = FALSE]
  rownames(expected) <- NULL
  expected
}

#' Derive terminal species exclusions from a projection audit
#'
#' Converts reason-coded terminal branch outcomes into a species-level table
#' suitable for the `exclusions` argument of [select_projection_paths()]. This
#' is the automatic replacement for maintaining a hard-coded blacklist.
#' Unresolved statuses such as `"prediction_error"` and
#' `"projection_missing"` are deliberately not converted to exclusions.
#'
#' @param projection_audit Data frame from [make_projection_audit()].
#' @param terminal_statuses Statuses which justify exclusion from all
#'   comparable scenarios. Defaults to [projection_terminal_statuses()].
#'
#' @return A species-level data frame with `species`, `status`,
#'   `trigger_status`, `scenario`, and `reason`.
#' @export
projection_exclusions <- function(
    projection_audit,
    terminal_statuses = projection_terminal_statuses()) {
  if (!is.data.frame(projection_audit)) {
    stop("`projection_audit` must be a data frame.", call. = FALSE)
  }
  required <- c("species", "scenario", "status")
  missing_columns <- setdiff(required, names(projection_audit))
  if (length(missing_columns) > 0L) {
    stop(
      "`projection_audit` is missing: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
  if (!"reason" %in% names(projection_audit)) {
    projection_audit$reason <- NA_character_
  }

  terminal_statuses <- unique(as.character(terminal_statuses))
  unknown <- setdiff(terminal_statuses, .projection_status_levels)
  if (length(unknown) > 0L) {
    stop(
      "Unknown terminal status: ", paste(unknown, collapse = ", "),
      call. = FALSE
    )
  }

  terminal <- projection_audit[
    projection_audit$status %in% terminal_statuses,
    ,
    drop = FALSE
  ]
  if (nrow(terminal) == 0L) {
    return(data.frame(
      species = character(),
      status = character(),
      trigger_status = character(),
      scenario = character(),
      reason = character(),
      stringsAsFactors = FALSE
    ))
  }

  groups <- split(terminal, as.character(terminal$species))
  rows <- lapply(groups, function(x) {
    trigger_status <- paste(sort(unique(x$status)), collapse = ";")
    scenarios <- paste(sort(unique(as.character(x$scenario))), collapse = ";")
    reasons <- unique(as.character(x$reason))
    reasons <- reasons[!is.na(reasons) & nzchar(reasons)]

    data.frame(
      species = as.character(x$species[[1L]]),
      status = "excluded_from_comparisons",
      trigger_status = trigger_status,
      scenario = scenarios,
      reason = if (length(reasons) > 0L) {
        paste(reasons, collapse = " | ")
      } else {
        paste0("Terminal projection status: ", trigger_status, ".")
      },
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out <- out[order(out$species), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Validate and select binary projection paths
#'
#' Selects exactly one binary raster for every successfully fitted,
#' non-excluded species in one scenario. Missing summaries, duplicated species,
#' missing paths, and missing files are treated as unresolved errors. The
#' returned vector is ordered to match the model audit, making downstream
#' reductions deterministic.
#'
#' `exclusions` may be supplied manually for recovery of an older cached run,
#' but new pipelines should derive it with [projection_exclusions()] from
#' standardized status markers.
#'
#' @param projection_summary Projection summary table containing `scenario`,
#'   `species`, and `binary_path`.
#' @param model_audit Model audit from [summarise_model_branches()].
#' @param scenario Scenario to select.
#' @param exclusions Optional data frame with `species`, or a character vector
#'   of species approved for terminal exclusion.
#' @param require_files If `TRUE` (default), verify that every selected path
#'   exists.
#'
#' @return A named character vector of binary raster paths, with species names
#'   as names.
#' @export
select_projection_paths <- function(
    projection_summary,
    model_audit,
    scenario,
    exclusions = NULL,
    require_files = TRUE) {
  .assert_scalar_character(as.character(scenario), "scenario")
  scenario <- as.character(scenario)

  if (!is.data.frame(projection_summary)) {
    stop("`projection_summary` must be a data frame.", call. = FALSE)
  }
  required_summary <- c("scenario", "species", "binary_path")
  missing_summary <- setdiff(required_summary, names(projection_summary))
  if (length(missing_summary) > 0L) {
    stop(
      "`projection_summary` is missing: ",
      paste(missing_summary, collapse = ", "),
      call. = FALSE
    )
  }

  if (!is.data.frame(model_audit)) {
    stop("`model_audit` must be a data frame.", call. = FALSE)
  }
  required_model <- c("species", "model_ok")
  missing_model <- setdiff(required_model, names(model_audit))
  if (length(missing_model) > 0L) {
    stop(
      "`model_audit` is missing: ",
      paste(missing_model, collapse = ", "),
      call. = FALSE
    )
  }

  excluded_species <- if (is.null(exclusions)) {
    character()
  } else if (is.data.frame(exclusions)) {
    if (!"species" %in% names(exclusions)) {
      stop("`exclusions` must contain `species`.", call. = FALSE)
    }
    as.character(exclusions$species)
  } else {
    as.character(exclusions)
  }
  excluded_species <- unique(
    excluded_species[!is.na(excluded_species) & nzchar(excluded_species)]
  )

  expected_species <- as.character(model_audit$species)[
    !is.na(model_audit$model_ok) &
      model_audit$model_ok &
      !as.character(model_audit$species) %in% excluded_species
  ]
  expected_species <- unique(expected_species)
  expected_species <- expected_species[
    !is.na(expected_species) & nzchar(expected_species)
  ]
  if (length(expected_species) == 0L) {
    stop(
      "No successfully fitted, non-excluded species were available for `",
      scenario, "`.",
      call. = FALSE
    )
  }

  selected <- projection_summary[
    as.character(projection_summary$scenario) == scenario &
      as.character(projection_summary$species) %in% expected_species,
    ,
    drop = FALSE
  ]

  duplicated_species <- unique(
    as.character(selected$species)[duplicated(as.character(selected$species))]
  )
  missing_species <- setdiff(
    expected_species,
    as.character(selected$species)
  )

  selected_index <- match(
    expected_species,
    as.character(selected$species)
  )
  selected_paths <- as.character(selected$binary_path[selected_index])
  invalid_paths <- is.na(selected_paths) | !nzchar(selected_paths)
  missing_files <- if (isTRUE(require_files)) {
    !invalid_paths & !file.exists(selected_paths)
  } else {
    rep(FALSE, length(selected_paths))
  }

  if (
    length(duplicated_species) > 0L ||
      length(missing_species) > 0L ||
      any(invalid_paths) ||
      any(missing_files)
  ) {
    stop(
      "Projection set for `", scenario, "` is incomplete after terminal ",
      "exclusions. Expected ", length(expected_species), " species and found ",
      nrow(selected), ". Missing species: ",
      paste(utils::head(missing_species, 20L), collapse = ", "),
      if (length(missing_species) > 20L) " ..." else "",
      if (any(missing_files)) {
        paste0(
          ". Missing files: ",
          paste(utils::head(selected_paths[missing_files], 20L), collapse = ", ")
        )
      } else {
        ""
      },
      call. = FALSE
    )
  }

  message(
    "Using ", length(expected_species), " species for `", scenario,
    "`; excluding ", length(excluded_species), " terminal species."
  )

  stats::setNames(selected_paths, expected_species)
}

#' Construct the common valid predictor domain
#'
#' @param predictors A `terra::SpatRaster` or path vector readable by
#'   [terra::rast()].
#'
#' @return A single-layer `SpatRaster` containing `1` where every predictor is
#'   non-missing and `NA` elsewhere.
#' @keywords internal
make_predictor_domain <- function(predictors) {
  predictors <- if (inherits(predictors, "SpatRaster")) {
    predictors
  } else {
    terra::rast(predictors)
  }

  if (terra::nlyr(predictors) < 1L) {
    stop("`predictors` must contain at least one layer.", call. = FALSE)
  }

  valid_layers <- terra::app(
    !is.na(predictors),
    fun = sum
  )

  domain <- terra::ifel(
    valid_layers == terra::nlyr(predictors),
    1,
    NA
  )
  names(domain) <- "prediction_domain"
  domain
}

.configure_terra_reduction <- function() {
  available_options <- names(terra::terraOptions(print = FALSE))
  settings <- list(progress = 0L)

  if ("threads" %in% available_options) {
    settings$threads <- 1L
  }

  do.call(terra::terraOptions, settings)
  invisible(NULL)
}

#' Sum many binary raster files with bounded memory
#'
#' Reduces binary species projections as a tree of partial sums instead of
#' opening the full species stack. At most `chunk_size` rasters are opened for
#' one intermediate sum. The final result is masked to the common non-missing
#' predictor domain.
#'
#' @param paths Character vector of single-layer binary raster files.
#' @param predictors Predictor raster or path vector used to define the valid
#'   output domain.
#' @param filename Output raster path.
#' @param name Output layer name.
#' @param chunk_size Maximum rasters in an intermediate sum. Must be at least
#'   two. Default `50L`.
#' @param overwrite Whether `filename` may be replaced. Default `TRUE`.
#'
#' @return A file-backed, single-layer `terra::SpatRaster` containing the
#'   summed binary rasters.
#' @export
sum_binary_files_tree <- function(
    paths,
    predictors,
    filename,
    name,
    chunk_size = 50L,
    overwrite = TRUE) {
  .configure_terra_reduction()
  paths <- unique(as.character(paths))
  paths <- paths[!is.na(paths) & nzchar(paths)]

  if (length(paths) == 0L) {
    stop("No binary raster files were supplied.", call. = FALSE)
  }
  missing_inputs <- paths[!file.exists(paths)]
  if (length(missing_inputs) > 0L) {
    stop(
      "Binary raster files do not exist: ",
      paste(utils::head(missing_inputs, 20L), collapse = ", "),
      call. = FALSE
    )
  }

  .assert_scalar_character(filename, "filename")
  .assert_scalar_character(name, "name")
  if (file.exists(filename) && !isTRUE(overwrite)) {
    stop("Output raster already exists: ", filename, call. = FALSE)
  }

  dir.create(dirname(filename), recursive = TRUE, showWarnings = FALSE)

  input_paths <- normalizePath(paths, winslash = "/", mustWork = TRUE)
  output_path <- normalizePath(filename, winslash = "/", mustWork = FALSE)
  if (.Platform$OS.type == "windows") {
    input_paths <- tolower(input_paths)
    output_path <- tolower(output_path)
  }
  if (output_path %in% input_paths) {
    stop("`filename` must not overwrite an input raster.", call. = FALSE)
  }

  chunk_size <- as.integer(chunk_size)
  if (
    length(chunk_size) != 1L ||
      is.na(chunk_size) ||
      chunk_size < 2L
  ) {
    stop("`chunk_size` must be an integer of at least 2.", call. = FALSE)
  }
  if (length(paths) > 65534L) {
    stop(
      "INT2U richness output supports at most 65,534 species.",
      call. = FALSE
    )
  }

  current_level <- paths
  temporary_files <- character()
  on.exit({
    existing <- temporary_files[file.exists(temporary_files)]
    if (length(existing) > 0L) unlink(existing, force = TRUE)
  }, add = TRUE)

  level_number <- 0L
  while (length(current_level) > 1L) {
    level_number <- level_number + 1L
    groups <- split(
      current_level,
      ceiling(seq_along(current_level) / chunk_size)
    )

    next_level <- vapply(seq_along(groups), function(group_number) {
      group_paths <- groups[[group_number]]

      if (length(group_paths) == 1L) {
        return(group_paths[[1L]])
      }

      partial_path <- tempfile(
        pattern = paste0(
          "SpeciesPoolR_richness_level_",
          level_number,
          "_"
        ),
        fileext = ".tif"
      )

      partial <- terra::app(
        terra::rast(group_paths),
        fun = sum,
        na.rm = TRUE,
        filename = partial_path,
        overwrite = TRUE,
        wopt = list(
          datatype = "INT2U",
          gdal = c("COMPRESS=DEFLATE", "TILED=YES")
        )
      )

      temporary_files <<- c(temporary_files, partial_path)
      rm(partial)
      invisible(gc())
      partial_path
    }, character(1))

    current_level <- next_level
  }

  total <- terra::rast(current_level[[1L]])
  names(total) <- name
  domain <- make_predictor_domain(predictors)

  if (!terra::compareGeom(total, domain, stopOnError = FALSE)) {
    stop(
      "Binary projections and predictor domain have different geometry.",
      call. = FALSE
    )
  }

  richness <- terra::mask(
    total,
    domain,
    filename = filename,
    overwrite = overwrite,
    wopt = list(
      datatype = "INT2U",
      NAflag = 65535,
      gdal = c("COMPRESS=DEFLATE", "TILED=YES")
    )
  )
  names(richness) <- name

  rm(total, domain)
  invisible(gc())

  existing <- temporary_files[file.exists(temporary_files)]
  if (length(existing) > 0L) unlink(existing, force = TRUE)
  temporary_files <- character()

  richness
}

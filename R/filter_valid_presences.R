#' Filter Valid Species Presences
#'
#' Removes malformed, empty, duplicated, and spatially invalid occurrence
#' datasets.
#'
#' @param x A data frame or list of data frames returned by
#'   [get_presences()].
#'
#' @return A list of cleaned, non-empty presence data frames.
#'
#' @importFrom dplyr between distinct filter
#' @importFrom purrr keep map
#' @export
filter_valid_presences <- function(x) {
  species <- decimalLongitude <- decimalLatitude <- NULL

  if (is.data.frame(x)) {
    x <- list(x)
  }

  if (!is.list(x)) {
    stop("`x` must be a data frame or list of data frames.", call. = FALSE)
  }

  required <- c(
    "species",
    "decimalLongitude",
    "decimalLatitude"
  )

  valid <- x |>
    keep(\(z) {
      is.data.frame(z) &&
        nrow(z) > 0L &&
        all(required %in% names(z)) &&
        is.numeric(z$decimalLongitude) &&
        is.numeric(z$decimalLatitude)
    }) |>
    map(\(z) {
      z |>
        filter(
          !is.na(species),
          nzchar(species),
          is.finite(decimalLongitude),
          is.finite(decimalLatitude),
          between(decimalLongitude, -180, 180),
          between(decimalLatitude, -90, 90)
        ) |>
        distinct(
          species,
          decimalLongitude,
          decimalLatitude,
          .keep_all = TRUE
        )
    }) |>
    keep(\(z) nrow(z) > 0L)

  if (length(valid) == 0L) {
    stop(
      "No valid presence datasets remain after filtering.",
      call. = FALSE
    )
  }

  valid
}

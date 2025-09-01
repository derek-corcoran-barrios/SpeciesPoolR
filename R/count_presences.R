#' Build a CCW WKT polygon from a shapefile (lon/lat)
#'
#' Creates a minimum bounding rectangle (MBR) around the provided shapefile and
#' returns it as a WKT POLYGON in counter‑clockwise order. If the shapefile is
#' not in lon/lat, it is projected to EPSG:4326.
#'
#' @param shapefile Path to a vector file readable by \code{terra::vect()}.
#' @return A single-length character vector with WKT POLYGON, suitable for GBIF's `geometry` param.
#' @examples
#' f <- system.file("ex/Aarhus.shp", package = "SpeciesPoolR")
#' wkt <- wkt_rect_ccw(f)
#' cat(substr(wkt, 1, 60), "...\n")
#'
#' @importFrom terra vect is.lonlat project ext xmin xmax ymin ymax crs
#' @export
wkt_rect_ccw <- function(shapefile) {
  stopifnot(!is.null(shapefile), file.exists(shapefile))
  v <- terra::vect(shapefile)

  # Reproject to lon/lat if necessary
  if (!terra::is.lonlat(v)) {
    v <- terra::project(v, "EPSG:4326")
  }

  e <- terra::ext(v)
  xmn <- terra::xmin(e); xmx <- terra::xmax(e)
  ymn <- terra::ymin(e); ymx <- terra::ymax(e)

  # Counter‑clockwise ring: (xmin ymin, xmax ymin, xmax ymax, xmin ymax, xmin ymin)
  coords <- sprintf(
    "%f %f, %f %f, %f %f, %f %f, %f %f",
    xmn, ymn,  xmx, ymn,  xmx, ymx,  xmn, ymx,  xmn, ymn
  )
  paste0("POLYGON ((", coords, "))")
}

#' Count presences quickly (no auth) using GBIF facets
#'
#' @title Fast presence counts via GBIF facets (unauthenticated)
#'
#' @description
#' Performs a single GBIF search using a facet on \code{scientificName} and returns
#' occurrence counts for the supplied species list within either a country or the
#' minimum bounding rectangle (MBR) of a shapefile (converted to CCW WKT with
#' \code{\link{wkt_rect_ccw}}). This method is **fast and polite** (one request),
#' but facet results can be truncated if your species list exceeds \code{facet_limit}.
#'
#' @param species A data frame/data.table/tibble with columns \code{family}, \code{genus}, \code{species}.
#'   (Use cleaned GBIF-aligned names for best matches.)
#' @param shapefile Path to a vector file readable by \code{terra::vect()}.
#'   If provided (and \code{country} is \code{NULL}), its MBR is used as the GBIF
#'   \code{geometry} filter via \code{\link{wkt_rect_ccw}}. Mutually exclusive with \code{country}.
#' @param country Two-letter ISO country code (e.g., \code{"DK"}). Ignored if \code{shapefile} is provided.
#'   Mutually exclusive with \code{shapefile}.
#' @param year Integer vector \code{c(start, end)} with the year range (inclusive). Default is
#'   \code{c(1999, current_year)}.
#' @param facet_limit Integer maximum number of facet entries GBIF will return. Default \code{20000}.
#' @param verbose Logical; if \code{TRUE}, prints helpful warnings.
#'
#' @return A \code{data.table} with columns \code{family}, \code{genus}, \code{species}, \code{N}.
#'
#' @details
#' This function makes **one** call to \code{rgbif::occ_search()} with \code{facet = "scientificName"}
#' and joins the returned counts to your requested species. Species not present in the facet response
#' receive \code{N = 0}. If your list is longer than \code{facet_limit}, GBIF may truncate the facet;
#' consider \code{\link{count_presences_auth}} for complete, reproducible results.
#'
#' @examples
#' \dontrun{
#' f_species <- system.file("ex/Species_List.csv", package = "SpeciesPoolR")
#' shp       <- system.file("ex/Aarhus.shp",      package = "SpeciesPoolR")
#' sp        <- SpeciesPoolR::get_data(f_species)
#' clean     <- SpeciesPoolR::Clean_Taxa(sp$Species)
#'
#' out <- count_presences_simple(
#'   species   = clean,
#'   shapefile = shp,
#'   year      = c(1999, as.integer(format(Sys.Date(), "%Y")))
#' )
#' head(out)
#' }
#'
#' @seealso \code{\link{count_presences_auth}}, \code{\link{count_presences}}, \code{\link{wkt_rect_ccw}}
#' @family GBIF helpers
#' @export
count_presences_simple <- function(
    species,
    shapefile = NULL,
    country   = NULL,
    year      = c(1999L, as.integer(format(Sys.Date(), "%Y"))),
    facet_limit = 20000L,
    verbose   = TRUE
) {
  if (!xor(!is.null(shapefile), !is.null(country))) {
    stop("Provide either 'shapefile' OR 'country' (exclusively).")
  }
  if (!all(c("family","genus","species") %in% colnames(species))) {
    stop("`species` must have columns: family, genus, species")
  }

  geometry <- if (!is.null(shapefile)) wkt_rect_ccw(shapefile) else NULL

  r <- rgbif::occ_search(
    hasCoordinate      = TRUE,
    hasGeospatialIssue = FALSE,
    year               = paste(year, collapse = ","),
    country            = country,
    geometry           = geometry,
    facet              = "scientificName",
    facetLimit         = facet_limit
  )

  if (length(r$facets) == 0L) {
    dt <- data.table::data.table(species = character(), N = integer())
  } else {
    dt <- data.table::as.data.table(r$facets[[1]]$counts)[
      , .(species = name, N = as.integer(count))]
  }

  want <- data.table::as.data.table(unique(species[, c("family","genus","species")]))
  out  <- dt[want, on = "species"]
  out[is.na(N), N := 0L][]
  data.table::setcolorder(out, c("family","genus","species","N"))

  if (verbose && nrow(want) > facet_limit && any(out$N == 0L)) {
    message("count_presences_simple(): species list may exceed facet_limit; ",
            "facet results can be truncated. Consider count_presences_auth().")
  }
  out[]
}


#' Count presences robustly using the GBIF Occurrence Download API (auth required)
#'
#' @title Reproducible presence counts via GBIF downloads (authenticated)
#'
#' @description
#' Submits an authenticated GBIF Occurrence Download restricted by country/geometry
#' and year (optionally restricted to your species via GBIF taxon keys), waits for
#' completion, imports the result, and summarizes counts per species locally.
#' This is the **robust** and reproducible approach recommended for larger jobs.
#'
#' @param species A data frame/data.table/tibble with columns \code{family}, \code{genus}, \code{species}.
#' @param shapefile Path to a vector file readable by \code{terra::vect()}.
#'   If provided (and \code{country} is \code{NULL}), its MBR is used as the GBIF
#'   \code{geometry} filter via \code{\link{wkt_rect_ccw}}. Mutually exclusive with \code{country}.
#' @param country Two-letter ISO country code (e.g., \code{"DK"}). Ignored if \code{shapefile} is provided.
#'   Mutually exclusive with \code{shapefile}.
#' @param year Integer vector \code{c(start, end)} with the year range (inclusive). Default is
#'   \code{c(1999, current_year)}.
#' @param restrict_to_species Logical; if \code{TRUE} (default), the download is restricted to your
#'   species by GBIF \code{taxonKey} (resolved via \code{rgbif::name_backbone()}). If \code{FALSE},
#'   the download uses only area/time filters and species are filtered locally afterwards.
#' @param verbose Logical; if \code{TRUE}, prints progress messages.
#'
#' @section Credentials:
#' Requires the environment variables \code{GBIF_USER}, \code{GBIF_PWD}, \code{GBIF_EMAIL}.
#' A convenient place to define them is your \code{~/.Renviron}.
#'
#' @return A \code{data.table} with columns \code{family}, \code{genus}, \code{species}, \code{N}.
#'
#' @examples
#' \dontrun{
#' # Set GBIF creds in ~/.Renviron:
#' # GBIF_USER=youruser
#' # GBIF_PWD=yourpassword
#' # GBIF_EMAIL=you@example.org
#'
#' f_species <- system.file("ex/Species_List.csv", package = "SpeciesPoolR")
#' shp       <- system.file("ex/Aarhus.shp",      package = "SpeciesPoolR")
#' sp        <- SpeciesPoolR::get_data(f_species)
#' clean     <- SpeciesPoolR::Clean_Taxa(sp$Species)
#'
#' out <- count_presences_auth(
#'   species   = clean,
#'   shapefile = shp,
#'   year      = c(1999, as.integer(format(Sys.Date(), "%Y"))),
#'   restrict_to_species = TRUE,
#'   verbose   = TRUE
#' )
#' head(out)
#' }
#'
#' @seealso \code{\link{count_presences_simple}}, \code{\link{count_presences}}, \code{\link{wkt_rect_ccw}}
#' @family GBIF helpers
#' @export
count_presences_auth <- function(
    species,
    shapefile = NULL,
    country   = NULL,
    year      = c(1999L, as.integer(format(Sys.Date(), "%Y"))),
    restrict_to_species = TRUE,
    verbose   = TRUE
) {
  if (!xor(!is.null(shapefile), !is.null(country))) {
    stop("Provide either 'shapefile' OR 'country' (exclusively).")
  }
  if (!all(c("family","genus","species") %in% colnames(species))) {
    stop("`species` must have columns: family, genus, species")
  }

  req_env <- c("GBIF_USER","GBIF_PWD","GBIF_EMAIL")
  if (!all(nzchar(Sys.getenv(req_env)))) {
    stop("GBIF credentials not found. Please set GBIF_USER, GBIF_PWD, GBIF_EMAIL in your environment.")
  }

  geometry <- if (!is.null(shapefile)) wkt_rect_ccw(shapefile) else NULL
  want <- data.table::as.data.table(unique(species[, c("family","genus","species")]))

  keys <- NULL
  if (restrict_to_species) {
    if (verbose) message("Resolving GBIF taxon keys for supplied species...")
    keys <- lapply(want$species, function(s)
      tryCatch(rgbif::name_backbone(name = s)$usageKey, error = function(e) NA_integer_))
    keys <- as.integer(stats::na.omit(unlist(keys)))
    if (verbose) message("Resolved ", length(keys), " taxon keys.")
    if (length(keys) == 0L) {
      if (verbose) message("No taxon keys resolved; falling back to area/time-only download.")
      restrict_to_species <- FALSE
    }
  }

  preds <- list(
    rgbif::pred("hasCoordinate", TRUE),
    rgbif::pred("hasGeospatialIssue", FALSE),
    rgbif::pred_gte("year", year[1]),
    rgbif::pred_lte("year", year[2]),
    if (!is.null(country))  rgbif::pred("country", country) else NULL,
    if (!is.null(geometry)) rgbif::pred_within(geometry) else NULL,
    if (restrict_to_species) rgbif::pred_in("taxonKey", unique(keys)) else NULL
  )
  preds <- preds[!vapply(preds, is.null, logical(1))]

  if (verbose) message("Submitting GBIF download...")
  key <- rgbif::occ_download(
    preds,
    user   = Sys.getenv("GBIF_USER"),
    pwd    = Sys.getenv("GBIF_PWD"),
    email  = Sys.getenv("GBIF_EMAIL"),
    format = "SIMPLE_CSV"
  )

  if (verbose) message("Waiting for GBIF download to complete (key = ", key, ")...")
  rgbif::occ_download_wait(key)

  zipfile <- rgbif::occ_download_get(key, overwrite = TRUE)
  occs    <- rgbif::occ_download_import(zipfile)

  dt <- data.table::as.data.table(occs)[, .N, by = scientificName]
  data.table::setnames(dt, c("species","N"))

  out <- dt[want, on = "species"][, `:=`(family = i.family, genus = i.genus)][
    , c("i.family","i.genus") := NULL][]
  out[is.na(N), N := 0L][]
  data.table::setcolorder(out, c("family","genus","species","N"))
  out[]
}


#' Count presences via GBIF (choose fast **simple** or robust **auth** method)
#'
#' @title Unified interface for GBIF presence counts
#'
#' @description
#' Convenience wrapper that dispatches to \code{\link{count_presences_simple}} (fast,
#' no authentication) or \code{\link{count_presences_auth}} (robust, authenticated GBIF
#' download). Returns a tidy table of counts per species within either a country or
#' the MBR of a shapefile.
#'
#' @param species A data frame/data.table/tibble with columns \code{family}, \code{genus}, \code{species}.
#' @param shapefile Path to a vector file readable by \code{terra::vect()}.
#'   If provided (and \code{country} is \code{NULL}), its MBR is used as the GBIF
#'   \code{geometry} filter via \code{\link{wkt_rect_ccw}}. Mutually exclusive with \code{country}.
#' @param country Two-letter ISO country code (e.g., \code{"DK"}). Ignored if \code{shapefile} is provided.
#'   Mutually exclusive with \code{shapefile}.
#' @param method Character; one of \code{"simple"} (default) or \code{"auth"}.
#'   Matching is case-insensitive.
#' @param year Integer vector \code{c(start, end)} with the year range (inclusive). Default is
#'   \code{c(1999, current_year)}.
#' @param ... Additional arguments passed to the selected backend:
#'   \itemize{
#'     \item For \code{method = "simple"}: \code{facet_limit}, \code{verbose}.
#'     \item For \code{method = "auth"}: \code{restrict_to_species}, \code{verbose}.
#'   }
#'
#' @details
#' Use \code{method = "simple"} for quick exploratory work; switch to \code{"auth"} for
#' larger lists or when you need a citable, reproducible download record.
#'
#' @return A \code{data.table} with columns \code{family}, \code{genus}, \code{species}, \code{N}.
#'
#' @examples
#' \dontrun{
#' f_species <- system.file("ex/Species_List.csv", package = "SpeciesPoolR")
#' shp       <- system.file("ex/Aarhus.shp",      package = "SpeciesPoolR")
#' sp        <- SpeciesPoolR::get_data(f_species)
#' clean     <- SpeciesPoolR::Clean_Taxa(sp$Species)
#'
#' # Fast
#' out1 <- count_presences(clean, shapefile = shp, method = "simple")
#'
#' # Robust (requires GBIF_USER/GBIF_PWD/GBIF_EMAIL)
#' out2 <- count_presences(clean, shapefile = shp, method = "auth", restrict_to_species = TRUE)
#' }
#'
#' @seealso \code{\link{count_presences_simple}}, \code{\link{count_presences_auth}}, \code{\link{wkt_rect_ccw}}
#' @family GBIF helpers
#' @export
count_presences <- function(
    species,
    shapefile = NULL,
    country   = NULL,
    method    = c("simple", "auth"),
    year      = c(1999L, as.integer(format(Sys.Date(), "%Y"))),
    ...
) {
  if (!xor(!is.null(shapefile), !is.null(country))) {
    stop("Provide either 'shapefile' OR 'country' (exclusively).")
  }
  if (!all(c("family", "genus", "species") %in% colnames(species))) {
    stop("`species` must have columns: family, genus, species")
  }

  m <- tolower(method[1L])
  if (!m %in% c("simple", "auth")) {
    stop("`method` must be one of: 'simple', 'auth'.")
  }

  fun <- switch(m,
                simple = count_presences_simple,
                auth   = count_presences_auth
  )

  fun(
    species   = species,
    shapefile = shapefile,
    country   = country,
    year      = year,
    ...
  )
}

#' File-backed phylogenetic diversity with rtrees
#'
#' These functions classify taxa into the megatree groups supported by
#' `rtrees`, build one reproducible tree for a group, audit species coverage,
#' and calculate phylogenetic diversity (PD) from species-level binary raster
#' files without assembling a complete cells-by-species table in memory.
#'
#' @name phylogenetic_diversity_files
NULL

.rtrees_groups <- c(
  "amphibian",
  "bee",
  "bird",
  "butterfly",
  "fish",
  "mammal",
  "plant",
  "reptile",
  "shark_ray"
)

.rtrees_bee_families <- c(
  "andrenidae",
  "apidae",
  "colletidae",
  "halictidae",
  "megachilidae",
  "melittidae",
  "stenotritidae"
)

.rtrees_butterfly_families <- c(
  "papilionidae",
  "pieridae",
  "nymphalidae",
  "lycaenidae",
  "hesperiidae",
  "riodinidae"
)

.rtrees_taxonomy_column <- function(x, column) {
  index <- match(tolower(column), tolower(names(x)))

  if (is.na(index)) {
    stop(
      "`x` must contain a `", column, "` column (case-insensitive).",
      call. = FALSE
    )
  }

  names(x)[[index]]
}

.rtrees_species_key <- function(x) {
  out <- normalize_species_name(trimws(as.character(x)))
  gsub("^_+|_+$", "", out)
}

.validate_rtrees_group <- function(group) {
  if (
    !is.character(group) ||
      length(group) != 1L ||
      is.na(group) ||
      !nzchar(group)
  ) {
    stop("`group` must be one non-empty character value.", call. = FALSE)
  }

  group <- tolower(trimws(group))
  if (!group %in% .rtrees_groups) {
    stop(
      "Unsupported rtrees group `", group, "`. Choose one of: ",
      paste(.rtrees_groups, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  group
}

#' Classify taxa into rtrees megatree groups
#'
#' Assigns each row of a taxonomic table to the exact `taxon` label expected
#' by `rtrees::get_tree()`. Unsupported rows receive `NA` instead of being
#' silently assigned to an unrelated tree.
#'
#' Plants are recognized from kingdom; vertebrate groups are recognized from
#' class; bees and butterflies are recognized from family. Column names are
#' matched case-insensitively, so both `kingdom` and `Kingdom` are accepted.
#'
#' @param x A data frame containing kingdom, class, and family columns.
#'
#' @return A character vector with one value per row. Possible non-missing
#'   values are `"plant"`, `"bird"`, `"mammal"`, `"amphibian"`,
#'   `"reptile"`, `"shark_ray"`, `"fish"`, `"bee"`, and
#'   `"butterfly"`.
#' @export
classify_rtrees_group <- function(x) {
  if (!is.data.frame(x)) {
    stop("`x` must be a data frame.", call. = FALSE)
  }

  kingdom_column <- .rtrees_taxonomy_column(x, "kingdom")
  class_column <- .rtrees_taxonomy_column(x, "class")
  family_column <- .rtrees_taxonomy_column(x, "family")

  kingdom <- tolower(trimws(as.character(x[[kingdom_column]])))
  taxon_class <- tolower(trimws(as.character(x[[class_column]])))
  family <- tolower(trimws(as.character(x[[family_column]])))

  order_index <- match("order", tolower(names(x)))
  taxon_order <- if (is.na(order_index)) {
    rep(NA_character_, nrow(x))
  } else {
    tolower(trimws(as.character(x[[order_index]])))
  }

  out <- rep(NA_character_, nrow(x))
  out[kingdom %in% "plantae"] <- "plant"
  out[is.na(out) & taxon_class %in% "aves"] <- "bird"
  out[is.na(out) & taxon_class %in% "mammalia"] <- "mammal"
  out[is.na(out) & taxon_class %in% "amphibia"] <- "amphibian"
  out[
    is.na(out) &
      (
        taxon_class %in% "squamata" |
          taxon_order %in% "squamata"
      )
  ] <- "reptile"
  out[is.na(out) & taxon_class %in% "chondrichthyes"] <- "shark_ray"
  out[
    is.na(out) &
      taxon_class %in% c("actinopterygii", "sarcopterygii")
  ] <- "fish"
  out[is.na(out) & family %in% .rtrees_bee_families] <- "bee"
  out[
    is.na(out) & family %in% .rtrees_butterfly_families
  ] <- "butterfly"

  out
}

.prepare_rtrees_species <- function(species) {
  if (is.data.frame(species)) {
    species_column <- .rtrees_taxonomy_column(species, "species")
    genus_column <- .rtrees_taxonomy_column(species, "genus")
    family_column <- .rtrees_taxonomy_column(species, "family")

    out <- data.frame(
      species = .rtrees_species_key(species[[species_column]]),
      genus = trimws(as.character(species[[genus_column]])),
      family = trimws(as.character(species[[family_column]])),
      stringsAsFactors = FALSE
    )

    optional_columns <- c("close_sp", "close_genus")
    for (column in optional_columns) {
      index <- match(tolower(column), tolower(names(species)))
      if (!is.na(index)) {
        out[[column]] <- trimws(as.character(species[[index]]))
      }
    }

    invalid_species <- is.na(out$species) | !nzchar(out$species)
    invalid_genus <- is.na(out$genus) | !nzchar(out$genus)
    if (any(invalid_species) || any(invalid_genus)) {
      stop(
        "Every row supplied to `build_rtrees_tree()` must have a species ",
        "and genus.",
        call. = FALSE
      )
    }

    duplicated_species <- unique(out$species[duplicated(out$species)])
    if (length(duplicated_species) > 0L) {
      conflicting <- vapply(
        duplicated_species,
        function(name) {
          rows <- out[out$species == name, c("genus", "family"), drop = FALSE]
          nrow(unique(rows)) > 1L
        },
        logical(1)
      )
      if (any(conflicting)) {
        stop(
          "Conflicting genus or family assignments were supplied for: ",
          paste(duplicated_species[conflicting], collapse = ", "),
          ".",
          call. = FALSE
        )
      }
      out <- out[!duplicated(out$species), , drop = FALSE]
    }

    row.names(out) <- NULL
    return(out)
  }

  if (!is.character(species)) {
    stop(
      "`species` must be a character vector or a taxonomic data frame.",
      call. = FALSE
    )
  }

  out <- unique(.rtrees_species_key(species))
  out <- out[!is.na(out) & nzchar(out)]
  out
}

.select_one_phylogeny <- function(tree, tree_index, argument = "tree") {
  if (
    !is.numeric(tree_index) ||
    length(tree_index) != 1L ||
      is.na(tree_index) ||
      !is.finite(tree_index) ||
      tree_index != floor(tree_index) ||
      tree_index < 1L
  ) {
    stop("`tree_index` must be one positive integer.", call. = FALSE)
  }
  tree_index <- as.integer(tree_index)

  if (inherits(tree, "phylo")) {
    if (tree_index != 1L) {
      stop(
        "`tree_index` must be 1 when `", argument,
        "` is a single phylogeny.",
        call. = FALSE
      )
    }
    return(tree)
  }

  is_tree_collection <-
    (inherits(tree, "multiPhylo") || is.list(tree)) &&
      length(tree) > 0L &&
      all(vapply(tree, inherits, logical(1), what = "phylo"))

  if (!is_tree_collection) {
    stop(
      "`", argument, "` must be a phylo or multiPhylo object.",
      call. = FALSE
    )
  }

  if (tree_index > length(tree)) {
    stop(
      "`tree_index` is ", tree_index, " but `", argument,
      "` contains only ", length(tree), " trees.",
      call. = FALSE
    )
  }

  tree[[tree_index]]
}

.default_rtrees_megatree <- function(group) {
  if (!requireNamespace("megatrees", quietly = TRUE)) {
    stop(
      "Package `megatrees` is required to load the default rtrees trees.",
      call. = FALSE
    )
  }

  object <- switch(
    group,
    amphibian = "get_tree_amphibian_n100",
    bee = "tree_bee",
    bird = "get_tree_bird_n100",
    butterfly = "tree_butterfly",
    fish = "tree_fish_12k",
    mammal = "get_tree_mammal_n100_vertlife",
    plant = "tree_plant_otl",
    reptile = "get_tree_reptile_n100",
    shark_ray = "get_tree_shark_ray_n100"
  )

  value <- getExportedValue("megatrees", object)
  if (is.function(value)) value() else value
}

.as_single_phylo <- function(Tree) {
  if (inherits(Tree, "phylo")) {
    return(Tree)
  }

  if (
    is.list(Tree) &&
      !is.null(Tree[["scenario.3"]]) &&
      inherits(Tree[["scenario.3"]], "phylo")
  ) {
    return(Tree[["scenario.3"]])
  }

  if (
    (inherits(Tree, "multiPhylo") || is.list(Tree)) &&
      length(Tree) == 1L &&
      inherits(Tree[[1L]], "phylo")
  ) {
    return(Tree[[1L]])
  }

  stop(
    "`Tree` must contain exactly one phylogeny. Select one posterior tree ",
    "before calculating or auditing PD.",
    call. = FALSE
  )
}

#' Build one rtrees phylogeny
#'
#' Builds a single group-specific phylogeny with `rtrees::get_tree()`. When a
#' taxon uses a posterior collection, `tree_index` selects one megatree before
#' species are grafted. This avoids accidentally constructing all posterior
#' trees during a pilot run and makes the selected tree reproducible.
#'
#' A taxonomic data frame with `species`, `genus`, and `family` is recommended,
#' especially for bees, butterflies, and species absent from a megatree.
#' Species names are converted to the underscore format required by `rtrees`.
#'
#' @param species A character vector of species names, or a data frame with
#'   case-insensitive `species`, `genus`, and `family` columns. Optional
#'   `close_sp` and `close_genus` columns are retained.
#' @param group One group returned by [classify_rtrees_group()].
#' @param tree Optional user-supplied `phylo` or `multiPhylo`. When omitted,
#'   the default megatree for `group` is loaded from `megatrees`.
#' @param tree_index One-based tree to select from a posterior `multiPhylo`.
#'   Default `1L`.
#' @param scenario Grafting scenario passed to `rtrees::get_tree()`.
#' @param show_grafted Whether `rtrees` should append stars to grafted tip
#'   labels. Default `FALSE`; graft status remains available in the returned
#'   tree's `graft_status` table.
#' @param tree_by_user Whether `tree` is user supplied. `NULL` detects this
#'   from whether `tree` was supplied.
#' @param progress Progress-bar style passed as `.progress` to `rtrees`.
#' @param ... Additional named arguments passed to `rtrees::get_tree()`.
#' @param .tree_builder Optional replacement for `rtrees::get_tree()`, used
#'   for controlled testing.
#'
#' @return One `phylo` object, with requested species, group, and tree index
#'   recorded as attributes.
#' @export
build_rtrees_tree <- function(
    species,
    group,
    tree = NULL,
    tree_index = 1L,
    scenario = c("at_basal_node", "random_below_basal"),
    show_grafted = FALSE,
    tree_by_user = NULL,
    progress = "none",
    ...,
    .tree_builder = NULL) {
  group <- .validate_rtrees_group(group)
  scenario <- match.arg(scenario)
  species_input <- .prepare_rtrees_species(species)

  species_names <- if (is.data.frame(species_input)) {
    species_input$species
  } else {
    species_input
  }
  if (length(species_names) < 2L) {
    stop("At least two unique species are required to build a tree.", call. = FALSE)
  }

  supplied_tree <- !is.null(tree)
  if (!supplied_tree) {
    tree <- .default_rtrees_megatree(group)
  }
  tree <- .select_one_phylogeny(tree, tree_index, argument = "tree")

  if (is.null(tree_by_user)) {
    tree_by_user <- supplied_tree
  }
  if (!is.logical(tree_by_user) || length(tree_by_user) != 1L || is.na(tree_by_user)) {
    stop("`tree_by_user` must be TRUE, FALSE, or NULL.", call. = FALSE)
  }

  if (is.null(.tree_builder)) {
    if (!requireNamespace("rtrees", quietly = TRUE)) {
      stop(
        "Package `rtrees` is required to build an rtrees phylogeny.",
        call. = FALSE
      )
    }
    .tree_builder <- rtrees::get_tree
  }
  if (!is.function(.tree_builder)) {
    stop("`.tree_builder` must be a function.", call. = FALSE)
  }

  arguments <- list(
    sp_list = species_input,
    tree = tree,
    taxon = group,
    scenario = scenario,
    show_grafted = show_grafted,
    tree_by_user = tree_by_user,
    mc_cores = 1L,
    .progress = progress
  )
  dots <- list(...)
  if (
    length(dots) > 0L &&
      (
        is.null(names(dots)) ||
          anyNA(names(dots)) ||
          any(!nzchar(names(dots)))
      )
  ) {
    stop("Additional arguments in `...` must be named.", call. = FALSE)
  }
  duplicated_arguments <- intersect(names(dots), names(arguments))
  if (length(duplicated_arguments) > 0L) {
    stop(
      "Arguments supplied more than once: ",
      paste(duplicated_arguments, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  out <- do.call(.tree_builder, c(arguments, dots))
  out <- .as_single_phylo(out)
  attr(out, "requested_species") <- species_names
  attr(out, "rtrees_group") <- group
  attr(out, "rtrees_tree_index") <- as.integer(tree_index)
  out
}

.species_names_for_tree_audit <- function(species) {
  if (is.data.frame(species)) {
    column <- .rtrees_taxonomy_column(species, "species")
    species <- species[[column]]
  }

  if (!is.character(species)) {
    stop("`species` must be a character vector or data frame.", call. = FALSE)
  }

  species <- as.character(species)
  key <- .rtrees_species_key(species)
  invalid <- is.na(key) | !nzchar(key)
  if (any(invalid)) {
    stop("`species` contains missing or empty names.", call. = FALSE)
  }
  if (anyDuplicated(key)) {
    stop(
      "`species` is not unique after name normalization.",
      call. = FALSE
    )
  }

  list(species = species, key = key)
}

#' Audit species coverage in a phylogenetic tree
#'
#' Matches requested species to tree tips after normalizing spaces, dots, and
#' underscores. Terminal stars added by `rtrees` to mark grafts are ignored
#' during matching. When available, the original `rtrees` graft-status text is
#' included without using it as a substitute for an actual tip match.
#'
#' @param species Character vector or data frame containing the requested
#'   species.
#' @param Tree One `phylo`, an rtrees result, or a legacy V.PhyloMaker result
#'   containing `scenario.3`.
#' @param group Optional rtrees group. If omitted, the attribute written by
#'   [build_rtrees_tree()] is used.
#'
#' @return A data frame with one row per requested species and columns
#'   `group`, `species`, `normalized_species`, `tree_tip`, `matched`,
#'   `coverage_status`, and `graft_status`.
#' @export
audit_tree_coverage <- function(species, Tree, group = NULL) {
  requested <- .species_names_for_tree_audit(species)
  tree <- .as_single_phylo(Tree)

  tip_label <- as.character(tree$tip.label)
  tip_key <- .rtrees_species_key(sub("\\*+$", "", tip_label))
  if (anyNA(tip_key) || any(!nzchar(tip_key))) {
    stop("`Tree` contains missing or empty tip labels.", call. = FALSE)
  }
  if (anyDuplicated(tip_key)) {
    stop(
      "`Tree` tip labels are not unique after name normalization.",
      call. = FALSE
    )
  }

  index <- match(requested$key, tip_key)
  matched <- !is.na(index)

  graft_status <- rep(NA_character_, length(requested$key))
  status_table <- tree[["graft_status"]]
  if (
    is.data.frame(status_table) &&
      all(c("species", "status") %in% names(status_table))
  ) {
    status_key <- .rtrees_species_key(status_table$species)
    status_index <- match(requested$key, status_key)
    graft_status <- as.character(status_table$status[status_index])
  }

  if (is.null(group)) {
    group <- attr(tree, "rtrees_group", exact = TRUE)
  }
  if (is.null(group) || length(group) == 0L) {
    group <- NA_character_
  } else {
    group <- .validate_rtrees_group(as.character(group[[1L]]))
  }

  data.frame(
    group = rep(group, length(requested$species)),
    species = requested$species,
    normalized_species = requested$key,
    tree_tip = ifelse(matched, tip_label[index], NA_character_),
    matched = matched,
    coverage_status = ifelse(matched, "matched", "missing_from_tree"),
    graft_status = graft_status,
    stringsAsFactors = FALSE
  )
}

.validate_pd_tree <- function(Tree) {
  tree <- .as_single_phylo(Tree)

  if (is.null(tree$edge.length)) {
    stop("`Tree` must contain branch lengths.", call. = FALSE)
  }
  if (
    length(tree$edge.length) != nrow(tree$edge) ||
      any(!is.finite(tree$edge.length)) ||
      any(tree$edge.length < 0)
  ) {
    stop(
      "`Tree` branch lengths must be finite, non-negative, and match its edges.",
      call. = FALSE
    )
  }
  if (!ape::is.rooted(tree)) {
    stop("`Tree` must be rooted.", call. = FALSE)
  }

  tip_key <- .rtrees_species_key(sub("\\*+$", "", tree$tip.label))
  if (anyNA(tip_key) || any(!nzchar(tip_key)) || anyDuplicated(tip_key)) {
    stop(
      "`Tree` tip labels must be non-empty and unique after normalization.",
      call. = FALSE
    )
  }

  list(tree = tree, tip_key = tip_key)
}

.pd_edge_incidence <- function(tree, path_tip_nodes) {
  edge <- tree$edge
  number_tips <- length(tree$tip.label)
  maximum_node <- max(edge)

  path_row_by_tip <- integer(number_tips)
  path_row_by_tip[path_tip_nodes] <- seq_along(path_tip_nodes)

  descendants <- vector("list", maximum_node)
  for (tip in seq_len(number_tips)) {
    descendants[[tip]] <- if (path_row_by_tip[[tip]] > 0L) {
      path_row_by_tip[[tip]]
    } else {
      integer()
    }
  }

  edge_descendants <- vector("list", nrow(edge))
  edge_for_child <- integer(maximum_node)
  edge_for_child[edge[, 2L]] <- seq_len(nrow(edge))
  children_remaining <- tabulate(edge[, 1L], nbins = maximum_node)
  queue <- seq_len(number_tips)

  while (length(queue) > 0L) {
    child <- queue[[1L]]
    queue <- queue[-1L]
    index <- edge_for_child[[child]]
    if (index == 0L) next

    parent <- edge[index, 1L]
    below <- descendants[[child]]
    if (is.null(below)) below <- integer()
    edge_descendants[[index]] <- below
    if (length(below) > 0L) {
      descendants[[parent]] <- c(descendants[[parent]], below)
    }

    children_remaining[[parent]] <- children_remaining[[parent]] - 1L
    if (children_remaining[[parent]] == 0L) {
      queue <- c(queue, parent)
    }
  }

  number_descendants <- lengths(edge_descendants)
  incidence <- Matrix::sparseMatrix(
    i = unlist(edge_descendants, use.names = FALSE),
    j = rep(seq_len(nrow(edge)), times = number_descendants),
    x = 1,
    dims = c(length(path_tip_nodes), nrow(edge))
  )

  list(
    incidence = incidence,
    edge_length = as.numeric(tree$edge.length)
  )
}

.pd_from_sparse_presence <- function(
    presence,
    edge_incidence,
    edge_length,
    include_root) {
  richness <- as.numeric(Matrix::rowSums(presence))
  counts <- presence %*% edge_incidence
  entries <- Matrix::summary(counts)
  out <- numeric(nrow(presence))

  if (nrow(entries) == 0L) {
    return(out)
  }

  keep <- entries$x > 0
  if (!isTRUE(include_root)) {
    keep <- keep & entries$x < richness[entries$i]
  }

  if (any(keep)) {
    row_id <- entries$i[keep]
    contribution <- edge_length[entries$j[keep]]
    sums <- rowsum(
      matrix(contribution, ncol = 1L),
      group = row_id,
      reorder = FALSE
    )
    out[as.integer(row.names(sums))] <- sums[, 1L]
  }

  out
}

#' Calculate file-backed phylogenetic diversity
#'
#' Calculates Faith's phylogenetic diversity from named, single-layer binary
#' raster files. Raster values are read in spatial blocks and converted to a
#' sparse presence matrix. Tree edges are represented once as a sparse
#' species-by-edge matrix, so the complete study-area cells-by-species matrix
#' is never materialized.
#'
#' Missing values in a species raster are treated as absence inside the common
#' template domain, matching the existing richness reduction. Cells outside
#' that domain remain `NA` in the output.
#'
#' With the default `include_root = FALSE`, an edge contributes to a cell only
#' when at least one, but not all, species present in that cell descend from
#' the edge. This is the minimal subtree connecting the present species and is
#' equivalent to `picante::pd(..., include.root = FALSE)` for assemblages with
#' at least two species. Consistent with [calc_pd_raster()], empty and
#' single-species cells are recorded as PD zero rather than `NA`.
#'
#' @param paths Named character vector of single-layer binary raster files.
#'   Names must be species names, for example the output of
#'   [select_projection_paths()].
#' @param Tree One rooted `phylo` with finite branch lengths. Legacy
#'   V.PhyloMaker results containing `scenario.3` are also accepted.
#' @param template A `terra::SpatRaster` or raster file path vector defining
#'   the output geometry and common non-missing domain.
#' @param filename Output GeoTIFF path.
#' @param name Output raster-layer name. Default `"PD"`.
#' @param include_root Whether to include branches from the assemblage's most
#'   recent common ancestor to the tree root. Default `FALSE`.
#' @param unmatched How species files absent from the tree are handled.
#'   `"error"` is the safe default; `"drop"` explicitly excludes them.
#' @param align Geometry handling. `"error"` requires every binary raster to
#'   match `template`; `"near"` uses nearest-neighbour alignment.
#' @param max_cells_per_block Maximum number of spatial cells read per block.
#'   Memory also scales with the number of species in this tree group.
#' @param overwrite Whether `filename` may be replaced. Default `TRUE`.
#' @param verbose Whether to report block progress. Default `TRUE`.
#'
#' @return A file-backed, single-layer `terra::SpatRaster` in the branch-length
#'   units of `Tree`.
#' @export
calc_pd_files <- function(
    paths,
    Tree,
    template,
    filename,
    name = "PD",
    include_root = FALSE,
    unmatched = c("error", "drop"),
    align = c("error", "near"),
    max_cells_per_block = 20000L,
    overwrite = TRUE,
    verbose = TRUE) {
  paths <- .validate_named_binary_paths(paths)
  unmatched <- match.arg(unmatched)
  align <- match.arg(align)
  .range_rarity_assert_scalar_character(filename, "filename")
  .range_rarity_assert_scalar_character(name, "name")

  if (!is.logical(include_root) || length(include_root) != 1L || is.na(include_root)) {
    stop("`include_root` must be TRUE or FALSE.", call. = FALSE)
  }
  if (
    !is.numeric(max_cells_per_block) ||
      length(max_cells_per_block) != 1L ||
      is.na(max_cells_per_block) ||
      !is.finite(max_cells_per_block) ||
      max_cells_per_block != floor(max_cells_per_block) ||
      max_cells_per_block < 1L
  ) {
    stop("`max_cells_per_block` must be one positive integer.", call. = FALSE)
  }
  max_cells_per_block <- as.integer(max_cells_per_block)
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

  checked_tree <- .validate_pd_tree(Tree)
  path_key <- .rtrees_species_key(names(paths))
  tip_index <- match(path_key, checked_tree$tip_key)
  duplicated_tip_matches <- unique(
    tip_index[!is.na(tip_index) & duplicated(tip_index)]
  )
  if (length(duplicated_tip_matches) > 0L) {
    duplicated_species <- names(paths)[
      tip_index %in% duplicated_tip_matches
    ]
    stop(
      "Multiple binary rasters match the same normalized tree tip: ",
      paste(duplicated_species, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  missing_tree_species <- names(paths)[is.na(tip_index)]
  if (length(missing_tree_species) > 0L && identical(unmatched, "error")) {
    stop(
      "Binary raster species missing from `Tree`: ",
      paste(utils::head(missing_tree_species, 20L), collapse = ", "),
      if (length(missing_tree_species) > 20L) " ..." else "",
      ". Run `audit_tree_coverage()` before PD calculation.",
      call. = FALSE
    )
  }
  if (length(missing_tree_species) > 0L) {
    keep <- !is.na(tip_index)
    paths <- paths[keep]
    tip_index <- tip_index[keep]
    if (isTRUE(verbose)) {
      message(
        "Dropping ", length(missing_tree_species),
        " species absent from the tree."
      )
    }
  }
  if (length(paths) == 0L) {
    stop("No binary raster species match `Tree`.", call. = FALSE)
  }

  edge_data <- .pd_edge_incidence(
    tree = checked_tree$tree,
    path_tip_nodes = tip_index
  )
  domain <- .range_rarity_domain(template)
  dir.create(dirname(filename), recursive = TRUE, showWarnings = FALSE)

  temporary_files <- character()
  working_file <- tempfile(
    pattern = "SpeciesPoolR_pd_",
    tmpdir = dirname(filename),
    fileext = ".tif"
  )
  on.exit({
    invisible(gc())
    existing <- c(temporary_files, working_file)
    existing <- existing[file.exists(existing)]
    if (length(existing) > 0L) unlink(existing, force = TRUE)
  }, add = TRUE)

  aligned_paths <- character(length(paths))
  for (index in seq_along(paths)) {
    prepared <- .prepare_binary_for_domain(
      path = unname(paths[[index]]),
      domain = domain,
      align = align
    )
    if (!is.na(prepared$temporary)) {
      temporary_files <- c(temporary_files, prepared$temporary)
    }
    aligned_paths[[index]] <- if (is.na(prepared$temporary)) {
      unname(paths[[index]])
    } else {
      prepared$temporary
    }
    rm(prepared)
  }
  invisible(gc())

  binary_stack <- terra::rast(aligned_paths)
  names(binary_stack) <- names(paths)
  output <- terra::rast(domain, nlyrs = 1L)
  names(output) <- name

  stack_open <- FALSE
  domain_open <- FALSE
  output_open <- FALSE
  on.exit({
    if (stack_open) try(terra::readStop(binary_stack), silent = TRUE)
    if (domain_open) try(terra::readStop(domain), silent = TRUE)
    if (output_open) try(terra::writeStop(output), silent = TRUE)
  }, add = TRUE)

  terra::readStart(binary_stack)
  stack_open <- TRUE
  terra::readStart(domain)
  domain_open <- TRUE
  terra::writeStart(
    output,
    filename = working_file,
    overwrite = TRUE,
    wopt = list(
      datatype = "FLT8S",
      gdal = c("COMPRESS=DEFLATE", "TILED=YES")
    )
  )
  output_open <- TRUE

  rows_per_block <- max(
    1L,
    as.integer(floor(max_cells_per_block / terra::ncol(domain)))
  )
  first_rows <- seq.int(1L, terra::nrow(domain), by = rows_per_block)
  report_every <- max(1L, as.integer(floor(length(first_rows) / 10L)))

  for (block in seq_along(first_rows)) {
    first_row <- first_rows[[block]]
    number_rows <- min(
      rows_per_block,
      terra::nrow(domain) - first_row + 1L
    )
    domain_values <- terra::readValues(
      domain,
      row = first_row,
      nrows = number_rows,
      mat = FALSE
    )
    binary_values <- terra::readValues(
      binary_stack,
      row = first_row,
      nrows = number_rows,
      mat = TRUE
    )
    if (is.null(dim(binary_values))) {
      binary_values <- matrix(binary_values, ncol = length(paths))
    }

    inside <- !is.na(domain_values)
    result_values <- rep(NA_real_, length(domain_values))
    if (any(inside)) {
      assemblage <- binary_values[inside, , drop = FALSE]
      invalid <- !is.na(assemblage) & assemblage != 0 & assemblage != 1
      if (any(invalid)) {
        invalid_column <- which(invalid, arr.ind = TRUE)[1L, 2L]
        stop(
          "Binary raster for `", names(paths)[[invalid_column]],
          "` contains a finite value other than 0 or 1.",
          call. = FALSE
        )
      }
      assemblage[is.na(assemblage)] <- 0
      presence <- Matrix::Matrix(assemblage, sparse = TRUE)
      result_values[inside] <- .pd_from_sparse_presence(
        presence = presence,
        edge_incidence = edge_data$incidence,
        edge_length = edge_data$edge_length,
        include_root = include_root
      )
    }

    terra::writeValues(
      output,
      result_values,
      start = first_row,
      nrows = number_rows
    )

    if (
      isTRUE(verbose) &&
        (block == 1L || block %% report_every == 0L || block == length(first_rows))
    ) {
      message(
        "Calculated PD block ", block,
        " of ", length(first_rows), "."
      )
    }
  }

  terra::readStop(binary_stack)
  stack_open <- FALSE
  terra::readStop(domain)
  domain_open <- FALSE
  output <- terra::writeStop(output)
  output_open <- FALSE

  rm(binary_stack, domain, output)
  invisible(gc())
  if (!file.copy(working_file, filename, overwrite = overwrite)) {
    stop("Could not copy the completed PD raster to: ", filename, call. = FALSE)
  }
  unlink(working_file, force = TRUE)
  working_file <- character()

  existing_temporary <- temporary_files[file.exists(temporary_files)]
  if (length(existing_temporary) > 0L) {
    unlink(existing_temporary, force = TRUE)
  }
  temporary_files <- character()
  result <- terra::rast(filename)
  names(result) <- name
  result
}

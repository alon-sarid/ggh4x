# User function -----------------------------------------------------------

#' Axis guide with ticks for minor breaks
#'
#' These are similar the the normal axis guides for position scales, but also
#' place tickmarks at minor break positions.
#'
#' @inheritParams ggplot2::guide_axis
#'
#' @details The length of minor ticks can be controlled relative to the length
#'   of major ticks by setting \code{ggh4x.axis.ticks.length.minor} as a
#'   \code{rel} object.
#'
#' @return A \emph{axis_minor} guide class object.
#' @export
#'
#' @examples
#' # Using the minor breaks axis
#' p <- ggplot(iris, aes(Sepal.Width, Sepal.Length)) +
#'   geom_point()
#' p + scale_y_continuous(guide = "axis_minor")
#'
#' # Minor break positions are still controlled by the scale
#' p + scale_y_continuous(guide = "axis_minor",
#'                        minor_breaks = seq(4, 8, by = 0.2))
#'
#' # Minor tick length is controlled relative to major ticks
#' p + scale_y_continuous(guide = "axis_minor") +
#'   theme(ggh4x.axis.ticks.length.minor = rel(0.1))
guide_axis_minor <- function(
  title = waiver(),
  check.overlap = FALSE,
  angle = NULL,
  n.dodge = 1,
  order = 0,
  position = waiver()
) {
  structure(
    list(
      title = title,
      check.overlap = check.overlap,
      angle = angle,
      n.dodge = n.dodge,
      order = order,
      position = position,
      available_aes = c("x", "y"),
      name = "axis"
    ),
    class = c("guide", "axis_minor", "axis")
  )
}

# Internals ---------------------------------------------------------------

#' @export
#' @noRd
guide_train.axis_minor <- function(
  guide, scale, aesthetic = NULL
) {
  aesthetic <- aesthetic %||% scale$aesthetics[1]
  # Get major and minor breaks
  breaks_major <- scale$get_breaks()
  breaks_minor <- scale$get_breaks_minor()
  # Set actual breaks to union
  breaks <- union(breaks_major, breaks_minor)
  is_major <- breaks %in% breaks_major

  empty_ticks <- ggplot2:::new_data_frame(
    list(aesthetic = numeric(), .value = numeric(0), .label = character())
  )
  if (length(intersect(scale$aesthetics, guide$available_aes)) == 0) {
    warn(glue("axis guide needs appropriate scales: ",
              glue_collapse(guide$available_aes, ", ", last = " or ")))
    guide$key <- empty_ticks
  } else if (length(breaks) == 0) {
    guide$key <- empty_ticks
  } else {
    mapped_breaks <- if (scale$is_discrete()) {
      scale$map(breaks)
    } else {
      breaks
    }
    ticks <- ggplot2:::new_data_frame(setNames(list(mapped_breaks),
                                               aesthetic))
    ticks$.value <- breaks
    ticks$.label <- ""
    ticks$.label[is_major] <- scale$get_labels(breaks[is_major])

    # Now this is the bit where we set minor breaks to have empty labls
    ticks$.minority <- as.numeric(!is_major)

    guide$key <- ticks[is.finite(ticks[[aesthetic]]), ]
  }
  guide$name <- paste0(guide$name, "_", aesthetic)
  guide$hash <- digest::digest(list(guide$title, guide$key$.value,
                                    guide$key$.label, guide$name))
  guide
}

#' @export
#' @noRd
guide_gengrob.axis_minor <- function(guide, theme) {
  aesthetic <- names(guide$key)[!grepl("^\\.", names(guide$key))][1]
  draw_axis_minor(
    break_positions = guide$key[[aesthetic]],
    break_labels = guide$key$.label,
    axis_position = guide$position,
    theme = theme,
    check.overlap = guide$check.overlap,
    angle = guide$angle,
    n.dodge = guide$n.dodge,
    minority = guide$key$.minority
  )
}

draw_axis_minor <- function(
  break_positions,
  break_labels,
  axis_position,
  theme,
  check.overlap,
  angle = NULL,
  n.dodge = 1,
  minority = 0
) {
  axis_position <- match.arg(substr(axis_position, 1, 1),
                             c("t", "b", "r", "l"))
  aes <- if (axis_position %in% c("t", "b")) "x" else "y"

  elements <- build_axis_elements(axis_position, angle, theme)
  minor_len <- theme[["ggh4x.axis.ticks.length.minor"]]
  if (inherits(minor_len, "rel")) {
    elements$minor_len <- elements$tick_length * unclass(minor_len)
  } else {
    elements$minor_len <- minor_len
  }
  mini_len <- theme[["ggh4x.axis.ticks.length.minor"]]
  if (inherits(mini_len, "rel")) {
    elements$mini_len <- elements$tick_length * unclass(mini_len)
  } else {
    elements$mini_len <- mini_len
  }

  params <- setup_axis_params(axis_position)
  line_grob <- build_axis_line(elements$line, params)

  if ({n_breaks <- length(break_positions[minority == 0])} == 0) {
    out <- grid::gTree(
      children = grid::gList(line_grob),
      width = grid::grobWidth(line_grob),
      height = grid::grobHeight(line_grob),
      cl = "abosluteGrob"
    )
    return(out)
  }
  is_major <- minority == 0

  label_grobs <- build_axis_labels(
    elements,
    labels = break_labels[is_major],
    position = break_positions[is_major],
    dodge = n.dodge, check.overlap = check.overlap, params = params
  )

  # Setup ticks
  sizes <- unit.c(elements$tick_length, elements$minor_len, elements$mini_len)
  tick_grob <- build_axis_ticks_minor(elements$ticks, sizes,
                                      break_positions, params, minority)
  elements$tick_length <- max(sizes)

  assemble_axis_grobs(ticks = tick_grob, labels = label_grobs,
                      lines = line_grob, elements = elements,
                      params = params)
}

# Helpers -----------------------------------------------------------------

build_axis_ticks_minor <- function(element, length, position, params,
                                   minority = 0) {
  n_breaks <- length(position)
  pos <- params$pos + (params$tick_dir * length)
  pos <- grid::unit.c(params$pos, pos)
  idx <- c(do.call(rbind,
                   list(rep(1, n_breaks), minority + 2)[params$tick_ord]))
  pos <- pos[idx]

  args <- list(element, unit(rep(position, each = 2), "native"),
               pos, rep(2, times = n_breaks))
  names(args) <- c("element", params$aes, params$non_aes, "id.lengths")

  do.call(element_grob, args)
}







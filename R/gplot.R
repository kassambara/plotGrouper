# Copyright 2017-2018 John Gagnon
# This program is distributed under the terms of the GNU General Public License

#' A function to create a grouped plot and return a table grob.
#'
#' This function allows you to create a grouped plot and return a table grob.
#' It takes a tidy dataset containing sample replicate values for at least one
#' variable, a column organizing each replicate into the proper comparison
#' group, and a column that groups the variables to be plotted. Additional
#' arguments allow for the re-ordering of the variables and the
#' comparisons being ploted, selection of the type of graph to display (e.g.,
#' bar graph, boxplot, violin plot, points, statistical summary, etc...), as
#' well as other aesthetics of the plot.
#' @import shiny
#' @import shinythemes
#' @import dplyr
#' @import ggplot2
#' @rawNamespace import(Hmisc, except = c(summarize, src))
#' @importFrom rlang .data
#' @importFrom tibble as.tibble
#' @importFrom grid convertUnit nullGrob
#' @importFrom gridExtra grid.arrange arrangeGrob
#' @importFrom egg set_panel_size
#' @importFrom readxl excel_sheets read_excel
#' @importFrom ggpubr compare_means get_legend
#' @importFrom gtable gtable_add_padding
#' @importFrom readr parse_number read_csv read_tsv
#' @importFrom scales trans_format math_format rescale_none
#' @importFrom stringr str_remove str_split word
#' @importFrom tidyr gather
#' @importFrom stats na.omit start
#' @importFrom colourpicker colourInput updateColourInput
#' @param dataset Define your data set which should be a gathered tibble
#' @param comparison Specify the comparison you would like to make
#' (e.g., Genotype)
#' @param group.by Specify the variable to group by (e.g., Tissue).
#' @param levs Specify the order of the grouping variables
#' @param val Specify column name that contains values (optional)
#' @param geom Define the list of geoms you want to plot
#' @param p Specify representation of pvalue
#' (p.signif = astrisk representation of the raw p value;
#' p.format = 'p = 0.05'; 
#' p.adj = adjusted p-value; 
#' p.adj.signif = astrisk representation of the adjusted p value)
#' @param ref.group Specify a reference group to compare all other
#' comparisons to
#' @param p.adjust.method Method used for adjusting the pvalue
#' @param method Specify the statistical test to be used
#' @param paired Specify whether or not the statistical comparisons should be
#' paired
#' @param errortype Specify the method of statistical error to plot
#' @param comparisons Specify which of the available comparisons within your
#' data you would like to plot
#' @param y.lim Specify the min and max values to be used for the y-axis
#' @param y.lab Specify a custom y-axis label to use
#' @param expand.y Specify values to expand the y-axis
#' @param trans.y Specify the transformation to perform on the dependent
#' variable
#' @param x.lim Specify the min and max values to be used for the x-axis
#' @param x.lab Specify a custom x-axis label to use
#' @param trans.x Specify the transformation to perform on the independent
#' variable
#' @param sci Specify whether or not to display the dependent variable using
#' scientific notation
#' @param angle.x Specify whether or not to angle the x-axis text 45deg
#' @param levs.comps Specify the order in which to plot the comparisons
#' @param group.labs Specify custom labels for the independent variables
#' @param stats Specify whether or not to output the statistics table
#' @param split Specify whether or not to split the x-axis label text
#' @param split_str Specify the string to split the x-axis label text by; uses
#' regex
#' @param trim Specify the string to trim text from the right side of the
#' x-axis label text; uses regex
#' @param leg.pos Specify where to place the legend
#' @param stroke Specify the line thickness to use
#' @param font_size Specify the font size to use
#' @param size Specify the size of the points to use
#' @param width Specify the width of groups to be plotted
#' @param dodge Specify the width to dodge the comparisons by
#' @param plotWidth Specify the length of the x-axis in mm
#' @param plotHeight Specify the length of the y-axis in mm
#' @param shape.groups Specify the default shapes to use for the comparisons
#' @param color.groups Specify the default colors to use for the comparisons
#' @param fill.groups Specify the default fills to use for the comparisons
#' @return Table grob of the plot
#' @examples
#' iris %>% dplyr::mutate(Species = as.character(Species)) %>%
#' dplyr::group_by(Species) %>%
#' dplyr::mutate(Sample = paste0(Species, "_", dplyr::row_number()),
#' Sheet = "iris") %>%
#' dplyr::select(Sample, Sheet, Species, dplyr::everything()) %>%
#' tidyr::gather(variable, value, -c(Sample, Sheet, Species)) %>%
#' dplyr::filter(variable == "Sepal.Length") %>%
#' plotGrouper::gplot(
#' comparison = "Species",
#' group.by = "variable",
#' shape.groups = c(19,21,17),
#' color.groups = c(rep("black",3)),
#' fill.groups = c("black","#E016BE", "#1243C9")) %>%
#' gridExtra::grid.arrange()
#' @export
gplot <- function(dataset = NULL,
                  comparison = NULL,
                  group.by = NULL,
                  levs = TRUE,
                  val = "value",
                  geom = c("bar",
                           "errorbar",
                           "point",
                           "stat",
                           "seg"),
                  p = "p.signif",
                  ref.group = NULL,
                  p.adjust.method = "holm",
                  comparisons = NULL,
                  method = "t.test",
                  paired = FALSE,
                  errortype = "mean_sdl",
                  y.lim = NULL,
                  y.lab = NULL,
                  trans.y = "identity",
                  x.lim = c(NA, NA),
                  expand.y = c(0, 0),
                  x.lab = NULL,
                  trans.x = "identity",
                  sci = FALSE,
                  angle.x = FALSE,
                  levs.comps = TRUE,
                  group.labs = NULL,
                  stats = FALSE,
                  split = TRUE,
                  split_str = NULL,
                  trim = "none",
                  leg.pos = "top",
                  stroke = 0.25,
                  font_size = 9,
                  size = 1,
                  width = 0.8,
                  dodge = 0.8,
                  plotWidth = 30,
                  plotHeight = 40,
                  shape.groups = c(19, 21),
                  color.groups = c("black", "black"),
                  fill.groups = c("#444444", NA, "#A33838")) {
  . <- "Stop NOTE"
  
  df <- droplevels(dataset)
  
  # If the column of values has a different column name than 'value',
  # assign it 'value'
  colnames(df)[colnames(df) == val] <- "value"
  df$value <- as.numeric(df$value)
  
  # If comparison variable is not a factor, coerce it to one
  if (!is.factor(df[[comparison]])) {
    df[, comparison] <- factor(df[[comparison]],
                               levels = unique(df[[comparison]])[levs.comps])
  }
  
  df <- dplyr::arrange_(df, comparison)
  
  # Assign labels to the groups
  suppressWarnings(if (is.null(group.labs) & split == FALSE) {
    group.labs <- function(x) {
      x
    }
  } else if (is.null(group.labs) &
             split & is.null(split_str)) {
    group.labs <- function(x) {
      vapply(stringr::str_remove(
        stringr::word(stringr::str_remove(x, trim),-1,
                      sep = "/"),
        " %| #|% |# "
      ),
      "[",
      FUN.VALUE = "",
      1)
    }
  } else if (is.null(group.labs) &
             split & !is.null(split_str)) {
    group.labs <- function(x) {
      vapply(
        strsplit(
          stringr::str_remove(x, trim),
          split = split_str,
          fixed = TRUE
        ),
        "[",
        FUN.VALUE = "",
        2
      )
    }
  } else {
    group.labs <- group.labs
  })
  
  # If grouping variable is not numeric, scale x discretely, and assign levels.
  # If it is numeric, scale x continuously
  if (is.factor(df[[group.by]])) {
    scale.x <- ggplot2::scale_x_discrete(labels = group.labs,
                                         breaks = unique(df[[group.by]]))
  } else if (!is.numeric(df[[group.by]]) &
             !is.factor(df[[group.by]])) {
    df[, group.by] <- factor(df[[group.by]],
                             levels = unique(df[[group.by]])[levs])
    scale.x <- ggplot2::scale_x_discrete(labels = group.labs,
                                         breaks = unique(df[[group.by]]))
  } else {
    scale.x <- ggplot2::scale_x_continuous(
      breaks = df[[group.by]],
      labels = formatC(df[[group.by]],
                       drop0trailing = TRUE),
      trans = trans.x,
      limits = x.lim
    )
  }
  
  # Create a tibble of max values by group for assigning height of p values
  d_min <- droplevels(
    df %>%
      dplyr::group_by_(group.by, comparison) %>%
      dplyr::mutate("min_error" = min(
          get(errortype)(.data$value, mult = 1),
          na.rm = TRUE)) %>%
      dplyr::ungroup() %>%
      dplyr::group_by_(group.by) %>%
      dplyr::slice(which.min(.data$value)) %>%
      dplyr::mutate("min_value" = .data$value) %>%
      dplyr::select_(group.by, 
                     "min_value", 
                     "min_error") %>%
      dplyr::ungroup() %>%
      dplyr::mutate("min" = min(c(.data$min_value, 
                  .data$min_error),
                na.rm = TRUE)) %>%
      dplyr::arrange_(group.by)
  )
  
  d_max <- droplevels(
    df %>%
      dplyr::group_by_(group.by, comparison) %>%
      dplyr::mutate(
        "max_error" = max(
          get(errortype)(.data$value, mult = 1),
          na.rm = TRUE)) %>%
      dplyr::ungroup() %>%
      dplyr::group_by_(group.by) %>%
      dplyr::slice(which.max(.data$value)) %>%
      dplyr::mutate("max_value" = .data$value) %>%
      dplyr::select_(group.by, 
                     "max_value", 
                     "max_error") %>%
      dplyr::ungroup() %>%
      dplyr::arrange_(group.by)
  )
  
  d_min_max <- dplyr::left_join(d_min, d_max, by = group.by)

  
  # If no comparisons are specified, perform all comparisons
  if (is.null(comparisons)) {
    comparisons <- df[[comparison]]
  }
  
  symnum.args <- list(
    cutpoints = c(0, 0.0001, 0.001, 0.01, 0.05, 1),
    symbols = c("****", "***", "**", "*", NA)
  )
  
  # Calculate p values for all comparisons being made
  statOut <- try(ggpubr::compare_means(
    formula = stats::formula(paste("value", "~", comparison)),
    data = df,
    method = method,
    group.by = group.by,
    ref.group = ref.group,
    paired = paired,
    symnum.args = symnum.args,
    p.adjust.method = p.adjust.method) %>%
    mutate("p.adj.method" = p.adjust.method))
  statOut$p.adj.signif <- try(vapply(X = statOut$p.adj, 
                                     FUN = stats::symnum, 
                                     FUN.VALUE = "",
                                     cutpoints = symnum.args$cutpoints,
                                     symbols = symnum.args$symbols))
  
  if (method %in% c("t.test", "wilcox.test")) {
    statistics <- try(dplyr::left_join(statOut, d_max, by = group.by) %>%
                        dplyr::filter(.data$group1 %in% comparisons |
                                        .data$group2 %in% comparisons) %>%
                        # Find max value (individual point or errorbar)
                        dplyr::mutate("max" = max(c(.data$max_value, 
                                                    .data$max_error),
                                                  na.rm = TRUE)) %>%
                        dplyr::group_by_(group.by) %>%
                        dplyr::mutate(
                          "max_group" = max(c(.data$max_value,
                                              .data$max_error),
                                            na.rm = TRUE),
                          # Row number
                          "n" = dplyr::row_number(),
                          # First comparison group
                          "group1" = factor(.data$group1, 
                                            levels = levels(df[[comparison]])),
                          # Second comparison group
                          "group2" = factor(.data$group2, 
                                            levels = levels(df[[comparison]])),
                          # Adjustment of the height of the segment
                          "r" = dplyr::if_else(p == "p.signif" |
                                             p == "p.adj.signif",
                                               .data$max * 0.1 * 0.05,
                                               .data$max * 0.2 * 0.05),
                          # Adjustment of the hieght of the stats
                          "e" = .data$max * .data$n * 0.05,
                          # Number of comparisons
                          "n_comps" = max(.data$n),
                          # Number of grouping variables
                          "group.by_n" = as.numeric(get(group.by)),
                          # Group number associated with first comparison group
                          "group1_n" = as.integer(.data$group1),
                          # Group number associated with second comparison group
                          "group2_n" = as.integer(.data$group2),
                          # Relative width of 1 bar
                          "unit" = (width / max(.data$group2_n)) * 
                            dodge / 
                            width, 
                          # Center position of the first bar
                          "start" = .data$group.by_n -
                            .data$unit *
                            max(.data$group2_n) / 2,
                          # Center position of group1
                          "w.start" = .data$start +
                            (.data$group1_n - 1) *
                            .data$unit +
                            .data$unit /
                            2,
                          # Center position of group2
                          "w.stop" = .data$start +
                            (.data$group2_n - 1) *
                            .data$unit +
                            .data$unit / 2
                        ) %>% 
                        dplyr::ungroup() %>%
                        dplyr::mutate(
                          # Center of comparison line segment
                          "x.pos" = rowMeans(.[, c("w.start",
                                                   "w.stop")]),
                          # Update w.start if p.signif is.na()
                          "w.start" = ifelse(!is.na(.data$p.signif), 
                                             .data$w.start, NA),
                          # Update w.stop if p.signif is.na()
                          "w.stop" = ifelse(!is.na(.data$p.signif), 
                                            .data$w.stop, NA),
                          # Adjust height of stats
                          "h.p" = .data$max_group + .data$e,
                          # Adjust height of comparison line segment
                          "h.s" = .data$max_group + .data$e - .data$r
                        ))
  } else {
    statistics <- try(dplyr::left_join(statOut, d_max, by = group.by) %>%
                        # Find max value (individual point or errorbar)
                        dplyr::mutate("max" = max(c(max_value, max_error), 
                                                  na.rm = T)) %>%
                        dplyr::group_by_(group.by) %>%
                        dplyr::mutate(
                          "max_group" = max(c(.data$max_value,
                                              .data$max_error),
                                            na.rm = TRUE),
                          "n" = dplyr::row_number(),
                          "r" = dplyr::if_else(p == "p.signif" |
                                               p == "p.adj.signif", 
                                               max * 0.1 * 0.05, 
                                               max * 0.2 * 0.05),
                          "e" = .data$max * .data$n * 0.05,
                          "n_comps" = max(.data$n),
                          "group.by_n" = as.numeric(get(group.by)),
                          "w.start" = .data$group.by_n - 
                            width / length(unique(df[[comparison]])),
                          "w.stop" = .data$group.by_n + 
                            width / 
                            length(unique(df[[comparison]]))
                        ) %>%
                        dplyr::ungroup() %>%
                        dplyr::mutate(
                          "x.pos" = rowMeans(.[, c("w.start", "w.stop")]),
                          # center of segment
                          "w.start" = ifelse(!is.na(.data$p.signif), 
                                             .data$w.start, 
                                             NA),
                          "w.stop" = ifelse(!is.na(.data$p.signif), 
                                            .data$w.stop, 
                                            NA),
                          "h.p" = .data$max_group + .data$e,
                          "h.s" = .data$max_group + .data$e - .data$r
                        ))
  }
  if (("try-error" %in% class(statOut))) {
    statistics <- dplyr::tibble("p.signif" = NA)
  }
  if (("try-error" %in% class(statistics))) {
    statistics <- dplyr::tibble("p.signif" = NA)
  }
  if (stats) {
    return(statOut)
  }
  
  # Specify y-axis limits
  if (all(is.na(y.lim))) {
    y.lim <-
      c(0, max(d_max[, c("max_value", "max_error")], na.rm = TRUE) * 1.08)
  }
  if (!is.na(y.lim[1]) & is.na(y.lim[2])) {
    y.lim <- c(y.lim[1], max(d_max[, c("max_value", "max_error")],
                             na.rm = TRUE) * 1.08)
  }
  if (!is.na(y.lim[2] & is.na(y.lim[1]))) {
    y.lim <- c(0, y.lim[2])
  }
  
  # Adjust y limits if y transformation
  # if (trans.y != "identity" & !all(is.na(statistics$p.signif))) {
  #   logBase <- readr::parse_number(trans.y)
  #   # statistics <- statistics %>%
  #   #   dplyr::mutate("h.p" = .data$h.p * logBase,
  #   #                 "h.s" = .data$h.s * logBase)
  #   
  # }
  
  # If not specified by user, set y axis label to the variable being plotted.
  if (is.null(y.lab)) {
    y.lab <- unique(df$variable)
    
    if (length(y.lab) > 1) {
      y.lab <- y.lab[1]
    }
  }
  
  # Make pretty scientific notation
  max_e <- as.numeric(stringr::str_split(
    string = format(max(c(
      d_max$max_value,
      d_max$max_error
    )),
    scientific = TRUE),
    pattern = "e\\+"
  )[[1]][2])
  
  fancy_scientific <- function(l) {
    l <- format(l, scientific = TRUE)
    e <- as.numeric(vapply(l, function(a) {
      stringr::str_split(a, pattern = "e\\+")[[1]][2]
    }, ""))
    e_dif <- as.numeric(vapply(e, function(x) {
      (max_e - x)
    }, numeric(1)))
    l <- as.numeric(vapply(l, function(x) {
      stringr::str_split(string = x, pattern = "e\\+")[[1]][1]
    }, ""))
    l2 <- c()
    for (i in seq_len(length(e))) {
      l2[i] <- ifelse(e[i] == 0, l[i],
                      ifelse(e[i] < max_e, (10 ^ -e_dif[i]) * l[i], l[i]))
    }
    
    format(l2, trim = FALSE)
  }
  
  if (angle.x) {
    angle <- 45
    vjust <- 1
    hjust <- 1
  } else {
    angle <- 0
    vjust <- 0
    hjust <- 0.5
  }
  
  if (sci) {
    labs.y <- fancy_scientific
    y.lab <-
      bquote(.(paste0(gsub(
        "\\s*#\\s*", "", y.lab
      ), " "))(10 ^ .(max_e)))
  } else {
    labs.y <- ggplot2::waiver()
  }
  if (trans.y != "identity") {
    assign("statistics", statistics, envir = globalenv())
    .x <- NULL
    if (trans.y == "log2") {
      labs.y <- scales::trans_format(trans.y, scales::math_format(2 ^ .x))
    } else {
      labs.y <- scales::trans_format(trans.y, scales::math_format(10 ^ .x))
    }
    if (min(d_min$min, na.rm = TRUE) >= 0) {
      y.lim <- 
        c(NA,
          max(d_max[, c("max_value", "max_error")], na.rm = TRUE) * 1.08)
    }
    if (min(d_min$min, na.rm = TRUE) < 0) {
      y.lim <- 
        c(NA,
          max(d_max[, c("max_value", "max_error")], na.rm = TRUE) * 1.08)
    }
  }
  
  # Assign names to the shape, fill, color, and alpha arguments
  
  for (x in c("shape.groups", "fill.groups", "color.groups")) {
    assign(x, stats::setNames(object = get(x), levels(df[[comparison]])))
  }
  
  # Create geoms
  crossbar <- ggplot2::stat_summary(
    ggplot2::aes(
      group = get(comparison),
      color = get(comparison)
    ),
    fun.y = mean,
    fun.ymax = mean,
    fun.ymin = mean,
    size = stroke / 3,
    geom = "crossbar",
    width = width,
    position = ggplot2::position_dodge(dodge)
  )
  
  point <- ggplot2::geom_point(
    ggplot2::aes(
      shape = get(comparison),
      color = get(comparison)
    ),
    stroke = stroke,
    size = size,
    position = ggplot2::position_jitterdodge(jitter.width = 0.25,
                                             dodge.width = dodge)
  )
  
  point_noJitter <- ggplot2::geom_point(
    ggplot2::aes(
      shape = get(comparison),
      color = get(comparison)
    ),
    stroke = stroke,
    size = size,
    position = ggplot2::position_dodge(dodge)
  )
  
  errorbar <-
    ggplot2::stat_summary(
      ggplot2::aes(group = get(comparison)),
      fun.data = errortype,
      fun.args = list(mult = 1),
      geom = "errorbar",
      color = "black",
      width = 0.25 * width,
      position = ggplot2::position_dodge(dodge),
      size = stroke
    )
  
  bar <- ggplot2::stat_summary(
    ggplot2::aes(fill = get(comparison)),
    color = "black",
    fun.y = mean,
    size = stroke,
    geom = "bar",
    width = width,
    position = ggplot2::position_dodge(dodge),
    show.legend = TRUE
  )
  
  violin <- ggplot2::geom_violin(
    ggplot2::aes(fill = get(comparison),
                 color = get(comparison)),
    show.legend = TRUE,
    position = ggplot2::position_dodge(dodge)
  )
  
  box <- ggplot2::geom_boxplot(
    ggplot2::aes(color = get(comparison),
                 fill = get(comparison)),
    show.legend = TRUE,
    position = ggplot2::position_dodge(dodge)
  )
  
  line <- ggplot2::stat_summary(
    ggplot2::aes(
      group = get(comparison),
      color = get(comparison)
    ),
    fun.y = mean,
    geom = "line",
    size = stroke
  )
  
  line_error <-
    ggplot2::stat_summary(
      ggplot2::aes(group = get(comparison)),
      fun.data = errortype,
      fun.args = list(mult = 1),
      geom = "errorbar",
      color = "black",
      width = 0.25 * width,
      size = stroke
    )
  
  line_point <- ggplot2::stat_summary(
    ggplot2::aes(
      fill = get(comparison),
      shape = get(comparison),
      color = get(comparison)
    ),
    stroke = stroke,
    size = size,
    fun.y = mean,
    geom = "point"
  )
  
  dot <-
    ggplot2::geom_dotplot(
      ggplot2::aes(color = get(comparison)),
      binaxis = "y",
      stackdir = "center",
      method = "histodot",
      position = ggplot2::position_dodge(dodge)
    )
  
  density <- ggplot2::geom_density(ggplot2::aes(
    color = get(comparison),
    fill = get(comparison),
    x = .data$value
  ),
  inherit.aes = FALSE)
  
  if (all(is.na(statOut$p.signif))) {
    geom <- geom[which(!geom %in% c("stat", "seg"))]
  } else {
    stat <- ggplot2::geom_text(
      data = statistics,
      ggplot2::aes(.data$x.pos, stats::na.omit(.data$h.p)),
      label = statistics[[p]],
      size = font_size / (1 / 0.35),
      inherit.aes = FALSE,
      na.rm = TRUE
    )
    
    seg <- ggplot2::geom_segment(
      data = statistics,
      ggplot2::aes(
        x = .data$w.start,
        xend = .data$w.stop,
        y = .data$h.s,
        yend = .data$h.s
      ),
      size = stroke,
      inherit.aes = FALSE,
      na.rm = TRUE
    )
  }
  
  
  suppressWarnings(if ("line_point_stat" %in% geom) {
    geom <- c("line", "line_error", "line_point", "stat")
  })
  
  suppressWarnings(if ("density" %in% geom) {
    scale.x <-
      ggplot2::scale_x_continuous(expand = c(0, 0), limits = x.lim)
    y.lim <- c(0, NA)
  })
  
  # Create ggplot object and plot
  g <- ggplot2::ggplot(data = df,
                       ggplot2::aes(x = get(group.by),
                                    y = .data$value)) +
    ggplot2::labs(
      x = x.lab,
      y = y.lab,
      color = comparison,
      shape = comparison,
      fill = comparison,
      alpha = comparison,
      hjust = 0.5
    ) +
    ggplot2::scale_y_continuous(
      limits = y.lim,
      expand = expand.y,
      labels = labs.y,
      trans = trans.y,
      oob = scales::rescale_none
    ) +
    scale.x +
    ggplot2::scale_shape_manual(values = shape.groups) +
    ggplot2::scale_fill_manual(values = fill.groups) +
    ggplot2::scale_color_manual(values = color.groups) +
    lapply(geom, function(x)
      get(x)) +
    ggplot2::theme(
      line = ggplot2::element_line(colour = "black",
                                   size = stroke),
      text = ggplot2::element_text(size = font_size,
                                   colour = "black"),
      rect = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      legend.position = leg.pos,
      legend.title = ggplot2::element_text(size = font_size,
                                           colour = "black"),
      legend.text = ggplot2::element_text(size = font_size,
                                          colour = "black"),
      axis.line.x = ggplot2::element_line(colour = "black", size = stroke),
      axis.line.y = ggplot2::element_line(colour = "black", size = stroke),
      axis.ticks.x = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(
        size = font_size,
        colour = "black",
        angle = angle,
        vjust = vjust,
        hjust = hjust
      ),
      axis.text = ggplot2::element_text(size = font_size,
                                        colour = "black"),
      plot.margin = ggplot2::margin(5, 0, 5, 0, "mm"),
      legend.margin = ggplot2::margin(0, 0, 0, 0, "mm")
    )
  
  if (stats == FALSE) {
    if (leg.pos %in% c("top", "bottom")) {
      leg <- ggpubr::get_legend(g)
      lwidth <- sum(as.numeric(grid::convertUnit(leg$width, "mm")))
    } else {
      lwidth <- 0
    }
    gt <- egg::set_panel_size(
      g,
      width = ggplot2::unit(plotWidth, "mm"),
      height = ggplot2::unit(plotHeight, "mm")
    )
    gt$layout$clip[gt$layout$name == "panel"] <- "off"
    
    # rect grobs such as those created by geom_bar() have "height" / "width"
    # measurements, while point & text grobs have "y" / "x" measurements,
    # & we look for both
    max.grob.heights <- vapply(gt$grob[[which(
      gt$layout$name == "panel")]]$children,
                               function(x)
                                 ifelse(
                                   !is.null(x$height) & 
                                     "unit" %in% class(x$height),
                                   max(as.numeric(x$height), na.rm = TRUE),
                                   ifelse(!is.null(x$y) & 
                                            "unit" %in% class(x$y),
                                          max(as.numeric(x$y)),
                                          0)
                                 ), numeric(1))
    max.grob.heights <- max(max.grob.heights, na.rm = TRUE)
    
    min.grob.heights <- vapply(gt$grob[[which(
      gt$layout$name == "panel")]]$children,
                               function(x)
                                 ifelse(
                                   !is.null(x$height) & 
                                     "unit" %in% class(x$height),
                                   min(as.numeric(x$height), 
                                       na.rm = TRUE),
                                   ifelse(!is.null(x$y) & 
                                            "unit" %in% class(x$y),
                                          min(as.numeric(x$y)),
                                          0)
                                 ), numeric(1))
    min.grob.heights <- min(min.grob.heights, na.rm = TRUE)
    
    # identify panel row & calculate panel height
    panel.row <- gt$layout[gt$layout$name == "panel", "t"] # = 7
    panel.height <-
      as.numeric(grid::convertUnit(gt$heights[panel.row], "mm"))
    
    # calculate height of all the grobs above the panel
    height.above.panel <- gt$heights[seq_len(panel.row - 1)]
    height.above.panel <- sum(as.numeric(
      grid::convertUnit(height.above.panel, "mm")), na.rm = TRUE)
    
    # check whether the out-of-bound object (if any) exceeds this height,
    # & replace if necessary
    if (max.grob.heights > 1) {
      oob.height.above.panel <- (max.grob.heights - 1) * panel.height
      height.above.panel <-
        max(height.above.panel, oob.height.above.panel,
            na.rm = TRUE)
    }
    
    # as above, calculate the height of all the grobs below the panel
    height.below.panel <-
      gt$heights[(panel.row + 1):length(gt$heights)]
    height.below.panel <- sum(as.numeric(
      grid::convertUnit(height.below.panel, "mm")), na.rm = TRUE)
    
    # as above
    if (min.grob.heights < 0) {
      oob.height.below.panel <- abs(min.grob.heights) * panel.height
      height.below.panel <-
        max(height.below.panel, oob.height.below.panel,
            na.rm = TRUE)
    }
    
    # sum the result
    pheight <-
      height.above.panel + panel.height + height.below.panel
    gt <- gtable::gtable_add_padding(gt,
                                     padding = ggplot2::unit(c(
                                       height.above.panel,
                                       lwidth / 2,
                                       5,
                                       lwidth / 2
                                     ), "mm"))
    return(gt)
  }
}

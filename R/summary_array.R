#' Create the raw summary array for all spikes
#'
#' @description \code{create_simple_summary_array} creates a matrix containing
#'   every 7 time point summarised from the smooth psth.
#' @param x A list of smoothed psth objects for cell/odours combinations.
#'   Defaults to \code{\link{smSpikes}}
#' @param cells A character vector of cell names enabling calculation of
#'   summary_array for a subset of the data.
#' @export
#' @import physplitdata
#' @family summary_array
#' @examples
#' summary_array=create_raw_summary_array()
#' # histogram of baseline firing for all cells / odours
#' hist(summary_array[,,'baseline'])
#' # collapse all data for different odours for the same cell
#' # i.e. average baseline firing rate for each cell
#' baseline_cell=rowMeans(summary_array[,,'baseline'], na.rm=TRUE)
#' hist(baseline_cell, xlab='Firing freq /Hz')
#'
#' # examples of calculating summary for all cells
#' summary_array3=create_raw_summary_array(cells=c("nm20140714c1", "nm20150305c0", "nm20141128c0"))
#'
#' # Plot density distributions by cell group
#' pns=subset(PhySplitDB, Group=='PN' & cell %in% names(smSpikes))$cell
#' physplit=PhySplitDB[match(names(smSpikes), PhySplitDB$cell), ]
#' rownames(physplit)=physplit$cell
#' physplit$baseline=baseline_cell[physplit$cell]
#' library(ggplot2)
#' qplot(baseline,col=Group, data=subset(physplit, Group%in%c("L","O","PN")), geom='density')
create_raw_summary_array<-function(x=physplitdata::smSpikes, cells=NULL) {
  allfreqs_allodours <- create_simple_summary_arrays(x=x, cells=cells)
  num_cells <- length(allfreqs_allodours)
  allodours <- colnames(allfreqs_allodours[[1]])
  num_odours <- length(allodours)
  num_stats <- 7
  stat_names <- c("baseline", "max1", "max2", "max3", "max4", "max5", "max6")
  summary_array <- array(dim=c(num_cells, num_odours, num_stats),
                         dimnames=list(names(allfreqs_allodours), allodours, stat_names))

  summary_array[, , 'baseline'] <- t(sapply(allfreqs_allodours, function(x) colMeans(x[1,,drop=FALSE])))
  colMax=function(x) apply(x, 2, max)
  summary_array[, , 'max1'] <- t(sapply(allfreqs_allodours, function(x) colMax(x[12:19, ])))
  summary_array[, , 'max2'] <- t(sapply(allfreqs_allodours, function(x) colMax(x[16:23, ])))
  summary_array[, , 'max3'] <- t(sapply(allfreqs_allodours, function(x) colMax(x[20:27, ])))
  summary_array[, , 'max4'] <- t(sapply(allfreqs_allodours, function(x) colMax(x[24:31, ])))
  summary_array[, , 'max5'] <- t(sapply(allfreqs_allodours, function(x) colMax(x[28:35, ])))
  summary_array[, , 'max6'] <- t(sapply(allfreqs_allodours, function(x) colMax(x[32:39, ])))
  summary_array
}

#' @rdname create_raw_summary_array
#' @description \code{create_simple_summary_array} creates a list of matrices,
#'   one for each cell, containing every time point in the smoothed PSTH (rows)
#'   x every possible odour (cols).
#' @export
create_simple_summary_arrays=function (x = physplitdata::smSpikes, cells = NULL)
{
  if (!is.null(cells)) {
    if (!all(cells %in% names(x)))
      stop("Some cells are not present in cell list x!")
    x = x[cells]
  }
  allfreqs = lapply(x, function(psthsforcell) sapply(psthsforcell,function(psth) psth$freq))
  allodours = unique(unlist(lapply(x, names)))
  lapply(allfreqs, addnacols, allodours)
}


#' Find the common set of odours for which all cells have trials
#'
#' @param x Any identifier for the cells
#' @return A character vector of odour names
#' @details Uses \code{\link{create_raw_summary_array}} under the hood
#' @export
#' @examples
#' common_odours_for_cells(c("130823c0", "130809c0", "140211c0"))
common_odours_for_cells <- function(x) {
  x=anyid2longid(x)
  sa=create_raw_summary_array(cells=x)

  # pick any time point and look for NA
  baseline_spikes=sa[,,1]
  # sum spikes for each odour - the result will be NA if any spike count is NA
  sums=colSums(baseline_spikes)
  names(sums)[!is.na(sums)]
}

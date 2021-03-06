% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/spikes.R
\name{poissonTestOdoursSF}
\alias{poissonTestOdoursSF}
\title{Carry out Poisson test on absolute number of spikes in odour response}
\usage{
poissonTestOdoursSF(x, odours = colnames(x), maxtrials = NA,
  test_each_odour_trial = FALSE, ...)
}
\arguments{
\item{x}{An m x n odour response matrix for m trials of n odours}

\item{odours}{Names of odours (defaults to \code{colnames(x)})}

\item{maxtrials}{Maximum number of trials to consider (default => all)}

\item{test_each_odour_trial}{Whether to test each odour trial individually
against all blank trials.}

\item{...}{Additional parameters passed to \code{poisson.test}}
}
\value{
p values from the Poisson test
}
\description{
Carry out Poisson test on absolute number of spikes in odour response
}
\details{
This function compares each odour trial with a matching control
  (i.e. blank) response. It is assumed that each odour column is matched to
  the blank column that most recently preceded it.

  When \code{test_each_odour_trial} each single odour trial is compared with
  all of the blank trials (making an approoriate adjustment to the time base
  for the event counts, see Note in \code{\link{poisson.test}} docs).
}
\examples{
# calculate summary response for cell 100 for window of 700-1700 ms
spikeresp=OdourResponseFromSpikes(Spikes[[100]][[1]], responseWindow=c(700,1700))
poissonTestOdoursSF(spikeresp, alternative="greater")

\dontrun{
spikerespall=sapply(Spikes, function(x) OdourResponseFromSpikes(x[[1]],
  responseWindow=c(700,1700)), simplify = F)
# significant response (either up or down)
spikes.pval=sapply(spikerespall, poissonTestOdoursSF, simplify = F)
}
}
\seealso{
\code{\link{poisson.test}},
  \code{\link[gphys]{OdourResponseFromSpikes}}
}

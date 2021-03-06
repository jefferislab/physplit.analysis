% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/finite_pop_sampling.R
\name{required.sample.size}
\alias{required.sample.size}
\title{Estimate sample size to find population proportion with given tolerance}
\usage{
required.sample.size(epsilon, pest = 0.5, alpha = 0.05, N = Inf)
}
\arguments{
\item{epsilon}{Tolerange of proportion estimate (see details)}

\item{pest}{The estimated proportion (leave at 0.5 if unknown)}

\item{alpha}{The confidence interval is (1-alpha)*100\%}

\item{N}{Population size (default implies infinite population)}
}
\value{
numeric
}
\description{
Estimate sample size to find population proportion with given tolerance
}
\details{
Estimated proportion should have (1-alpha)*100\% confidence of being
  within p +/- epsilon of the true proportions
}
\examples{
required.sample.size(0.04, alpha=0.1)
required.sample.size(0.04, alpha=0.1, N=40)
# epsilon here is equivalent to +/- 4
required.sample.size(10/40, alpha=0.1, N=40)
}
\references{
See https://onlinecourses.science.psu.edu/stat414/node/264
}
\seealso{
Other population-sampling: \code{\link{prop.ci}},
  \code{\link{sample_finite_population}},
  \code{\link{truepos_given_sample}}
}
\concept{population-sampling}

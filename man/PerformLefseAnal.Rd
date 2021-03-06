% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/general_anal.R
\name{PerformLefseAnal}
\alias{PerformLefseAnal}
\title{Main function to perform LEfSe analysis}
\usage{
PerformLefseAnal(
  mbSetObj,
  p.lvl,
  pvalOpt = "fdr",
  lda.lvl,
  variable,
  isfunc,
  shotgunid,
  taxrank
)
}
\arguments{
\item{mbSetObj}{Input the name of the mbSetObj.}

\item{p.lvl}{Numeric, input the adjusted p-value cutoff.}

\item{lda.lvl}{Numeric, input the Log LDA score cutoff.}

\item{variable}{Character, input the name of the experimental factor.}

\item{isfunc}{Logical, default set to "F".}

\item{shotgunid}{Only valid for SDP module, set to "NA".}

\item{taxrank}{Character, input the taxonomic level to perform
univariate analysis.}

\item{datatype}{Character, input whether the data is marker gene
data ("16S") or metagenomic data ("metageno").}
}
\description{
This functions performs LEfSe analysis on the microbiome data.
}
\author{
Jeff Xia \email{jeff.xia@mcgill.ca}
McGill University, Canada
License: GNU GPL (>= 2)
}

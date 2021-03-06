% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/general_anal.R
\name{PerformRNAseqDE}
\alias{PerformRNAseqDE}
\title{Main function to perform RNAseq analysis}
\usage{
PerformRNAseqDE(mbSetObj, opts, p.lvl, variable, shotgunid, taxrank)
}
\arguments{
\item{mbSetObj}{Input the name of the mbSetObj.}

\item{opts}{Character, input "EdgeR" to use the edgeR algorithm and
"DESeq2" to use the DESeq2 algorithm.}

\item{p.lvl}{Numeric, input the adjusted p-value cutoff.}

\item{variable}{Character, input the experimental factor.}

\item{shotgunid}{Only valid for SDP module, set to "NA".}

\item{taxrank}{Character, input the taxonomic level
to use for RNAseq analysis.}

\item{datatype}{Character, input "16S" if the data is marker gene
data and "metageno" if it is metagenomic data.}
}
\description{
This functions performs RNAseq analysis on the microbiome data.
}
\author{
Jeff Xia \email{jeff.xia@mcgill.ca}
McGill University, Canada
License: GNU GPL (>= 2)
}

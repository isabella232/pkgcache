% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/installed.R
\name{parse_installed}
\alias{parse_installed}
\title{List metadata of installed packages}
\usage{
parse_installed(library = .libPaths(), priority = NULL, lowercase = FALSE)
}
\arguments{
\item{library}{Character vector of library paths.}

\item{priority}{If not \code{NULL} then it may be a \code{"base"} \code{"recommended"}
\code{NA} or a vector of these to select \emph{base} packages, \emph{recommended}
packages or \emph{other} packages. (These are the official, CRAN supported
package priorities, but you may introduce others in non-CRAN packages.)}

\item{lowercase}{Whether to convert keys in \code{DESCRIPTION} to lowercase.}
}
\description{
This function is similar to \code{\link[utils:installed.packages]{utils::installed.packages()}}.
See the differences below.
}
\details{
Differences with \code{\link[utils:installed.packages]{utils::installed.packages()}}:
\itemize{
\item \code{parse_installed()} cannot subset the extracted fields. (But you can
subset the result.)
\item \code{parse_installed()} does not cache the results.
\item \code{parse_installed()} handles errors better. See Section 'Errors' below.
#' * \code{parse_installed()} uses the \code{DESCRIPTION} files in the installed packages
instead of the \code{Meta/package.rds} files. This should not matter,
but because of a bug \code{Meta/package.rds} might contain the wrong
\code{Archs} field on multi-arch platforms.
\item \code{parse_installed()} reads \emph{all} fields from the \code{DESCRIPTION} files.
\code{\link[utils:installed.packages]{utils::installed.packages()}} only reads
\item \code{parse_installed()} is considerably faster.
}
\subsection{Errors}{

pkgcache silently ignores files and directories inside the library
directory.

The result also omits broken package installations. These include
\itemize{
\item packages with invalid \code{DESCRIPTION} files, and
\item packages the current user have no access to.
}

These errors are reported via a condition with class
\code{pkgcache_broken_install}. The condition has an \code{errors} entry, which
is a tibble with columns
\itemize{
\item \code{file}: path to the \code{DESCRIPTION} file of the broken package,
\item \code{error}: error message for this particular failure.
}

If you intend to handle broken package installation, you need to catch
this condition with \code{withCallingHandlers()}.
}
}

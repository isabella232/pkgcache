
#' R platforms
#'
#' @details
#' `current_r_platform()` detects the platform of the current R version.
#'
#' By default pkgcache works with source packages and binary packages for
#' the current platform. You can change this, by providing different
#' platform names as arguments to
#' [`cranlike_metadata_cache$new()`][cranlike_metadata_cache],
#' [repo_status()], etc.
#'
#' These functions accept the following platform names:
#' * `"source"` for source packages,
#' * `"macos"` for macOS binaries that are appropriate for the R versions
#'   pkgcache is working with (defaulting to the version of the current
#'   session), as defined by CRAN binaries. E.g. on R 3.5.0 macOS binaries
#'   are built for macOS El Capitan.
#' * `"windows"` for Windows binaries for the default CRAN architecture.
#'   This is currently Windows Vista for all supported R versions, but it
#'   might change in the future. The actual binary packages in the
#'   repository might support both 32 bit and 64 builds, or only one of
#'   them. In practice 32-bit only packages are very rare. CRAN builds
#'   before and including R 4.1 have both architectures, from R 4.2 they
#'   are 64 bit only. `"windows"` is an alias to `i386+x86_64-w64-mingw32`
#'   currently.
#' * A platform string like `R.version$platform`, but on Linux the name
#'   and version of the distribution are also included. Examples:
#'   - `x86_64-apple-darwin17.0`: macOS High Sierra.
#'   - `aarch64-apple-darwin20`: macOS Big Sur on arm64.
#'   - `x86_64-w64-mingw32`: 64 bit Windows.
#'   - `i386-w64-mingw32`: 32 bit Windows.
#'   - `i386+x86_64-w64-mingw32`: 64 bit + 32 bit Windows.
#'   - `i386-pc-solaris2.10`: 32 bit Solaris. (Some broken 64 Solaris
#'     builds might have the same platform string, unfortunately.)
#'   - `x86_64-pc-linux-gnu-debian-10`: Debian Linux 10 on x86_64.
#'   - `x86_64-pc-linux-musl-alpine-3.14.1`: Alpine Linux.
#'   - `x86_64-pc-linux-gnu-unknown`: Unknown Linux Distribution on x86_64.
#'   - `s390x-ibm-linux-gnu-ubuntu-20.04`: Ubuntu Linux 20.04 on S390x.
#'   - `amd64-portbld-freebsd12.1`: FreeBSD 12.1 on x86_64.
#'
#' @return `current_r_platform()` returns a character scalar.
#' @export
#' @examples
#' current_r_platform()

current_r_platform <- function() {
  raw <- get_platform()
  platform <- parse_platform(raw)
  if (platform$os == "linux" || substr(platform$os, 1, 6) == "linux-") {
    current_r_platform_linux(raw)
  } else {
    raw
  }
}

#' @details
#' `default_platfoms()` returns the default platforms for the current R
#' session. These typically consist of the detected platform of the current
#' R session, and `"source"`, for source packages.
#'
#' @rdname current_r_platform
#' @return `default_platforms()` returns a character vector of the
#' default platforms.
#' @export
#' @examples
#' default_platforms()

default_platforms <- function() {
  unique(c(current_r_platform(), "source"))
}

parse_platform <- function(x) {
  pcs <- strsplit(x, "-", fixed = TRUE)
  data.frame(
    stringsAsFactors = FALSE,
    cpu = vcapply(pcs, "[", 1),
    vendor = vcapply(pcs, "[", 2),
    os = vcapply(pcs, function(y) {
      if (length(y) < 3) NA_character_ else paste(y[-(1:2)], collapse = "-")
    })
  )
}

get_cran_extension <- function(platform) {
  if (platform == "source") {
    return(".tar.gz")
  } else if (platform %in% c("windows", "i386+x86_64-mingw32",
                             "x86_64-w64-mingw32", "i386-w64-mingw32")) {
    return(".zip")
  } else if (platform == "macos") {
    return(".tgz")
  }

  dtl <- parse_platform(platform)
  if (!is.na(dtl$os) && grepl("^darwin", dtl$os)) {
    return(".tgz")
  } else {
    paste0("_R_", platform, ".tar.gz")
  }
}

get_all_package_dirs <- function(platforms, rversions) {
  minors <- unique(get_minor_r_version(rversions))
  res <- lapply(platforms, get_package_dirs_for_platform, minors)

  mat <- do.call(rbind, res)
  colnames(mat) <- c("platform", "rversion", "contriburl")
  res <- as_tibble(mat)
  res <- unique(res)

  res
}

get_package_dirs_for_platform <- function(pl, minors) {
  if (any(package_version(minors) < "3.2")) {
    stop("pkgcache does not support packages for R versions before R 3.2")
  }

  ## Should we add extra arch repos?
  xtr <- getOption(
    "pkg.extra_arch_repos",
    Sys.getenv("PKG_EXTRA_ARCH_REPOS", FALSE)
  )

  if (pl == "source") {
    return(cbind("source", "*", "src/contrib"))

  }

  if (pl %in% c("x86_64-w64-mingw32", "i386-w64-mingw32",
                "i386+x86_64-w64-mingw32")) {
    return(cbind(
      pl,
      minors,
      paste0("bin/windows/contrib/", minors)
    ))

  }

  if (pl == "windows") {
    return(cbind(
      "i386+x86_64-w64-mingw32",
      minors,
      paste0("bin/windows/contrib/", minors)
    ))
  }

  if (pl == "macos") {
    res1 <- lapply(minors, function(v) {
      rpl <- get_cran_macos_platform(v)
      if (nrow(rpl)) {
        cbind(rpl$platform, v, paste0(
          "bin/macosx/",
          ifelse(nchar(rpl$subdir), paste0(rpl$subdir, "/"), ""),
          "contrib/",
          v
        ))
      }
    })
    return(do.call(rbind, res1))

  }

  ## Which R versions match this platform on CRAN?
  mcp <- macos_cran_platforms
  cranmrv <- mcp[mcp$platform == pl & mcp$rversion %in% minors,]

  rbind(
    if (nrow(cranmrv)) {
      dirs <- paste0(
        "bin/macosx/",
        ifelse(nchar(cranmrv$subdir), paste0(cranmrv$subdir, "/"), ""),
        "contrib/",
        cranmrv$rversion
      )
      cbind(pl, cranmrv$rversion, dirs)
    },
    if (xtr) cbind(pl, minors, paste0("bin/", pl, "/", minors))
  )
}

macos_cran_platforms <- read.table(
  header = TRUE,
  stringsAsFactors = FALSE,
  textConnection(
     "rversion platform subdir
     3.1.3 x86_64-apple-darwin10.8.0 mavericks
     3.2.0 x86_64-apple-darwin13.4.0 mavericks
     3.2.1 x86_64-apple-darwin13.4.0 mavericks
     3.2.2 x86_64-apple-darwin13.4.0 mavericks
     3.2.3 x86_64-apple-darwin13.4.0 mavericks
     3.2.4 x86_64-apple-darwin13.4.0 mavericks
     3.2.5 x86_64-apple-darwin13.4.0 mavericks
     3.3.0 x86_64-apple-darwin13.4.0 mavericks
     3.3.1 x86_64-apple-darwin13.4.0 mavericks
     3.3.2 x86_64-apple-darwin13.4.0 mavericks
     3.3.3 x86_64-apple-darwin13.4.0 mavericks
     3.4.0 x86_64-apple-darwin15.6.0 el-capitan
     3.4.1 x86_64-apple-darwin15.6.0 el-capitan
     3.4.2 x86_64-apple-darwin15.6.0 el-capitan
     3.4.3 x86_64-apple-darwin15.6.0 el-capitan
     3.4.4 x86_64-apple-darwin15.6.0 el-capitan
     3.5.0 x86_64-apple-darwin15.6.0 el-capitan
     3.5.1 x86_64-apple-darwin15.6.0 el-capitan
     3.5.2 x86_64-apple-darwin15.6.0 el-capitan
     3.5.3 x86_64-apple-darwin15.6.0 el-capitan
     3.6.0 x86_64-apple-darwin15.6.0 el-capitan
     3.6.1 x86_64-apple-darwin15.6.0 el-capitan
     3.6.2 x86_64-apple-darwin15.6.0 el-capitan
     3.6.3 x86_64-apple-darwin15.6.0 el-capitan
     4.0.0 x86_64-apple-darwin17.0   ''
     4.0.1 x86_64-apple-darwin17.0   ''
     4.0.2 x86_64-apple-darwin17.0   ''
     4.0.3 x86_64-apple-darwin17.0   ''
     4.0.4 x86_64-apple-darwin17.0   ''
     4.0.5 x86_64-apple-darwin17.0   ''
     4.1.0 x86_64-apple-darwin17.0   ''
     4.1.0 aarch64-apple-darwin20    big-sur-arm64
     4.1.1 x86_64-apple-darwin17.0   ''
     4.1.1 aarch64-apple-darwin20    big-sur-arm64
     4.2.0 x86_64-apple-darwin17.0   ''
     4.2.0 aarch64-apple-darwin20    big-sur-arm64
"))

# For now we only use the minor version number, because the CRAN OS version
# does not change for a patch version.

get_minor_r_version <- function(x) {
  x <- package_version(x)
  vapply(unclass(x), function(x) paste(x[1:2], collapse = "."), character(1))
}

macos_cran_platforms$rversion <- get_minor_r_version(
  macos_cran_platforms$rversion
)
macos_cran_platforms <- unique(macos_cran_platforms)

get_cran_macos_platform <- function(v) {
  macos_cran_platforms[macos_cran_platforms$rversion %in% v,,drop = FALSE]
}

#' Query the default CRAN repository for this session
#'
#' If `options("repos")` (see [options()]) contains an entry called
#' `"CRAN"`, then that is returned. If it is a list, it is converted
#' to a character vector.
#'
#' Otherwise the RStudio CRAN mirror is used.
#'
#' @return A named character vector of length one, where the
#'   name is `"CRAN"`.
#'
#' @export
#' @examples
#' default_cran_mirror()

default_cran_mirror <- function() {
  mirror <- getOption("repos")["CRAN"]
  if (is.null(mirror) || is.na(mirror) || mirror == "@CRAN@") {
    c(CRAN = "https://cran.rstudio.com")
  } else {
    unlist(mirror)
  }
}

#' Query Bioconductor version information
#'
#' Various helper functions to deal with Bioconductor repositories.
#' See <https://www.bioconductor.org/> for more information on
#' Bioconductor.
#'
#' `bioc_version()` queries the matching Bioconductor version for
#' an R version, defaulting to the current R version
#'
#' @param r_version The R version number to match.
#' @param forget Use `TRUE` to avoid caching the Bioconductor mapping.
#' @return `bioc_version()` returns a [package_version] object.
#'
#' @export
#' @examplesIf pkgcache:::run_examples()
#' bioc_version()
#' bioc_version("4.0")
#' bioc_version("4.1")

bioc_version <- function(r_version = getRversion(), forget = FALSE) {
  bioconductor$get_bioc_version(r_version, forget)
}

#' @details
#' `bioc_version_map()` returns the current mapping between R versions
#' and Bioconductor versions.
#'
#' @return `bioc_version_map()` returns a tibble with columns:
#' * `bioc_version`: [package_version] object, Bioconductor versions.
#' * `r_version`: [package_version] object, the matching R versions.
#' * `bioc_status`: factor, with levels: `out-of-date`, `release`,
#'   `devel`, `future`.
#'
#' @rdname bioc_version
#'
#' @export
#' @examplesIf pkgcache:::run_examples()
#' bioc_version_map()

bioc_version_map <- function(forget = FALSE) {
  tibble::as_tibble(bioconductor$get_version_map(forget))
}

#' @details
#' `bioc_devel_version()` returns the version number of the current
#' Bioconductor devel version.
#'
#' @return `bioc_devel_version()` returns a [package_version] object.
#' @rdname bioc_version
#'
#' @export
#' @examplesIf pkgcache:::run_examples()
#' bioc_devel_version()

bioc_devel_version <- function(forget = FALSE) {
  bioconductor$get_devel_version(forget)
}

#' @details
#' `bioc_release_version()` returns the version number of the current
#' Bioconductor release.
#'
#' @return `bioc_release_version()` returns a [package_version] object.
#' @rdname bioc_version
#'
#' @export
#' @examplesIf pkgcache:::run_examples()
#' bioc_release_version()

bioc_release_version <- function(forget = FALSE) {
  bioconductor$get_release_version(forget)
}

#' @details
#' `bioc_repos()` returns the Bioconductor repository URLs.
#'
#' See the `BioC_mirror` option and the `R_BIOC_MIRROR` and
#' `R_BIOC_VERSION` environment variables in the [pkgcache] manual page.
#' They can be used to customize the desired Bioconductor version.
#'
#' @param bioc_version Bioconductor version string or `package_version`
#'   object, or the string `"auto"` to use the one matching the current R
#'   version.
#'
#' @return `bioc_repos()` returns a named character vector.
#' @rdname bioc_version
#' @export
#' @examplesIf pkgcache:::run_examples()
#' bioc_repos()

bioc_repos <- function(bioc_version = "auto", forget = FALSE) {
  bioconductor$get_repos(bioc_version, forget)
}

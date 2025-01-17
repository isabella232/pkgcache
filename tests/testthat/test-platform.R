
test_that("current_r_platform", {
  mockery::stub(current_r_platform, "get_platform", "x86_64-apple-darwin17.0")
  expect_equal(current_r_platform(), "x86_64-apple-darwin17.0")
})

test_that("default_platforms", {
  mockery::stub(default_platforms, "current_r_platform", "macos")
  expect_equal(default_platforms(), c("macos", "source"))

  mockery::stub(default_platforms, "current_r_platform", "windows")
  expect_equal(default_platforms(), c("windows", "source"))

  mockery::stub(default_platforms, "current_r_platform", "source")
  expect_equal(default_platforms(), "source")
})

test_that("get_all_package_dirs", {
  res <- get_all_package_dirs(
    unique(c(current_r_platform(), "source")), getRversion())

  expect_s3_class(res, "tbl_df")
  expect_equal(
    colnames(res),
    c("platform", "rversion", "contriburl"))
  expect_gte(nrow(res), 1)
  expect_true(all(sapply(res, is.character)))
  expect_error(get_all_package_dirs("source", "3.1"), "R versions before")
  expect_error(
    get_package_dirs_for_platform("source", "3.1"),
    "R versions before"
  )

  res2 <- get_all_package_dirs("i386+x86_64-w64-mingw32", "4.0")
  res3 <- get_all_package_dirs("windows", "4.0")
  expect_equal(res2, res3)
})

test_that("get_cran_extension", {
  expect_equal(get_cran_extension("source"), ".tar.gz")
  expect_equal(get_cran_extension("windows"), ".zip")
  expect_equal(get_cran_extension("macos"), ".tgz")
  expect_equal(get_cran_extension("x86_64-apple-darwin17.0"), ".tgz")
  expect_equal(
    get_cran_extension("x86_64-pc-linux-musl"),
    "_R_x86_64-pc-linux-musl.tar.gz"
  )
  expect_equal(
    get_cran_extension("foobar"),
    "_R_foobar.tar.gz"
  )
})

test_that("get_all_package_dirs", {
  d <- get_all_package_dirs(c("macos", "source"), "4.0.0")
  expect_true("x86_64-apple-darwin17.0" %in% d$platform)
  expect_true("source" %in% d$platform)

  expect_error(
    get_all_package_dirs("windows", "2.15.0"),
    "does not support packages for R versions before"
  )
  expect_error(
    get_all_package_dirs("macos", "3.1.3"),
    "does not support packages for R versions before"
  )

  d <- get_all_package_dirs("macos", "3.2.0")
  expect_equal(
    sort(d$contriburl),
    "bin/macosx/mavericks/contrib/3.2"
  )
  d <- get_all_package_dirs("macos", "3.3.0")
  expect_match(d$contriburl, "bin/macosx/mavericks/contrib/3.3")
  d <- get_all_package_dirs("macos", "3.6.3")
  expect_match(d$contriburl, "bin/macosx/el-capitan/contrib/3.6")

  d <- get_all_package_dirs("macos", "4.0.0")
  expect_match(d$contriburl, "bin/macosx/contrib/4.0")
})

test_that("current_r_platform_linux", {
  testthat::local_edition(3)
  dists <- dir(test_path("fixtures", "linux"))
  vers <- lapply(dists, function(d) dir(test_path("fixtures", "linux", d)))

  mapply(dists, vers, FUN = function(d, v) {
    etc <- test_path("fixtures", "linux", d, v)
    expect_snapshot(vcapply(etc, current_r_platform_linux, raw = "foo"))
  })
})

test_that("linux", {
  mockery::stub(current_r_platform, "get_platform", "x86_64-pc-linux-gnu")
  mockery::stub(current_r_platform, "current_r_platform_linux", "boo")
  expect_equal(current_r_platform(), "boo")
})

test_that("unknown linux", {
  expect_equal(current_r_platform_linux("foo", tempfile()), "foo-unknown")
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp)
  file.create(file.path(tmp, "os-release"))
  expect_equal(current_r_platform_linux("foo", tmp), "foo-unknown")
})

test_that("remove_quotes", {
  expect_equal(remove_quotes("x"), "x")
  expect_equal(remove_quotes("'xyz'"), "xyz")
  expect_equal(remove_quotes('"xyz"'), "xyz")
})

test_that("parse_redhat_release", {
  expect_equal(parse_redhat_release(""), "unknown")
  expect_equal(parse_redhat_release("Something"), "something")
})

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

#' Read a CSV or other delimited file with Arrow
#'
#' These functions uses the Arrow C++ CSV reader to read into a `tibble`.
#' Arrow C++ options have been mapped to argument names that follow those of
#' `readr::read_delim()`, and `col_select` was inspired by `vroom::vroom()`.
#'
#' `read_csv_arrow()` and `read_tsv_arrow()` are wrappers around
#' `read_delim_arrow()` that specify a delimiter. `read_csv2_arrow()` uses `;` for
#' the delimiter and `,` for the decimal point.
#'
#' Note that not all `readr` options are currently implemented here. Please file
#' an issue if you encounter one that `arrow` should support.
#'
#' If you need to control Arrow-specific reader parameters that don't have an
#' equivalent in `readr::read_csv()`, you can either provide them in the
#' `parse_options`, `convert_options`, or `read_options` arguments, or you can
#' use [CsvTableReader] directly for lower-level access.
#'
#' @section Specifying column types and names:
#'
#' By default, the CSV reader will infer the column names and data types from the file, but there
#' are a few ways you can specify them directly.
#'
#' One way is to provide an Arrow [Schema] in the `schema` argument,
#' which is an ordered map of column name to type.
#' When provided, it satisfies both the `col_names` and `col_types` arguments.
#' This is good if you know all of this information up front.
#'
#' You can also pass a `Schema` to the `col_types` argument. If you do this,
#' column names will still be inferred from the file unless you also specify
#' `col_names`. In either case, the column names in the `Schema` must match the
#' data's column names, whether they are explicitly provided or inferred. That
#' said, this `Schema` does not have to reference all columns: those omitted
#' will have their types inferred.
#'
#' Alternatively, you can declare column types by providing the compact string representation
#' that `readr` uses to the `col_types` argument. This means you provide a
#' single string, one character per column, where the characters map to Arrow
#' types analogously to the `readr` type mapping:
#'
#' * "c": [utf8()]
#' * "i": [int32()]
#' * "n": [float64()]
#' * "d": [float64()]
#' * "l": [bool()]
#' * "f": [dictionary()]
#' * "D": [date32()]
#' * "T": [`timestamp(unit = "ns")`][timestamp()]
#' * "t": [time32()] (The `unit` arg is set to the default value `"ms"`)
#' * "_": [null()]
#' * "-": [null()]
#' * "?": infer the type from the data
#'
#' If you use the compact string representation for `col_types`, you must also
#' specify `col_names`.
#'
#' Regardless of how types are specified, all columns with a `null()` type will
#' be dropped.
#'
#' Note that if you are specifying column names, whether by `schema` or
#' `col_names`, and the CSV file has a header row that would otherwise be used
#' to identify column names, you'll need to add `skip = 1` to skip that row.
#'
#' @param file A character file name or URI, connection, literal data (either a
#' single string or a [raw] vector), an Arrow input stream, or a `FileSystem`
#' with path (`SubTreeFileSystem`).
#'
#' If a file name, a memory-mapped Arrow [InputStream] will be opened and
#' closed when finished; compression will be detected from the file extension
#' and handled automatically. If an input stream is provided, it will be left
#' open.
#'
#' To be recognised as literal data, the input must be wrapped with `I()`.
#' @param delim Single character used to separate fields within a record.
#' @param quote Single character used to quote strings.
#' @param escape_double Does the file escape quotes by doubling them?
#' i.e. If this option is `TRUE`, the value `""""` represents
#' a single quote, `\"`.
#' @param escape_backslash Does the file use backslashes to escape special
#' characters? This is more general than `escape_double` as backslashes
#' can be used to escape the delimiter character, the quote character, or
#' to add special characters like `\\n`.
#' @param schema [Schema] that describes the table. If provided, it will be
#' used to satisfy both `col_names` and `col_types`.
#' @param col_names If `TRUE`, the first row of the input will be used as the
#' column names and will not be included in the data frame. If `FALSE`, column
#' names will be generated by Arrow, starting with "f0", "f1", ..., "fN".
#' Alternatively, you can specify a character vector of column names.
#' @param col_types A compact string representation of the column types,
#' an Arrow [Schema], or `NULL` (the default) to infer types from the data.
#' @param col_select A character vector of column names to keep, as in the
#' "select" argument to `data.table::fread()`, or a
#' [tidy selection specification][tidyselect::eval_select()]
#' of columns, as used in `dplyr::select()`.
#' @param na A character vector of strings to interpret as missing values.
#' @param quoted_na Should missing values inside quotes be treated as missing
#' values (the default) or strings. (Note that this is different from the
#' the Arrow C++ default for the corresponding convert option,
#' `strings_can_be_null`.)
#' @param skip_empty_rows Should blank rows be ignored altogether? If
#' `TRUE`, blank rows will not be represented at all. If `FALSE`, they will be
#' filled with missings.
#' @param skip Number of lines to skip before reading data.
#' @param timestamp_parsers User-defined timestamp parsers. If more than one
#' parser is specified, the CSV conversion logic will try parsing values
#' starting from the beginning of this vector. Possible values are:
#'  - `NULL`: the default, which uses the ISO-8601 parser
#'  - a character vector of [strptime][base::strptime()] parse strings
#'  - a list of [TimestampParser] objects
#' @param parse_options see [CSV parsing options][csv_parse_options()].
#' If given, this overrides any
#' parsing options provided in other arguments (e.g. `delim`, `quote`, etc.).
#' @param convert_options see [CSV conversion options][csv_convert_options()]
#' @param read_options see [CSV reading options][csv_read_options()]
#' @param as_data_frame Should the function return a `tibble` (default) or
#' an Arrow [Table]?
#' @param decimal_point Character to use for decimal point in floating point numbers.
#'
#' @return A `tibble`, or a Table if `as_data_frame = FALSE`.
#' @export
#' @examples
#' tf <- tempfile()
#' on.exit(unlink(tf))
#' write.csv(mtcars, file = tf)
#' df <- read_csv_arrow(tf)
#' dim(df)
#' # Can select columns
#' df <- read_csv_arrow(tf, col_select = starts_with("d"))
#'
#' # Specifying column types and names
#' write.csv(data.frame(x = c(1, 3), y = c(2, 4)), file = tf, row.names = FALSE)
#' read_csv_arrow(tf, schema = schema(x = int32(), y = utf8()), skip = 1)
#' read_csv_arrow(tf, col_types = schema(y = utf8()))
#' read_csv_arrow(tf, col_types = "ic", col_names = c("x", "y"), skip = 1)
#'
#' # Note that if a timestamp column contains time zones,
#' # the string "T" `col_types` specification won't work.
#' # To parse timestamps with time zones, provide a [Schema] to `col_types`
#' # and specify the time zone in the type object:
#' tf <- tempfile()
#' write.csv(data.frame(x = "1970-01-01T12:00:00+12:00"), file = tf, row.names = FALSE)
#' read_csv_arrow(
#'   tf,
#'   col_types = schema(x = timestamp(unit = "us", timezone = "UTC"))
#' )
#'
#' # Read directly from strings with `I()`
#' read_csv_arrow(I("x,y\n1,2\n3,4"))
#' read_delim_arrow(I(c("x y", "1 2", "3 4")), delim = " ")
read_delim_arrow <- function(file,
                             delim = ",",
                             quote = '"',
                             escape_double = TRUE,
                             escape_backslash = FALSE,
                             schema = NULL,
                             col_names = TRUE,
                             col_types = NULL,
                             col_select = NULL,
                             na = c("", "NA"),
                             quoted_na = TRUE,
                             skip_empty_rows = TRUE,
                             skip = 0L,
                             parse_options = NULL,
                             convert_options = NULL,
                             read_options = NULL,
                             as_data_frame = TRUE,
                             timestamp_parsers = NULL,
                             decimal_point = ".") {
  if (inherits(schema, "Schema")) {
    col_names <- names(schema)
    col_types <- schema
  }
  if (is.null(parse_options)) {
    parse_options <- readr_to_csv_parse_options(
      delim,
      quote,
      escape_double,
      escape_backslash,
      skip_empty_rows
    )
  }
  if (is.null(read_options)) {
    read_options <- readr_to_csv_read_options(skip, col_names)
  }
  if (is.null(convert_options)) {
    convert_options <- readr_to_csv_convert_options(
      na = na,
      quoted_na = quoted_na,
      decimal_point = decimal_point,
      col_types = col_types,
      col_names = read_options$column_names,
      timestamp_parsers = timestamp_parsers
    )
  }

  if (inherits(file, "AsIs")) {
    if (is.raw(file)) {
      # If a raw vector is wrapped by `I()`, we need to unclass the `AsIs` class to read the raw vector.
      file <- unclass(file)
    } else {
      file <- charToRaw(paste(file, collapse = "\n"))
    }
  }

  if (!inherits(file, "InputStream")) {
    compression <- detect_compression(file)
    file <- make_readable_file(file, random_access = FALSE)
    if (compression != "uncompressed") {
      # TODO: accept compression and compression_level as args
      file <- CompressedInputStream$create(file, compression)
    }
    on.exit(file$close())
  }

  reader <- CsvTableReader$create(
    file,
    read_options = read_options,
    parse_options = parse_options,
    convert_options = convert_options
  )

  tryCatch(
    tab <- reader$Read(),
    # n = 4 because we want the error to show up as being from read_delim_arrow()
    # and not augment_io_error_msg()
    error = function(e, call = caller_env(n = 4)) {
      augment_io_error_msg(e, call, schema = schema)
    }
  )

  # TODO: move this into convert_options using include_columns
  col_select <- enquo(col_select)
  if (!quo_is_null(col_select)) {
    sim_df <- as.data.frame(tab$schema)
    tab <- tab[eval_select(col_select, sim_df)]
  }

  if (isTRUE(as_data_frame)) {
    tab <- collect.ArrowTabular(tab)
  }

  tab
}

#' @rdname read_delim_arrow
#' @export
read_csv_arrow <- function(file,
                           quote = '"',
                           escape_double = TRUE,
                           escape_backslash = FALSE,
                           schema = NULL,
                           col_names = TRUE,
                           col_types = NULL,
                           col_select = NULL,
                           na = c("", "NA"),
                           quoted_na = TRUE,
                           skip_empty_rows = TRUE,
                           skip = 0L,
                           parse_options = NULL,
                           convert_options = NULL,
                           read_options = NULL,
                           as_data_frame = TRUE,
                           timestamp_parsers = NULL) {
  mc <- match.call()
  mc$delim <- ","
  mc[[1]] <- get("read_delim_arrow", envir = asNamespace("arrow"))
  eval.parent(mc)
}

#' @rdname read_delim_arrow
#' @export
read_csv2_arrow <- function(file,
                            quote = '"',
                            escape_double = TRUE,
                            escape_backslash = FALSE,
                            schema = NULL,
                            col_names = TRUE,
                            col_types = NULL,
                            col_select = NULL,
                            na = c("", "NA"),
                            quoted_na = TRUE,
                            skip_empty_rows = TRUE,
                            skip = 0L,
                            parse_options = NULL,
                            convert_options = NULL,
                            read_options = NULL,
                            as_data_frame = TRUE,
                            timestamp_parsers = NULL) {
  mc <- match.call()
  mc$delim <- ";"
  mc$decimal_point <- ","
  mc[[1]] <- get("read_delim_arrow", envir = asNamespace("arrow"))
  eval.parent(mc)
}

#' @rdname read_delim_arrow
#' @export
read_tsv_arrow <- function(file,
                           quote = '"',
                           escape_double = TRUE,
                           escape_backslash = FALSE,
                           schema = NULL,
                           col_names = TRUE,
                           col_types = NULL,
                           col_select = NULL,
                           na = c("", "NA"),
                           quoted_na = TRUE,
                           skip_empty_rows = TRUE,
                           skip = 0L,
                           parse_options = NULL,
                           convert_options = NULL,
                           read_options = NULL,
                           as_data_frame = TRUE,
                           timestamp_parsers = NULL) {
  mc <- match.call()
  mc$delim <- "\t"
  mc[[1]] <- get("read_delim_arrow", envir = asNamespace("arrow"))
  eval.parent(mc)
}

#' @title Arrow CSV and JSON table reader classes
#' @rdname CsvTableReader
#' @name CsvTableReader
#' @docType class
#' @usage NULL
#' @format NULL
#' @description `CsvTableReader` and `JsonTableReader` wrap the Arrow C++ CSV
#' and JSON table readers. See their usage in [read_csv_arrow()] and
#' [read_json_arrow()], respectively.
#'
#' @section Factory:
#'
#' The `CsvTableReader$create()` and `JsonTableReader$create()` factory methods
#' take the following arguments:
#'
#' - `file` An Arrow [InputStream]
#' - `convert_options` (CSV only), `parse_options`, `read_options`: see
#'    [CsvReadOptions]
#' - `...` additional parameters.
#'
#' @section Methods:
#'
#' - `$Read()`: returns an Arrow Table.
#'
#' @include arrow-object.R
#' @export
CsvTableReader <- R6Class("CsvTableReader",
  inherit = ArrowObject,
  public = list(
    Read = function() csv___TableReader__Read(self)
  )
)
CsvTableReader$create <- function(file,
                                  read_options = csv_read_options(),
                                  parse_options = csv_parse_options(),
                                  convert_options = csv_convert_options(),
                                  ...) {
  assert_is(file, "InputStream")

  if (is.list(read_options)) {
    read_options <- do.call(csv_read_options, read_options)
  }

  if (is.list(parse_options)) {
    parse_options <- do.call(csv_parse_options, parse_options)
  }

  if (is.list(convert_options)) {
    convert_options <- do.call(csv_convert_options, convert_options)
  }

  if (!(tolower(read_options$encoding) %in% c("utf-8", "utf8"))) {
    file <- MakeReencodeInputStream(file, read_options$encoding)
  }

  csv___TableReader__Make(file, read_options, parse_options, convert_options)
}

#' CSV Reading Options
#'
#' @param use_threads Whether to use the global CPU thread pool
#' @param block_size Block size we request from the IO layer; also determines
#'  the size of chunks when use_threads is `TRUE`.
#' @param skip_rows Number of lines to skip before reading data (default 0).
#' @param column_names Character vector to supply column names. If length-0
#' (the default), the first non-skipped row will be parsed to generate column
#' names, unless `autogenerate_column_names` is `TRUE`.
#' @param autogenerate_column_names Logical: generate column names instead of
#' using the first non-skipped row (the default)? If `TRUE`, column names will
#' be "f0", "f1", ..., "fN".
#' @param encoding The file encoding. (default `"UTF-8"`)
#' @param skip_rows_after_names Number of lines to skip after the column names (default 0).
#'    This number can be larger than the number of rows in one block, and empty rows are counted.
#'    The order of application is as follows:
#'      - `skip_rows` is applied (if non-zero);
#'      - column names are read (unless `column_names` is set);
#'      - `skip_rows_after_names` is applied (if non-zero).
#'
#' @examplesIf arrow_with_dataset()
#' tf <- tempfile()
#' on.exit(unlink(tf))
#' writeLines("my file has a non-data header\nx\n1\n2", tf)
#' read_csv_arrow(tf, read_options = csv_read_options(skip_rows = 1))
#' open_csv_dataset(tf, read_options = csv_read_options(skip_rows = 1))
#' @export
csv_read_options <- function(use_threads = option_use_threads(),
                             block_size = 1048576L,
                             skip_rows = 0L,
                             column_names = character(0),
                             autogenerate_column_names = FALSE,
                             encoding = "UTF-8",
                             skip_rows_after_names = 0L) {
  assert_that(is.string(encoding))

  options <- csv___ReadOptions__initialize(
    list(
      use_threads = use_threads,
      block_size = block_size,
      skip_rows = skip_rows,
      skip_rows_after_names = skip_rows_after_names,
      column_names = column_names,
      autogenerate_column_names = autogenerate_column_names
    )
  )

  options$encoding <- encoding

  options
}

#' @title File reader options
#' @rdname CsvReadOptions
#' @name CsvReadOptions
#' @docType class
#' @usage NULL
#' @format NULL
#' @description `CsvReadOptions`, `CsvParseOptions`, `CsvConvertOptions`,
#' `JsonReadOptions`, `JsonParseOptions`, and `TimestampParser` are containers for various
#' file reading options. See their usage in [read_csv_arrow()] and
#' [read_json_arrow()], respectively.
#'
#' @section Factory:
#'
#' The `CsvReadOptions$create()` and `JsonReadOptions$create()` factory methods
#' take the following arguments:
#'
#' - `use_threads` Whether to use the global CPU thread pool
#' - `block_size` Block size we request from the IO layer; also determines
#' the size of chunks when use_threads is `TRUE`. NB: if `FALSE`, JSON input
#' must end with an empty line.
#'
#' `CsvReadOptions$create()` further accepts these additional arguments:
#'
#' - `skip_rows` Number of lines to skip before reading data (default 0).
#' - `column_names` Character vector to supply column names. If length-0
#' (the default), the first non-skipped row will be parsed to generate column
#' names, unless `autogenerate_column_names` is `TRUE`.
#' - `autogenerate_column_names` Logical: generate column names instead of
#' using the first non-skipped row (the default)? If `TRUE`, column names will
#' be "f0", "f1", ..., "fN".
#' - `encoding` The file encoding. (default `"UTF-8"`)
#' - `skip_rows_after_names` Number of lines to skip after the column names (default 0).
#'    This number can be larger than the number of rows in one block, and empty rows are counted.
#'    The order of application is as follows:
#'      - `skip_rows` is applied (if non-zero);
#'      - column names are read (unless `column_names` is set);
#'      - `skip_rows_after_names` is applied (if non-zero).
#'
#' `CsvParseOptions$create()` takes the following arguments:
#'
#' - `delimiter` Field delimiting character (default `","`)
#' - `quoting` Logical: are strings quoted? (default `TRUE`)
#' - `quote_char` Quoting character, if `quoting` is `TRUE` (default `'"'`)
#' - `double_quote` Logical: are quotes inside values double-quoted? (default `TRUE`)
#' - `escaping` Logical: whether escaping is used (default `FALSE`)
#' - `escape_char` Escaping character, if `escaping` is `TRUE` (default `"\\"`)
#' - `newlines_in_values` Logical: are values allowed to contain CR (`0x0d`)
#'    and LF (`0x0a`) characters? (default `FALSE`)
#' - `ignore_empty_lines` Logical: should empty lines be ignored (default) or
#'    generate a row of missing values (if `FALSE`)?
#'
#' `JsonParseOptions$create()` accepts only the `newlines_in_values` argument.
#'
#' `CsvConvertOptions$create()` takes the following arguments:
#'
#' - `check_utf8` Logical: check UTF8 validity of string columns? (default `TRUE`)
#' - `null_values` character vector of recognized spellings for null values.
#'    Analogous to the `na.strings` argument to
#'    [`read.csv()`][utils::read.csv()] or `na` in [readr::read_csv()].
#' - `strings_can_be_null` Logical: can string / binary columns have
#'    null values? Similar to the `quoted_na` argument to [readr::read_csv()].
#'    (default `FALSE`)
#' - `true_values` character vector of recognized spellings for `TRUE` values
#' - `false_values` character vector of recognized spellings for `FALSE` values
#' - `col_types` A `Schema` or `NULL` to infer types
#' - `auto_dict_encode` Logical: Whether to try to automatically
#'    dictionary-encode string / binary data (think `stringsAsFactors`). Default `FALSE`.
#'    This setting is ignored for non-inferred columns (those in `col_types`).
#' - `auto_dict_max_cardinality` If `auto_dict_encode`, string/binary columns
#'    are dictionary-encoded up to this number of unique values (default 50),
#'    after which it switches to regular encoding.
#' - `include_columns` If non-empty, indicates the names of columns from the
#'    CSV file that should be actually read and converted (in the vector's order).
#' - `include_missing_columns` Logical: if `include_columns` is provided, should
#'    columns named in it but not found in the data be included as a column of
#'    type `null()`? The default (`FALSE`) means that the reader will instead
#'    raise an error.
#' - `timestamp_parsers` User-defined timestamp parsers. If more than one
#'    parser is specified, the CSV conversion logic will try parsing values
#'    starting from the beginning of this vector. Possible values are
#'    (a) `NULL`, the default, which uses the ISO-8601 parser;
#'    (b) a character vector of [strptime][base::strptime()] parse strings; or
#'    (c) a list of [TimestampParser] objects.
#' - `decimal_point` Character to use for decimal point in floating point numbers. Default: "."
#'
#' `TimestampParser$create()` takes an optional `format` string argument.
#' See [`strptime()`][base::strptime()] for example syntax.
#' The default is to use an ISO-8601 format parser.
#'
#' The `CsvWriteOptions$create()` factory method takes the following arguments:
#' - `include_header` Whether to write an initial header line with column names
#' - `batch_size` Maximum number of rows processed at a time. Default is 1024.
#' - `null_string` The string to be written for null values. Must not contain
#'   quotation marks. Default is an empty string (`""`).
#' - `eol` The end of line character to use for ending rows.
#' - `delimiter` Field delimiter
#' - `quoting_style` Quoting style: "Needed" (Only enclose values in quotes which need them, because their CSV
#'    rendering can contain quotes itself (e.g. strings or binary values)), "AllValid" (Enclose all valid values in
#'    quotes), or "None" (Do not enclose any values in quotes).
#'
#' @section Active bindings:
#'
#' - `column_names`: from `CsvReadOptions`
#'
#' @export
CsvReadOptions <- R6Class("CsvReadOptions",
  inherit = ArrowObject,
  public = list(
    encoding = NULL,
    print = function(...) {
      cat("CsvReadOptions\n")
      for (attr in c(
        "column_names", "block_size", "skip_rows", "autogenerate_column_names",
        "use_threads", "skip_rows_after_names", "encoding"
      )) {
        cat(sprintf("%s: %s\n", attr, self[[attr]]))
      }
      invisible(self)
    }
  ),
  active = list(
    column_names = function() csv___ReadOptions__column_names(self),
    block_size = function() csv___ReadOptions__block_size(self),
    skip_rows = function() csv___ReadOptions__skip_rows(self),
    autogenerate_column_names = function() csv___ReadOptions__autogenerate_column_names(self),
    use_threads = function() csv___ReadOptions__use_threads(self),
    skip_rows_after_names = function() csv___ReadOptions__skip_rows_after_names(self)
  )
)

CsvReadOptions$create <- csv_read_options

readr_to_csv_write_options <- function(col_names = TRUE,
                                       batch_size = 1024L,
                                       delim = ",",
                                       na = "",
                                       eol = "\n",
                                       quote = c("needed", "all", "none")) {
  quoting_style_arrow_opts <- c("Needed", "AllValid", "None")
  quote <- match(match.arg(quote), c("needed", "all", "none"))
  quote <- quoting_style_arrow_opts[quote]

  csv_write_options(
    include_header = col_names,
    batch_size = batch_size,
    delimiter = delim,
    null_string = na,
    eol = eol,
    quoting_style = quote
  )
}

#' CSV Writing Options
#'
#' @param include_header Whether to write an initial header line with column names
#' @param batch_size Maximum number of rows processed at a time.
#' @param null_string The string to be written for null values. Must not contain quotation marks.
#' @param delimiter Field delimiter
#' @param eol The end of line character to use for ending rows
#' @param quoting_style How to handle quotes. "Needed" (Only enclose values in quotes which need them, because their CSV
#'    rendering can contain quotes itself (e.g. strings or binary values)), "AllValid" (Enclose all valid values in
#'    quotes), or "None" (Do not enclose any values in quotes).
#'
#' @examples
#' tf <- tempfile()
#' on.exit(unlink(tf))
#' write_csv_arrow(airquality, tf, write_options = csv_write_options(null_string = "-99"))
#' @export
csv_write_options <- function(include_header = TRUE,
                              batch_size = 1024L,
                              null_string = "",
                              delimiter = ",",
                              eol = "\n",
                              quoting_style = c("Needed", "AllValid", "None")) {
  quoting_style <- match.arg(quoting_style)
  quoting_style_opts <- c("Needed", "AllValid", "None")
  quoting_style <- match(quoting_style, quoting_style_opts) - 1L

  assert_that(is.logical(include_header))
  assert_that(is_integerish(batch_size, n = 1, finite = TRUE), batch_size > 0)
  assert_that(is.character(delimiter))
  assert_that(is.character(null_string))
  assert_that(!is.na(null_string))
  assert_that(length(null_string) == 1)
  assert_that(!grepl('"', null_string), msg = "na argument must not contain quote characters.")
  assert_that(is.character(eol))

  csv___WriteOptions__initialize(
    list(
      include_header = include_header,
      batch_size = as.integer(batch_size),
      delimiter = delimiter,
      null_string = as.character(null_string),
      eol = eol,
      quoting_style = quoting_style
    )
  )
}

#' @rdname CsvReadOptions
#' @export
CsvWriteOptions <- R6Class("CsvWriteOptions", inherit = ArrowObject)
CsvWriteOptions$create <- csv_write_options

readr_to_csv_read_options <- function(skip = 0, col_names = TRUE) {
  if (isTRUE(col_names)) {
    # C++ default to parse is 0-length string array
    col_names <- character(0)
  }
  if (identical(col_names, FALSE)) {
    csv_read_options(skip_rows = skip, autogenerate_column_names = TRUE)
  } else {
    csv_read_options(skip_rows = skip, column_names = col_names)
  }
}

#' CSV Parsing Options
#'
#' @param delimiter Field delimiting character
#' @param quoting Logical: are strings quoted?
#' @param quote_char Quoting character, if `quoting` is `TRUE`
#' @param double_quote Logical: are quotes inside values double-quoted?
#' @param escaping Logical: whether escaping is used
#' @param escape_char Escaping character, if `escaping` is `TRUE`
#' @param newlines_in_values Logical: are values allowed to contain CR (`0x0d`)
#'    and LF (`0x0a`) characters?
#' @param ignore_empty_lines Logical: should empty lines be ignored (default) or
#'    generate a row of missing values (if `FALSE`)?
#' @examplesIf arrow_with_dataset()
#' tf <- tempfile()
#' on.exit(unlink(tf))
#' writeLines("x\n1\n\n2", tf)
#' read_csv_arrow(tf, parse_options = csv_parse_options(ignore_empty_lines = FALSE))
#' open_csv_dataset(tf, parse_options = csv_parse_options(ignore_empty_lines = FALSE))
#' @export
csv_parse_options <- function(delimiter = ",",
                              quoting = TRUE,
                              quote_char = '"',
                              double_quote = TRUE,
                              escaping = FALSE,
                              escape_char = "\\",
                              newlines_in_values = FALSE,
                              ignore_empty_lines = TRUE) {
  csv___ParseOptions__initialize(
    list(
      delimiter = delimiter,
      quoting = quoting,
      quote_char = quote_char,
      double_quote = double_quote,
      escaping = escaping,
      escape_char = escape_char,
      newlines_in_values = newlines_in_values,
      ignore_empty_lines = ignore_empty_lines
    )
  )
}

#' @rdname CsvReadOptions
#' @usage NULL
#' @format NULL
#' @docType class
#' @export
CsvParseOptions <- R6Class("CsvParseOptions", inherit = ArrowObject)
CsvParseOptions$create <- csv_parse_options

readr_to_csv_parse_options <- function(delim = ",",
                                       quote = '"',
                                       escape_double = TRUE,
                                       escape_backslash = FALSE,
                                       skip_empty_rows = TRUE) {
  # This function translates from the readr argument list to the arrow arg names
  # TODO: validate inputs
  csv_parse_options(
    delimiter = delim,
    quoting = nzchar(quote),
    quote_char = quote,
    double_quote = escape_double,
    escaping = escape_backslash,
    escape_char = "\\",
    newlines_in_values = escape_backslash,
    ignore_empty_lines = skip_empty_rows
  )
}

#' @rdname CsvReadOptions
#' @usage NULL
#' @format NULL
#' @docType class
#' @export
TimestampParser <- R6Class("TimestampParser",
  inherit = ArrowObject,
  public = list(
    kind = function() TimestampParser__kind(self),
    format = function() TimestampParser__format(self)
  )
)
TimestampParser$create <- function(format = NULL) {
  if (is.null(format)) {
    TimestampParser__MakeISO8601()
  } else {
    TimestampParser__MakeStrptime(format)
  }
}


#' CSV Convert Options
#'
#' @param check_utf8 Logical: check UTF8 validity of string columns?
#' @param null_values Character vector of recognized spellings for null values.
#'    Analogous to the `na.strings` argument to
#'    [`read.csv()`][utils::read.csv()] or `na` in [readr::read_csv()].
#' @param strings_can_be_null Logical: can string / binary columns have
#'    null values? Similar to the `quoted_na` argument to [readr::read_csv()]
#' @param true_values Character vector of recognized spellings for `TRUE` values
#' @param false_values Character vector of recognized spellings for `FALSE` values
#' @param col_types A `Schema` or `NULL` to infer types
#' @param auto_dict_encode Logical: Whether to try to automatically
#'    dictionary-encode string / binary data (think `stringsAsFactors`).
#'    This setting is ignored for non-inferred columns (those in `col_types`).
#' @param auto_dict_max_cardinality If `auto_dict_encode`, string/binary columns
#'    are dictionary-encoded up to this number of unique values (default 50),
#'    after which it switches to regular encoding.
#' @param include_columns If non-empty, indicates the names of columns from the
#'    CSV file that should be actually read and converted (in the vector's order).
#' @param include_missing_columns Logical: if `include_columns` is provided, should
#'    columns named in it but not found in the data be included as a column of
#'    type `null()`? The default (`FALSE`) means that the reader will instead
#'    raise an error.
#' @param timestamp_parsers User-defined timestamp parsers. If more than one
#'    parser is specified, the CSV conversion logic will try parsing values
#'    starting from the beginning of this vector. Possible values are
#'    (a) `NULL`, the default, which uses the ISO-8601 parser;
#'    (b) a character vector of [strptime][base::strptime()] parse strings; or
#'    (c) a list of [TimestampParser] objects.
#' @param decimal_point Character to use for decimal point in floating point numbers.
#'
#' @examplesIf arrow_with_dataset()
#' tf <- tempfile()
#' on.exit(unlink(tf))
#' writeLines("x\n1\nNULL\n2\nNA", tf)
#' read_csv_arrow(tf, convert_options = csv_convert_options(null_values = c("", "NA", "NULL")))
#' open_csv_dataset(tf, convert_options = csv_convert_options(null_values = c("", "NA", "NULL")))
#' @export
csv_convert_options <- function(check_utf8 = TRUE,
                                null_values = c("", "NA"),
                                true_values = c("T", "true", "TRUE"),
                                false_values = c("F", "false", "FALSE"),
                                strings_can_be_null = FALSE,
                                col_types = NULL,
                                auto_dict_encode = FALSE,
                                auto_dict_max_cardinality = 50L,
                                include_columns = character(),
                                include_missing_columns = FALSE,
                                timestamp_parsers = NULL,
                                decimal_point = ".") {
  if (!is.null(col_types) && !inherits(col_types, "Schema")) {
    abort(c(
      "Unsupported `col_types` specification.",
      i = "`col_types` must be NULL, or a <Schema>."
    ))
  }

  csv___ConvertOptions__initialize(
    list(
      check_utf8 = check_utf8,
      null_values = null_values,
      strings_can_be_null = strings_can_be_null,
      col_types = col_types,
      true_values = true_values,
      false_values = false_values,
      auto_dict_encode = auto_dict_encode,
      auto_dict_max_cardinality = auto_dict_max_cardinality,
      include_columns = include_columns,
      include_missing_columns = include_missing_columns,
      timestamp_parsers = timestamp_parsers,
      decimal_point = decimal_point
    )
  )
}

#' @rdname CsvReadOptions
#' @usage NULL
#' @format NULL
#' @docType class
#' @export
CsvConvertOptions <- R6Class("CsvConvertOptions", inherit = ArrowObject)
CsvConvertOptions$create <- csv_convert_options

readr_to_csv_convert_options <- function(na,
                                         quoted_na,
                                         decimal_point,
                                         col_types = NULL,
                                         col_names = NULL,
                                         timestamp_parsers = NULL) {
  include_columns <- character()

  if (is.character(col_types)) {
    col_types <- parse_compact_col_spec(col_types, col_names)
  }

  if (!is.null(col_types)) {
    assert_is(col_types, "Schema")
    # If any columns are null(), drop them
    # (by specifying the other columns in include_columns)
    nulls <- map_lgl(col_types$fields, ~ .$type$Equals(null()))
    if (any(nulls)) {
      include_columns <- setdiff(col_names, names(col_types)[nulls])
    }
  }
  csv_convert_options(
    null_values = na,
    strings_can_be_null = quoted_na,
    col_types = col_types,
    timestamp_parsers = timestamp_parsers,
    include_columns = include_columns,
    decimal_point = decimal_point
  )
}

#' Write CSV file to disk
#'
#' @param x `data.frame`, [RecordBatch], or [Table]
#' @param sink A string file path, connection, URI, or [OutputStream], or path in a file
#' system (`SubTreeFileSystem`)
#' @param file file name. Specify this or `sink`, not both.
#' @param include_header Whether to write an initial header line with column names
#' @param col_names identical to `include_header`. Specify this or
#'     `include_headers`, not both.
#' @param batch_size Maximum number of rows processed at a time. Default is 1024.
#' @param na value to write for NA values. Must not contain quote marks. Default
#'     is `""`.
#' @param write_options see [CSV write options][csv_write_options]
#' @param ... additional parameters
#'
#' @return The input `x`, invisibly. Note that if `sink` is an [OutputStream],
#' the stream will be left open.
#' @export
#' @examples
#' tf <- tempfile()
#' on.exit(unlink(tf))
#' write_csv_arrow(mtcars, tf)
#' @include arrow-object.R
write_csv_arrow <- function(x,
                            sink,
                            file = NULL,
                            include_header = TRUE,
                            col_names = NULL,
                            batch_size = 1024L,
                            na = "",
                            write_options = NULL,
                            ...) {
  unsupported_passed_args <- names(list(...))

  if (length(unsupported_passed_args)) {
    stop(
      "The following ",
      ngettext(length(unsupported_passed_args), "argument is ", "arguments are "),
      "not yet supported in Arrow: ",
      oxford_paste(unsupported_passed_args),
      call. = FALSE
    )
  }

  if (!missing(file) && !missing(sink)) {
    stop(
      "You have supplied both \"file\" and \"sink\" arguments. Please ",
      "supply only one of them.",
      call. = FALSE
    )
  }

  if (missing(sink) && !missing(file)) {
    sink <- file
  }

  if (!missing(col_names) && !missing(include_header)) {
    stop(
      "You have supplied both \"col_names\" and \"include_header\" ",
      "arguments. Please supply only one of them.",
      call. = FALSE
    )
  }

  if (missing(include_header) && !missing(col_names)) {
    include_header <- col_names
  }

  if (is.null(write_options)) {
    write_options <- readr_to_csv_write_options(
      col_names = include_header,
      batch_size = batch_size,
      na = na
    )
  }

  x_out <- x
  if (!inherits(x, "ArrowTabular")) {
    tryCatch(
      x <- as_record_batch_reader(x),
      error = function(e) {
        if (grepl("Input data frame columns must be named", conditionMessage(e))) {
          abort(conditionMessage(e), parent = NA)
        } else {
          abort(
            paste0(
              "x must be an object of class 'data.frame', 'RecordBatch', ",
              "'Dataset', 'Table', or 'RecordBatchReader' not '", class(x)[1], "'."
            ),
            parent = NA
          )
        }
      }
    )
  }

  if (!inherits(sink, "OutputStream")) {
    compression <- detect_compression(sink)
    sink <- make_output_stream(sink)
    if (compression != "uncompressed") {
      # TODO: accept compression and compression_level as args
      sink <- CompressedOutputStream$create(sink, codec = compression)
    }
    on.exit(sink$close())
  }

  if (inherits(x, "RecordBatch")) {
    csv___WriteCSV__RecordBatch(x, write_options, sink)
  } else if (inherits(x, "Table")) {
    csv___WriteCSV__Table(x, write_options, sink)
  } else if (inherits(x, c("RecordBatchReader"))) {
    csv___WriteCSV__RecordBatchReader(x, write_options, sink)
  }

  invisible(x_out)
}

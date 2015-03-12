#!/usr/bin/Rscript

# load packages
suppressMessages(library(data.table))
suppressMessages(library(dplyr))

# get data file URLs to download
message("Downloading list of available data files...", appendLF=FALSE)
url <- "http://citibikenyc.com/system-data"
fileregexp <- paste0("https:\\/\\/s3\\.amazonaws\\.com\\/tripdata\\/",
  "[0-9]{6}-citibike-tripdata\\.zip")
fileurls <- readLines(url, warn=FALSE)
fileurls <- fileurls[grep(fileregexp, fileurls)]
fileurls <- sub(paste0("^(.*)(", fileregexp, ")(.*)$"), "\\2", fileurls)
fileurls <- sub("^https", "http", fileurls)
filenames <- basename(fileurls)
message()
rm(list=c("url", "fileregexp"))
invisible(gc())

# load existing data if available
if (file.exists("rides.rds")) {
  message("Loading existing data...", appendLF=FALSE)
  rides <- list(readRDS("rides.rds"))
  message()
  present <- unique(sub("^([0-9]{4})-([0-9]{2})-([0-9]{2})$", "\\1\\2",
    unique(rides[[1]]$start.date)))
  skip <- substring(filenames, 1, 6) %in% present
  message(paste0(filenames[skip], ": skipping\n"), appendLF=FALSE)
  fileurls <- fileurls[!skip]
  filenames <- filenames[!skip]
  rm(list=c("present", "skip"))
  invisible(gc())
  if (length(fileurls) == 0)
    q("no")
} else {
  rides <- list()
}  
  
# data files use two different date/time formats, regexps to detect which one
dateregexps <- c(
  "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$",
  "^[0-9]{1,2}\\/[0-9]{1,2}\\/[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$")
names(dateregexps) <- c(
  "%Y-%m-%d %H:%M:%S",
  "%m/%d/%Y %H:%M:%S")

# change working directory to a tmp dir
wd <- getwd()
setwd(tempdir())

# download, uncompress, load, and process each data file
for (i in seq_along(fileurls)) {
  message(filenames[i], ": downloading...", appendLF=FALSE)
  download.file(fileurls[i], filenames[i], quiet=TRUE)
  message(" uncompressing...", appendLF=FALSE)
  filedata <- unzip(filenames[i])
  unlink(filenames[i])
  message(" loading...", appendLF=FALSE)
  # tmp <- read.csv(filedata[i], na.strings=c("", "\\N"), stringsAsFactors=FALSE)
  tmp <- fread(filedata[1], na.strings=c("", "\\N"), showProgress=FALSE)
  unlink(filedata)
  message(" processing...", appendLF=FALSE)
  setnames(tmp, colnames(tmp), make.names(colnames(tmp)))
  tmp$tripduration <- as.integer(tmp$tripduration)
  tmp$start.station.id <- as.integer(tmp$start.station.id)
  tmp$start.station.latitude <- as.numeric(tmp$start.station.latitude)
  tmp$start.station.longitude <- as.numeric(tmp$start.station.longitude)
  tmp$end.station.id <- as.integer(tmp$end.station.id)
  tmp$end.station.latitude <- as.numeric(tmp$end.station.latitude)
  tmp$end.station.longitude <- as.numeric(tmp$end.station.longitude)
  tmp$bikeid <- as.integer(tmp$bikeid)
  tmp$birth.year <- as.integer(tmp$birth.year)
  tmp$gender[tmp$gender == "1"] <- "male"
  tmp$gender[tmp$gender == "2"] <- "female"
  tmp$gender[tmp$gender == "0"] <- NA
  start.format <- NULL
  stop.format <- NULL
  for (regexp in dateregexps) {
    if (length(grep(regexp, tmp$starttime[1])) == 1)
      start.format <- names(dateregexps[dateregexps==regexp])
    if (length(grep(regexp, tmp$stoptime[1])) == 1)
      stop.format <- names(dateregexps[dateregexps==regexp])
  }
  if (is.null(start.format))
    stop("Unknown starttime format in file ", filenames[i], ": ",
      tmp$starttime[1])
  if (is.null(stop.format))
    stop("Unknown stoptime format in file ", filenames[i], ": ",
      tmp$stoptime[1])
  tmp$start.date <- as.IDate(tmp$starttime,
    format=start.format)
  tmp$start.time <- as.ITime(tmp$starttime,
    format=start.format)
  tmp$end.date <- as.IDate(tmp$stoptime,
    format=stop.format)
  tmp$end.time <- as.ITime(tmp$stoptime,
    format=stop.format)
  tmp$starttime <- NULL
  tmp$stoptime <- NULL
  setcolorder(tmp, c("tripduration", "start.date", "start.time",
    "start.station.id", "start.station.name",
    "start.station.latitude", "start.station.longitude",
    "end.date", "end.time", "end.station.id", "end.station.name",
    "end.station.latitude", "end.station.longitude",
    "bikeid", "usertype", "birth.year", "gender"))
  rides[[i]] <- tmp
  message()
}
rm(list=c("fileurls", "filenames", "i", "tmp", "dateregexps", "filedata", "regexp", "start.format", "stop.format"))
invisible(gc())

# change working directory back
setwd(wd)
rm(list=c("wd"))
invisible(gc())

# combine and save
message("Combining and saving rides...", appendLF=FALSE)
rides <- tbl_dt(rbindlist(rides))
saveRDS(rides, "rides.rds")
message()

# EOF

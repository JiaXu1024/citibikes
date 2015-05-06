#!/usr/bin/Rscript

# load packages
suppressMessages({
  library(data.table)
  library(dplyr)
  library(rjson)
})

# get stations from the JSON feed
message("Downloading and saving stations...", appendLF=FALSE)
stations <- fromJSON(file="http://citibikenyc.com/stations/json")
stations <- stations[["stationBeanList"]]
for (i in seq_along(stations))
  stations[[i]]$lastCommunicationTime <- NULL
stations <- tbl_dt(rbindlist(stations))
stations <- stations %>%
  select(id, name=stationName, docks=totalDocks, latitude, longitude)
setkey(stations, id)
saveRDS(stations, "stations.rds")
message()
rm(list=c("i", "stations"))
invisible(gc())

# get data file URLs to download
message("Downloading list of available ride files...", appendLF=FALSE)
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
  message("Loading existing rides...", appendLF=FALSE)
  rides <- list(readRDS("rides.rds"))
  message()
  present <- unique(sub("^([0-9]{4})-([0-9]{2})-([0-9]{2})$", "\\1\\2",
    unique(rides[[1]]$start_date)))
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
  "^[0-9]{1,2}\\/[0-9]{1,2}\\/[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$",
  "^[0-9]{1,2}\\/[0-9]{1,2}\\/[0-9]{4} [0-9]{1,2}:[0-9]{2}$")
names(dateregexps) <- c(
  "%Y-%m-%d %H:%M:%S",
  "%m/%d/%Y %H:%M:%S",
  "%m/%d/%Y %H:%M")

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
  setnames(tmp, gsub(" ", "_", colnames(tmp)))
  tmp$tripduration <- as.integer(tmp$tripduration)
  tmp$start_station <- as.integer(tmp$start_station_id)
  tmp$start_station_id <- NULL
  tmp$start_station_name <- NULL
  tmp$start_station_latitude <- NULL
  tmp$start_station_longitude <- NULL
  tmp$end_station <- as.integer(tmp$end_station_id)
  tmp$end_station_id <- NULL
  tmp$end_station_name <- NULL
  tmp$end_station_latitude <- NULL
  tmp$end_station_longitude <- NULL
  tmp$bikeid <- as.integer(tmp$bikeid)
  tmp$birth_year <- as.integer(tmp$birth_year)
  tmp$gender[tmp$gender == "1"] <- "male"
  tmp$gender[tmp$gender == "2"] <- "female"
  tmp$gender[tmp$gender == "0"] <- NA
  start_format <- NULL
  stop_format <- NULL
  for (regexp in dateregexps) {
    if (length(grep(regexp, tmp$starttime[1])) == 1)
      start_format <- names(dateregexps[dateregexps==regexp])
    if (length(grep(regexp, tmp$stoptime[1])) == 1)
      stop_format <- names(dateregexps[dateregexps==regexp])
  }
  if (is.null(start_format))
    stop("Unknown starttime format in file ", filenames[i], ": ",
      tmp$starttime[1])
  if (is.null(stop_format))
    stop("Unknown stoptime format in file ", filenames[i], ": ",
      tmp$stoptime[1])
  tmp$start_date <- as.IDate(tmp$starttime,
    format=start_format)
  tmp$start_time <- as.ITime(tmp$starttime,
    format=start_format)
  tmp$end_date <- as.IDate(tmp$stoptime,
    format=stop_format)
  tmp$end_time <- as.ITime(tmp$stoptime,
    format=stop_format)
  tmp$starttime <- NULL
  tmp$stoptime <- NULL
  setcolorder(tmp, c("start_date", "start_time", "start_station",
    "end_date", "end_time", "end_station",
    "tripduration", "bikeid", "usertype", "birth_year", "gender"))
  rides[[length(rides) + 1]] <- tmp
  message()
}

# change working directory back
setwd(wd)
rm(list=c("fileurls", "filenames", "i", "tmp", "dateregexps",
  "filedata", "regexp", "start_format", "stop_format", "wd"))
invisible(gc())

# combine and save
message("Combining and saving rides...", appendLF=FALSE)
rides <- tbl_dt(rbindlist(rides))
setkey(rides, start_date, start_time)
saveRDS(rides, "rides.rds")
message()
rm(list=c("rides"))
invisible(gc())

# EOF

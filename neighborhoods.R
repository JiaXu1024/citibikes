suppressMessages({
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(ggmap)
  library(scales)
  library(gridExtra)
})

rides <- readRDS("rides.rds")
stations <- readRDS("stations.rds")

# remove stations no longer operational (not included in the station JSON feed)
rides <- rides %>%
  filter(start_station %in% stations$id, end_station %in% stations$id)

# count incoming rides
# define weekends as Friday 6pm until 6pm Sunday 6pm
weekends <- (wday(rides$end_date) == 6 & hour(rides$end_time) >= 18) |
  wday(rides$end_date) == 7 |
  (wday(rides$end_date) == 1 & hour(rides$end_time) < 18)
weekdays <- !weekends

wd_in <- rides[weekdays,] %>%
  count(id=end_station, hour=hour(end_time))
wd_in$n <- wd_in$n / 5
# setkey(wd_in, id)
# wd_in$n <- wd_in$n / wd_in[stations, docks]
wd_in <- spread(wd_in, hour, n)
wd_in[is.na(wd_in)] <- 0
setkey(wd_in, id)
setnames(wd_in, colnames(wd_in)[-1],
  paste0("wd_in_", colnames(wd_in)[-1]))
patterns <- wd_in
rm(list=c("wd_in"))

we_in <- rides[weekends,] %>%
  count(id=end_station, hour=hour(end_time))
we_in$n <- we_in$n / 2
# setkey(we_in, id)
# we_in$n <- we_in$n / we_in[stations, docks]
we_in <- spread(we_in, hour, n)
we_in[is.na(we_in)] <- 0
setkey(we_in, id)
setnames(we_in, colnames(we_in)[-1],
  paste0("we_in_", colnames(we_in)[-1]))
patterns <- patterns[we_in]
rm(list=c("we_in", "weekdays", "weekends"))

# count outgoing rides
# define weekends as Friday 6pm until 6pm Sunday 6pm
weekends <- (wday(rides$start_date) == 6 & hour(rides$start_time) >= 18) |
  wday(rides$start_date) == 7 |
  (wday(rides$start_date) == 1 & hour(rides$start_time) < 18)
weekdays <- !weekends

wd_out <- rides[weekdays,] %>%
  count(id=start_station, hour=hour(start_time))
wd_out$n <- wd_out$n / 5
# setkey(wd_out, id)
# wd_out$n <- wd_out$n / wd_out[stations, docks]
wd_out <- spread(wd_out, hour, n)
wd_out[is.na(wd_out)] <- 0
setkey(wd_out, id)
setnames(wd_out, colnames(wd_out)[-1],
  paste0("wd_out_", colnames(wd_out)[-1]))
patterns <- patterns[wd_out]
rm(list=c("wd_out"))

we_out <- rides[weekends,] %>%
  count(id=start_station, hour=hour(start_time))
we_out$n <- we_out$n / 2
# setkey(we_out, id)
# we_out$n <- we_out$n / we_out[stations, docks]
we_out <- spread(we_out, hour, n)
we_out[is.na(we_out)] <- 0
setkey(we_out, id)
setnames(we_out, colnames(we_out)[-1],
  paste0("we_out_", colnames(we_out)[-1]))
patterns <- patterns[we_out]
rm(list=c("we_out", "weekdays", "weekends"))

kmax <- 15
variance <- data.frame(k=1:kmax, explained=rep(NA_real_, kmax))
for (k in 1:kmax) {
  km <- kmeans(patterns, centers=k, iter.max=100, nstart=100)
  stations[, paste0("k_", k)] <- as.factor(km$cluster)
  variance[k, "explained"] <- 1 - km$tot.withinss / km$totss
}
rm(list=c("k", "kmax", "km"))

if (!file.exists("neighborhoods"))
  dir.create("neighborhoods", mode="755")
save(stations, variance, file=file.path("neighborhoods", "neighborhoods.rda"))

# run shiny app
# library(shiny)
# runApp("neighborhoods")

# deploy shiny app
# suppressMessages(library(shinyapps))
# deployApp("neighborhoods", "citibike-neighborhoods")

# EOF

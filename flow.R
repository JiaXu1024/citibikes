#!/usr/bin/Rscript

suppressMessages({
  library(data.table)
  library(dplyr)
  library(ggplot2)
  library(ggmap)
  library(scales)
  library(gridExtra)
})

if (!file.exists("rides.rds"))
  stop("Data file not found: rides.rds\nPlease run import.R first.")

message("Loading rides...", appendLF=FALSE)
rides <- readRDS("rides.rds")
message()

# extract stations
# another option is the JSON feed, which also gives the number of docks
# http://citibikenyc.com/stations/json

message("Extracting stations...", appendLF=FALSE)
stations <- rbind(
  rides %>%
    select(id=start.station.id, name=start.station.name,
      latitude=start.station.latitude, longitude=start.station.longitude),
  rides %>%
    select(id=end.station.id, name=end.station.name,
      latitude=end.station.latitude, longitude=end.station.longitude)) %>%
  group_by(id) %>%
  summarise(name=last(name),
    latitude=last(latitude), longitude=last(longitude)) %>%
  arrange(id)
setkey(stations, id)
message()

# flow

message("Calculating flow of bikes...", appendLF=FALSE)
flow <- tbl_dt(data.table(expand.grid(id=stations$id, hour=0:23)))
setkey(flow, id, hour)
flow <- flow[stations]

# count incoming rides
# define weekends as Friday 6pm until 6pm Sunday 6pm
weekends <- (wday(rides$end.date) == 6 & hour(rides$end.time) >= 18) |
  wday(rides$end.date) == 7 |
  (wday(rides$end.date) == 1 & hour(rides$end.time) < 18)
weekdays <- !weekends

weekdays.in <- rides[weekdays,] %>%
  count(id=end.station.id, hour=hour(end.time))
setkey(weekdays.in, id, hour)
flow$in.weekdays <- weekdays.in[flow, n] / 5
flow$in.weekdays[is.na(flow$in.weekdays)] <- 0

weekends.in <- rides[weekends,] %>%
  count(id=end.station.id, hour=hour(end.time))
setkey(weekends.in, id, hour)
flow$in.weekends <- weekends.in[flow, n] / 2
flow$in.weekends[is.na(flow$in.weekends)] <- 0

# count outgoing rides
# define weekends as Friday 6pm until 6pm Sunday 6pm
weekends <- (wday(rides$start.date) == 6 & hour(rides$start.time) >= 18) |
  wday(rides$start.date) == 7 |
  (wday(rides$start.date) == 1 & hour(rides$start.time) < 18)
weekdays <- !weekends

weekdays.out <- rides[weekdays,] %>%
  count(id=start.station.id, hour=hour(start.time))
setkey(weekdays.out, id, hour)
flow$out.weekdays <- weekdays.out[flow, n] / 5
flow$out.weekdays[is.na(flow$out.weekdays)] <- 0

weekends.out <- rides[weekends,] %>%
  count(id=start.station.id, hour=hour(start.time))
setkey(weekends.out, id, hour)
flow$out.weekends <- weekends.out[flow, n] / 2
flow$out.weekends[is.na(flow$out.weekends)] <- 0

rm(list=c("weekdays", "weekdays.in", "weekdays.out",
  "weekends", "weekends.in", "weekends.out"))
invisible(gc())

flow <- flow %>%
  mutate(weekdays = in.weekdays - out.weekdays,
    weekends = in.weekends - out.weekends)

differences <- c(flow$weekdays, flow$weekends)
differences <- cut_number(differences, n=11)
levels(differences) <- -5:5

flow$group.weekdays <- differences[1:nrow(flow)]
flow$group.weekends <- differences[(nrow(flow)+1):(nrow(flow)*2)]

rm(list=c("differences"))

saveRDS(flow, "flow.rds")
message()

# pre-generate shiny app plots for best performance

message("Pre-generating plots for shiny app...", appendLF=FALSE)
if (!file.exists(file.path("flow", "www")))
  dir.create(file.path("flow", "www"), recursive=TRUE, mode="755")

# generate and extract a legend
# http://stackoverflow.com/q/13649473/
# suppress blank plot window opening
# https://github.com/hadley/ggplot2/issues/809
pdf(NULL)
p <- ggplot(flow[flow$hour == 0, ],
  aes(longitude, latitude, color=as.integer(group.weekdays))) +
  geom_point() + scale_color_gradient2(name=element_blank(),
  low=muted("blue"), high=muted("red"), limits=c(-5, 5),
  breaks=c(-5, 5), labels=c("leaving", "arriving")) +
  theme(legend.position="bottom")
tmp <- ggplot_gtable(ggplot_build(p))
legend <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
legend <- tmp$grobs[[legend]]
suppress <- dev.off()
rm(list="tmp")

suppressWarnings({
  suppressMessages({
    p <- ggmap(get_map(c(-74.05, 40.55, -73.93, 40.9)), extent="device") +
      scale_color_brewer("bikes\n", type="div", palette="RdBu")
  })
})

for (h in 0:23) {
  png(file.path("flow", "www", paste0(h, ".png")),
    width=300, height=180, units="mm", res=72)
  suppressWarnings({
    wd <- p + ggtitle(paste0("Weekdays ", h, ":00 - ", h+1, ":00")) +
      geom_point(data=flow[flow$hour == h,], size=10, alpha=1/5,
      aes(longitude, latitude, color=group.weekdays)) +
      theme(legend.position="none")
    we <- p + ggtitle(paste0("Weekends ", h, ":00 - ", h+1, ":00")) +
      geom_point(data=flow[flow$hour == h,], size=10, alpha=1/5,
      aes(longitude, latitude, color=group.weekends)) +
      theme(legend.position="none")
    grid.arrange(arrangeGrob(wd + theme(legend.position="none"),
      we + theme(legend.position="none"), nrow=1),
      legend, nrow=2, heights=c(10, 1))
  })
  suppress <- dev.off()
}
message()

# run shiny app
# library(shiny)
# runApp("flow")

# deploy shiny app
# suppressMessages(library(shinyapps))
# deployApp("flow", "citibike-flow")

# EOF

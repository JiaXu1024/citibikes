#!/usr/bin/Rscript

suppressMessages({
  library(data.table)
  library(dplyr)
  library(ggplot2)
  library(ggmap)
  library(scales)
  library(gridExtra)
})

if (!file.exists("stations.rds"))
  stop("Data file not found: stations.rds\nPlease run import.R first.")

message("Loading stations...", appendLF=FALSE)
stations <- readRDS("stations.rds")
message()

if (!file.exists("rides.rds"))
  stop("Data file not found: rides.rds\nPlease run import.R first.")

message("Loading rides...", appendLF=FALSE)
rides <- readRDS("rides.rds")
message()

# flow

message("Calculating flow of bikes...", appendLF=FALSE)
flow <- tbl_dt(data.table(expand.grid(id=stations$id, hour=0:23)))
setkey(flow, id, hour)
flow <- flow[stations]

# count incoming rides
# define weekends as Friday 6pm until 6pm Sunday 6pm
weekends <- (wday(rides$end_date) == 6 & hour(rides$end_time) >= 18) |
  wday(rides$end_date) == 7 |
  (wday(rides$end_date) == 1 & hour(rides$end_time) < 18)
weekdays <- !weekends

wd_in <- rides[weekdays,] %>%
  count(id=end_station, hour=hour(end_time))
setkey(wd_in, id, hour)
flow$wd_in <- wd_in[flow, n] / 5

we_in <- rides[weekends,] %>%
  count(id=end_station, hour=hour(end_time))
setkey(we_in, id, hour)
flow$we_in <- we_in[flow, n] / 2

# count outgoing rides
# define weekends as Friday 6pm until 6pm Sunday 6pm
weekends <- (wday(rides$start_date) == 6 & hour(rides$start_time) >= 18) |
  wday(rides$start_date) == 7 |
  (wday(rides$start_date) == 1 & hour(rides$start_time) < 18)
weekdays <- !weekends

wd_out <- rides[weekdays,] %>%
  count(id=start_station, hour=hour(start_time))
setkey(wd_out, id, hour)
flow$wd_out <- wd_out[flow, n] / 5

we_out <- rides[weekends,] %>%
  count(id=start_station, hour=hour(start_time))
setkey(we_out, id, hour)
flow$we_out <- we_out[flow, n] / 2

rm(list=c("weekdays", "wd_in", "wd_out", "weekends", "we_in", "we_out"))
invisible(gc())

flow[is.na(flow)] <- 0
flow <- flow %>%
  mutate(wd = wd_in - wd_out, we = we_in - we_out)

differences <- c(flow$wd, flow$we)
differences <- cut_number(differences, n=11)
levels(differences) <- -5:5

flow$wd_group <- differences[1:nrow(flow)]
flow$we_group <- differences[(nrow(flow)+1):(nrow(flow)*2)]

rm(list=c("differences"))

saveRDS(flow, "flow.rds")
message()

# try out pre-generating shny app plots for best performance

message("Pre-generating plots for shiny app...", appendLF=FALSE)
if (!file.exists(file.path("flow", "www")))
  dir.create(file.path("flow", "www"), recursive=TRUE, mode="755")

# generate and extract a legend
# http://stackoverflow.com/q/13649473/
# suppress blank plot window opening
# https://github.com/hadley/ggplot2/issues/809
pdf(NULL)
p <- ggplot(flow[flow$hour == 0, ],
  aes(longitude, latitude, color=as.integer(wd_group))) +
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
      aes(longitude, latitude, color=wd_group)) +
      theme(legend.position="none")
    we <- p + ggtitle(paste0("Weekends ", h, ":00 - ", h+1, ":00")) +
      geom_point(data=flow[flow$hour == h,], size=10, alpha=1/5,
      aes(longitude, latitude, color=we_group)) +
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

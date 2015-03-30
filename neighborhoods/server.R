library(data.table)
library(shiny)
library(ggplot2)
library(ggmap)

load("neighborhoods.rda")

p <- ggmap(get_map(c(-74.05, 40.55, -73.93, 40.9)), extent="device")

shinyServer(function(input, output) {
  # output$plot <- renderImage({
  #   list(src=file.path("www", paste0(input$hour, ".png")))
  output$clusters <- renderPlot({
    stations$cluster <- stations[, paste0("k_", input$k), with=FALSE]
    p +
      geom_point(data=stations,
        aes(longitude, latitude, color=cluster, size=docks)) +
      guides(color=guide_legend(title="cluster", order=1,
        override.aes=list(size=8)), size=guide_legend(order=2)) +
      scale_size(range=c(3, 8))
  })
  output$variance <- renderPlot({
    ggplot(variance, aes(k, explained)) +
      geom_point() + geom_line() +
      geom_point(data=variance[input$k,], color="red", size=3) +
      xlab("number of clusters") + ylab("variance explained")
  })
})

# EOF

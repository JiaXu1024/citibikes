library(shiny)

shinyUI(fluidPage(
  titlePanel("Citi Bike Neighborhoods"),
  sidebarLayout(
    sidebarPanel(
      p(paste0("This app shows a K-means clustering based on the average ",
        "number of bikes arriving to and leaving from each station every ",
        "hour, counting separately for weekdays and weekends.")),
      p(paste0("The first tab contains the clustering results, and the second ",
        "tab the proportion of variance explained for each value of k.")),
      sliderInput("k", "Number of clusters",
        min=1, max=15, value=3, step=1, round=TRUE,
        animate=animationOptions(interval=2000, loop=TRUE))
    ),
    mainPanel(tabsetPanel(
      tabPanel("Clusters",
        # plotOutput("clusters", width="600px", height="600px")),
        plotOutput("clusters", width="auto", height="600px")),
      tabPanel("Variance Explained",
        plotOutput("variance"))
    ))
  )
))

# EOF

library(shiny)

shinyUI(fluidPage(
  titlePanel("Citi Bike Neighborhoods"),
  sidebarLayout(
    sidebarPanel(
      p("This app shows a K-means clustering of",
        a(href="http://www.citibikenyc.com", "Citi Bike"),
        "stations. It is based on the pattern of bikes arriving to and leaving",
        "from each station, every hour of the day and counting separately for",
        "weekdays and weekends."),
      p("The first tab contains the clustering results, and the second",
        "tab the proportion of variance explained for each value of k."),
      p("Source code is available on",
        a(href="https://github.com/ilarischeinin/citibikes", "GitHub.")),
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

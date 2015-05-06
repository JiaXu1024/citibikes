library(shiny)

shinyUI(fluidPage(
  verticalLayout(
    titlePanel("Flow of Citi Bikes"),
    div(style=paste("width: 850px; height: 510px;",
      "margin-left: auto; margin-right: auto;"),
      imageOutput("plot", width="850px", height="510px")),
    wellPanel(
      sliderInput("hour", "Hour",
        min=0, max=23, value=0, step=1, round=TRUE,
        animate=animationOptions(interval=2000, loop=TRUE)),
      p("This visualization shows",
        a(href="http://www.citibikenyc.com", "Citi Bike"),
        "stations in New York City with the blue / red colors representing",
        "the number of bikes leaving from / arriving to each station.",
        "Weekdays and weekends are shown next to each other, and each hour of",
        "the day separately. Source code is available on",
        a(href="https://github.com/ilarischeinin/citibikes", "GitHub."))
    ))
))

# EOF

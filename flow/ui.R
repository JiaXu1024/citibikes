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
        animate=animationOptions(interval=2000, loop=TRUE))
    ))
))

# EOF

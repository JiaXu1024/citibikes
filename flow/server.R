library(shiny)

shinyServer(function(input, output) {
  output$plot <- renderImage({
    list(src=file.path("www", paste0(input$hour, ".png")))
  }, deleteFile=FALSE)
})

# EOF

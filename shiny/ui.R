library(shiny)
library(plotly)
v1<-2012
v2<- 8
v3<-100
lat<-55.2045
lon<--162.7184
site<-"Cold Bay, Alaska"
raster_dem<-"cold_bay_3857_clip.tiff"


shinyUI(fluidPage(
  
  titlePanel("MoRph Brant web interface"),
  navlistPanel(
    "Parameters",
    tabPanel("Global parameters",
             "Brant geese",
             img(src="http://www.mullbirds.com/Brant%20Geese-SS.jpg",width=100),
             column(6,
             textInput("G1", val=site,'Site name'),
             textInput("lon", val=lon, 'Longitude'),
             textInput("lat", val= lat,'Latitude'),
             
             ######
             sliderInput("G2", "Start year:",  
                         min = 2000, max = 2050, value = v1),
             #########
             ######
             sliderInput("G3", "Start month:",  
                         min = 1, max = 12, value = v2)),
             #########
             ######
             column(6,
             sliderInput("G4", "Time step in hours:",  
                         min = 1, max = 24, value = 1),
             #########
             ######
             sliderInput("G5", "Length of model run in days:",  
                         min = 1, max = 1000, value = v3))
             #########
             
             
             
             
             
             ),
    tabPanel("Patch parameters",
             sliderInput("P1", "Grid cell side length in raster units",  
                         min = 2, max = 100, value = 10,step=1),
             textInput("raster_dem", val=raster_dem,'Raster elevation layer'),
             actionButton("Grid_Button", "Click here to extract values to grid cells. Warning, this may take some time to run")
             #########
             
             ),
  
    tabPanel("Forager parameters",
             
             ######
             sliderInput("F1", "Number of foragers:",  
                         min = 10, max = 5000, value = 200,step = 10),
             #########
             
             ######
             sliderInput("F2", "Initial mass of foragers kg:",  
                         min = 0.5, max = 8, value = 2.8,step = 0.1),
             #########
             
             ######
             sliderInput("F3", "Standard deviation of mass of foragers kg:",  
                         min = 0.1, max = 1, value = 0.3,step = 0.01),
             #########
            
             plotOutput("hist")
             
             ),
    "Figures",
    tabPanel("Map",
             radioButtons("to_map", "Show a single layer",
                          c("Elevation" = "r",
                            "Graticule" = "grat",
                            "Site centroids" = "grat_points")),
             plotOutput("map")),
    tabPanel("Tide heights",
             sliderInput("off1", "Amplitude offset %:",  min = 0, max = 200,step=0.1, value = 100),
             sliderInput("off2", "Height offset m:",  min = -2, max = 2,step=0.1, value = 0),
             sliderInput("off3", "Tide time offset (min):",  min = -360, max = 360,step=1, value = 0),
             plotlyOutput("tide_plot")),
    tabPanel("Day length",
             plotOutput("day_plot")),
    tabPanel("Temperature",
             plotlyOutput("temperature_plot")),
    tabPanel("Wind",
             plotlyOutput("wind_plot")),
    
    tabPanel("Model",
    uiOutput("model_day"),
    sliderInput("hour", "Hour of day",  min = 0, max = 24,step=1, value = 12),
    textOutput("isday"),
    plotOutput("model_plot"))
  )    
))









# 
# shinyUI(navbarPage("Morph...",
#                    titlePanel("title panel"),
#                    navbarMenu("Input parameters",
#                    tabPanel("Global parameters"),
#                    tabPanel("Patch parameters")),
#                    
#                    navbarMenu("Run",
#                               tabPanel("Setup"),
#                               tabPanel("Start")     
#                               ),
#                    navbarMenu("Show results",
#                               tabPanel("Patch results"),
#                               tabPanel("Forager results"))
# ))


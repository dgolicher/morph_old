#
# This is the server logic of a Shiny web application. You can run the 
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#
library(XML)
library(ggplot2)
library(rtide)
library(rgdal)
library(graticule)
#library(ggmap)
library(raster)
library(dismo)
library(rgeos)
library(insol)
library(shiny)
library(plotly)
library(rnoaa)
library(reshape2)
library(RColorBrewer)

source("/home/rstudio/morph/scripts/db_functions.R")
PgMakeDb("brant")
PgInit("brant")
PgPlr("brant")
PgLoadRaster()
#station_data <- ghcnd_stations()
#load("station_data.dat")
#stations<-meteo_process_geographic_data(station_data, lat, lon)
#climate_data<-ghcnd("USW00025624") ## Load cold bay
climate_data<-read.csv("data/climate_data.csv")
meas<-paste("VALUE",1:31,sep="")
climate_data<-melt(climate_data,id=c("year","month","element"),m=meas)
climate_days<-as.numeric(gsub("VALUE","",climate_data$variable))
climate_year<-as.numeric(as.character(climate_data$year))
climate_month<-as.numeric(as.character(climate_data$month))
climate_data$date<-as.Date(sprintf("%04d-%02d-%02d",climate_year,climate_month,climate_days))
load("data/patches.rda")
mp <- gmap(r)

shinyServer(function(input, output) {
  observeEvent(input$Grid_Button, {
    progress <- shiny::Progress$new()
    on.exit(progress$close())
    progress$set(message = "Extracting, please wait", value = 0.2)
 
    gridsize<-input$P1
    PgMakeGrat(xdim=gridsize,ydim=gridsize)
    PgPSuitable()
  
  })
#####

output$hist <- renderPlot({
  
#### Forager tab  
  n<-input$F1
  mn<-input$F2
  sd<-input$F3
  hist(rnorm(n,mn,sd),main="Forager mass",col="grey",xlab="Kg")
     })  
####################################  Tide tab
output$tide_plot <- renderPlotly({

  progress <- shiny::Progress$new()
  # Make sure it closes when we exit this reactive, even if there's an error
  on.exit(progress$close())
  progress$set(message = "Making plot, please wait", value = 0.2)
  
startyr<-input$G2
startmn<-input$G3
days<-input$G5
off1<-input$off1/100
off2<-input$off2
off3<-input$off3*60
##Test
# startyr<-2000
# startmn<-1
# days<-100

start_date<-as.Date(sprintf("%04d-%02d-%02d",startyr,startmn,1))
end_date<-start_date+30

tide_station1<-tide_height(stations = "King Cove*", minutes = 60L,
                 from = start_date, to = end_date, tz = "UTC",
                 harmonics = rtide::harmonics)
tide_station2<-tide_height(stations = "Port Moller*", minutes = 60L,
               from = start_date, to = end_date, tz = "UTC",
               harmonics = rtide::harmonics)
tide_site<-tide_station1
tide_site$Station<-"Actual site"

tide_site$TideHeight<-(tide_site$TideHeight*off1)+off2
tide_site$DateTime<-tide_site$DateTime+off3

d<-rbind(tide_station1,tide_station2,tide_site)
d$Station<-substr(d$Station,0,20)
  g0<-ggplot(d,aes(x=DateTime,y=TideHeight,col=Station))
  g1<-g0+geom_line()  
  g1
  ggplotly(g1)

})

### Temperature tab

output$temperature_plot <- renderPlotly({

progress <- shiny::Progress$new()
on.exit(progress$close())
progress$set(message = "Making plot, please wait", value = 0.2)
temp_data<-climate_data[climate_data$element=="TMIN"|climate_data$element=="TMAX",]
temp_data$element<-as.character(temp_data$element)

g0<-ggplot(temp_data,aes(x=date,y=value,col=element))
g1<-g0+geom_line()
ggplotly(g1)


})
####  Wind
output$wind_plot<-renderPlotly({
  
  wind_data<-climate_data[climate_data$element=="AWND",]   
  wind_data<-na.omit(wind_data)
  wind_data$element<-as.character(wind_data$element)
  
  g0<-ggplot(wind_data,aes(x=date,y=value/10))
  g1<-g0+geom_line()
  ggplotly(g1)
  
})

######################  Day length tab
output$day_plot <- renderPlot({
  lat<-as.numeric(input$lat)
  lon<-as.numeric(input$lon)
  startyr<-input$G2
  startmn<-input$G3
  days<-input$G5
  
  start_date<-as.Date(sprintf("%04d-%02d-%02d",startyr,startmn,1))
  day_seq<-seq(start_date,start_date+days,1)
  jd<-as.numeric(format(day_seq, "%j"))
  day_length<-data.frame(day_seq,daylength(lat, lon,jd, tmz=-10))  
  sun<-melt(day_length,id=1,meas=2:3)
  g0<-ggplot(sun,aes(x=day_seq,y=value,colour=variable))
  g1<-g0+geom_line()  
  g1
  })

#############################


############### Map tab
 
output$map <- renderPlot({
   gridsize<-input$P1
  
    mp <- gmap(r)
    plot(mp)
    #save(mp,file="basemap.rda")
    grat<-PgGetQuery()
    grat_points<-data.frame(coordinates(grat),grat@data)
    map <- switch(input$to_map,
                   r = "r",
                   grat = "grat",
                   grat_points = "grat_points")
    
    
    if (map=="grat")plot(grat,add=T)
    r[r>5]<-NA
    r[r< -10]<-NA
    cols <- brewer.pal(8,"Blues")[8:1]
    if(map=="r")plot(r, col=cols,alpha=0.8, add=TRUE,legend=FALSE)
    if(map=="grat_points") points(grat_points,pch=21,bg="red",cex=grat_points$psuitable/100)
    
    
   
  })

#### Model run
output$model_day <- renderUI({
  startyr<-input$G2
  startmn<-input$G3
  days<-input$G5
  start_date<-as.Date(sprintf("%04d-%02d-%02d",startyr,startmn,1))
  end_date<-start_date+days
  sliderInput("model_day", "Date", min=start_date, max=end_date, value=start_date)
})


output$model_plot <- renderPlot({

lat<-as.numeric(input$lat)
lon<-as.numeric(input$lon)
model_day<-input$model_day
model_hour<-input$hour
plot(mp) 
n<-sample(1:100+5*model_hour,10)
points(grat_points[n,],pch=21,col="red",bg="red")

jd<-as.numeric(format(model_day, "%j"))
day_len<-data.frame(daylength(lat, lon,jd, tmz=-10))
isday<-ifelse(model_hour>day_len$sunrise & model_hour< day_len$sunset,"Day","Night")  
output$isday <- renderText({ isday})

})

  
})

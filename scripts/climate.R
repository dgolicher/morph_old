library(rnoaa)
#station_data <- ghcnd_stations()
#load("station_data.dat")
#stations<-meteo_process_geographic_data(station_data, lat, lon)
#climate_data<-ghcnd("USW00025624") ## Load cold bay
climate_data<-read.csv("/home/rstudio/morph/data/climate_data.csv")
meas<-paste("VALUE",1:31,sep="")
climate_data<-melt(climate_data,id=c("year","month","element"),m=meas)
climate_days<-as.numeric(gsub("VALUE","",climate_data$variable))
climate_year<-as.numeric(as.character(climate_data$year))
climate_month<-as.numeric(as.character(climate_data$month))
climate_data$date<-as.Date(sprintf("%04d-%02d-%02d",climate_year,climate_month,climate_days))


d<-data.frame(date=climate_data$date,element=climate_data$element,value=climate_data$value)
d<-na.omit(d)
con<-odbcConnect("brant")

write.table(d,"/home/rstudio/morph/tmp.csv",col.names = F,row.names=F,sep=",")

query<-"
drop table if exists climate;
create table climate
(
date date,
element varchar(6),
value float
);"
odbcQuery(con,query)
com<-"echo \"\\COPY climate FROM '/home/rstudio/morph/tmp.csv' DELIMITERS ',' CSV;\" | psql -h postgis -U docker -d brant"
com
system(com)
com<-"rm /home/rstudio/morph/tmp.csv"
system(com)


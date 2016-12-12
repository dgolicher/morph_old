
source("/home/rstudio/morph/scripts/db_functions.R")
## Assuming the Brant database exists
PgLoadVector(flnm="xtide_sites",tabnm="xtide_sites",db="brant",srid=4326,path="/home/rstudio/morph/shapefiles/")
library("date")
startchar <- '2016-01-01 01:00'
endchar <- '2018-01-01 01:00'
# Site name, taken from http://www.flaterco.com/xtide/locations.html
site1 <-'Grant Point, Izembek Lagoon, Bristol Bay, Alaska'
site2<-'Cold Bay, Alaska'
site3<-'Morzhovoi Bay, Alaska'
#site4<-'Amak Island, 5 miles southeast of, Alaska Current'
site4<-'St. Catherine Cove, Unimak Island, Alaska'
#site6<-'Bechevin Bay, off Rocky Point, Alaska Current'

get_tides<-function(sitename=site1)
{
tidecommand = paste('tide -l "',sitename,'" -b "',
		startchar, '" -e "', endchar,
		'" -f c -m m -s 00:60 -u m -z', sep = '')

ss = system(tidecommand, intern = TRUE) #invoke tide.exe and return results
# Convert the character strings in 'ss' into a data frame
tides = read.table(textConnection(ss), sep = ',', colClasses = 'character')
# Add column names to the data frame
names(tides) = c('Site','Date','Hour','TideHt')
# Combine the Date & Hour columns into a POSIX time stamp
#tides$Date<-as.Date(tides$Date)
tides$Time = as.POSIXlt(paste(tides$Date,tides$Hour), 
		format = "%Y-%m-%d %I:%M %p", tz = "US/Alaska")
# Strip off the height units and convert tide height to numeric values
tides$TideHt = as.numeric(gsub('[ [:alpha:]]',' ',tides$TideHt))
# Create a column of time stamps in the current R session time zone
# tides$LocalTime = c(tides$Time)
tides}

tides<-get_tides(site1)
d<-data.frame(station=1,nm="Grant",time=tides$Time,ht=tides$TideHt)
tides<-get_tides(site2)
d2<-data.frame(station=2,nm="Cold",time=tides$Time,ht=tides$TideHt)
d<-rbind(d,d2)
tides<-get_tides(site3)
d2<-data.frame(station=3,nm="Morz",time=tides$Time,ht=tides$TideHt)
d<-rbind(d,d2)
tides<-get_tides(site4)
d2<-data.frame(station=4,nm="StCath",time=tides$Time,ht=tides$TideHt)
d<-rbind(d,d2)

library(RODBC)
con<-odbcConnect("brant")

write.table(d,"/home/rstudio/morph/tmp.csv",col.names = F,row.names=F,sep=",")

query<-"
drop table if exists tides;
create table tides
(
station integer,
name varchar(6),
time timestamp,
ht float
);"
odbcQuery(con,query)
com<-"echo \"\\COPY tides FROM '/home/rstudio/morph/tmp.csv' DELIMITERS ',' CSV;\" | psql -h postgis -U docker -d brant"
com
system(com)
com<-"rm /home/rstudio/morph/tmp.csv"
system(com)


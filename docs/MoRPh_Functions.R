# ---
# title: "MoRph functions"
# author: "Duncan Golicher"
# date: "01/12/2016"
# output: html_document
# ---
# 
# 
# # PostGIS database functions.
# 
# All functions that work on the database begin with the suffix Pg. The naming convention thereafter is to use two capitalised. words for each function.
# 
# ## Creating a new data base
# Save this with the name .pgpass to the home directory.
# 
# New databases can be added directly from the command line, but a simple R function can be used.
# The function drops the database if it is not in use and then creates it. So use with care if the database already exists! It only needs to be called once!
# 
# ```{r}


PgMakeDb<-function(dbname="brant"){
  com<-paste("dropdb -h postgis -U docker ",dbname,sep="")
  system(com)
  com<-paste("createdb -h postgis -U docker ",dbname,sep="")
  system(com)
}


# ```
# 
# ### Allowing connections to the database using RODBC
# 
# Every database being used needs an entry in the odbc.ini file that is placed in /etc/odbc.ini.
# As this is only directly editable with root priviledges the best strategy is to edit an odbc.ini file in the home directory and then copy it into place by opening a shell.
# 
# #### odbc.ini example
# 
# **Make sure that the connection name (in this case brant) matches the database name, as this convention will be used in the subsequent functions.**
# 
# ```{bash, eval=FALSE}
# [brant]
# Driver = /usr/lib/x86_64-linux-gnu/odbc/psqlodbcw.so
# Database = brant
# Servername = postgis
# Username = docker
# Password = docker
# Protocol = 8.2.5
# ReadOnly = 0
# ```
# 
# Then open a shell and run
# 
# ```{bash,eval=FALSE}
# sudo cp odbc.ini /etc/odbc.ini
# ```
# 
# A new entry that follows this format should be added to the odbc.ini file ever time a new data base is created. It is envisaged that a new database would be used for each model, with all tables being placed in the public schema. In some cases it may be useful to use more schemas within the database for separate sites, but this may not be necessary. The concept is to allow storage and backup of all the relevant information by dumping the database to a single file.
# 
# ### Adding extensions to the database
# 
# ```{r}


PgInit<-function(dbname="brant"){
  require(RODBC)
  con<-odbcConnect(dbname) ## Note the use of the connection name. IT MUST MATCH THE DATABASE!
  odbcQuery(con,"create extension postgis")
  odbcQuery(con,"create extension plr")
}


# ```
# 
# 
# ### Adding PLR statistical functions to the database
# 
# Many useful statistical functions from R can be added as functions to the database. Again this can be done directly through R by using the open connection. The general format of all the functions involves coercing the arguments to numeric(to be on the safe side if characters are passed) and calculating stats after removing NAs. A float is returned. It is easy to add more to this function if required.
# 
# ```{r}
PgPlr<-function(dbname="brant"){
require(RODBC)
con<-odbcConnect(dbname)  

query<-"CREATE OR REPLACE FUNCTION median (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
median(x,na.rm=TRUE)'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION q10 (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
quantile(x,0.1,na.rm=TRUE)'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION q90 (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
quantile(x,0.9,na.rm=TRUE)'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION q75 (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
quantile(x,0.75,na.rm=TRUE)'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION q25 (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
quantile(x,0.25,na.rm=TRUE)'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION minimum (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
min(x,na.rm=TRUE)'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION maximum (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
max(x,na.rm=TRUE)'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION mean (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
mean(x,na.rm=TRUE)'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION sd (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
sd(x,na.rm=TRUE)'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION se (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
sd(x,na.rm=TRUE)/sqrt(length(x))'
LANGUAGE 'plr' STRICT;

CREATE OR REPLACE FUNCTION length (float[]) RETURNS float AS '
x<-arg1
x<-as.numeric(as.character(x))
x<-na.omit(x)
length(x)'
LANGUAGE 'plr' STRICT;

"
odbcQuery(con,query)
}
# ```
# 
# 
# ## Loading raster layers
# 
# Raster layers uses a few more arguments. The layers are loaded in database (as referenced rasters can't be transfered). The tiles are usually square, but the x and y width can be set.  Arguments are thus
# 
# 1. flnm: name of file
# 2. x: Number of pixels in tile x dimension
# 3. y: Number of pixels in tile y dimension
# 4. tabnm: Name of table to hold data
# 5. db: Database name
# 6. srid: If this is 0 the srid will be taken from the file if it is included. It is usually safer to set this if known.
# 7.  path: Path to file with trailing /
# 
# 
# ```{r}

PgLoadRaster<-function(flnm="cold_bay_3857_clip.tiff",x=10,y=10,tabnm="dem",db="brant",srid=3857,path="/home/rstudio/shiny_morph/"){
flnm<-paste(path,flnm,sep="")  
command <- paste("raster2pgsql -s ",srid, "-I -d  -M  ",flnm, " -F -t ",x,"x",y," ",tabnm,"|psql -h postgis -U docker -d ",db,sep="")
system(command)
}



# 
# ## Loading vector layers
# 
# Vector layers can be loaded directly from the canvas of QQGIS after logging into the database through the dbmanager interface.  However if they are stored on the server this command will load them into the data base from a shapefile. There is no need to specify the .shp extension for the name of the file.
# 
# Arguments are:
# 
# 1. flnm: name of file
# 2. tabnm: Name of table to hold data
# 3. db: Database name
# 4. srid: If this is 0 the srid will be taken from the file if it is included. It is usually safer to set this if known.
# 5.  path: Path to file with trailing /
# 
# 
# ```{r}

PgLoadVector<-function(flnm="tide_regime",tabnm="tide_regime",db="brant",srid=3857,path="/home/rstudio/shiny_morph/"){
flnm<-paste(path,flnm,sep="")  
command <- sprintf("shp2pgsql -s %s -d -I %s  %s |psql -h postgis -U docker -d %s",srid,flnm,tabnm,db)
command
system(command)
}

# 
# 
# 
# ## Setting up graticule from dem
# 
# In the MoRph application patches will be either square or rectangular polygons that are derived from vectorising the raster dem that is first added to the data base. Statistics are calulated from the pixel values of the dem and held as attributes. The function can drop graticules where the minimum value is below a certain level and those with a maximum above a certain level, as this may be useful along coastlines.
# 
# 
# ```{r}


PgMakeGrat<-function(dem="dem",minht=-10,maxht=10,db="brant")
{
  require(RODBC)
  con<-odbcConnect(db)
  
  query<-paste("
drop table if exists grat;
create table grat as
select s.* from
(select rid, st_envelope(rast) geom,
minimum((st_dumpvalues(rast)).valarray) min,
q10((st_dumpvalues(rast)).valarray) q10,
q25((st_dumpvalues(rast)).valarray) q25,
median((st_dumpvalues(rast)).valarray) median,
mean((st_dumpvalues(rast)).valarray) mean,
q75((st_dumpvalues(rast)).valarray) q75,
q90((st_dumpvalues(rast)).valarray) q90,
maximum((st_dumpvalues(rast)).valarray) max
from ",dem,") s
where min>",minht," and max < ",maxht," and min <1000000000000;
CREATE INDEX grat_gix ON grat USING GIST (geom);",sep="")
odbcQuery(con,query)  
}



# 
# ## Getting vector layer from the data base
# 
# ```{r}

PgGetQuery <- function(query="select * from grat",db="brant") {
    require(RODBC)
    require(rgdal)
    con<-odbcConnect(db)
    query <- paste("create view temp_view as ", query, sep = "")
    odbcQuery(con, query)
    dsn<-paste("PG:dbname='",db,"' host='postgis' port=5432 user= 'docker'",sep="")
    result <- readOGR(dsn, "temp_view")
    odbcQuery(con, "drop view temp_view")
    return(result)
}


# 
# ## Adding mean and median from resource layer
# 
# This query works by overlaying the graticule onto any raster layer that has been first uploaded into the data base using PgLoadRaster. A temporary table is formed, then renamed grat and re-indexed. This is a more robust method than adding columns to grat.
# 
# ```{r}

PgAddResource<-function(db="brant",resource="dem")
{
  require(RODBC)
  con<-odbcConnect(db)
  query<-sprintf("create table tmp as
select g.*,
med median_%s,
mn mean_%s
from 
grat g,
(select 
t2.rid,
median((st_dumpvalues(st_union(st_clip(rast,geom)))).valarray) med,
mean((st_dumpvalues(st_union(st_clip(rast,geom)))).valarray) mn
from %s t,
(select * from grat) t2
where st_intersects(rast,geom)
group by t2.rid) s
where s.rid=g.rid;
drop table grat;
ALTER TABLE tmp RENAME TO grat;
CREATE INDEX grat_gix ON grat USING GIST (geom);",resource,resource,resource)
   odbcQuery(con,query)
}



# 
# ## Extracting attribute to grat from vector polygon layer
# 
# The idea behind this function is quite specific to MoRph, but can be adapted. Assuming that there is a polyon layer loaded using PgLoadVector. The example is a layer with codes representing the tide regime in each bay. Some of the graticule patches may possiby overlap the boundary between tide regimes but only one of the values is needed. The function simply chooses (arbitrarily) the minimum value. This is not going to be a problem in most cases as the boundary is also fairly arbitrary.
# 
# ```{r}


PgAddVector<-function(db="brant",l1="grat",l2="tide_regime",col="tide"){
  require(RODBC)
  con<-odbcConnect(db)
  query<-sprintf("
drop table if exists tmp;
create table tmp as
select gg.*,s.%s from
%s gg,
(select g.rid,min(%s) %s from 
grat g,
%s t
where st_intersects(t.geom,g.geom)
group by rid,g.geom) s
where s.rid=gg.rid;
drop table %s;
ALTER TABLE tmp RENAME TO %s;
CREATE INDEX %s_gix ON %s USING GIST (geom);",col,l1,col,col,l2,l1,l1,l1,l1)
  
odbcQuery(con,query)  
}






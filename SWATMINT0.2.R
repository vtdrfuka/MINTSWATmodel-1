if (!require("pacman")) install.packages("pacman")
pacman::p_load(SWATmodel,RSQLite,argparse,stringi,stringr,rgdal,ggplot2,rgeos,rnoaa,moments,sf,readr,tools,diffr)
source("https://raw.githubusercontent.com/Rojakaveh/FillMissWX/main/FillMissWX.R")
source("https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/build_wgn_file.R")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/SWATmodel/R/readSWAT.R?root=ecohydrology")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/EcoHydRology/R/setup_swatcal.R?root=ecohydrology")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/EcoHydRology/R/swat_objective_function_rch.R?root=ecohydrology")
source("https://raw.githubusercontent.com/mintproject/MINTSWATmodel/main/get_grdc_gage.R")
source("https://raw.githubusercontent.com/mintproject/MINTSWATmodel/main/MINTSWATcalib.R")
source("https://raw.githubusercontent.com/mintproject/MINTSWATmodel/main/swat_objective_function_rch.R")
setwd("~")
basedir=getwd()
outbasedir=paste0(basedir,"/MINTSWATmodel_output")
inbasedir=paste0(basedir,"/MINTSWATmodel_input")
dir.create(outbasedir)
dir.create(inbasedir)
setwd(inbasedir)
Sys.setenv(R_USER_CACHE_DIR=inbasedir)
# If a parameter change scenario, we use --swatscen
parser <- ArgumentParser()
parser$add_argument("-p","--swatparam", action="append", metavar="param:val[:regex_file]",
                    help = "Add in SWAT parameters that need to be modified")
parser$add_argument("-s","--swatscen", metavar="calib01",
                    help = "Scenario folder name, 'calib' for calibration, 'scen' for scenario")
parser$add_argument("-d","--swatiniturl", metavar="url to ArcSWAT init or GRDC format dataset",
                    help = "Scenario folder name")

# Examples:
# geojson example 
exampleargs=c("-d https://data.mint.isi.edu/files/files/geojson/guder.json")
# GRDC Calibration example 
exampleargs=c("-s calib01","-p GW_DELAY:12","-p deiter:3","-p rch:3","-d https://bit.ly/grdcdownload_external_331d632e-deba-44c2-9ed8-396d646adb8d_2021-12-03_19-13_zip")
# ArcSWAT example 
#exampleargs=c("-d https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/tb_s2.zip")
#
args <- parser$parse_args()
if(is.null(args$swatiniturl)){
   args <- parser$parse_args(c(exampleargs))
}
print(paste0("This run's args: ",args))
dlfilename=basename(args$swatiniturl)
dlurl=trimws(args$swatiniturl)

paramloc=grep("deiter",args$swatparam)
if(length(paramloc)>0){
  deiter=as.numeric(strsplit(args$swatparam[paramloc],split = ":")[[1]][2])
}else{
  deiter=200
}
paramloc=grep("rch",args$swatparam)
if(length(paramloc)>0){
  rch=as.numeric(strsplit(args$swatparam[paramloc],split = ":")[[1]][2])
}else{
  rch=3
}

# *** download
dlfiletype=file_ext(dlfilename)
if(dlfiletype=="json"){
  print("geojson single run")
  download.file(dlurl,paste0("data.",dlfiletype))
  swatrun="basic"
  } else {
  print("different")
  dlfiletype="zip"
  download.file(dlurl,paste0("data.",dlfiletype))
  if(grepl("Q_Day",unzip("data.zip", list=T)[1])){
     swatrun="GRDC"
  }    
}

if(swatrun=="GRDC"){
  print("GRDC Format Uninitialized")
  dir.create("GRDCstns")
  setwd("GRDCstns")
  currentdir=getwd()
  unzip("../data.zip")
  stationbasins_shp=readOGR("stationbasins.geojson")
#  for(filename in list.files(pattern = "_Q_Day")){
  for(filename in list.files(pattern = "_Q_Day")[2]){
      #    filename=list.files(pattern = "_Q_Day")[2]
    print(filename)    
    setwd(currentdir)
    flowgage=get_grdc_gage(filename)
    basinid=strsplit(filename,"_")[[1]][1]
    if(is.character(flowgage)){next()}
    GRDC_mindate=min(flowgage$flowdata$mdate)
    GRDC_maxdate=max(flowgage$flowdata$mdate)
    # Depends on: rnoaa, lubridate::month,ggplot2
    declat=flowgage$declat
    declon=flowgage$declon
    proj4_utm = paste0("+proj=utm +zone=", trunc((180+declon)/6+1), " +datum=WGS84 +units=m +no_defs")
    print(proj4_utm)
    basin_area=flowgage$area
    if(length(try(which(stationbasins_shp$grdc_no==as.numeric(flowgage$id))))>0){
      basinloc=which(stationbasins_shp$grdc_no==as.numeric(flowgage$id))
      basin=stationbasins_shp[basinloc,]
      basinutm=spTransform(basin,CRS(proj4_utm))
      wxlat=gCentroid(basin)$y
      wxlon=gCentroid(basin)$x
    } else {
      wxlat=declat
      wxlon=declon
    }
    stradius=20;minstns=30
    station_data=ghcnd_stations()
    while(stradius<2000){
      print(paste0("Looking for WX Stations within: ",stradius,"km"))
      junk=meteo_distance(
        station_data=station_data,
        lat=wxlat, long=wxlon,
        units = "deg",
        radius = stradius,
        limit = NULL
      )
      if(length(unique(junk$id))>minstns){break()}
      stradius=stradius*1.2
    }
    basinoutdir=paste0(outbasedir,"/",basinid);dir.create(basinoutdir)
    pdf(file = paste0(basinoutdir,"/","WXSummary.pdf"),width = 6,height = 4)
    WXData=FillMissWX(gCentroid(basin)$y,gCentroid(basin)$x,date_min = "1979-01-01",date_max = "2022-01-01", StnRadius = stradius,method = "IDW",alfa = 2)
    dev.off()
    GRDC_mindate=min(WXData$date)
    GRDC_maxdate=max(WXData$date)
    AllDays=data.frame(date=seq(GRDC_mindate, by = "day", length.out = GRDC_maxdate-GRDC_mindate))
    WXData=merge(AllDays,WXData,all=T)
    
    WXData$PRECIP=WXData$P
    WXData$PRECIP[is.na(WXData$PRECIP)]=-99
    WXData$TMX=WXData$MaxTemp
    WXData$TMX[is.na(WXData$TMX)]=-99
    WXData$TMN=WXData$MinTemp
    WXData$TMN[is.na(WXData$TMN)]=-99
    WXData$DATE=WXData$date
    build_swat_basic(dirname=basinoutdir, iyr=min(year(WXData$DATE),na.rm=T),    ###***basin name!
                     nbyr=(max(year(WXData$DATE),na.rm=T)-min(year(WXData$DATE),na.rm=T)), 
                     wsarea=basin_area, elev=mean(WXData$prcpElevation,na.rm=T), 
                     declat=declat, declon=declon, hist_wx=WXData)
    build_wgn_file(metdata_df=WXData,declat=declat,declon=declon)
    if(!is.null(args$swatscen) && 
       substr(trimws(args$swatscen),1,5)=="calib"){
      MINTSWATcalib()
    }

    runSWAT2012()
    output_rch=readSWAT("rch",".")
    output_plot=merge(output_rch[output_rch$RCH==rch],flowgage$flowdata,by="mdate")
    output_plot=merge(output_plot,WXData,by.x="mdate",by.y="date")
    output_plot$Qpredmm=output_plot$FLOW_OUTcms/(basin_area*10^6)*3600*24*1000
    output_plot$Qmm=output_plot$Qm3ps/(basin_area*10^6)*3600*24*1000
    maxRange <- 1.1*(max(output_plot$P,na.rm = T) + max(output_plot$Qpredmm,na.rm = T))
    p1<- ggplot() +
      # Use geom_tile to create the inverted hyetograph. geom_tile has a bug that displays a warning message for height and width, you can ignore it.
      geom_tile(data = output_plot, aes(x=date,y = -1*(P/2-maxRange), # y = the center point of each bar
                height = P,width = 1),
                fill = "black",
                color = "black") +
      # Plot your discharge data
      geom_line(data=output_plot,aes(x=date, y = Qmm, colour ="Qmm"), size=1) +
      geom_line(data=output_plot,aes(x=date, y = Qpredmm, colour= "Qpred"), size=1) +
      scale_colour_manual("",breaks = c("Qmm", "Qpred"),values = c("red", "blue")) +
      # Create a second axis with sec_axis() and format the labels to display the original precipitation units.
      scale_y_continuous(name = "Discharge (mm/day)",
                         sec.axis = sec_axis(trans = ~-1*(.-maxRange),
                                             name = "Precipitation (mm/day)"))+
      scale_x_continuous(name = NULL,labels = NULL)+
      ggtitle(flowgage$gagename)
    pdf(file = paste0(basinoutdir,"/","HydroSummary.pdf"),width = 6,height = 4)
    p1
    dev.off()
  }
}

if(dlfiletype=="json"){
  basinname=strsplit(basename(args$swatiniturl),split = "\\.")[[1]][1]
  basinoutdir=paste0(outbasedir,"/",basinname);dir.create(basinoutdir)
  basin=readOGR("data.json")
  declat=gCentroid(basin)$y
  declon=gCentroid(basin)$x
  proj4_utm = paste0("+proj=utm +zone=", trunc((180+declon)/6+1), " +datum=WGS84 +units=m +no_defs")
  print(proj4_utm)
  basinutm=spTransform(basin,CRS(proj4_utm))
  basin_area=gArea(basinutm)/10^6
  stradius=20;minstns=30
  station_data=ghcnd_stations()
  while(stradius<2000){
    print(stradius)
    junk=meteo_distance(
      station_data=station_data,
      lat=gCentroid(basin)$y, long=gCentroid(basin)$x,
      units = "deg",
      radius = stradius,
      limit = NULL
    )
    if(length(unique(junk$id))>minstns){break()}
    stradius=stradius*1.2
  }
  pdf(file = paste0(basinoutdir,"/WXSummary.pdf"),width = 6,height = 4)
  WXData=FillMissWX(gCentroid(basin)$y,gCentroid(basin)$x,date_min = "1979-01-01",date_max = "2022-01-01", StnRadius = stradius,method = "IDW",alfa = 2)
  dev.off()
  GRDC_mindate=min(WXData$date)
  GRDC_maxdate=max(WXData$date)
  AllDays=data.frame(date=seq(GRDC_mindate, by = "day", length.out = GRDC_maxdate-GRDC_mindate))
  WXData=merge(AllDays,WXData,all=T)
  
  WXData$PRECIP=WXData$P
  WXData$PRECIP[is.na(WXData$PRECIP)]=-99
  WXData$TMX=WXData$MaxTemp
  WXData$TMX[is.na(WXData$TMX)]=-99
  WXData$TMN=WXData$MinTemp
  WXData$TMN[is.na(WXData$TMN)]=-99
  WXData$DATE=WXData$date
  build_swat_basic(dirname=basinname, iyr=min(year(WXData$DATE),na.rm=T), 
                   nbyr=(max(year(WXData$DATE),na.rm=T)-min(year(WXData$DATE),na.rm=T)), 
                   wsarea=basin_area, elev=mean(WXData$prcpElevation,na.rm=T), 
                   declat=declat, declon=declon, hist_wx=WXData)
  build_wgn_file(metdata_df=WXData,declat=declat,declon=declon)
  runSWAT2012()
  output_rch=readSWAT("rch",".")
  output_plot=merge(output_rch,WXData,by.x="mdate",by.y="date")
  output_plot$Qpredmm=output_plot$FLOW_OUTcms/(basin_area*10^6)*3600*24*1000
  output_plot$Qmm=output_plot$Qm3ps/(basin_area*10^6)*3600*24/10
  
  maxRange <- 1.1*(max(output_plot$P,na.rm = T) + max(output_plot$Qpredmm,na.rm = T))
  
  p1<- ggplot() +
    # Use geom_tile to create the inverted hyetograph. geom_tile has a bug that displays a warning message for height and width, you can ignore it.
    geom_tile(data = output_plot, aes(x=date,y = -1*(P/2-maxRange), # y = the center point of each bar
                                      height = P,width = 1),
              fill = "black",
              color = "black") +
    # Plot your discharge data
    geom_line(data=output_plot,aes(x=date, y = Qpredmm, colour= "Qpred"), size=1) +
    scale_colour_manual("",breaks = c("Qmm", "Qpred"),values = c("red", "blue")) +
    # Create a second axis with sec_axis() and format the labels to display the original precipitation units.
    scale_y_continuous(name = "Discharge (mm/day)",
                       sec.axis = sec_axis(trans = ~-1*(.-maxRange),
                                           name = "Precipitation (mm/day)"))+
    scale_x_continuous(name = NULL,labels = NULL)+
    ggtitle(toupper(basinname))
  pdf(file = paste0(basinoutdir,"/","HydroSummary.pdf"),width = 6,height = 4)
  p1
  dev.off()
  
  # first weather generator function
  
}


quit()

# Good study to compare P/Q S against CN from:
# https://www.nature.com/articles/s41597-019-0155-x Reference dataset
# CN250url="https://figshare.com/ndownloader/files/15377363"
# download.file(CN250url,"GCN250_ARCII.tif")

setwd("./Scenarios/Default/TxtInOut/")
load(paste(path.package("EcoHydRology"), "data/change_params.rda", sep = "/"))

if(!is.null(args$swatscen)){
  junk=NULL
  junknames=c("parameter","current","filetype")
  if(max(stri_count_regex(args$swatparam,pattern=":"))==1){junknames=c("parameter","current")}
  parrep=setDT(junk)[,tstrsplit(args$swatparam,":",names=junknames)]
  calib_params=merge(parrep,change_params,by.x="parameter",by.y="parameter")
  names(calib_params)[names(calib_params) == 'current.x'] <- 'current'
  names(calib_params)[names(calib_params) == 'filetype.x'] <- 'filetype'
  if(length(parrep)==3){
    calib_params$filetype[is.na(calib_params$filetype)]=
      as.character(calib_params$filetype.y[is.na(calib_params$filetype)])
  }
  if("filetype.y" %in% colnames(calib_params)) {
    calib_params = subset(calib_params, select = -c(filetype.y) ) 
  }
  calib_params = subset(calib_params, select = -c(current.y) )
  tmpdir=paste0("../",args$swatscen)
  file.remove(list.files(pattern="output."))
  dir.create(tmpdir)
  file.copy(list.files(),tmpdir)
  setwd(tmpdir)
  setup_swatcal(calib_params)
  alter_files(calib_params)
}

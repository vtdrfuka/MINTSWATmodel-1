if (!require("pacman")) install.packages("pacman")
pacman::p_load(SWATmodel,RSQLite,argparse,stringi,stringr,rgdal,ggplot2,rgeos,rnoaa,moments,sf,readr)
source("https://raw.githubusercontent.com/Rojakaveh/FillMissWX/main/FillMissWX.R")
source("https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/build_wgn_file.R")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/SWATmodel/R/readSWAT.R?root=ecohydrology")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/EcoHydRology/R/setup_swatcal.R?root=ecohydrology")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/EcoHydRology/R/swat_objective_function_rch.R?root=ecohydrology")
source("https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/get_grdc_gage.R")

setwd("~")
dir.create("./MINTSWATmodel_output")
dir.create("./MINTSWATmodel_input")
setwd("./MINTSWATmodel_input")
Sys.setenv(R_USER_CACHE_DIR="./MINTSWATmodel_output")
# If a parameter change scenario, we use --swatscen
parser <- ArgumentParser()
parser$add_argument("-p","--swatparam", action="append", metavar="param:val[:regex_file]",
                    help = "Add in SWAT parameters that need to be modified")
parser$add_argument("-s","--swatscen", metavar="scen1",
                    help = "Scenario folder name")
parser$add_argument("-d","--swatiniturl", metavar="url or tinyurl ext",
                    help = "Scenario folder name")
# Example GeoJSON 15cKb96URjHYDWjiuw75BqyPs25a2UYvu
# https://drive.google.com/file/d/1Bs3OUmSALsPvGCTTg06NFvlPOORbKMZI/view?usp=sharing
gle="1Bs3OUmSALsPvGCTTg06NFvlPOORbKMZI"
msurl=paste0("https://docs.google.com/a/vt.edu/uc?id=",gle,"&export=download")
download.file(msurl,"data.zip")
if(grepl("Q_Day",unzip("data.zip", list=T)[1])){
  print("GRDC")
  dir.create("GRDCstns")
  setwd("GRDCstns")
  unzip("../data.zip")
  stationbasins_shp=readOGR("stationbasins.geojson")
  for(filename in list.files(pattern = "_Q_Day")){
    print(filename)    
    filename=list.files(pattern = "_Q_Day")[2]
    flowgage=get_grdc_gage(filename)
    if(is.character(flowgage)){next()}
    GRDC_mindate=min(flowgage$flowdata$mdate)
    GRDC_maxdate=max(flowgage$flowdata$mdate)
    # Depends on: rnoaa, lubridate::month,ggplot2
    declat=flowgage$declat
    declat=flowgage$declon
    proj4_utm = paste0("+proj=utm +zone=", trunc((180+declon)/6+1), " +datum=WGS84 +units=m +no_defs")
    print(proj4_utm)
#    basinutm=spTransform(basin,CRS(proj4_utm))
    basin_area=flowgage$area
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
    pdf(file = "WXSummary.pdf",width = 6,height = 4)
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
    build_swat_basic(dirname=basinname, iyr=min(year(WXData$DATE),na.rm=T),    ###***basin name!
                     nbyr=(max(year(WXData$DATE),na.rm=T)-min(year(WXData$DATE),na.rm=T)), 
                     wsarea=basin_area, elev=mean(WXData$prcpElevation,na.rm=T), 
                     declat=declat, declon=declon, hist_wx=WXData)
    build_wgn_file(metdata_df=WXData,declat=declat,declon=declon)
    runSWAT2012()
    
    
        
  }
}

for(filename in list.files(pattern = "_Q_Day")){
  #  filename=list.files(pattern = "_Q_Day")[2]
  #  par(mfrow=c(4,2))
  #setwd(basedir)
  flowgage=get_grdc_gage(filename)
  if(is.character(flowgage)){next()}
  GRDC_mindate=min(flowgage$flowdata$mdate)
  GRDC_maxdate=max(flowgage$flowdata$mdate)
  # Depends on: rnoaa, lubridate::month,ggplot2
  WXData=FillMissWX(declat = flowgage$declat,declon = flowgage$declon,StnRadius = 500,date_min=GRDC_mindate,date_max=GRDC_maxdate,method = "IDW",minstns = 3)
  AllDays=data.frame(date=seq(GRDC_mindate, by = "day", length.out = GRDC_maxdate-GRDC_mindate))
  WXData=merge(AllDays,WXData,all=T)
  
  WXData$PRECIP=WXData$P
  WXData$PRECIP[is.na(WXData$PRECIP)]=-99
  WXData$TMX=WXData$MaxTemp
  WXData$TMX[is.na(WXData$TMX)]=-99
  WXData$TMN=WXData$MinTemp
  WXData$TMN[is.na(WXData$TMN)]=-99
  WXData$DATE=WXData$date
  build_swat_basic(dirname= flowgage$id, iyr=min(year(WXData$DATE),na.rm=T), nbyr=(max(year(WXData$DATE),na.rm=T)-min(year(WXData$DATE),na.rm=T) +1), wsarea=flowgage$area, elev=flowgage$elev, declat=flowgage$declat, declon=flowgage$declon, hist_wx=WXData)
  build_wgn_file()
  runSWAT2012()
  output_hru=readSWAT("hru",".")
  output_sub=readSWAT("sub",".")
  output_rch=readSWAT("rch",".")
  test2 = subset(output_rch, output_rch$RCH == 3)
  test2=merge(test2,flowgage$flowdata,by="mdate")
  plot(test2$mdate,test2$FLOW_OUTcms,type="l")
  
  
}  
  save(readSWAT,file="readSWAT.R")
  
  change_params=""
  rm(change_params)
  load(paste(path.package("EcoHydRology"), "data/change_params.rda", sep = "/"))
  calib_range=c("1999-12-31","2021-12-31")
  params_select=c(1,2,3,4,5,6,7,8,9,10,11,14,19,21,23,24,32,33)
  calib_params=change_params[params_select,]
  
  calib_params[grep("Ksat",calib_params[,"parameter"]),c("min","max","current")]=c(.5,1.5,1)
  calib_params[grep("SMFMN",calib_params[,"parameter"]),c("min","max","current")]=c(0,5,2.5)
  calib_params[grep("SMFMX",calib_params[,"parameter"]),c("min","max","current")]=c(0,5,2.5)
  calib_params[grep("CN2",calib_params[,"parameter"]),c("min","max","current")]=c(35,95,70)
  calib_params[grep("Depth",calib_params[,"parameter"]),c("min","max","current")]=c(.5,2,1)
  calib_params[grep("Ave",calib_params[,"parameter"]),c("min","max","current")]=c(.5,2,1)
  calib_params[grep("ALPHA_BF",calib_params[,"parameter"]),c("min","max","current")]=c(.01,1,.8)
  calib_params[grep("GWQMN",calib_params[,"parameter"]),c("min","max","current")]=c(.1,600,1)
  calib_params[grep("GW_REVAP",calib_params[,"parameter"]),c("min","max","current")]=c(0,.3,.02)
  
  setup_swatcal(calib_params)
  rch=3
  
  # Test calibration
  x=calib_params$current
  swat_objective_function_rch(x,calib_range,calib_params,flowgage,rch,save_results=F)
  outDEoptim<-DEoptim(swat_objective_function_rch,calib_params$min,calib_params$max,
                      DEoptim.control(strategy = 6,NP = 16,itermax=200,parallelType = 1,
                                      packages = c("SWATmodel")),calib_range,calib_params,flowgage,rch)
  x=outDEoptim$optim$bestmem  # need to save this, along with an ArcSWAT like directory structure for the basin  
  # mkdir -p Scenarios/Default/TxtInOut
  
  #  dev.copy(png, file = "geyserplot.png")
  #  dev.off()
  #  dev.off()
}





args <- parser$parse_args(c("-d https://data.mint.isi.edu/files/files/geojson/guder.json"))
#args <- parser$parse_args()
print(args)

if(!is.null(args$swatiniturl)){
  args$swatiniturl=str_trim(args$swatiniturl,side = c("both"))
  dlfilename=basename(args$swatiniturl)
  basinname=strsplit(basename(args$swatiniturl),split = "\\.")[[1]][1]
  download.file(args$swatiniturl,dlfilename)
  basin=readOGR(dlfilename)
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
  pdf(file = "WXSummary.pdf",width = 6,height = 4)
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
  
  # first weather generator function
  
}

# https://www.nature.com/articles/s41597-019-0155-x Reference dataset
#CN250url="https://figshare.com/ndownloader/files/15377363"
#download.file(CN250url,"GCN250_ARCII.tif")



urlpath=""
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

runSWAT2012(rch = 1)
output_hru=readSWAT("hru",".")
output_sub=readSWAT("sub",".")
output_rch=readSWAT("rch",".")
test2 = subset(output_rch, output_rch$RCH == 3)
plot(test2$mdate,test2$FLOW_OUTcms,type="l")

setwd("../../../")
sqlitefile=paste0("./MINTSWATmodel_output/",args$swatscen,"MINTSWATtables.sqlite")
con <- dbConnect(RSQLite::SQLite(), sqlitefile)
dbWriteTable(con, "output_hru", output_hru,overwrite = TRUE)
dbWriteTable(con, "output_rch", output_rch,overwrite = TRUE)
dbWriteTable(con, "output_sub", output_sub,overwrite = TRUE)
dbListTables(con)

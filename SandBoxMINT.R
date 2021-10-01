#
# Bugs to address: FillMissWX - stnradius, MINTSWATmodel_output needs to be base project dir 
#
pacman::p_load(moments,sqldf,curl,readr,SWATmodel)
source("https://raw.githubusercontent.com/Rojakaveh/FillMissWX/main/FillMissWX.R")
source("https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/FillMissWX.R")
source("https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/FillMissWX.R")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/SWATmodel/R/readSWAT.R?root=ecohydrology")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/EcoHydRology/R/setup_swatcal.R?root=ecohydrology")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/EcoHydRology/R/swat_objective_function_rch.R?root=ecohydrology")


setwd("~/");dir.create("./MINTSWATmodel_input")
#grdcurl="https://portal.grdc.bafg.de/grdcdownload/external/5b076f5b-c7ec-45b5-99fb-e4f6b45828f8/2021-09-24_13-30.zip"
#
# Go to https://portal.grdc.bafg.de/applications/public.html?publicuser=PublicUser#dataDownload/Subregions
# Get the link to Download a subregion
#
# Or, if interested in searching for a station, grab the station catalog
# https://portal.grdc.bafg.de/applications/public.html?publicuser=PublicUser#dataDownload/StationCatalogue
# 


grdcurl="https://portal.grdc.bafg.de/grdcdownload/external/0fbd1d52-938e-46f9-a6a2-9e1b3c1a1b1b/2021-09-24_16-19.zip"
setwd("./MINTSWATmodel_input")
download.file(grdcurl,"grdc.zip")
unzip("grdc.zip")
basedir=getwd()
setwd(basedir)
for(filename in list.files(pattern = "_Q_Day")){
#  filename=list.files(pattern = "_Q_Day")[2]
#  par(mfrow=c(4,2))
  setwd(basedir)
  flowgage=get_grdc_gage(filename)
  if(is.character(flowgage)){next()}
  GRDC_mindate=min(flowgage$flowdata$mdate)
  GRDC_maxdate=max(flowgage$flowdata$mdate)
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
  
  save(readSWAT,file="readSWAT.R")
  
  change_params=""
  rm(change_params)
  load(paste(path.package("EcoHydRology"), "data/change_params.rda", sep = "/"))
  calib_range=c("1999-12-31","2021-12-31")
  params_select=c(1,2,3,4,5,6,7,8,9,10,11,14,19,21,23,24,32,33)
  calib_params=change_params[params_select,]
  
  calib_params$min[9]=0
  calib_params$min[10]=0
  calib_params$current[9]=2.5
  calib_params$current[10]=2.5
  calib_params$min[11]=0.01
  calib_params$max[11]=1
  calib_params$min[13]=45
  calib_params$max[14]=2
  calib_params$max[15]=2
  calib_params$max[2]=2
  calib_params$max[3]=600
  calib_params$max[4]=0.3
  calib_params$min[2]=0
  calib_params$max[2]=1
  
  calib_params[c(9,10),4]=0
  calib_params[c(9,10),6]=2.5
  calib_params[11,5]=1
  calib_params[11,6]=.5
  calib_params[1:7]
  setup_swatcal(calib_params)
  rch=3
  
  # Test calibration
  x=calib_params$current
  swat_objective_function_rch(x,calib_range,calib_params,flowgage,rch,save_results=F)
  outDEoptim<-DEoptim(swat_objective_function_rch,calib_params$min,calib_params$max,
                      DEoptim.control(strategy = 6,NP = 16,itermax=200,parallelType = 1,
                                      packages = c("SWATmodel")),calib_range,calib_params,flowgage,rch)
  
  
#  dev.copy(png, file = "geyserplot.png")
#  dev.off()
#  dev.off()
}

#
# Beginning of the functions for capturing stats for weather generator




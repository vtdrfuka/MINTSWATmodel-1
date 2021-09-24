#
# Bugs to address: FillMissWX - stnradius, MINTSWATmodel_output needs to be base project dir 
#
pacman::p_load(moments,sqldf,curl,readr,SWATmodel)
source("https://raw.githubusercontent.com/Rojakaveh/FillMissWX/main/FillMissWX.R")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/SWATmodel/R/readSWAT.R?root=ecohydrology")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/EcoHydRology/R/setup_swatcal.R?root=ecohydrology")
source("https://r-forge.r-project.org/scm/viewvc.php/*checkout*/pkg/EcoHydRology/R/swat_objective_function_rch.R?root=ecohydrology")


setwd("~/");dir.create("./MINTSWATmodel_input")
#grdcurl="https://portal.grdc.bafg.de/grdcdownload/external/5b076f5b-c7ec-45b5-99fb-e4f6b45828f8/2021-09-24_13-30.zip"
grdcurl="https://portal.grdc.bafg.de/grdcdownload/external/0fbd1d52-938e-46f9-a6a2-9e1b3c1a1b1b/2021-09-24_16-19.zip"
setwd("./MINTSWATmodel_input")
download.file(grdcurl,"grdc.zip")
unzip("grdc.zip")
basedir=getwd()
setwd(basedir)
for(filename in list.files(pattern = "_Q_Day")){
#  par(mfrow=c(4,2))
  setwd(basedir)
  flowgage=get_grdc_gage(filename)
  if(is.character(flowgage)){next()}
  GRDC_mindate=min(flowgage$flowdata$mdate)
  GRDC_maxdate=max(flowgage$flowdata$mdate)
  WXData=FillMissWX(declat = flowgage$declat,declon = flowgage$declon,StnRadius = 500,date_min=GRDC_mindate,date_max=GRDC_maxdate,method = "IDW",minstns = 3)
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



#### Functions
get_grdc_gage=function(filename=filename){  
  # A function to make a data object similar to EcoHydrology::get_usgs_gage  
  #filename="1577050_Q_Day.Cmd.txt"
  print(filename)
  nskipline = grep("YYYY-MM-DD", readLines(filename))[2]-1
  gaugeno <- strsplit(filename, '[.]')[[1]][1]
  gaugetab <- cbind(fread(filename, header = T, skip = nskipline, sep=";",colClasses = c('character', 'character', 'numeric')), GRDC_Info = gaugeno)%>%
    setnames('YYYY-MM-DD', 'dates') %>%
    setorder(GRDC_Info, dates)
  gaugetab$dates=as.Date(gaugetab$dates)
  if(length(gaugetab$dates)<100){return("not enough data")}
  # GRDC-No.:              1577050"     
  nskipline = grep("GRDC-No", readLines(filename))[1]-1
  GRDC_No=as.numeric(strsplit(read_lines(filename,n_max = 1,skip=nskipline),":")[[1]][2])
  # River:                 HOLETA SHET'"                                                                          
  nskipline = grep("River:", readLines(filename))[1]-1
  GRDC_River=str_trim(as.character(strsplit(read_lines(filename,n_max = 1,skip=nskipline),":")[[1]][2]))
  # Station:               NEAR HOLETTA"                                                                          
  nskipline = grep("Station:", readLines(filename))[1]-1
  GRDC_Station=str_trim(as.character(strsplit(read_lines(filename,n_max = 1,skip=nskipline),":")[[1]][2]))
  # Country:               ET"                                                                                    
  nskipline = grep("Country:", readLines(filename))[1]-1
  GRDC_Country=str_trim(as.character(strsplit(read_lines(filename,n_max = 1,skip=nskipline),":")[[1]][2]))
  # Latitude (DD):       9.08"                                                                                    
  nskipline = grep("Latitude", readLines(filename))[1]-1
  GRDC_Latitude=as.numeric(strsplit(read_lines(filename,n_max = 1,skip=nskipline),":")[[1]][2])
  # Longitude (DD):      38.52"                                                                                   
  nskipline = grep("Longitude", readLines(filename))[1]-1
  GRDC_Longitude=as.numeric(strsplit(read_lines(filename,n_max = 1,skip=nskipline),":")[[1]][2])
  # Catchment area (km\xb2):      119.0"                                                                          
  nskipline = grep("Catchment", gsub("\xb2","",readLines(filename)))[1]-1
  GRDC_Catchment_area=as.numeric(strsplit(read_lines(filename,n_max = 1,skip=nskipline),":")[[1]][2])
  # Altitude (m ASL):        1860.0"                                                                              
  nskipline = grep("Altitude", readLines(filename))[1]-1
  GRDC_Altitude=as.numeric(strsplit(read_lines(filename,n_max = 1,skip=nskipline),":")[[1]][2])
  # Next downstream station:      1577600"           
  nskipline = grep("Next downstream station:", readLines(filename))[1]-1
  GRDC_Next_downstream_station=as.numeric(strsplit(read_lines(filename,n_max = 1,skip=nskipline),":")[[1]][2])
  
  gaugetab=gaugetab[!(Value %in% c(-999, -99, -9999, 99, 999, 9999))]
  
  plot(gaugetab$dates,gaugetab$Value,main=filename)
  GRDC_mindate=min(gaugetab$dates)
  GRDC_maxdate=max(gaugetab$dates)
  
  flowgage_id="04216500"
  flowgage=get_usgs_gage(flowgage_id) # Just grabbing a station as a template
  flowgage$id=as.character(GRDC_No)
  flowgage$declat=GRDC_Latitude
  flowgage$declon=GRDC_Longitude
  flowgage$elev=GRDC_Altitude
  flowgage$area=GRDC_Catchment_area
  flowgage$gagename=GRDC_Station
  flowgage$River=GRDC_River
  
  # Building flowdata df in flowgage object to match EcoHydrology::get_usgs_gage
  flowgage$flowdata=gaugetab
  flowgage$flowdata$agency="GRDC"
  flowgage$flowdata$site_no=GRDC_No
  flowgage$flowdata$date=flowgage$flowdata$dates
  flowgage$flowdata$mdate=flowgage$flowdata$dates
  flowgage$flowdata$flow=flowgage$flowdata$Value*3600*24   #flow is in cubic meters per day
  return(flowgage)
}

build_wgn_file=function(metdata_df=WXData,declat=flowgage$declat,declon=flowgage$declon){
  wgdata=data.frame(matrix(nrow = 14,ncol = 12),row.names = c("tmpmx","tmpmn","tmpstdmx","tmpstdmn","pcpmm","pcpstd","pcpskw","pr_wd","pr_ww","pcpd","rainhhmx","solarav","dewpt","wndav"))
  colnames(wgdata)<-unique(months(metdata_df$date))
  metdata_df$Ppost  <- append(metdata_df$P, 0, 0)[-nrow(metdata_df)]
  metdata_df$wnd=4
  years=length(unique(year(metdata_df$date)))
  
  
  metdata_df$MaxTemp[is.na(metdata_df$MaxTemp)]=metdata_df$MinTemp[is.na(metdata_df$MaxTemp)] +1
  metdata_df$MinTemp[is.na(metdata_df$MinTemp)]=metdata_df$MaxTemp[is.na(metdata_df$MinTemp)] -1
  cleanup=(metdata_df$MaxTemp<metdata_df$MinTemp)
  cleanup[is.na(cleanup)]=FALSE
  metdata_df$MaxTemp[cleanup]=metdata_df$MinTemp[cleanup]+1
  metdata_df$dewpt=metdata_df$MinTemp
  metdata_df$Solar=NA
  metdata_df$Solar[!is.na(metdata_df$MaxTemp)]=Solar(lat=44.47/180*pi,
                                                     Jday=julian(metdata_df$date[!is.na(metdata_df$MaxTemp)],
                                                                 origin=as.Date("2000-01-01")),
                                                     Tx=metdata_df$MaxTemp[!is.na(metdata_df$MaxTemp)],
                                                     Tn=metdata_df$MinTemp[!is.na(metdata_df$MaxTemp)])/1000
  for (i in unique(months(metdata_df$date))){
    wgdata["tmpmx",i]=mean(metdata_df$MaxTemp[months(metdata_df$date)==i],na.rm=T)
    wgdata["tmpmn",i]=mean(metdata_df$MinTemp[months(metdata_df$date)==i],na.rm=T)
    wgdata["tmpstdmx",i]=sd(metdata_df$MaxTemp[months(metdata_df$date)==i],na.rm=T)
    wgdata["tmpstdmn",i]=sd(metdata_df$MinTemp[months(metdata_df$date)==i],na.rm=T)
    wgdata["pcpmm",i]=mean(metdata_df$P[months(metdata_df$date)==i]*30,na.rm=T)
    wgdata["pcpstd",i]=sd(metdata_df$P[months(metdata_df$date)==i],na.rm=T)
    wgdata["pcpskw",i]=skewness(metdata_df$P[months(metdata_df$date)==i],na.rm=T)
    wgdata["pr_wd",i]=length(metdata_df$P[months(metdata_df$date)==i &
                                            metdata_df$P<1 & metdata_df$Ppost >
                                            1])/length((metdata_df$P[months(metdata_df$date)==i ]))
    wgdata["pr_ww",i]=length(metdata_df$P[months(metdata_df$date)==i &
                                            metdata_df$P>1 & metdata_df$Ppost >
                                            1])/length((metdata_df$P[months(metdata_df$date)==i]))
    wgdata["pcpd",i]=length(metdata_df$P[months(metdata_df$date)==i &
                                           metdata_df$P>1])/years
    wgdata["rainhhmx",i]=max(metdata_df$P[months(metdata_df$date)==i],na.rm=T)/4
    wgdata["solarav",i]=mean(metdata_df$Solar[months(metdata_df$date)==i],na.rm=T)
    wgdata["dewpt",i]=mean(metdata_df$dewpt[months(metdata_df$date)==i],na.rm=T)
    wgdata["wndav",i]=mean(metdata_df$wnd[months(metdata_df$date)==i],na.rm=T)
  }
  #outfile=paste(args[4],"/wgn.df",sep="")
  #write.table(wgdata,file=outfile)
  header=paste0("This line is not used\n  LATITUDE =",sprintf("%7.2f",declat)," LONGITUDE =",sprintf("%7.2f",declon),"
  ELEV [m] =",sprintf("%7.2f",mean(WXData$prcpElevation,na.rm=T)),"
  RAIN_YRS =  10.00
")
  outfile=paste("000010000.wgn",sep="")
  cat(header,file=outfile)
  for (i in seq(1:14)){
    if(i!=5){cat(sprintf("%6.2f",wgdata[i,]),file=outfile,append=T,sep="")
    }else{
      cat(sprintf("%6.1f",wgdata[i,]),file=outfile,append=T,sep="")
    }
    cat("\n",file=outfile,append=T,sep="")
  }
  for (filename in list.files(pattern = "wgn")){
    try(file.copy("000010000.wgn",filename,overwrite = T),silent=T)
  }
  
}

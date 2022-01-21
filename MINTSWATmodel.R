#rm -rf mintswat
#mkdir mintswat
#curl https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/MINTSWATmodel.R > mintswat/MINTSWATmodel.R
#curl https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/tb_s2.zip > mintswat/tb_s2.zip
#cd mintswat/
#unzip tb_s2.zip
#cd ../
#docker run -dt -v ~/docker/MINTSWATmodel/mintswat/:/mintswat --name mint_swat mintswatmodel
#docker exec -it mint_swat Rscript MINTSWATmodel.R 
## To run with parameter changes
#docker exec -it mint_swat Rscript MINTSWATmodel.R -p GW_DELAY:12 -p CN2:75:00\*.mgt -s test1
## And the help without run
#docker exec -it mint_swat Rscript MINTSWATmodel.R --help
pacman::p_load(SWATmodel,RSQLite,argparse,stringi,stringr,rgdal,ggplot2,rgeos)
dir.create("./MINTSWATmodel_output")
dir.create("./MINTSWATmodel_input")
setwd("./Scenarios/Default/TxtInOut/")
load(paste(path.package("EcoHydRology"), "data/change_params.rda", sep = "/"))
source("https://raw.githubusercontent.com/Rojakaveh/FillMissWX/main/FillMissWX.R")
# If a parameter change scenario, we use --swatscen
parser <- ArgumentParser()
parser$add_argument("-p","--swatparam", action="append", metavar="param:val[:regex_file]",
    help = "Add in SWAT parameters that need to be modified")
parser$add_argument("-s","--swatscen", metavar="scen1",
    help = "Scenario folder name")
parser$add_argument("-u","--url", metavar="dataurl",
    help = "The URL for generalized base data to be used")
parser$add_argument("-d","--swatiniturl", metavar="url or tinyurl ext",
                    help = "Scenario folder name")
args <- parser$parse_args()
args <- parser$parse_args(c("-d https://data.mint.isi.edu/files/files/geojson/guder.json"))
print(args)

if(!is.null(args$swatiniturl)){
  args$swatiniturl=str_trim(args$swatiniturl,side = c("both"))
  dlfilename=basename(args$swatiniturl)
  basinname=strsplit(basename(args$swatiniturl),split = "\\.")[[1]][1]
  download.file(args$swatiniturl,dlfilename)
  basin=readOGR(dlfilename)
  proj4_utm = paste0("+proj=utm +zone=", trunc((180+gCentroid(basin)$x)/6+1), " +datum=WGS84 +units=m +no_defs")
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
  pdf()
  WXData=FillMissWX(gCentroid(basin)$y,gCentroid(basin)$x,date_min = "1979-01-01",date_max = "2022-01-01", StnRadius = stradius,method = "IDW",alfa = 2)
  dev.off()
  # first weather generator function
  WXData$P[is.na(WXData$P)]=-99.0
  WXData$MaxTemp[is.na(WXData$MaxTemp)]=-99.0
  WXData$MinTemp[is.na(WXData$MinTemp)]=-99.0
}

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
setwd("../../../")
sqlitefile=paste0("./MINTSWATmodel_output/",args$swatscen,"MINTSWATtables.sqlite")
con <- dbConnect(RSQLite::SQLite(), sqlitefile)
dbWriteTable(con, "output_hru", output_hru,overwrite = TRUE)
dbWriteTable(con, "output_rch", output_rch,overwrite = TRUE)
dbWriteTable(con, "output_sub", output_sub,overwrite = TRUE)
dbListTables(con)

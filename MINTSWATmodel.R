pacman::p_load(SWATmodel,RSQLite,argparse,stringi)
dir.create("./MINTSWATmodel_output")
setwd("./Scenarios/Default/TxtInOut/")
load(paste(path.package("EcoHydRology"), "data/change_params.rda", sep = "/"))
# If a parameter change scenario, we use --swatscen
parser <- ArgumentParser()
parser$add_argument("-p","--swatparam", action="append", metavar="param:val[:regex_file]",
    help = "Add in SWAT parameters that need to be modified")
parser$add_argument("-s","--swatscen", metavar="scen1",
    help = "Scenario folder name")
args <- parser$parse_args()
print(args$swatscen)
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

runSWAT2012()
output_hru=readSWAT("hru",".")
output_sub=readSWAT("sub",".")
output_rch=readSWAT("rch",".")
setwd("../../../")
sqlitefile=paste0("./MINTSWATmodel_output/",args$swatscen,"MINTSWATtables.sqlite")
con <- dbConnect(RSQLite::SQLite(), sqlitefile)
dbWriteTable(con, "output_hru", output_hru)
dbWriteTable(con, "output_rch", output_rch)
dbWriteTable(con, "output_sub", output_sub)
dbListTables(con)

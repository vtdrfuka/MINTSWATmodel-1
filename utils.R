swatsqlite=function(){
 output_hru=readSWAT("hru",".")
 output_sub=readSWAT("sub",".")
 output_rch=readSWAT("rch",".")
 sqlitefile=paste0("./",args$swatscen,"MINTSWATtables.sqlite")
 con <- dbConnect(RSQLite::SQLite(), sqlitefile)
 dbWriteTable(con, "output_hru", output_hru,overwrite = TRUE)
 dbWriteTable(con, "output_rch", output_rch,overwrite = TRUE)
 dbWriteTable(con, "output_sub", output_sub,overwrite = TRUE)
 dbListTables(con)
}
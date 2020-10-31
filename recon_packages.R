# db_con <- connect2DB()
# recon_packages <- read.csv('data/recon_packages.csv', stringsAsFactors = F)
# recon_packages$approved_by <- 'benjaminortizulloa'
# RPostgres::dbRemoveTable(db_con, "recon_package")
# RPostgres::dbListTables(db_con)
# RPostgres::dbWriteTable(db_con, 'recon_package', recon_packages)
# RPostgres::dbGetQuery(db_con, 'alter table recon_package add id serial;')
# RPostgres::dbGetQuery(db_con, "alter table recon_package add created_on timestamp default current_timestamp")
# RPostgres::dbGetQuery(db_con, "alter table recon_package add last_update timestamp default current_timestamp")
# RPostgres::dbDisconnect(db_con)

recon_packages <- function(pkg = NA){
  db_con <- connect2DB()
  
  if(is.na(pkg)){
    qry <- paste0("SELECT * FROM recon_package")
  } else {
    info <- unlist(stringr::str_split(pkg, '/'))
    qry <- paste0("SELECT * FROM recon_package WHERE org = '", info[1], "' AND repo = '", info[2], "'")
  }
  
  dta <- RPostgres::dbGetQuery(db_con, qry)
  dta <- dplyr::arrange(dta, repo)
  
  RPostgres::dbDisconnect(db_con)
  
  return(dta)
}

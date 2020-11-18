# #https://gist.github.com/hrbrmstr/45c67103a9728f59212cd13262adca74
# 
# db_con <- connect2DB()
# RPostgres::dbRemoveTable(db_con, "admin")
# admin <- tibble::tibble(username = 'benjaminortizulloa', type = 'admin', approver="benjaminortizulloa")
# RPostgres::dbListTables(db_con)
# RPostgres::dbWriteTable(db_con, 'admin', admin)
# RPostgres::dbGetQuery(db_con, 'alter table admin add id serial;')
# RPostgres::dbGetQuery(db_con, "alter table admin add created_on timestamp default current_timestamp")
# RPostgres::dbGetQuery(db_con, "alter table admin add last_update timestamp default current_timestamp")
# RPostgres::dbReadTable(db_con, 'admin')
#
#DELETE FROM tasks WHERE status = 'DONE' RETURNING *;
# 
# test <- addAuthorization('', 'benjaminortizulloa', 'beemyfriend', 'admin')
# test2 <- editAuthorization('', 'benjaminortizulloa', 'beemyfriend', 'reviewer')
# test3 <- getAuthorization('beemyfriend')
# test4 <- getAuthorization()

pullAuthorization <- function(db_con, user){
  qry <- paste0(
    "SELECT * FROM admin WHERE username = '",
    user,
    "'"
  )
  
  info <- RPostgres::dbGetQuery(db_con, qry)
  return(info)
}

autoFillUser <- function(db_con,token, admin, user){
  if(nrow(pullAuthorization(db_con, user))){
    return(FALSE)
  } 
  confirm <- addAuthorization(token, admin, user, 'user')
  # print(confirm)
  return(TRUE)
}

#Need admin rights to main project
#will use personal for now
addGitCollab <- function(token, username, type){
  permission <- "push"
  
  if(type == 'admin' | type == "reviewer"){
    permission <- "admin"
  }
  
  ## 'maintain' only works for organization owned repos
  # if(type =="reviewer"){
  #   permission <- "maintain"
  # }
  
  bdy <- jsonlite::toJSON(list(permission = permission), auto_unbox = T)
  # print(bdy)
  
  url = paste0("https://api.github.com/repos/", "reconhub", "/", "tasks", "/collaborators/", username)
  # print(url)
  
  tkn = paste('token', token)

  config <- httr::add_headers(Authorization = tkn, Accept = "application/vnd.github.v3+json")
  # print(config)
  
  postres <- httr::PUT(url,
                       config = config,
                       body = bdy)
  
  # print(postres)
  # print(httr::content(postres))
  httr::content(postres)
}

removeGitCollab <- function(token, username){
  url = paste0("https://api.github.com/repos/", "reconhub", "/", "tasks", "/collaborators/", username)
  # print(url)
  
  tkn = paste('token', token)
  config <- httr::add_headers(Authorization = tkn, Accept = "application/vnd.github.v3+json")
  
  postres <- httr::DELETE(url, config = config)

  # print(postres)
  # print(httr::content(postres))
  httr::content(postres)
}

authAPI <- function(req, res){
  if(req$REQUEST_METHOD == 'OPTIONS'){
    return( 'Successful OPTIONS')
  }
  
  if(!nchar(req$HTTP_AUTHORIZATION)){
    res$status <- 401 # Unauthorized
    return(list(error="Authentication required [Must have valid JWT]"))
  }
  
  . <- req$args
  decoded <- readJWT(req$HTTP_AUTHORIZATION)
  
  if(req$REQUEST_METHOD == 'POST'){
    return( addAuthorization(decoded$gitToken, decoded$login, .$login, .$type))
  }
  
  if(req$REQUEST_METHOD == 'PUT'){
    return( editAuthorization(decoded$gitToken, decoded$login, .$login, .$type))
  }
  
  if(req$REQUEST_METHOD == 'GET'){
    return( getAuthorization("", decoded$gitToken))
  }
  
}

# reviewer can approve issues and assign issues
# admin same as reviewer but can add new reviewer admin
# user is default...push priveledges
addAuthorization <- function(token, user, login, type){
  
  db_con <- connect2DB()
  is_recorded <- nrow(pullAuthorization(db_con, login))
  
  if(is_recorded != 0){
    RPostgres::dbDisconnect(db_con)
    return("User already exists.")
  }
  
  qry <- paste0(
    "INSERT INTO admin(username, type, approver) ",
    "VALUES ('", 
    paste(stringr::str_replace_all(c(login, type, user), "'", "''"),  collapse = "', '"),
    "') RETURNING *;"
  )
  
  info <- RPostgres::dbGetQuery(db_con, qry)
  RPostgres::dbDisconnect(db_con)
  
  addGitCollab(token, login, type)
  
  return("User successfully added.")
}

editAuthorization <- function(token, user, login, type){
  
  qry <- paste0(
    "UPDATE admin ",
    "SET type = '", type,"', ",
    "approver = '", user, "', ",
    "last_update = current_timestamp ",
    "WHERE username = '", login, "' RETURNING *;"
  )
  
  db_con <- connect2DB()
  info <- RPostgres::dbGetQuery(db_con, qry)
  RPostgres::dbDisconnect(db_con)
  
  if(type == 'nothing'){
    removeGitCollab(token, login)
  } else {
    addGitCollab(token, login, type)
  }
  
  return(info)
}

getAuthorization <- function(user = "", token){
  db_con <- connect2DB()
  
  if(user == "" ){
    info <- RPostgres::dbReadTable(db_con, 'admin')
    RPostgres::dbDisconnect(db_con)
    return(info)
  }
  
  info <- pullAuthorization(db_con, user)
  RPostgres::dbDisconnect(db_con)
  
  if(nrow(info) <= 0){
    auth <- list(user=user, type = "user")
  } else {
    auth <- list(user = user ,type = info$type[1])
  }
  
  jwt <- createJWT(auth$user, auth$type, token)
  auth$jwt <- jwt
  
  return(auth)
}


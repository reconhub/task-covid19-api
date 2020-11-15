# following <- tibble::tibble(
#   issue_id = integer(0),
#   username = character(0),
#   status = logical(0)
# )
# db_con <- connect2DB()
# RPostgres::dbRemoveTable(db_con, "following")
# RPostgres::dbListTables(db_con)
# RPostgres::dbWriteTable(db_con, 'following', following)
# RPostgres::dbGetQuery(db_con, 'alter table following ADD CONSTRAINT one_per UNIQUE (issue_id, username);')
# RPostgres::dbGetQuery(db_con, 'alter table following add id serial;')
# RPostgres::dbGetQuery(db_con, "alter table following add created_on timestamp default current_timestamp")
# RPostgres::dbGetQuery(db_con, "alter table following add last_update timestamp default current_timestamp")
# RPostgres::dbReadTable(db_con, 'following')
# RPostgres::dbDisconnect(db_con)


parseIssues <- function(dta) {
  tasks <- lapply(dta, function(x){
    title <- x$title
    id <- x$id
    labs <- vapply(x$labels, `[[`, character(1), 'name')

    priority <- labs[grepl('^Priority_', labs)]
    priority <- ifelse(length(priority), gsub('_', ' ', priority), "No Priority Assigned")
    
    complexity <- labs[grepl('^Complexity_', labs)]
    complexity <- ifelse(length(complexity), gsub('_', ' ', complexity), "No Complexity Assigned")
    
    otherTags <- labs[!grepl('^Complexity_|^Priority_', labs)]
    otherTags <- ifelse(length(otherTags), paste(otherTags, collapse = ' | '), '')

    description <- x$body
    url <- x$html_url
    
    return(
      tibble::tibble(
        title = title,
        id = id,
        priority = priority,
        complexity = complexity,
        description = description,
        url = url,
        otherTags = otherTags
      )
    )
  })
  
  dplyr::bind_rows(tasks)
}
  

indiviualizedTasks <- function(req){
  if(req$REQUEST_METHOD == 'OPTIONS'){
    return( 'Successful OPTIONS')
  }
  
  if(!nchar(req$HTTP_AUTHORIZATION)){
    res$status <- 401 # Unauthorized
    return(list(error="Authentication required [Must have valid JWT]"))
  }
  
  decoded <- readJWT(req$HTTP_AUTHORIZATION)
  
  return(serveTasks(decoded$login))
}

serveTasks <- function(user=NA){
  db_con <- connect2DB()
  
  res <- httr::GET('https://api.github.com/repos/reconhub/tasks/issues')
  cnt <- httr::content(res)
  
  if(length(cnt) > 0){
    tasks <- parseIssues(cnt)
    rank_score <- RPostgres::dbGetQuery(db_con, "SELECT issue_id, score FROM rank_score")
    tasks <- dplyr::left_join(tasks, rank_score, by = c('id' = 'issue_id'))
    tasks <- dplyr::mutate(tasks, perc_score = round(score/max(score) * 100))
    tasks <- dplyr::arrange(tasks, desc(score))
    
    if(!is.na(user)){
      qry_follow <- paste0(
        "SELECT issue_id, status FROM following WHERE username = '",
        user,
        "'"
      )
      
      qry_vote <- paste0(
        "SELECT issue_id, vote FROM votes WHERE username = '",
        user, 
        "'"
      )
      
      following <- RPostgres::dbGetQuery(db_con, qry_follow)
      votes <- RPostgres::dbGetQuery(db_con, qry_vote)
      
      tasks <- dplyr::left_join(tasks, following, by = c('id' = 'issue_id'))
      tasks <- dplyr::left_join(tasks, votes, by = c("id" = "issue_id"))
  
      tasks <- dplyr::mutate(
        tasks, 
        status = replace(status, is.na(status), F),
        vote = replace(vote, is.na(vote), F)
      )
    }
    
    RPostgres::dbDisconnect(db_con)
    
    return(tasks)
  }
  
  return(list())
}
  
#last_update isn't updating...
followTasks <- function(issue_id, user, status){
  db_con <- connect2DB()
  
  qry <- paste0(
    "INSERT INTO following(issue_id, username, status) ",
    "VALUES ('", 
    paste(c(issue_id, user, status),  collapse = "', '"),
    "') ",
    "ON CONFLICT (issue_id, username) DO UPDATE ",
    "SET status = '", status, "' ",
    "RETURNING *;"
  )
  
  following <- RPostgres::dbGetQuery(db_con, qry)
  RPostgres::dbDisconnect(db_con)
  return(following)
}
# res <- httr::GET('https://api.github.com/repos/BenjaminOrtizUlloa/ExploreGitAPI/issues')
# cnt <- httr::content(res)
# tasks <- parseIssues(cnt)
# 
# #base_scores in utils
# rank_score <- tibble::tibble(
#   issue_id = tasks$id,
#   score = vapply(tasks$priority, function(x) base_scores[[x]], double(1))
# )
# rank_score <- tibble::tibble(
#   issue_id = integer(0),
#   score = integer(0)
# )
#  
# db_con <- connect2DB()
# RPostgres::dbRemoveTable(db_con, "rank_score")
# RPostgres::dbListTables(db_con)
# RPostgres::dbWriteTable(db_con, 'rank_score', rank_score)
# RPostgres::dbGetQuery(db_con, 'alter table rank_score ADD CONSTRAINT one_per_rank UNIQUE (issue_id);')
# RPostgres::dbGetQuery(db_con, 'alter table rank_score add id serial;')
# RPostgres::dbGetQuery(db_con, "alter table rank_score add created_on timestamp default current_timestamp")
# RPostgres::dbGetQuery(db_con, "alter table rank_score add last_update timestamp default current_timestamp")
# RPostgres::dbReadTable(db_con, 'rank_score')


# -5 downvote
# 0 no vote
# +5 vote
# votes <- tibble::tibble(
#   issue_id = integer(0),
#   username = character(0),
#   vote = integer(0)
# )
# 
# db_con <- connect2DB()
# RPostgres::dbRemoveTable(db_con, "votes")
# RPostgres::dbListTables(db_con)
# RPostgres::dbWriteTable(db_con, 'votes', votes)
# RPostgres::dbGetQuery(db_con, 'alter table votes ADD CONSTRAINT one_per_vote UNIQUE (issue_id, username);')
# RPostgres::dbGetQuery(db_con, 'alter table votes add id serial;')
# RPostgres::dbGetQuery(db_con, "alter table votes add created_on timestamp default current_timestamp")
# RPostgres::dbGetQuery(db_con, "alter table votes add last_update timestamp default current_timestamp")
# voteTasks(699365250, 'test', 'up')
# voteTasks(699365250, 'test', 'none')
# voteTasks(699365250, 'test2', 'fail')
# RPostgres::dbReadTable(db_con, 'votes')

score_card = c(
  'up' = 5,
  'down' = -5,
  'none' = 0
)

updateVoteTable <- function(issue_id, username, vote){
  if(!vote %in% names(score_card)) return('Please choose appropriate vote')
  
  qry <- paste0(
    "INSERT INTO votes(issue_id, username, vote) ",
    "VALUES ('", 
    paste(c(issue_id, username, score_card[[vote]]),  collapse = "', '"),
    "') ",
    "ON CONFLICT (issue_id, username) DO UPDATE ",
    "SET vote = ", score_card[[vote]], ", last_update = current_timestamp ",
    "RETURNING *;"
  )
  
  db_con <- connect2DB()
  votes <- RPostgres::dbGetQuery(db_con, qry)
  RPostgres::dbDisconnect(db_con)
  return(votes)
}

setRankScore <- function(issue_id, priority){
  db_con <- connect2DB()
  
  qry <- paste0(
    "INSERT INTO rank_score(issue_id, score) ",
    "VALUES ('", 
    paste(stringr::str_replace_all(c(issue_id, base_scores[[priority]]), "'", "''"),  collapse = "', '"),
    "') RETURNING *;")
    
  res <- RPostgres::dbGetQuery(db_con, qry)
  RPostgres::dbDisconnect(db_con)
  return(res)
}

changeRankScore <- function(issue_id, delta){
  db_con <- connect2DB()
  
  qry_score <- paste0(
    "SELECT * FROM rank_score WHERE issue_id = ",
    issue_id
  )
  
  score <- RPostgres::dbGetQuery(db_con, qry_score)$score
  score <- score + delta
  score <- ifelse(score < 0, 0, score)
  
  qry <- paste0(
    "UPDATE rank_score ",
    "SET score = ",
    score,
    ", last_update = current_timestamp WHERE issue_id = ",
    issue_id,
    " RETURNING *;"
  )
  
  updated_issue <- RPostgres::dbGetQuery(db_con, qry)
  RPostgres::dbDisconnect(db_con)
  return(updated_issue)
}

voteTasks <- function(req, res){
  if(req$REQUEST_METHOD == 'OPTIONS'){
    return( 'Successful OPTIONS')
  }
  
  if(!nchar(req$HTTP_AUTHORIZATION)){
    res$status <- 401 # Unauthorized
    return(list(error="Authentication required [Must have valid JWT]"))
  }
  
  . <- req$args
  decoded <- readJWT(req$HTTP_AUTHORIZATION)
  
  if(!.$vote %in% names(score_card)) return('Please choose appropriate vote')
  
  qry_orig <- paste0(
    "SELECT * FROM votes WHERE issue_id = ",
    .$issue_id,
    " AND username = '",
    decoded$login, 
    "'"
  )
  
  db_con <- connect2DB()
  originalScore <- RPostgres::dbGetQuery(db_con, qry_orig)$vote
  originalScore <- ifelse(length(originalScore), originalScore, 0)
  
  newVote <- updateVoteTable(.$issue_id, decoded$login, .$vote)
  
  #necessary if thumbs up to thumbs down delta will be |10| not |5|
  delta <- newVote$vote - originalScore
  
  newRank <- changeRankScore(.$issue_id, delta)
  
  qry_max_score <- paste0(
    "SELECT score FROM rank_score ",
    "WHERE score = (SELECT MAX (score) FROM rank_score);"
  )
  
  maxScore <- RPostgres::dbGetQuery(db_con, qry_max_score)$score[1]

  RPostgres::dbDisconnect(db_con)
  return(list(newRank = newRank, newVote = newVote, maxScore = maxScore))
}
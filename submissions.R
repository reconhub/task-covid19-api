# submissions <- tibble::tibble(
#   title = character(0),
#   author = character(0),
#   token = character(0),
#   body = character(0),
#   impact = character(0),
#   timeline = character(0),
#   priority = character(0),
#   complexity = character(0),
#   assignees = character(0),
#   repo = character(0),
#   status = character(0),
#   approver = character(0),
#   note = character(0),
#   url = character(0)
# )
# 
# db_con <- connect2DB()
# RPostgres::dbListTables(db_con)
# RPostgres::dbWriteTable(db_con, 'submission', submissions)
# RPostgres::dbGetQuery(db_con, 'alter table submission add id serial;')
# RPostgres::dbGetQuery(db_con, "alter table submission add created_on timestamp default current_timestamp")
# RPostgres::dbGetQuery(db_con, "alter table submission add last_update timestamp default current_timestamp")
# RPostgres::dbReadTable(db_con, 'submission')
# RPostgres::dbRemoveTable(db_con, "submission")

# test <- submitIssue(title = 'myTitle',
#                     author = 'beemyfriend',
#                     body = 'myBody',
#                     impact = "impact",
#                     timeline = "timeline",
#                     priority = 'Priority_Low',
#                     complexity = 'Complexity_Low',
#                     assignees = 'beemyfriend',
#                     repo = "ExploreGitAPI",
#                     token="")
# 
# test2 <- judgeIssue('', 
#                     test$id, 
#                     'approved', 
#                     'benjaminortizulloa', 
#                     'approvingnow',
#                     'Complexity_Low',
#                     'Priority_Low',
#                     'Do not know')
# 
# fail <- submitIssue(title = 'myTitle',
#                     author = 'beemyfriend',
#                     body = 'myBody',
#                     impact = "impact",
#                     timeline = "timeline",
#                     priority = 'Priority_Low',
#                     complexity = 'Complexity_Low',
#                     assignees = 'beemyfriend',
#                     repo = "ExploreGitAPI",
#                     token="shouldnotwork")
# 
# fail2 <- judgeIssue('', 
#                     fail$id, 
#                     'approved', 
#                     'benjaminortizulloa', 
#                     'approvingnow',
#                     'Complexity_Low',
#                     'Priority_Low',
#                     'Do not know')

# submit issue for admins to approve
submitIssue <- function(title,
                        author,
                        token,
                        body,
                        impact,
                        timeline,
                        priority,
                        complexity,
                        assignees,
                        repo
                        ){
  db_con <- connect2DB()
  print(c(title, author, token, body, impact, timeline, priority, complexity, assignees, repo, "pending validation", " "))
  qry <- paste0(
    "INSERT INTO submission(title, author, token, body, impact, timeline, priority, complexity, assignees, repo, status, note) ",
    "VALUES ('", 
    paste(stringr::str_replace_all(c(title, author, token, body, impact, timeline, priority, complexity, assignees, repo, "pending validation", " "), "'", "''"),  collapse = "', '"),
    "') RETURNING *;"
  )
  
  print(qry)
  
  info <- RPostgres::dbGetQuery(db_con, qry)
  
  RPostgres::dbDisconnect(db_con)
  
  return(info)
}

# approve or reject submitted issues
judgeIssue <- function(token, id, status, approver, note, complexity, priority, repo){
  db_con <- connect2DB()
  
  qry <- paste0(
    "UPDATE submission ",
    "SET status = '", status,"', ",
    "approver = '", approver,"', ",
    "note = '", stringr::str_replace_all(note, "'", "''"),"', ",
    "complexity = '", complexity, "', ",
    "priority = '", priority, "', ",
    "repo = '", repo, "', ",
    "last_update = current_timestamp ",
    "WHERE id = ", id," RETURNING *;"
  )
  
  info <- RPostgres::dbGetQuery(db_con, qry)
  info <- list(info = info)
  
  rep_info <- ""
  
  if(info$info$repo[1] == 'Do not know'){
    rep_info <- info$info$repo[1]
  } else {
    rep_info <- recon_packages(info$info$repo[1])
    rep_info <- paste0('https://github.com/', info$info$repo[1], ' | @', rep_info$poc)
  }
    
    paste0('github.com/', info$info$repo[1])
  if(status == 'approved'){
    bdy <- paste(paste(info$info$body[1], "\n"), 
                 paste0("[impact: ", info$info$impact[1], "]"), 
                 # paste0("[timeline: ", info$info$timeline[1], "]" ),
                 paste0("[originally proposed by @", info$info$author[1], "]"),
                 paste0("[suggested repo: ", rep_info, "]"),
                 paste0("[additional notes: ", info$info$note[1], "]"),
                 sep = "\n")
    
    ## this was only useful if we were going to add comments directly from suggesting user
    ## to avoid hassle of adding auth to random users [for tagging] we will only care about explicitly added users
    # if(autoFillUser(db_con, token, approver, info$info$author[1])){
    #   gitRes <- postIssue(token, info$info$title[1], bdy, info$info$priority[1], info$info$complexity[1], info$info$assignees[1])
    # } else {
    #   gitRes <- postIssue(info$info$token[1], info$info$title[1], bdy, info$info$priority[1], info$info$complexity[1], info$info$assignees[1])
    # }
    
    gitRes <- postIssue(token, info$info$title[1], bdy, info$info$priority[1], info$info$complexity[1], info$info$assignees[1])
    
    print(httr::status_code(gitRes))
    # #if attempt to submit issue with original author fails
    # #then submit issue with approver
    # if(httr::status_code(gitRes) != 201){
    #   gitRes <- postIssue(token, info$info$title[1], bdy, info$info$priority[1], info$info$complexity[1], info$info$assignees[1])
    #   print(gitRes)
    #   print(token)
    # }

    print(gitRes)
    
    info$gitRes <- httr::content(gitRes)
    
    qry <- paste0(
      "UPDATE submission ",
      "SET url = '", info$gitRes$html_url[1],"', ",
      "last_update = current_timestamp ",
      "WHERE id = ", id," RETURNING *;"
    )
    
    print('update url')
    print(qry)
    
    
    
    info$info <- RPostgres::dbGetQuery(db_con, qry)

    info$rank <- setRankScore(info$gitRes$id, gsub('_', ' ', priority))
  }
  
  RPostgres::dbDisconnect(db_con)
  
  return(info)
}

#' get issues by status
issues <- function(status){
  db_con <- connect2DB()
  
  qry <- paste0("SELECT * FROM submission WHERE status = '", status, "'")
  
  statuses <- RPostgres::dbGetQuery(db_con, qry)
  
  RPostgres::dbDisconnect(db_con)
  
  return(statuses)
}

myIssues <- function(user){
  db_con <- connect2DB()
  
  qry <- paste0("SELECT * FROM submission WHERE author = '", user, "'")
  
  statuses <- RPostgres::dbGetQuery(db_con, qry)
  
  RPostgres::dbDisconnect(db_con)
  
  return(statuses)
}

postIssue <- function(token,title, body, priority, complexity, assignees){
  #eventually assign task to assigned repos, but for now we will use reconhub/tasks
  owner = "reconhub"
  repo = "tasks"
  print('postIssue')
  
  bdy <- list(title = title, body = body, labels = c(priority, complexity))
  
  if(assignees != "Do not know"){
    bdy$assignees = list(assignees)
  }
  
  bdy <- jsonlite::toJSON(bdy, auto_unbox = T)
  
  url = paste0("https://api.github.com/repos/", owner, "/", repo, "/issues")

  tkn = paste('token', token)
  postres <- httr::POST(url, httr::add_headers(Authorization = tkn), body = bdy)
  
  return(postres)
}

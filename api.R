# https://github.com/rstudio/plumber/issues/418

source('utils.R')
source('git_oauth.R')
source('auth_db.R')
source('submissions.R')
source('follow_task.R')
source('vote_task.R')
source('recon_packages.R')

#* @filter cors
cors <- function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
  res$setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-User')

  plumber::forward()
}



#' @get /my-oauth
#' @param code
#' @html
gitOauth

#' @post /addAuth
#' @param token GitHup user token
#' @param user admin who is submittint a new user
#' @param login github handle of new user
#' @param type type of authorization [admin, reviewer, user]
addAuthorization
  
#' @get /auth
#' @serializer unboxedJSON
#' @param user
#' @param token
getAuthorization

#' @post /editAuth
#' @param token GitHub user token
#' @param user admin who is edditing user role
#' @param login github handle of user whose role is being edite
#' @param type new authorization type for user [admin, reviewer, user]
editAuthorization

#' @post /issue
#' @put /issue
#' @get /issue
#' @options /issue
#' @param title string title of task [POST]
#' @param user handle of author submitting task [POST] or approving task  [PUT]
#' @param body string of description
#' @param impact string of impact
#' @param timeline string of how long to expect
#' @param priority Priority_Low, Priority_Medium, Priority_High [POST, PUT]
#' @param complexity Complexity_Low, Complexity_Medium, Complexity_High [POST, PUT]
#' @param assignees single string for potential help
#' @param repo potential repo for task [POST, PUT]
#' @param token GitHub user token of person submitting task [POST] or approving task [PUT]
#' @param id ID of task [PUT]
#' @param status pending validation, approved, or rejected [PUT]
#' @param note not from approver [PUT]
issueAPI


#' @get /myIssues
#' @param user
#' @param token
myIssues

#' @get /tasks
#' @param user
#' @param token
serveTasks

#' @get /follow
#' @param issue_id
#' @param user
#' @param status
#' @param token
followTasks

#' @get /vote
#' @param issue_id
#' @param user
#' @param vote
#' @param token
voteTasks

#' @get /pkgs
#' @param status
recon_packages

#' @post /suggestPkg
#' @param org
#' @param pkg
#' @param poc
#' @param user
#' @param token
suggestPackages

#' @post /editPkg
#' @param id
#' @param status
#' @param user
#' @param token
editPackages

#' @serializer unboxedJSON
#' @post /test
#' @get /test
#' @put /test
#' @options /test
#' @param test
#' @param other
sanityCheck

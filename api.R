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
  res$setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
  # # print(Sys.time())
  # # print(req$REQUEST_METHOD)
  plumber::forward()
}

#' @get /my-oauth
#' @param code
#' @html
gitOauth

#' @options /auth
#' @post /auth
#' @put /auth
#' @get /auth
#' @param login github handle of new user for[POST, PUT]
#' @param type type of authorization [admin, reviewer, user] for [POST, PUT]
authAPI
  
#' @get /auth/<user>/<token>
#' @serializer unboxedJSON
getAuthorization


#' @options /issue
#' @post /issue
#' @put /issue
#' @get /issue
#' @param title string title of task [POST]
#' @param body string of description
#' @param impact string of impact
#' @param timeline string of how long to expect
#' @param priority Priority_Low, Priority_Medium, Priority_High [POST, PUT]
#' @param complexity Complexity_Low, Complexity_Medium, Complexity_High [POST, PUT]
#' @param assignees single string for potential help
#' @param repo potential repo for task [POST, PUT]
#' @param id ID of task [PUT]
#' @param status pending validation, approved, or rejected [PUT]
#' @param note not from approver [PUT]
issueAPI

#' @options /issue/<user>
#' @get /issue/<user>
#' @put /issue/<user>
myIssues

#' @get /tasks
serveTasks

#' @options /tasks/<users>
#' @get /tasks/<user>
indiviualizedTasks

#' @options /follow
#' @put /follow
#' @param issue_id id of issue/task to follow [PUT]
#' @param status Boolean true, false [PUT]
followTasks

#' @options /vote
#' @put /vote
#' @param issue_id id of issue/task to follow [PUT]
#' @param vote up, down, or none [PUT]
voteTasks

#' @options /pkgs
#' @post /pkgs
#' @put /pkgs
#' @get /pkgs
#' @param status pending validation, approved, rejected [PUT, GET]
#' @param org organization of package to suggest for RECON [POST]
#' @param pkg package name to sugget for recon [POST]
#' @param poc point of contact to refer queries about package [POST]
#' @param id id of pkg in db [PUT]
pkgAPI


#' @serializer unboxedJSON
#' @options /test
#' @post /test
#' @put /test
#' @get /test
#' @param test
#' @param other
sanityCheck

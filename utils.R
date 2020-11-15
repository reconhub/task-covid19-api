url_type <- Sys.getenv("RECON_URL_TYPE")
web = ifelse(url_type == 'dev', Sys.getenv("RECON_URL_DEV") ,Sys.getenv("RECON_URL_PROD"))
url <- Sys.getenv("GITHUB_AUTH_ACCESSTOKEN_URL")
id <- ifelse(url_type == 'dev', Sys.getenv("CLIENT_ID_DEV"), Sys.getenv("CLIENT_ID_PROD"))
secret <- ifelse(url_type == 'dev', Sys.getenv("CLIENT_SECRET_DEV"), Sys.getenv("CLIENT_SECRET_PROD"))
pg_auth <- Sys.getenv("PG_AUTH")

#https://gist.github.com/hrbrmstr/45c67103a9728f59212cd13262adca74
pg <- httr::parse_url(pg_auth)

connect2DB <- function(){
  RPostgres::dbConnect(RPostgres::Postgres(),
                       dbname = trimws(pg$path),
                       host = pg$hostname,
                       port = pg$port,
                       user = pg$username,
                       password = pg$password,
                       sslmode = "require"
  )
}

sanityCheck <- function(req){
  print(req$HTTP_AUTHORIZATION)
  print(req$REQUEST_METHOD)
  return('sanity check')
}

validateUser <- function(login, token){
  # 4ae7cfdc86436ba2f2a801e11cb63b9db7a253b5
  if(is.null(login) | is.null(token)) return(F)
  tkn <- paste('token', token)
  res <- httr::GET("https://api.github.com/user", httr::add_headers(Authorization = tkn))
  validation <- httr::content(res)$login == login
  validation
}

base_scores <- c(
  "Priority Low" = 10,
  "Priority Medium" = 30,
  "Priority High" = 50,
  "Priority Urgent" = 70
)
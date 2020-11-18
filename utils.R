url_type <- Sys.getenv("RECON_URL_TYPE")
web = ifelse(url_type == 'dev', Sys.getenv("RECON_URL_DEV") ,Sys.getenv("RECON_URL_PROD"))
url <- Sys.getenv("GITHUB_AUTH_ACCESSTOKEN_URL")
id <- ifelse(url_type == 'dev', Sys.getenv("CLIENT_ID_DEV"), Sys.getenv("CLIENT_ID_PROD"))
secret <- ifelse(url_type == 'dev', Sys.getenv("CLIENT_SECRET_DEV"), Sys.getenv("CLIENT_SECRET_PROD"))
pg_auth <- Sys.getenv("PG_AUTH")
recon_secret <- Sys.getenv('RECON_SECRET')

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
  # print(req$HTTP_AUTHORIZATION)
  # print(req$REQUEST_METHOD)
  # print(ls(req))
  return('sanity check')
}

createJWT <- function(name, type, gitToken){
  token <- jose::jwt_claim(login = name, auth = type, gitToken = gitToken)
  sig <- jose::jwt_encode_hmac(token, recon_secret)
  return(sig)
}

readJWT <- function(jwt){
  jose::jwt_decode_hmac(jwt, recon_secret)
}

validateUser <- function(login, jwt){
  # 4ae7cfdc86436ba2f2a801e11cb63b9db7a253b5
  # print(paste('jwt', jwt))
  if(is.null(login) | is.null(jwt)) return(F)
  decoded <- readJWT(jwt)
  validation <- decoded$login == login
  # tkn <- paste('token', token)
  # res <- httr::GET("https://api.github.com/user", httr::add_headers(Authorization = tkn))
  # validation <- httr::content(res)$login == login
  validation
}

base_scores <- c(
  "Priority Low" = 10,
  "Priority Medium" = 30,
  "Priority High" = 50,
  "Priority Urgent" = 70
)
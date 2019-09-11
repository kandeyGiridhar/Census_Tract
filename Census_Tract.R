census <- function(tablename,query,DBname){

  if(!require(pacman))utils::install.packages("pacman")
  pacman::p_load("httr",
                 "devtools",
                 "RCurl",
                 "urltools",
                 "DBI",
                 "odbc",
                 "RODBC",
                 "roxygen2",
                 "usethis",
                 "utils")
  library(httr)
  library(devtools)
  library(RCurl)
  library(urltools)
  library(DBI)
  library(odbc)
  library(RODBC)

  #Establish a database connection to retrieve input data
  connection <- DBI::dbConnect(odbc::odbc(),
                               Driver = "SQL Server",
                               Server = "172.28.30.25",
                               Database = paste(DBname),
                               UID = Sys.getenv("UID"),
                               PWD = Sys.getenv("PWD"),
                               Port = 1433)

  #SQL to specify which table to be used
  Census_Tract<- DBI::dbGetQuery(connection,paste(query))

  names(Census_Tract) <- NULL

  #Create and store the data retrieved from the SQL (input data)
  input <- tempfile(fileext = ".csv")
  utils::write.csv(Census_Tract, input, row.names = FALSE)

  #Function to implement the conversion of input address to the desired output
  apiurl <- "https://geocoding.geo.census.gov/geocoder/geographies/addressbatch"
  list_output <- httr::POST(apiurl, body= list(addressFile = httr::upload_file(input),
                                               benchmark = "Public_AR_Current",
                                               vintage = "Current_Current"
  ),
  encode="multipart"
  )

  #Cat function is used to print the output in user desired manner
  cat(httr::content(list_output, "text", encoding = "UTF-8"), "\n")

  #Store the encoded form of output in a file
  cat(httr::content(list_output, "text", encoding = "UTF-8"), file="output.csv")

  #convert the list format to a .csv format with column names
  df_output<-utils::read.csv(file ="output.csv",header = FALSE,
                             col.names = c("record_id_number"
                                           ,"input_address"
                                           ,"tiger_address_range_match_indicator"
                                           ,"tiger_match_type"
                                           ,"tiger_output_address"
                                           ,"longitude_latitude"
                                           ,"tigerline_id"
                                           ,"tigerline_id_side"
                                           ,"state_code"
                                           ,"county_code"
                                           ,"tract_code"
                                           ,"block_code"))

  #Store the output in a temp file
  output <- tempfile(fileext = ".csv")
  utils::write.csv(df_output, output, row.names = FALSE)


  #Establish the connection between SQL server and load the output data to tables
  DBI::dbWriteTable(conn = connection,
                    name = paste(tablename),
                    value = df_output,
                    overwrite = T)
}

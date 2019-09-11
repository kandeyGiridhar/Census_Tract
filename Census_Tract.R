library(httr)
library(tidyverse)
library(devtools)
library(RCurl)
library(urltools)
library(DBI)
library(odbc)
library(RODBC)

#Establish database connection 
connection <- DBI::dbConnect(odbc::odbc(), 
                             Driver = "SQL Server", 
                             Server = "172.28.30.25", 
                             Database = "lara_data",
                             UID = "prodigydba", 
                             PWD = "3FsRxlD9ermiU1A!", 
                             Port = 1433)

#Query to fetch the data from SQL  
Census_Tract<- DBI::dbGetQuery(connection,"select top 10 * from [test_geocoding]")

#store the data in a temp .csv file
input <- tempfile(fileext = ".csv")
write.csv(Census_Tract, input, row.names = FALSE)

#Function to conver the input address to desiered output
apiurl <- "https://geocoding.geo.census.gov/geocoder/geographies/addressbatch"
list_output <- POST(apiurl, body= list(addressFile = upload_file(input), 
                                       benchmark = "Public_AR_Current",
                                       vintage = "Current_Current"
), 
encode="multipart"
)



content(list_output)


cat(content(list_output, "text", encoding = "UTF-8"), "\n")

#Storing the Encoded data in a file  
cat(content(list_output, "text", encoding = "UTF-8"), file="output.csv")

#Converting the output to a data frame
df_output<-read.csv(file ="output.csv",header = FALSE,
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

#Removing the column headers from the output 
df_output=subset(df_output,df_output$input_address!="street_address, city, state, zip")

#store the output in a temp file 
output <- tempfile(fileext = ".csv")
write.csv(df_output, output, row.names = FALSE)

#Storing the formated output in the database
dbWriteTable(conn = connection, 
             name = "Census_Tract", 
             value = df_output,
             overwrite = T)

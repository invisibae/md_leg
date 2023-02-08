# Required Packages -------------------------------------------------------
# for basic data transformation
library(dplyr)
library(stringr)
library(readr)
# for accessing the site 
library(RSelenium)
# for scraping table
library(rvest)
# for parallel operations 
library(furrr)
# for the 'clean_names' function
library(janitor)
# for writing to google sheets 
library(googlesheets4)
# for sending messages to slack 
library(slackr)
##
# library(wdman)




# start scraping  --------------------------------------------------------


# the broken bit
selServ <- wdman::selenium(verbose = FALSE)
selServ$log()

# 
# rD <- rsDriver(browser = "firefox", 
#                version = "3.141.59",
#                verbose = T
# )
# 
# 
# remDr <- rD[["client"]]





## break glass in case of emergencies: 

# for a very worst case where we forget to close the server 
# 
# rD <- rsDriver()
# rm(rD)

# this one stops the session so we can re-use the port
# rD$server$stop()

# this one closes the browser window
# remDr$close()


# our scraper elements ---------------------------------------------------------


#  This opens the url in our browser window 

base_url <- "https://mgaleg.maryland.gov/mgawebsite/Legislation/Index/house"

remDr$navigate(base_url)

# save page html and grab the table 
Sys.sleep(2) 
vignette("basics", package = "RSelenium")

base_html <- remDr$getPageSource()[[1]]



test_table <- read_html(base_url) %>% 
  html_table() %>% 
  .[[2]] 


# let's get bill url's so we can get detail page info
# url structure is fairly easy 
test_table <- 
  test_table %>% 
  mutate(house_bill = word(`Bill/Chapter  (Cross/Chapter)`, 1),
         page_url = paste0("https://mgaleg.maryland.gov/mgawebsite/Legislation/Details/", 
                           house_bill, "?ys=2023RS"))

# we've now scraped the entire table 
# but we're not done 
# lets grab some additional information from the page associated with each bill 

# write some functions to get additional relevant info from bill page 

# synopsis 
get_synopsis <- function(bill_url) {
  
  bill_url %>% 
    read_html %>% 
    html_nodes(".details-content-area .row:nth-child(1) .col-sm-10") %>% 
    html_text() %>% 
    .[1] %>% 
    as.character()
  
}

# when was bill originally introduced 
get_detail_1 <- function(bill_url) {
  
  bill_url %>% 
    read_html %>% 
    html_nodes(".pl-0:nth-child(1) .col-sm-12") %>% 
    html_text() %>% 
    .[1] %>% 
    as.character()
  
} 

# who are the bill's sponsors and co-sponsors?
get_sponsors <- function(bill_url) {
  
  bill_url %>% 
    read_html %>% 
    html_nodes(".col-sm-10:nth-child(4)") %>% 
    html_text() %>% 
    .[1] %>% 
    as.character()
  
} 

# parallelize operations 
# makes this thing go way faster
plan(multisession, workers = 75)


# add columns 
test_table <- test_table %>% 
  mutate(synopsis = as.character(future_map(test_table$page_url, get_synopsis)),
         leg_history = as.character(future_map(test_table$page_url, get_detail_1)),
         sponsors = as.character(future_map(test_table$page_url, get_sponsors))
  ) %>% 
  clean_names()

# Do an anti-join to find out which bills have changed --------------------

# read in old version of our table 

old_table <- read_rds("data/old_table.rds")


# perform anti-join
new_stuff <- 
  test_table %>% 
  anti_join(old_table)

# write csv file to replace the one in the 'data' folder ------------------

fold <- 'data/'

# get all files in the directories, recursively
f <- list.files(fold, include.dirs = F, full.names = T, recursive = T)
# remove the files
file.remove(f)

# save our most recent table as the "old_table"
write_rds(test_table, "data/old_table.rds")


# Update slack with info on new/changed bills  ----------------------------

# authenticate gs4 
gs4_auth(path = "keys/md-house-google-credential.json")

# overwrite sheets
sheet_write(test_table, 
           ss = Sys.getenv("DOC_URL"),
           sheet = "all_current_bills"
           )

sheet_write(new_stuff, 
            ss = Sys.getenv("DOC_URL"),
            sheet = "new_stuff_and_changes"
            )


# define message to post to slack 

doc <- Sys.getenv("DOC_URL")

message <- 
  paste0("New info on", " ", nrow(new_stuff)," bill(s).", " Read more here:", " ", doc)

# Post to slack 
if (identical(test_table, old_table) == FALSE) {
  slackr_msg(txt = message,
             token = Sys.getenv("SLACK_TOKEN"),
             channel = Sys.getenv("SLACK_CHANNEL"),
             username = Sys.getenv("SLACK_USERNAME"),
             thread_ts = NULL,
             reply_broadcast = FALSE
  )
} else {
  slackr_msg(txt = "No new updates :cry:",
             token = Sys.getenv("SLACK_TOKEN"),
             channel = Sys.getenv("SLACK_CHANNEL"),
             username = Sys.getenv("SLACK_USERNAME"),
             thread_ts = NULL,
             reply_broadcast = FALSE)
  
}


# Shut our ports down and close out the show ---------------------------------------
# this one stops the session so we can re-use the port 
rD$server$stop()




# Done! -------------------------------------------------------------------

















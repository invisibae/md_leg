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
library(wdman)




# start scraping  --------------------------------------------------------

# Learn about RSelenium 
vignette("basics", package = "RSelenium")

# start up our server 
rD <- rsDriver(browser = "firefox",
               verbose = T,
               port = 10101L
               
)


remDr <- rD[["client"]]





## break glass in case of emergencies: 

# for a very worst case where we forget to close the server 

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


# Shut our ports down and close out the show ---------------------------------------
# this one stops the session so we can re-use the port 
rD$server$stop()


# Done! -------------------------------------------------------------------

















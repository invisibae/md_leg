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
library(jsonlite)
library(pdftools)
library(jsonlite)


# start scraping  --------------------------------------------------------

# We're gonna have to start the server at the beginning of the session so we can continue to use the broswer further down (Unfinished)

# rD <- rsDriver(browser = "firefox",
#                verbose = F,
#                chromever = NULL,
#                )
# 
# 
# remDr <- rD[["client"]]
# 
# 
# remDrclose


## break glass in case of emergencies: 

# for a very worst case where we forget to close the server 
# 
# rD <- rsDriver()


# remDr$stop()
# this one stops the session so we can re-use the port
# rD$server$stop()

# this one closes the browser window
# remDr$close()




# our scraper elements ---------------------------------------------------------


#  This opens the url in our browser window 

base_url <- "https://mgaleg.maryland.gov/mgawebsite/Legislation/Index/house"


# save page html and grab the table 
# Sys.sleep(2) 


# Functions  --------------------------------------------------------------

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

test_table %>% 
  clean_names %>% 
  group_by(current_status) %>% 
  count(sort = T)
# Convert Bill text/fiscal note to text from pdf 

get_text<- function(our_pdf) {
  
pdf_path <- our_pdf

txt_output <- pdftools::pdf_text(pdf_path) %>%
  paste0(collapse = " ") %>%
  paste0(collapse = " ") %>%
  stringr::str_squish() 

return(txt_output)
}

# Get bill status 
# problems: too computationally expensive. Selenium forces me to navigate to every page and get each element one page at a time. Need to find a way to cut this down
get_status <- function(detail_url) {
  
  # open server
  rD <- rsDriver(browser = "firefox",
                 verbose = F,
                 chromever = NULL,
  )
  
  # make remDr object that we can use to navigate and grab page source 
  remDr <- rD[["client"]]
  
  # navigate to url so the javascript can load
  remDr$navigate(detail_url)
  
  # let the page load
  Sys.sleep(time = 2)
  
  # find status element 
  elems <- remDr$findElements(using = 'xpath',
                   '//*[contains(concat( " ", @class, " " ), concat( " ", "active", " " ))]//*[contains(concat( " ", @class, " " ), concat( " ", "label", " " ))]') 
  # grab it
  elem <- elems[[1]]
  
  # save it as text
  status <- elem$getElementText()[[1]]

  
  # shut down the server 
  
  remDr$quit()
  rD$server$stop()
  return(status)
  

}

get_status("https://mgaleg.maryland.gov/mgawebsite/Legislation/Details/hb0002?ys=2023RS")


# function for grabbing last character of string for pdf url
substrRight <- function(x, n){
  substr(x, nchar(x)-n+1, nchar(x))
}



# get html table 
test_table <- read_html(base_url) %>% 
  html_table() %>% 
  .[[2]]


# let's get bill url's so we can get detail page info
# url structure is fairly easy 



test_table <- 
  test_table %>% 
  mutate(house_bill = word(`Bill/Chapter  (Cross/Chapter)`, 1),
         page_url = paste0("https://mgaleg.maryland.gov/mgawebsite/Legislation/Details/", 
                           house_bill, "?ys=2023RS"), 
         leg_note_url = paste0("https://mgaleg.maryland.gov/2023RS/fnotes/",
                               "bil_000",
                               substrRight(house_bill, 1),
                               "/",
                               str_to_lower(house_bill),
                               ".pdf"),
         bill_text_url = paste0("https://mgaleg.maryland.gov/2023RS/bills/hb/",
                                str_to_lower(house_bill),
                                "f.pdf"
                                ))  %>% 
  clean_names() %>% 
  mutate(chamber = case_when(str_detect(current_status, "In the House") ~ "house",
                             str_detect(current_status, "In the Senate") ~ "senate"),
         status = case_when(str_detect(current_status, "First Reading|Hearing|Rereferred to ") ~ "first_read",
                            str_detect(current_status, "Second Reading") ~ "third_read",
                            str_detect(current_status, "Third Reading") ~ "first_read_senate",
                            str_detect(current_status, "Review") ~ "review_in_og_chamber",
                            str_detect(current_status, "Conference") ~ "conf_cmte",
                            str_detect(current_status, "Governor") ~ "on_gov_desk",
                            str_detect(current_status, "Withdrawn") ~ "withdrawn",
                            str_detect(current_status, "Unfavorable") ~ "died_in_cmte",
                            str_detect(current_status, "Special Order") ~ "special_order",
                            TRUE ~ "Other"
                            ))


test_table %>% 
  filter((status != "first_read") + (chamber != "house") == 1) %>% 
  View()

test_json <- toJSON(x = test_table, dataframe = 'rows', pretty = T)

write_json(test_json, "data/test_json.json")

# parallelize operations 
# makes this thing go way faster
plan(multisession, workers = 75)


# add columns 
test_table <- test_table %>% 
  head(10) %>% 
  group_by(page_url) %>% 
  mutate(synopsis = as.character(future_map(page_url, get_synopsis)),
         leg_history = as.character(future_map(page_url, get_detail_1)),
         sponsors = as.character(future_map(page_url, get_sponsors)),
         # legislative_note = as.character(future_map(leg_note_url, get_text)),
         # bill_tet = as.character(future_map(bill_text_url, get_text)),
         bill_progress = as.character(future_map(page_url, get_status))
         
  ) %>% 
  clean_names()


# Do an anti-join to find out which bills have changed --------------------

# read in old version of our table 

old_table <- read_rds("data/old_table.rds")


# perform anti-join (can we be doing this better?)
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


gs4_deauth()

gs4_auth(
         path = "keys/md-house-google-credential.json"
         )



# overwrite sheets
sheet_write(test_table, 
           ss = "1Y2MW_7ttg4ROgbbi0p5zJGme32hlqmem85zzpHrCKKg",
           sheet = "all_current_bills"
           )

sheet_write(new_stuff, 
            ss = "1Y2MW_7ttg4ROgbbi0p5zJGme32hlqmem85zzpHrCKKg",
            sheet = "new_stuff_and_changes"
            )




# define message to post to slack 

doc <- "https://docs.google.com/spreadsheets/d/1Y2MW_7ttg4ROgbbi0p5zJGme32hlqmem85zzpHrCKKg/edit?usp=sharing"



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
  slackr_msg(txt = paste0("No new updates :cry:",", check out the full list of bills here: ", doc),
             token = Sys.getenv("SLACK_TOKEN"),
             channel = Sys.getenv("SLACK_CHANNEL"),
             username = Sys.getenv("SLACK_USERNAME"),
             thread_ts = NULL,
             reply_broadcast = FALSE)
  
}


# Shut our ports down and close out the show ---------------------------------------
# this one stops the session so we can re-use the port 
# rD$server$stop()




# Done! -------------------------------------------------------------------

















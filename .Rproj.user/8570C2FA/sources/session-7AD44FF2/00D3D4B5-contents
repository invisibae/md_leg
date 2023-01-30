# This is a basic workflow to help you get started with Actions

name: test nlrb

# Controls when the workflow will run
on:
  # Triggers the workflow on push or pull request events but only for the main branch
  push:
  schedule:
  - cron: "0 8-18 * * *" # runs every hour from 8 am - 6 pm
# Allows you to run this workflow manually from the Actions tab
workflow_dispatch:
  
  
  # A workflow run is made up of one or more jobs that can run sequentially or in parallel
  jobs:
  autoscrape:
  env:
  SLACK_INCOMING_WEBHOOK_URL: ${{ secrets.SLACK_INCOMING_WEBHOOK_URL }}
SLACK_CHANNEL: ${{ secrets.SLACK_CHANNEL }}
SLACK_USERNAME: ${{ secrets.SLACK_USERNAME }}
SLACK_ICON_EMOJI: ${{ secrets.ICON_EMOJI }}
SLACK_TOKEN: ${{ secrets.SLACK_TOKEN }}
GGMAP_GOOGLE_API_KEY: ${{ secrets.GGMAP_GOOGLE_API_KEY }}

# The type of runner that the job will run on
runs-on: macos-latest

# Load repo and install R
steps:
  - uses: actions/checkout@master
- uses: r-lib/actions/setup-r@master

- name: Cache R packages
if: runner.os != 'Windows'
uses: actions/cache@v2
with:
  path: /slack.bot.packages/DESCRIPTION
key: "{{ test_key }}"

- name: setup firefox 
steps:
  - uses: browser-actions/setup-firefox@v1
- run: firefox --version

jobs:
  build:
  runs-on: ubuntu-latest
strategy:
  matrix:
  firefox: [ '84.0', 'latest-beta', 'latest-devedition', 'latest-esr', 'latest' ]
name: Firefox ${{ matrix.firefox }} sample
steps:
  - name: Setup firefox
uses: browser-actions/setup-firefox@v1
with:
  firefox-version: ${{ matrix.firefox }}
- run: firefox --version



# Set-up R
- name: Install packages
run: |
  R -e 'install.packages("slackr")'
R -e 'install.packages("tidyverse")'
R -e 'install.packages("slackr")'
R -e 'install.packages("rvest")'
R -e 'install.packages("dplyr")'
R -e 'install.packages("DBI")'
R -e 'install.packages("RSQLite")'
R -e 'install.packages("data.table")'
R -e 'install.packages("tidyverse")'
R -e 'install.packages("lubridate")'
R -e 'install.packages("knitr")'
R -e 'install.packages("janitor")'
R -e 'install.packages("remotes")'
R -e 'install.packages("ggmap")'
R -e 'install.packages("leaflet")'
R -e 'install.packages("leaflet.providers")'
R -e 'install.packages("data.table")'
R -e 'install.packages("packcircles")'
- name: print env variables
run: |
  echo ${{ secrets.SLACK_USERNAME }}
- name: scrape - r
run: Rscript md_leg_scraper.R
- name: fetch
run: git fetch
- name: pull
run: git pull
- name: add
run: git add --all
- name: commit
run: |-
  git config user.name "Automated"
git config user.email "actions@users.noreply.github.com"
git commit -m "Latest data ${timestamp}"
- name: push
run: git push
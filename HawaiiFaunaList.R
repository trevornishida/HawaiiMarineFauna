# Hawaii Marine Fauna Regional Species List
# Sources: Bishop Museum, Lifewatch.be, Ocean Biodiversity Information System
# InverteBase, ARMS, Various professionals
# Compiled August 2023

library(tidyverse)
source("dataWranglingFuns.R")

# Collect Invert Data from File Generated by regionalInvertList.R
invertData <- read.csv("HawaiiInvertList.csv")

# Fish Data Compiled by Jonathan Whitney
# Sources:
# B.C. Mundy 2005: Checklist of the Fishes of the Hawaiian Archipelago
# J.E. Randall 2007: Reef and shore fishes of the Hawaiian Islands
# FishBase
fishData <- read.csv("HawaiiFishList.csv") %>% 
  rename("TaxStatus" = "Status")

# Define columns of interest to be used with wormsProcess function
# See dataWranglingFuns.R for full list of possible columns.
ColOfInterest <- c(
  "scientificname", "AphiaID", "valid_AphiaID", "valid_name", "status",
  "kingdom", "phylum", "class", "order", "family", "genus", "rank"
)

# Parse out metadata from original fish data file
fishMeta <- fishData %>% 
  # Common name, endemic status, species name, pelagic distribution, and original record of species.
  select(FBname, status, species, DemersPelag, source) %>% 
  # Create endemic column by collapsing status column into a binary indicating endemic or not
  mutate(endemic = case_when(status == "Endemic" ~ 1,
                             .default = 0)) %>% 
  # Remove status from dataframe
  select(!status) %>% 
  # Create data origin column based on numbers correlating to original record of species.
  mutate(origin = case_when(source == "1" ~ "Randall2007",
                            source == "2" ~ "Fishbase",
                            source == "3" ~ "Mundy2005",
                            source == "1,3" ~ "Mundy2005",
                            source == "2,3" ~ "Mundy2005",
                            source == "1,4" ~ "Randall2007",
                            source == "2,4" ~ "Mundy2005",
                            .default = "Whitney")) %>% 
  # Remove source column from dataframe.
  select(!source) %>% 
  # Rename columns to be able to properly join to invert data.
  rename("distribution" = "DemersPelag",
         "common" = "FBname")

# Process species through WoRMS API to collect data regarding Taxonomy
fishWormsData <- wormsProcess(fishData, ColOfInterest)

# Combine WoRMS processed data with metadata dataframe.
fishJoinData <- fishWormsData %>% 
  left_join(fishMeta, by = join_by("scientificname" == "species")) 

# Combine fish data with invert data to create comprehensive marine fauna list
allFauna <- invertData %>% 
  full_join(fishJoinData) %>% 
  select(!X)

# Save off marine fauna list to CSV file. 
write.csv(allFauna, "HawaiiMarineFaunaList.csv", row.names = FALSE)

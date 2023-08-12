# Hawaii Invertebrate Regional Species List
# Sources: Bishop Museum, Lifewatch.be, Ocean Biodiversity Information System
# InverteBase, ARMS, Various professionals
# Compiled June 2023

library(xml2)
library(tidyverse)
library(tools)
library(readxl)
source("dataWranglingFuns.R")

# Function that will extract species from HTML files
# Bishop Museum stored species data in HTML files this function integrates
# another function `extractSpecies()` to pull out the data 
# and save off into a more interact-able format. 

bishopProcess <- function(fileName){
  
  file_html = xml2::read_html(fileName)
  
  # Save the file name which corresponds to taxa group
  name = tools::file_path_sans_ext(basename(fileName)) 
  
  # Use extractSpecies function to pull out species from raw HTML
  name = extractSpecies(file_html)
  name = name %>% 
    select(species)
  
  # Return the list of species
  # Should be a character vector splitting species by newlines
  return(name)
}

#### Process Bishop Files and Create Master Bishop List ####

# Set working directory and save off names of all files
setwd("Species Lists/Bishop Processing/")
file.list <- dir()

# Apply the bishopProcess function to all files in the directory
allBishop <- sapply(file.list, bishopProcess)

# Flatten the list of character vectors into a single list
allBishopSp = purrr::flatten(allBishop)

# Define columns of interest to be used with wormsProcess function
# See dataWranglingFuns.R for full list of possible columns.
CoI <- c(
  "scientificname", "AphiaID", "valid_AphiaID", "valid_name", "status",
  "kingdom", "phylum", "class", "order", "family", "genus", "rank"
)


# Process list of species from Bishop using WoRMS
bishopListProcessed <- allBishopSp %>% 
  # Convert List of Species into a Dataframe
  as.data.frame() %>% 
  # Spread to long
  pivot_longer(everything()) %>% 
  # Rename column and select only that column.
  dplyr::rename("species" = "value") %>% 
  dplyr::select("species") %>% 
  # Collapse classifications of sp. and cf to genus level id
  dplyr::mutate(across("species", str_replace, " sp.| Sp.| cf", "")) %>% 
  # Keep only one of each taxonomic entry
  dplyr::distinct() %>% 
  # Clean up list
  dplyr::filter(!str_starts(species, "\\(")) %>% 
  dplyr::filter(!str_starts(species, "\\-")) %>% 
  # Process list using wormsProcess function
  wormsProcess(., CoI)

# Process species that came up invalid in previous function using Fuzzy search.
bishopFuzzyProcessed <- allBishopSp %>% 
  # Convert List of Species into a Dataframe
  as.data.frame() %>% 
  # Spread to long
  pivot_longer(everything()) %>% 
  # Rename column and select only that column.
  dplyr::rename("species" = "value") %>% 
  dplyr::select("species") %>% 
  # Collapse classifications of sp. and cf to genus level id
  dplyr::mutate(across("species", str_replace, " sp.| Sp.| cf", "")) %>% 
  # Keep only one of each taxonomic entry
  dplyr::distinct() %>% 
  # Clean up list
  dplyr::filter(!str_starts(species, "\\(")) %>% 
  dplyr::filter(!str_starts(species, "\\-")) %>% 
  # Cross check WoRMS processed list to see which taxa were not found.
  anti_join(bishopListProcessed, by = join_by("species" == "scientificname")) %>% 
  # Remove entries that are a part of taxa authority.
  dplyr::filter(!str_ends(species, " and")) %>% 
  # Process list using wormsProcess function
  wormsProcess(., CoI, fuzzy = TRUE)

# Combine fuzzy searched and normal searched lists
bishopList <- bishopListProcessed %>% 
  bind_rows(bishopFuzzyProcessed)

bishopListSpecies <- bishopList %>% 
  filter(rank == "Species")

setwd("~/Hawaii Invert List")

#### Lifewatch List ####

hiEEZReport <- read.csv("Species Lists/LifewatchList.csv")

# Filter out extinct species and species that have only a single recorded entry
lifewatchList <- hiEEZReport %>% 
  dplyr::filter(isExtinct != 1 | is.na(isExtinct)) %>% 
  distinct(acceptedNameUsageID, .keep_all = T) %>% 
  dplyr::filter(phylum != "Chordata",
         count > 1)

# Create list of species not already recorded in the Bishop list
unmatchedLifewatch <- bishopListSpecies %>% 
  anti_join(lifewatchList, by = join_by("worms_name" == "acceptedNameUsage"))
# 817 unmatched species 

# Put lifewatch list into format compatible with Bishop list
lifewatch <- lifewatchList %>% 
  anti_join(bishopListSpecies, by = join_by("acceptedNameUsage" == "worms_name")) %>% 
  dplyr::select(scientificName:genus) %>% 
  dplyr::select(!count) %>% 
  dplyr::select(!scientificNameAuthorship) %>% 
  dplyr::rename("scientificname" = "scientificName",
         "AphiaID" = "aphiaID",
         "status" = "taxonomicStatus",
         "valid_AphiaID" = "acceptedNameUsageID",
         "worms_name" = "acceptedNameUsage") %>% 
  dplyr::mutate("valid_name" = stringr::str_replace(worms_name, " \\s*\\([^\\)]+\\)", ""))

# Combine bishop and lifewatch lists
# Remove duplicated AphiaIDs
lifewatchAndBishop <- bishopListSpecies %>% 
  full_join(lifewatch) %>%
  distinct(AphiaID, .keep_all = TRUE) %>% 
  mutate(origin = if_else(is.na(origin), "bishop", origin)) %>% 
  mutate(origin = as.factor(origin))

#### OBIS List ####

# Filter out empty species entires and select columns that have the data we 
# are interested in
#
# WILL ERROR NEED TO DOWNLOAD OBIS DATA FROM THE OBIS PORTAL
# TOO LARGE TO STORE FILE ON GITHUB

hawaiiOBISinverts <- read.csv("Species Lists/HAWAII_OBIS_DATA.csv") %>% 
  dplyr::filter(phylum != "Chordata") %>% 
  dplyr::select(c("scientificname", "originalscientificname", "taxonrank", "aphiaid", 
           "kingdom", "phylum", "class", "order", "family", "genus", "basisofrecord", "id")) %>% 
  distinct(scientificname, aphiaid, .keep_all = TRUE) %>% 
  dplyr::filter(scientificname != "")

# Filter to Species entries
hawaiiOBISinverts = hawaiiOBISinverts %>% 
  filter(taxonrank == "Species")


OBISidList <- hawaiiOBISinverts %>% 
  select(scientificname, id)
  
unmatchedOBIS <- hawaiiOBISinverts %>% 
  anti_join(lifewatchAndBishop, by = join_by("scientificname" == "worms_name"))

# Remove entries that are based on preserved specimens.
unmatchedOBISFilter <- unmatchedOBIS %>% 
  filter(basisofrecord != "PreservedSpecimen") %>% 
  dplyr::rename("AphiaID" = "aphiaid",
         "rank" = "taxonrank") %>% 
  select(!originalscientificname) %>% 
  select(!basisofrecord)

#### ARMS List ####

armsData <- read_xlsx("Species Lists/ARMS_MarineInverts_ListsGuildFood.xlsx")

armsSpecies <- armsData %>% 
  # 
  select(SCIENTIFICNAME, TROPHIC_GUILD_CODE) %>% 
  mutate(species = str_match(SCIENTIFICNAME, "[A-Z][a-z]+\\W[a-z]+\\b|[A-Z][a-z]+\\b")) %>% 
  mutate(across("species", str_replace, " sp", "")) %>% 
  distinct(species, .keep_all = TRUE)

armsWoRMS <- armsSpecies %>% 
  wormsProcess(., CoI, fuzzy = TRUE) %>% 
  mutate(origin = "arms") %>% 
  left_join(armsSpecies, by = join_by("scientificname" == "species")) %>% 
  select(!SCIENTIFICNAME)


#### InvertBase ####

invertBaseData <- read.csv("Species Lists/InvertBase_Marine Invertebrates of Kaneohe Bay_1685607641.csv")

invertBaseWoRMS <- invertBaseData %>% 
  filter(!str_starts(ScientificName, "\\[")) %>% 
  select(ScientificName) %>% 
  mutate(species = str_match(ScientificName, "[A-Z][a-z]+\\W[a-z]+\\b|[A-Z][a-z]+\\b")) %>% 
  mutate(across("species", str_replace, " sp", "")) %>% 
  distinct(species) %>% 
  wormsProcess(., CoI, fuzzy = TRUE) %>% 
  mutate(origin = "invertbase")
  

#### Micromollusc List ####

micromolluscs <- read_xlsx("Species Lists/Micromollusc species list.xlsx")

micromolluscWoRMS <- micromolluscs %>% 
  select(Species) %>% 
  mutate(Species = str_match(Species, "[A-Z][a-z]+\\W[a-z]+\\b|[A-Z][a-z]+\\b")) %>% 
  mutate(across("Species", str_replace, " sp", "")) %>% 
  distinct(Species, .keep_all = TRUE) %>% 
  wormsProcess(., CoI, fuzzy = TRUE) %>% 
  mutate(origin = "micromolluscList")
  

#### Creating full list ####

poriferaList <- read.csv("Species Lists/poriferaSpecies.csv") %>% 
  rename("AphiaID" = "id")
cnidariaList <- read.csv("Species Lists/cnidarianSpeciesCSV.csv") %>% 
  rename("scientificname" = "species")

# Combine all lists into one list
fullInvertList <- lifewatchAndBishop %>% 
  full_join(unmatchedOBISFilter) %>% 
  full_join(OBISidList) %>% 
  full_join(poriferaList) %>% 
  full_join(cnidariaList) %>% 
  full_join(armsWoRMS) %>% 
  full_join(invertBaseWoRMS) %>% 
  full_join(micromolluscWoRMS) %>% 
  # Keep one entry of each unique Aphia ID
  distinct(AphiaID, .keep_all = TRUE) %>% 
  # Add in metadata regarding original dataset each entry came from
  mutate(origin = if_else(is.na(origin), listID, origin)) %>% 
  mutate(origin = if_else(is.na(origin), "bishop", origin)) %>% 
  mutate(rank = if_else(is.na(rank), "Species", rank))

#### Write out the full list to a CSV file ####

write.csv(fullInvertList, file = "HawaiiInvertList.csv")  






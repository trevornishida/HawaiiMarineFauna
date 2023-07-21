# Extract Species Function ----
# Trevor Nishida
# Function to extract species level information from Bishop Museum HTML files

require(tidyverse)

# Function used to extract the species information from HTML files
# Input HTML file data after reading into R (xml2::read_html())

extractSpecies <- function(rawHTML) {
  # Harvest raw text data from the HTML file
  # CSS selectors to navigate through child elements
  textFromHTML <- rawHTML %>%
    rvest::html_element("body > div") %>%
    rvest::html_elements("p") %>%
    rvest::html_text2()

  # Remove clutter (HTML tags) from text and format into a list
  cleanText <- gsub("\r", "", textFromHTML, fixed = T) %>%
    trimws(.)
  listOfText <- as.list(scan(text = cleanText, what = "", sep = "\n"))

  # Create a dataframe using the list
  # Use RegEx to extract species level identification
  speciesDF <- listOfText %>%
    stringr::str_extract_all(., "(\\S\\w+\\s[[:lower:]]+(?!\\')|\\S\\w+\\s\\(\\w+\\)\\s[[:lower:]]+\\w)") %>%
    purrr::list_c() %>%
    purrr::compact() %>% # Remove empty list entries
    stringr::str_replace_all(., " sp", " sp.") %>% # Fix Sp. labels (Missing punctuation)
    dplyr::tibble() %>% # Send list to a tibble
    dplyr::rename("species" = ".") %>% # Rename column to properly reflect what is stored
    dplyr::mutate(listID = "bishop") %>% # Add origin of data identifier for each entry
    # mutate(across("species", str_replace, " sp.| Sp.", "")) %>% # Remove Sp. to (hopefully) identify to Genus
    dplyr::distinct() # Remove duplicates (if any)
  return(speciesDF) # Return the dataframe
}


# WoRMS Cross reference function ----
# Trevor Nishida
# Adapted from https://marinegeo.github.io/2018-04-24-working-with-worms/
# Script to cross reference species name to the World Registry of Marine Species database

require(tidyverse)
require(worrms)

# Input a data frame containing a column of species names --> Most likely output from extractSpecies()
# Also takes ColumnsOfInterest --> Character Vector of column names from WoRMS output that is of interest

# Possible column names: AphiaID, url, scientificname, authority, status, unacceptreason, taxonRankID, rank
#                        valid_AphiaID, valid_name, valid_authority, parentNameUsageID, kingdom, phylum, class, order
#                        family, genus, citation, lsid, isMarine, isBrackish, isFreshwater, isTerrestrial, isExtinct,
#                        match_type, modified

# Optionally, fuzzy: A binary operator which determines if it should fuzzy search

wormsProcess <- function(dataframe, ColumnsOfInterest, fuzzy = FALSE) {
  # Split every 50 or so rows -- Can only request ~50 instances to WoRMS database; drops all results after ~50 for request of 100
  n <- 25

  
  df <- dataframe %>%
    rename_with(tolower) %>% # Ensure column labels are lower case
    mutate(species = as.character(species)) %>% # and make sure species is coming in as a character column
    filter(species != "") %>% 
    filter(species != " ") %>% 
    mutate(scientificName = species) %>% # Collect ONLY species column from input
    group_split(group_id = row_number() %/% n) # Use integer division to split up data by groups of 100
  
  wormPH <- list() # Initialize list that will store WoRMS data
  
  
  for (i in 1:length(df)) {
    uniqueSpeciesList <- df[[i]] %>% # Iterate over each group of data save off a list of species
      dplyr::select(scientificName) %>%
      dplyr::distinct() %>% # Make sure species names are unique within iterations
      dplyr::pull(scientificName)
    
    if (fuzzy == FALSE){
      worms_rec <- worrms::wm_records_names(name = uniqueSpeciesList) # Save the data table from WoRMS for each species
    } else {
      worms_rec <- worrms::wm_records_taxamatch(name = uniqueSpeciesList) # If Fuzzy search is true
    }
    
    
    worms_df <- worms_rec %>% # Combine them into one single data frame compiling all data from iteration
      dplyr::bind_rows()
    
    wormPH[[i]] <- worms_df # Save the data frame for each iteration into list initialized above.
  }
  
  wormTogether <- dplyr::bind_rows(wormPH) # Bind all data frames contained in the list into one
  
  wormFinal <- wormTogether %>% # Save and return only the columns of interest
    dplyr::select(all_of(ColumnsOfInterest)) %>% 
    rename("worms_name" = "valid_name") %>% 
    mutate("valid_name" = str_replace(worms_name, " \\s*\\([^\\)]+\\)", "")) # Remove entries with Genus (Genus) species type naming
    
  
  return(wormFinal)
}
